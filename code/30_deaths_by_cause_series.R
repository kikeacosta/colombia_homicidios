# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 30. National deaths by cause group (violent / non-violent), sex and age,
#     1953-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Total deaths are the expected deaths of 27 (WPP 2024 with its conflict
# component replaced by the MSE correction in 1985-2018). They are split
# into violent and non-violent deaths:
#
#   violent, registered   homicide + undetermined intent (+ legal
#                         intervention from 1979), by sex and age group:
#                         1953-1967 WHO ICD-7 A149; 1968-1977 WHO ICD-8
#                         A148 + A149 (21); 1979-2023 EEVV dx_v (01-02).
#                         WHO has no causes for 1970, 1971, 1973 and 1978.
#                         1973 and 1978 come from DANE, "Registro de
#                         defunciones en Colombia 1970-1978", Cuadro 6 (150
#                         causes by age and sex, hist/25), causes 148 + 149
#                         of the same ICD-8 list A: for 1974-1977 that table
#                         equals the WHO series in every sex, age and cause
#                         cell, which is asserted below. 1970 and 1971 have
#                         no cause detail anywhere and are interpolated
#                         log-linearly by sex and age.
#   violent, adjusted     1985-2018: registered + MSE conflict homicides not
#                         registered as violent + enforced disappearances
#                         (27). Other years: registered violent deaths scaled
#                         by the all-cause factor expected / registered of
#                         the same year, sex and age group (bounded to
#                         [1, 2]), i.e. assuming violent deaths are missed
#                         at the same rate as the rest; there is no
#                         independent estimate for those years.
#   non-violent           expected total - violent adjusted.
#
# quality flag per year: "MSE" (1985-2018), "scaled" (1953-1969, 1972-1984,
# 2019-2023), "interpolated" (1970, 1971).
#
# output: output/tables/deaths_by_cause_sex_age_1953-2023.csv
#           (year, sex, age, pop, total, violent_reg, violent_adj,
#            nonviolent, mx_total, mx_violent, mx_nonviolent, quality)
#         figures/04_completeness/violent_mx_men_series.png
#         figures/04_completeness/violent_share_series.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

age_top <- 80
mse_years <- 1985:2018

exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |>
  filter(year >= 1953)

# registered violent deaths ---------------------------------------------------
who_raw <- read_rds("data_inter/who_violent_age_1953-1977.rds")
who_v <- who_raw |>
  mutate(age = pmin(age, age_top)) |>
  summarise(violent_reg = sum(dx), .by = c(year, sex, age))
# DANE, Registro de defunciones 1970-1978, Cuadro 6: causes 148 (homicide and legal intervention) and 149
# (undetermined intent) by sex and age, with the unknown ages spread pro rata as in 21. Used for the
# years WHO lacks (1973, 1978); the other years (1974-1977) must reproduce the WHO series exactly.
dane_c6 <- read_csv("data_input/historical/dane_defunciones_1970_1978_cuadro06_causas_edad_1973_1978.csv",
                    show_col_types = FALSE, col_types = cols(cause_code = col_character())) |>
  filter(cause_code %in% c("148", "149"), age != "all") |>
  mutate(group = if_else(cause_code == "148", "homicide", "undetermined"),
         age = case_when(str_detect(age, "day|months$") & age != "12-23 months" ~ 0, age %in% c("12-23 months", "2-4") ~ 1,
                         str_detect(age, "^[0-9]+-[0-9]+$") ~ suppressWarnings(as.numeric(str_extract(age, "^[0-9]+"))),
                         str_detect(age, "^85") ~ 85, TRUE ~ NA_real_)) |>
  pivot_longer(c(male, female), names_to = "sex", values_to = "dx") |>
  mutate(sex = if_else(sex == "male", "m", "f")) |>
  summarise(dx = sum(dx), .by = c(year, sex, group, age)) |>
  mutate(unk = sum(dx[is.na(age)]), tot = sum(dx[!is.na(age)]), .by = c(year, sex, group)) |>
  filter(!is.na(age)) |>
  mutate(dx = if_else(tot > 0, dx * (1 + unk / tot), dx)) |>
  select(year, sex, group, age, dx)
overlap <- inner_join(dane_c6, who_raw, by = c("year", "sex", "group", "age"), suffix = c("_dane", "_who"))
stopifnot(n_distinct(overlap$year) == 4, nrow(overlap) == sum(who_raw$year %in% overlap$year), max(abs(overlap$dx_dane - overlap$dx_who)) < 1e-6)
cat("DANE Cuadro 6 against WHO, causes 148 and 149 by sex and age:", nrow(overlap), "cells in", paste(range(overlap$year), collapse = "-"), "identical\n")
dane_v <- dane_c6 |>
  filter(!year %in% who_raw$year) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(violent_reg = sum(dx), .by = c(year, sex, age))
cat("violent deaths taken from DANE Cuadro 6:", paste(sort(unique(dane_v$year)), collapse = ", "), "\n")
eevv_v <- read_rds("data_inter/deaths_munic_age_1979-2023.rds") |>
  filter(sex %in% c("m", "f"), !is.na(age)) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(violent_reg = sum(dx_v), .by = c(year, sex, age))

violent <-
  bind_rows(who_v, dane_v, eevv_v) |>
  complete(year = 1953:2023, sex, age = unique(exp$age)) |>
  mutate(quality = if_else(is.na(violent_reg), "interpolated", "registered")) |>
  arrange(sex, age, year) |>
  # log-linear interpolation by sex and age (zero counts handled on the count scale)
  mutate(violent_reg = {
    obs <- !is.na(violent_reg)
    out <- violent_reg
    if (any(obs) && any(!obs)) {
      lg <- log(pmax(violent_reg[obs], 0.5))
      out[!obs] <- exp(approx(year[obs], lg, xout = year[!obs], rule = 2)$y)
      out[!obs][violent_reg[obs][findInterval(year[!obs], year[obs])] == 0] <- 0
    }
    out
  }, .by = c(sex, age))

cat("registered (or interpolated) violent deaths by year, both sexes:\n")
print(violent |> summarise(violent = round(sum(violent_reg)), quality = first(quality), .by = year) |>
        filter(year <= 1985 | year %% 5 == 0) |> as.data.frame())

# split --------------------------------------------------------------------------
series <-
  exp |>
  left_join(violent, by = c("year", "sex", "age")) |>
  mutate(factor = pmin(pmax(expected / registered, 1), 2),
         factor = replace_na(factor, 1),
         violent_adj = if_else(year %in% mse_years, violent_reg + hom_excess + dsp, violent_reg * factor),
         violent_adj = pmin(violent_adj, expected),
         nonviolent = expected - violent_adj,
         quality = case_when(year %in% mse_years ~ "MSE", quality == "interpolated" ~ "interpolated", TRUE ~ "scaled")) |>
  transmute(year, sex, age, pop, total = expected, violent_reg, violent_adj, nonviolent,
            mx_total = total / pop, mx_violent = violent_adj / pop, mx_nonviolent = nonviolent / pop, quality) |>
  arrange(year, sex, age)
write_csv(series, "output/tables/deaths_by_cause_sex_age_1953-2023.csv")

cat("\nviolent deaths, registered and adjusted, and share of total deaths, by year (both sexes):\n")
print(series |> summarise(total = round(sum(total)), violent_reg = round(sum(violent_reg)), violent_adj = round(sum(violent_adj)),
                          share = round(100 * sum(violent_adj) / sum(total), 1), quality = first(quality), .by = year) |>
        filter(year %% 5 == 0 | year %in% c(1958, 1991, 2002)) |> as.data.frame())

cat("\nmen 15-44: violent share of all deaths, by year:\n")
print(series |> filter(sex == "m", age >= 15, age < 45) |>
        summarise(share_reg = round(100 * sum(violent_reg) / sum(total), 1), share_adj = round(100 * sum(violent_adj) / sum(total), 1), .by = year) |>
        filter(year %% 5 == 0 | year %in% c(1958, 1991, 2002)) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
age_lab <- \(a) factor(a, c(0, 1, seq(5, age_top, 5)), c("0", "1-4", paste0(seq(5, age_top - 5, 5), "-", seq(9, age_top - 1, 5)), paste0(age_top, "+")))
lab_sex <- \(s) factor(s, c("f", "m"), c("Mujeres", "Hombres"))
qual_cols <- c("MSE" = "#9B2226", "scaled" = "#CA6702", "interpolated" = "grey60")

series |>
  filter(sex == "m", age %in% seq(15, 55, 10)) |>
  mutate(age_lab = age_lab(age)) |>
  mutate(reg = 1e5 * violent_reg / pop, adj = 1e5 * violent_adj / pop) |>
  ggplot(aes(year)) +
  geom_line(aes(y = reg), col = "grey55", linewidth = 0.5) +
  geom_line(aes(y = adj, col = quality, group = 1), linewidth = 0.7) +
  facet_wrap(~age_lab, nrow = 1) +
  scale_y_log10() +
  scale_color_manual(values = qual_cols, labels = c(MSE = "ajuste MSE", scaled = "escalado por completitud", interpolated = "interpolado")) +
  labs(title = "Mortalidad violenta masculina por edad, Colombia 1953-2023 (por 100.000, población WPP)",
       subtitle = "Homicidio + intención no determinada (+ intervención legal desde 1979). Gris: registradas; color: ajustadas, según el tipo de ajuste del año",
       x = NULL, y = "Tasa por 100.000 (escala log)", col = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/violent_mx_men_series.png", w = 14, h = 5)

series |>
  mutate(band = case_when(age < 15 ~ "0-14", age < 45 ~ "15-44", age < 65 ~ "45-64", TRUE ~ "65+")) |>
  summarise(share = 100 * sum(violent_adj) / sum(total), .by = c(year, sex, band)) |>
  mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, share, col = band)) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~sex, scales = "free_y") +
  scale_color_manual(values = c("0-14" = "#94D2BD", "15-44" = "#9B2226", "45-64" = "#CA6702", "65+" = "#4A4E69")) +
  labs(title = "Participación de las muertes violentas (ajustadas) en el total de defunciones, por sexo y grupo de edad",
       x = NULL, y = "% de las defunciones", col = "Edad") +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/04_completeness/violent_share_series.png", w = 11, h = 5)
