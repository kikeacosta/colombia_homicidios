# 22_ddm_census_national.R ---------------------------------------------------
# national completeness of adult death registration with DDM (GGB, SEG and the
# GGB-SEG hybrid) on the unadjusted census counts (21), for the six
# intercensal windows 1938-1951, ..., 2005-2018, and its interpolation to an
# annual series of completeness and corrected adult deaths.
#
# unlike 18 (DANE retroprojections, by department), the population here is the
# census as enumerated, so the GGB's delta measures the relative coverage of
# the two censuses and the hybrid corrects for it.
#
# deaths: WHO Mortality Database 1953-1977 (21), DANE microdata 1979-2023,
# LAMBdA (UN Demographic Yearbook transcriptions, 21) for 1938-1952, 1971 and
# 1973, all at ages 0, 1, 5, ..., 80+ (the 1973 census stops at 80+; LAMBdA
# groups 40-49, ..., 70+ before 1947 are split with the age pattern of the
# nearest year that has 5-year groups). 1978 takes the log-linearly
# interpolated age pattern of the neighbouring years, scaled to the national
# total of the DANE anuarios (data_input/historical); 1979 microdata are
# short (110,400 against 125,925 in the anuario) and are scaled up the same
# way. WHO and LAMBdA match the anuarios year by year, including the
# 1969-1971 dip. Average annual deaths per window are weighted by the share
# of each calendar year that falls between the two census dates.
#
# migration: two population variants.
#   "closed": the census counts as they are.
#   "migration": the second census of each window is brought back to what a
#     closed population would show, by adding the net emigration of
#     Colombian-born and removing the net immigration of foreign-born during
#     the window. Net flows by age at the second census are the stock at the
#     second date minus the stock at the first date aged n years (mortality
#     and returns of the stock ignored; negative values set to 0).
#     - emigrants: UN DESA stocks by sex and age (21), log-linearly
#       interpolated to census dates; before 1990 the 1990 stock by age is
#       extrapolated back with each sex's 1990-2000 growth rate (assumption:
#       no data; it makes the 1951-1985 correction rough).
#     - immigrants: only 2005-2018 (Venezuela), from the 2018 census
#       foreign-born; UNdata has no 2005 foreign-born by age, so all 963,492
#       are removed (overstates it by the ~0.1 million already there in 2005).
#
# sensitivity: automatic age-range selection (DDM default, 15-75) versus fixed
# ranges 15-55 and 30-65.
#
# annual series: the hybrid (automatic ages, "migration" variant) is placed at
# each window's midpoint and interpolated linearly on the logit scale between
# midpoints, held constant before the first and after the last; completeness
# above 1 is capped at 0.995 before applying it.
#
# outputs: output/tables/completeness_ddm_census.csv,
#          output/tables/completeness_ddm_census_annual.csv,
#          figures/04_completeness/completeness_ddm_census.png

rm(list = ls())
gc()
source("code/00_setup.R")
library(DDM)

cen <- read_rds("data_inter/census_pop_age.rds")
who <- read_rds("data_inter/who_deaths_age_1953-1977.rds")
dx_micro <- read_rds("data_inter/deaths_munic_age_1979-2023.rds")
emig <- read_rds("data_inter/emigrant_stock_age_1990-2024.rds")
lambda <- read_rds("data_inter/lambda_deaths_age_1926-2015.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# annual deaths by sex and age (0, 1, 5, ..., 80+) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_top <- 80

micro <-
  dx_micro |>
  filter(!is.na(sex)) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(dx = sum(dx_tot), .by = c(year, sex, age))
unk <- micro |> filter(is.na(age)) |> select(year, sex, unk = dx)
micro <-
  micro |>
  filter(!is.na(age)) |>
  mutate(tot = sum(dx), .by = c(year, sex)) |>
  left_join(unk, by = c("year", "sex")) |>
  replace_na(list(unk = 0)) |>
  mutate(dx = dx * (1 + unk / tot), src = "DANE") |>
  select(year, sex, age, dx, src)

# national totals from the anuarios, by sex where every department reports it
anuario <-
  read_csv("data_input/historical/deaths_department_v01.csv", show_col_types = FALSE) |>
  summarise(tot = sum(deaths_total, na.rm = TRUE), m = sum(deaths_male), f = sum(deaths_female), .by = year) |>
  mutate(across(c(m, f), ~ if_else(.x > 0, .x, NA)))

# LAMBdA years not covered by WHO or DANE. Groups wider than 5 years (40-49,
# ..., 70+ in 1938-1946; 50-59, 60-69, 70-79 in 1947-1951) are split with
# the within-group shares of 1952, the first year with 5-year groups, by sex
lam_years <- setdiff(unique(lambda$year), c(unique(who$year), unique(micro$year), 1970))
lam <- lambda |> filter(year %in% lam_years, year >= 1938) |> mutate(age = pmin(age, age_top)) |> summarise(dx = sum(dx), .by = c(year, sex, age))
ref <- lam |> filter(year == 1952) |> select(sex, age5 = age, ref = dx)
lam <-
  lam |>
  arrange(year, sex, age) |>
  mutate(age_next = lead(age, default = 999L), .by = c(year, sex)) |>
  inner_join(ref, by = "sex", relationship = "many-to-many") |>
  filter(age5 >= age, age5 < age_next) |>
  mutate(dx = dx * ref / sum(ref), .by = c(year, sex, age)) |>
  select(year, sex, age = age5, dx) |>
  mutate(src = "LAMBdA")

deaths <-
  bind_rows(who |> mutate(age = pmin(age, age_top), src = "WHO"), micro, lam) |>
  summarise(dx = sum(dx), .by = c(year, sex, age, src)) |>
  complete(year = 1938:2023, sex, age) |>
  arrange(sex, age, year) |>
  group_by(sex, age) |>
  mutate(
    src = replace_na(src, "anuario"),
    dx = exp(approx(year[!is.na(dx)], log(pmax(dx[!is.na(dx)], 0.5)), xout = year, rule = 2)$y)
  ) |>
  ungroup()

# scale the years without age detail, and 1979, to the anuario totals (by sex
# when available, else the interpolated sex ratio is kept)
fix_years <- c(1978, 1979)
target <-
  deaths |>
  filter(year %in% fix_years) |>
  summarise(dx = sum(dx), .by = c(year, sex)) |>
  left_join(anuario, by = "year") |>
  mutate(target = case_when(sex == "m" & !is.na(m) ~ m, sex == "f" & !is.na(f) ~ f,
                            TRUE ~ tot * dx / sum(dx)), .by = year) |>
  mutate(scale = target / dx) |>
  select(year, sex, scale)
deaths <-
  deaths |>
  left_join(target, by = c("year", "sex")) |>
  mutate(dx = dx * replace_na(scale, 1), src = if_else(year == 1979, "DANE (scaled)", src)) |>
  select(-scale)

cat("deaths by year around the WHO-DANE junction, against the anuarios:\n")
print(deaths |> filter(year %in% 1938:1985) |> summarise(dx = round(sum(dx)), src = first(src), .by = year) |>
        left_join(anuario |> select(year, anuario = tot), by = "year") |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DDM input per window ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# consecutive censuses, plus 1964-1985 skipping 1973: the UNdata 1973 counts
# are not the enumeration (22.8 million against 20.7 million enumerated) but
# DANE's adjusted figures, graduated by single age
censuses <- cen |> distinct(census, dec) |> arrange(census)
windows <-
  tibble(c1 = head(censuses$census, -1), c2 = tail(censuses$census, -1)) |>
  add_row(c1 = 1964, c2 = 1985) |>
  mutate(d1 = censuses$dec[match(c1, censuses$census)], d2 = censuses$dec[match(c2, censuses$census)],
         window = paste(c1, c2, sep = "-"))

# average annual deaths between two decimal dates
avg_deaths <- function(d1, d2) {
  yrs <- floor(d1):floor(d2)
  w <- pmin(yrs + 1, d2) - pmax(yrs, d1)
  deaths |>
    inner_join(tibble(year = yrs, w = w), by = "year") |>
    summarise(deaths = sum(dx * w) / (d2 - d1), .by = c(sex, age))
}

# net flow by age at the second date: stock s2 minus stock s1 aged n years;
# s1's cumulative count above age a is interpolated linearly within age groups
# (80+ spread to age 100). s1 and s2: tibbles (sex, age, stock)
net_flow <- function(s1, s2, n) {
  map_dfr(c("m", "f"), \(s) {
    a1 <- s1 |> filter(sex == s) |> arrange(age)
    above <- rev(cumsum(rev(c(a1$stock, 0))))
    surv_above <- \(x) approx(c(a1$age, 100), above, xout = pmax(x - n, 0), rule = 2)$y
    a2 <- s2 |> filter(sex == s) |> arrange(age)
    surv <- surv_above(a2$age) - c(surv_above(a2$age[-1]), 0)
    tibble(sex = s, age = a2$age, net = pmax(a2$stock - surv, 0))
  })
}

# emigrant stock at a decimal date: log-linear between UN DESA years; before
# 1990, the 1990 age structure scaled back at the 1990-2000 growth rate
g_emig <-
  emig |>
  filter(year %in% c(1990, 2000)) |>
  summarise(s = sum(stock), .by = c(year, sex)) |>
  summarise(g = log(s[year == 2000] / s[year == 1990]) / 10, .by = sex)
emig_at <- function(d) {
  if (d < 1990) {
    return(emig |> filter(year == 1990) |> left_join(g_emig, by = "sex") |>
             mutate(stock = stock * exp(g * (d - 1990))) |> select(sex, age, stock))
  }
  emig |>
    group_by(sex, age) |>
    summarise(stock = exp(approx(year + 0.5, log(pmax(stock, 1)), xout = d, rule = 2)$y), .groups = "drop")
}

build <- function(c1, c2, d1, d2, window) {
  p1 <- cen |> filter(census == c1) |> select(sex, age, pop1 = pop)
  p2 <- cen |> filter(census == c2) |> select(sex, age, pop2 = pop)
  p1 |>
    inner_join(p2, by = c("sex", "age")) |>
    inner_join(avg_deaths(d1, d2), by = c("sex", "age")) |>
    mutate(year1 = d1, year2 = d2, cod = window)
}

X <- pmap_dfr(windows, build)

migr <-
  pmap_dfr(windows, \(c1, c2, d1, d2, window) {
    em <- net_flow(emig_at(d1), emig_at(d2), d2 - d1) |> rename(emig = net)
    im <-
      if (c2 == 2018) {
        fb <- \(y) cen |> filter(census == y) |> select(sex, age, stock = fb) |> replace_na(list(stock = 0))
        net_flow(fb(2005), fb(2018), d2 - d1) |> rename(immig = net)
      } else {
        em |> transmute(sex, age, immig = 0)
      }
    left_join(em, im, by = c("sex", "age")) |> mutate(cod = window)
  })

cat("\nnet migration during each window, added to (emigrants) or removed from (immigrants) the second census:\n")
print(migr |> summarise(emig = round(sum(emig)), immig = round(sum(immig)), .by = c(cod, sex)) |> as.data.frame())

X <-
  bind_rows(
    X |> mutate(variant = "closed"),
    X |>
      left_join(migr, by = c("cod", "sex", "age")) |>
      mutate(pop2 = pop2 + emig - immig, variant = "migration") |>
      select(-emig, -immig)
  )

# annual deaths and DDM inputs, reused by 23 (conflict-adjusted numerator)
write_rds(deaths, "data_inter/deaths_age_annual_1938-2023.rds")
write_rds(list(X = X, windows = windows, migr = migr), "data_inter/ddm_census_inputs.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DDM ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_ranges <- list("auto 15-75" = NULL, "15-55" = seq(15, 55, 5), "30-65" = seq(30, 65, 5))

res <-
  expand_grid(variant = c("closed", "migration"), sex = c("m", "f"), ages = names(age_ranges)) |>
  pmap_dfr(\(variant, sex, ages) {
    x <- X |> filter(variant == !!variant, sex == !!sex) |>
      select(cod, pop1, pop2, deaths, year1, year2, age, sex) |> as.data.frame()
    ddm(x, exact.ages = age_ranges[[ages]]) |> as_tibble() |>
      mutate(variant = variant, sex = sex, ages = ages, .before = 1)
  }) |>
  rename(window = cod)

write_csv(res, "output/tables/completeness_ddm_census.csv")

cat("\nDDM on unadjusted censuses, national: hybrid GGB-SEG (and GGB) by variant\n")
print(res |>
        select(sex, ages, window, variant, ggb, ggbseg) |>
        pivot_wider(names_from = variant, values_from = c(ggb, ggbseg)) |>
        mutate(across(where(is.numeric), ~ round(.x, 3))) |>
        arrange(ages, sex, window) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# annual completeness ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# main specification: hybrid, automatic ages, migration-adjusted, 1964-1985
# in place of the two windows that use 1973
logit <- \(p) log(p / (1 - p))
expit <- \(x) 1 / (1 + exp(-x))

res <- res |> left_join(windows |> select(window, d1, d2), by = "window")

anchors <-
  res |>
  filter(ages == "auto 15-75", variant == "migration", !window %in% c("1964-1973", "1973-1985")) |>
  mutate(mid = (d1 + d2) / 2, comp = pmin(ggbseg, 0.995))

annual <-
  anchors |>
  group_by(sex) |>
  reframe(year = 1938:2023,
          completeness = expit(approx(mid, logit(comp), xout = year + 0.5, rule = 2)$y)) |>
  left_join(deaths |> filter(age >= 15) |> summarise(dx15 = sum(dx), .by = c(year, sex)), by = c("year", "sex")) |>
  left_join(deaths |> distinct(year, src) |> summarise(src = paste(unique(src), collapse = "/"), .by = year), by = "year") |>
  mutate(dx15_corrected = dx15 / completeness)

write_csv(annual, "output/tables/completeness_ddm_census_annual.csv")

cat("\nannual completeness (hybrid), selected years\n")
print(annual |> filter(year %% 5 == 0) |> select(year, sex, completeness) |>
        mutate(completeness = round(completeness, 3)) |>
        pivot_wider(names_from = sex, values_from = completeness) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pts <-
  res |>
  filter(ages == "auto 15-75") |>
  mutate(mid = (d1 + d2) / 2 + if_else(variant == "migration", 0.6, 0),
         variant = factor(variant, c("closed", "migration"), c("cerrada", "con migración"))) |>
  pivot_longer(c(ggb, seg, ggbseg), names_to = "method", values_to = "completeness") |>
  mutate(method = factor(method, c("ggb", "seg", "ggbseg"), c("GGB", "SEG", "GGB-SEG")),
         sex = factor(sex, c("f", "m"), c("Mujeres", "Hombres")))

annual |>
  mutate(sex = factor(sex, c("f", "m"), c("Mujeres", "Hombres"))) |>
  ggplot(aes(year + 0.5, completeness)) +
  geom_hline(yintercept = 1, lty = "dashed", col = "grey60") +
  geom_line(col = "black") +
  geom_point(data = pts, aes(mid, completeness, col = method, shape = variant), alpha = 0.8) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("GGB" = "#0A9396", "SEG" = "#CA6702", "GGB-SEG" = "#9B2226")) +
  coord_cartesian(ylim = c(0.4, 1.3)) +
  labs(title = "Completitud del registro de defunciones adultas, Colombia (censos sin ajustar)",
       subtitle = "Puntos: DDM por periodo intercensal (edades automáticas); línea: serie anual (GGB-SEG, con migración)",
       x = NULL, y = "Completitud", col = NULL, shape = "Población") +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/completeness_ddm_census.png", w = 10, h = 5.5)
