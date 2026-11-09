# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 23. DDM with a conflict-corrected numerator, and external reference series
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The DDM of 22 takes registered deaths as the numerator. Two sources of
# deaths that the registry is known to miss are added here for 1985-2018:
#
# 1. conflict homicides that vital statistics did not capture: the JEP-CEV-
#    HRDAG multiple-systems estimate of conflict homicides (21) exceeds the
#    EEVV count of ALL violent deaths (homicide + undetermined intent + legal
#    intervention, dx_v) in several years; the excess
#    max(MSE homicides - dx_v, 0), by year, sex and 5-year age group, is a
#    lower bound on homicides missing from the registry (a conflict homicide
#    registered under another cause is already in dx_v);
# 2. enforced disappearances (MSE), counted in the year of disappearance and
#    multiplied by the fraction presumed dead (1 in the central scenario).
#
# The MSE age groups run 0-4, ..., 95+. Victims of unknown age were not
# removed in the source pipeline: they sit in 0-4 and in one of the top
# groups (85-89 up to 1988, 90-94 in 1989-1993, 95+ in 1994-2000, spread
# over 85-95+ afterwards), with counts far above any plausible number of
# conflict victims at those ages (men, 1995: 1,947 homicides at 95+ against
# 17 at 80-84). The groups 0-4, 85-89, 90-94 and 95+ are therefore treated
# as unknown age and redistributed over 5-84 by year and sex.
# Scenarios: "conflict" = mean excess + all disappearances; "conflict (low)"
# = 2.5% quantile of the MSE minus dx_v, half of the disappearances.
#
# Three external series give the completeness implied by registered deaths
# against an independent set of deaths, at ages 15-64, by calendar year and
# averaged over each intercensal window: WPP 2024 (mx x population, single
# ages), DANE life tables 1985-2020 (nmx x DANE population) and LAMBdA (mx
# from the adjusted life tables x WPP population, 1950-2015). None of the
# three is a gold standard: WPP and DANE are themselves model-based, and
# LAMBdA's adjustment is a Bennett-Horiuchi correction of the same registry.
#
# output: output/tables/completeness_ddm_conflict.csv (window x sex x
#         variant, DDM estimates and the three references),
#         output/tables/completeness_ddm_conflict_annual.csv,
#         figures/04_completeness/completeness_ddm_conflict.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(DDM)

age_top <- 80
frac_dead_low <- 0.5
logit <- \(p) log(p / (1 - p))
expit <- \(x) 1 / (1 + exp(-x))

deaths <- read_rds("data_inter/deaths_age_annual_1938-2023.rds")
inp <- read_rds("data_inter/ddm_census_inputs.rds")
windows <- inp$windows
X0 <- inp$X |> filter(variant == "migration")
mse <- read_rds("data_inter/conflict_mse_age5_1985-2018.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# conflict deaths missing from the registry ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 0-4 and 85+ (unknown-age artefacts) redistributed over 5-84, then 80-84
# folded into 80+
mse <-
  mse |>
  mutate(known = !age %in% c(0, 85, 90, 95)) |>
  mutate(across(c(mean, q025, q975), \(v) if_else(known, v * sum(v) / sum(v[known]), 0)), .by = c(violation, year, sex)) |>
  filter(known) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(across(c(mean, q025, q975), sum), .by = c(violation, year, sex, age))

# EEVV violent deaths by year, sex and age group (0 and 1-4 folded into 0-4)
dxv <-
  read_rds("data_inter/deaths_munic_age_1979-2023.rds") |>
  filter(sex %in% c("m", "f"), !is.na(age)) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(dx_v = sum(dx_v), .by = c(year, sex, age))

excess <-
  mse |>
  filter(violation == "hom") |>
  left_join(dxv, by = c("year", "sex", "age")) |>
  mutate(hom_mean = pmax(mean - dx_v, 0), hom_low = pmax(q025 - dx_v, 0)) |>
  select(year, sex, age, dx_v, mse_hom = mean, hom_mean, hom_low) |>
  left_join(mse |> filter(violation == "dsp") |> select(year, sex, age, dsp = mean), by = c("year", "sex", "age")) |>
  replace_na(list(dsp = 0)) |>
  mutate(add_mean = hom_mean + dsp, add_low = hom_low + frac_dead_low * dsp)

cat("conflict deaths added to the registered numerator, by year (both sexes):\n")
print(excess |>
        summarise(across(c(dx_v, mse_hom, hom_mean, hom_low, dsp, add_mean, add_low), \(v) round(sum(v))), .by = year) |>
        left_join(deaths |> summarise(registered = round(sum(dx)), .by = year), by = "year") |>
        mutate(pct_mean = round(100 * add_mean / registered, 1)) |>
        as.data.frame())
cat("\ntotals 1985-2018:\n")
print(excess |> summarise(across(c(mse_hom, hom_mean, hom_low, dsp, add_mean, add_low), \(v) round(sum(v))), .by = sex) |> as.data.frame())

deaths_adj <-
  deaths |>
  left_join(excess |> select(year, sex, age, add_mean, add_low), by = c("year", "sex", "age")) |>
  replace_na(list(add_mean = 0, add_low = 0)) |>
  mutate(dx_conflict = dx + add_mean, dx_conflict_low = dx + add_low)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DDM input with the corrected numerator ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# window weights: share of each calendar year between the two census dates
window_weights <- function(d1, d2) {
  yrs <- floor(d1):floor(d2)
  tibble(year = yrs, w = (pmin(yrs + 1, d2) - pmax(yrs, d1)) / (d2 - d1))
}

avg_deaths <- function(d1, d2, var) {
  deaths_adj |>
    inner_join(window_weights(d1, d2), by = "year") |>
    summarise(deaths = sum(.data[[var]] * w), .by = c(sex, age))
}

X <-
  bind_rows(
    X0,
    map_dfr(c(conflict = "dx_conflict", "conflict (low)" = "dx_conflict_low"), \(var) {
      pmap_dfr(windows, \(c1, c2, d1, d2, window) {
        X0 |> filter(cod == window) |> select(-deaths) |>
          inner_join(avg_deaths(d1, d2, var), by = c("sex", "age"))
      })
    }, .id = "variant") |>
      mutate(variant = paste("migration +", variant))
  )

cat("\naverage annual deaths per window at ages 15-64, registered and corrected:\n")
print(X |> filter(age >= 15, age < 65) |> summarise(deaths = round(sum(deaths)), .by = c(cod, sex, variant)) |>
        pivot_wider(names_from = variant, values_from = deaths) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DDM ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_ranges <- list("auto 15-75" = NULL, "15-55" = seq(15, 55, 5), "30-65" = seq(30, 65, 5))
variants <- unique(X$variant)

res <-
  expand_grid(variant = variants, sex = c("m", "f"), ages = names(age_ranges)) |>
  pmap_dfr(\(variant, sex, ages) {
    x <- X |> filter(variant == !!variant, sex == !!sex) |>
      select(cod, pop1, pop2, deaths, year1, year2, age, sex) |> as.data.frame()
    ddm(x, exact.ages = age_ranges[[ages]]) |> as_tibble() |>
      mutate(variant = variant, sex = sex, ages = ages, .before = 1)
  }) |>
  rename(window = cod) |>
  left_join(windows |> select(window, d1, d2), by = "window")

# the DDM estimates refer to the numerator it was given; the completeness of
# the registered deaths alone is that estimate times registered / corrected
# deaths at the ages used (15+), per window and sex
d_ratio <-
  X |> filter(age >= 15) |> summarise(d = sum(deaths), .by = c(cod, sex, variant)) |> rename(window = cod) |>
  mutate(ratio = d[variant == "migration"] / d, .by = c(window, sex)) |> select(-d)
res <- res |> left_join(d_ratio, by = c("window", "sex", "variant")) |> mutate(ggbseg_reg = ggbseg * ratio)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# external reference series: registered / expected deaths at ages 15-64 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
grp5 <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), age_top))

wpp <-
  read_rds("data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds") |>
  filter(year <= 2023) |>
  mutate(age5 = grp5(age), exp = mx * pop)

# WPP: mx x pop
ref_wpp <- wpp |> summarise(expected = sum(exp), .by = c(year, sex, age5)) |> rename(age = age5) |> mutate(ref = "WPP 2024")

# DANE: abridged nmx by 5-year period x DANE population of each year
dane_pop <-
  read_rds("data_inter/pop_munic_1985-2017.rds") |>
  filter(sex %in% c("m", "f"), !is.na(age)) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(pop = sum(pop), .by = c(year, sex, age))
ref_dane <-
  read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE) |>
  filter(area == "Nacional") |>
  mutate(y1 = as.integer(str_sub(period, 1, 4))) |>
  reframe(year = y1:(y1 + 4), nmx, .by = c(sex, age, y1)) |>
  inner_join(dane_pop, by = c("year", "sex", "age")) |>
  summarise(expected = sum(nmx * pop), .by = c(year, sex, age)) |>
  mutate(ref = "DANE (tablas de vida)")

# LAMBdA: adjusted life-table mx (5-year groups from the 1x1 tables, deaths /
# person-years) x WPP population
ref_lambda <-
  map_dfr(c(m = "mltper", f = "fltper"), \(f) read_table(paste0("data_input/historical/lambda_Col_", f, "_1x1.txt"), show_col_types = FALSE), .id = "sex") |>
  mutate(age = as.integer(str_remove(age, fixed("+"))), age5 = grp5(age)) |>
  summarise(mx5 = sum(lx * qx) / sum(Lx), .by = c(year, sex, age5)) |>
  inner_join(wpp |> summarise(pop = sum(pop), .by = c(year, sex, age5)), by = c("year", "sex", "age5")) |>
  summarise(expected = sum(mx5 * pop), .by = c(year, sex, age5)) |> rename(age = age5) |>
  mutate(ref = "LAMBdA")

refs <-
  bind_rows(ref_wpp, ref_dane, ref_lambda) |>
  filter(age >= 15, age < 65) |>
  summarise(expected = sum(expected), .by = c(ref, year, sex)) |>
  inner_join(deaths |> filter(age >= 15, age < 65) |> summarise(registered = sum(dx), .by = c(year, sex)), by = c("year", "sex")) |>
  mutate(completeness = registered / expected)

cat("\nimplied completeness at 15-64 from the three reference series, selected years:\n")
print(refs |> filter(year %% 5 == 0) |> mutate(completeness = round(completeness, 3)) |>
        select(ref, year, sex, completeness) |> pivot_wider(names_from = c(ref, sex), values_from = completeness) |> as.data.frame())

# per window: sum of registered / sum of expected over the window years
refs_w <-
  pmap_dfr(windows, \(c1, c2, d1, d2, window) {
    refs |> inner_join(window_weights(d1, d2), by = "year") |>
      summarise(completeness = sum(registered * w) / sum(expected * w), n_years = sum(w), .by = c(ref, sex)) |>
      mutate(window = window)
  }) |>
  filter(n_years > 0.9) |>
  select(window, sex, ref, completeness)

out <-
  res |>
  filter(ages == "auto 15-75") |>
  select(window, sex, variant, ggb, seg, ggbseg, ggbseg_reg) |>
  left_join(refs_w |> pivot_wider(names_from = ref, values_from = completeness), by = c("window", "sex"))
write_csv(res |> left_join(refs_w |> pivot_wider(names_from = ref, values_from = completeness), by = c("window", "sex")),
          "output/tables/completeness_ddm_conflict.csv")

cat("\nGGB-SEG (automatic ages, with migration) by numerator, against the reference series:\n")
print(out |> mutate(across(where(is.numeric), \(v) round(v, 3))) |>
        select(-ggb, -seg, -ggbseg_reg) |> pivot_wider(names_from = variant, values_from = ggbseg) |> as.data.frame())
cat("\nthe same, expressed as completeness of the registered deaths (GGB-SEG x registered / corrected):\n")
print(out |> mutate(across(where(is.numeric), \(v) round(v, 3))) |>
        select(window, sex, variant, ggbseg_reg) |> pivot_wider(names_from = variant, values_from = ggbseg_reg) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# annual series ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# same anchoring as 22, for each numerator, expressed as completeness of the
# registered deaths
annual <-
  res |>
  filter(ages == "auto 15-75", !window %in% c("1964-1973", "1973-1985")) |>
  mutate(mid = (d1 + d2) / 2, comp = pmin(ggbseg_reg, 0.995)) |>
  group_by(variant, sex) |>
  reframe(year = 1938:2023,
          completeness = expit(approx(mid, logit(comp), xout = year + 0.5, rule = 2)$y)) |>
  left_join(deaths_adj |> filter(age >= 15) |>
              summarise(dx15 = sum(dx), dx15_conflict = sum(dx_conflict), .by = c(year, sex)), by = c("year", "sex")) |>
  mutate(dx15_corrected = dx15 / completeness)
write_csv(annual, "output/tables/completeness_ddm_conflict_annual.csv")

cat("\nannual completeness (GGB-SEG, migration + conflict), selected years:\n")
print(annual |> filter(year %% 5 == 0, variant == "migration + conflict") |>
        mutate(completeness = round(completeness, 3)) |> select(year, sex, completeness) |>
        pivot_wider(names_from = sex, values_from = completeness) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lab_sex <- \(s) factor(s, c("f", "m"), c("Mujeres", "Hombres"))
lab_var <- \(v) factor(v, c("migration", "migration + conflict", "migration + conflict (low)"),
                       c("registradas", "+ conflicto", "+ conflicto (bajo)"))
pts <-
  res |>
  filter(ages == "auto 15-75") |>
  mutate(mid = (d1 + d2) / 2 + c(-0.6, 0, 0.6)[match(variant, variants)], sex = lab_sex(sex), variant = lab_var(variant))

annual |>
  filter(variant != "migration + conflict (low)") |>
  mutate(sex = lab_sex(sex), variant = lab_var(variant)) |>
  ggplot(aes(year + 0.5, completeness)) +
  geom_hline(yintercept = 1, lty = "dashed", col = "grey60") +
  geom_line(data = refs |> mutate(sex = lab_sex(sex)), aes(year + 0.5, completeness, col = ref), linewidth = 0.6) +
  geom_line(aes(lty = variant), col = "black") +
  geom_point(data = pts, aes(mid, ggbseg_reg, shape = variant), size = 2) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("WPP 2024" = "#0A9396", "DANE (tablas de vida)" = "#CA6702", "LAMBdA" = "#9B2226")) +
  scale_shape_manual(values = c(1, 16, 4)) +
  scale_linetype_manual(values = c("solid", "dashed")) +
  coord_cartesian(ylim = c(0.5, 1.3)) +
  labs(title = "Completitud del registro de defunciones adultas, Colombia: DDM y series de referencia",
       subtitle = "Puntos y líneas negras: GGB-SEG (censos sin ajustar, con migración), numerador registrado o corregido por conflicto (1985-2018)\nLíneas de color: defunciones registradas / esperadas a 15-64 según WPP, DANE y LAMBdA",
       x = NULL, y = "Completitud", col = "Referencia", shape = "Numerador DDM", lty = "Serie anual") +
  theme_bw() + theme(legend.position = "bottom", legend.box = "vertical")
ggsave("figures/04_completeness/completeness_ddm_conflict.png", w = 10, h = 6.5)
