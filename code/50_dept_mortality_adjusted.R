# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 50. Mortality adjusted component by component, by department, sex and
#     age, 1985-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The national adjustment of 42 run by department, with the same five
# components and the departmental counterpart of each input. 29 units: the
# 24 departments of 1985, Arauca, Casanare, Putumayo, San Andrés, and the
# five Amazon departments (Amazonas, Guainía, Guaviare, Vaupés, Vichada) as
# one group ("9X"), as DANE's life tables and 33 do.
#
#   deaths          EEVV microdata by municipality, sex and age group (11b,
#                   output/deaths_pop_munic_age_1985_2023.parquet), summed to
#                   departments; 85+ folded into 80+ as in the national
#                   series; deaths of unknown age (1.6 % in 1985, 0.1 % in
#                   2023) spread within department, year, sex and component
#   population      DANE: retroprojection 1985-2017 and the 2018 census
#                   projections 2018-2023, the same file. Not WPP, so the
#                   departmental rates are not strictly comparable with the
#                   national series, whose denominator is WPP (the sum of the
#                   departments is compared with it below)
#   under five      UN IGME national m0 and 4m1 (41) times a departmental
#                   index: the ratio of DANE's departmental to national nmx at
#                   ages 0 and 1-4 in its abridged life tables 1985-2020
#                   (13), interpolated between period midpoints and held
#                   constant after 2017.5 and before 1987.5
#   natural 5-64    registered natural deaths / completeness, smoothed with a
#                   tensor P-spline over age and year per department and sex
#                   (fitted on 1985-2019; 2020-2023 take the corrected annual
#                   rates, as nationally)
#   natural 65+     relational model on the WPP 2024 national standard of
#                   2010-2019 (logit m(x) = alpha + logit m_s(x)), alpha the
#                   root of the corrected natural deaths at 65+, smoothed
#                   over years (fitted on 1985-2019)
#   completeness    Adair-Lopez model 1 on the non-violent registered deaths
#                   by department and sex (33, q5 pattern DANE scaled to ENDS),
#                   smoothed on the logit scale over 1985-2019 (the annual
#                   departmental values swing by 20-50 points) and held at
#                   the 2019 value from 2020, where the model reads the
#                   pandemic's extra deaths as better registration; capped
#                   at 1. Then CALIBRATED to the national series: the
#                   departmental omissions (1/c - 1) are scaled by k(year,
#                   sex) so that the sum of the corrected non-violent deaths
#                   at 5+ equals the national corrected deaths of 42; the
#                   departmental model gives the distribution of the
#                   omission, the national series its level. Applied to the
#                   natural and other external deaths. Likewise the under-five
#                   index is rescaled so that its population-weighted mean is
#                   IGME's national rate
#   other external  registered / completeness
#   violent         registered homicide, undetermined intent and legal
#                   intervention, plus the department's share of the
#                   national MSE conflict deaths of 27 (hom_excess + dsp by
#                   year, sex and age), ASSUMPTION: allocated to departments
#                   in proportion to their registered violent deaths of the
#                   year. The JEP-CEV-HRDAG replicates carry department and
#                   would replace this key (R package verdata)
#   crisis          Armero 1985 (47): 22,654 deaths by sex and age, of which
#                   1,100 to Caldas (Chinchiná) and the rest to Tolima
#                   (ASSUMPTION on the split). The police floor is zero from
#                   1985 nationally and the police jurisdictions are not
#                   departments, so no other crisis deaths enter
#
# output: output/tables/dept_mortality_adjusted_components_1985-2023.csv
#         output/tables/dept_mortality_adjusted_summary.csv
#         output/tables/dept_completeness_applied_1985-2023.csv
#         output/tables/dept_vs_national_adjusted_deaths.csv
#         figures/07_departments/dept_e0_adjusted.png
#         figures/07_departments/dept_completeness_applied.png
#         figures/07_departments/dept_components_2000.png
#         figures/07_departments/dept_sum_vs_national.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(arrow)
dir.create("figures/07_departments", showWarnings = FALSE)

years <- 1985:2023
last_smooth <- 2019
std_years <- 2010:2019
age_mid <- function(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, TRUE ~ a + 2.5)
lab_sex <- function(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
amazon <- c("91", "94", "95", "97", "99")
unit_of <- function(cod) if_else(cod %in% amazon, "9X", cod)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# registered deaths and population by department ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
raw <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |>
  transmute(cod = unit_of(cod_dpto), year, sex, age = if_else(is.na(age), NA_real_, pmin(age, 80)), pop,
            natural = dx_residual, other_external = dx_suicide + dx_accident, violent = dx_homicide + dx_undetermined + dx_legal) |>
  summarise(pop = sum(pop, na.rm = TRUE), across(c(natural, other_external, violent), sum), .by = c(cod, year, sex, age))   # one Chocó municipality has no population 1985-2017
names_tab <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |> distinct(cod_dpto, dpto) |>
  transmute(cod = unit_of(cod_dpto), unit = if_else(cod == "9X", "Amazonía (5 deptos)", dpto)) |> distinct() |>
  mutate(unit = sub("Archipiélago de San Andrés.*", "San Andrés", unit), unit = sub("Bogotá, D.C.", "Bogotá", unit, fixed = TRUE)) |>
  arrange(cod)
# unknown ages spread within department, year, sex and component
comp <- raw |>
  mutate(across(c(natural, other_external, violent), function(v) v * (1 + sum(v[is.na(age)]) / pmax(sum(v[!is.na(age)]), 1))), .by = c(cod, year, sex)) |>
  filter(!is.na(age)) |> select(-pop) |>
  left_join(raw |> filter(!is.na(age)) |> select(cod, year, sex, age, pop), by = c("cod", "year", "sex", "age")) |>
  mutate(registered = natural + other_external + violent)
stopifnot(nrow(comp) == 29 * length(years) * 2 * 18, !anyNA(comp$pop), all(comp$pop > 0))
cat(sprintf("registered deaths 1985-2023, sum of departments: %s (parquet all ages: %s)\n",
            format(round(sum(comp$registered)), big.mark = ","),
            format(sum(read_parquet("output/deaths_pop_munic_age_1985_2023.parquet")$dx_all), big.mark = ",")))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# completeness: Adair-Lopez model 1, non-violent deaths, smoothed ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
c_raw <- read_csv("output/tables/completeness_empirical_dept_1985-2023.csv", show_col_types = FALSE) |>
  filter(level == "department", model == 1, variant == "non_violent", q5_source == "DANE-ENDS", sex %in% c("m", "f"), cod %in% names_tab$cod) |>
  select(cod, year, sex, c_annual = completeness)
stopifnot(nrow(c_raw) == 29 * length(years) * 2)
cc <- c_raw |>
  group_by(cod, sex) |>
  group_modify(function(d, k) {
    fit <- gam(y ~ s(year, k = 8, bs = "ps"), data = d |> filter(year <= last_smooth) |> mutate(y = qlogis(pmin(c_annual, 0.995))), method = "REML")
    d |> mutate(c_model = plogis(as.numeric(predict(fit, newdata = tibble(year = pmin(year, last_smooth))))), c_model = pmin(c_model, 1))
  }) |> ungroup()
# calibration to the national series: the departmental omissions (1/c - 1) are
# scaled by k(year, sex) so that the sum of the corrected non-violent deaths at
# 5+ equals the national corrected deaths of 42 (registered / national
# completeness). Departments with c = 1 stay at 1; the departmental model gives
# the distribution of the omission, the national series its level
nat_ctrl <- read_csv("output/tables/deaths_components_registered_1950-2023.csv", show_col_types = FALSE) |>
  filter(year %in% years, age >= 5) |>
  inner_join(read_csv("output/tables/mortality_adjusted_components_1950-2023.csv", show_col_types = FALSE) |> distinct(year, sex, c_nat = completeness_natural),
             by = c("year", "sex")) |>
  summarise(N = sum((natural + other_external) / c_nat), .by = c(year, sex))
kk <- comp |> filter(age >= 5) |> summarise(R = sum(natural + other_external), .by = c(cod, year, sex)) |>
  inner_join(cc |> select(cod, year, sex, c_model), by = c("cod", "year", "sex")) |>
  summarise(omit = sum(R * (1 / c_model - 1)), R = sum(R), .by = c(year, sex)) |>   # omit first: summarise evaluates in order
  inner_join(nat_ctrl, by = c("year", "sex")) |>
  mutate(k = pmax((N - R) / omit, 0))
cc <- cc |> inner_join(kk |> select(year, sex, k), by = c("year", "sex")) |> mutate(c = 1 / (1 + k * (1 / c_model - 1)))
write_csv(cc |> left_join(names_tab, by = "cod") |> select(cod, unit, year, sex, completeness_annual = c_annual, completeness_model = c_model, k, completeness = c),
          "output/tables/dept_completeness_applied_1985-2023.csv")
cat("\ncalibration factor k of the departmental omissions (1 = the departmental model already adds up to the national series):\n")
print(kk |> filter(year %in% c(1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020, 2023)) |> transmute(year, sex, k = round(k, 2)) |> pivot_wider(names_from = sex, values_from = k) |> as.data.frame())
cat("\ncompleteness applied (Adair-Lopez model 1 non-violent, smoothed and calibrated), men, selected years:\n")
print(cc |> filter(sex == "m", year %in% c(1985, 1995, 2005, 2015, 2023)) |> left_join(names_tab, by = "cod") |>
        transmute(unit, year, c = round(c, 2)) |> pivot_wider(names_from = year, values_from = c) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# under five: IGME national times the DANE departmental index ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
child <- read_csv("output/tables/igme_child_mortality_1950-2023.csv", show_col_types = FALSE) |> filter(year %in% years) |> select(year, sex, m0, m1_4)
dane_names <- names_tab |> mutate(area = case_when(cod == "11" ~ "Bogotá D.C.", cod == "88" ~ "San Andrés", cod == "9X" ~ "Grupo Amazonía", TRUE ~ unit))
dane_lt <- read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE) |>
  mutate(mid = as.numeric(substr(period, 1, 4)) + 2.5)
stopifnot(all(dane_names$area %in% dane_lt$area))
idx_pts <- dane_lt |> filter(age <= 1) |>
  inner_join(dane_lt |> filter(area == "Nacional", age <= 1) |> select(mid, sex, age, nat = nmx), by = c("mid", "sex", "age")) |>
  inner_join(dane_names |> select(cod, area), by = "area") |>
  transmute(cod, sex, age, mid, idx = nmx / nat)
idx <- expand_grid(cod = names_tab$cod, sex = c("m", "f"), age = c(0, 1), year = years) |>
  left_join(idx_pts |> nest(pts = c(mid, idx)), by = c("cod", "sex", "age")) |>
  mutate(idx = map2_dbl(pts, year, function(p, y) approx(p$mid, p$idx, xout = y, rule = 2)$y)) |> select(-pts)
# the index is rescaled so that the population-weighted mean of the departments is IGME's national rate
idx <- idx |> inner_join(comp |> filter(age <= 1) |> select(cod, year, sex, age, pop), by = c("cod", "year", "sex", "age")) |>
  mutate(idx = idx * sum(pop) / sum(pop * idx), .by = c(year, sex, age)) |> select(-pop)
u5 <- idx |> left_join(child, by = c("year", "sex")) |>
  transmute(cod, year, sex, age, m_u5 = if_else(age == 0, m0, m1_4) * idx, idx_u5 = idx)
cat("\nunder-five index (DANE departmental / national nmx, rescaled to IGME), age 0, men, 2017: range",
    paste(round(range(idx$idx[idx$age == 0 & idx$sex == "m" & idx$year == 2017]), 2), collapse = "-"), "\n")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MSE conflict deaths allocated to departments; Armero ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MSE conflict deaths by department (51): regional MSE x documented share, excess over the EEVV violent deaths
# and disappearances calibrated to the national series of 27; zero outside 1985-2018 and under five
mse_dept <- read_csv("output/tables/mse_departments_1985-2018.csv", show_col_types = FALSE, col_types = cols(cod = "c")) |>
  select(cod, year, sex, age, mse = mse_added)
armero_split <- c("73" = 1 - 1100 / 22654, "17" = 1100 / 22654)
armero <- read_csv("output/tables/crisis_deaths_1950-2023.csv", show_col_types = FALSE) |>
  filter(year == 1985) |> select(year, sex, age, armero) |>
  expand_grid(cod = names(armero_split)) |> mutate(crisis = armero * armero_split[cod]) |> select(cod, year, sex, age, crisis)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# the adjustment, by department ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# old-age standard: WPP 2024 national mx of 2010-2019 by 5-year group (65-69 ... 80+), population-weighted
pop1 <- read_csv("data_input/reference/wpp2024_colombia_pop_single_age_1950-2023.csv", show_col_types = FALSE) |>
  filter(Time %in% std_years, AgeGrpStart >= 65) |>
  transmute(year = Time, age1 = AgeGrpStart, m = PopMale * 1000, f = PopFemale * 1000) |>
  pivot_longer(c(m, f), names_to = "sex", values_to = "pop")
std <- read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Time %in% std_years, Sex != "Total", AgeGrpStart >= 65) |>
  transmute(year = Time, sex = unname(c(Female = "f", Male = "m")[Sex]), age1 = AgeGrpStart, mx) |>
  inner_join(pop1, by = c("year", "sex", "age1")) |>
  mutate(age = pmin(5 * (age1 %/% 5), 80)) |>
  summarise(y_s = qlogis(sum(mx * pop) / sum(pop)), .by = c(sex, age))

d <- comp |>
  left_join(cc |> select(cod, year, sex, c, c_model), by = c("cod", "year", "sex")) |>
  left_join(mse_dept, by = c("cod", "year", "sex", "age")) |>
  left_join(armero, by = c("cod", "year", "sex", "age")) |>
  mutate(crisis = replace_na(crisis, 0), mse = replace_na(mse, 0), nat_c = natural / c, oext_c = other_external / c, viol_adj = violent + mse, x = age_mid(age))
stopifnot(!anyNA(d$c), !anyNA(d$mse))

fit_unit <- function(dd) {   # dd: one department and sex, all years and ages
  s <- dd$sex[1]
  # natural 5-79: tensor P-spline, fitted on years <= last_smooth
  d5 <- dd |> filter(age >= 5, age < 80)
  m <- gam(nat_c ~ te(x, year, k = c(8, 10), bs = "ps") + offset(log(pop)), family = quasipoisson(),
           data = d5 |> filter(year <= last_smooth), method = "REML")
  # 2020-2023: the corrected annual rate; the 2019 surface where a small unit has no natural deaths in a cell
  nat <- d5 |> mutate(pred = as.numeric(predict(m, newdata = mutate(d5, year = pmin(year, last_smooth)), type = "response")) / pop,
                      mx_nat = if_else(year <= last_smooth | nat_c == 0, pred, nat_c / pop)) |>
    select(year, age, mx_nat)
  # natural 65+: relational model, alpha per year, smoothed
  d65 <- dd |> filter(age >= 65) |> left_join(std |> filter(sex == s) |> select(age, y_s), by = "age")
  al <- d65 |> summarise(alpha_obs = uniroot(function(a) sum(plogis(a + y_s) * pop) - sum(nat_c), c(-8, 8), tol = 1e-10)$root, .by = year)
  f <- gam(alpha_obs ~ s(year, k = 8, bs = "ps"), data = al |> filter(year <= last_smooth), method = "REML")
  al <- al |> mutate(alpha = if_else(year <= last_smooth, as.numeric(predict(f, newdata = tibble(year = pmin(year, last_smooth)))), alpha_obs))
  old <- d65 |> left_join(al |> select(year, alpha), by = "year") |> transmute(year, age, mx_nat_old = plogis(alpha + y_s))
  dd |> left_join(nat, by = c("year", "age")) |> left_join(old, by = c("year", "age")) |>
    left_join(al, by = "year") |> mutate(dev_expl = summary(m)$dev.expl) |> select(-sex)
}
adj <- d |> group_by(cod, sex) |> group_modify(function(dd, k) fit_unit(dd |> mutate(sex = k$sex))) |> ungroup() |>
  left_join(u5, by = c("cod", "year", "sex", "age")) |>
  mutate(mx_other_external = oext_c / pop, mx_violent = viol_adj / pop, mx_crisis = crisis / pop,
         mx_natural = case_when(age < 5 ~ pmax(m_u5 - mx_other_external - mx_violent, 0), age >= 65 ~ mx_nat_old, TRUE ~ mx_nat),
         mx_total = if_else(age < 5, m_u5 + mx_crisis, mx_natural + mx_other_external + mx_violent + mx_crisis),
         mx_registered = registered / pop,
         method_natural = case_when(age < 5 ~ "UN IGME x índice DANE departamental", age >= 65 ~ "modelo relacional 65+",
                                    year <= last_smooth ~ "corregida y suavizada", TRUE ~ "corregida, anual")) |>
  left_join(names_tab, by = "cod") |>
  select(cod, unit, year, sex, age, pop, registered, mx_natural, mx_other_external, mx_violent, mx_crisis, mx_total, mx_registered,
         completeness_natural = c, completeness_model = c_model, idx_u5, alpha_old = alpha, method_natural) |>
  arrange(cod, year, sex, age)
stopifnot(!anyNA(adj$mx_total), all(adj$mx_total > 0), nrow(adj) == nrow(comp))
write_csv(adj, "output/tables/dept_mortality_adjusted_components_1985-2023.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# life tables and summaries ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lifetable <- function(age, mx, sex) {   # abridged, as in 42
  n <- c(diff(age), Inf)
  m0 <- mx[1]
  a0 <- if (sex == "m") { if (m0 < 0.023) 0.14929 - 1.99545 * m0 else if (m0 < 0.08307) 0.02832 + 3.26201 * m0 else 0.29915 } else
                        { if (m0 < 0.01724) 0.14903 - 2.05527 * m0 else if (m0 < 0.06891) 0.04667 + 3.88089 * m0 else 0.31411 }
  a1 <- if (sex == "m") { if (m0 < 0.023) 1.6534 else if (m0 < 0.08307) 1.5806 else 1.3607 } else
                        { if (m0 < 0.01724) 1.6338 else if (m0 < 0.06891) 1.5265 else 1.3062 }
  ax <- c(a0, a1, rep(2.5, length(age) - 3), 1 / mx[length(age)])
  qx <- n * mx / (1 + (n - ax) * mx); qx[length(age)] <- 1
  lx <- c(1, cumprod(1 - qx))[seq_along(age)]
  dx <- lx * qx
  Lx <- n * (lx - dx) + ax * dx; Lx[length(age)] <- lx[length(age)] / mx[length(age)]
  Tx <- rev(cumsum(rev(Lx)))
  tibble(age, lx, ex = Tx / lx)
}
indicators <- function(x) {
  gv <- group_vars(x)
  x |> reframe(lifetable(age, mx, first(sex))) |>
    summarise(e0 = ex[age == 0], q5 = 1 - lx[age == 5], q45_15 = 1 - lx[age == 60] / lx[age == 15], e60 = ex[age == 60], .by = all_of(gv))
}
series <- c("Ajustada por componentes" = "mx_total", "Registradas" = "mx_registered")
summ <- adj |>
  pivot_longer(all_of(unname(series)), names_to = "v", values_to = "mx") |>
  mutate(series = factor(names(series)[match(v, series)], names(series))) |>
  arrange(series, cod, year, sex, age) |> group_by(series, cod, unit, year, sex) |> indicators()
# DANE's own abridged life tables by period, for comparison
dane_e0 <- dane_lt |> inner_join(dane_names |> select(cod, unit, area), by = "area") |>
  arrange(cod, mid, sex, age) |> group_by(cod, unit, year = mid, sex) |> rename(mx = nmx) |> indicators() |>
  mutate(series = factor("DANE (tablas abreviadas por quinquenio)"))
summ <- bind_rows(summ, dane_e0) |> arrange(series, cod, year, sex)
write_csv(summ, "output/tables/dept_mortality_adjusted_summary.csv")

cat("\ne0 adjusted, registered and DANE, 2015-2020 (DANE) against 2017 (ours), men:\n")
print(bind_rows(summ |> filter(series != "DANE (tablas abreviadas por quinquenio)", year == 2017, sex == "m"),
                summ |> filter(series == "DANE (tablas abreviadas por quinquenio)", year == 2017.5, sex == "m")) |>
        transmute(unit, series = c("Ajustada por componentes" = "ajustada", "Registradas" = "registrada", "DANE (tablas abreviadas por quinquenio)" = "dane")[as.character(series)], e0 = round(e0, 1)) |>
        pivot_wider(names_from = series, values_from = e0) |> mutate(aj_menos_dane = round(ajustada - dane, 1)) |> arrange(ajustada) |> as.data.frame())

# sum of departments against the national adjusted series (WPP population there, DANE here)
nat_adj <- read_csv("output/tables/mortality_adjusted_components_1950-2023.csv", show_col_types = FALSE) |>
  filter(year %in% years) |>
  summarise(nat_total = sum(mx_total * pop), nat_natural = sum(mx_natural * pop), nat_violent = sum(mx_violent * pop), nat_pop = sum(pop), .by = c(year, sex))
cmp <- adj |> summarise(dep_total = sum(mx_total * pop), dep_natural = sum(mx_natural * pop), dep_violent = sum(mx_violent * pop), dep_registered = sum(registered), dep_pop = sum(pop), .by = c(year, sex)) |>
  inner_join(nat_adj, by = c("year", "sex")) |>
  mutate(ratio_total = dep_total / nat_total, ratio_natural = dep_natural / nat_natural, ratio_violent = dep_violent / nat_violent, ratio_pop = dep_pop / nat_pop)
write_csv(cmp, "output/tables/dept_vs_national_adjusted_deaths.csv")
cat("\nsum of departments / national adjusted series (deaths; population DANE / WPP):\n")
print(cmp |> filter(year %in% c(1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020, 2023)) |>
        transmute(year, sex, dep_total = round(dep_total / 1e3, 1), nat_total = round(nat_total / 1e3, 1), ratio_total = round(ratio_total, 3),
                  ratio_natural = round(ratio_natural, 3), ratio_violent = round(ratio_violent, 3), ratio_pop = round(ratio_pop, 3)) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ord <- summ |> filter(series == "Ajustada por componentes", year == 2019, sex == "m") |> arrange(e0) |> pull(unit)
cols <- c("Ajustada por componentes" = "#1f5fa6", "Registradas" = "#7a7a7a", "DANE (tablas abreviadas por quinquenio)" = "#d6641a")
p <- summ |> mutate(unit = factor(unit, ord), sexo = lab_sex(sex)) |>
  ggplot(aes(year, e0, colour = series)) +
  geom_line(data = function(x) filter(x, series != "DANE (tablas abreviadas por quinquenio)"), linewidth = 0.6) +
  geom_point(data = function(x) filter(x, series == "DANE (tablas abreviadas por quinquenio)"), size = 1.4) +
  facet_grid(sexo ~ unit, labeller = labeller(unit = label_wrap_gen(14))) +
  scale_colour_manual(values = cols, name = NULL) +
  scale_x_continuous(breaks = c(1990, 2010)) +
  coord_cartesian(ylim = c(55, 95)) +
  labs(x = NULL, y = "Esperanza de vida al nacer (años)",
       title = "Esperanza de vida al nacer por departamento, 1985-2023: serie ajustada por componentes, registro y DANE",
       subtitle = "Departamentos ordenados por la e0 ajustada de los hombres en 2019; Amazonas, Guainía, Guaviare, Vaupés y Vichada agrupados. Eje recortado en 55-95 (Tolima 1985 con Armero y los registros de Chocó y Amazonía quedan fuera)") +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), strip.text.x = element_text(size = 6.5))
ggsave("figures/07_departments/dept_e0_adjusted.png", p, width = 20, height = 6, bg = "white", dpi = 150)

p <- cc |> left_join(names_tab, by = "cod") |> mutate(unit = factor(unit, ord), sexo = lab_sex(sex)) |>
  ggplot(aes(year)) +
  geom_point(aes(y = c_annual, colour = sexo), size = 0.5, alpha = 0.5) +
  geom_line(aes(y = c_model, colour = sexo), linewidth = 0.4, linetype = "22") +
  geom_line(aes(y = c, colour = sexo), linewidth = 0.7) +
  facet_wrap(~ unit, ncol = 10, labeller = label_wrap_gen(16)) +
  scale_colour_manual(values = c(Hombres = "#1f5fa6", Mujeres = "#d6641a"), name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) + scale_x_continuous(breaks = c(1990, 2010)) +
  labs(x = NULL, y = "Completitud del registro de defunciones no violentas",
       title = "Completitud aplicada por departamento: Adair-Lopez modelo 1 anual (puntos), suavizada (punteada) y calibrada a la serie nacional (línea)",
       subtitle = "Suavizado sobre 1985-2019 y mantenido desde 2020; la omisión departamental se escala para que la suma de los departamentos iguale la serie nacional") +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/07_departments/dept_completeness_applied.png", p, width = 14, height = 6, bg = "white", dpi = 150)

shares <- adj |> filter(year == 2000) |>
  summarise(across(c(mx_natural, mx_other_external, mx_violent), function(v) sum(v * pop)), registered = sum(registered), .by = c(unit, sex)) |>
  mutate(total = mx_natural + mx_other_external + mx_violent, added = total - registered) |>
  pivot_longer(c(mx_natural, mx_other_external, mx_violent), names_to = "component", values_to = "deaths") |>
  mutate(component = factor(component, c("mx_violent", "mx_other_external", "mx_natural"), c("Violenta (con MSE)", "Otras externas", "Natural")),
         unit = factor(unit, ord), sexo = lab_sex(sex))
p <- ggplot(shares, aes(deaths / total, unit, fill = component)) +
  geom_col(width = 0.8) +
  facet_wrap(~ sexo) +
  scale_fill_manual(values = c("#d6641a", "#9ecae1", "#1f5fa6"), name = NULL) +
  scale_x_continuous(labels = scales::percent) +
  labs(x = "Participación en las defunciones ajustadas, 2000", y = NULL,
       title = "Composición de la mortalidad ajustada por departamento en 2000") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/07_departments/dept_components_2000.png", p, width = 10, height = 7, bg = "white", dpi = 150)

p <- cmp |> select(year, sex, ratio_total, ratio_natural, ratio_violent, ratio_pop) |>
  pivot_longer(-c(year, sex), names_to = "what", values_to = "ratio") |>
  mutate(what = factor(what, c("ratio_total", "ratio_natural", "ratio_violent", "ratio_pop"),
                       c("Defunciones ajustadas", "Naturales", "Violentas", "Población (DANE / WPP)")), sexo = lab_sex(sex)) |>
  ggplot(aes(year, ratio, colour = what)) +
  geom_hline(yintercept = 1, colour = "grey60") + geom_line(linewidth = 0.7) +
  facet_wrap(~ sexo) +
  scale_colour_manual(values = c("#1f5fa6", "#7a7a7a", "#d6641a", "#2a9d8f"), name = NULL) +
  labs(x = NULL, y = "Suma de departamentos / serie nacional",
       title = "Suma de los departamentos frente a la serie nacional ajustada",
       subtitle = "Las tasas departamentales usan la población DANE; la serie nacional, la de WPP 2024") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/07_departments/dept_sum_vs_national.png", p, width = 10, height = 4.5, bg = "white", dpi = 150)
cat("written: output/tables/dept_mortality_adjusted_*.csv, figures/07_departments/\n")
