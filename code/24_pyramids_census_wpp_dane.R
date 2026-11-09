# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 24. Population pyramids at each census date: enumerated, WPP 2024, DANE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Three populations by sex and age group (0, 1-4, 5-9, ..., 80+) at the date
# of each census: the enumerated counts used as DDM input (21), the WPP 2024
# estimates interpolated linearly to the census date (1 July figures), and
# the DANE retroprojections used throughout this project (national sum of
# data_inter/pop_munic_1985-2017.rds, available for 1985, 1993 and 2005).
# The ratio panel shows WPP / census and DANE / census by age, which is the
# coverage pattern the DDM has to work against.
#
# output: figures/04_completeness/pyramids_census_wpp_dane.png
#         figures/04_completeness/pyramids_ratio_to_census.png
#         output/tables/pyramids_census_wpp_dane.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

age_top <- 80
grp5 <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), age_top))

cen <- read_rds("data_inter/census_pop_age.rds") |> select(census, dec, sex, age, pop)
dates <- cen |> distinct(census, dec)

# WPP: 1 July estimates, linear interpolation between the two mid-years
# around the census date
wpp <-
  read_rds("data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds") |>
  mutate(age = grp5(age)) |>
  summarise(pop = sum(pop), .by = c(year, sex, age))
wpp_at <-
  pmap_dfr(dates, \(census, dec) {
    t <- dec - 0.5                       # years since 1 July of floor(t)
    y0 <- floor(t); f <- t - y0
    wpp |> filter(year %in% c(y0, y0 + 1)) |>
      summarise(pop = sum(pop * if_else(year == y0, 1 - f, f)), .by = c(sex, age)) |>
      mutate(census = census)
  }) |>
  filter(census >= 1951)

# DANE retroprojections (30 June), interpolated the same way
dane <-
  read_rds("data_inter/pop_munic_1985-2017.rds") |>
  filter(sex %in% c("m", "f"), !is.na(age)) |>
  mutate(age = grp5(age)) |>
  summarise(pop = sum(pop), .by = c(year, sex, age))
dane_at <-
  pmap_dfr(dates |> filter(census %in% 1985:2016), \(census, dec) {
    t <- dec - 0.5; y0 <- floor(t); f <- t - y0
    dane |> filter(year %in% c(y0, y0 + 1)) |>
      summarise(pop = sum(pop * if_else(year == y0, 1 - f, f)), .by = c(sex, age)) |>
      mutate(census = census)
  })

pyr <-
  bind_rows(cen |> select(-dec) |> mutate(src = "Censo (enumerado)"),
            wpp_at |> mutate(src = "WPP 2024"),
            dane_at |> mutate(src = "DANE (retroproyección)")) |>
  mutate(src = factor(src, c("Censo (enumerado)", "WPP 2024", "DANE (retroproyección)")))
write_csv(pyr, "output/tables/pyramids_census_wpp_dane.csv")

cat("total population at each census date, by source (thousands):\n")
print(pyr |> summarise(pop = round(sum(pop) / 1e3), .by = c(census, src)) |>
        pivot_wider(names_from = src, values_from = pop) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# single-year groups (0 and 1-4) drawn with their per-year width so the bars
# are comparable in height with the 5-year groups
age_lab <- \(a) factor(a, c(0, 1, seq(5, age_top, 5)), c("0", "1-4", paste0(seq(5, age_top - 5, 5), "-", seq(9, age_top - 1, 5)), paste0(age_top, "+")))
pyr_plot <-
  pyr |>
  mutate(w = case_when(age == 0 ~ 1, age == 1 ~ 4, TRUE ~ 5),
         pop_yr = pop / w / 1e3,
         x = if_else(sex == "m", -pop_yr, pop_yr),
         age_lab = age_lab(age))

pyr_plot |>
  ggplot(aes(x, age_lab, col = src, group = interaction(src, sex))) +
  geom_vline(xintercept = 0, col = "grey50") +
  geom_col(data = pyr_plot |> filter(src == "Censo (enumerado)"), aes(fill = src), col = NA, alpha = 0.35, width = 1) +
  geom_path(linewidth = 0.6) +
  facet_wrap(~census, scales = "free_x", ncol = 4) +
  scale_fill_manual(values = c("Censo (enumerado)" = "grey40"), guide = "none") +
  scale_color_manual(values = c("Censo (enumerado)" = "grey20", "WPP 2024" = "#0A9396", "DANE (retroproyección)" = "#CA6702")) +
  scale_x_continuous(labels = \(v) abs(v)) +
  labs(title = "Pirámides de población en las fechas censales: censo enumerado, WPP 2024 y retroproyecciones DANE",
       subtitle = "Miles de personas por año de edad (hombres a la izquierda, mujeres a la derecha); barras: censo enumerado",
       x = NULL, y = NULL, col = NULL) +
  theme_bw() + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/04_completeness/pyramids_census_wpp_dane.png", w = 12, h = 7)

ratio <-
  pyr |>
  filter(src != "Censo (enumerado)") |>
  inner_join(cen |> select(census, sex, age, census_pop = pop), by = c("census", "sex", "age")) |>
  mutate(ratio = pop / census_pop, sex = factor(sex, c("f", "m"), c("Mujeres", "Hombres")), age_lab = age_lab(age))

ratio |>
  ggplot(aes(age_lab, ratio, col = src, group = interaction(src, sex), lty = sex)) +
  geom_hline(yintercept = 1, lty = "dashed", col = "grey60") +
  geom_line() + geom_point(size = 1) +
  facet_wrap(~census, ncol = 4) +
  scale_color_manual(values = c("WPP 2024" = "#0A9396", "DANE (retroproyección)" = "#CA6702")) +
  coord_cartesian(ylim = c(0.8, 1.4)) +
  labs(title = "Población estimada / población enumerada, por edad y sexo, en cada censo",
       subtitle = "Valores > 1: la estimación supone omisión censal en esa edad",
       x = NULL, y = "Razón a la población censada", col = NULL, lty = NULL) +
  theme_bw() + theme(legend.position = "bottom", axis.text.x = element_text(angle = 90, vjust = 0.5))
ggsave("figures/04_completeness/pyramids_ratio_to_census.png", w = 12, h = 6)
