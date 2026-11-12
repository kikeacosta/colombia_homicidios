# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 47. Crisis deaths the registry could not see: Armero, La Violencia and the
#     police homicide count, by year, sex and age, 1950-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The adjusted series (42) corrects the registered deaths component by
# component, and the violent component gets no completeness factor: from
# 1979 violent deaths are certified by legal medicine. That leaves out the
# deaths that never entered the registry, which the MSE covers only in
# 1985-2018. This script builds a fifth component, "crisis", from three
# external counts, each used as a floor of the registered violent deaths of
# the year (the larger of the sources is taken, the usual rule when two
# counts of homicides disagree), plus the Armero disaster:
#
#   police      Policía Nacional homicides 1962-2002 by jurisdiction
#               (data_input/historical/Homicidio 1962-2002 por depto de
#               Policía_v1.xlsx, TOTAL row). Above the EEVV violent deaths in
#               1963-1968 (by 8-52 %) and 1978-1984 (2-17 %); below them from
#               1985, where the MSE applies. Police counts are homicides only
#               (no undetermined intent, no legal intervention), so where they
#               fall short of the EEVV the difference is definitional, not
#               under-registration
#   violencia   Romero-Prieto and Meisel-Roca (2019), Análisis demográfico de
#               la Violencia en Colombia, Cuadernos de Historia Económica 50,
#               Banco de la República, Cuadro 1: violent deaths 1945-1969 by
#               sex estimated from censuses and vital records with life
#               tables ("todas las muertes violentas"; the "descontando
#               1945-47" variant is kept in the file but not used). Their
#               figures are 20-40 % above the registered violent deaths of
#               1950-1968, consistent with the adult completeness of those
#               years. Oquist's (1978) annual series (43,557 deaths in 1948,
#               50,516 in 1950; 160,474 in 1948-1957) comes from a
#               retrospective survey of 5,800 households and is rejected by
#               Romero-Prieto and Meisel-Roca; it is not used
#   armero      the Nevado del Ruiz eruption, 13 November 1985: WPP 2024's
#               disaster mortality for Colombia (EM-DAT count, 22,654 deaths
#               implied by WPP's rates on its population; 26, file
#               wpp2024_crises_colombia_mx1_disasters.csv) by sex and single
#               age, aggregated to the age groups of the series. The registry
#               shows no trace of it: the other external deaths of 1985 are
#               688 above the mean of 1984 and 1986. Other EM-DAT disasters
#               (at most 1,330 deaths, Armenia 1999) are left to the registry
#
# The floors act on the national totals of the year, against the EEVV violent
# deaths plus the MSE conflict deaths already added in 1985-2018 (27); the
# extra deaths are distributed by sex and age with the EEVV violent pattern
# of the same year (40), so the crisis component has the age profile of
# registered violence.
#   crisis(year) = max(eevv + mse, police, violencia) - (eevv + mse)
#                  [+ armero in 1985]
#
# output: output/tables/crisis_deaths_1950-2023.csv
#           (year, sex, age, police, violencia, armero, crisis)
#         figures/06_components/crisis_deaths.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(dplyr); library(tidyr); library(readr); library(readxl); library(ggplot2)})

comp <- read_csv("output/tables/deaths_components_registered_1950-2023.csv", show_col_types = FALSE) |>
  select(year, sex, age, registered, violent)
# the MSE conflict deaths already added to the violent component in 1985-2018 (27, 42)
mse <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |>
  summarise(mse = sum(hom_excess + dsp), .by = year)
eevv <- comp |> summarise(eevv = sum(violent), registered = sum(registered), .by = year) |>
  left_join(mse, by = "year") |> mutate(mse = replace_na(mse, 0), eevv_mse = eevv + mse)

# ---- external counts, national totals ---------------------------------------
police <- read_excel("data_input/historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx", sheet = 1) |>
  filter(Jurisdiccion == "TOTAL") |>
  pivot_longer(-Jurisdiccion, names_to = "year", values_to = "police") |>
  transmute(year = as.integer(year), police)
rpm <- read_csv("data_input/reference/romero_meisel_2019_violent_deaths_1945_1969.csv", show_col_types = FALSE) |>
  transmute(year, violencia = total_all)

floors <- eevv |>
  left_join(police, by = "year") |> left_join(rpm, by = "year") |>
  mutate(police = replace_na(police, 0), violencia = replace_na(violencia, 0),
         extra_police = pmax(police - eevv_mse, 0),
         extra_violencia = pmax(violencia - pmax(eevv_mse, police), 0))
cat("years with a floor above the EEVV violent deaths plus the MSE conflict deaths:\n")
print(floors |> filter(extra_police > 0 | extra_violencia > 0) |>
        transmute(year, eevv = round(eevv), mse = round(mse), police, violencia, extra_police = round(extra_police), extra_violencia = round(extra_violencia)) |> as.data.frame())
cat(sprintf("total extra: police %s, violencia %s\n", format(round(sum(floors$extra_police)), big.mark = ","), format(round(sum(floors$extra_violencia)), big.mark = ",")))

# ---- distribute by sex and age with the EEVV violent pattern of the year -----
pattern <- comp |> mutate(share = violent / sum(violent), .by = year) |> select(year, sex, age, share)
stopifnot(all(abs(pattern |> summarise(s = sum(share), .by = year) |> pull(s) - 1) < 1e-9))
crisis <- pattern |>
  left_join(floors |> select(year, extra_police, extra_violencia), by = "year") |>
  mutate(police = share * extra_police, violencia = share * extra_violencia) |>
  select(year, sex, age, police, violencia)

# ---- Armero 1985 from WPP's disaster mortality --------------------------------
pop1 <- read_csv("data_input/reference/wpp2024_colombia_pop_single_age_1950-2023.csv", show_col_types = FALSE) |>
  transmute(year = Time, age1 = AgeGrpStart, m = PopMale * 1000, f = PopFemale * 1000) |>
  pivot_longer(c(m, f), names_to = "sex", values_to = "pop")
armero <- read_csv("data_input/reference/wpp2024_crises_colombia_mx1_disasters.csv", show_col_types = FALSE) |>
  transmute(year = Year, sex = substr(Sex, 1, 1), age1 = age_start, mx = value) |>
  filter(year == 1985) |>
  inner_join(pop1, by = c("year", "sex", "age1")) |>
  mutate(age = case_when(age1 == 0 ~ 0, age1 < 5 ~ 1, TRUE ~ pmin(age1 %/% 5 * 5, 80))) |>
  summarise(armero = sum(mx * pop), .by = c(year, sex, age))
cat(sprintf("Armero 1985, deaths implied by WPP's disaster rates: %s (men %s, women %s)\n",
            format(round(sum(armero$armero)), big.mark = ","), format(round(sum(armero$armero[armero$sex == "m"])), big.mark = ","),
            format(round(sum(armero$armero[armero$sex == "f"])), big.mark = ",")))

crisis <- crisis |>
  left_join(armero, by = c("year", "sex", "age")) |>
  mutate(armero = replace_na(armero, 0), crisis = police + violencia + armero) |>
  arrange(year, sex, age)
stopifnot(nrow(crisis) == nrow(comp), !anyNA(crisis$crisis))
write_csv(crisis, "output/tables/crisis_deaths_1950-2023.csv")

# ---- figure -----------------------------------------------------------------
ann <- crisis |> summarise(across(c(police, violencia, armero), sum), .by = year) |>
  left_join(eevv, by = "year") |>
  mutate(share = (police + violencia + armero) / registered)
cat("\ncrisis deaths by decade and source, and their share of registered deaths in the peak year:\n")
print(ann |> mutate(dec = paste0(year %/% 10 * 10, "s")) |>
        summarise(police = round(sum(police)), violencia = round(sum(violencia)), armero = round(sum(armero)), max_share = round(100 * max(share), 1), .by = dec) |> as.data.frame())
lab <- c(violencia = "La Violencia (Romero-Prieto y Meisel-Roca 2019)", police = "Policía Nacional sobre EEVV", armero = "Armero 1985 (WPP / EM-DAT)")
p <- ann |> select(year, police, violencia, armero) |>
  pivot_longer(-year, names_to = "source", values_to = "deaths") |>
  filter(deaths > 0) |>
  mutate(source = factor(lab[source], lab)) |>
  ggplot(aes(year, deaths / 1000, fill = source)) +
  geom_col(width = 0.9) +
  scale_fill_manual(values = c("#d6641a", "#1f5fa6", "#7a7a7a"), name = NULL) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), limits = c(1949, 2024)) +
  labs(x = NULL, y = "Muertes añadidas (miles)",
       title = "Componente de crisis: muertes que el registro no recogió",
       subtitle = "Piso de las violentas registradas con la Policía y con la serie demográfica de La Violencia, más Armero") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", legend.direction = "vertical", panel.grid.minor = element_blank())
ggsave("figures/06_components/crisis_deaths.png", p, width = 9, height = 5.5, bg = "white", dpi = 150)
cat("written: output/tables/crisis_deaths_1950-2023.csv, figures/06_components/crisis_deaths.png\n")
