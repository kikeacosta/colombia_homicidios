# 09_sex_ratio_by_cause.R ----------------------------------------------------
# cause-specific decomposition of the all-cause mortality sex ratio by
# department and year. the question: which causes carry the excess male
# mortality, and does the answer change around 1998 in the Caribbean?
#
# for each department-year, with mx_c,s the cause-specific death rate,
#     ratio - 1 = sum_c (mx_c,m - mx_c,f) / CDR_f
# so each cause's contribution to the excess of the ratio over 1 is
#     cont_c = (mx_c,m - mx_c,f) / CDR_f,   and   cont_per_c = cont_c / (ratio - 1).
# cont_pos_per is the share of the *positive* contributions only, which is
# easier to read where some causes have a female excess.
#
# (formerly 11_sex_ratio_decomp_by_cause.R; reordered, and the join on a
# non-existent `dpto` column removed)

rm(list = ls())
gc()
source("code/00_setup.R")

dt <- read_rds("data_inter/micro_1979_2023.rds")
pop <- read_rds("data_inter/pop_munic_1985-2017.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# inputs ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dptos <- pop |> distinct(cod_dpto, dpto)
munic_codes <- pop |> distinct(cod_munic)

pop_dpto_sx <-
  pop |>
  filter(sex %in% c("m", "f"), year %in% yrs_analysis) |>
  summarise(pop = sum(pop), .by = c(year, cod_dpto, dpto, sex))

# deaths by department, broad cause and sex (municipalities in the projection only)
dx_cause <-
  dt |>
  as_tibble() |>
  filter(ano %in% yrs_analysis, !is.na(sexo)) |>
  mutate(cod_munic = make_cod_munic(cod_dpto, cod_munic)) |>
  semi_join(munic_codes, by = "cod_munic") |>
  mutate(
    cod_dpto = str_sub(cod_munic, 1, 2),
    cause = recode_cause_broad(cod_col)
  ) |>
  rename(year = ano, sex = sexo) |>
  summarise(dx = n(), .by = c(year, cod_dpto, cause, sex))

print(dx_cause |> summarise(dx = sum(dx), .by = cause) |> arrange(-dx))

# cause-specific rates
mx_cause <-
  dx_cause |>
  left_join(pop_dpto_sx, by = c("year", "cod_dpto", "sex")) |>
  mutate(mx = dx / pop)

# all-cause rates and the sex ratio
ratio_dept <-
  mx_cause |>
  summarise(dx = sum(dx), pop = first(pop), .by = c(year, cod_dpto, dpto, sex)) |>
  mutate(mx = dx / pop) |>
  select(year, cod_dpto, dpto, sex, mx) |>
  pivot_wider(names_from = sex, values_from = mx) |>
  mutate(ratio = m / f)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# decomposition ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

contrib <-
  mx_cause |>
  select(year, cod_dpto, dpto, cause, sex, mx) |>
  complete(nesting(year, cod_dpto, dpto), cause, sex, fill = list(mx = 0)) |>
  pivot_wider(names_from = sex, values_from = mx) |>
  left_join(
    ratio_dept |> select(year, cod_dpto, cdr_f = f, r_tot = ratio),
    by = c("year", "cod_dpto")
  ) |>
  mutate(
    diff = m - f,
    cont = diff / cdr_f,
    cont_per = cont / (r_tot - 1),
    cont_pos = ifelse(cont > 0, cont, 0)
  ) |>
  mutate(cont_pos_per = cont_pos / sum(cont_pos), .by = c(year, cod_dpto))

# identity check: contributions sum to 1 within each department-year
# department-years with an undefined or exactly 1 ratio have no decomposition
chk <- contrib |>
  filter(is.finite(r_tot), abs(r_tot - 1) > 1e-6) |>
  summarise(s = sum(cont_per), .by = c(year, cod_dpto))
print(summary(abs(chk$s - 1)))
stopifnot(all(abs(chk$s - 1) < 1e-6, na.rm = TRUE))

# mean contributions in the Caribbean, 2009 (a post-transition reference year)
print(
  contrib |>
    filter(year == 2009, cod_dpto %in% cod_caribe) |>
    summarise(cont_per = mean(cont_per), .by = cause) |>
    arrange(-cont_per)
)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# plots: contributions ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

carib5 <- c("44", "23", "47", "70", "08") # La Guajira, Cordoba, Magdalena, Sucre, Atlantico

contrib |>
  filter(cod_dpto %in% carib5) |>
  ggplot() +
  geom_line(aes(year, cont_per, color = cause)) +
  geom_vline(xintercept = 1998, lty = "dashed", alpha = 0.5) +
  facet_wrap(~dpto) +
  coord_cartesian(ylim = c(-1, 1)) +
  labs(title = "Cause contributions to the all-cause sex ratio (share of ratio - 1)", x = NULL, y = NULL) +
  theme_minimal()
ggsave("figures/contrib_ratio_all_causes.png", width = 10, height = 6)

contrib |>
  filter(cod_dpto %in% carib5, cause %in% c("mal_definidas", "otras")) |>
  ggplot() +
  geom_line(aes(year, cont_per, color = cause)) +
  geom_vline(xintercept = 1998, lty = "dashed", alpha = 0.5) +
  facet_wrap(~dpto) +
  labs(title = "Contribution of ill-defined and residual causes", x = NULL, y = NULL) +
  theme_minimal()
ggsave("figures/contrib_ratio_mal_definidas.png", width = 10, height = 6)

contrib |>
  filter(cod_dpto %in% c(carib5, "20")) |>
  ggplot() +
  geom_tile(aes(year, cause, fill = cont_per)) +
  scale_fill_gradient2(low = "blue", high = "red", midpoint = 0, limits = c(-1, 1), oob = scales::squish) +
  geom_vline(xintercept = 1997.5, lty = "dashed") +
  facet_grid(~dpto) +
  labs(x = NULL, y = NULL, fill = "share") +
  theme_bw() +
  theme(axis.text.x = element_text(size = 6))
ggsave("figures/contrib_ratio_tiles_caribe.png", width = 14, height = 5)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# plots: standardised ratio vs alternative violence series ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# does the sex ratio track homicides better once undetermined-intent,
# ill-defined/residual, or all external deaths are added to the homicide series?

std_series <- function(causes, name) {
  mx_cause |>
    filter(cause %in% causes) |>
    summarise(dx = sum(dx), .by = c(year, cod_dpto, dpto)) |>
    left_join(
      pop_dpto_sx |> summarise(pop = sum(pop), .by = c(year, cod_dpto)),
      by = c("year", "cod_dpto")
    ) |>
    mutate(value = minmax(dx / pop), .by = cod_dpto) |>
    mutate(metric = name) |>
    select(year, cod_dpto, dpto, metric, value)
}

ratio_homs <-
  bind_rows(
    ratio_dept |>
      mutate(value = minmax(ratio), .by = cod_dpto) |>
      mutate(metric = "ratio_std") |>
      select(year, cod_dpto, dpto, metric, value),
    std_series("homicidio", "homs_std"),
    std_series(c("homicidio", "violnt_sin_det"), "homs_ind_std"),
    std_series(c("homicidio", "violnt_sin_det", "mal_definidas", "otras"), "homs_mal_std"),
    std_series(c("accidente", "suicidio", "homicidio", "violnt_sin_det"), "exts_std")
  ) |>
  mutate(metric = factor(metric, levels = c("ratio_std", "homs_std", "homs_ind_std", "homs_mal_std", "exts_std")))

ratio_homs |>
  filter(cod_dpto %in% carib5) |>
  ggplot() +
  geom_line(aes(year, value, color = metric, linewidth = metric), alpha = 0.7) +
  scale_color_manual(values = c("black", "#1d3557", "#606c38", "#CA6702", "#9B2226")) +
  scale_linewidth_manual(values = c(1.5, 0.8, 0.8, 0.8, 0.8)) +
  facet_wrap(~dpto) +
  labs(x = NULL, y = "min-max standardised", color = NULL, linewidth = NULL) +
  theme_minimal()
ggsave("figures/ratio_homs_ext.png", width = 12, height = 8)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# smoothed positive contributions ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# P-spline smoother on each department x cause series of cont_pos_per, to see
# the slow movement under the year-to-year noise, and its year-on-year change

smooth_conts <- function(chunk) {
  # sparse series (few years, all zeros) cannot support the spline: return NA
  sm <- tryCatch(
    predict(
      gam(cont_pos_per ~ s(year, bs = "ps", k = 6), data = chunk, family = "quasipoisson"),
      newdata = chunk,
      type = "response"
    ),
    error = function(e) rep(NA_real_, nrow(chunk))
  )
  chunk |> mutate(cnt_sm = as.numeric(sm))
}

contrib_sm <-
  contrib |>
  filter(!is.na(cont_pos_per)) |>
  group_by(cod_dpto, dpto, cause) |>
  group_modify(~ smooth_conts(.x)) |>
  ungroup() |>
  arrange(cod_dpto, cause, year) |>
  mutate(ch = cnt_sm / lag(cnt_sm), .by = c(cod_dpto, cause))

contrib_sm |>
  filter(
    cod_dpto %in% c(cod_caribe, "05", "11", "68"),
    !cause %in% c("homicidio", "accidente", "circulatoria")
  ) |>
  ggplot() +
  geom_line(aes(year, cnt_sm, col = cause)) +
  geom_vline(xintercept = 1998, lty = "dashed") +
  facet_wrap(~dpto, scales = "free_y") +
  labs(title = "Smoothed share of positive contributions to the sex ratio", x = NULL, y = NULL) +
  theme_bw()
ggsave("figures/contrib_ratio_smoothed.png", width = 12, height = 8)

contrib_sm |>
  filter(cod_dpto %in% c("47", "70", "08", "20")) |>
  ggplot() +
  geom_tile(aes(year, cause, fill = ch)) +
  scale_fill_gradient2(low = "blue", high = "red", midpoint = 1, limits = c(0.5, 1.5), oob = scales::squish) +
  facet_grid(~dpto) +
  labs(x = NULL, y = NULL, fill = "year-on-year\nchange") +
  theme_bw() +
  theme(axis.text.x = element_text(size = 6))
ggsave("figures/contrib_ratio_change_tiles.png", width = 12, height = 5)

write_rds(contrib, "data_inter/sex_ratio_contrib_by_cause.rds")
