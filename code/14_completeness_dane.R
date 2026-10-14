# 14_completeness_dane.R -----------------------------------------------------
# registration completeness implied by DANE's conciliated life tables
# (13_extract_dane_lifetables.R), by department, sex and quinquennium:
#
#   completeness = registered deaths / (sum over ages of nMx_DANE x population)
#
# DANE's nMx is a corrected estimate of true mortality (registry deaths
# adjusted with census information), so the ratio is an external check on the
# GGB-based completeness of 10. it is not independent of the registry (DANE's
# correction starts from registered deaths) and it inherits DANE's population
# series; but it does not use the project's own death counts to define
# completeness, which the annual coverage index of 10 does.
#
# unknown-age deaths (<0.5 percent of deaths) are distributed pro rata over
# known ages within department x sex x year.
#
# inputs: data_input/reference/dane_lifetables_nmx_1985_2020.csv,
#         data_inter/deaths_munic_age_1979-2023.rds, pop_munic_1985-2017.rds,
#         data_inter/completeness_deptos.rds
# outputs: output/tables/completeness_dane.csv,
#          figures/completeness_dane_vs_ggb.png

rm(list = ls())
gc()
source("code/00_setup.R")

nmx <- read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE)
dx <- read_rds("data_inter/deaths_munic_age_1979-2023.rds")
pop <- read_rds("data_inter/pop_munic_1985-2017.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# areas ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DANE publishes the five Amazonia / Orinoquia micro-departments as one group
# and Bogota apart. codes follow DIVIPOLA.

area_map <- tribble(
  ~area, ~cod_dpto,
  "Antioquia", "05", "Atlántico", "08", "Bogotá D.C.", "11", "Bolívar", "13",
  "Boyacá", "15", "Caldas", "17", "Caquetá", "18", "Cauca", "19",
  "Cesar", "20", "Córdoba", "23", "Cundinamarca", "25", "Chocó", "27",
  "Huila", "41", "La Guajira", "44", "Magdalena", "47", "Meta", "50",
  "Nariño", "52", "Norte de Santander", "54", "Quindío", "63",
  "Risaralda", "66", "Santander", "68", "Sucre", "70", "Tolima", "73",
  "Valle del Cauca", "76", "Arauca", "81", "Casanare", "85", "Putumayo", "86",
  "San Andrés", "88",
  "Grupo Amazonía", "91", "Grupo Amazonía", "94", "Grupo Amazonía", "95",
  "Grupo Amazonía", "97", "Grupo Amazonía", "99"
)
stopifnot(all(unique(nmx$area) %in% c(area_map$area, "Nacional")))

# periods: calendar years covered, within the 1985-2017 window of the data.
# DANE's quinquenium 1985-1990 is mid-1985 to mid-1990; years 1985-1989 are
# used (1990-1994 for the next, ...)
per <- tibble(
  period = c("1985-1990", "1990-1995", "1995-2000", "2000-2005", "2005-2010", "2010-2015", "2015-2020"),
  y1 = c(1985, 1990, 1995, 2000, 2005, 2010, 2015)
) |>
  mutate(y2 = pmin(y1 + 4, 2017))

# 5-year age groups used by the life tables: 0, 1-4, 5-9, ..., 75-79, 80+
age_lt <- function(a) case_when(a >= 80 ~ 80, TRUE ~ a)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# population and registered deaths by area x year x sex x age ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

pop_a <-
  pop |>
  filter(sex %in% c("m", "f"), !is.na(age), year %in% 1985:2017) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)), age = age_lt(age)) |>
  summarise(pop = sum(pop), .by = c(cod_dpto, year, sex, age))

dx_a <-
  dx |>
  filter(year %in% 1985:2017, !is.na(sex)) |>
  mutate(cod_dpto = sprintf("%02d", cod_dpto)) |>
  filter(cod_dpto %in% area_map$cod_dpto) |>
  mutate(age = age_lt(age)) |>
  summarise(dx = sum(dx_tot), .by = c(cod_dpto, year, sex, age))

# unknown-age deaths: pro rata over known ages, within department x year x sex
dx_known <- dx_a |> filter(!is.na(age))
dx_unk <- dx_a |> filter(is.na(age)) |> select(cod_dpto, year, sex, dx_unk = dx)
dx_b <-
  dx_known |>
  mutate(tot_known = sum(dx), .by = c(cod_dpto, year, sex)) |>
  left_join(dx_unk, by = c("cod_dpto", "year", "sex")) |>
  replace_na(list(dx_unk = 0)) |>
  mutate(dx_adj = dx * (1 + dx_unk / tot_known)) |>
  select(cod_dpto, year, sex, age, dx = dx_adj)

cat("share of deaths with unknown age, 1985-2017:",
    round(sum(dx_unk$dx_unk) / sum(dx_a$dx), 4), "\n")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# expected vs registered ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

cells <-
  pop_a |>
  left_join(dx_b, by = c("cod_dpto", "year", "sex", "age")) |>
  replace_na(list(dx = 0)) |>
  inner_join(area_map, by = "cod_dpto") |>
  cross_join(per) |>
  filter(year >= y1, year <= y2) |>
  left_join(nmx, by = c("area", "period", "sex", "age")) |>
  mutate(exp = nmx * pop)

stopifnot(!anyNA(cells$nmx))

comp_dane <-
  cells |>
  summarise(
    registered = sum(dx),
    expected = sum(exp),
    registered_15_64 = sum(dx[age >= 15 & age < 65]),
    expected_15_64 = sum(exp[age >= 15 & age < 65]),
    registered_5plus = sum(dx[age >= 5]),
    expected_5plus = sum(exp[age >= 5]),
    pop = sum(pop),
    .by = c(area, period, sex)
  ) |>
  mutate(
    c_all = registered / expected,
    c_15_64 = registered_15_64 / expected_15_64,
    c_5plus = registered_5plus / expected_5plus
  )

# national, same method: DANE told the UN that registration at ages 5+ was
# 0.89 (men) and 0.95 (women) in 1985, and 0.855 / 0.87 in 1993
nal <-
  cells |>
  summarise(
    registered = sum(dx[age >= 5]), expected = sum(exp[age >= 5]),
    .by = c(period, sex)
  ) |>
  mutate(c_5plus_nal_pooled = registered / expected)
cat("\ncompleteness at ages 5+, the 30 areas pooled (compare DANE to the UN: m 0.89 f 0.95 in 1985; m 0.855 f 0.87 in 1993):\n")
print(nal |> select(period, sex, c_5plus_nal_pooled) |> pivot_wider(names_from = sex, values_from = c_5plus_nal_pooled))

write_csv(comp_dane, "output/tables/completeness_dane.csv")

cat("\ncompleteness, all ages, 1985-1990 (selected departments):\n")
print(
  comp_dane |>
    filter(period == "1985-1990") |>
    select(area, sex, c_all, c_15_64) |>
    pivot_wider(names_from = sex, values_from = c(c_all, c_15_64)) |>
    arrange(c_all_f) |>
    mutate(across(where(is.numeric), ~ round(.x, 2))),
  n = 40
)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# comparison with the GGB-anchored index of 10 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

comp_ggb <-
  read_rds("data_inter/completeness_deptos.rds") |>
  filter(reliable) |>
  inner_join(area_map, by = "cod_dpto") |>
  cross_join(per) |>
  filter(year >= y1, year <= y2) |>
  summarise(c_ggb = mean(completeness), .by = c(cod_dpto, dpto, area, period, sex))

cmp <-
  comp_dane |>
  inner_join(comp_ggb, by = c("area", "period", "sex")) |>
  mutate(caribe = cod_dpto %in% cod_caribe)

cat("\nDANE-implied vs GGB-anchored completeness, department x sex x period (n =", nrow(cmp), ")\n")
print(
  cmp |>
    summarise(
      pearson = cor(c_15_64, c_ggb),
      spearman = cor(c_15_64, c_ggb, method = "spearman"),
      mean_diff = mean(c_15_64 - c_ggb),
      mad = mean(abs(c_15_64 - c_ggb)),
      .by = period
    )
)

print(
  cmp |>
    filter(period %in% c("1985-1990", "1995-2000")) |>
    select(dpto, sex, period, dane = c_15_64, ggb = c_ggb) |>
    pivot_wider(names_from = c(period, sex), values_from = c(dane, ggb), names_sep = "_") |>
    mutate(across(where(is.numeric), ~ round(.x, 2))) |>
    arrange(dpto),
  n = 40, width = 200
)

cmp |>
  ggplot(aes(c_ggb, c_15_64, col = caribe)) +
  geom_abline(lty = "dashed") +
  geom_point(alpha = 0.7) +
  facet_wrap(~period) +
  coord_equal(xlim = c(0, 1.3), ylim = c(0, 1.3)) +
  scale_color_manual(values = c("TRUE" = "#CA6702", "FALSE" = "grey50"), labels = c("TRUE" = "Caribe", "FALSE" = "resto")) +
  labs(
    title = "Completeness: DANE conciliated life tables vs GGB-anchored index",
    subtitle = "registered / expected deaths at ages 15-64, by department, sex and quinquennium",
    x = "GGB-anchored index (10)", y = "implied by DANE life tables (this script)", col = NULL
  ) +
  theme_bw() +
  theme(legend.position = "bottom")
ggsave("figures/completeness_dane_vs_ggb.png", w = 10, h = 7)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# the decisive comparison: registered vs DANE-expected sex ratio ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# the level of DANE-implied completeness is not reliable (see header: the 2007
# tables sit on an older population series than the retroprojections used
# here; pooled completeness at 5+ comes out at 0.74 in 1985 and 0.75 in
# 2010-15, which is not plausible). the sex ratio of EXPECTED deaths does not
# need that level: it uses DANE's male and female nMx, which carry the
# conciliated sex differential in mortality.
#
# test: across areas, within each quinquennium, which sex ratio predicts the
# registered violent-death rate better, the observed one or the DANE-expected
# one? if differential under-registration is what breaks the observed ratio
# before 1998, the expected ratio should do clearly better there and similarly
# after. violent deaths (101-103) are taken as the outcome, as in the model.

viol <-
  dx |>
  filter(year %in% 1985:2017) |>
  mutate(cod_dpto = sprintf("%02d", cod_dpto)) |>
  inner_join(area_map, by = "cod_dpto") |>
  cross_join(per) |>
  filter(year >= y1, year <= y2) |>
  summarise(dx_v = sum(dx_v), .by = c(area, period))

sr <-
  cells |>
  summarise(dx = sum(dx), exp = sum(exp), pop = sum(pop), .by = c(area, period, sex)) |>
  pivot_wider(names_from = sex, values_from = c(dx, exp, pop)) |>
  mutate(
    log_sr_obs = log((dx_m / pop_m) / (dx_f / pop_f)),
    log_sr_dane = log((exp_m / pop_m) / (exp_f / pop_f))
  ) |>
  left_join(viol, by = c("area", "period")) |>
  mutate(log_h = log(dx_v / (pop_m + pop_f)))

res <-
  sr |>
  summarise(
    n = n(),
    r2_obs = summary(lm(log_h ~ log_sr_obs))$r.squared,
    r2_dane = summary(lm(log_h ~ log_sr_dane))$r.squared,
    r_obs = cor(log_h, log_sr_obs),
    r_dane = cor(log_h, log_sr_dane),
    sd_obs = sd(log_sr_obs),
    sd_dane = sd(log_sr_dane),
    .by = period
  ) |>
  arrange(period)

cat("\nacross areas, per quinquennium: log violent-death rate ~ log sex ratio of all-cause mortality\n")
print(res |> mutate(across(where(is.numeric), ~ round(.x, 2))))

write_csv(sr, "output/tables/sex_ratio_observed_vs_dane_expected.csv")

sr |>
  ggplot(aes(log_sr_dane - log_sr_obs, log_h - predict(lm(log_h ~ log_sr_dane), sr))) +
  geom_point() +
  facet_wrap(~period) +
  labs(
    x = "log expected - log observed sex ratio (DANE minus registry)",
    y = "violent-death rate, residual from expected sex ratio"
  ) +
  theme_bw()
ggsave("figures/sex_ratio_obs_vs_dane_expected.png", w = 9, h = 6)
