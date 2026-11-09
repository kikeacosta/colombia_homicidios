# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 28. Abridged life tables by source and period
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Period life tables (ages 0, 1-4, 5-9, ..., 80+) from the age-specific
# rates of each source, averaged over five calendar years, by sex:
#   Registradas            registered deaths (22) / WPP population
#   WPP 2024               as published
#   WPP sin confl. + MSE   WPP without its conflict component plus the MSE
#                          correction (27)
#   LAMBdA                 adjusted 1x1 life tables collapsed to 5-year groups
#   DANE                   national abridged nmx of the DANE life tables,
#                          1985-2020 (five-year periods as published)
# All tables use the same nax conventions (a0 and 4a1 from Andreev-Kingkade,
# n/2 elsewhere, 1/m in the open group), so differences come from the rates.
#
# output: output/tables/lifetables_compared.csv (full tables)
#         output/tables/lifetables_compared_summary.csv (e0, e15, e65, 5q0,
#           45q15, 20q60 by source, period and sex)
#         figures/04_completeness/lifetables_compared_qx.png
#         figures/04_completeness/lifetables_compared_ex.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

age_top <- 80
ages <- c(0, 1, seq(5, age_top, 5))
grp5 <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), age_top))
periods <- tibble(start = c(1950, 1960, 1970, 1985, 1995, 2000, 2010, 2015)) |>
  mutate(period = paste0(start, "-", start + 4))
in_period <- function(y) {
  i <- findInterval(y, periods$start)
  ok <- i > 0 & y - periods$start[pmax(i, 1)] <= 4
  if_else(ok, periods$period[pmax(i, 1)], NA_character_)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rates by source, year, sex, age group ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
rates_annual <-
  bind_rows(
    exp |> transmute(src = "Registradas", year, sex, age, d = registered, pop),
    exp |> transmute(src = "WPP 2024", year, sex, age, d = wpp_total, pop),
    exp |> transmute(src = "WPP sin confl. + MSE", year, sex, age, d = expected, pop),
    map_dfr(c(m = "mltper", f = "fltper"), \(f) read_table(paste0("data_input/historical/lambda_Col_", f, "_1x1.txt"), show_col_types = FALSE), .id = "sex") |>
      mutate(age = grp5(as.integer(str_remove(age, fixed("+"))))) |>
      summarise(d = sum(lx * qx), pop = sum(Lx), .by = c(year, sex, age)) |> mutate(src = "LAMBdA")
  ) |>
  mutate(period = in_period(year)) |>
  filter(!is.na(period), !is.na(d))

# period rates: deaths / exposure summed over the five years
rates <-
  rates_annual |>
  summarise(mx = sum(d) / sum(pop), n_years = n_distinct(year), .by = c(src, period, sex, age)) |>
  filter(n_years == 5) |> select(-n_years)

# DANE: published by 5-year period, matching periods only
dane <-
  read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE) |>
  filter(area == "Nacional") |>
  mutate(start = as.integer(str_sub(period, 1, 4)), period = paste0(start, "-", start + 4), src = "DANE") |>
  filter(period %in% periods$period) |>
  select(src, period, sex, age, mx = nmx)

rates <- bind_rows(rates, dane)

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
  tibble(age, n, mx, ax, qx, lx, dx, Lx, Tx, ex = Tx / lx)
}

lt <-
  rates |>
  arrange(src, period, sex, age) |>
  group_by(src, period, sex) |>
  filter(n() == length(ages)) |>
  reframe(lifetable(age, mx, first(sex))) |>
  mutate(src = factor(src, c("Registradas", "WPP 2024", "WPP sin confl. + MSE", "LAMBdA", "DANE")))
write_csv(lt, "output/tables/lifetables_compared.csv")

summ <-
  lt |>
  summarise(e0 = ex[age == 0], e15 = ex[age == 15], e65 = ex[age == 65],
            `5q0` = 1 - lx[age == 5], `45q15` = 1 - lx[age == 60] / lx[age == 15], `20q60` = 1 - lx[age == 80] / lx[age == 60],
            .by = c(src, period, sex))
write_csv(summ, "output/tables/lifetables_compared_summary.csv")

for (s in c("m", "f")) {
  cat("\n", if (s == "m") "HOMBRES" else "MUJERES", "- e0 / e15 / 45q15 (x1000) by source and period\n")
  print(summ |> filter(sex == s) |>
          transmute(src, period, cell = sprintf("%.1f / %.1f / %3.0f", e0, e15, 1000 * `45q15`)) |>
          pivot_wider(names_from = period, values_from = cell) |> as.data.frame())
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
cols <- c("Registradas" = "grey45", "WPP 2024" = "#0A9396", "WPP sin confl. + MSE" = "#9B2226", "LAMBdA" = "#CA6702", "DANE" = "#4A4E69")
ltys <- c("Registradas" = "dotted", "WPP 2024" = "solid", "WPP sin confl. + MSE" = "solid", "LAMBdA" = "solid", "DANE" = "dashed")
lab_sex <- \(s) factor(s, c("f", "m"), c("Mujeres", "Hombres"))
age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, a == age_top ~ age_top + 5, TRUE ~ a + 2.5)

lt |>
  mutate(sex = lab_sex(sex), x = age_mid(age)) |>
  ggplot(aes(x, qx, col = src, lty = src)) +
  geom_line(linewidth = 0.6) + geom_point(size = 0.8) +
  facet_grid(sex ~ period) +
  scale_y_log10() +
  scale_color_manual(values = cols) + scale_linetype_manual(values = ltys) +
  labs(title = "Probabilidades de muerte por grupo de edad (nqx) según fuente, Colombia",
       subtitle = "Tablas abreviadas con las mismas convenciones de nax; las diferencias provienen de las tasas",
       x = "Edad", y = "nqx (escala log)", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/lifetables_compared_qx.png", w = 15, h = 6.5)

summ |>
  pivot_longer(c(e0, e15, e65), names_to = "ind", values_to = "value") |>
  mutate(sex = lab_sex(sex), ind = factor(ind, c("e0", "e15", "e65")), start = as.integer(str_sub(period, 1, 4)) + 2.5) |>
  ggplot(aes(start, value, col = src, lty = src)) +
  geom_line(linewidth = 0.6) + geom_point(size = 1.2) +
  facet_grid(ind ~ sex, scales = "free_y") +
  scale_color_manual(values = cols) + scale_linetype_manual(values = ltys) +
  labs(title = "Esperanza de vida a 0, 15 y 65 años según fuente, Colombia (periodos quinquenales)",
       x = NULL, y = "Años", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/lifetables_compared_ex.png", w = 10, h = 8)
