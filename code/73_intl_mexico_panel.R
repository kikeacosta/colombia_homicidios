# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 73. Mexico: deaths by state, year of occurrence, sex, age band and cause
#     group, 1990-2025, from the INEGI microdata of registered deaths
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Input for the validation of the sex-ratio model outside Colombia (70, 72).
# Read from `inegi_dir` (D:, 1 GB; backup in H:/data); only the aggregated
# panel is written into the project. One dbf per year of REGISTRATION
# (DEFUNyy.dbf), 1990-2025, inside the zips of INEGI: five of five years
# each for 1990-2019 and one per year from 2020. the dbf of 2020 replaces
# the earlier csv (defun20.csv), which INEGI corrected in 2022; the csv of
# 2012-2020 (mexico_deaths.zip, defun20.csv) stay in the folder but are not
# read.
# each file is extracted to the temporary folder of R, read and deleted.
#
# unit     state (entidad federativa) of residence, ent_resid 01-32. where
#          the residence is unknown (99) or abroad (33-35) the state of
#          occurrence is used: from 2017 the residence is unknown in 1-2 % of
#          the deaths and in about 10 % of the homicides (unidentified
#          bodies), and leaving them out would lower the homicides of the
#          last years. records without either state are left out and counted
# year     year of OCCURRENCE (anio_ocur: two digits to 1997, four from
#          1998). each file carries deaths of earlier years: all the files
#          are read and the deaths re-sorted by year of occurrence. where the
#          year of occurrence is unknown (99 to 1997, 9999 later; 2.7 % of the
#          records of 1990) the year of registration is used. deaths that
#          occurred before 1990 are left out. 2025 is incomplete (its late
#          registrations will come in later files) and 2020-2021 are
#          inflated by COVID-19, which raised the deaths of men
# sex      sexo: 1 male, 2 female, 9 unknown
# age      edad, four digits: the first is the unit (4 years, 1-3 under one
#          year), 4998 unknown. the same coding in all the years
# cause    causa_def: ICD-9 in 1990-1997 (four characters, external causes
#          without the letter E, e.g. 9654), ICD-10 from 1998. grouped by
#          intl_cause_icd9 / intl_cause_icd10 (70)
#
# input    D:/data/mexico_mortality/defunciones_generales_base_datos_<y>_<y+4>_dbf.zip (1990-2019)
#          D:/data/mexico_mortality/defunciones_base_datos_<year>_dbf.zip (2020-2025)
# output   output/tables/intl_mexico_deaths_state_year.csv
#            (country, unit, unit_label, year, sex, age_band, cause, deaths)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(data.table)

inegi_dir <- "D:/data/mexico_mortality/"
years <- 1990:2025
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

ent <- c("01" = "Aguascalientes", "02" = "Baja California", "03" = "Baja California Sur", "04" = "Campeche", "05" = "Coahuila",
         "06" = "Colima", "07" = "Chiapas", "08" = "Chihuahua", "09" = "Ciudad de México", "10" = "Durango", "11" = "Guanajuato",
         "12" = "Guerrero", "13" = "Hidalgo", "14" = "Jalisco", "15" = "México", "16" = "Michoacán", "17" = "Morelos", "18" = "Nayarit",
         "19" = "Nuevo León", "20" = "Oaxaca", "21" = "Puebla", "22" = "Querétaro", "23" = "Quintana Roo", "24" = "San Luis Potosí",
         "25" = "Sinaloa", "26" = "Sonora", "27" = "Tabasco", "28" = "Tamaulipas", "29" = "Tlaxcala", "30" = "Veracruz",
         "31" = "Yucatán", "32" = "Zacatecas")
vars <- c("ent_resid", "ent_ocurr", "sexo", "edad", "anio_ocur", "anio_regis", "causa_def")

# x: one row per death with the columns of `vars`, as character; ry: year of registration
aggregate_file <- function(x, ry, label) {
  for (v in names(x)) set(x, j = v, value = trimws(x[[v]])) # 2012-2019 csv carry a tab inside the codes
  n0 <- nrow(x)
  x[, cause := if (ry <= 1997) intl_cause_icd9(causa_def) else intl_cause_icd10(causa_def)]
  x[, unit := sprintf("%02d", suppressWarnings(as.integer(ent_resid)))]
  no_res <- !(x$unit %in% names(ent))
  n_nores <- sum(no_res); h_nores <- sum(no_res & x$cause == "homicide")
  x[no_res, unit := sprintf("%02d", suppressWarnings(as.integer(ent_ocurr)))]
  yo <- suppressWarnings(as.integer(x$anio_ocur))
  if (ry <= 1997) yo <- ifelse(yo == 99, NA, 1900L + yo) # two digits, 99 unknown
  yo[yo == 9999 | yo < 1900] <- NA
  n_noyear <- sum(is.na(yo))
  x[, year := fcoalesce(yo, as.integer(ry))]
  x[, sex := fcase(sexo == "1", "m", sexo == "2", "f", default = "u")]
  a_unit <- substr(x$edad, 1, 1); a_val <- suppressWarnings(as.integer(substr(x$edad, 2, 4)))
  x[, age_band := fcase(nchar(edad) != 4 | !(a_unit %in% as.character(1:4)), "unknown",
                        a_unit %in% as.character(1:3), "0-14",
                        is.na(a_val) | a_val > 130, "unknown",
                        a_val <= 14, "0-14", a_val <= 44, "15-44", default = "45+")]
  say(label, "| records", n0, "| residence unknown or abroad", n_nores, "(homicides", h_nores, ") | still without state", sum(!(x$unit %in% names(ent))),
      "| year of occurrence unknown", n_noyear, "| occurred before", min(years), ":", sum(x$year < min(years)),
      "| unknown sex", sum(x$sex == "u"), "| unknown age", sum(x$age_band == "unknown"), "| homicide", sum(x$cause == "homicide"))
  x[unit %in% names(ent) & year %in% years, .(deaths = .N), by = .(unit, year, sex, age_band, cause)]
}

td <- file.path(tempdir(), "inegi"); dir.create(td, showWarnings = FALSE)
parts <- list()

# one dbf per year of registration, found in whichever zip holds it
zips <- list.files(inegi_dir, pattern = "^defunciones_.*_dbf[.]zip$", full.names = TRUE)
where <- rbindlist(lapply(zips, function(z) data.table(zip = z, entry = unzip(z, list = TRUE)$Name)))
for (y in years) {
  e <- where[grepl(sprintf("(^|/)DEFUN%02d[.]dbf$", y %% 100), entry, ignore.case = TRUE)]
  stopifnot(nrow(e) == 1)
  f <- unzip(e$zip, files = e$entry, exdir = td, junkpaths = TRUE)
  x <- foreign::read.dbf(f, as.is = TRUE); unlink(f)
  names(x) <- tolower(names(x))
  stopifnot(all(vars %in% names(x)))
  x <- as.data.table(lapply(x[vars], as.character))
  parts[[length(parts) + 1]] <- aggregate_file(x, y, paste(basename(e$zip), "/", basename(e$entry)))
}
unlink(td, recursive = TRUE)
stopifnot(length(parts) == length(years))

panel <- rbindlist(parts)[, .(deaths = sum(deaths)), by = .(unit, year, sex, age_band, cause)]
panel[, `:=`(country = "mexico", unit_label = ent[unit])]
setcolorder(panel, c("country", "unit", "unit_label", "year", "sex", "age_band", "cause", "deaths"))
setorder(panel, unit, year, sex, age_band, cause)
fwrite(panel, "output/tables/intl_mexico_deaths_state_year.csv")

cat("\n== national, by year of occurrence: deaths and the three violent groups ==\n")
print(as.data.frame(dcast(panel[, .(deaths = sum(deaths)), by = .(year, grp = ifelse(cause %in% intl_violent, cause, "all_other"))],
                          year ~ grp, value.var = "deaths", fill = 0)[, total := all_other + homicide + legal + undetermined][
                            , violent_pct := round(100 * (homicide + legal + undetermined) / total, 2)][]), row.names = FALSE)
say("rows written:", nrow(panel))
