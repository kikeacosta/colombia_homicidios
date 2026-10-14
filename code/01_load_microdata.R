# 01_load_microdata.R --------------------------------------------------------
# reads the 45 DANE EEVV non-fetal death files (one per year, 1979-2023),
# harmonises the variable names across the two layouts, attaches sex, 5-year
# age group, ICD revision and a fine cause-of-death group, and writes one
# compressed .rds. ~8.5M rows; needs a few GB of RAM and some minutes.
#
# dictionaries: documents/metadata/*.pdf and VariablesMicrodatos.xlsx
# layouts: lower-case names 1979-2007 (.txt), upper-case names 2008+ (.txt/.csv)

rm(list = ls())
gc()
source("code/00_setup.R")

my_files <- list.files(
  "data_input/micro",
  pattern = "\\.txt$|\\.csv$",
  full.names = TRUE
)
stopifnot(length(my_files) == 45)

mort_all <- lapply(my_files, fread)
names(mort_all) <- paste0("y", str_extract(basename(my_files), "\\d{4}"))

vars <- c(
  "ano", # year of registration
  "mes",
  "sexo",
  "gr_edad", # age group, period-specific coding (see recode_age_group)
  "a_defun", # year of death
  "ucod", # underlying cause, ICD code
  "cod_col", # underlying cause, DANE list 105 (cau_homol)
  "cod_dpto", # department of OCCURRENCE
  "cod_munic" # municipality of OCCURRENCE (3 digits within department)
)

clean_mins <- function(x) {
  x |>
    rename(gr_edad = gru_ed1, cod_col = cau_homol, ucod = c_bas1) |>
    select(all_of(vars))
}

clean_mays <- function(x) {
  x |>
    select(
      gr_edad = GRU_ED1,
      sexo = SEXO,
      a_defun = A_DEFUN,
      ano = ANO,
      mes = MES,
      cod_dpto = COD_DPTO,
      cod_munic = COD_MUNIC,
      cod_col = CAU_HOMOL,
      ucod = C_BAS1
    )
}

# files with upper-case names use the second layout
is_upper <- map_lgl(mort_all, ~ names(.x)[1] == toupper(names(.x)[1]))

mort_all <-
  mort_all |>
  map_at(names(mort_all)[!is_upper], clean_mins) |>
  map_at(names(mort_all)[is_upper], clean_mays)

mort_final <-
  imap(mort_all, function(df, nm) {
    year <- as.numeric(str_extract(nm, "\\d{4}"))
    df |>
      mutate(
        sexo = case_when(sexo == 1 ~ "m", sexo == 2 ~ "f", TRUE ~ NA_character_),
        edad = recode_age_group(gr_edad, year),
        icd = ifelse(year <= 1997, 9L, 10L),
        externa = as.integer(cod_col %in% codes_external),
        causa = recode_cause_fine(cod_col),
        ucod = as.character(ucod)
      )
  }) |>
  bind_rows()

# quick checks
print(table(mort_final$sexo, useNA = "ifany"))
print(table(mort_final$causa == "x")) # unmapped list-105 codes
print(range(mort_final$ano))

write_rds(mort_final, "data_inter/micro_1979_2023.rds", compress = "xz")
