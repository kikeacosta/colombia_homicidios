# 16_age_placebo.R -----------------------------------------------------------
# placebo test of the registration explanation, by age.
#
# the male/female ratio of all-cause mortality at ages 50-79 is dominated by
# natural causes (homicide contributes very little) and has a stable male
# excess. if registration is differentially incomplete by sex, that ratio
# should drift across departments and over time, and the drift should be
# larger where completeness is lower. at ages 15-44, where homicide dominates
# male mortality, both registration and violence move the ratio.
#
#   1. sex ratio at 50-79 and at 15-44 by department and year, from the age
#      file (11b), 1985-2023, Caribbean vs rest
#   2. at 50-79, registered ratio vs the ratio implied by DANE's conciliated
#      nMx (13), department x quinquennium, 1985-2015: a direct measure of
#      differential registration that does not use causes of death
#   3. does the 50-79 ratio correlate with the homicide rate? (it should not
#      if natural mortality is measured cleanly)
#
# outputs: output/tables/age_placebo_*.csv, figures/age_placebo_*.png

rm(list = ls())
gc()
source("code/00_setup.R")
library(arrow)

d <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |> as_tibble()
d <- d |> filter(!is.na(age)) |> mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)))

# department x year x sex x broad age band
band <- function(a) case_when(a >= 15 & a <= 40 ~ "15-44", a >= 50 & a <= 75 ~ "50-79", TRUE ~ NA_character_)
dep <-
  d |>
  mutate(band = band(age)) |>
  filter(!is.na(band)) |>
  summarise(dx = sum(dx_all), v = sum(dx_homicide + dx_undetermined + dx_legal), pop = sum(pop, na.rm = TRUE),
            .by = c(year, cod_dpto, dpto, sex, band))

sr <-
  dep |>
  mutate(mx = dx / pop) |>
  select(year, cod_dpto, dpto, band, sex, mx, v) |>
  pivot_wider(names_from = sex, values_from = c(mx, v)) |>
  mutate(sr = mx_m / mx_f, caribe = cod_dpto %in% cod_caribe) |>
  filter(is.finite(sr), cod_dpto != "88")

cat("sex ratio of all-cause mortality by age band, mean over departments\n")
tab1 <-
  sr |>
  mutate(per = cut(year, c(1984, 1989, 1994, 1997, 2002, 2007, 2017, 2023),
                   labels = c("1985-89", "1990-94", "1995-97", "1998-2002", "2003-07", "2008-17", "2018-23"))) |>
  summarise(mean_sr = mean(sr), sd_sr = sd(sr), .by = c(band, caribe, per)) |>
  arrange(band, caribe, per)
print(tab1 |> mutate(across(where(is.numeric), ~ round(.x, 2))) |> as.data.frame(), row.names = FALSE)
write_csv(tab1, "output/tables/age_placebo_sex_ratio_by_period.csv")

sr |>
  mutate(region = ifelse(caribe, "Caribe", "resto")) |>
  summarise(sr = median(sr), lo = quantile(sr, .25), hi = quantile(sr, .75), .by = c(year, band, region)) |>
  ggplot(aes(year, sr, col = region, fill = region)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, col = NA) +
  geom_line() +
  geom_vline(xintercept = 1997.5, lty = "dashed", alpha = 0.5) +
  facet_wrap(~band, scales = "free_y") +
  scale_color_manual(values = c(Caribe = "#CA6702", resto = "grey40")) +
  scale_fill_manual(values = c(Caribe = "#CA6702", resto = "grey40")) +
  labs(title = "Sex ratio of all-cause mortality by age band",
       subtitle = "median and interquartile range across departments", x = NULL, y = "male / female") +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/age_placebo_sex_ratio.png", w = 9, h = 4.5)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. registered vs DANE-expected ratio at 50-79 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

nmx <- read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE)
area_map <- tribble(
  ~area, ~cod_dpto,
  "Antioquia", "05", "Atlántico", "08", "Bogotá D.C.", "11", "Bolívar", "13",
  "Boyacá", "15", "Caldas", "17", "Caquetá", "18", "Cauca", "19",
  "Cesar", "20", "Córdoba", "23", "Cundinamarca", "25", "Chocó", "27",
  "Huila", "41", "La Guajira", "44", "Magdalena", "47", "Meta", "50",
  "Nariño", "52", "Norte de Santander", "54", "Quindío", "63",
  "Risaralda", "66", "Santander", "68", "Sucre", "70", "Tolima", "73",
  "Valle del Cauca", "76", "Arauca", "81", "Casanare", "85", "Putumayo", "86"
)
per <- tibble(period = c("1985-1990", "1990-1995", "1995-2000", "2000-2005", "2005-2010", "2010-2015"),
              y1 = c(1985, 1990, 1995, 2000, 2005, 2010), y2 = y1 + 4)

cells <-
  d |>
  filter(age >= 50, age <= 75) |>
  inner_join(area_map, by = "cod_dpto") |>
  cross_join(per) |>
  filter(year >= y1, year <= y2) |>
  left_join(nmx |> select(area, period, sex, age, nmx), by = c("area", "period", "sex", "age")) |>
  summarise(dx = sum(dx_all), pop = sum(pop), exp = sum(nmx * pop), .by = c(area, cod_dpto, period, sex))

diffreg <-
  cells |>
  pivot_wider(names_from = sex, values_from = c(dx, pop, exp)) |>
  mutate(
    sr_reg = (dx_m / pop_m) / (dx_f / pop_f),
    sr_dane = (exp_m / pop_m) / (exp_f / pop_f),
    log_gap = log(sr_reg / sr_dane),   # < 0: men under-registered relative to women
    caribe = cod_dpto %in% cod_caribe
  )

cat("\nlog(registered / DANE-expected) sex ratio at ages 50-79: 0 = same differential\n")
print(
  diffreg |> summarise(n_na = sum(is.na(log_gap)), mean = mean(log_gap, na.rm = TRUE), sd = sd(log_gap, na.rm = TRUE), min = min(log_gap, na.rm = TRUE), max = max(log_gap, na.rm = TRUE), .by = c(period, caribe)) |>
    arrange(caribe, period) |> mutate(across(where(is.numeric), ~ round(.x, 3))) |> as.data.frame(),
  row.names = FALSE
)
write_csv(diffreg |> select(area, cod_dpto, period, sr_reg, sr_dane, log_gap, caribe), "output/tables/age_placebo_reg_vs_dane_50_79.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. does the 50-79 ratio track homicide? ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

hom <-
  d |>
  summarise(v = sum(dx_homicide + dx_undetermined + dx_legal), pop = sum(pop, na.rm = TRUE), .by = c(year, cod_dpto)) |>
  mutate(log_h = log(v / pop))

pl <-
  sr |>
  select(year, cod_dpto, dpto, band, sr, caribe) |>
  pivot_wider(names_from = band, values_from = sr, names_prefix = "sr_") |>
  left_join(hom |> select(year, cod_dpto, log_h), by = c("year", "cod_dpto")) |>
  filter(is.finite(log_h)) |>
  mutate(per = ifelse(year < 1998, "1985-1997", "1998-2017"), lsr_old = log(`sr_50-79`), lsr_young = log(`sr_15-44`)) |>
  filter(year <= 2017)

r_pl <-
  pl |>
  arrange(cod_dpto, year) |>
  summarise(r_young = cor(lsr_young, log_h), r_old = cor(lsr_old, log_h),
            rd_young = cor(diff(lsr_young), diff(log_h)), rd_old = cor(diff(lsr_old), diff(log_h)), n = n(),
            .by = c(cod_dpto, dpto, per, caribe))
cat("\nwithin-department correlation with log homicide rate (mean over departments)\n")
print(r_pl |> summarise(young_levels = mean(r_young, na.rm = TRUE), old_levels = mean(r_old, na.rm = TRUE), young_diff = mean(rd_young, na.rm = TRUE), old_diff = mean(rd_old, na.rm = TRUE), .by = c(per, caribe)) |>
        arrange(caribe, per) |> mutate(across(where(is.numeric), ~ round(.x, 2))) |> as.data.frame(), row.names = FALSE)
write_csv(r_pl, "output/tables/age_placebo_correlations.csv")
