# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 29. Extend the age-specific rates back from 1950 with the LAMBdA tables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Our series (WPP 2024 without its conflict component plus the MSE
# correction, 27) starts in 1950. LAMBdA publishes abridged life tables for
# the pivotal years 1905, 1908, 1912, 1915, 1918, 1923, 1928, 1933, 1938 and
# 1944 (Colombia), and annual 1x1 tables from 1950. The two are linked the
# way colombia_bereavement_pdr/code/02_bereav/02c_historic_mx_interpolation.R
# links LAMBdA with WPP: the pivotal-year rates are taken as anchors and a
# P-spline GAM (quasi-Poisson, weights 1 on observed years) is fitted to
# log-mortality over calendar time for each age group and sex, together with
# our own annual rates from 1950 on, and evaluated for 1905-1949.
#
# One difference: LAMBdA's level differs from WPP's (its Bennett-Horiuchi
# adjustment gives 5-15% higher adult mortality in 1950-1957, 28), so the
# historic LAMBdA rates are first rescaled, by sex and age group, by the
# ratio of our rates to the LAMBdA 1x1 rates over 1950-1957. This keeps
# LAMBdA's trend and removes the level offset at the junction; the choice is
# a convention and both scaled and unscaled anchors are drawn.
#
# output: output/tables/mx_extended_1905-2023.csv
#           (year, sex, age, mx, src: "LAMBdA interpolado" / "WPP sin
#            confl. + MSE")
#         output/tables/lifetables_extended_summary.csv (e0, e15, 45q15 by
#           year and sex, 1905-2023)
#         figures/04_completeness/mx_extended_back.png
#         figures/04_completeness/e0_extended_back.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(mgcv)

age_top <- 80
ages <- c(0, 1, seq(5, age_top, 5))
grp5 <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), age_top))
link_years <- 1950:1957       # overlap used to rescale LAMBdA to our level
fit_years <- 1950:1965        # our years entering the GAM with the anchors
first_year <- 1905

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# inputs ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ours <-
  read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |>
  transmute(year, sex, age, mx = expected / pop)

# LAMBdA abridged tables for the pivotal years (life-table deaths / Lx within
# our age groups, 80 and 85+ collapsed)
lambda_piv <-
  read_csv("I:/My Drive/gits_drive/colombia_bereavement_pdr/data_input/life_tables_lambda.csv", show_col_types = FALSE) |>
  filter(year < 1950) |>
  mutate(sex = if_else(Sex == "Males", "m", "f"), age = grp5(age), dx = lx * qx) |>
  summarise(mx = sum(dx) / sum(Lx), .by = c(year, sex, age))

# LAMBdA 1x1 tables over the link years, same groups
lambda_1x1 <-
  map_dfr(c(m = "mltper", f = "fltper"), \(f) read_table(paste0("data_input/historical/lambda_Col_", f, "_1x1.txt"), show_col_types = FALSE), .id = "sex") |>
  filter(year %in% link_years) |>
  mutate(age = grp5(as.integer(str_remove(age, fixed("+"))))) |>
  summarise(mx = sum(lx * qx) / sum(Lx), .by = c(year, sex, age))

# level link: our rates / LAMBdA rates, 1950-1957
link <-
  ours |> filter(year %in% link_years) |> summarise(ours = mean(mx), .by = c(sex, age)) |>
  inner_join(lambda_1x1 |> summarise(lambda = mean(mx), .by = c(sex, age)), by = c("sex", "age")) |>
  mutate(ratio = ours / lambda)
cat("level ratio ours / LAMBdA, 1950-1957, by age group:\n")
print(link |> mutate(ratio = round(ratio, 3)) |> select(sex, age, ratio) |> pivot_wider(names_from = sex, values_from = ratio) |> as.data.frame())

anchors <-
  lambda_piv |>
  inner_join(link |> select(sex, age, ratio), by = c("sex", "age")) |>
  mutate(mx_raw = mx, mx = mx * ratio)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# GAM over calendar year, per sex and age group ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# anchors (scaled) plus our annual rates 1950-1965; quasi-Poisson P-spline
# on the rate with weights 1 on observed years, as in the bereavement script
# (gamma 0.6); evaluated on 1905-1949
fit_one <- function(d) {
  grid <- tibble(year = first_year:max(fit_years)) |> left_join(d, by = "year") |> mutate(w = as.integer(!is.na(mx)))
  k <- min(12, sum(grid$w) - 1)
  md <- gam(mx ~ s(year, bs = "ps", k = k), weights = w, data = grid |> mutate(mx = replace_na(mx, 0)),
            family = quasipoisson(), gamma = 0.6)
  pred <- tibble(year = first_year:1950, mx = as.numeric(predict(md, newdata = tibble(year = first_year:1950), type = "response")))
  # continuity at the junction: the smooth does not pass exactly through our
  # 1950 value, so the segment after the last anchor (1944) is multiplied by
  # a factor that grows geometrically from 1 in 1944 to observed/fitted in
  # 1950; the anchors themselves are untouched
  last_anchor <- max(d$year[d$year < 1950])
  r <- d$mx[d$year == 1950] / pred$mx[pred$year == 1950]
  pred |> filter(year < 1950) |>
    mutate(mx = mx * r^pmax(0, (year - last_anchor) / (1950 - last_anchor)))
}

back <-
  bind_rows(anchors |> select(year, sex, age, mx), ours |> filter(year %in% fit_years)) |>
  group_by(sex, age) |>
  group_modify(\(d, k) fit_one(d)) |>
  ungroup() |>
  mutate(src = "LAMBdA interpolado")

mx_ext <-
  bind_rows(back, ours |> mutate(src = "WPP sin confl. + MSE")) |>
  arrange(sex, age, year)
write_csv(mx_ext, "output/tables/mx_extended_1905-2023.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# life tables ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lifetable <- function(age, mx, sex) {
  n <- c(diff(age), Inf)
  m0 <- mx[1]
  a0 <- if (sex == "m") { if (m0 < 0.023) 0.14929 - 1.99545 * m0 else if (m0 < 0.08307) 0.02832 + 3.26201 * m0 else 0.29915 } else
                        { if (m0 < 0.01724) 0.14903 - 2.05527 * m0 else if (m0 < 0.06891) 0.04667 + 3.88089 * m0 else 0.31411 }
  a1 <- if (sex == "m") { if (m0 < 0.023) 1.6534 else if (m0 < 0.08307) 1.5806 else 1.3607 } else
                        { if (m0 < 0.01724) 1.6338 else if (m0 < 0.06891) 1.5265 else 1.3062 }
  ax <- c(a0, a1, rep(2.5, length(age) - 3), 1 / mx[length(age)])
  qx <- n * mx / (1 + (n - ax) * mx); qx[length(age)] <- 1
  lx <- c(1, cumprod(1 - qx))[seq_along(age)]
  dx <- lx * qx
  Lx <- n * (lx - dx) + ax * dx; Lx[length(age)] <- lx[length(age)] / mx[length(age)]
  Tx <- rev(cumsum(rev(Lx)))
  tibble(age, mx, qx, lx, ex = Tx / lx)
}
lt_summary <- function(d) {
  d |> arrange(sex, year, age) |> group_by(sex, year) |> reframe(lifetable(age, mx, first(sex))) |>
    summarise(e0 = ex[age == 0], e15 = ex[age == 15], `5q0` = 1 - lx[age == 5], `45q15` = 1 - lx[age == 60] / lx[age == 15], .by = c(sex, year))
}

summ <- lt_summary(mx_ext |> select(year, sex, age, mx)) |> left_join(mx_ext |> distinct(year, src), by = "year")
write_csv(summ, "output/tables/lifetables_extended_summary.csv")
summ_lambda <- lt_summary(lambda_piv) |> mutate(src = "LAMBdA pivotal (sin reescalar)")
summ_anch <- lt_summary(anchors |> select(year, sex, age, mx)) |> mutate(src = "LAMBdA pivotal (reescalado)")

cat("\ne0 / e15 / 45q15 (x1000), extended series, selected years:\n")
print(summ |> filter(year %in% c(1905, 1910, 1920, 1930, 1938, 1944, 1950, 1960)) |>
        transmute(year, sex, cell = sprintf("%.1f / %.1f / %3.0f", e0, e15, 1000 * `45q15`)) |>
        pivot_wider(names_from = sex, values_from = cell) |> as.data.frame())
cat("\nLAMBdA pivotal years, unscaled, same indicators:\n")
print(summ_lambda |> transmute(year, sex, cell = sprintf("%.1f / %.1f / %3.0f", e0, e15, 1000 * `45q15`)) |>
        pivot_wider(names_from = sex, values_from = cell) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lab_sex <- \(s) factor(s, c("f", "m"), c("Mujeres", "Hombres"))
age_lab <- \(a) factor(a, ages, c("0", "1-4", paste0(seq(5, age_top - 5, 5), "-", seq(9, age_top - 1, 5)), paste0(age_top, "+")))

mx_ext |>
  filter(year <= 1975) |>
  mutate(sex = lab_sex(sex), age_lab = age_lab(age)) |>
  ggplot(aes(year, mx)) +
  geom_line(aes(col = src), linewidth = 0.6) +
  geom_point(data = anchors |> mutate(sex = lab_sex(sex), age_lab = age_lab(age)), aes(y = mx_raw), shape = 1, col = "#CA6702", size = 1.3) +
  geom_point(data = anchors |> mutate(sex = lab_sex(sex), age_lab = age_lab(age)), shape = 16, col = "#CA6702", size = 1.3) +
  facet_grid(age_lab ~ sex, scales = "free_y") +
  scale_y_log10() +
  scale_color_manual(values = c("LAMBdA interpolado" = "#9B2226", "WPP sin confl. + MSE" = "#0A9396")) +
  labs(title = "Tasas de mortalidad por grupo de edad, 1905-1975: extensión hacia atrás con LAMBdA",
       subtitle = "Puntos: tablas pivotales LAMBdA (vacíos: originales; llenos: reescalados al nivel de nuestra serie en 1950-57). Línea roja: GAM sobre anclas y serie 1950-65",
       x = NULL, y = "Tasa (escala log)", col = NULL) +
  theme_bw() + theme(legend.position = "bottom", strip.text.y = element_text(angle = 0))
ggsave("figures/04_completeness/mx_extended_back.png", w = 10, h = 16)

bind_rows(summ |> select(year, sex, e0, e15, src), summ_lambda |> select(year, sex, e0, e15, src), summ_anch |> select(year, sex, e0, e15, src)) |>
  pivot_longer(c(e0, e15), names_to = "ind", values_to = "value") |>
  filter(year <= 1975) |>
  mutate(sex = lab_sex(sex), pivot = str_detect(src, "pivotal")) |>
  ggplot(aes(year, value, col = src)) +
  geom_line(data = \(d) filter(d, !pivot), linewidth = 0.7) +
  geom_point(data = \(d) filter(d, pivot), aes(shape = src), size = 2) +
  facet_grid(ind ~ sex, scales = "free_y") +
  scale_color_manual(values = c("LAMBdA interpolado" = "#9B2226", "WPP sin confl. + MSE" = "#0A9396",
                                "LAMBdA pivotal (sin reescalar)" = "#CA6702", "LAMBdA pivotal (reescalado)" = "#CA6702")) +
  scale_shape_manual(values = c("LAMBdA pivotal (sin reescalar)" = 1, "LAMBdA pivotal (reescalado)" = 16)) +
  labs(title = "Esperanza de vida a 0 y 15 años, 1905-1975: serie extendida y tablas pivotales LAMBdA",
       x = NULL, y = "Años", col = NULL, shape = NULL) +
  theme_bw() + theme(legend.position = "bottom") + guides(col = guide_legend(nrow = 2))
ggsave("figures/04_completeness/e0_extended_back.png", w = 10, h = 7)
