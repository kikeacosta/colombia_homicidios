# diagnostics of data quality

rm(list = ls())
gc()
source("code/00_setup.R")

hms_dto <- read_csv("data_input/historical/homicides_department_v02.csv")
hms_nal <- read_csv("data_input/historical/homicides_national_v02.csv")

dts_mun <- read_csv("data_input/historical/deaths_municipal_v01.csv")
dts_dto <- read_csv("data_input/historical/deaths_department_v01.csv")

pop_mun <- read_csv("data_input/historical/population_municipal_v01.csv")
pop_dto <- read_csv("data_input/historical/population_department_v01.csv")


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# testing quality of historical data ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

hms_nal_std <-
  hms_nal |>
  select(
    year,
    tot = homicide_total,
    m = homicide_male,
    f = homicide_female
  )

hms_dto_std <-
  hms_dto |>
  select(
    dto = department,
    year,
    tot = homicide_total,
    m = homicide_male,
    f = homicide_female
  )

dts_mun_std <-
  dts_mun |>
  select(
    dpto = department,
    mun = municipality,
    year,
    tot = deaths_total,
    m = deaths_male,
    f = deaths_female
  )

dts_dto_std <-
  dts_dto |>
  select(
    dpto = department,
    year,
    tot = deaths_total,
    m = deaths_male,
    f = deaths_female
  )

pop_mun_std <-
  pop_mun |>
  select(
    dpto = department,
    mun = municipality,
    year,
    tot = pop_total,
    m = pop_male,
    f = pop_female
  )

pop_dto_std <-
  pop_dto |>
  select(
    dpto = department,
    year,
    tot = pop_total,
    m = pop_male,
    f = pop_female
  )

# functions for testing and summarizing the data files
{
  add_tests <- function(db) {
    db |>
      mutate(tot_sum = m + f, tst = tot == tot_sum) |>
      mutate(
        obs = case_when(
          !is.na(m) & is.na(f) ~ "missing female 0",
          is.na(m) & !is.na(f) ~ "missing male 0",
          !is.na(m) & !is.na(f) & is.na(tot) ~ "missing total",
          is.na(m) & is.na(f) & !is.na(tot) ~ "missing by sex, maybe ok",
          is.na(m) & is.na(f) & is.na(tot) ~ "missing all",
          !is.na(m) &
            !is.na(f) &
            tot_sum != tot &
            (m != 0 & f != 0) ~ "total mismatch",
          m == 0 & f == 0 & tot > 0 ~ "NAs as 0s",
          TRUE ~ "ok"
        )
      )
  }

  summ_this <- function(db, src) {
    db |>
      summarise(n = n(), .by = obs) |>
      spread(obs, n) |>
      mutate(data = src) |>
      select(data, everything())
  }
}

# testing data
hms_dto_tst <- add_tests(hms_dto_std)
hms_nal_tst <- add_tests(hms_nal_std)
dts_mun_tst <- add_tests(dts_mun_std)
dts_dto_tst <- add_tests(dts_dto_std)
pop_mun_tst <- add_tests(pop_mun_std)
pop_dto_tst <- add_tests(pop_dto_std)

# summareizing tests
tst_all <-
  bind_rows(
    summ_this(hms_nal_tst, "homicides national"),
    summ_this(hms_dto_tst, "homicides department"),
    summ_this(dts_mun_tst, "deaths municipal"),
    summ_this(dts_dto_tst, "deaths department"),
    summ_this(pop_mun_tst, "population municipal"),
    summ_this(pop_dto_tst, "population department")
  )

print(tst_all)

# saving files with observations
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
write_csv(hms_nal_tst, "data_inter/q_test/hms_nal_tst.csv")
write_csv(hms_dto_tst, "data_inter/q_test/hms_dto_tst.csv")
write_csv(dts_mun_tst, "data_inter/q_test/dts_mun_tst.csv")
write_csv(dts_dto_tst, "data_inter/q_test/dts_dto_tst.csv")
write_csv(pop_mun_tst, "data_inter/q_test/pop_mun_tst.csv")
write_csv(pop_dto_tst, "data_inter/q_test/pop_dto_tst.csv")
