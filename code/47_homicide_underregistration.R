# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 47. From registered to total homicides by department, 1950-2019:
#     prototype, three scenarios
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# PROTOTYPE. 45 estimates homicides among REGISTERED deaths. This script
# asks how many were not registered. The project has two conventions for
# violent deaths: 42 applies no completeness factor to them ("certified by
# legal medicine"), 30 applies the factor of all deaths. Both are put to a
# test here and neither holds before 1998.
#
# 1. test    the Policia counts homicides without depending on death
#            registration. across departments, log(Policia / EEVV violent
#            deaths) is regressed on -log(completeness of adult male deaths):
#              slope 0  homicides are registered in full whatever the
#                       completeness of the department (convention of 42)
#              slope 1  homicides are missed like any other death (30)
#            done for 1985-1997 and 1998-2002, with three completeness
#            measures (GGB of 10, DDM of 18, Adair-Lopez non-violent of 33).
#            the slope of 1985-1997 is theta, the elasticity used below.
#            caveat: the Policia is itself incomplete. if it misses more
#            where registration is poor, theta is too low.
#
# 2. index   there is no completeness by department before 1985. an index is
#            built for the 15 units of 45, 1950-1997:
#              expected non-violent deaths of the unit = national adjusted
#              non-violent rates by age and sex (42) x population of the
#              unit by age and sex (censuses 1938, 1951, 1964 and DANE from
#              1985; age shares interpolated; totals of 45)
#              R = (registered non-violent / expected), relative to the same
#              ratio for the country, median of five years
#              completeness of the unit = national completeness (42) x R,
#              capped at 1
#            the expected deaths of a unit are scaled by its level of
#            mortality: child mortality of the unit over the national (DANE
#            life tables of 1985-1990, held constant over time), raised to
#            the elasticity of each age to child mortality in the national
#            series. without it the index assumes the same mortality
#            everywhere and overstates completeness where mortality is
#            higher. the index of the 1973 census (43) is kept only as a
#            sensitivity check: it puts child mortality below the national
#            in the Caribbean, where dead children are under-reported.
#            checked against the GGB of 1985-1995.
#
# 3. totals  total = registered x completeness^(-theta), up to 1997:
#              low      theta = 0        (42: no correction)
#              central  theta estimated  (test above)
#              high     theta = 1        (30: like any other death)
#            from 1998 the three are the registered count: the test finds
#            no relation with completeness after the 1998 certificate.
#            not included: the conflict homicides and disappearances that
#            the MSE estimates add nationally in 1985-2018 (42); they are not
#            available by department.
#
# inputs   output/tables/homicide_backcast_dept_1915-2019.csv           (45)
#          output/tables/homicide_backcast_police_bias.csv               (45)
#          output/tables/mortality_adjusted_components_1950-2023.csv     (42)
#          output/tables/child_mortality_census1973_departments.csv      (43)
#          output/tables/completeness_ggb.csv, completeness_ddm.csv,
#          completeness_empirical_dept_1985-2023.csv             (10, 18, 33)
#          output/deaths_pop_munic_1985_2023.csv.gz, ..._age_1985_2023.parquet
#          data_input/historical/census_tables/census1951_dept_age5_sex_1938_1951.csv
#          data_input/historical/census_tables/census1964_dept_age5_sex_zone.csv
#          data_input/historical/Homicidio 1962-2002 por depto de Policia_v1.xlsx
# outputs  output/tables/homicide_underreg_theta.csv
#          output/tables/homicide_underreg_completeness_index.csv
#          output/tables/homicide_underreg_index_validation.csv
#          output/tables/homicide_underreg_sensitivity_level.csv
#          output/tables/homicide_total_dept_1950-2019.csv
#          output/tables/homicide_total_national_1950-2019.csv
#          figures/07_backcast/underreg_theta.png
#          figures/07_backcast/underreg_totals.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls())
gc()
source("code/00_setup.R")
library(arrow)

dir.create("figures/07_backcast", showWarnings = FALSE, recursive = TRUE)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
norm_name <- function(x) {
  x |> stringi::stri_trans_general("Latin-ASCII") |> tolower() |> trimws() |>
    gsub(pattern = "[ _]+", replacement = "_")
}
cod_unit <- c(
  "05" = "antioquia", "08" = "atlantico", "13" = "bolivar", "23" = "bolivar", "70" = "bolivar",
  "15" = "boyaca", "17" = "caldas", "63" = "caldas", "66" = "caldas", "19" = "cauca",
  "11" = "cundinamarca", "25" = "cundinamarca", "41" = "huila", "47" = "magdalena", "20" = "magdalena",
  "52" = "narino", "54" = "norte_de_santander", "68" = "santander", "73" = "tolima", "76" = "valle_del_cauca"
) # every other code is "territorios" (same units as 45)
unit_of_cod <- function(cod) coalesce(unname(cod_unit[sprintf("%02d", as.integer(cod))]), "territorios")
name_unit <- c(antioquia = "antioquia", atlantico = "atlantico", bolivar = "bolivar", cordoba = "bolivar", boyaca = "boyaca",
               caldas = "caldas", cauca = "cauca", cundinamarca = "cundinamarca", "bogota_d.e." = "cundinamarca", huila = "huila",
               magdalena = "magdalena", narino = "narino", norte_de_santander = "norte_de_santander", santander = "santander",
               tolima = "tolima", valle_del_cauca = "valle_del_cauca") # every other census unit is "territorios"

bc <- read_csv("output/tables/homicide_backcast_dept_1915-2019.csv", show_col_types = FALSE)
unit_lab <- deframe(distinct(bc, unit, unit_label))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. test: Policia / EEVV against completeness, by department ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Bogota and Cundinamarca are pooled (the Policia jurisdictions do not split
# them like DIVIPOLA); the territories are left out (jurisdictions change)
pol_code <- c(antioquia = "05", uraba = "05", metropolitana_medellin = "05", atlantico = "08", bolivar = "13", boyaca = "15",
              caldas = "17", caqueta = "18", cauca = "19", cesar = "20", cordoba = "23", cundinamarca = "25",
              metropolitana_bogota = "25", choco = "27", huila = "41", guajira = "44", magdalena = "47", meta = "50",
              narino = "52", norte_de_santander = "54", quindio = "63", risaralda = "66", santander = "68", sucre = "70",
              tolima = "73", valle = "76", metropolitana_cali = "76")
pool <- function(cod) { cod <- sprintf("%02d", as.integer(cod)); ifelse(cod == "11", "25", cod) }
per_of <- function(year) ifelse(year <= 1997, "1985-1997", "1998-2002")

pol <- read_excel("data_input/historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx", sheet = "Tabla_ancha") |>
  pivot_longer(-Jurisdiccion, names_to = "year", values_to = "n") |>
  mutate(year = as.integer(year), cod = unname(pol_code[norm_name(Jurisdiccion)])) |>
  filter(!is.na(cod), year >= 1985) |>
  summarise(pol = sum(n, na.rm = TRUE), .by = c(cod, year))
sh <- read_csv("output/deaths_pop_munic_1985_2023.csv.gz", show_col_types = FALSE) |>
  mutate(dx_v = dx_homicide + dx_undetermined + dx_legal)
ev <- sh |>
  filter(year <= 2002) |>
  mutate(cod = pool(cod_dpto)) |>
  summarise(v = sum(dx_v), .by = c(cod, year))
ratio <- inner_join(pol, ev, by = c("cod", "year")) |>
  mutate(per = per_of(year)) |>
  summarise(pol = sum(pol), v = sum(v), .by = c(cod, per)) |>
  mutate(log_ratio = log(pol / v))

comp <- bind_rows(
  read_csv("output/tables/completeness_ggb.csv", show_col_types = FALSE) |>
    filter(sex == "m", period %in% c("1985-1995", "1995-2005")) |>
    transmute(measure = "GGB (10)", cod = pool(cod_dpto), per = ifelse(period == "1985-1995", "1985-1997", "1998-2002"), completeness),
  read_csv("output/tables/completeness_ddm.csv", show_col_types = FALSE) |>
    filter(sex == "m", window %in% c("1985-1993", "1993-2005")) |>
    transmute(measure = "DDM (18)", cod = pool(cod), per = ifelse(window == "1985-1993", "1985-1997", "1998-2002"), completeness = ggbseg),
  read_csv("output/tables/completeness_empirical_dept_1985-2023.csv", show_col_types = FALSE) |>
    filter(sex == "m", variant == "non_violent", model == 1, q5_source == "DANE-ENDS", year <= 2002, !is.na(suppressWarnings(as.integer(cod)))) |>
    transmute(measure = "Adair-Lopez (33)", cod = pool(cod), per = per_of(year), completeness)
) |>
  summarise(completeness = pmin(mean(completeness), 1), .by = c(measure, cod, per))

tst <- inner_join(ratio, comp, by = c("cod", "per")) |> mutate(x = -log(completeness))
theta_tab <- tst |>
  group_by(measure, per) |>
  group_modify(~ {
    s <- summary(lm(log_ratio ~ x, .x))
    tibble(departments = nrow(.x), intercept = s$coef[1, 1], slope = s$coef[2, 1], se = s$coef[2, 2], r2 = s$r.squared)
  }) |>
  ungroup()
write_csv(theta_tab, "output/tables/homicide_underreg_theta.csv")
cat("\n== log(Policia / EEVV) on -log(completeness), by department ==\n")
print(as.data.frame(theta_tab |> mutate(across(where(is.double), ~ round(.x, 2)))), row.names = FALSE)
theta <- theta_tab |> filter(per == "1985-1997") |> summarise(theta = mean(slope)) |> pull(theta)
say("theta (mean slope of the three measures, 1985-1997):", round(theta, 2),
    "| 1998-2002:", round(mean(theta_tab$slope[theta_tab$per == "1998-2002"]), 2))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. completeness index by unit, 1950-1997 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
idx_years <- 1950:1997
ages <- c(0, 1, seq(5, 80, 5))

# age and sex shares of each unit in the census years
cen <- bind_rows(
  read_csv("data_input/historical/census_tables/census1951_dept_age5_sex_1938_1951.csv", show_col_types = FALSE),
  read_csv("data_input/historical/census_tables/census1964_dept_age5_sex_zone.csv", show_col_types = FALSE) |> filter(zone == "total")
) |>
  filter(unit_type != "total", age != "total", !is.na(age_start)) |>
  mutate(unit = coalesce(unname(name_unit[norm_name(unit)]), "territorios"), age = pmin(age_start, 80)) |>
  pivot_longer(c(male, female), names_to = "sex", values_to = "pop") |>
  mutate(sex = ifelse(sex == "male", "m", "f")) |>
  rename(year = census_year) |>
  summarise(pop = sum(pop, na.rm = TRUE), .by = c(year, unit, sex, age))
pq <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet", col_select = c("year", "sex", "cod_dpto", "age", "pop")) |>
  filter(year <= max(idx_years), !is.na(age)) |> # age NA holds deaths of unknown age, no population
  mutate(unit = unit_of_cod(cod_dpto), age = pmin(age, 80)) |>
  summarise(pop = sum(pop, na.rm = TRUE), .by = c(year, unit, sex, age))
stopifnot(setequal(unique(cen$age), ages), setequal(unique(pq$age), ages))
shares <- bind_rows(cen, pq) |> mutate(share = pop / sum(pop), .by = c(year, unit))
anchor <- sort(unique(shares$year))
say("age structure by unit available in:", paste(range(anchor[anchor < 1985]), collapse = "-"), "(censuses", paste(anchor[anchor < 1985], collapse = ", "), ") and DANE from 1985")
shares_y <- shares |>
  group_by(unit, sex, age) |>
  reframe(share = approx(year, share, idx_years, rule = 2)$y, year = idx_years)

# national non-violent rates and completeness (42)
m42 <- read_csv("output/tables/mortality_adjusted_components_1950-2023.csv", show_col_types = FALSE) |>
  filter(year %in% idx_years) |>
  transmute(year, sex, age, pop_nat = pop, mx_nv = mx_total - mx_violent, completeness_natural)
c_nat <- m42 |>
  summarise(c_nat = sum(mx_nv * pop_nat) / sum(mx_nv * pop_nat / completeness_natural), .by = year) # both sexes

# relative level of mortality of each unit, from child mortality. two
# sources: the index of the 1973 census (43; depends on how well dead
# children are reported, which is worse where registration is worse) and the
# DANE life tables of 1985-1990. q5 of the unit over the national, weighted
# by women aged 15+ in 1973.
name_unit_73 <- c(name_unit, valle = "valle_del_cauca", cesar = "magdalena", sucre = "bolivar", quindio = "caldas", risaralda = "caldas")
level <- read_csv("output/tables/child_mortality_census1973_departments.csv", show_col_types = FALSE) |>
  filter(zone == "total") |>
  mutate(unit = coalesce(unname(name_unit_73[norm_name(unit)]), "territorios")) |>
  summarise(q5_1973 = weighted.mean(q5_index, women), q5_dane = weighted.mean(q5_dane_1985_1990, women * !is.na(q5_dane_1985_1990), na.rm = TRUE),
            women = sum(women), .by = unit) |>
  mutate(r_census1973 = q5_1973 / weighted.mean(q5_1973, women), r_dane = q5_dane / weighted.mean(q5_dane, women), r_none = 1)
cat("\n== child mortality of the unit relative to the country ==\n")
print(as.data.frame(level |> transmute(unit, census_1973 = round(r_census1973, 2), dane_1985_1990 = round(r_dane, 2)) |> arrange(dane_1985_1990)), row.names = FALSE)
say("correlation between the two sources of level:", round(cor(level$r_census1973, level$r_dane), 2))

# how much mortality at each age moves with child mortality: elasticity of
# the national non-violent rate of each age and sex to the rate under five,
# across the years of the index (the country's own transition as the family
# of schedules). 1 under five, bounded to [0, 1] above.
child <- m42 |> filter(age < 5) |> summarise(child = sum(mx_nv * pop_nat) / sum(pop_nat), .by = year)
elas <- m42 |> filter(age >= 5) |> left_join(child, by = "year") |>
  summarise(elasticity = pmin(pmax(coef(lm(log(mx_nv) ~ log(child)))[2], 0), 1), .by = c(sex, age)) |>
  bind_rows(expand_grid(sex = c("m", "f"), age = c(0, 1), elasticity = 1))
cat("\n== elasticity of the rate of each age to child mortality (men / women) ==\n")
print(as.data.frame(elas |> mutate(elasticity = round(elasticity, 2)) |> pivot_wider(names_from = sex, values_from = elasticity) |> arrange(age)), row.names = FALSE)

# index with the expected deaths of each unit scaled by its level of
# mortality (r^elasticity), keeping the national expected deaths of the year
build_idx <- function(source) {
  shares_y |>
    left_join(bc |> select(unit, year, pop, deaths_adj, hom_est), by = c("unit", "year")) |>
    left_join(m42 |> select(year, sex, age, mx_nv), by = c("year", "sex", "age")) |>
    left_join(elas, by = c("sex", "age")) |>
    left_join(level |> transmute(unit, r = .data[[paste0("r_", source)]]), by = "unit") |>
    summarise(expected_plain = sum(share * pop * mx_nv), expected = sum(share * pop * mx_nv * r^elasticity),
              registered_nv = first(deaths_adj) - first(hom_est), pop = first(pop), .by = c(unit, year)) |>
    mutate(expected = expected * sum(expected_plain) / sum(expected),
           ratio = registered_nv / expected, ratio_nat = sum(registered_nv) / sum(expected), .by = year) |>
    arrange(unit, year) |>
    mutate(rel = ratio / ratio_nat,
           rel_smooth = exp(vapply(seq_along(year), function(i) median(log(rel[abs(year - year[i]) <= 2])), numeric(1))),
           .by = unit) |>
    left_join(c_nat, by = "year") |>
    mutate(completeness_index = pmin(c_nat * rel_smooth, 1))
}
idx_all <- list(none = build_idx("none"), census1973 = build_idx("census1973"), dane = build_idx("dane"))
# the version used below is chosen in section 3; until then idx is the DANE one
level_used <- "dane"
idx <- idx_all[[level_used]]
cat("\n== national: registered / expected non-violent deaths against the completeness of 42 ==\n")
print(as.data.frame(idx |> distinct(year, ratio_nat = round(ratio_nat, 2), c_nat = round(c_nat, 2)) |> filter(year %% 5 == 0)), row.names = FALSE)
idx |>
  transmute(unit, unit_label = unit_lab[unit], year, registered_nonviolent = registered_nv, expected_nonviolent = expected,
            relative_to_national = rel, relative_smooth = rel_smooth, completeness_national = c_nat, completeness_index) |>
  left_join(idx_all$none |> select(unit, year, completeness_index_no_level = completeness_index), by = c("unit", "year")) |>
  left_join(idx_all$census1973 |> select(unit, year, completeness_index_level_census1973 = completeness_index), by = c("unit", "year")) |>
  write_csv("output/tables/homicide_underreg_completeness_index.csv")
cat("\n== completeness index by unit, selected years ==\n")
print(as.data.frame(idx |> filter(year %in% c(1950, 1955, 1960, 1965, 1970, 1975, 1980, 1985, 1990, 1995)) |>
  transmute(unit, year, c = round(completeness_index, 2)) |> pivot_wider(names_from = year, values_from = c)), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. checks of the index ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# against the GGB of 1985-1995 and the DDM of 1985-1993 (both sexes, units as
# registered deaths over the sum of registered / completeness)
dreg <- sh |> filter(year %in% 1985:1995) |>
  mutate(cod = sprintf("%02d", as.integer(cod_dpto))) |>
  summarise(d = sum(dx_all), .by = c(cod, sex))
agg_c <- function(tab, cod, completeness) {
  tab |> transmute(cod = sprintf("%02d", as.integer({{ cod }})), sex, completeness = pmin({{ completeness }}, 1)) |>
    inner_join(dreg, by = c("cod", "sex")) |>
    mutate(unit = unit_of_cod(cod)) |>
    summarise(c = sum(d) / sum(d / completeness), .by = unit)
}
chk <- bind_rows(idx_all, .id = "level") |> filter(year %in% 1985:1995) |>
  summarise(index = mean(completeness_index), .by = c(level, unit)) |>
  pivot_wider(names_from = level, values_from = index, names_prefix = "index_") |>
  left_join(agg_c(read_csv("output/tables/completeness_ggb.csv", show_col_types = FALSE) |> filter(period == "1985-1995"), cod_dpto, completeness) |> rename(ggb = c), by = "unit") |>
  left_join(agg_c(read_csv("output/tables/completeness_ddm.csv", show_col_types = FALSE) |> filter(window == "1985-1993", cod != "91"), cod, ggbseg) |> rename(ddm = c), by = "unit")
write_csv(chk, "output/tables/homicide_underreg_index_validation.csv")
cat("\n== index against GGB and DDM, 1985-1995 ==\n")
print(as.data.frame(chk |> mutate(across(where(is.double), ~ round(.x, 2))) |> arrange(ggb)), row.names = FALSE)
fit_chk <- tibble(level = names(idx_all)) |>
  mutate(mean_index = map_dbl(level, ~ mean(chk[[paste0("index_", .x)]])),
         r_ggb = map_dbl(level, ~ cor(chk[[paste0("index_", .x)]], chk$ggb, use = "complete.obs")),
         r_ddm = map_dbl(level, ~ cor(chk[[paste0("index_", .x)]], chk$ddm, use = "complete.obs")),
         rmse_log_ggb = map_dbl(level, ~ sqrt(mean(log(chk[[paste0("index_", .x)]] / chk$ggb)^2, na.rm = TRUE))),
         mean_ggb = mean(chk$ggb, na.rm = TRUE), mean_ddm = mean(chk$ddm, na.rm = TRUE))
cat("\n== which level of mortality brings the index closer to the GGB of 1985-1995 ==\n")
print(as.data.frame(fit_chk |> mutate(across(where(is.double), ~ round(.x, 2)))), row.names = FALSE)

# the same test as in 1, in 1962-1965 and 1979-1984, with the bias of the
# Policia estimated by 45 (log Policia / vital statistics) and the index
pb <- read_csv("output/tables/homicide_backcast_police_bias.csv", show_col_types = FALSE)
early <- pb |> transmute(unit, `1962-1965` = log_ratio_anuario_1962_65, `1979-1984` = log_ratio_eevv_1979_84, `1985-1997` = log_ratio_eevv_1985_97) |>
  pivot_longer(-unit, names_to = "per", values_to = "log_ratio") |>
  mutate(y0 = as.integer(substr(per, 1, 4)), y1 = as.integer(substr(per, 6, 9))) |>
  left_join(idx |> select(unit, year, completeness_index), by = join_by(unit, y0 <= year, y1 >= year)) |>
  summarise(log_ratio = first(log_ratio), x = -log(mean(completeness_index)), .by = c(unit, per))
theta_units <- early |> filter(is.finite(log_ratio)) |> group_by(per) |>
  group_modify(~ { s <- summary(lm(log_ratio ~ x, .x)); tibble(units = nrow(.x), intercept = s$coef[1, 1], slope = s$coef[2, 1], se = s$coef[2, 2], r2 = s$r.squared) }) |>
  ungroup()
cat("\n== the same test with the 15 units and the index ==\n")
print(as.data.frame(theta_units |> mutate(across(where(is.double), ~ round(.x, 2)))), row.names = FALSE)
bind_rows(theta_tab |> mutate(level = "department"), theta_units |> transmute(measure = "index of this script", per, departments = units, intercept, slope, se, r2, level = "unit")) |>
  write_csv("output/tables/homicide_underreg_theta.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 4. total homicides, three scenarios ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tot <- bc |>
  filter(year >= 1950) |>
  select(unit, unit_label, year, pop, hom_reg = hom_est, hom_reg_lo90 = hom_lo90, hom_reg_hi90 = hom_hi90) |>
  left_join(idx |> select(unit, year, completeness_index), by = c("unit", "year")) |>
  mutate(
    c_use = ifelse(year <= 1997, completeness_index, 1), # from 1998: no relation with completeness
    hom_total_low = hom_reg,
    hom_total_central = hom_reg * c_use^(-theta),
    hom_total_high = hom_reg / c_use,
    across(starts_with("hom_total"), ~ 1e5 * .x / pop, .names = "rate_{sub('hom_', '', .col)}"),
    rate_reg = 1e5 * hom_reg / pop
  ) |>
  select(-c_use)
write_csv(tot, "output/tables/homicide_total_dept_1950-2019.csv")
nat <- tot |>
  summarise(pop = sum(pop), across(c(hom_reg, starts_with("hom_total")), sum), .by = year) |>
  mutate(across(starts_with("hom_total"), ~ .x / hom_reg, .names = "factor_{sub('hom_total_', '', .col)}"))
write_csv(nat, "output/tables/homicide_total_national_1950-2019.csv")
cat("\n== national totals by scenario ==\n")
print(as.data.frame(nat |> filter(year %in% c(1950, 1955, 1958, 1960, 1965, 1970, 1975, 1980, 1985, 1990, 1995, 1997, 1998)) |>
  transmute(year, registered = round(hom_reg), central = round(hom_total_central), high = round(hom_total_high),
            factor_central = round(factor_central, 2), factor_high = round(factor_high, 2))), row.names = FALSE)
sens <- bind_rows(idx_all, .id = "level") |>
  inner_join(bc |> select(unit, year, hom_est), by = c("unit", "year")) |>
  summarise(registered = sum(hom_est), central = sum(hom_est * completeness_index^(-theta)), high = sum(hom_est / completeness_index), .by = level) |>
  mutate(factor_central = central / registered, factor_high = high / registered)
write_csv(sens, "output/tables/homicide_underreg_sensitivity_level.csv")
cat("\n== 1950-1997, national: factors by version of the index ==\n")
print(as.data.frame(sens |> mutate(across(where(is.double), ~ round(.x, 3)))), row.names = FALSE)
cat("\n== 1950-1997 by unit: registered, central, high and factors ==\n")
print(as.data.frame(tot |> filter(year <= 1997) |> summarise(registered = round(sum(hom_reg)), central = round(sum(hom_total_central)), high = round(sum(hom_total_high)), .by = unit) |>
  mutate(factor_central = round(central / registered, 2), factor_high = round(high / registered, 2)) |> arrange(-factor_central)), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 5. figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#1f1f1e"
base <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
        legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey40", hjust = 0))

# 5.1 the test
ref <- expand_grid(per = c("1985-1997", "1998-2002"), x = seq(0, 1.5, 0.1), linea = c("Como cualquier defunción (30)", "Registro completo (42)")) |>
  mutate(y = ifelse(linea == "Registro completo (42)", 0, x))
fig1 <- tst |>
  filter(measure == "GGB (10)") |>
  ggplot(aes(x, log_ratio)) +
  geom_line(data = ref, aes(x, y, linetype = linea), colour = "grey45", linewidth = 0.35) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "#2a78d6", linewidth = 0.6) +
  geom_point(colour = ink, size = 1.6) +
  scale_linetype_manual(values = c("Como cualquier defunción (30)" = "22", "Registro completo (42)" = "solid")) +
  scale_x_continuous(breaks = -log(c(1, 0.8, 0.6, 0.4, 0.25)), labels = c("1", "0,8", "0,6", "0,4", "0,25")) +
  scale_y_continuous(breaks = log(c(0.5, 0.75, 1, 1.5, 2, 3)), labels = c("0,5", "0,75", "1", "1,5", "2", "3")) +
  coord_cartesian(ylim = log(c(0.45, 3.2))) +
  facet_wrap(~per) +
  labs(title = "¿Se registran los homicidios cuando el registro general es malo?",
       subtitle = "Cada punto es un departamento. Línea azul: relación observada. Líneas grises: lo que se vería bajo cada uno de los dos criterios del proyecto.",
       x = "Completitud del registro de defunciones de hombres adultos (GGB)", y = "Homicidios según la Policía / según EEVV") +
  base
ggsave("figures/07_backcast/underreg_theta.png", fig1, w = 10, h = 5, bg = "white", dpi = 160)

# 5.2 totals: national and by unit
esc_col <- c("Registrados (sin corrección)" = ink, "Central" = "#2a78d6", "Como cualquier defunción" = "#eb6834")
long <- function(d) d |>
  pivot_longer(c(hom_total_low, hom_total_central, hom_total_high), names_to = "esc", values_to = "hom") |>
  mutate(esc = factor(esc, c("hom_total_low", "hom_total_central", "hom_total_high"), names(esc_col)), rate = 1e5 * hom / pop)
fig2a <- ggplot(long(nat), aes(year, rate, colour = esc)) +
  geom_vline(xintercept = 1997.5, colour = "grey70", linewidth = 0.3, linetype = 3) +
  geom_line(linewidth = 0.55) +
  scale_colour_manual(values = esc_col) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Homicidios por 100.000 habitantes: registrados y totales según el criterio de subregistro",
       subtitle = paste0("Suma de las 15 unidades. Central: elasticidad de ", format(round(theta, 2), decimal.mark = ","),
                         " respecto de la completitud general. Desde 1998 (línea punteada) no se corrige."),
       x = NULL, y = NULL) +
  base
fig2b <- ggplot(long(tot), aes(year, rate, colour = esc)) +
  geom_line(linewidth = 0.4) +
  scale_colour_manual(values = esc_col, guide = "none") +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  facet_wrap(~unit_label, ncol = 5, scales = "free_y") +
  labs(x = NULL, y = NULL,
       caption = "Prototipo. No incluye los homicidios del conflicto y las desapariciones que las estimaciones de sistemas múltiples añaden a nivel nacional en 1985-2018.") +
  base
ggsave("figures/07_backcast/underreg_totals.png", ggpubr::ggarrange(fig2a, fig2b, ncol = 1, heights = c(1, 1.5)), w = 12, h = 11, bg = "white", dpi = 160)

say("done")
