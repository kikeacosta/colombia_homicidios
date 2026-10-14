# 05_municipal_panel.R -------------------------------------------------------
# builds the two municipal inputs of the model from the panel:
#   data_inter/sex_ratios_munic_1985-2017.rds   sex ratio of all-cause CDR
#   data_inter/homicide_cdr_munic_1985-2017.rds violent deaths, population,
#                                               department rates
# (formerly 06_sex_ratios_munic.R)

rm(list = ls())
gc()
source("code/00_setup.R")

pop <- read_rds("data_inter/pop_munic_1985-2017.rds")
dts <- read_rds("data_inter/deaths_munic_1979-2023.rds")

panel <- build_munic_panel(dts, pop)
dept_rates <- dept_rates_from_panel(panel)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# fallback sex ratio ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# average all-cause sex ratio in municipality-years with (near) zero violent
# deaths. used where a municipality-year has no population match.

rt_av <-
  panel |>
  filter(cdr_v < 1e-5) |>
  summarise(dx_tot = sum(dx_tot), pop = sum(pop, na.rm = TRUE), .by = c(year, sex)) |>
  mutate(cdr = dx_tot / pop) |>
  select(year, sex, cdr) |>
  pivot_wider(names_from = sex, values_from = cdr) |>
  mutate(sex_rt = m / f)

rt_av |>
  ggplot() +
  geom_line(aes(year, sex_rt)) +
  labs(title = "All-cause sex ratio in municipality-years with ~no violent deaths", x = NULL, y = NULL) +
  theme_bw()
ggsave("figures/sex_ratio_low_violence_munics.png", w = 6, h = 3)

sex_rt_av <- mean(rt_av$sex_rt, na.rm = TRUE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# sex ratio of all-cause CDR by municipality ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# uses cdr2 = (deaths + 5) / pop, which pulls the ratio toward 1 in
# municipalities with very few deaths

sex_r <-
  panel |>
  select(cod_munic, munic, year, sex, cdr = cdr2, dts = dx_tot) |>
  pivot_wider(names_from = sex, values_from = c(cdr, dts)) |>
  mutate(sex_r = cdr_m / cdr_f) |>
  replace_na(list(sex_r = sex_rt_av))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# violent deaths by municipality (both sexes) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

cdr_h <-
  panel |>
  summarise(
    dts = sum(dx_tot),
    dts_v = sum(dx_v),
    pop = sum(pop, na.rm = TRUE),
    .by = c(year, cod_dpto, dpto, cod_munic, munic)
  ) |>
  mutate(
    cdr_h = ifelse(dts_v == 0 | pop == 0, 0, dts_v / pop),
    cdr = ifelse(dts == 0 | pop == 0, 0, dts / pop)
  ) |>
  left_join(dept_rates, by = c("year", "cod_dpto", "dpto")) |>
  replace_na(list(cdr_dpto = 0, cdr_h_dpto = 0))

print(cdr_h |> summarise(dts_v = sum(dts_v), pop = sum(pop), .by = year) |> mutate(cdr_h = 1e5 * dts_v / pop), n = 40)

write_rds(sex_r, "data_inter/sex_ratios_munic_1985-2017.rds")
write_rds(cdr_h, "data_inter/homicide_cdr_munic_1985-2017.rds")
