# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 46. Our adjusted rates against WPP 2024, by age and year
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Two views of the same comparison, from the adjusted series of 42 (ages 0,
# 1-4, 5-9, ..., 80+; WPP 2024 at the same ages, both on the WPP population):
#
# 1. Lexis surface of the ratio mx(ours) / mx(WPP), year x age, by sex, on a
#    log colour scale centred at 1 (blue: ours lower, orange: ours higher)
# 2. age-specific rates (log scale) of both series in eight years spanning
#    the period, by sex
#
# output: figures/06_components/ours_vs_wpp_lexis_ratio.png
#         figures/06_components/ours_vs_wpp_rates_by_age.png
#         output/tables/ours_vs_wpp_mx_ratio_1950-2023.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2)})

d <- read_csv("output/tables/mortality_adjusted_components_1950-2023.csv", show_col_types = FALSE) |>
  transmute(year, sex = c(m = "Hombres", f = "Mujeres")[sex], age, ours = mx_total, wpp = mx_wpp, ratio = ours / wpp)
write_csv(d, "output/tables/ours_vs_wpp_mx_ratio_1950-2023.csv")
age_lab <- function(a) if_else(a == 0, "0", if_else(a == 1, "1-4", if_else(a >= 80, "80+", paste0(a, "-", a + 4))))
ages <- sort(unique(d$age))
d <- d |> mutate(age_f = factor(age_lab(age), age_lab(ages)))

cat("ratio ours / WPP, both sexes pooled by age group (geometric mean over years):\n")
print(d |> mutate(period = cut(year, c(1949, 1969, 1989, 2009, 2023), labels = c("1950-69", "1970-89", "1990-2009", "2010-23"))) |>
        summarise(r = exp(mean(log(ratio))), .by = c(period, age_f)) |>
        mutate(r = round(r, 2)) |> pivot_wider(names_from = period, values_from = r) |> as.data.frame())

# ---- 1. Lexis surface of the ratio ----------------------------------------
lim <- 2  # colour scale clipped at 1/2 and 2
p1 <- d |>
  mutate(lr = pmin(pmax(log(ratio), -log(lim)), log(lim)),
         age_lo = age, age_hi = if_else(age == 0, 1, if_else(age == 1, 5, if_else(age >= 80, 90, age + 5)))) |>
  ggplot() +
  geom_rect(aes(xmin = year, xmax = year + 1, ymin = age_lo, ymax = age_hi, fill = lr)) +
  facet_wrap(~ sex) +
  scale_fill_gradient2(low = "#2166ac", mid = "#f7f7f7", high = "#d6641a", midpoint = 0,
                       breaks = log(c(0.5, 0.67, 0.8, 1, 1.25, 1.5, 2)), labels = c("0.5", "0.67", "0.8", "1", "1.25", "1.5", "2"),
                       limits = c(-log(lim), log(lim)), name = "mx propia / mx WPP") +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0, 0)) +
  scale_y_continuous(breaks = c(0, 1, seq(10, 80, 10)), labels = c("0", "1", seq(10, 80, 10)), expand = c(0, 0)) +
  labs(x = NULL, y = "Edad", title = "Cociente de tasas de mortalidad, serie propia ajustada frente a WPP 2024",
       subtitle = "Superficie de Lexis por sexo; escala logarítmica centrada en 1, recortada en 0,5 y 2") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", legend.key.width = grid::unit(1.6, "cm"), panel.grid = element_blank(), strip.text = element_text(face = "bold"))
ggsave("figures/06_components/ours_vs_wpp_lexis_ratio.png", p1, width = 11, height = 6, bg = "white", dpi = 150)

# ---- 2. age-specific rates in selected years ------------------------------
sel <- c(1955, 1965, 1975, 1985, 1995, 2005, 2015, 2023)
age_mid <- function(a) if_else(a == 0, 0.5, if_else(a == 1, 3, if_else(a >= 80, 85, a + 2.5)))
long <- d |> filter(year %in% sel) |>
  select(year, sex, age, ours, wpp) |>
  pivot_longer(c(ours, wpp), names_to = "series", values_to = "mx") |>
  mutate(series = factor(c(ours = "Propia ajustada", wpp = "WPP 2024")[series], c("Propia ajustada", "WPP 2024")),
         x = age_mid(age))
p2 <- ggplot(long, aes(x, mx, colour = series, linetype = series)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.2) +
  facet_grid(sex ~ year) +
  scale_colour_manual(values = c(`Propia ajustada` = "#1f5fa6", `WPP 2024` = "#7a7a7a"), name = NULL) +
  scale_linetype_manual(values = c(1, 2), name = NULL) +
  scale_y_log10(breaks = c(0.0002, 0.001, 0.005, 0.02, 0.1, 0.5), labels = c("0.2", "1", "5", "20", "100", "500")) +
  scale_x_continuous(breaks = c(0, 20, 40, 60, 80)) +
  labs(x = "Edad", y = "mx (por mil, escala logarítmica)",
       title = "Tasas de mortalidad por edad: serie propia ajustada y WPP 2024",
       subtitle = "Edades 0, 1-4, 5-9, ..., 80+ (puntos en el centro del grupo)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(), strip.text = element_text(face = "bold"))
ggsave("figures/06_components/ours_vs_wpp_rates_by_age.png", p2, width = 14, height = 6.5, bg = "white", dpi = 150)
cat("written: figures/06_components/ours_vs_wpp_lexis_ratio.png, ours_vs_wpp_rates_by_age.png, output/tables/ours_vs_wpp_mx_ratio_1950-2023.csv\n")
