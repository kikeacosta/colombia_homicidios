# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 53. Violent deaths by department, 1923-2023: level from the registry and
#     the external sources, sex ratio only to fill the cause gaps
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Design (after 52: the registered sex ratio does not see the deaths the
# registry never recorded, so it cannot estimate under-registration; it can
# only distribute a level that comes from elsewhere and fill the years and
# departments where deaths are registered by sex but not by cause).
#
# units  the departments of 1985 (24, Bogotá separate), the territories that
#        became departments in 1991 (Arauca, Casanare, Putumayo, San Andrés,
#        the five Amazon ones as "9X") and, before 1985, the territories as
#        one unit "TN" (intendencias y comisarías of the anuarios, Caquetá
#        included until 1981). Boundaries are those of each year: before a
#        department existed its deaths sit in the parent (Córdoba in Bolívar
#        until 1952, Meta in TN until 1959, Guajira and Cesar in Magdalena
#        until 1965/67, Sucre in Bolívar until 1966, Quindío and Risaralda in
#        Caldas until 1966, Bogotá in Cundinamarca until 1956 in the deaths
#        and until 1962 in the homicides, Casanare in Boyacá until 1973)
#
# registered violent deaths (EEVV concept: homicide, undetermined intent,
# legal intervention; the anuarios' "homicidios" before 1979)
#   1923-1965   anuarios DANE by department (col_gap_analysis, 33 years,
#               10-20 departments with data)
#   1966-1978   no departmental cause table on disk: imputed, and the
#               imputations rescaled to the national registered violent
#               deaths of the year (27)
#   1979-2023   EEVV microdata (deaths_munic_age_1979-2023.rds), the
#               territories folded into TN until 1984; 1979 lacks
#               Caldas, Quindío, Risaralda, Santander and Norte de Santander
#               entirely: imputed
# deaths by sex  anuarios 1915-1984 by department (67 years), EEVV 1979-2023
#
# cause-gap model  binomial GLMM of the registered violent share of all
#   registered deaths on the log sex ratio of all-cause registered deaths,
#   a spline in year and a department random intercept, fitted on the
#   department-years with both (anuarios 1923-1965, EEVV 1979-2023), used to
#   impute the registered violent deaths where only deaths by sex exist.
#   Where the anuario gives deaths without sex (1934, 1939, 1950) the violent
#   share of the unit is interpolated between its neighbouring years.
#
# double counts in the anuarios, removed here (checked against the national
# registered deaths of 22: the sum of the units is then 1.00 of the national)
#   - the territories listed on their own before 1982 are already in the
#     intendencias y comisarías line; Meta too until 1959
#   - Bogotá's deaths 1956-1961 are listed and also inside Cundinamarca's;
#     its homicides stay inside Cundinamarca's until 1961: they are split
#     between the two with Bogotá's deaths and the ratio of violent shares
#     of 1962-1965; before 1956 Bogotá's homicides (1936-1939) go to
#     Cundinamarca, where its deaths are
#
# external level
#   police      Policía Nacional homicides 1962-2002 by jurisdiction, mapped
#               to departments (the metropolitan areas to Bogotá, Valle and
#               Antioquia, Urabá to Antioquia, intendencias and comisarías to
#               TN); a floor of the registered (or imputed) violent deaths
#   MSE         conflict deaths missing from the violent component by
#               department 1985-2018 (51), added
#   national    1950-2023 the departments are calibrated to the national
#               adjusted violent deaths of 42 plus the police and La
#               Violencia extras of 47 (the national series carries the
#               floors by Romero-Prieto and Meisel-Roca, who give no
#               departmental counts): level = national x department share,
#               share = max(registered or imputed + MSE, police). Before 1950
#               there is no national series: the departmental sum is the
#               level, from the registry alone
#
# output: output/tables/dept_violent_deaths_series_1923-2023.csv
#         output/tables/dept_violent_deaths_causegap_model.csv
#         figures/07_departments/dept_violent_series.png
#         figures/07_departments/dept_violent_causegap_fit.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(splines)
dir.create("figures/07_departments", showWarnings = FALSE)

amazon <- c("91", "94", "95", "97", "99")
territories <- c("81", "85", "86", "88", amazon, "18")   # 18 Caquetá: intendencia until 1981
unit_of <- function(cod) if_else(cod %in% amazon, "9X", cod)
code_of <- c(amazonas = "91", antioquia = "05", arauca = "81", atlantico = "08", bogota = "11", `bogota d.e.` = "11", bolivar = "13", boyaca = "15",
             caldas = "17", caqueta = "18", casanare = "85", cauca = "19", cesar = "20", choco = "27", cordoba = "23", cundinamarca = "25",
             `cundinamarca sin bogota` = "25", guainia = "94", guaviare = "95", huila = "41", la_guajira = "44", magdalena = "47", meta = "50",
             narino = "52", norte_de_santander = "54", putumayo = "86", quindio = "63", risaralda = "66", san_andres_y_providencia = "88",
             santander = "68", sucre = "70", tolima = "73", valle_del_cauca = "76", vaupes = "97", vichada = "99",
             intendencias_y_comisarias = "TN", intendencias = "TN", comisarias = "TN")
norm_name <- function(x) { x <- tolower(x); x <- gsub(" ", "_", x); x <- sub("^cundinamarca_sin_bogota$", "cundinamarca sin bogota", x); x <- sub("^bogota_d.e.$", "bogota d.e.", x); x }
unit_names <- c("05" = "Antioquia", "08" = "Atlántico", "11" = "Bogotá", "13" = "Bolívar", "15" = "Boyacá", "17" = "Caldas", "18" = "Caquetá", "19" = "Cauca",
                "20" = "Cesar", "23" = "Córdoba", "25" = "Cundinamarca", "27" = "Chocó", "41" = "Huila", "44" = "La Guajira", "47" = "Magdalena", "50" = "Meta",
                "52" = "Nariño", "54" = "Norte de Santander", "63" = "Quindío", "66" = "Risaralda", "68" = "Santander", "70" = "Sucre", "73" = "Tolima",
                "76" = "Valle del Cauca", "81" = "Arauca", "85" = "Casanare", "86" = "Putumayo", "88" = "San Andrés", "9X" = "Amazonía (5 deptos)", "TN" = "Territorios nacionales")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# registered deaths by sex and registered violent deaths, by unit and year ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# anuarios: deaths by sex 1915-1984
an_d <- read_delim("data_input/historical/col_gap_analysis_1920_1985_department_deaths_clean_v06.csv", delim = ";", show_col_types = FALSE) |>
  filter(!is.na(total)) |>
  transmute(cod = unname(code_of[norm_name(department)]), year, d = total, d_m = male, d_f = female, src_d = "anuario")
stopifnot(!anyNA(an_d$cod))
# territories: in the years with an intendencias y comisarías line the territories listed on their own
# (and Meta until 1959) are inside it and are dropped; without the line they are summed into TN
in_tn <- function(cod, year) (cod %in% territories & year < 1982) | (cod == "50" & year < 1960)
fold_tn <- function(df, vars) {
  has_tn <- df |> filter(cod == "TN") |> distinct(year) |> mutate(has_tn = TRUE)
  df <- df |> left_join(has_tn, by = "year") |> mutate(has_tn = replace_na(has_tn, FALSE), listed = in_tn(cod, year))
  bind_rows(df |> filter(!listed),
            df |> filter(listed, !has_tn) |> mutate(cod = "TN") |> summarise(across(all_of(vars), ~ if (all(is.na(.x))) NA_real_ else sum(.x, na.rm = TRUE)), .by = c(cod, year))) |>
    select(-has_tn, -listed)
}
an_d <- fold_tn(an_d, c("d", "d_m", "d_f")) |> mutate(src_d = "anuario")
# Bogotá listed and also inside Cundinamarca's deaths 1956-1961: take it out of Cundinamarca (sexes in proportion)
bog_in_cund_d <- an_d |> filter(cod == "11") |> pull(year) |> min()
bog_cund_years <- an_d |> filter(cod == "11", year < 1962) |> pull(year)
bog_d <- an_d |> filter(cod == "11", year %in% bog_cund_years) |> select(year, d11 = d)
an_d <- an_d |> left_join(bog_d, by = "year") |>
  mutate(k = if_else(cod == "25" & !is.na(d11), (d - d11) / d, 1), d = d * k, d_m = d_m * k, d_f = d_f * k) |> select(-d11, -k)
an_h <- read_csv("data_input/historical/col_gap_analysis_1920_1985_department_homicides_clean_v02.csv", show_col_types = FALSE) |>
  filter(!is.na(total)) |>
  transmute(cod = unname(code_of[norm_name(department)]), year, v = total, v_m = male, v_f = female, dept_raw = department, src_v = "anuario")
stopifnot(!anyNA(an_h$cod))
# Cundinamarca: when "CUNDINAMARCA" (with Bogotá) and BOGOTA both appear, keep the split pair;
# before 1956 Bogotá's deaths are inside Cundinamarca's, so its homicides go there too
an_h <- an_h |> group_by(year) |>
  filter(!(dept_raw == "CUNDINAMARCA" & any(dept_raw == "CUNDINAMARCA SIN BOGOTA"))) |> ungroup() |>
  mutate(cod = if_else(cod == "11" & year < bog_in_cund_d, "25", cod)) |>
  summarise(v = sum(v), v_m = sum(v_m), v_f = sum(v_f), .by = c(cod, year))
an_h <- fold_tn(an_h, c("v", "v_m", "v_f")) |> mutate(src_v = "anuario")
# 1956-1961: Cundinamarca's homicides include Bogotá's. Split with the deaths of each and the ratio of
# their violent shares in 1962-1965 (Bogotá's share per death relative to Cundinamarca's)
r_bog <- an_h |> filter(year %in% 1962:1965, cod %in% c("11", "25")) |> inner_join(an_d |> select(cod, year, d), by = c("cod", "year")) |>
  mutate(s = v / d) |> summarise(r = s[cod == "11"] / s[cod == "25"], .by = year) |> pull(r) |> mean()
split_bog <- an_h |> filter(cod == "25", year %in% bog_cund_years) |>
  inner_join(an_d |> filter(cod %in% c("11", "25"), year %in% bog_cund_years) |> select(cod, year, d) |> pivot_wider(names_from = cod, values_from = d, names_prefix = "d"), by = "year") |>
  mutate(w11 = r_bog * d11 / (r_bog * d11 + d25)) |>
  reframe(cod = c("11", "25"), v = v * c(w11, 1 - w11), v_m = v_m * c(w11, 1 - w11), v_f = v_f * c(w11, 1 - w11), src_v = "anuario, Bogotá separada de Cundinamarca", .by = year)
an_h <- bind_rows(an_h |> anti_join(split_bog, by = c("cod", "year")), split_bog)
cat(sprintf("Bogotá's violent share per death relative to Cundinamarca's, 1962-1965: %.2f; Bogotá's share of the joint homicides 1956-1961: %s\n",
            r_bog, paste(round(split_bog$v[split_bog$cod == "11"] / (split_bog$v[split_bog$cod == "11"] + split_bog$v[split_bog$cod == "25"]), 2), collapse = " ")))
# EEVV 1979-2023
ee <- read_rds("data_inter/deaths_munic_age_1979-2023.rds") |>
  mutate(cod = sprintf("%02d", cod_dpto),
         cod = case_when(year < 1985 & (cod == "83" | (cod %in% territories & !(cod == "18" & year >= 1982))) ~ "TN",   # 83: Caquetá before 1982
                         year >= 1985 & cod %in% amazon ~ "9X", TRUE ~ cod)) |>
  summarise(d = sum(dx_tot), v = sum(dx_v), .by = c(cod, year, sex))
ee_u <- ee |> summarise(d = sum(d), v = sum(v), .by = c(cod, year)) |>
  left_join(ee |> filter(sex %in% c("m", "f")) |> select(cod, year, sex, d, v) |> pivot_wider(names_from = sex, values_from = c(d, v)), by = c("cod", "year")) |>
  mutate(src_d = "EEVV", src_v = "EEVV")
# 1979: departments entirely absent from the microdata are not zero
missing79 <- setdiff(c(sprintf("%02d", c(5, 8, 11, 13, 15, 17, 19, 20, 23, 25, 27, 41, 44, 47, 50, 52, 54, 63, 66, 68, 70, 73, 76))), ee_u$cod[ee_u$year == 1979 & ee_u$d > 100])
cat("departments absent from the 1979 microdata:", paste(unit_names[missing79], collapse = ", "), "\n")
ee_u <- ee_u |> filter(!(year == 1979 & cod %in% missing79))

# the panel: EEVV where it exists, anuarios otherwise (1979 of the five absent departments from the anuarios)
panel <- bind_rows(ee_u, an_d |> anti_join(ee_u, by = c("cod", "year")) |> left_join(an_h, by = c("cod", "year"))) |>
  { \(p) { stopifnot(all(p$cod %in% names(unit_names))); p } }() |>
  mutate(unit = unit_names[cod]) |>
  arrange(cod, year)
# check: anuario sum of units against the national registered deaths of 22 (scaled to the anuario totals)
nat_reg <- read_rds("data_inter/deaths_age_annual_1938-2023.rds") |> summarise(nat = sum(dx), .by = year)
chk <- panel |> filter(src_d == "anuario") |> summarise(units = sum(d), tn_line = sum(d[cod == "TN"]), n_units = n(), .by = year) |>
  inner_join(nat_reg, by = "year") |> mutate(ratio = units / nat)
cat("\nanuario deaths after removing the double counts, sum of units / national registered (22):\n")
print(chk |> filter(year %in% c(1938, 1945, 1951, 1956, 1958, 1961, 1964, 1970, 1975, 1978, 1979)) |> mutate(ratio = round(ratio, 3)) |> as.data.frame())
stopifnot(abs(chk$ratio[chk$year %in% 1938:1978] - 1) < 0.02)   # 1979: only the five departments absent from the microdata

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cause-gap model ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
fitd <- panel |> filter(!is.na(v), !is.na(d_m), !is.na(d_f), d_m > 0, d_f > 0, d > v, v >= 0) |>
  mutate(across(c(d, v), round), lsr = log(d_m / d_f), era = if_else(year < 1970, "anuario", "EEVV"))
m_cg <- glmmTMB(cbind(v, d - v) ~ lsr + ns(year, df = 4) + (1 | cod), data = fitd, family = binomial())
co <- summary(m_cg)$coefficients$cond
cat(sprintf("\ncause-gap model on %d department-years: log sex ratio coefficient %.2f (se %.2f); department sd %.2f\n",
            nrow(fitd), co["lsr", 1], co["lsr", 2], sqrt(VarCorr(m_cg)$cond$cod[1])))
fitd <- fitd |> mutate(share_hat = predict(m_cg, type = "response"), v_hat = share_hat * d)
r2 <- fitd |> summarise(cor_log = cor(log1p(v), log1p(v_hat)), .by = era)
cat("correlation of log registered and log fitted violent deaths by era:\n"); print(as.data.frame(r2))
write_csv(as_tibble(co, rownames = "term") |> transmute(term, estimate = Estimate, se = `Std. Error`), "output/tables/dept_violent_deaths_causegap_model.csv")
# impute where deaths by sex exist but violent deaths do not
imp <- panel |> filter(is.na(v), !is.na(d_m), !is.na(d_f), d_m > 0, d_f > 0) |> mutate(lsr = log(d_m / d_f)) |>
  mutate(v_imp = predict(m_cg, newdata = pick(everything()), type = "response", allow.new.levels = TRUE) * d) |> select(cod, year, v_imp)
# 1966-1978: every unit is imputed and the model, interpolating between the anuario and EEVV eras, runs
# 10-30 % above the national registered violent deaths (27): rescale the imputations of those years to it
nat_reg_v <- read_csv("output/tables/deaths_components_registered_1950-2023.csv", show_col_types = FALSE) |> summarise(nat_v = sum(violent), .by = year)
all_imp_years <- panel |> summarise(all_imp = all(is.na(v)), .by = year) |> filter(all_imp) |> pull(year)
imp <- imp |> left_join(nat_reg_v, by = "year") |>
  mutate(k = if_else(year %in% all_imp_years & !is.na(nat_v), nat_v / sum(v_imp), 1), .by = year)
cat("\nyears with every unit imputed, rescaling factor to the national registered violent deaths:\n")
print(imp |> filter(year %in% all_imp_years, !is.na(nat_v)) |> summarise(sum_model = round(sum(v_imp)), national = round(first(nat_v)), k = round(first(k), 2), .by = year) |> as.data.frame())
imp <- imp |> mutate(v_imp = v_imp * k, rescaled = k != 1) |> select(cod, year, v_imp, rescaled)
panel <- panel |> left_join(imp, by = c("cod", "year")) |>
  mutate(v_use = coalesce(v, v_imp),
         method_v = case_when(!is.na(v) ~ src_v, !is.na(v_imp) & rescaled ~ "imputada (cociente de sexo, reescalada al nacional)",
                              !is.na(v_imp) ~ "imputada (cociente de sexo)", TRUE ~ NA_character_))
# deaths without sex (anuario 1934, 1939, 1950): the unit's violent share interpolated between its neighbouring years
panel <- panel |> arrange(cod, year) |>
  mutate(share_int = if (sum(!is.na(v_use)) >= 2) approx(year[!is.na(v_use)], (v_use / d)[!is.na(v_use)], xout = year, rule = 1)$y else NA_real_, .by = cod) |>
  mutate(v_imp = if_else(is.na(v_use) & !is.na(d) & !is.na(share_int), share_int * d, v_imp),
         method_v = if_else(is.na(v_use) & !is.na(d) & !is.na(share_int), "imputada (proporción violenta interpolada)", method_v),
         v_use = coalesce(v_use, v_imp)) |> select(-share_int, -rescaled)
cat(sprintf("\nviolent deaths: %d unit-years registered, %d imputed with the sex ratio (%d of them rescaled), %d by interpolation of the share, %d left empty\n",
            sum(!is.na(panel$v)), sum(grepl("cociente", panel$method_v)), sum(grepl("reescalada", panel$method_v)), sum(grepl("interpolada", panel$method_v)), sum(is.na(panel$v_use))))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# external level: police, MSE, national calibration ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pol_map <- c(Amazonas = "91", Antioquia = "05", Arauca = "81", Atlántico = "08", Bolívar = "13", Boyacá = "15", Caldas = "17", Caquetá = "18", Cauca = "19",
             Casanare = "85", Cesar = "20", Córdoba = "23", Cundinamarca = "25", Chocó = "27", Guajira = "44", Guainía = "94", Guaviare = "95", Magdalena = "47",
             Meta = "50", Nariño = "52", `Norte de Santander` = "54", Putumayo = "86", Quindío = "63", Risaralda = "66", Santander = "68", `San Andrés` = "88",
             Sucre = "70", Tolima = "73", Huila = "41", Urabá = "05", Valle = "76", Vaupés = "97", Vichada = "99", `Metropolitana Bogotá` = "11",
             `Metropolitana Cali` = "76", `Metropolitana Medellín` = "05", Comisarías = "TN", Intendencias = "TN")
police <- read_excel("data_input/historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx", sheet = 1) |>
  filter(Jurisdiccion %in% names(pol_map)) |>
  pivot_longer(-Jurisdiccion, names_to = "year", values_to = "n") |>
  transmute(cod = unname(pol_map[Jurisdiccion]), year = as.integer(year), n) |>
  summarise(police = sum(n), .by = c(cod, year))
# before 1985 the territories are one unit also in the police counts; from 1985 they are separate and TN is their sum
police <- police |> mutate(cod = if_else(year < 1985 & cod %in% territories & !(cod == "18" & year >= 1982), "TN", cod)) |>
  summarise(police = sum(police), .by = c(cod, year))
mse <- read_csv("output/tables/mse_departments_1985-2018.csv", show_col_types = FALSE, col_types = cols(cod = "c")) |>
  summarise(mse = sum(mse_added), .by = c(cod, year))
series <- panel |>
  left_join(police, by = c("cod", "year")) |> left_join(mse, by = c("cod", "year")) |>
  mutate(mse = replace_na(mse, 0), base = pmax(v_use + mse, police, na.rm = TRUE),
         floor_police = !is.na(police) & !is.na(v_use) & police > v_use + mse)
# national: adjusted violent deaths (42, with the MSE) plus the police and La Violencia extras (47)
nat <- read_csv("output/tables/mortality_adjusted_components_1950-2023.csv", show_col_types = FALSE) |>
  summarise(nat_violent = sum(mx_violent * pop), .by = year) |>
  left_join(read_csv("output/tables/crisis_deaths_1950-2023.csv", show_col_types = FALSE) |> summarise(nat_extra = sum(police + violencia), .by = year), by = "year") |>
  mutate(nat_total = nat_violent + nat_extra)
series <- series |> left_join(nat, by = "year") |>
  mutate(sum_base = sum(base, na.rm = TRUE), .by = year) |>
  mutate(level = if_else(!is.na(nat_total), nat_total * base / sum_base, base),
         calibrated = !is.na(nat_total),
         method = case_when(is.na(base) ~ "sin dato",
                            calibrated & floor_police ~ "piso Policía, calibrado al nacional",
                            calibrated & mse > 0 ~ "EEVV + MSE",
                            calibrated ~ paste0(method_v, ", calibrado al nacional"),
                            TRUE ~ method_v)) |>
  select(cod, unit, year, deaths = d, deaths_m = d_m, deaths_f = d_f, violent_registered = v, violent_imputed = v_imp, violent_used = v_use,
         police, mse, base, national_total = nat_total, level, calibrated, method) |>
  arrange(cod, year)
# annual national ratio before calibration: how far the departments' sum is from the national series
cat("\nsum of the departments' base (registered or imputed + MSE, police floor) / national series, selected years:\n")
print(series |> filter(calibrated) |> summarise(n_units = sum(!is.na(base)), sum_base = round(sum(base, na.rm = TRUE)), national = round(first(national_total)), ratio = round(sum_base / national, 2), .by = year) |>
        filter(year %in% c(1950, 1955, 1958, 1962, 1965, 1970, 1975, 1979, 1980, 1985, 1990, 2000, 2010, 2020, 2023)) |> as.data.frame())
write_csv(series, "output/tables/dept_violent_deaths_series_1923-2023.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lab_m <- function(m) case_when(grepl("piso Policía", m) ~ "Piso Policía", grepl("MSE", m) ~ "EEVV + MSE", grepl("interpolada", m) ~ "Imputada (proporción interpolada)", grepl("imputada", m) ~ "Imputada (cociente de sexo)",
                               grepl("EEVV", m) ~ "EEVV", grepl("anuario", m) ~ "Anuario", TRUE ~ "Sin dato")
ord <- series |> filter(year == 2000) |> arrange(-level) |> pull(unit)
p <- series |> filter(!is.na(level)) |> mutate(unit = factor(unit, c(ord, setdiff(unique(series$unit), ord))), src = lab_m(method)) |>
  ggplot(aes(year, level / 1e3)) +
  geom_line(colour = "grey75", linewidth = 0.4) +
  geom_point(aes(colour = src), size = 0.9) +
  geom_line(aes(y = police / 1e3), colour = "black", linetype = "22", linewidth = 0.35, na.rm = TRUE) +
  facet_wrap(~ unit, ncol = 6, scales = "free_y") +
  scale_colour_manual(values = c("Anuario" = "#7a7a7a", "EEVV" = "#1f5fa6", "EEVV + MSE" = "#d6641a", "Imputada (cociente de sexo)" = "#2a9d8f", "Imputada (proporción interpolada)" = "#8ab17d", "Piso Policía" = "#c51b7d"), name = NULL) +
  scale_x_continuous(breaks = seq(1930, 2020, 30)) +
  labs(x = NULL, y = "Muertes violentas (miles)",
       title = "Muertes violentas por departamento, 1923-2023: nivel calibrado a la serie nacional desde 1950",
       subtitle = "Puntos: fuente del dato departamental; línea punteada negra: homicidios de la Policía (1962-2002). Fronteras del año: los departamentos nuevos están en el padre antes de crearse") +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/07_departments/dept_violent_series.png", p, width = 15, height = 10, bg = "white", dpi = 150)

p <- fitd |> ggplot(aes(v_hat, v, colour = era)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey50", linetype = "22") +
  geom_point(size = 0.8, alpha = 0.6) +
  scale_x_log10() + scale_y_log10() +
  scale_colour_manual(values = c(anuario = "#7a7a7a", EEVV = "#1f5fa6"), name = NULL) +
  labs(x = "Violentas ajustadas por el modelo (cociente de sexo, año, departamento)", y = "Violentas registradas",
       title = "Modelo de huecos de causa: violentas registradas frente a las ajustadas, departamento-año") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom")
ggsave("figures/07_departments/dept_violent_causegap_fit.png", p, width = 7, height = 6, bg = "white", dpi = 150)
cat("written: output/tables/dept_violent_deaths_series_1923-2023.csv, figures/07_departments/dept_violent_*.png\n")
