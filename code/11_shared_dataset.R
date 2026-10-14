# 11_shared_dataset.R --------------------------------------------------------
# tidy file for sharing: deaths by cause group and population, by year,
# municipality and sex, 1985-2023.
#
#   deaths: DANE EEVV microdata (place of OCCURRENCE), from 01
#   population: DANE retroprojections 1985-2017 (output of 03) and projections
#   2018-2042 (PPED workbook), both on the 2018-census base; population is by
#   place of RESIDENCE.
#
# writes output/deaths_pop_munic_1985_2023.csv.gz
# columns: year, sex, cod_dpto, dpto, cod_munic, munic, pop, dx_all,
#          dx_homicide, dx_undetermined, dx_legal, dx_suicide, dx_accident,
#          dx_residual   (the six cause columns sum to dx_all)

rm(list = ls())
gc()
source("code/00_setup.R")

yrs <- 1985:2023
dir.create("output", showWarnings = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# population ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

pop_a <-
  read_rds("data_inter/pop_munic_1985-2017.rds") |>
  filter(sex %in% c("m", "f")) |>
  summarise(pop = sum(pop), .by = c(year, cod_dpto, dpto, cod_munic, munic, sex)) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)))

# 2018-2042 workbook: columns are DP, DPNOM, MPIO (5-digit code), DPMP
# (name), year, area, total, men, women, then age columns. keep the "Total"
# area rows and the sex totals.
f_pped <- "data_input/DANEpop/PPED-AreaSexoEdadMun-2018-2042_VP.xlsx"
sheet_pped <- grep("Mun", excel_sheets(f_pped), value = TRUE)[1]

pop_b <-
  read_xlsx(
    f_pped,
    sheet = sheet_pped,
    skip = 7,
    col_names = FALSE,
    col_types = "text"
  )[, 1:9]
names(pop_b) <- c("cod_dpto", "dpto", "cod_munic", "munic", "year", "area", "total", "m", "f")
pop_b <-
  pop_b |>
  filter(area == "Total", !is.na(cod_munic)) |>
  mutate(across(c(year, m, f), as.numeric)) |>
  filter(year %in% 2018:max(yrs)) |>
  pivot_longer(c(m, f), names_to = "sex", values_to = "pop") |>
  select(year, cod_dpto, dpto, cod_munic, munic, sex, pop)

pop <- bind_rows(pop_a, pop_b) |> filter(year %in% yrs)

# names: latest available per code
names_tab <-
  pop |>
  arrange(cod_munic, desc(year)) |>
  distinct(cod_munic, .keep_all = TRUE) |>
  select(cod_munic, cod_dpto, dpto, munic)

pop <-
  pop |>
  select(year, cod_munic, sex, pop) |>
  complete(year = yrs, cod_munic, sex = c("m", "f"))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# deaths ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dt <- read_rds("data_inter/micro_1979_2023.rds") |> as_tibble()

dx <-
  dt |>
  filter(ano %in% yrs) |>
  transmute(
    year = ano,
    sex = sexo,
    cod_munic = make_cod_munic(cod_dpto, cod_munic),
    group = cause_groups_shared(cod_col)
  )

n_tot <- nrow(dx)
n_nosex <- sum(is.na(dx$sex))
n_nomunic <- sum(!dx$cod_munic %in% names_tab$cod_munic)
cat(sprintf(
  "deaths %d-%d: %d; unknown sex %d; code not in the population file %d\n",
  min(yrs), max(yrs), n_tot, n_nosex, n_nomunic
))

dx_w <-
  dx |>
  filter(!is.na(sex), cod_munic %in% names_tab$cod_munic) |>
  count(year, cod_munic, sex, group) |>
  pivot_wider(names_from = group, values_from = n, values_fill = 0)

for (g in c("homicide", "undetermined", "legal", "suicide", "accident", "residual")) {
  if (!g %in% names(dx_w)) dx_w[[g]] <- 0L
}

out <-
  pop |>
  left_join(dx_w, by = c("year", "cod_munic", "sex")) |>
  mutate(across(c(homicide, undetermined, legal, suicide, accident, residual), ~ replace_na(.x, 0L))) |>
  mutate(dx_all = homicide + undetermined + legal + suicide + accident + residual) |>
  left_join(names_tab, by = "cod_munic") |>
  transmute(
    year, sex, cod_dpto, dpto, cod_munic, munic, pop,
    dx_all,
    dx_homicide = homicide,
    dx_undetermined = undetermined,
    dx_legal = legal,
    dx_suicide = suicide,
    dx_accident = accident,
    dx_residual = residual
  ) |>
  arrange(year, cod_munic, sex)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# checks ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

stopifnot(
  nrow(out) == length(yrs) * n_distinct(out$cod_munic) * 2,
  sum(out$dx_all) == sum(dx_w[, c("homicide", "undetermined", "legal", "suicide", "accident", "residual")]),
  !any(duplicated(out[, c("year", "cod_munic", "sex")]))
)
cat("deaths kept:", sum(out$dx_all), " dropped:", n_tot - sum(out$dx_all), "
")
cat("rows:", nrow(out), " municipalities:", n_distinct(out$cod_munic), "\n")
cat("rows with missing population:", sum(is.na(out$pop)), "\n")

nat <-
  out |>
  summarise(across(c(pop, starts_with("dx_")), ~ sum(.x, na.rm = TRUE)), .by = year)
print(nat, n = 40)

write_csv(out, "output/deaths_pop_munic_1985_2023.csv.gz")
cat("written, MB:", round(file.size("output/deaths_pop_munic_1985_2023.csv.gz") / 1e6, 2), "\n")
