# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 33. Empirical completeness of death registration (Adair & Lopez 2018)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Adair T, Lopez AD (2018) Estimating the completeness of death registration:
# an empirical method. PLoS ONE 13(5): e0197047. Random-effects models fitted
# on 2,451 country-years (GBD 2015 as truth) predict the logit of all-age
# completeness from the registered crude death rate (per 1,000, with its
# square), the share of the population aged 65+, the log of the "true" 5q0
# (probability), calendar year and, in Model 1, the completeness of under-five
# death registration (registered / true 5q0). Coefficients from Table 2
# (p. 10), both sexes, males and females. Country random effects are not
# published for Colombia (S2-S7 tables), so predictions use the fixed part
# only, as the paper does for out-of-sample populations (p. 12).
#
# A third national completeness series, annual 1979-2023, alongside the DDM
# (23) and WPP-based (27) estimates, and a departmental series 1985-2023 that
# does not need the closed-population assumption of GGB/SEG (10, 18).
#
# Inputs
#   registered deaths by year, department, sex, age group: the shared file
#     output/deaths_pop_munic_age_1985_2023.parquet (deaths and DANE
#     population 1985-2023) and data_inter/deaths_munic_age_1979-2023.rds
#     for 1979-1984 (national only, population from WPP 2024)
#   true 5q0, m0 and 4m1: WPP 2024 complete life tables (national, by sex);
#     for departments the DANE abridged life tables 1985-2020 give the
#     departmental pattern, scaled to the WPP national level of the same
#     period (the paper scales ENDS to GBD in the same way, p. 9)
#
# Two variants of the registered deaths: "all" (as in the paper) and
# "non_violent" (homicide, undetermined intent and legal intervention
# removed). The model reads a higher registered CDR as better registration
# (positive coefficient), so where violence adds deaths beyond what 5q0
# implies the "all" variant over-predicts completeness; the paper excludes
# such country-years from its sample (p. 8). The "non_violent" variant is the
# completeness of the registration of non-violent deaths.
#
# output: output/tables/completeness_empirical_national_1979-2023.csv
#         output/tables/completeness_empirical_dept_1985-2023.csv
#         output/tables/completeness_empirical_validation_2014.csv
#         figures/04_completeness/completeness_empirical_national.png
#         figures/04_completeness/completeness_empirical_dept.png
#         figures/04_completeness/completeness_empirical_validation_2014.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(tidyverse); library(arrow)})
options(width = 200)

# ---------------------------------------------------------------------------
# coefficients (Table 2, p. 10) ====
# ---------------------------------------------------------------------------
coefs <- tribble(
  ~model, ~sex, ~cdr2,   ~cdr,   ~p65,     ~lnq5,   ~c5q0,  ~year,   ~const,
  1,      "t",  -0.0177, 0.6375, -13.8914, -1.1136, 2.2063, -0.0174, 29.3677,
  1,      "m",  -0.0174, 0.5957, -12.9528, -1.1266, 2.0030, -0.0188, 32.3442,
  1,      "f",  -0.0198, 0.6959, -17.4154, -1.1720, 1.9387, -0.0144, 23.5542,
  2,      "t",  -0.0238, 0.8419, -19.6118, -1.5135, 0,      -0.0251, 44.3755,
  2,      "m",  -0.0227, 0.7620, -17.3543, -1.4798, 0,      -0.0265, 47.3778,
  2,      "f",  -0.0255, 0.8841, -22.1099, -1.5262, 0,      -0.0217, 37.7887)

# predicted completeness; reg_cdr per 1,000, p65 a fraction, q5 a probability
predict_c <- function(model, sex, reg_cdr, p65, q5, c5q0, year) {
  b <- coefs[match(paste(model, sex), paste(coefs$model, coefs$sex)), ]
  lg <- b$const + b$cdr2 * reg_cdr^2 + b$cdr * reg_cdr + b$p65 * p65 + b$lnq5 * log(q5) +
    b$c5q0 * c5q0 + b$year * year
  plogis(lg)
}

# ---------------------------------------------------------------------------
# true under-five mortality: WPP 2024 national, DANE departmental pattern ====
# ---------------------------------------------------------------------------
lt <- read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Time %in% 1979:2023) |>
  mutate(sex = c(Female = "f", Male = "m", Total = "t")[Sex])
wpp_u5 <- lt |>
  group_by(year = Time, sex) |>
  summarise(q5 = 1 - lx[AgeGrpStart == 5] / lx[AgeGrpStart == 0],
            m0 = mx[AgeGrpStart == 0],
            m1_4 = sum(dx[AgeGrpStart %in% 1:4]) / sum(Lx[AgeGrpStart %in% 1:4]), .groups = "drop")

# DANE abridged tables: nmx at 0 and 1-4 by area, period and sex -> 5q0
dane <- read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE) |>
  filter(age_label %in% c("0", "1a4")) |>
  select(area, period, sex, age, nmx) |>
  pivot_wider(names_from = age, values_from = nmx, names_prefix = "m") |>
  rename(m0 = m0, m1_4 = m1) |>
  mutate(q0 = m0 / (1 + (1 - 0.2) * m0), q1_4 = 4 * m1_4 / (1 + (4 - 1.5) * m1_4),
         q5 = 1 - (1 - q0) * (1 - q1_4), p0 = as.integer(substr(period, 1, 4)))
# both sexes: simple mean of the sex-specific rates (births are ~51 % male)
dane <- bind_rows(dane, dane |> group_by(area, period, p0) |>
                    summarise(across(c(m0, m1_4, q5), mean), sex = "t", .groups = "drop"))
# scale factor by period and sex: WPP national / DANE national, same years
scale_dane <- wpp_u5 |>
  mutate(p0 = pmin(1985 + 5 * ((year - 1985) %/% 5), 2015)) |>
  filter(year >= 1985) |>
  group_by(p0, sex) |> summarise(across(c(q5, m0, m1_4), mean), .groups = "drop") |>
  inner_join(dane |> filter(area == "Nacional") |> select(p0, sex, q5_d = q5, m0_d = m0, m1_4_d = m1_4), by = c("p0", "sex")) |>
  transmute(p0, sex, k_q5 = q5 / q5_d, k_m0 = m0 / m0_d, k_m1 = m1_4 / m1_4_d)

# department code -> DANE life-table area (five Amazon units are one group)
dept_area <- c(`05` = "Antioquia", `08` = "Atlántico", `11` = "Bogotá D.C.", `13` = "Bolívar", `15` = "Boyacá",
               `17` = "Caldas", `18` = "Caquetá", `19` = "Cauca", `20` = "Cesar", `23` = "Córdoba",
               `25` = "Cundinamarca", `27` = "Chocó", `41` = "Huila", `44` = "La Guajira", `47` = "Magdalena",
               `50` = "Meta", `52` = "Nariño", `54` = "Norte de Santander", `63` = "Quindío", `66` = "Risaralda",
               `68` = "Santander", `70` = "Sucre", `73` = "Tolima", `76` = "Valle del Cauca", `81` = "Arauca",
               `85` = "Casanare", `86` = "Putumayo", `88` = "San Andrés", `91` = "Grupo Amazonía",
               `94` = "Grupo Amazonía", `95` = "Grupo Amazonía", `97` = "Grupo Amazonía", `99` = "Grupo Amazonía")

# ---------------------------------------------------------------------------
# registered deaths and population ====
# ---------------------------------------------------------------------------
pq <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |>
  mutate(dx_violent = dx_homicide + dx_undetermined + dx_legal,
         age_band = case_when(is.na(age) ~ "unknown", age == 0 ~ "a0", age == 1 ~ "a1_4", age >= 65 ~ "a65", TRUE ~ "other"))

# aggregate to unit x year x sex: deaths (all, violent, under five), population (total, 65+, 0, 1-4)
agg <- function(d, by) {
  d |>
    # subsets first: a summarised column masks the original one in later expressions
    summarise(dx_u5 = sum(dx_all[age_band %in% c("a0", "a1_4")]), dx_u5_violent = sum(dx_violent[age_band %in% c("a0", "a1_4")]),
              pop65 = sum(pop[age_band == "a65"], na.rm = TRUE),
              pop0 = sum(pop[age_band == "a0"], na.rm = TRUE), pop1_4 = sum(pop[age_band == "a1_4"], na.rm = TRUE),
              dx_all = sum(dx_all), dx_violent = sum(dx_violent), pop = sum(pop, na.rm = TRUE),
              .by = all_of(by))
}
both <- \(x, by) bind_rows(x, x |> summarise(across(c(dx_all, dx_violent, dx_u5, dx_u5_violent, pop, pop65, pop0, pop1_4), sum), .by = all_of(setdiff(by, "sex"))) |> mutate(sex = "t"))

nat85 <- agg(pq, c("year", "sex")) |> both(c("year", "sex")) |> mutate(unit = "Colombia", cod = "00")
dep85 <- agg(pq, c("year", "sex", "cod_dpto", "dpto")) |> both(c("year", "sex", "cod_dpto", "dpto")) |> rename(cod = cod_dpto, unit = dpto)
# the five Amazon units as one group (the paper pools them: each is under 110,000 people)
amaz <- pq |> filter(cod_dpto %in% c("91", "94", "95", "97", "99")) |> agg(c("year", "sex")) |> both(c("year", "sex")) |>
  mutate(unit = "Amazonas, Guainía, Guaviare, Vaupés y Vichada", cod = "9X")

# 1979-1984, national only: deaths from the microdata summary, population from WPP 2024 (thousands)
d79 <- read_rds("data_inter/deaths_munic_age_1979-2023.rds") |>
  filter(year <= 1984, !is.na(sex)) |>
  mutate(age_band = case_when(is.na(age) ~ "unknown", age == 0 ~ "a0", age == 1 ~ "a1_4", TRUE ~ "other")) |>
  summarise(dx_u5 = sum(dx_tot[age_band %in% c("a0", "a1_4")]), dx_u5_violent = sum(dx_v[age_band %in% c("a0", "a1_4")]),
            dx_all = sum(dx_tot), dx_violent = sum(dx_v), .by = c(year, sex))
d79 <- bind_rows(d79, d79 |> summarise(across(-sex, sum), .by = year) |> mutate(sex = "t"))
wpp_pop <- read_csv("data_input/reference/wpp2024_colombia_pop_single_age_1950-2023.csv", show_col_types = FALSE) |>
  filter(Time %in% 1979:1984) |>
  pivot_longer(c(PopMale, PopFemale, PopTotal), names_to = "sex", values_to = "pop") |>
  mutate(sex = c(PopMale = "m", PopFemale = "f", PopTotal = "t")[sex], pop = pop * 1000, year = Time) |>
  summarise(pop65 = sum(pop[AgeGrpStart >= 65]), pop0 = sum(pop[AgeGrpStart == 0]),
            pop1_4 = sum(pop[AgeGrpStart %in% 1:4]), pop = sum(pop), .by = c(year, sex))
nat79 <- d79 |> inner_join(wpp_pop, by = c("year", "sex")) |> mutate(unit = "Colombia", cod = "00")

units <- bind_rows(nat79, nat85, dep85, amaz) |>
  mutate(level = if_else(cod == "00", "national", "department"))

# ---------------------------------------------------------------------------
# inputs of the model and predictions ====
# ---------------------------------------------------------------------------
# Table 6 of the paper (2014, both sexes, deaths by residence): completeness
# (%), RegCDR, %65+, 5q0 (per 1,000; ENDS 2015 scaled to GBD) and C5q0 (%)
paper <- tribble(
  ~unit_paper, ~cod, ~m1_paper, ~m2_paper, ~cdr_paper, ~p65_paper, ~q5_paper, ~c5_paper,
  "National", "00", 84, 87, 4.4, 7.3, 17, 63, "Antioquia", "05", 88, 90, 4.5, 7.6, 14, 64,
  "Arauca", "81", 90, 94, 4.1, 5.0, 12, 61, "Atlántico", "08", 91, 88, 4.5, 6.8, 18, 85,
  "Bogotá", "11", 83, 84, 3.8, 7.2, 15, 66, "Bolívar", "13", 80, 79, 3.6, 6.8, 18, 67,
  "Boyacá", "15", 85, 89, 5.0, 9.6, 14, 57, "Caldas", "17", 96, 96, 5.8, 9.4, 9, 83,
  "Caquetá", "18", 82, 85, 3.6, 5.4, 16, 59, "Casanare", "85", 94, 92, 3.5, 4.7, 11, 88,
  "Cauca", "19", 74, 78, 3.8, 7.5, 19, 54, "Cesar", "20", 79, 79, 3.8, 5.5, 24, 66,
  "Chocó", "27", 53, 53, 2.7, 4.7, 34, 51, "Córdoba", "23", 82, 81, 3.9, 6.4, 19, 67,
  "Cundinamarca", "25", 92, 92, 4.4, 7.5, 11, 74, "Huila", "41", 81, 85, 4.5, 6.7, 20, 56,
  "La Guajira", "44", 25, 29, 2.0, 5.0, 45, 28, "Magdalena", "47", 85, 85, 4.1, 6.3, 18, 71,
  "Meta", "50", 96, 95, 4.6, 6.0, 11, 100, "Nariño", "52", 72, 79, 3.8, 7.4, 18, 47,
  "Norte de Santander", "54", 87, 91, 5.1, 6.9, 17, 56, "Putumayo", "86", 55, 68, 3.1, 5.0, 27, 33,
  "Quindío", "63", 89, 94, 6.4, 9.1, 16, 48, "Risaralda", "66", 93, 94, 5.7, 8.8, 13, 76,
  "Santander", "68", 90, 91, 5.0, 8.2, 14, 71, "Sucre (+ San Andrés)", "70", 91, 86, 3.8, 7.1, 14, 93,
  "Tolima", "73", 84, 89, 5.6, 9.0, 19, 55, "Valle del Cauca", "76", 91, 94, 5.3, 8.1, 13, 64,
  "Vaupés-Guaviare-Amazonas-Vichada-Guainía", "9X", 72, 70, 2.4, 4.1, 20, 65)

# true 5q0, m0, 4m1 for every unit-year-sex. Departments get two sources:
#  "DANE": the DANE 2007 departmental pattern scaled to the WPP national level
#  "DANE-ENDS": the same, rescaled per department so that 2014 (both sexes)
#    matches the survey-based 5q0 the paper used (ENDS 2015 scaled to GBD).
#  DANE's 2007 projections place the peripheral departments (Chocó, Cauca,
#  Nariño, Amazon group) at two to three times the ENDS level, and ln(5q0)
#  enters with a coefficient of -1.1 to -1.5, so the choice matters there.
u5_nat <- units |> filter(level == "national") |> distinct(cod, year, sex) |>
  inner_join(wpp_u5, by = c("year", "sex")) |> mutate(q5_source = "WPP 2024")
u5_dane <- units |> filter(level == "department") |> distinct(cod, year, sex) |>
  mutate(area = if_else(cod == "9X", "Grupo Amazonía", unname(dept_area[cod])),
         p0 = pmin(1985 + 5 * ((year - 1985) %/% 5), 2015)) |>
  inner_join(dane |> select(area, p0, sex, q5, m0, m1_4), by = c("area", "p0", "sex")) |>
  inner_join(scale_dane, by = c("p0", "sex")) |>
  mutate(q5 = q5 * k_q5, m0 = m0 * k_m0, m1_4 = m1_4 * k_m1, q5_source = "DANE") |>
  select(cod, year, sex, q5, m0, m1_4, q5_source)
anchor <- u5_dane |> filter(year == 2014, sex == "t") |>
  inner_join(paper |> select(cod, q5_paper), by = "cod") |>
  transmute(cod, r = (q5_paper / 1000) / q5)
# the five Amazon units take the group's ratio; San Andrés (pooled with Sucre in the paper) keeps DANE
anchor <- bind_rows(anchor, tibble(cod = c("91", "94", "95", "97", "99"), r = anchor$r[anchor$cod == "9X"]))
u5_ends <- u5_dane |> left_join(anchor, by = "cod") |>
  mutate(r = coalesce(r, 1), across(c(q5, m0, m1_4), ~ .x * r), q5_source = "DANE-ENDS") |> select(-r)
u5 <- bind_rows(u5_nat, u5_dane, u5_ends)

inputs <- units |>
  inner_join(u5, by = c("cod", "year", "sex"), relationship = "many-to-many") |>
  crossing(variant = c("all", "non_violent")) |>
  mutate(registered = if_else(variant == "all", dx_all, dx_all - dx_violent),
         registered_u5 = if_else(variant == "all", dx_u5, dx_u5 - dx_u5_violent),
         reg_cdr = 1000 * registered / pop,
         p65 = pop65 / pop,
         expected_u5 = pop0 * m0 + pop1_4 * m1_4,
         c5q0 = pmin(registered_u5 / expected_u5, 1.2))

res <- inputs |>
  crossing(model = c(1, 2)) |>
  mutate(completeness = predict_c(model, sex, reg_cdr, p65, q5, c5q0, year),
         expected = registered / completeness) |>
  select(level, cod, unit, year, sex, variant, q5_source, model, registered, pop, reg_cdr, p65, q5, c5q0, completeness, expected) |>
  arrange(level, cod, year, sex, variant, q5_source, model)

write_csv(res |> filter(level == "national"), "output/tables/completeness_empirical_national_1979-2023.csv")
write_csv(res |> filter(level == "department"), "output/tables/completeness_empirical_dept_1985-2023.csv")

# ---------------------------------------------------------------------------
# validation: Table 6 of the paper (2014, both sexes, residence) ====
# ---------------------------------------------------------------------------
val <- res |> filter(year == 2014, sex == "t", variant == "all") |>
  select(cod, unit, q5_source, model, reg_cdr, p65, q5, c5q0, completeness) |>
  pivot_wider(names_from = model, values_from = completeness, names_prefix = "m") |>
  inner_join(paper, by = "cod") |>
  mutate(across(c(m1, m2), ~ round(100 * .x)), reg_cdr = round(reg_cdr, 1), p65 = round(100 * p65, 1),
         q5 = round(1000 * q5), c5q0 = round(100 * c5q0)) |>
  select(unit, q5_source, m1, m1_paper, m2, m2_paper, reg_cdr, cdr_paper, p65, p65_paper, q5, q5_paper, c5q0, c5_paper)
write_csv(val, "output/tables/completeness_empirical_validation_2014.csv")
cat("validation against Table 6 (2014, both sexes):\n"); print(val, n = 60)
for (s in unique(val$q5_source)) {
  v <- val |> filter(q5_source == s)
  cat(sprintf("%-10s model 1: mean diff %5.1f, RMSD %4.1f | model 2: mean diff %5.1f, RMSD %4.1f (points, ours minus paper, %d units)\n", s,
              mean(v$m1 - v$m1_paper), sqrt(mean((v$m1 - v$m1_paper)^2)),
              mean(v$m2 - v$m2_paper), sqrt(mean((v$m2 - v$m2_paper)^2)), nrow(v)))
}

# ---------------------------------------------------------------------------
# figures ====
# ---------------------------------------------------------------------------
sex_lab <- c(f = "Mujeres", m = "Hombres", t = "Ambos sexos")
other <- read_csv("output/tables/completeness_wpp_mse_annual.csv", show_col_types = FALSE) |>
  filter(year >= 1979) |>
  select(year, sex, `WPP sin conflicto + MSE`, `DDM (23)`) |>
  pivot_longer(-c(year, sex), names_to = "serie", values_to = "completeness")

nat <- res |> filter(level == "national") |>
  mutate(serie = sprintf("Empírica, modelo %d, %s", model, if_else(variant == "all", "todas las defunciones", "sin violentas")))
p1 <- ggplot() +
  geom_line(data = other, aes(year, completeness, linetype = serie), colour = "grey35", linewidth = 0.5) +
  geom_line(data = nat, aes(year, completeness, colour = serie), linewidth = 0.8) +
  facet_wrap(~ sex_lab[sex], nrow = 1) +
  scale_colour_manual(values = c("#9ecae1", "#3182bd", "#fdae6b", "#e6550d"), name = NULL) +
  scale_linetype_manual(values = c("dashed", "dotted"), name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0.5, 1.05), breaks = seq(0.5, 1, 0.1)) +
  labs(x = NULL, y = "Completitud del registro de defunciones",
       title = "Completitud empírica (Adair y Lopez 2018) frente al DDM y a WPP sin conflicto + MSE, Colombia 1979-2023",
       subtitle = "Modelo 1 usa la completitud del registro de menores de cinco años; modelo 2 no. 'Sin violentas' quita homicidios, intención no determinada e intervención legal de las defunciones registradas",
       caption = "5q0 de WPP 2024; población DANE 1985-2023 y WPP 1979-1984. Sin efecto aleatorio de país (no publicado). Script: code/33_completeness_empirical.R") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", legend.box = "vertical", plot.title.position = "plot")
ggsave("figures/04_completeness/completeness_empirical_national.png", p1, width = 13, height = 6.5, dpi = 200, bg = "white")

dep <- res |> filter(level == "department", sex == "t", model == 2, variant == "non_violent", q5_source == "DANE-ENDS", cod != "9X") |>
  mutate(unit = sub("Archipiélago de San Andrés.*", "San Andrés y Providencia", unit), unit = fct_reorder(unit, completeness, mean))
p2 <- ggplot(dep, aes(year, unit, fill = pmin(completeness, 1))) +
  geom_tile() +
  scale_fill_distiller(palette = "Blues", direction = 1, labels = scales::percent, name = "Completitud", limits = c(0.2, 1)) +
  scale_x_continuous(breaks = seq(1985, 2020, 5), expand = c(0, 0)) +
  labs(x = NULL, y = NULL, title = "Completitud empírica por departamento, 1985-2023 (modelo 2, sin violentas, ambos sexos)",
       subtitle = "5q0 departamental: patrón DANE 1985-2020 escalado a WPP 2024 y anclado en 2014 a la ENDS 2015 (Adair y Lopez, tabla 6); ordenado por completitud media. Defunciones por lugar de ocurrencia",
       caption = "Script: code/33_completeness_empirical.R") +
  theme_minimal(base_size = 11) + theme(panel.grid = element_blank(), plot.title.position = "plot")
ggsave("figures/04_completeness/completeness_empirical_dept.png", p2, width = 11, height = 8, dpi = 200, bg = "white")

val_long <- bind_rows(val |> filter(q5_source != "WPP 2024"),
                      val |> filter(q5_source == "WPP 2024") |> select(-q5_source) |> crossing(q5_source = c("DANE", "DANE-ENDS"))) |>
  pivot_longer(c(m1, m2), names_to = "model", values_to = "ours") |>
  mutate(paper = if_else(model == "m1", m1_paper, m2_paper), model = c(m1 = "Modelo 1", m2 = "Modelo 2")[model],
         q5_source = c(DANE = "5q0 departamental DANE escalada a WPP", `DANE-ENDS` = "5q0 DANE anclada en 2014 a la ENDS 2015")[q5_source],
         unit = sub("Amazonas, Guainía.*", "Grupo Amazonía", unit))
p3 <- ggplot(val_long, aes(paper, ours)) +
  geom_abline(colour = "grey60", linetype = "dashed") +
  geom_point(colour = "#3182bd", size = 2) +
  ggrepel::geom_text_repel(aes(label = if_else(abs(ours - paper) >= 5, unit, "")), size = 2.5, colour = "grey30", max.overlaps = 30, seed = 1) +
  facet_grid(q5_source ~ model) + coord_equal(xlim = c(20, 105), ylim = c(20, 105)) +
  labs(x = "Adair y Lopez 2018, tabla 6 (%)", y = "Este proyecto (%)",
       title = "Validación: completitud 2014 por departamento, ambos sexos, todas las defunciones",
       subtitle = "Etiquetas donde la diferencia es de 5 puntos o más. Otras fuentes de diferencia: población (proyecciones DANE 2005 en el paper;\nbase censo 2018 aquí) y lugar (residencia en el paper; ocurrencia aquí). Sucre incluye San Andrés en el paper, no aquí",
       caption = "Script: code/33_completeness_empirical.R") +
  theme_minimal(base_size = 11) + theme(plot.title.position = "plot")
ggsave("figures/04_completeness/completeness_empirical_validation_2014.png", p3, width = 11, height = 10.5, dpi = 200, bg = "white")

# summary of the national series
cat("\nnational completeness, both sexes, selected years:\n")
res |> filter(level == "national", sex == "t", year %in% c(1979, 1985, 1990, 1995, 2000, 2005, 2010, 2014, 2018, 2023)) |>
  mutate(k = sprintf("m%d_%s", model, variant)) |>
  select(year, k, completeness) |> pivot_wider(names_from = k, values_from = completeness) |>
  mutate(across(-year, ~ round(100 * .x, 1))) |> print()
