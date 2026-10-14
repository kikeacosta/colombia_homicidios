# 17_residence.R -------------------------------------------------------------
# does tabulating deaths by place of RESIDENCE instead of OCCURRENCE change the
# sex ratio - homicide relationship? (plan B4.2)
#
# the project's deaths are by occurrence (COD_DPTO) while population is by
# residence. DANE's microdata also carry residence (CODPTORE). deaths are
# re-tabulated by department of residence here, by year, sex, age band and
# violent / other, 1985-2017, and compared with the occurrence-based series.
# deaths of residents of a foreign country or with unknown residence are
# dropped from the residence series.
#
# reads the raw files in data_input/micro (a few minutes).
#
# outputs: output/tables/residence_vs_occurrence_*.csv

rm(list = ls())
gc()
source("code/00_setup.R")
library(arrow)

files <- list.files("data_input/micro", pattern = "[.]txt$|[.]csv$", full.names = TRUE)
rd <- function(f) {
  nm <- names(fread(f, nrows = 0))
  low <- tolower(nm)
  want <- c("cod_dpto", "ano", "sexo", "gru_ed1", "codptore", "cau_homol")
  stopifnot(all(want %in% low))
  x <- fread(f, select = nm[match(want, low)], colClasses = "character")
  setnames(x, want)
  x[, year := as.integer(str_extract(basename(f), "[0-9]{4}"))]
  x
}
raw <- bind_rows(lapply(files, rd))
cat("rows:", nrow(raw), "\n")

dt <-
  raw |>
  as_tibble() |>
  filter(year %in% 1985:2017) |>
  transmute(
    year,
    sex = case_when(sexo == "1" ~ "m", sexo == "2" ~ "f", TRUE ~ NA_character_),
    age = recode_age_group(as.integer(gru_ed1), year),
    occ = sprintf("%02d", suppressWarnings(as.integer(cod_dpto))),
    res = sprintf("%02d", suppressWarnings(as.integer(codptore))),
    viol = as.integer(cau_homol) %in% 101:103
  ) |>
  filter(!is.na(sex))

cat("share of deaths with residence outside the 33 departments or unknown:\n")
valid <- c(sprintf("%02d", c(5, 8, 11, 13, 15, 17, 18, 19, 20, 23, 25, 27, 41, 44, 47, 50, 52, 54, 63, 66, 68, 70, 73, 76, 81, 85, 86, 88, 91, 94, 95, 97, 99)))
print(round(mean(!dt$res %in% valid), 4))
cat("share where residence department differs from occurrence department (both valid):",
    round(mean(dt$res != dt$occ & dt$res %in% valid & dt$occ %in% valid), 4), "\n")

# population by department, year, sex, age band (residence basis)
pop <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |>
  filter(!is.na(age), year <= 2017) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)),
         band = case_when(age >= 15 & age <= 40 ~ "15-44", age >= 50 & age <= 75 ~ "50-79", TRUE ~ "other")) |>
  summarise(pop = sum(pop, na.rm = TRUE), .by = c(year, cod_dpto, sex, band))

tab <- function(key) {
  dt |>
    mutate(band = case_when(age >= 15 & age <= 40 ~ "15-44", age >= 50 & age <= 75 ~ "50-79", TRUE ~ "other"),
           cod_dpto = .data[[key]]) |>
    filter(cod_dpto %in% valid, cod_dpto != "88") |>
    summarise(dx = n(), v = sum(viol), .by = c(year, cod_dpto, sex, band)) |>
    mutate(basis = key)
}
both <- bind_rows(tab("occ"), tab("res")) |> left_join(pop, by = c("year", "cod_dpto", "sex", "band"))

sr <-
  both |>
  filter(band != "other") |>
  mutate(mx = dx / pop) |>
  select(year, cod_dpto, basis, band, sex, mx) |>
  pivot_wider(names_from = sex, values_from = mx) |>
  mutate(sr = m / f)

hom <-
  both |>
  summarise(v = sum(v), pop = sum(pop), .by = c(year, cod_dpto, basis)) |>
  mutate(log_h = log(v / pop))

an <-
  sr |>
  select(year, cod_dpto, basis, band, sr) |>
  pivot_wider(names_from = band, values_from = sr, names_prefix = "sr_") |>
  left_join(hom |> select(year, cod_dpto, basis, log_h), by = c("year", "cod_dpto", "basis")) |>
  filter(is.finite(log_h), is.finite(`sr_15-44`)) |>
  mutate(caribe = cod_dpto %in% cod_caribe, per = ifelse(year < 1998, "1985-1997", "1998-2017"),
         l = log(`sr_15-44`)) |>
  arrange(basis, cod_dpto, year)

res <-
  an |>
  summarise(r_levels = cor(l, log_h), r_diff = cor(diff(l), diff(log_h)), .by = c(basis, cod_dpto, caribe, per)) |>
  summarise(levels = mean(r_levels, na.rm = TRUE), first_diff = mean(r_diff, na.rm = TRUE),
            n_dept = n(), .by = c(basis, caribe, per)) |>
  arrange(caribe, per, basis)
cat("\nage 15-44: correlation of log sex ratio with log violent-death rate, mean across departments\n")
print(res |> mutate(across(where(is.numeric), ~ round(.x, 2))) |> as.data.frame(), row.names = FALSE)

write_csv(res, "output/tables/residence_vs_occurrence_correlations.csv")
write_csv(an, "output/tables/residence_vs_occurrence_series.csv")

# net flow: deaths by residence relative to occurrence, Caribbean departments
flow <-
  both |>
  filter(band != "other", year %in% c(1985, 1990, 1995, 1997, 2000, 2010)) |>
  summarise(dx = sum(dx), .by = c(year, cod_dpto, basis)) |>
  pivot_wider(names_from = basis, values_from = dx) |>
  mutate(res_over_occ = res / occ) |>
  filter(cod_dpto %in% cod_caribe)
cat("\nratio of resident to occurrence deaths, Caribbean departments, ages 15-79\n")
print(flow |> select(year, cod_dpto, res_over_occ) |> pivot_wider(names_from = year, values_from = res_over_occ) |>
        mutate(across(where(is.numeric), ~ round(.x, 2))) |> as.data.frame(), row.names = FALSE)
