# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 34. Our mortality estimates against WPP 2024, 1950-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Our series (27) is WPP 2024 with its conflict component replaced, in
# 1985-2018, by the MSE correction (conflict homicides not registered as
# violent deaths + enforced disappearances). Outside those years the two
# series are the same by construction, so the comparison shows where and by
# how much the MSE correction moves WPP:
#
#   a. life expectancy at birth by sex, both series
#   b. difference in e0 (ours - WPP) by sex
#   c. ratio of our rates to WPP's by age group and year, 1985-2018
#   d. deaths per year behind the difference: WPP conflict deaths removed,
#      MSE homicides not registered and disappearances added
#
# Both sets of life tables are abridged (0, 1-4, ..., 80+), built with the
# same function on the WPP population, so the differences are not an
# artefact of the life-table method.
#
# output: output/tables/ours_vs_wpp_annual.csv
#         figures/04_completeness/ours_vs_wpp.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
mse_years <- range(exp$year[exp$mse_added > 0 | exp$hom_excess > 0 | exp$dsp > 0])

# abridged life table, Andreev-Kingkade a0 and 4a1 (same as 28)
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
  tibble(age, lx, ex = Tx / lx)
}

rates <-
  exp |>
  transmute(year, sex, age, `WPP 2024` = wpp_total / pop, Nuestra = expected / pop) |>
  pivot_longer(c(`WPP 2024`, Nuestra), names_to = "src", values_to = "mx")

summ <-
  rates |>
  arrange(src, year, sex, age) |>
  group_by(src, year, sex) |>
  reframe(lifetable(age, mx, first(sex))) |>
  summarise(e0 = ex[age == 0], q45_15 = 1 - lx[age == 60] / lx[age == 15], .by = c(src, year, sex))

annual <-
  summ |>
  pivot_wider(names_from = src, values_from = c(e0, q45_15)) |>
  left_join(exp |> summarise(deaths_wpp = sum(wpp_total), deaths_ours = sum(expected),
                             wpp_conflict = sum(wpp_conflict), hom_excess = sum(hom_excess), dsp = sum(dsp),
                             .by = c(year, sex)), by = c("year", "sex")) |>
  mutate(d_e0 = e0_Nuestra - `e0_WPP 2024`, d_deaths = deaths_ours - deaths_wpp) |>
  arrange(sex, year)
write_csv(annual, "output/tables/ours_vs_wpp_annual.csv")

cat("largest e0 differences (ours - WPP), by sex:\n")
print(annual |> slice_min(d_e0, n = 3, by = sex) |> select(sex, year, `e0_WPP 2024`, e0_Nuestra, d_e0) |> as.data.frame())
cat("\ndeaths 1985-2018, both sexes (thousands): WPP", round(sum(annual$deaths_wpp[annual$year %in% 1985:2018]) / 1e3),
    " ours", round(sum(annual$deaths_ours[annual$year %in% 1985:2018]) / 1e3),
    " difference", round(sum(annual$d_deaths) / 1e3), "\n")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_top <- max(exp$age)
age_lab <- \(a) factor(a, c(0, 1, seq(5, age_top, 5)), c("0", "1-4", paste0(seq(5, age_top - 5, 5), "-", seq(9, age_top - 1, 5)), paste0(age_top, "+")))
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
cols <- c("WPP 2024" = "#2a78d6", "Nuestra" = "#eb6834")
ink <- "#52514e"
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 11, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))
band <- annotate("rect", xmin = mse_years[1] - 0.5, xmax = mse_years[2] + 0.5, ymin = -Inf, ymax = Inf, fill = "grey50", alpha = 0.08)

pa <-
  summ |>
  mutate(sex = lab_sex(sex), src = factor(src, names(cols))) |>
  ggplot(aes(year, e0, col = src)) +
  band +
  geom_line(linewidth = 0.8) +
  facet_wrap(~sex, scales = "free_y") +
  scale_color_manual(values = cols) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "a. Esperanza de vida al nacer", subtitle = "Franja gris: años con corrección MSE (1985-2018); fuera de ella las dos series coinciden",
       x = NULL, y = "e0 (años)", col = NULL) +
  base

pb <-
  annual |>
  filter(year >= 1980) |>
  mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, d_e0, linetype = sex)) +
  band +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_line(linewidth = 0.8, colour = cols[["Nuestra"]]) +
  scale_linetype_manual(values = c(Hombres = "solid", Mujeres = "22")) +
  scale_x_continuous(breaks = seq(1980, 2020, 10)) +
  labs(title = "b. Diferencia en e0: nuestra serie menos WPP", subtitle = "Años de vida; valores negativos indican mayor mortalidad en nuestra serie",
       x = NULL, y = "Diferencia (años)", linetype = NULL) +
  base + theme(legend.key.width = unit(1.2, "cm"))

pc <-
  exp |>
  filter(year %in% seq(mse_years[1], mse_years[2])) |>
  mutate(pct = 100 * (expected / wpp_total - 1), sex = lab_sex(sex), age = age_lab(age)) |>
  ggplot(aes(year, age, fill = pct)) +
  geom_tile(colour = "white", linewidth = 0.2) +
  facet_wrap(~sex) +
  scale_fill_gradient2(low = "#2a78d6", mid = "#f0efec", high = "#eb6834", midpoint = 0,
                       labels = \(x) paste0(ifelse(x > 0, "+", ""), x, " %")) +
  scale_x_continuous(breaks = seq(1985, 2015, 5), expand = c(0, 0)) +
  scale_y_discrete(expand = c(0, 0)) +
  labs(title = "c. Diferencia relativa de las tasas por edad: nuestra serie frente a WPP",
       subtitle = "Naranja: nuestra tasa es mayor; azul: menor", x = NULL, y = "Edad", fill = NULL) +
  base + theme(legend.key.width = unit(1.6, "cm"), panel.grid = element_blank())

comp_cols <- c("Conflicto WPP (se quita)" = "#2a78d6", "Homicidios MSE no registrados (se suman)" = "#eb6834", "Desapariciones MSE (se suman)" = "#1baf7a")
pd <-
  annual |>
  filter(year %in% seq(mse_years[1], mse_years[2])) |>
  summarise(`Conflicto WPP (se quita)` = -sum(wpp_conflict), `Homicidios MSE no registrados (se suman)` = sum(hom_excess),
            `Desapariciones MSE (se suman)` = sum(dsp), .by = year) |>
  pivot_longer(-year, names_to = "comp", values_to = "n") |>
  mutate(comp = factor(comp, names(comp_cols))) |>
  ggplot(aes(year, n / 1e3, fill = comp)) +
  geom_col(colour = "white", linewidth = 0.25, width = 0.9) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  scale_fill_manual(values = comp_cols) +
  scale_x_continuous(breaks = seq(1985, 2015, 5)) +
  labs(title = "d. Defunciones por año detrás de la diferencia (ambos sexos)", subtitle = "Miles de defunciones",
       x = NULL, y = "Miles", fill = NULL) +
  base + guides(fill = guide_legend(nrow = 3))

fig <- ggpubr::ggarrange(pa, pb, pc, pd, ncol = 2, nrow = 2, widths = c(1.45, 1), heights = c(1, 1.15))
fig <- ggpubr::annotate_figure(fig, top = ggpubr::text_grob("Mortalidad estimada: nuestra serie (WPP 2024 con el conflicto sustituido por el ajuste MSE) frente a WPP 2024, Colombia",
                                                            face = "bold", size = 13, hjust = 0, x = 0.01))
ggsave("figures/04_completeness/ours_vs_wpp.png", fig, w = 15, h = 10.5, bg = "white")
