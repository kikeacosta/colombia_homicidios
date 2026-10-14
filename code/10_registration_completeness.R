rm(list = ls())
gc()
source("code/00_setup.R")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# completeness of death registration, by department and sex ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
# motivation: observed crude death rates in the Caribbean departments run at
# 1.7-2.8 per 1000 in the late 1980s, against 6.0-6.3 in Antioquia, Bogota and
# Santander. no real population dies that slowly, so a large share of deaths is
# simply never registered, and the share varies by department, by sex and over
# time. any sex ratio computed from those counts is a ratio of two differently
# incomplete numbers, which is the main reason the all-cause sex ratio and the
# homicide rate come apart before ~1998 in some departments.
#
# this script produces two things:
#
#   1. GGB (generalized growth balance, Hill 1987) estimates of completeness of
#      adult death registration, by department, sex and inter-census-style
#      period. these are absolute levels but only one number per period.
#   2. an annual index of relative coverage (department natural-cause ASDR over
#      the national one), anchored to the GGB levels so it can be used as an
#      annual covariate / offset in 07_model_zinb.R.
#
# caveats, in order of importance:
#   - GGB assumes no net migration. in departments with heavy displacement or
#     male out-migration (Antioquia 1985-95 is the clear case) male completeness
#     is biased downwards, because emigrants look like missing deaths.
#   - the "population" here is the DANE municipal projection, not a census
#     count, so what is estimated is completeness *relative to DANE's own
#     projected population*. that is the relevant quantity for this project,
#     since the same denominators are used for the rates.
#   - results move with the age range used for the fit; see the sensitivity
#     block at the end before trusting any single number.
#   - for a fuller treatment (SEG, GGB-SEG hybrid, age-trimming diagnostics)
#     see the DDM package, timriffe/DDM on github.

pop <- read_rds("data_inter/pop_munic_1985-2017.rds")
dt <- read_rds("data_inter/micro_1979_2023.rds")

yrs <- 1985:2017

# ~~~~~~~~~~~~~~~~~~~~
# preparing inputs ====
# ~~~~~~~~~~~~~~~~~~~~

# population by department, year, sex and 5-year age group
pop_dpto <-
  pop |>
  filter(sex != "t", !is.na(age), year %in% yrs) |>
  mutate(
    cod_dpto = str_sub(cod_munic, 1, 2),
    age = case_when(age < 5 ~ 0, age >= age_open ~ age_open, TRUE ~ age)
  ) |>
  summarise(pop = sum(pop), .by = c(cod_dpto, dpto, year, sex, age))

dptos <-
  pop_dpto |>
  select(cod_dpto, dpto) |>
  distinct()

# deaths by department, year, sex, 5-year age group and broad cause.
# `edad` is recomputed from gr_edad here so this script does not depend on
# which version of 01_loading_microdata.R produced the .rds
dts_dpto <-
  dt |>
  as_tibble() |>
  filter(ano %in% yrs, !is.na(sexo)) |>
  mutate(
    cod_dpto = sprintf("%02d", cod_dpto),
    edad = recode_age_group(gr_edad, ano),
    age = case_when(edad < 5 ~ 0, edad >= age_open ~ age_open, TRUE ~ edad),
    # natural causes only: excludes external causes (90-105) and the
    # ill-defined residual (89), both of which move sharply at the 1998
    # certificate/ICD-10 change and would contaminate the coverage index
    natural = cod_col %in% codes_natural
  ) |>
  filter(!is.na(age)) |>
  summarise(
    dx = n(),
    dx_nat = sum(natural),
    .by = c(cod_dpto, ano, sexo, age)
  ) |>
  rename(year = ano, sex = sexo)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. generalized growth balance (Hill 1987) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
# for the open interval a+, in a closed population,
#
#     N(a) / N(a+)  =  r(a+)  +  D(a+) / N(a+)
#
#   N(a)    person-years lived at exact age a  (entries into a+)
#   N(a+)   person-years lived at ages a and over
#   r(a+)   growth rate of the a+ population between t1 and t2
#   D(a+)   annual average registered deaths at ages a and over
#
# if only a fraction c of deaths is registered, regressing
# [N(a)/N(a+) - r(a+)] on [D(a+)/N(a+)] over a range of a gives slope = 1/c.
# the intercept carries the relative coverage of the two population counts,
# and should sit near zero when both come from the same projection series.

ggb_fit <- function(pop1, pop2, deaths, t1, t2, age_fit = seq(15, 60, 5)) {
  # pop1, pop2 : tibbles with `age`, `pop` at t1 and t2
  # deaths     : tibble with `age`, `dx` = annual average deaths over [t1, t2)

  d <-
    tibble(age = sort(unique(pop1$age))) |>
    left_join(pop1 |> select(age, n1 = pop), by = "age") |>
    left_join(pop2 |> select(age, n2 = pop), by = "age") |>
    left_join(deaths |> select(age, dx), by = "age") |>
    replace_na(list(dx = 0)) |>
    filter(n1 > 0, n2 > 0)

  if (nrow(d) < 8) {
    return(tibble(completeness = NA_real_, intercept = NA_real_, r2 = NA_real_))
  }

  n <- nrow(d)
  d <- d |> mutate(py = sqrt(n1 * n2)) # person-years by age group

  # "a and over" cumulations, from the open-ended group downwards
  cum_up <- function(x) rev(cumsum(rev(x)))
  n_plus <- cum_up(d$py)
  n1_plus <- cum_up(d$n1)
  n2_plus <- cum_up(d$n2)
  d_plus <- cum_up(d$dx)

  # person-years at exact age a, from the two groups either side of a
  n_at <- c(NA_real_, sqrt(d$py[-n] * d$py[-1]) / 5)

  bal <-
    tibble(
      age = d$age,
      entry = n_at / n_plus,
      growth = log(n2_plus / n1_plus) / (t2 - t1),
      exit = d_plus / n_plus
    ) |>
    filter(age %in% age_fit, is.finite(entry), is.finite(growth), is.finite(exit))

  if (nrow(bal) < 5) {
    return(tibble(completeness = NA_real_, intercept = NA_real_, r2 = NA_real_))
  }

  fit <- lm(I(entry - growth) ~ exit, data = bal)
  slope <- coef(fit)[["exit"]]

  tibble(
    completeness = ifelse(is.finite(slope) & slope > 0, 1 / slope, NA_real_),
    intercept = coef(fit)[["(Intercept)"]],
    r2 = summary(fit)$r.squared,
    n_ages = nrow(bal)
  )
}

# wrapper: one department x sex x period
ggb_one <- function(cd, sx, t1, t2, age_fit = seq(15, 60, 5)) {
  p1 <- pop_dpto |> filter(cod_dpto == cd, sex == sx, year == t1)
  p2 <- pop_dpto |> filter(cod_dpto == cd, sex == sx, year == t2)
  if (nrow(p1) == 0 | nrow(p2) == 0) {
    return(tibble(completeness = NA_real_, intercept = NA_real_, r2 = NA_real_))
  }
  dd <-
    dts_dpto |>
    filter(cod_dpto == cd, sex == sx, year >= t1, year < t2) |>
    summarise(dx = sum(dx) / (t2 - t1), .by = age)
  ggb_fit(p1, p2, dd, t1, t2, age_fit)
}

# periods: 10-year windows across the observation range
periods <- tribble(
  ~period, ~t1, ~t2,
  "1985-1995", 1985, 1995,
  "1995-2005", 1995, 2005,
  "2005-2015", 2005, 2015
)

comp_ggb <-
  expand_grid(
    dptos,
    sex = c("m", "f"),
    periods
  ) |>
  rowwise() |>
  mutate(ggb_fit = list(ggb_one(cod_dpto, sex, t1, t2))) |>
  ungroup() |>
  unnest(ggb_fit) |>
  select(cod_dpto, dpto, sex, period, t1, t2, completeness, intercept, r2, n_ages)

comp_ggb |>
  filter(period == "1985-1995") |>
  select(dpto, sex, completeness) |>
  pivot_wider(names_from = sex, values_from = completeness) |>
  arrange(f) |>
  print(n = 40)

write_rds(comp_ggb, "data_inter/completeness_ggb.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# GGB diagnostic plot: the fitted balance lines themselves ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# a well-behaved department gives points on a straight line. curvature means
# age misreporting or migration, and the completeness estimate should not be
# believed. always look at this before using the numbers.

ggb_points <- function(cd, sx, t1, t2) {
  p1 <- pop_dpto |> filter(cod_dpto == cd, sex == sx, year == t1)
  p2 <- pop_dpto |> filter(cod_dpto == cd, sex == sx, year == t2)
  dd <-
    dts_dpto |>
    filter(cod_dpto == cd, sex == sx, year >= t1, year < t2) |>
    summarise(dx = sum(dx) / (t2 - t1), .by = age)
  d <-
    tibble(age = sort(unique(p1$age))) |>
    left_join(p1 |> select(age, n1 = pop), by = "age") |>
    left_join(p2 |> select(age, n2 = pop), by = "age") |>
    left_join(dd, by = "age") |>
    replace_na(list(dx = 0)) |>
    filter(n1 > 0, n2 > 0) |>
    mutate(py = sqrt(n1 * n2))
  n <- nrow(d)
  cum_up <- function(x) rev(cumsum(rev(x)))
  tibble(
    age = d$age,
    entry = c(NA_real_, sqrt(d$py[-n] * d$py[-1]) / 5) / cum_up(d$py),
    growth = log(cum_up(d$n2) / cum_up(d$n1)) / (t2 - t1),
    exit = cum_up(d$dx) / cum_up(d$py)
  ) |>
    mutate(y = entry - growth)
}

diag_pts <-
  expand_grid(dptos, sex = c("m", "f"), periods) |>
  rowwise() |>
  mutate(pts = list(ggb_points(cod_dpto, sex, t1, t2))) |>
  ungroup() |>
  unnest(pts) |>
  filter(is.finite(y), is.finite(exit))

diag_pts |>
  filter(period == "1985-1995") |>
  ggplot(aes(exit, y, col = sex)) +
  geom_point(size = 0.7, alpha = 0.8) +
  geom_smooth(
    data = ~ filter(.x, age %in% seq(15, 60, 5)),
    method = "lm",
    se = FALSE,
    linewidth = 0.4
  ) +
  facet_wrap(~dpto, scales = "free") +
  scale_color_manual(values = c("m" = "#1d3557", "f" = "#9B2226")) +
  labs(
    title = "GGB balance diagnostic, 1985-1995",
    subtitle = "slope = 1 / completeness; curvature invalidates the estimate",
    x = "D(a+) / N(a+)",
    y = "N(a) / N(a+) - r(a+)"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave("figures/completeness_ggb_diagnostic.png", w = 14, h = 11)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. annual coverage index, anchored to the GGB levels ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# the GGB estimates are periodic. for use as a model covariate we need an
# annual series, so take the department's age-standardized natural-cause death
# rate relative to the national one as a within-year index of relative
# coverage, then rescale each department's index so that its mean over each GGB
# window reproduces the GGB estimate.
#
# this assumes that differences in *natural-cause* mortality between
# departments are small relative to differences in registration coverage.
# that is a strong assumption and it is the weak point of this step: genuine
# excess natural mortality will be read as better coverage. it is defensible
# here only because the spread being explained is enormous (a factor of three
# in the crude death rate) and cannot plausibly be real mortality.

# standard: national age distribution in 2017
std <-
  pop_dpto |>
  filter(year == 2017) |>
  summarise(pop = sum(pop), .by = age) |>
  mutate(cx_std = pop / sum(pop)) |>
  select(age, cx_std)

asdr_nat <-
  pop_dpto |>
  left_join(
    dts_dpto |> select(cod_dpto, year, sex, age, dx_nat),
    by = join_by(cod_dpto, year, sex, age)
  ) |>
  replace_na(list(dx_nat = 0)) |>
  left_join(std, by = "age") |>
  summarise(
    pop = sum(pop),
    dx_nat = sum(dx_nat),
    asdr = sum(cx_std * dx_nat / pop),
    .by = c(cod_dpto, dpto, year, sex)
  )

asdr_nal <-
  asdr_nat |>
  summarise(asdr_nal = sum(asdr * pop) / sum(pop), .by = c(year, sex))

cov_idx <-
  asdr_nat |>
  left_join(asdr_nal, by = join_by(year, sex)) |>
  mutate(idx = asdr / asdr_nal) |>
  select(cod_dpto, dpto, year, sex, pop, idx)

# mean of the annual index over each GGB window
idx_period <-
  cov_idx |>
  cross_join(periods) |>
  filter(year >= t1, year < t2) |>
  summarise(idx_mean = mean(idx, na.rm = TRUE), .by = c(cod_dpto, sex, period))

# anchoring factor: one per department x sex x window, then averaged over the
# windows where the GGB fit is usable
anchor_k <-
  comp_ggb |>
  select(cod_dpto, sex, period, completeness, r2) |>
  left_join(idx_period, by = join_by(cod_dpto, sex, period)) |>
  mutate(k = completeness / idx_mean) |>
  filter(is.finite(k), completeness > 0, completeness < 1.5, r2 > 0.8) |>
  summarise(k = mean(k), n_windows = n(), .by = c(cod_dpto, sex))

comp_annual <-
  cov_idx |>
  left_join(anchor_k, by = join_by(cod_dpto, sex)) |>
  mutate(
    anchored = !is.na(k),
    # departments with no usable GGB fit fall back to the unscaled index
    k = ifelse(is.na(k), 1, k),
    # capped at 1: a department cannot register more deaths than occur. the cap
    # binds for Bogota, Tolima and Caldas, where the index runs above the
    # national average for reasons that are probably part real excess natural
    # mortality rather than coverage. treat those as "complete, near enough"
    capped = idx * k > 1,
    completeness = pmin(idx * k, 1),
    # the Amazonia / Orinoquia micro-departments have 10-40k inhabitants and
    # single-digit annual natural-cause death counts, so both the GGB fit and
    # the index are meaningless there - some years register zero natural deaths
    # and the index collapses to 0. flag them rather than emitting a number.
    reliable = anchored & pop >= 5e4 & completeness > 0.05,
    completeness = ifelse(reliable, completeness, NA_real_)
  ) |>
  select(
    cod_dpto, dpto, year, sex, pop, idx, completeness, anchored, capped, reliable
  )

cat("\ndepartment-years flagged unreliable:\n")
comp_annual |>
  filter(!reliable) |>
  count(dpto, name = "n_years") |>
  arrange(-n_years) |>
  print(n = 20)

write_rds(comp_annual, "data_inter/completeness_deptos.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# sanity check: does the correction imply a plausible national CDR? ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# registered national CDR sits at 4.5-5.1 per 1000 across the whole period,
# which is too low for Colombia's age structure. if the completeness estimates
# are roughly right, dividing through by them should land the implied CDR in
# the 5.5-7 range and give it a sensible downward trend.

sanity <-
  read_rds("data_inter/deaths_munic_1979-2023.rds") |>
  filter(year %in% yrs, !is.na(sex)) |>
  mutate(cod_dpto = sprintf("%02d", cod_dpto)) |>
  summarise(dx_reg = sum(dx_tot), .by = c(cod_dpto, year, sex)) |>
  inner_join(
    comp_annual |> select(cod_dpto, year, sex, pop, completeness, reliable),
    by = join_by(cod_dpto, year, sex)
  ) |>
  filter(reliable) |>
  # NB: compute the row-wise quantity before summarising. summarise() evaluates
  # its arguments in sequence, so `sum(dx_reg / completeness)` placed after
  # `dx_reg = sum(dx_reg)` would divide the already-aggregated total
  mutate(dx_implied = dx_reg / completeness) |>
  summarise(
    dx_reg = sum(dx_reg),
    dx_implied = sum(dx_implied),
    pop = sum(pop),
    .by = year
  ) |>
  mutate(
    cdr_reg = 1e3 * dx_reg / pop,
    cdr_implied = 1e3 * dx_implied / pop,
    ratio = dx_implied / dx_reg
  )

sanity |>
  mutate(across(c(cdr_reg, cdr_implied, ratio), ~ round(.x, 2))) |>
  select(year, cdr_reg, cdr_implied, ratio) |>
  print(n = 40)

sanity |>
  select(year, cdr_reg, cdr_implied) |>
  pivot_longer(-year, names_to = "serie", values_to = "cdr") |>
  ggplot() +
  geom_line(aes(year, cdr, col = serie), linewidth = 0.8) +
  geom_vline(xintercept = 1998, lty = "dashed", alpha = 0.5) +
  scale_color_manual(
    values = c("cdr_reg" = "grey40", "cdr_implied" = "#9B2226"),
    labels = c("cdr_implied" = "corregida", "cdr_reg" = "registrada")
  ) +
  coord_cartesian(ylim = c(0, 8)) +
  labs(
    title = "National crude death rate, registered vs corrected for completeness",
    y = "per 1000",
    x = NULL,
    col = NULL
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave("figures/completeness_national_cdr.png", w = 7, h = 4)

# ~~~~~~~~~~~~~~~~~~~~
# result plots ====
# ~~~~~~~~~~~~~~~~~~~~

carib <- cod_caribe

comp_annual |>
  filter(reliable) |>
  mutate(region = ifelse(cod_dpto %in% carib, "Caribe", "Resto")) |>
  ggplot() +
  geom_line(aes(year, completeness, col = sex), linewidth = 0.6) +
  geom_vline(xintercept = 1998, lty = "dashed", alpha = 0.5) +
  facet_wrap(~dpto) +
  scale_color_manual(values = c("m" = "#1d3557", "f" = "#9B2226")) +
  coord_cartesian(ylim = c(0, 1.1)) +
  labs(
    title = "Estimated completeness of death registration",
    subtitle = "annual coverage index anchored to GGB levels; dashed line = 1998 certificate / ICD-10 change",
    y = "completeness",
    x = NULL
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave("figures/completeness_deptos.png", w = 14, h = 10)

# the sex-differential, which is what distorts the all-cause sex ratio
comp_annual |>
  filter(reliable) |>
  select(cod_dpto, dpto, year, sex, completeness) |>
  pivot_wider(names_from = sex, values_from = completeness) |>
  drop_na(m, f) |>
  mutate(ratio = m / f, region = ifelse(cod_dpto %in% carib, "Caribe", "Resto")) |>
  ggplot() +
  geom_line(aes(year, ratio, group = dpto, col = region), alpha = 0.7) +
  geom_hline(yintercept = 1, lty = "dashed") +
  geom_vline(xintercept = 1998, lty = "dashed", alpha = 0.5) +
  scale_color_manual(values = c("Caribe" = "#CA6702", "Resto" = "grey50")) +
  labs(
    title = "Sex differential in registration completeness",
    subtitle = "male completeness / female completeness; departures from 1 bias the all-cause sex ratio",
    y = "male / female completeness",
    x = NULL
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave("figures/completeness_sex_ratio.png", w = 8, h = 5)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# sensitivity of GGB to the fitting age range ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# run this before quoting any single completeness figure. departments where
# the three ranges disagree badly are the ones where migration or age
# misreporting is breaking the GGB assumptions.

age_ranges <- list(
  "15-60" = seq(15, 60, 5),
  "5-65" = seq(5, 65, 5),
  "25-70" = seq(25, 70, 5)
)

sens <-
  expand_grid(
    dptos,
    sex = c("m", "f"),
    periods |> filter(period == "1985-1995"),
    range = names(age_ranges)
  ) |>
  rowwise() |>
  mutate(
    completeness = ggb_one(cod_dpto, sex, t1, t2, age_ranges[[range]])$completeness
  ) |>
  ungroup() |>
  select(dpto, sex, range, completeness) |>
  pivot_wider(names_from = range, values_from = completeness) |>
  mutate(across(where(is.numeric), ~ round(.x, 2)))

print(sens, n = 70)

write_csv(sens, "data_inter/q_test/completeness_ggb_sensitivity.csv")
