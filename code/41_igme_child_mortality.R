# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 41. Mortality under age five from UN IGME, 1950-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Registered deaths under five are the least complete (they explain 40-50 %
# of the gap in e0 with WPP in 1970-1989, script 35) and the DDM and the
# empirical method say nothing specific about them. The under-five block of
# the adjusted series therefore comes from the UN Inter-agency Group for
# Child Mortality Estimation (UN IGME, 2024 round), which fits all the
# surveys, censuses and vital registration of the country.
#
# source: UNICEF Data Warehouse, SDMX API, dataflow UNICEF:CME_DF_2021_WQ(1.0),
#   https://sdmx.data.unicef.org/ws/public/sdmxapi/rest/data/UNICEF,CME_DF_2021_WQ,1.0/COL.MRY0T4+MRY0+MRY1T4+MRM0.M+F+_T._T.../?format=sdmx-csv&dimensionAtObservation=AllDimensions&endPeriod=2024
#   downloaded 2026-11-11 to data_input/reference/unigme2024_colombia_sdmx.csv
#   (the estimates, SERIES_NAME "UN_IGME", and the source data points)
#
# indicators (per 1,000): MRY0 infant mortality rate (1q0), MRY1T4 child
#   mortality rate (4q1), MRY0T4 under-five mortality rate (5q0), by sex,
#   1954-2024. They are turned into the death rates m0 and 4m1 that the life
#   tables of this project use, with Andreev-Kingkade a0 (as a function of
#   q0) and the same 4a1 as 28. For 1950-1953, before the IGME series starts,
#   the WPP 2024 rates are scaled by the ratio IGME / WPP of 1954.
#
# output: output/tables/igme_child_mortality_1950-2023.csv
#         figures/06_components/igme_child_mortality.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
dir.create("figures/06_components", showWarnings = FALSE)

raw <- read_csv("data_input/reference/unigme2024_colombia_sdmx.csv", show_col_types = FALSE, guess_max = 5000)
igme <-
  raw |>
  filter(SERIES_NAME == "UN_IGME", INDICATOR %in% c("MRY0", "MRY1T4", "MRY0T4"), SEX %in% c("M", "F")) |>
  transmute(year = as.integer(substr(TIME_PERIOD, 1, 4)), sex = if_else(SEX == "M", "m", "f"),
            ind = c(MRY0 = "q0", MRY1T4 = "q1_4", MRY0T4 = "q5")[INDICATOR], v = OBS_VALUE / 1000, lo = LOWER_BOUND / 1000, hi = UPPER_BOUND / 1000) |>
  filter(year <= 2023)
cat("UN IGME round:", unique(raw$SERIES_YEAR[raw$SERIES_NAME == "UN_IGME"]), "; years", paste(range(igme$year), collapse = "-"), "\n")
stopifnot(all(igme |> select(year, sex, ind, v) |> pivot_wider(names_from = ind, values_from = v) |>
                with(abs(1 - (1 - q0) * (1 - q1_4) - q5) < 2e-4)))

# q -> m
a0_q <- function(q, sex) if_else(sex == "m",
                                 case_when(q < 0.0226 ~ 0.1493 - 2.0367 * q, q < 0.0785 ~ 0.0244 + 3.4994 * q, TRUE ~ 0.2991),
                                 case_when(q < 0.0170 ~ 0.1490 - 2.0867 * q, q < 0.0658 ~ 0.0438 + 4.1075 * q, TRUE ~ 0.3141))
a1_m0 <- function(m0, sex) if_else(sex == "m",
                                   case_when(m0 < 0.023 ~ 1.6534, m0 < 0.08307 ~ 1.5806, TRUE ~ 1.3607),
                                   case_when(m0 < 0.01724 ~ 1.6338, m0 < 0.06891 ~ 1.5265, TRUE ~ 1.3062))
est <-
  igme |>
  pivot_wider(names_from = ind, values_from = c(v, lo, hi)) |>
  transmute(year, sex, q0 = v_q0, q1_4 = v_q1_4, q5 = v_q5, q5_lo = lo_q5, q5_hi = hi_q5,
            m0 = q0 / (1 - (1 - a0_q(q0, sex)) * q0),
            m1_4 = q1_4 / (4 - (4 - a1_m0(m0, sex)) * q1_4), source = "UN IGME")

# WPP 2024 and registered, for comparison and for 1950-1953
exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |> filter(age < 5)
q_from_m <- function(m0, m1, sex) {
  a0 <- if_else(sex == "m", case_when(m0 < 0.023 ~ 0.14929 - 1.99545 * m0, m0 < 0.08307 ~ 0.02832 + 3.26201 * m0, TRUE ~ 0.29915),
                case_when(m0 < 0.01724 ~ 0.14903 - 2.05527 * m0, m0 < 0.06891 ~ 0.04667 + 3.88089 * m0, TRUE ~ 0.31411))
  q0 <- m0 / (1 + (1 - a0) * m0); q1 <- 4 * m1 / (1 + (4 - a1_m0(m0, sex)) * m1)
  tibble(q0, q1_4 = q1, q5 = 1 - (1 - q0) * (1 - q1))
}
other <-
  exp |>
  transmute(year, sex, age, WPP = wpp_total / pop, Registradas = registered / pop) |>
  pivot_longer(c(WPP, Registradas), names_to = "source", values_to = "mx") |>
  pivot_wider(names_from = age, values_from = mx, names_prefix = "m") |>
  rename(m0 = m0, m1_4 = m1) |>
  mutate(q_from_m(m0, m1_4, sex))

back <-
  other |> filter(source == "WPP", year <= 1954) |>
  left_join(est |> filter(year == 1954) |> select(sex, i0 = m0, i1 = m1_4), by = "sex") |>
  mutate(m0 = m0 * i0 / m0[year == 1954], m1_4 = m1_4 * i1 / m1_4[year == 1954], .by = sex) |>
  filter(year < 1954) |>
  mutate(q_from_m(m0, m1_4, sex), q5_lo = NA, q5_hi = NA, source = "WPP escalado a IGME 1954") |>
  select(all_of(names(est)))
child <- bind_rows(back, est) |> arrange(sex, year)

# registered deaths as a lower bound. IGME's 4q1 falls below the rate of the
# registered deaths at 1-4 in most years (0.37 against 0.61 per 1,000 for
# boys in 2018), and around 1960 the registered 5q0 itself is slightly above
# IGME's. Rule: 5q0 is IGME's unless the registered one is higher; within it,
# neither age may fall below its registered rate, and the other age follows
# by difference. (The registered rates use the WPP population, so a few per
# cent of the excess may be denominator error.)
child <-
  child |>
  rename(q5_igme = q5, q0_igme = q0, q1_4_igme = q1_4, m0_igme = m0, m1_4_igme = m1_4) |>
  left_join(other |> filter(source == "Registradas") |> select(year, sex, q0_reg = q0, q1_4_reg = q1_4, q5_reg = q5), by = c("year", "sex")) |>
  mutate(q5 = pmax(q5_igme, q5_reg),
         q1_4 = pmax(q1_4_igme, q1_4_reg), q0 = 1 - (1 - q5) / (1 - q1_4),
         low0 = q0 < q0_reg, q0 = if_else(low0, q0_reg, q0), q1_4 = if_else(low0, 1 - (1 - q5) / (1 - q0), q1_4),
         rule = case_when(q5_reg > q5_igme ~ "5q0 registrada", q1_4 > q1_4_igme + 1e-9 ~ "5q0 IGME, 1-4 registrada", low0 ~ "5q0 IGME, 0 registrada", TRUE ~ "UN IGME"),
         m0 = q0 / (1 - (1 - a0_q(q0, sex)) * q0), m1_4 = q1_4 / (4 - (4 - a1_m0(m0, sex)) * q1_4)) |>
  select(year, sex, q5, q5_lo, q5_hi, q0, q1_4, m0, m1_4, rule, q5_igme, q0_igme, q1_4_igme, m0_igme, m1_4_igme, source)
stopifnot(all(child$q0 > 0), all(child$q1_4 > 0))
cat("\nrule applied to the under-five rates, number of years by sex:\n")
print(child |> count(sex, rule) |> pivot_wider(names_from = sex, values_from = n) |> as.data.frame())
cat("years with the registered 5q0 above IGME's:", paste(sort(unique(child$year[child$rule == "5q0 registrada"])), collapse = " "), "\n")
write_csv(child, "output/tables/igme_child_mortality_1950-2023.csv")

cmp <- child |> select(year, sex, igme = q5) |>
  left_join(other |> select(year, sex, source, q5) |> pivot_wider(names_from = source, values_from = q5), by = c("year", "sex"))
cat("\n5q0 per 1,000: UN IGME, WPP 2024 and registered deaths, and registered / IGME:\n")
print(cmp |> filter(year %in% c(1950, 1955, 1960, 1970, 1980, 1990, 2000, 2010, 2020)) |>
        transmute(year, sex, reg_igme = round(Registradas / igme, 2), wpp_igme = round(WPP / igme, 3),
                  IGME = round(1000 * igme, 1), WPP = round(1000 * WPP, 1), registradas = round(1000 * Registradas, 1)) |> arrange(sex, year) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
cols <- c("UN IGME" = "#2a78d6", "WPP 2024" = "#0b0b0b", "Registradas" = "#8a8983")
bind_rows(child |> transmute(year, sex, series = "UN IGME", q5, q5_lo, q5_hi),
          other |> transmute(year, sex, series = if_else(source == "WPP", "WPP 2024", source), q5)) |>
  mutate(sex = lab_sex(sex), series = factor(series, names(cols))) |>
  ggplot(aes(year, 1000 * q5, col = series)) +
  geom_ribbon(aes(ymin = 1000 * q5_lo, ymax = 1000 * q5_hi), fill = "#2a78d6", alpha = 0.18, colour = NA) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~sex) +
  scale_color_manual(values = cols) +
  scale_y_log10(breaks = c(10, 20, 50, 100, 200)) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "Mortalidad de menores de cinco años (5q0 por 1.000 nacidos vivos), Colombia 1950-2023",
       subtitle = "UN IGME (ronda 2024, banda: intervalo de incertidumbre del 90 %), WPP 2024 y defunciones registradas sin ajustar. Escala logarítmica",
       x = NULL, y = "5q0 por 1.000", col = NULL) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"), legend.position = "bottom",
        strip.background = element_rect(fill = "grey96", colour = NA), plot.title = element_text(size = 12, face = "bold"),
        plot.subtitle = element_text(size = 9.5, colour = "#52514e"))
ggsave("figures/06_components/igme_child_mortality.png", w = 12, h = 6, bg = "white")
