# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 35. Where the gap with WPP 2024 comes from: age decomposition of e0
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The difference in life expectancy at birth between each of our series and
# WPP 2024 is decomposed by age with Arriaga's method (direct + indirect and
# interaction effects), year by year and by sex, 1950-2023:
#
#   Registradas   deaths as registered (22)
#   Ajuste DDM    registered deaths / annual DDM completeness (23), at all ages
#
# A positive contribution means that the series has lower mortality than WPP
# at those ages (deaths missing with respect to WPP); a negative one, higher
# mortality. The contributions of the 18 age groups add up to e0(series) -
# e0(WPP) and are shown in six bands: 0, 1-4, 5-14, 15-59, 60-79, 80+.
#
# The rates use the WPP population and the same abridged life table (34), so
# the gap is a gap in deaths. This sizes the blocks an own adjusted series
# has to deal with: child mortality, adult completeness and old-age rates.
#
# output: output/tables/e0_gap_decomposition.csv
#         figures/04_completeness/e0_gap_decomposition.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
comp <-
  read_csv("output/tables/completeness_ddm_conflict_annual.csv", show_col_types = FALSE) |>
  filter(variant == "migration + conflict") |>
  select(year, sex, c_ddm = completeness)

# abridged life table, Andreev-Kingkade a0 and 4a1 (same as 28 and 34)
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
  tibble(age, lx, Lx, Tx)
}

# Arriaga: contribution of each age group to e0(2) - e0(1)
arriaga <- function(lx1, Lx1, Tx1, lx2, Lx2, Tx2) {
  k <- length(lx1)
  lead <- \(x) c(x[-1], 0)
  direct <- lx1 * (Lx2 / lx2 - Lx1 / lx1)
  indirect <- lead(Tx2) * (lx1 / lx2 - lead(lx1) / lead(lx2))
  indirect[k] <- 0
  direct[k] <- lx1[k] * (Tx2[k] / lx2[k] - Tx1[k] / lx1[k])
  direct + indirect
}

srcs <- c("Registradas", "Ajuste DDM")
lt <-
  exp |>
  left_join(comp, by = c("year", "sex")) |>
  transmute(year, sex, age,
            Registradas = registered / pop,
            `Ajuste DDM` = registered / c_ddm / pop,
            `WPP 2024` = wpp_total / pop) |>
  pivot_longer(c(all_of(srcs), `WPP 2024`), names_to = "src", values_to = "mx") |>
  arrange(src, year, sex, age) |>
  group_by(src, year, sex) |>
  reframe(lifetable(age, mx, first(sex)))

band <- \(a) cut(a, c(-1, 0, 4, 14, 59, 79, Inf), c("0", "1-4", "5-14", "15-59", "60-79", "80+"))
dec <-
  lt |>
  filter(src != "WPP 2024") |>
  left_join(lt |> filter(src == "WPP 2024") |> select(year, sex, age, lx_w = lx, Lx_w = Lx, Tx_w = Tx), by = c("year", "sex", "age")) |>
  arrange(src, year, sex, age) |>
  mutate(contrib = arriaga(lx_w, Lx_w, Tx_w, lx, Lx, Tx), gap = Tx[1] - Tx_w[1], .by = c(src, year, sex))

cat("largest absolute difference between the sum of contributions and the e0 gap:",
    dec |> summarise(d = sum(contrib) - first(gap), .by = c(src, year, sex)) |> pull(d) |> abs() |> max() |> signif(3), "\n")

bands <-
  dec |>
  mutate(band = band(age)) |>
  summarise(contrib = sum(contrib), gap = first(gap), .by = c(src, year, sex, band)) |>
  mutate(src = factor(src, srcs))
write_csv(bands, "output/tables/e0_gap_decomposition.csv")

period <- \(y) cut(y, c(1949, 1959, 1969, 1979, 1989, 1999, 2009, 2019, 2023),
                   c("1950-59", "1960-69", "1970-79", "1980-89", "1990-99", "2000-09", "2010-19", "2020-23"))
tab <-
  bands |>
  mutate(period = period(year)) |>
  summarise(contrib = mean(contrib), .by = c(src, sex, period, band)) |>
  pivot_wider(names_from = band, values_from = contrib) |>
  mutate(total = rowSums(across(where(is.numeric)))) |>
  mutate(across(where(is.numeric), ~ round(.x, 2))) |>
  arrange(src, sex, period)
cat("\naverage contribution to e0(series) - e0(WPP), years of life, by decade:\n")
print(as.data.frame(tab))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
band_cols <- c("0" = "#2a78d6", "1-4" = "#eb6834", "5-14" = "#1baf7a", "15-59" = "#eda100", "60-79" = "#e87ba4", "80+" = "#6250d6")
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))

bands |>
  mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, contrib)) +
  geom_col(aes(fill = band), width = 1, colour = "white", linewidth = 0.1) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.3) +
  geom_line(data = \(d) distinct(d, src, sex, year, gap), aes(y = gap), colour = "#0b0b0b", linewidth = 0.6) +
  facet_grid(src ~ sex) +
  scale_fill_manual(values = band_cols) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0.01, 0)) +
  labs(title = "De dónde viene la brecha con WPP 2024: descomposición por edad de la diferencia en esperanza de vida al nacer",
       subtitle = "Años de vida. Barras: contribución de cada grupo de edad (positivo: menos mortalidad que WPP, es decir defunciones que faltan). Línea negra: diferencia total en e0",
       x = NULL, y = "Contribución a e0(serie) − e0(WPP), años", fill = "Edad") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = "#52514e")) +
  guides(fill = guide_legend(nrow = 1))
ggsave("figures/04_completeness/e0_gap_decomposition.png", w = 14, h = 9, bg = "white")
