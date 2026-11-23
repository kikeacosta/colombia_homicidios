# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 77. Ecuador: deaths by province, year, sex, age band and cause group,
#     1990-2024, from the INEC microdata of general deaths
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Input for the validation of the sex-ratio model outside Colombia (70, 72).
# Read in place from `inec_dir` (one SPSS file per year, downloaded on
# 2026-11-22 from ecuadorencifras.gob.ec; addresses in download_log.csv);
# only the aggregated panel is written into the project. Each zip is
# extracted whole to the temporary folder of R (with 7-Zip where the entry
# names are in an old encoding that R cannot read), read and deleted.
#
# layouts  1990-2008  provr, sexo, edad + codi, anof, causa
#          2009-2015  provr, sexo, edad + cod_eda, aniof, causa (and causa4)
#          2016-2024  prov_res, sexo, edad + cod_edad, anio_fall, causa4
#          the script takes the first name of each list that the file has
# unit     province of residence. 21 units, stable over 1990-2024: Orellana
#          (22, created in 1998 from Napo) stays within Napo (15), Santo
#          Domingo de los Tsachilas (23, 2007) within Pichincha (17) and
#          Santa Elena (24, 2007) within Guayas (09). 88 (abroad) and 90
#          (zonas no delimitadas) are left out and counted
# year     the year of the file. the files of 1990-2015 hold only deaths
#          that occurred in the year of the file; from 2016 they also carry
#          late registrations of earlier years, which are left out so that
#          the series is the same throughout (counted in the log)
# sex      1 male, 2 female
# age      edad with its unit: 1 hours, 2 days, 3 months, 4 years, 9 unknown;
#          999 unknown. bands 0-14, 15-44, 45+ and unknown
# cause    ICD-9 in 1990-1996 (three digits, external causes without the
#          letter E, e.g. 965), ICD-10 from 1997 (three characters to 2009,
#          four from 2010). grouped by intl_cause_icd9 / intl_cause_icd10 (70)
#
# input    D:/data/ecuador_mortality/edg_<year>_spss.zip (2018: inside
#          nac_def_2018_spss.zip)
# output   output/tables/intl_ecuador_deaths_province_year.csv
#            (country, unit, unit_label, year, sex, age_band, cause, deaths)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(data.table)

inec_dir <- "D:/data/ecuador_mortality/"
years <- 1990:2024
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

prov <- c("01" = "Azuay", "02" = "Bolívar", "03" = "Cañar", "04" = "Carchi", "05" = "Cotopaxi", "06" = "Chimborazo",
          "07" = "El Oro", "08" = "Esmeraldas", "09" = "Guayas + Santa Elena", "10" = "Imbabura", "11" = "Loja",
          "12" = "Los Ríos", "13" = "Manabí", "14" = "Morona Santiago", "15" = "Napo + Orellana", "16" = "Pastaza",
          "17" = "Pichincha + Santo Domingo", "18" = "Tungurahua", "19" = "Zamora Chinchipe", "20" = "Galápagos",
          "21" = "Sucumbíos")
merge_prov <- c("22" = "15", "23" = "17", "24" = "09")
first_of <- function(n, cands) { v <- intersect(cands, n); if (length(v)) v[1] else NA_character_ }

td <- file.path(tempdir(), "inec"); dir.create(td, showWarnings = FALSE)
# extract a whole zip; R's unzip cannot read the entry names in an old
# encoding of 2011-2015, so 7-Zip is used then
unzip_all <- function(z, out) {
  ok <- tryCatch({ utils::unzip(z, exdir = out); TRUE }, error = function(e) FALSE)
  if (!ok) {
    stopifnot(nzchar(Sys.which("7z")))
    st <- system2("7z", c("x", shQuote(z), paste0("-o", shQuote(out)), "-y"), stdout = FALSE, stderr = FALSE)
    stopifnot(st == 0)
  }
}
read_year <- function(y) {
  out <- file.path(td, y); dir.create(out, showWarnings = FALSE)
  if (y == 2018) {
    unzip_all(paste0(inec_dir, "nac_def_2018_spss.zip"), out)
    z <- list.files(out, pattern = "EDG_2018[.]zip$", recursive = TRUE, full.names = TRUE)
  } else z <- sprintf("%sedg_%d_spss.zip", inec_dir, y)
  unzip_all(z, out)
  inner <- list.files(out, pattern = "[.]zip$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  for (i in setdiff(inner, z)) unzip_all(i, out) # 2017: a zip inside the zip
  sav <- list.files(out, pattern = "[.]sav$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (y == 2018) sav <- sav[grepl("EDG", basename(sav))]
  stopifnot(length(sav) == 1)
  x <- haven::read_sav(sav)
  unlink(out, recursive = TRUE)
  names(x) <- tolower(names(x)); n <- names(x)
  v <- c(prov = first_of(n, c("prov_res", "provr")), sex = first_of(n, "sexo"), age = first_of(n, "edad"),
         age_unit = first_of(n, c("cod_edad", "cod_eda", "codi")), year = first_of(n, c("anio_fall", "aniof", "anof")),
         cause = if (y >= 2010) first_of(n, c("causa4", "causa")) else first_of(n, "causa"))
  if (anyNA(v)) stop(y, ": missing ", paste(names(v)[is.na(v)], collapse = ", "), " | variables: ", paste(n, collapse = ","))
  d <- data.table(p = as.integer(haven::zap_labels(x[[v["prov"]]])), s = as.integer(haven::zap_labels(x[[v["sex"]]])),
                  a = suppressWarnings(as.integer(haven::zap_labels(x[[v["age"]]]))),
                  u = as.integer(haven::zap_labels(x[[v["age_unit"]]])),
                  yo = as.integer(haven::zap_labels(x[[v["year"]]])), c = toupper(trimws(as.character(haven::zap_labels(x[[v["cause"]]])))))
  n0 <- nrow(d)
  d[yo < 100, yo := yo + 1900L] # two digits in the early files
  late <- sum(d$yo != y, na.rm = TRUE)
  d <- d[is.na(yo) | yo == y]
  d[, unit := sprintf("%02d", p)]
  d[unit %in% names(merge_prov), unit := merge_prov[unit]]
  out_unit <- sum(!(d$unit %in% names(prov)))
  d[, sex := fcase(s == 1L, "m", s == 2L, "f", default = "u")]
  d[, age_band := fcase(u %in% 1:3, "0-14", u != 4L | is.na(a) | a > 130, "unknown",
                        a <= 14, "0-14", a <= 44, "15-44", default = "45+")]
  d[, cause := if (y <= 1996) intl_cause_icd9(c) else intl_cause_icd10(c)]
  say(y, "| records", n0, "| other years (late registrations)", late, "| province abroad or not delimited", out_unit,
      "| unknown sex", sum(d$sex == "u"), "| unknown age", sum(d$age_band == "unknown"),
      "| homicide", sum(d$cause == "homicide"), "| legal", sum(d$cause == "legal"), "| undetermined", sum(d$cause == "undetermined"),
      "| vars:", paste(v, collapse = ","))
  d[unit %in% names(prov), .(deaths = .N), by = .(unit, sex, age_band, cause)][, year := y]
}

panel <- rbindlist(lapply(years, read_year))
unlink(td, recursive = TRUE)
panel[, `:=`(country = "ecuador", unit_label = prov[unit])]
setcolorder(panel, c("country", "unit", "unit_label", "year", "sex", "age_band", "cause", "deaths"))
setorder(panel, unit, year, sex, age_band, cause)
fwrite(panel, "output/tables/intl_ecuador_deaths_province_year.csv")

cat("\n== national, by year: deaths and the three violent groups ==\n")
print(as.data.frame(dcast(panel[, .(deaths = sum(deaths)), by = .(year, grp = ifelse(cause %in% intl_violent, cause, "all_other"))],
                          year ~ grp, value.var = "deaths", fill = 0)[, total := all_other + homicide + legal + undetermined][
                            , violent_pct := round(100 * (homicide + legal + undetermined) / total, 2)][]), row.names = FALSE)
say("rows written:", nrow(panel), "| units", uniqueN(panel$unit))
