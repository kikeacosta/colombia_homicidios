# 11b_shared_dataset_age.R ---------------------------------------------------
# companion of 11_shared_dataset.R with age detail: deaths by cause group and
# population by year, municipality, sex and age group, 1985-2023.
#
#   age groups: 0, 1-4, 5-9, ..., 80-84, 85+  (19 groups) and "unknown"
#   (deaths with unknown age; no population)
#   population 1985-2017: DANE retroprojections (03); 2018-2023: single ages
#   0-100+ of the PPED-AreaSexoEdadMun-2018-2042 workbook, grouped here
#
# written as parquet (zstd): the csv.gz equivalent is ~10 times larger.
# read with arrow::read_parquet(), pandas.read_parquet() or duckdb.
#
# output: output/deaths_pop_munic_age_1985_2023.parquet

rm(list = ls())
gc()
source("code/00_setup.R")
library(arrow)

yrs <- 1985:2023
age_lv <- c(0, 1, seq(5, 85, 5))
age_lab <- c("0", "1-4", paste(seq(5, 80, 5), seq(9, 84, 5), sep = "-"), "85+")
names(age_lab) <- age_lv

# names and codes: same as the main file
main <- read_csv("output/deaths_pop_munic_1985_2023.csv.gz", show_col_types = FALSE)
names_tab <-
  main |>
  distinct(cod_munic, cod_dpto, dpto, munic) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)), cod_munic = sprintf("%05d", as.integer(cod_munic)))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# population ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

pop_a <-
  read_rds("data_inter/pop_munic_1985-2017.rds") |>
  filter(sex %in% c("m", "f"), !is.na(age)) |>
  summarise(pop = sum(pop), .by = c(year, cod_munic, sex, age))

f_pped <- "data_input/DANEpop/PPED-AreaSexoEdadMun-2018-2042_VP.xlsx"
sheet_pped <- grep("Mun", excel_sheets(f_pped), value = TRUE)[1]
# columns: 1 DP, 2 DPNOM, 3 MPIO (code), 4 DPMP (name), 5 year, 6 area,
# 7-9 totals, 10-110 men aged 0..100+, 111-211 women aged 0..100+, 212-312 both
raw <-
  read_xlsx(
    f_pped, sheet = sheet_pped, skip = 7, col_names = FALSE,
    col_types = c("text", "text", "text", "text", "numeric", "text", rep("numeric", 306))
  )
raw <- raw |> filter(...6 == "Total", !is.na(...3), ...5 %in% 2018:max(yrs))

ages_single <- 0:100
mk <- function(cols, sx) {
  m <- as.matrix(raw[, cols])
  tibble(year = rep(raw$...5, each = length(ages_single)),
         cod_munic = rep(raw$...3, each = length(ages_single)),
         sex = sx,
         age = rep(ages_single, times = nrow(raw)),
         pop = as.vector(t(m)))
}
pop_b <-
  bind_rows(mk(10:110, "m"), mk(111:211, "f")) |>
  mutate(age = case_when(age == 0 ~ 0, age < 5 ~ 1, age >= 85 ~ 85, TRUE ~ age - age %% 5)) |>
  summarise(pop = sum(pop), .by = c(year, cod_munic, sex, age))
rm(raw)

pop <- bind_rows(pop_a, pop_b) |> filter(year %in% yrs)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# deaths ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dt <- read_rds("data_inter/micro_1979_2023.rds") |> as_tibble()

dx <-
  dt |>
  filter(ano %in% yrs, !is.na(sexo)) |>
  transmute(
    year = ano, sex = sexo,
    cod_munic = make_cod_munic(cod_dpto, cod_munic),
    age = recode_age_group(gr_edad, ano),
    group = cause_groups_shared(cod_col)
  ) |>
  filter(cod_munic %in% names_tab$cod_munic) |>
  mutate(age = ifelse(is.na(age), NA_real_, pmin(age, 85))) |>
  count(year, cod_munic, sex, age, group) |>
  pivot_wider(names_from = group, values_from = n, values_fill = 0)
rm(dt)

for (g in c("homicide", "undetermined", "legal", "suicide", "accident", "residual")) {
  if (!g %in% names(dx)) dx[[g]] <- 0L
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# assemble ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

grid <-
  expand_grid(
    year = yrs, cod_munic = names_tab$cod_munic, sex = c("m", "f"),
    age = c(age_lv, NA_real_)
  )

out <-
  grid |>
  left_join(pop |> mutate(age = as.numeric(age)), by = c("year", "cod_munic", "sex", "age")) |>
  left_join(dx, by = c("year", "cod_munic", "sex", "age")) |>
  mutate(across(c(homicide, undetermined, legal, suicide, accident, residual), ~ replace_na(.x, 0L))) |>
  mutate(dx_all = homicide + undetermined + legal + suicide + accident + residual) |>
  left_join(names_tab, by = "cod_munic") |>
  transmute(
    year = as.integer(year), sex, cod_dpto, dpto, cod_munic, munic,
    age = as.integer(age),
    age_group = ifelse(is.na(age), "unknown", unname(age_lab[as.character(age)])),
    pop, dx_all,
    dx_homicide = homicide, dx_undetermined = undetermined, dx_legal = legal,
    dx_suicide = suicide, dx_accident = accident, dx_residual = residual
  ) |>
  arrange(year, cod_munic, sex, age)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# checks against the main file ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

stopifnot(
  sum(out$dx_all) == sum(main$dx_all),
  all(out |> summarise(s = sum(dx_all), .by = c(year, sex)) |> arrange(year, sex) |> pull(s) ==
        main |> summarise(s = sum(dx_all), .by = c(year, sex)) |> arrange(year, sex) |> pull(s))
)
pc <-
  full_join(
    out |> summarise(p = sum(pop, na.rm = TRUE), .by = c(year, sex)),
    main |> summarise(q = sum(pop, na.rm = TRUE), .by = c(year, sex)),
    by = c("year", "sex")
  ) |>
  mutate(rel = abs(p / q - 1))
cat("max relative difference of population totals vs main file:", max(pc$rel), "\n")
stopifnot(max(pc$rel) < 1e-6)

cat("rows:", nrow(out), "\n")
write_parquet(out, "output/deaths_pop_munic_age_1985_2023.parquet", compression = "zstd")
cat("parquet MB:", round(file.size("output/deaths_pop_munic_age_1985_2023.parquet") / 1e6, 1), "\n")
print(out |> filter(cod_munic == "05001", year == 2010, sex == "m") |> select(age_group, pop, dx_all, dx_homicide) |> as.data.frame())
