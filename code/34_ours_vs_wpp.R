# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 34. Our mortality estimates against WPP 2024, 1950-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Two estimates of this project are set against WPP 2024, with the registered
# deaths as a reference:
#
#   Registradas        deaths as registered (22: WHO, DANE microdata, LAMBdA)
#   Ajuste DDM         registered deaths divided by the annual completeness
#                      of 23 (GGB-SEG on the unadjusted censuses, with
#                      migration and the conflict-corrected numerator),
#                      applied at all ages although the DDM only speaks for
#                      adults; this is the estimate that does not use WPP
#   WPP + MSE          WPP 2024 with its conflict component replaced, in
#                      1985-2018, by the MSE correction (27); equal to WPP
#                      outside those years by construction
#   WPP 2024           the reference
#
# All rates use the WPP population and all life tables are abridged (0, 1-4,
# ..., 80+) with the same function, so only the numerators differ.
#
#   a. life expectancy at birth by sex, and its difference from WPP
#   b. 45q15 by sex, and its ratio to WPP (the DDM is an adult method, so
#      this is the indicator where the DDM estimate is on its own ground)
#   c. relative difference of the age-specific rates from WPP, by age and
#      year, for the DDM adjustment (1950-2023) and for WPP + MSE (1985-2018)
#
# output: output/tables/ours_vs_wpp_annual.csv
#         figures/04_completeness/ours_vs_wpp.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
mse_years <- range(exp$year[exp$mse_added > 0 | exp$hom_excess > 0 | exp$dsp > 0])

comp <-
  read_csv("output/tables/completeness_ddm_conflict_annual.csv", show_col_types = FALSE) |>
  filter(variant == "migration + conflict") |>
  select(year, sex, c_ddm = completeness)

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

srcs <- c("Registradas", "Ajuste DDM", "WPP + MSE", "WPP 2024")
rates <-
  exp |>
  left_join(comp, by = c("year", "sex")) |>
  transmute(year, sex, age, pop,
            Registradas = registered / pop,
            `Ajuste DDM` = registered / c_ddm / pop,
            `WPP + MSE` = expected / pop,
            `WPP 2024` = wpp_total / pop) |>
  pivot_longer(all_of(srcs), names_to = "src", values_to = "mx") |>
  mutate(src = factor(src, srcs))

summ <-
  rates |>
  arrange(src, year, sex, age) |>
  group_by(src, year, sex) |>
  reframe(lifetable(age, mx, first(sex))) |>
  summarise(e0 = ex[age == 0], q45_15 = 1 - lx[age == 60] / lx[age == 15], .by = c(src, year, sex)) |>
  mutate(d_e0 = e0 - e0[src == "WPP 2024"], r_q = q45_15 / q45_15[src == "WPP 2024"], .by = c(year, sex))

annual <-
  summ |>
  left_join(rates |> summarise(deaths = sum(mx * pop), deaths_15_64 = sum((mx * pop)[age >= 15 & age < 65]), .by = c(src, year, sex)),
            by = c("src", "year", "sex")) |>
  left_join(comp, by = c("year", "sex")) |>
  arrange(src, sex, year)
write_csv(annual, "output/tables/ours_vs_wpp_annual.csv")

cat("e0 and 45q15 against WPP, selected years:\n")
print(summ |> filter(year %in% c(1950, 1960, 1970, 1980, 1990, 2000, 2010, 2018), src != "WPP 2024") |>
        transmute(sex, year, src, d_e0 = round(d_e0, 2), r_q = round(r_q, 3)) |>
        pivot_wider(names_from = src, values_from = c(d_e0, r_q)) |> arrange(sex, year) |> as.data.frame())
cat("\nDDM completeness applied, selected years:\n")
print(comp |> filter(year %in% c(1950, 1960, 1970, 1980, 1990, 2000, 2010, 2018)) |> mutate(c_ddm = round(c_ddm, 3)) |>
        pivot_wider(names_from = sex, values_from = c_ddm) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_top <- max(exp$age)
age_lab <- \(a) factor(a, c(0, 1, seq(5, age_top, 5)), c("0", "1-4", paste0(seq(5, age_top - 5, 5), "-", seq(9, age_top - 1, 5)), paste0(age_top, "+")))
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
cols <- c("Registradas" = "#8a8983", "Ajuste DDM" = "#1baf7a", "WPP + MSE" = "#eb6834", "WPP 2024" = "#2a78d6")
lwd <- c("Registradas" = 0.5, "Ajuste DDM" = 0.9, "WPP + MSE" = 0.9, "WPP 2024" = 0.9)
ink <- "#52514e"
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 11, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))
band <- annotate("rect", xmin = mse_years[1] - 0.5, xmax = mse_years[2] + 0.5, ymin = -Inf, ymax = Inf, fill = "grey50", alpha = 0.08)
sc <- list(scale_color_manual(values = cols), scale_linewidth_manual(values = lwd, guide = "none"),
           scale_x_continuous(breaks = seq(1950, 2020, 10)))
d <- summ |> mutate(sex = lab_sex(sex))

lines <- function(data, y, title, subtitle, ylab, ref = NULL) {
  ggplot(data, aes(year, {{ y }}, col = src, linewidth = src)) +
    band +
    { if (!is.null(ref)) geom_hline(yintercept = ref, colour = "grey55", linewidth = 0.3) } +
    geom_line() +
    facet_wrap(~sex) +
    sc +
    labs(title = title, subtitle = subtitle, x = NULL, y = ylab, col = NULL) +
    base
}

pa1 <- lines(d, e0, "a. Esperanza de vida al nacer", "Franja gris: años con corrección MSE (1985-2018)", "e0 (años)")
pa2 <- lines(d |> filter(src != "WPP 2024"), d_e0, "Diferencia en e0 respecto a WPP 2024",
             "Años de vida; positivo: menos mortalidad que WPP", "Diferencia (años)", ref = 0)
pb1 <- lines(d, q45_15, "b. Probabilidad de morir entre los 15 y los 60 años (45q15)",
             "El DDM es un método de adultos: este es su terreno", "45q15")
pb2 <- lines(d |> filter(src != "WPP 2024"), r_q, "Razón de 45q15 respecto a WPP 2024",
             "1 = igual que WPP; menos de 1: mortalidad adulta menor que WPP", "Razón", ref = 1)

heat <- function(source, years, title) {
  rates |>
    mutate(pct = 100 * (mx / mx[src == "WPP 2024"] - 1), .by = c(year, sex, age)) |>
    filter(src == source, year %in% years) |>
    mutate(sex = lab_sex(sex), age = age_lab(age)) |>
    ggplot(aes(year, age, fill = pct)) +
    geom_tile() +
    facet_wrap(~sex) +
    scale_fill_gradient2(low = "#2a78d6", mid = "#f0efec", high = "#eb6834", midpoint = 0, limits = c(-50, 50),
                         oob = scales::squish, breaks = seq(-50, 50, 25),
                         labels = \(x) paste0(ifelse(x > 0, "+", ""), x, " %")) +
    scale_x_continuous(breaks = if (length(years) > 40) seq(1960, 2020, 20) else seq(1990, 2015, 5), expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    labs(title = title, subtitle = "Naranja: tasa mayor que la de WPP; azul: menor (escala cortada en ±50 %)", x = NULL, y = "Edad", fill = NULL) +
    base + theme(legend.key.width = unit(1.6, "cm"), panel.grid = element_blank())
}
pc1 <- heat("Ajuste DDM", 1950:2023, "c. Tasas por edad del ajuste DDM frente a WPP 2024")
pc2 <- heat("WPP + MSE", seq(mse_years[1], mse_years[2]), "Tasas por edad de WPP + MSE frente a WPP 2024")

top <- ggpubr::ggarrange(pa1, pa2, pb1, pb2, ncol = 2, nrow = 2, common.legend = TRUE, legend = "bottom")
bottom <- ggpubr::ggarrange(pc1, pc2, ncol = 2, common.legend = TRUE, legend = "bottom")
fig <- ggpubr::ggarrange(top, bottom, ncol = 1, heights = c(2, 1.15))
fig <- ggpubr::annotate_figure(fig, top = ggpubr::text_grob("Mortalidad estimada frente a WPP 2024, Colombia 1950-2023: registradas, ajuste DDM y WPP con el conflicto sustituido por el MSE",
                                                            face = "bold", size = 13, hjust = 0, x = 0.01))
ggsave("figures/04_completeness/ours_vs_wpp.png", fig, w = 15, h = 14, bg = "white")
