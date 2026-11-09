# diagnostics of data quality

rm(list = ls())
gc()
source("code/00_setup.R")

# col_gap_analysis transcriptions of the DANE anuarios (the v01/v02 files
# they replace are in data_input/historical/archive_v01_v02/); columns renamed
# to the names of the old files. Departmental deaths: territories_aggregated
# variant (25 units). The national homicide series is the sum of the
# departments with data in each year.
hist_dir <- "data_input/historical/"
read_hist <- function(file, prefix, delim = ",") {
  read_delim(paste0(hist_dir, "col_gap_analysis_1920_1985_", file), delim = delim,
             show_col_types = FALSE, guess_max = 1e5) |>
    mutate(across(any_of("department"), str_to_upper)) |>
    rename_with(~ paste0(prefix, "_", .x), any_of(c("total", "male", "female")))
}

hms_dto <- read_hist("department_homicides_clean_v02.csv", "homicide")
hms_nal <-
  hms_dto |>
  filter(!is.na(homicide_total)) |>
  summarise(across(c(homicide_total, homicide_male, homicide_female), sum),
            n_dept_with_data = n(), .by = year) |>
  arrange(year)

dts_mun <- read_hist("municipal_deaths_clean_v03.csv", "deaths")
dts_dto <- read_hist("department_deaths_clean_v06_territories_aggregated.csv", "deaths", delim = ";")
dts_nal <- read_hist("national_deaths_clean_v03.csv", "deaths", delim = ";")

pop_mun <- read_hist("municipal_population_clean_v03.csv", "pop")
pop_dto <- read_hist("department_population_clean_v03.csv", "pop", delim = ";")
pop_nal <- read_hist("national_population_clean_v02.csv", "pop", delim = ";")


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

dts_nal_std <- dts_nal |> select(year, tot = deaths_total, m = deaths_male, f = deaths_female)
pop_nal_std <- pop_nal |> select(year, tot = pop_total, m = pop_male, f = pop_female)

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
dts_nal_tst <- add_tests(dts_nal_std)
pop_nal_tst <- add_tests(pop_nal_std)

# summareizing tests
tst_all <-
  bind_rows(
    summ_this(hms_nal_tst, "homicides national"),
    summ_this(hms_dto_tst, "homicides department"),
    summ_this(dts_nal_tst, "deaths national"),
    summ_this(dts_mun_tst, "deaths municipal"),
    summ_this(dts_dto_tst, "deaths department"),
    summ_this(pop_nal_tst, "population national"),
    summ_this(pop_mun_tst, "population municipal"),
    summ_this(pop_dto_tst, "population department")
  )

# the departmental deaths (territories aggregated) add up to the national
# file except in 1926, 1931, 1932, 1934 (national lower than the sum) and
# 1956-1961 (Bogota listed separately and still inside Cundinamarca), plus
# rounding in 1943 and 1969
chk_nal <-
  dts_dto |>
  summarise(dto_sum = sum(deaths_total, na.rm = TRUE), .by = year) |>
  inner_join(dts_nal |> select(year, nal = deaths_total), by = "year") |>
  filter(dto_sum != nal)
cat("years where the departmental sum differs from the national file:", nrow(chk_nal), "\n")
if (nrow(chk_nal) > 0) print(chk_nal)

print(tst_all)

# saving files with observations
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
write_csv(hms_nal_tst, "data_inter/q_test/hms_nal_tst.csv")
write_csv(hms_dto_tst, "data_inter/q_test/hms_dto_tst.csv")
write_csv(dts_mun_tst, "data_inter/q_test/dts_mun_tst.csv")
write_csv(dts_dto_tst, "data_inter/q_test/dts_dto_tst.csv")
write_csv(pop_mun_tst, "data_inter/q_test/pop_mun_tst.csv")
write_csv(pop_dto_tst, "data_inter/q_test/pop_dto_tst.csv")
write_csv(dts_nal_tst, "data_inter/q_test/dts_nal_tst.csv")
write_csv(pop_nal_tst, "data_inter/q_test/pop_nal_tst.csv")
