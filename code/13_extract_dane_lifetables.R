# 13_extract_dane_lifetables.R ------------------------------------------------
# extracts the age-specific death rates (nMx) of DANE's abbreviated life
# tables by sex, national and departmental, 7 quinquennial periods
# 1985-1990 ... 2015-2020, from the PDF
#
#   DANE (2007) "Colombia. Tablas abreviadas de mortalidad nacionales y
#   departamentales 1985-2020", Proyecciones de poblacion 2005-2020.
#   https://www.dane.gov.co/files/investigaciones/poblacion/conciliacenso/8Tablasvida1985_2020.pdf
#
# step 0 (outside R, needs poppler's pdftotext; the PDF is not versioned):
#   pdftotext -layout 8Tablasvida1985_2020.pdf data_input/lifetables/tablas.txt
#   iconv -f latin1 -t utf-8 -o data_input/lifetables/tablas_utf8.txt data_input/lifetables/tablas.txt
#
# output: data_input/reference/dane_lifetables_nmx_1985_2020.csv
#   area, period, sex, age_label, age (lower bound), nmx
#
# these life tables are DANE's conciliated estimates (registry deaths
# corrected for under-registration with census information), so nMx here is
# an external estimate of true mortality, against which registered deaths
# can be compared (see 14_completeness_dane.R).

rm(list = ls())
source("code/00_setup.R")

txt <- readLines("data_input/lifetables/tablas_utf8.txt", encoding = "UTF-8")

area <- NA_character_
period <- NA_character_
sex <- NA_character_
rows <- list()

age_re <- "^\\s*(0|1 ?a ?4|[0-9]{1,2} ?a ?[0-9]{1,2}|80 ?y ?\\+)\\s+([0-9]+,[0-9]+)"

for (ln in txt) {
  if (grepl("Tabla de mortalidad", ln)) {
    area <- ln |> str_remove("\\.? *Tabla de mortalidad.*$") |> str_squish()
    period <- NA_character_
    sex <- NA_character_
    next
  }
  if (grepl("^\\s*[0-9]{4}-[0-9]{4}\\s*$", ln) && !is.na(area)) {
    period <- str_squish(ln)
    next
  }
  if (grepl("^\\s*Hombres\\s*$", ln)) { sex <- "m"; next }
  if (grepl("^\\s*Mujeres\\s*$", ln)) { sex <- "f"; next }
  m <- str_match(ln, age_re)
  if (!is.na(m[1, 1]) && !is.na(area) && !is.na(period) && !is.na(sex)) {
    rows[[length(rows) + 1]] <- tibble(
      area = area, period = period, sex = sex,
      age_label = str_remove_all(m[1, 2], " "),
      nmx = as.numeric(str_replace(m[1, 3], ",", "."))
    )
  }
}

nmx <-
  bind_rows(rows) |>
  mutate(
    age = case_when(
      age_label == "0" ~ 0,
      age_label == "1a4" ~ 1,
      age_label == "80y+" ~ 80,
      TRUE ~ as.numeric(str_extract(age_label, "^[0-9]+"))
    ),
    area = case_match(
      area,
      c("Bogotá D.C", "Bogotá D.C.", "Bogotá, D.C.", "Bogotá, D.C..") ~ "Bogotá D.C.",
      c("Boyaca", "Boyacá") ~ "Boyacá",
      .default = area
    )
  )

# one row per area x period x sex x age: duplicates mean the parser matched a
# stray line (page headers, notes)
dups <- nmx |> count(area, period, sex, age) |> filter(n > 1)
cat("duplicated area-period-sex-age cells:", nrow(dups), "\n")
nmx <- nmx |> distinct(area, period, sex, age, .keep_all = TRUE)

# completeness of the extraction: 18 age groups x 2 sexes x 7 periods per area
chk <- nmx |> count(area, name = "n_cells") |> mutate(expected = 18 * 2 * 7, ok = n_cells == expected)
print(chk, n = 40)
print(nmx |> count(period, sex))

# note: nMx can fall with age among men aged 30-49 where violence is high
# (Antioquia 1990s); that is real, not a parsing error
bad <-
  nmx |>
  filter(age >= 5) |>
  arrange(area, period, sex, age) |>
  mutate(dec = nmx < lag(nmx), .by = c(area, period, sex)) |>
  filter(dec, age >= 30)
cat("cells where nMx falls with age above 30:", nrow(bad), "\n")
print(head(bad, 10))

dir.create("data_input/reference", showWarnings = FALSE)
write_csv(nmx, "data_input/reference/dane_lifetables_nmx_1985_2020.csv")
