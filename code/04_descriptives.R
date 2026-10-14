# 04_descriptives.R ----------------------------------------------------------
# descriptive analysis of the relationship between the all-cause mortality sex
# ratio and homicide rates at national, department and municipal level.
# merges the former 04_rates.R (age-standardised municipal rates and the
# scatter clouds) and the department part of 05_sex_ratios_deptos.R.
#
# nothing downstream depends on this script except
# data_inter/asdr_munic_1985-2017.rds (age-standardised municipal rates, used
# in the under-registration work).
#
# "homicides" throughout = dx_v (codes 101-103), as in the model.

rm(list = ls())
gc()
source("code/00_setup.R")

pop <- read_rds("data_inter/pop_munic_1985-2017.rds")
dts <- read_rds("data_inter/deaths_munic_1979-2023.rds")
dts_age <- read_rds("data_inter/deaths_munic_age_1979-2023.rds")

panel <- build_munic_panel(dts, pop)
dptos <- pop |> distinct(cod_dpto, dpto)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# national ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

nal_sx <-
  panel |>
  summarise(
    dx_tot = sum(dx_tot),
    dx_v = sum(dx_v),
    pop = sum(pop, na.rm = TRUE),
    .by = c(year, sex)
  )

nal <-
  nal_sx |>
  summarise(across(c(dx_tot, dx_v, pop), sum), .by = year) |>
  mutate(cdr_h = dx_v / pop)

nal_sexr <-
  nal_sx |>
  mutate(cdr = dx_tot / pop) |>
  select(year, sex, cdr) |>
  pivot_wider(names_from = sex, values_from = cdr) |>
  mutate(sex_r = m / f)

nal |>
  ggplot() +
  geom_line(aes(year, dx_v)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  labs(title = "Violent deaths (homicide, undetermined intent, legal intervention)", y = "deaths", x = NULL) +
  theme_bw()
ggsave("figures/01_descriptives/homicide_counts.png", w = 6, h = 3)

nal |>
  ggplot() +
  geom_line(aes(year, cdr_h * 1e5)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  labs(title = "Crude violent-death rate", y = "per 100,000", x = NULL) +
  theme_bw()
ggsave("figures/01_descriptives/homicide_cdr.png", w = 6, h = 3)

nal_sexr |>
  ggplot() +
  geom_line(aes(year, sex_r)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  labs(title = "Sex ratio of all-cause mortality (male CDR / female CDR)", y = NULL, x = NULL) +
  theme_bw()
ggsave("figures/01_descriptives/sex_ratios_all_cause_cdr.png", w = 6, h = 3)

# both series min-max standardised and overlaid
nal_std <-
  nal |>
  select(year, cdr_h) |>
  left_join(nal_sexr |> select(year, sex_r), by = "year") |>
  mutate(cdr_h_std = minmax(cdr_h), sex_r_std = minmax(sex_r))

type_labels <- c(
  cdr_h_std = "standardized CDR homicides",
  sex_r_std = "standardized sex ratio all-cause"
)

nal_std |>
  pivot_longer(ends_with("_std"), names_to = "type", values_to = "std") |>
  mutate(type = type_labels[type]) |>
  ggplot() +
  geom_line(aes(year, std, col = type)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  scale_color_manual(values = c("red", "blue")) +
  labs(title = "Sex ratio of all-cause mortality and homicide CDR, Colombia", x = NULL, y = NULL, col = NULL) +
  theme_bw() +
  theme(legend.position = "bottom")
ggsave("figures/01_descriptives/sex_ratios_and_cdr_homics_plus.png", w = 6, h = 4)

# a first linear test at national level
m_nal <- lm(cdr_h_std ~ sex_r_std, data = nal_std)
print(summary(m_nal))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# departments ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dep_sx <-
  panel |>
  summarise(
    dx_tot = sum(dx_tot),
    dx_v = sum(dx_v),
    pop = sum(pop, na.rm = TRUE),
    .by = c(year, cod_dpto, dpto, sex)
  )

dep <-
  dep_sx |>
  summarise(across(c(dx_tot, dx_v, pop), sum), .by = c(year, cod_dpto, dpto)) |>
  mutate(cdr_h = dx_v / pop)

dep_sexr <-
  dep_sx |>
  mutate(cdr = dx_tot / pop) |>
  select(year, cod_dpto, dpto, sex, cdr) |>
  pivot_wider(names_from = sex, values_from = cdr) |>
  mutate(sex_r = m / f)

dep_std <-
  dep |>
  select(year, cod_dpto, dpto, cdr_h) |>
  left_join(dep_sexr |> select(year, cod_dpto, sex_r), by = c("year", "cod_dpto")) |>
  mutate(
    cdr_h_std = minmax(cdr_h),
    sex_r_std = minmax(sex_r),
    .by = cod_dpto
  ) |>
  mutate(diff = sex_r_std - cdr_h_std)

dep_sexr |>
  filter(cod_dpto == "05") |>
  ggplot() +
  geom_line(aes(year, sex_r)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  labs(title = "Sex ratio of all-cause mortality, Antioquia", x = NULL, y = NULL) +
  theme_bw()
ggsave("figures/01_descriptives/sex_ratio_all_cause_antioquia.png", w = 6, h = 3)

plot_dep_overlay <- function(d, file, w, h, nrow = 3) {
  p <-
    d |>
    pivot_longer(ends_with("_std"), names_to = "type", values_to = "std") |>
    mutate(type = type_labels[type]) |>
    ggplot() +
    facet_wrap(~dpto, nrow = nrow) +
    geom_line(aes(year, std, col = type)) +
    scale_x_continuous(breaks = seq(1985, 2020, 5)) +
    scale_color_manual(values = c("red", "blue")) +
    labs(title = "Sex ratio of all-cause mortality and homicide CDR, standardised", x = NULL, y = NULL, col = NULL) +
    theme_bw() +
    theme(legend.position = "bottom")
  ggsave(file, p, w = w, h = h)
}

# departments with more than 500,000 inhabitants in 2017 (both sexes)
dptos_lrg <-
  pop |>
  filter(year == 2017, sex %in% c("m", "f")) |>
  summarise(pop = sum(pop), .by = cod_dpto) |>
  filter(pop > 5e5) |>
  pull(cod_dpto)

plot_dep_overlay(dep_std |> filter(cod_dpto %in% dptos_lrg), "figures/01_descriptives/sex_ratios_and_cdr_dptos_large.png", w = 12, h = 7)
plot_dep_overlay(dep_std, "figures/01_descriptives/sex_ratios_and_cdr_dptos.png", w = 12, h = 7)
# Antioquia, Valle del Cauca, Bogota, Caqueta
plot_dep_overlay(dep_std |> filter(cod_dpto %in% c("05", "76", "11", "18")), "figures/01_descriptives/sex_ratios_and_cdr_dptos_sel.png", w = 8, h = 5, nrow = 2)

# gap between the two standardised series: positive = the sex ratio runs above
# what homicides would suggest. the Caribbean departments open a gap before
# ~1998 that the interior ones do not.
dep_std |>
  filter(cod_dpto %in% c(cod_caribe, "05", "11", "68")) |>
  ggplot() +
  geom_line(aes(year, diff)) +
  geom_hline(yintercept = 0, lty = "dashed") +
  geom_vline(xintercept = 1998, lty = "dotted", alpha = 0.5) +
  facet_wrap(~dpto) +
  labs(title = "Standardised sex ratio minus standardised homicide CDR", x = NULL, y = NULL) +
  theme_bw()
ggsave("figures/01_descriptives/sex_ratio_minus_homicide_std.png", w = 9, h = 6)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# municipalities: age-standardised rates and sex ratios ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# standard: Colombia 2017 age structure (sex-specific for sex-specific rates)

munic_codes <- pop |> distinct(cod_dpto, dpto, cod_munic, munic)

pop_age <-
  pop |>
  filter(sex %in% c("m", "f"), year %in% yrs_analysis) |>
  select(cod_munic, year, sex, age, pop)

std_nal <-
  pop_age |>
  filter(year == 2017) |>
  summarise(pop = sum(pop), .by = c(sex, age)) |>
  mutate(cx_sx_std = pop / sum(pop), .by = sex) |>
  mutate(cx_std = pop / sum(pop)) |>
  select(-pop)

ages <- sort(unique(std_nal$age))

# deaths by age, top interval aligned with the projection's open interval (85+)
dx_age <-
  dts_age |>
  filter(year %in% yrs_analysis, !is.na(sex), !is.na(age)) |>
  mutate(
    cod_munic = make_cod_munic(cod_dpto, cod_munic),
    age = pmin(age, age_open)
  ) |>
  semi_join(munic_codes, by = "cod_munic") |>
  summarise(all = sum(dx_tot), homic = sum(dx_v), .by = c(cod_munic, year, sex, age)) |>
  complete(
    cod_munic = munic_codes$cod_munic,
    year = yrs_analysis,
    sex = c("m", "f"),
    age = ages,
    fill = list(all = 0, homic = 0)
  )

rates_age <-
  dx_age |>
  left_join(pop_age, by = c("cod_munic", "year", "sex", "age")) |>
  drop_na(pop) |>
  left_join(std_nal, by = c("sex", "age")) |>
  # NB grouped by code, not by name: municipality names repeat across departments
  mutate(cx = pop / sum(pop), .by = c(cod_munic, year)) |>
  mutate(cx_sx = pop / sum(pop), .by = c(cod_munic, year, sex)) |>
  pivot_longer(c(all, homic), names_to = "cause", values_to = "dx") |>
  mutate(mx = ifelse(pop > 0, dx / pop, 0))

# both sexes: crude (sum mx * own structure) and age-standardised rates
rates <-
  rates_age |>
  summarise(
    dts = sum(dx),
    pop = sum(pop),
    cdr = sum(mx * cx),
    asdr = sum(mx * cx_std),
    .by = c(cod_munic, year, cause)
  )

# by sex
rates_sx <-
  rates_age |>
  summarise(
    dts = sum(dx),
    cdr = sum(mx * cx_sx),
    asdr = sum(mx * cx_sx_std),
    .by = c(cod_munic, year, sex, cause)
  )

# sex ratios of all-cause death counts, CDRs and ASDRs
sex_ratios <-
  rates_sx |>
  filter(cause == "all") |>
  select(-cause) |>
  pivot_wider(names_from = sex, values_from = c(dts, cdr, asdr)) |>
  mutate(
    rt_dts = dts_m / dts_f,
    rt_cdr = cdr_m / cdr_f,
    rt_asdr = asdr_m / asdr_f
  ) |>
  select(cod_munic, year, rt_dts, rt_cdr, rt_asdr)

# share of population at the ages where homicide concentrates (15-49)
age_ratios <-
  pop_age |>
  summarise(
    pop_yng = sum(pop[age %in% 15:45]),
    pop_rest = sum(pop[!age %in% 15:45]),
    .by = c(cod_munic, year)
  ) |>
  mutate(rt_yng = pop_yng / pop_rest) |>
  select(cod_munic, year, rt_yng)

munic_rates <-
  rates |>
  pivot_wider(names_from = cause, values_from = c(dts, cdr, asdr)) |>
  left_join(sex_ratios, by = c("cod_munic", "year")) |>
  left_join(age_ratios, by = c("cod_munic", "year")) |>
  left_join(munic_codes, by = "cod_munic") |>
  select(cod_dpto, dpto, cod_munic, munic, year, pop, everything()) |>
  arrange(cod_munic, year)

write_rds(munic_rates, "data_inter/asdr_munic_1985-2017.rds")

# plots ----------------------------------------------------------------------

munic_rates |>
  ggplot() +
  geom_jitter(aes(year, cdr_homic, col = dpto), alpha = 0.5, size = 0.5) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  labs(x = NULL, y = "crude homicide rate", col = NULL) +
  theme_bw() +
  theme(legend.position = "bottom", legend.text = element_text(size = 6))
ggsave("figures/01_descriptives/cdr_all_munics.png", w = 10, h = 7)

# Medellin, Bogota, Curillo (Caqueta), Mapiripan (Meta)
munic_rates |>
  filter(cod_munic %in% c("05001", "11001", "18205", "50325")) |>
  ggplot() +
  geom_line(aes(year, cdr_homic * 1e5, col = munic)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5)) +
  labs(x = NULL, y = "crude homicide rate per 100,000", col = NULL) +
  theme_bw() +
  theme(legend.position = "bottom")
ggsave("figures/01_descriptives/cdr_few_munics.png", w = 10, h = 7)

# scatter of sex ratio vs homicide rate (log-log) with linear fit and r
plot_cloud <- function(d, x, y, xlab, ylab, file) {
  p <-
    d |>
    ggplot(aes({{ x }}, {{ y }})) +
    geom_point(aes(col = log(rt_yng)), alpha = 0.7, size = 0.5) +
    geom_smooth(method = "lm", color = "red", se = TRUE) +
    stat_cor(method = "pearson", label.x.npc = "left", label.y.npc = "top", p.accuracy = 0.0001, digits = 3) +
    stat_regline_equation(label.x.npc = "left", label.y.npc = "top", vjust = 3) +
    stat_regline_equation(label.x.npc = "left", label.y.npc = "top", vjust = 4.2, aes(label = after_stat(rr.label))) +
    scale_x_log10() +
    scale_y_log10() +
    coord_cartesian(ylim = c(1e-6, .1)) +
    labs(x = xlab, y = ylab, col = "log(pop 15-49 / rest)") +
    theme_bw()
  ggsave(file, p, w = 7, h = 5)
}

plot_cloud(munic_rates, rt_cdr, cdr_homic, "Sex ratio of all-cause CDR", "Crude homicide rate", "figures/01_descriptives/cdr_sex_r_cloud_reg.png")
plot_cloud(munic_rates |> filter(pop >= 1e5), rt_cdr, cdr_homic, "Sex ratio of all-cause CDR", "Crude homicide rate", "figures/01_descriptives/cdr_sex_r_cloud_reg_100Kplus.png")
plot_cloud(munic_rates |> filter(pop >= 1e5), rt_asdr, cdr_homic, "Sex ratio of all-cause ASDR", "Crude homicide rate", "figures/01_descriptives/sex_ratios_vs_homicide_asdr_100Kplus.png")
