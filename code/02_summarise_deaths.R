# 02_summarise_deaths.R ------------------------------------------------------
# collapses the microdata to municipal death counts by sex (and, in a second
# table, by 5-year age group), for all causes and for the violent-death groups
# used downstream:
#   dx_tot  all deaths
#   dx_h    homicide (list 105 code 101)
#   dx_v    violent deaths = homicide + undetermined intent + legal intervention
#           (101, 102, 103): the dependent variable of the model
#   dx_e    all external causes (90-105)
#
# age is recomputed from gr_edad here, so the result does not depend on which
# version of 01 produced the .rds. rows with unknown sex or age are kept
# (sex = NA, age = NA); the panel builder drops them.

rm(list = ls())
gc()
source("code/00_setup.R")

dt <- read_rds("data_inter/micro_1979_2023.rds")

dt2 <-
  dt |>
  as_tibble() |>
  transmute(
    year = ano,
    cod_dpto = as.integer(cod_dpto),
    cod_munic = as.integer(cod_munic),
    sex = sexo,
    age = recode_age_group(gr_edad, ano),
    is_h = cod_col %in% codes_homicide,
    is_v = cod_col %in% codes_violent,
    is_e = cod_col %in% codes_external
  )

# by municipality, sex and age group
deaths_age <-
  dt2 |>
  summarise(
    dx_tot = n(),
    dx_h = sum(is_h),
    dx_v = sum(is_v),
    dx_e = sum(is_e),
    .by = c(year, cod_dpto, cod_munic, sex, age)
  ) |>
  arrange(year, cod_dpto, cod_munic, sex, age)

# by municipality and sex, all ages (including unknown age)
deaths <-
  deaths_age |>
  summarise(
    across(c(dx_tot, dx_h, dx_v, dx_e), sum),
    .by = c(year, cod_dpto, cod_munic, sex)
  ) |>
  arrange(year, cod_dpto, cod_munic, sex)

# checks: totals must agree with the microdata
stopifnot(sum(deaths$dx_tot) == nrow(dt))
print(deaths |> summarise(across(c(dx_tot, dx_h, dx_v, dx_e), sum), .by = year), n = 50)

write_rds(deaths, "data_inter/deaths_munic_1979-2023.rds")
write_rds(deaths_age, "data_inter/deaths_munic_age_1979-2023.rds")
