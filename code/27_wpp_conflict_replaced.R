# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 27. WPP 2024 with its conflict mortality replaced by the MSE estimates
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# WPP 2024 builds its mortality as a crisis-free life table plus crisis
# components added on top (26 checks that mx_total - mx_crises_free equals
# mx_crises exactly). Its conflict component for Colombia is small: about
# 12,000 deaths a year for La Violencia (1950-1956, Valentino 2004), then
# UCDP/PRIO battle deaths, roughly 1,000 a year in 1987-1999 and 2,500-4,700
# in 2000-2008, and a flat ~500 a year afterwards; about 65,000 deaths over
# 1985-2018 against 618,000 conflict homicides and 127,000 enforced
# disappearances in the JEP-CEV-HRDAG multiple-systems estimates (21).
#
# Here the WPP conflict component is removed and the MSE-based correction of
# 23 is added instead:
#   expected = (mx_WPP - mx_conflict_WPP) x pop_WPP
#              + max(MSE homicides - EEVV violent deaths, 0) + disappearances
# The WPP baseline is itself an estimate of complete mortality (it already
# assumes incomplete registration), and the registered conflict homicides
# are inside it through the registry; only the conflict deaths the registry
# missed are added, as in 23. Disasters (Armero 1985) and COVID-19 stay in,
# because the registry does capture them.
#
# The implied completeness of the registry is registered / expected, by
# year, sex and age group; it is compared with the completeness implied by
# WPP as published and with the DDM of 23.
#
# output: output/tables/deaths_expected_wpp_mse_1950-2023.csv
#           (year, sex, age, registered, wpp_total, wpp_conflict, mse_added,
#            expected, completeness)
#         output/tables/completeness_wpp_mse_annual.csv (15-64, by sex)
#         figures/04_completeness/wpp_conflict_vs_mse.png
#         figures/04_completeness/completeness_wpp_mse.png
#         figures/04_completeness/mx_wpp_mse_men.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

age_top <- 80
grp5 <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), age_top))
sexes <- c(male = "m", female = "f")

wpp <-
  read_rds("data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds") |>
  filter(year <= 2023) |>
  select(year, sex, age, pop, mx)

conf <-
  read_csv("data_input/reference/wpp2024_crises_colombia_mx1_conflicts.csv", show_col_types = FALSE) |>
  transmute(year = Year, sex = sexes[Sex], age = age_start, mx_conflict = value) |>
  filter(!is.na(sex))

# single ages -> 5-year groups, deaths
wpp5 <-
  wpp |>
  left_join(conf, by = c("year", "sex", "age")) |>
  replace_na(list(mx_conflict = 0)) |>
  mutate(age5 = grp5(age), d_total = mx * pop, d_conflict = mx_conflict * pop) |>
  summarise(pop = sum(pop), wpp_total = sum(d_total), wpp_conflict = sum(d_conflict), .by = c(year, sex, age5)) |>
  rename(age = age5)

# registered deaths (22) and the MSE additions of 23 (excess homicides over
# EEVV violent deaths, plus disappearances), by year, sex and age group
deaths <- read_rds("data_inter/deaths_age_annual_1938-2023.rds") |> select(year, sex, age, registered = dx)

mse <- read_rds("data_inter/conflict_mse_age5_1985-2018.rds") |>
  mutate(known = !age %in% c(0, 85)) |>
  mutate(across(c(mean, q025, q975), \(v) if_else(known, v * sum(v) / sum(v[known]), 0)), .by = c(violation, year, sex)) |>
  filter(known) |> mutate(age = pmin(age, age_top)) |>
  summarise(across(c(mean, q025, q975), sum), .by = c(violation, year, sex, age))
dxv <- read_rds("data_inter/deaths_munic_age_1979-2023.rds") |>
  filter(sex %in% c("m", "f"), !is.na(age)) |> mutate(age = pmin(age, age_top)) |>
  summarise(dx_v = sum(dx_v), .by = c(year, sex, age))
added <-
  mse |> filter(violation == "hom") |>
  left_join(dxv, by = c("year", "sex", "age")) |>
  left_join(mse |> filter(violation == "dsp") |> select(year, sex, age, dsp = mean), by = c("year", "sex", "age")) |>
  replace_na(list(dsp = 0)) |>
  transmute(year, sex, age, mse_hom = mean, hom_excess = pmax(mean - dx_v, 0), dsp, mse_added = hom_excess + dsp)

exp <-
  wpp5 |>
  left_join(deaths, by = c("year", "sex", "age")) |>
  left_join(added, by = c("year", "sex", "age")) |>
  replace_na(list(mse_hom = 0, hom_excess = 0, dsp = 0, mse_added = 0)) |>
  mutate(expected = wpp_total - wpp_conflict + mse_added,
         completeness = registered / expected,
         completeness_wpp = registered / wpp_total) |>
  arrange(year, sex, age)
write_csv(exp |> select(year, sex, age, pop, registered, wpp_total, wpp_conflict, mse_hom, hom_excess, dsp, mse_added, expected, completeness),
          "output/tables/deaths_expected_wpp_mse_1950-2023.csv")

cat("WPP conflict deaths against the MSE, both sexes (thousands):\n")
yr <- exp |> summarise(across(c(registered, wpp_total, wpp_conflict, mse_hom, hom_excess, dsp, expected), sum), .by = year) |>
  mutate(pct_conflict_wpp = 100 * wpp_conflict / wpp_total, pct_added = 100 * (mse_hom + dsp) / expected)
print(yr |> filter(year %in% c(1950, 1955, 1960, 1970, 1980, seq(1985, 2020, 5), 2002, 2023)) |> arrange(year) |>
        mutate(across(-c(year, starts_with("pct")), \(v) round(v / 1e3, 1)), across(starts_with("pct"), \(v) round(v, 1))) |> as.data.frame())
cat("\ntotals 1985-2018 (thousands): WPP conflict", round(sum(yr$wpp_conflict[yr$year %in% 1985:2018]) / 1e3),
    "; MSE homicides", round(sum(yr$mse_hom[yr$year %in% 1985:2018]) / 1e3),
    "; of which not in EEVV violent deaths", round(sum(yr$hom_excess[yr$year %in% 1985:2018]) / 1e3),
    "; disappearances", round(sum(yr$dsp[yr$year %in% 1985:2018]) / 1e3), "\n")

# annual completeness at 15-64, WPP as published vs WPP without its conflict + MSE
ann <-
  exp |> filter(age >= 15, age < 65) |>
  summarise(registered = sum(registered), wpp_total = sum(wpp_total), expected = sum(expected), .by = c(year, sex)) |>
  mutate(`WPP 2024 publicado` = registered / wpp_total, `WPP sin conflicto + MSE` = registered / expected)
ddm <- read_csv("output/tables/completeness_ddm_conflict_annual.csv", show_col_types = FALSE) |>
  filter(variant == "migration + conflict") |> select(year, sex, `DDM (23)` = completeness)
ann <- ann |> left_join(ddm, by = c("year", "sex"))
write_csv(ann, "output/tables/completeness_wpp_mse_annual.csv")

cat("\ncompleteness at 15-64, selected years:\n")
print(ann |> filter(year %in% c(1950, 1960, 1970, 1980, 1990, 1995, 2000, 2002, 2005, 2010, 2015, 2020, 2023)) |>
        mutate(across(c(`WPP 2024 publicado`, `WPP sin conflicto + MSE`, `DDM (23)`), \(v) round(v, 3))) |>
        select(year, sex, `WPP 2024 publicado`, `WPP sin conflicto + MSE`, `DDM (23)`) |>
        pivot_wider(names_from = sex, values_from = c(`WPP 2024 publicado`, `WPP sin conflicto + MSE`, `DDM (23)`)) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lab_sex <- \(s) factor(s, c("f", "m"), c("Mujeres", "Hombres"))

# conflict deaths: WPP component vs MSE, by year and sex
exp |> filter(year >= 1980) |>
  summarise(`WPP 2024 (componente conflicto)` = sum(wpp_conflict), `MSE homicidios` = sum(mse_hom),
            `MSE homicidios no registrados como violentos` = sum(hom_excess), `MSE desapariciones` = sum(dsp), .by = c(year, sex)) |>
  pivot_longer(-c(year, sex), names_to = "serie", values_to = "deaths") |>
  mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, deaths / 1e3, col = serie)) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~sex, scales = "free_y") +
  scale_color_manual(values = c("#0A9396", "#9B2226", "#CA6702", "#4A4E69")) +
  labs(title = "Mortalidad por conflicto en Colombia: lo que WPP 2024 incorpora frente a las estimaciones MSE (JEP-CEV-HRDAG)",
       x = NULL, y = "Muertes (miles)", col = NULL) +
  theme_bw() + theme(legend.position = "bottom") + guides(col = guide_legend(nrow = 2))
ggsave("figures/04_completeness/wpp_conflict_vs_mse.png", w = 11, h = 5.5)

# completeness at 15-64
ann |>
  pivot_longer(c(`WPP 2024 publicado`, `WPP sin conflicto + MSE`, `DDM (23)`), names_to = "serie", values_to = "completeness") |>
  filter(!is.na(completeness)) |>
  mutate(sex = lab_sex(sex), serie = factor(serie, c("WPP 2024 publicado", "WPP sin conflicto + MSE", "DDM (23)"))) |>
  ggplot(aes(year, completeness, col = serie, lty = serie)) +
  geom_hline(yintercept = 1, lty = "dashed", col = "grey60") +
  geom_line(linewidth = 0.7) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("#0A9396", "#9B2226", "black")) +
  scale_linetype_manual(values = c("solid", "solid", "dotted")) +
  coord_cartesian(ylim = c(0.5, 1.1)) +
  labs(title = "Completitud implícita del registro de defunciones a 15-64, Colombia 1950-2023",
       subtitle = "Registradas / esperadas; esperadas según WPP 2024 publicado, WPP sin su componente de conflicto más MSE, y DDM (censos sin ajustar)",
       x = NULL, y = "Completitud", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/completeness_wpp_mse.png", w = 11, h = 5.5)

# men's rates in conflict years: registered, WPP, WPP without conflict + MSE
age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, a == age_top ~ age_top + 5, TRUE ~ a + 2.5)
exp |> filter(sex == "m", year %in% c(1990, 1995, 2000, 2002, 2005, 2010), age >= 10) |>
  transmute(year, x = age_mid(age), Registradas = registered / pop, `WPP 2024` = wpp_total / pop,
            `WPP sin conflicto` = (wpp_total - wpp_conflict) / pop, `WPP sin conflicto + MSE` = expected / pop) |>
  pivot_longer(-c(year, x), names_to = "serie", values_to = "mx") |>
  mutate(serie = factor(serie, c("Registradas", "WPP 2024", "WPP sin conflicto", "WPP sin conflicto + MSE"))) |>
  ggplot(aes(x, mx, col = serie, lty = serie)) +
  geom_line(linewidth = 0.6) + geom_point(size = 0.9) +
  facet_wrap(~year, nrow = 1) +
  scale_y_log10() +
  scale_color_manual(values = c("grey45", "#0A9396", "#94D2BD", "#9B2226")) +
  scale_linetype_manual(values = c("dotted", "solid", "dashed", "solid")) +
  labs(title = "Tasas de mortalidad masculina por edad en años de conflicto: registro, WPP y WPP con el conflicto reemplazado por el MSE",
       x = "Edad", y = "Tasa (escala log)", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/mx_wpp_mse_men.png", w = 14, h = 5)
