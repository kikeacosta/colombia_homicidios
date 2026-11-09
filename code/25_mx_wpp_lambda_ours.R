# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 25. Age-specific death rates: WPP 2024, LAMBdA and this project
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Rates by sex and age group (0, 1-4, 5-9, ..., 80+) for selected years, all
# with the WPP 2024 population as denominator so that only the numerators
# differ:
#   WPP 2024      mx from the WPP single-age life tables (deaths = mx x pop)
#   LAMBdA        mx from the adjusted 1x1 life tables (deaths / person-years
#                 within each group)
#   registradas   deaths as registered (22: WHO, DANE microdata, LAMBdA
#                 transcriptions)
#   ajustadas     registered deaths divided by the annual completeness of 23
#                 (GGB-SEG with migration and the conflict-corrected
#                 numerator, expressed for registered deaths), applied at all
#                 ages although the DDM only speaks for adults (15-75)
#
# output: figures/04_completeness/mx_wpp_lambda_ours.png
#         output/tables/mx_wpp_lambda_ours.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

years <- c(1950, 1970, 1990, 2000, 2010)
age_top <- 80
grp5 <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), age_top))

wpp <-
  read_rds("data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds") |>
  filter(year %in% years) |>
  mutate(age = grp5(age)) |>
  summarise(dx_wpp = sum(mx * pop), pop = sum(pop), .by = c(year, sex, age))

lambda <-
  map_dfr(c(m = "mltper", f = "fltper"), \(f) read_table(paste0("data_input/historical/lambda_Col_", f, "_1x1.txt"), show_col_types = FALSE), .id = "sex") |>
  filter(year %in% years) |>
  mutate(age = grp5(as.integer(str_remove(age, fixed("+"))))) |>
  summarise(mx_lambda = sum(lx * qx) / sum(Lx), .by = c(year, sex, age))

reg <-
  read_rds("data_inter/deaths_age_annual_1938-2023.rds") |>
  filter(year %in% years) |>
  select(year, sex, age, dx_reg = dx)

comp <-
  read_csv("output/tables/completeness_ddm_conflict_annual.csv", show_col_types = FALSE) |>
  filter(variant == "migration + conflict", year %in% years) |>
  select(year, sex, completeness)

mx <-
  wpp |>
  left_join(lambda, by = c("year", "sex", "age")) |>
  left_join(reg, by = c("year", "sex", "age")) |>
  left_join(comp, by = c("year", "sex")) |>
  mutate(`WPP 2024` = dx_wpp / pop,
         LAMBdA = mx_lambda,
         `Registradas` = dx_reg / pop,
         `Ajustadas (DDM)` = dx_reg / completeness / pop) |>
  select(year, sex, age, pop, completeness, `WPP 2024`, LAMBdA, Registradas, `Ajustadas (DDM)`)
write_csv(mx, "output/tables/mx_wpp_lambda_ours.csv")

cat("completeness applied (GGB-SEG, migration + conflict):\n")
print(comp |> mutate(completeness = round(completeness, 3)) |> pivot_wider(names_from = sex, values_from = completeness) |> as.data.frame())

cat("\ndeaths at 15-64 implied by each series, thousands (WPP population):\n")
print(mx |> filter(age >= 15, age < 65) |>
        summarise(across(c(`WPP 2024`, LAMBdA, Registradas, `Ajustadas (DDM)`), \(m) round(sum(m * pop) / 1e3, 1)), .by = c(year, sex)) |>
        arrange(sex, year) |> as.data.frame())

cat("\nratio of each series to WPP at 15-64:\n")
print(mx |> filter(age >= 15, age < 65) |>
        summarise(across(c(LAMBdA, Registradas, `Ajustadas (DDM)`), \(m) round(sum(m * pop) / sum(`WPP 2024` * pop), 3)), .by = c(year, sex)) |>
        arrange(sex, year) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, a == age_top ~ age_top + 5, TRUE ~ a + 2.5)
long <-
  mx |>
  pivot_longer(c(`WPP 2024`, LAMBdA, Registradas, `Ajustadas (DDM)`), names_to = "src", values_to = "mx") |>
  filter(!is.na(mx)) |>
  mutate(src = factor(src, c("WPP 2024", "LAMBdA", "Registradas", "Ajustadas (DDM)")),
         sex = factor(sex, c("f", "m"), c("Mujeres", "Hombres")),
         x = age_mid(age))

long |>
  ggplot(aes(x, mx, col = src, lty = src)) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 0.9) +
  facet_grid(sex ~ year) +
  scale_y_log10(labels = \(v) format(v, scientific = FALSE, drop0trailing = TRUE)) +
  scale_color_manual(values = c("WPP 2024" = "#0A9396", "LAMBdA" = "#9B2226", "Registradas" = "grey45", "Ajustadas (DDM)" = "black")) +
  scale_linetype_manual(values = c("solid", "solid", "dotted", "solid")) +
  labs(title = "Tasas de mortalidad por edad y sexo: WPP 2024, LAMBdA y este proyecto",
       subtitle = "Denominador común: población WPP 2024. Ajustadas = registradas / completitud GGB-SEG (con migración y corrección por conflicto)",
       x = "Edad", y = "Tasa (escala log)", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/mx_wpp_lambda_ours.png", w = 13, h = 6.5)

# ratio to WPP, adults only, where the differences are legible
long |>
  filter(age >= 15) |>
  left_join(mx |> select(year, sex, age, wpp = `WPP 2024`) |> mutate(sex = factor(sex, c("f", "m"), c("Mujeres", "Hombres"))),
            by = c("year", "sex", "age")) |>
  filter(src != "WPP 2024") |>
  ggplot(aes(x, mx / wpp, col = src, lty = src)) +
  geom_hline(yintercept = 1, lty = "dashed", col = "grey60") +
  geom_line(linewidth = 0.6) + geom_point(size = 0.9) +
  facet_grid(sex ~ year) +
  scale_color_manual(values = c("LAMBdA" = "#9B2226", "Registradas" = "grey45", "Ajustadas (DDM)" = "black")) +
  scale_linetype_manual(values = c("solid", "dotted", "solid")) +
  coord_cartesian(ylim = c(0.5, 1.6)) +
  labs(title = "Razón de cada serie a la tasa WPP 2024, edades 15+",
       x = "Edad", y = "Tasa / tasa WPP", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/mx_ratio_to_wpp.png", w = 13, h = 6)
