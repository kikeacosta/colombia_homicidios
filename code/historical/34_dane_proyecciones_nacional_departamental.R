# 34_dane_proyecciones_nacional_departamental.R
# Reads the DANE population projections and retroprojections (base: CNPV 2018) by area, sex and
# single age from the six xlsx in data_input/dane_pdfs/censos/ and writes them in long format:
#   national   1950-2070  -> data_input/reference/dane_proyecciones_nacional_1950-2070.csv
#   departmental 1985-2050 -> data_input/reference/dane_proyecciones_departamental_1985-2050.csv.gz
# Source: https://www.dane.gov.co/index.php/estadisticas-por-tema/demografia-y-poblacion/proyecciones-de-poblacion
# File versions (xlsx metadata): 1950-2017 and 2018-2070 national 2025-07-18; departmental 2005-2050 2025-08-08;
# departmental 1993-2004 2023-03-29 and 1985-1992 2023-03-17.
# Columns: unit_code (DANE DP code, 00 = Colombia), unit, year, area (cabecera, resto, total), sex (male, female),
#   age (0-100), age_open (TRUE for age 100, which includes older ages), population, file.
# Checks are written to data_input/reference/dane_proyecciones_verification.csv.
# Run from the project root: Rscript code/historical/34_dane_proyecciones_nacional_departamental.R

suppressPackageStartupMessages({ library(readxl); library(dplyr); library(tidyr); library(stringr); library(readr) })
dir_in <- "data_input/dane_pdfs/censos"
dir_out <- "data_input/reference"

area_std <- function(a) case_when(str_detect(a, "^Cabecera") ~ "cabecera",
                                  str_detect(a, "^Centros") ~ "resto", a == "Total" ~ "total", TRUE ~ NA_character_)

read_one <- function(f, sheet = 1) {
  raw <- suppressMessages(read_excel(file.path(dir_in, f), sheet = sheet, col_names = FALSE, col_types = "text"))
  # header: first row that has an area column name and a data row below it
  hdr_area <- which(apply(raw[1:40, ], 1, function(r) any(grepl("^(ÁREA GEOGRÁFICA|ÁREA)$", r))))[1]
  nm_age <- which(apply(raw[1:40, ], 1, function(r) any(grepl("^Hombres(_| )0", r))))[1]
  stopifnot(!is.na(hdr_area), !is.na(nm_age))
  first <- max(hdr_area, nm_age) + 1
  top <- unlist(raw[hdr_area, ]); ages <- unlist(raw[nm_age, ])
  nat_new <- !any(top == "DP", na.rm = TRUE)               # 2018+ national: TERRITORIO, AÑO, ÁREA...
  col_year <- which(top == "AÑO")[1]; col_area <- which(grepl("^ÁREA", top))[1]
  col_unit <- if (nat_new) 1 else 2; col_code <- if (nat_new) NA else 1
  is_age <- grepl("^(Hombres|Mujeres)(_| )[0-9]+", ages)
  d <- raw[first:nrow(raw), ]
  d <- d[!is.na(d[[col_year]]) & grepl("^[0-9]{4}$", d[[col_year]]), ]
  idx <- which(is_age)
  long <- lapply(idx, function(j) tibble(unit_code = if (is.na(col_code)) "00" else d[[col_code]], unit = d[[col_unit]],
    year = as.integer(d[[col_year]]), area = area_std(d[[col_area]]),
    sex = if (grepl("^Hombres", ages[j])) "male" else "female",
    age = as.integer(str_extract(ages[j], "[0-9]+")), population = as.numeric(d[[j]])))
  # also keep the printed totals for the check
  tot <- tibble(unit_code = if (is.na(col_code)) "00" else d[[col_code]], year = as.integer(d[[col_year]]),
                area = area_std(d[[col_area]]), unit = d[[col_unit]],
                printed_male = as.numeric(d[[which(grepl("^Total Hombres$|^Hombres$|^HOMBRES$", ages) | grepl("^HOMBRES$", top))[1]]]),
                printed_female = as.numeric(d[[which(grepl("^Total Mujeres$|^Mujeres$|^MUJERES$", ages) | grepl("^MUJERES$", top))[1]]]))
  out <- bind_rows(long) |> mutate(unit = if_else(unit == "Total Nacional", "Nacional", unit), file = f)
  list(long = out, printed = tot |> mutate(unit = if_else(unit == "Total Nacional", "Nacional", unit), file = f))
}

files <- tribble(~f, ~sheet, ~nivel,
  "PPED-AreaSexoEdadNac-1950-2017.xlsx", 1, "nacional",
  "PPED-AreaSexoEdadNac-2018-2070.xlsx", 3, "nacional",
  "DCD-area-sexo-edad-proypoblacion-dep-1985-1992.xlsx", 1, "departamental",
  "DCD-area-sexo-edad-proypoblacion-dep-1993-2004.xlsx", 1, "departamental",
  "DCD-area-sexo-edad-proypoblacion-dep-2005-2017_VP.xlsx", 1, "departamental",
  "PPED-AreaSexoEdadDep-2018-2050_VP.xlsx", 3, "departamental")
res <- lapply(seq_len(nrow(files)), function(i) { cat("reading", files$f[i], "\n"); read_one(files$f[i], files$sheet[i]) })
names(res) <- files$f

add_open <- function(x) x |> group_by(file) |> mutate(age_open = age == max(age)) |> ungroup()
nat <- bind_rows(lapply(res[files$nivel == "nacional"], `[[`, "long")) |> add_open() |> arrange(year, area, sex, age)
dep <- bind_rows(lapply(res[files$nivel == "departamental"], `[[`, "long")) |> add_open() |> arrange(unit_code, year, area, sex, age)
write_csv(nat, file.path(dir_out, "dane_proyecciones_nacional_1950-2070.csv"))
write_csv(dep, gzfile(file.path(dir_out, "dane_proyecciones_departamental_1985-2050.csv.gz")))

# ---- checks ----
chk <- list(); add <- function(name, n, bad, note = "") chk[[length(chk) + 1]] <<- tibble(check = name, n = n, n_failing = bad, note = note)
# 1. all cells present, populations non-negative
add("celdas vacias o negativas (nacional)", nrow(nat), sum(is.na(nat$population) | nat$population < 0))
add("celdas vacias o negativas (departamental)", nrow(dep), sum(is.na(dep$population) | dep$population < 0))
# 2. printed male/female totals = sum over ages
printed <- bind_rows(lapply(res, `[[`, "printed"))
sums <- bind_rows(nat, dep) |> group_by(file, unit_code, year, area, sex) |> summarise(s = sum(population), .groups = "drop") |>
  pivot_wider(names_from = sex, values_from = s)
m <- inner_join(sums, printed, by = c("file", "unit_code", "year", "area"))
add("suma por edades = total impreso de hombres y mujeres", nrow(m), sum(abs(m$male - m$printed_male) > 1 | abs(m$female - m$printed_female) > 1))
# 3. cabecera + resto = total
w <- bind_rows(nat, dep) |> group_by(file, unit_code, year, area, sex, age) |> summarise(p = sum(population), .groups = "drop") |>
  pivot_wider(names_from = area, values_from = p)
add("cabecera + resto = total (por unidad, ano, sexo y edad)", nrow(w), sum(abs(w$cabecera + w$resto - w$total) > 1, na.rm = TRUE))
# 4. departments add up to the national total (by year, sex and age), area total
dd <- dep |> filter(area == "total") |> group_by(year, sex, age) |> summarise(dep = sum(population), .groups = "drop")
nn <- nat |> filter(area == "total") |> select(year, sex, age, nat = population)
j <- inner_join(dd, nn, by = c("year", "sex", "age")) |> mutate(diff = dep - nat)
add("suma de departamentos = nacional (ano, sexo, edad)", nrow(j), sum(abs(j$diff) > 1), paste("diferencia maxima", max(abs(j$diff))))
# 5. coverage
add("anos nacionales 1950-2070 completos", 121, 121 - n_distinct(nat$year))
add("anos departamentales 1985-2050 completos", 66, 66 - n_distinct(dep$year))
add("33 unidades departamentales por ano", 66, sum(dep |> filter(area == "total", sex == "male", age == 0) |> count(year) |> pull(n) != 33))
# 6. continuity at the file boundaries (national total, ratio of consecutive years)
tn <- nat |> filter(area == "total") |> group_by(year) |> summarise(p = sum(population)) |> mutate(g = p / lag(p) - 1)
add("crecimiento anual del total nacional entre -1% y 3%", nrow(tn) - 1, sum(abs(tn$g[-1] - 0.01) > 0.02), paste0("empalmes 2017-2018: ", round(100 * tn$g[tn$year == 2018], 2), " %"))
v <- bind_rows(chk); write_csv(v, file.path(dir_out, "dane_proyecciones_verification.csv")); print(as.data.frame(v), right = FALSE)
cat(nrow(nat), "filas nacionales;", nrow(dep), "filas departamentales\n")
