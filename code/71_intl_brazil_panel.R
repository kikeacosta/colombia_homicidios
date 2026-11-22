# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 71. Brazil: deaths by state, year, sex, age band and cause group, 1979-2020,
#     from the SIM microdata
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Input for the validation of the sex-ratio model outside Colombia (70, 72).
# The microdata are read IN PLACE from `sim_dir` and only the aggregated
# panel is written; nothing is copied into the project:
#   1979-1989  national files DORBR<yy>.dbc of the DATASUS site (SIM, ICD-9,
#              DORES), downloaded to `sim_dir`/sim_cid9_1979_1989 and read
#              with microdatasus::read_dbc. same variables as 1990-1995
#   1990-2020  Mortalidade_Geral_<year>.csv (31 csv, 7 GB)
#
# unit     state (UF) of residence: first two digits of the municipality of
#          residence (MUNIRES to 1995, CODMUNRES from 1996). 26 units, stable
#          over 1979-2020: Tocantins (17), created in 1988 from northern
#          Goiás, is kept within Goiás (52), and Fernando de Noronha (20), a
#          territory until 1988, within Pernambuco (26)
# year     the year of the file (the files are by year of death)
# sex      SEXO: 1 male, 2 female, anything else unknown
# age      IDADE, three digits: the first is the unit (4 years, 5 years over
#          100, 0-3 under one year). bands 0-14, 15-44, 45+ and unknown
# cause    CAUSABAS, underlying cause. ICD-9 in 1979-1995, stored without the
#          letter E (external causes are 800-999); ICD-10 from 1996
#            homicide        E960-E969            X85-Y09, Y87.1
#            legal           E970-E978            Y35, Y89.0
#            undetermined    E980-E989            Y10-Y34, Y87.2
#            other_external  the rest of E800-E999 / V01-Y98
#            other           everything else
#          "violent" in the rest of the project is the sum of the first
#          three, the convention of the Colombian series
# fetal deaths (TIPOBITO = 1) are dropped; the files inspected have none
# broken lines: the files of 1991, 1997 and 1999 have 1, 2 and 5 lines with
# the wrong number of fields; they are dropped and counted in the log
#
# input    D:/data/brazil_mortality/sim_cid9_1979_1989/DORBR<yy>.dbc
#          D:/data/brazil_mortality/Mortalidade_Geral_<year>.csv
# output   output/tables/intl_brazil_deaths_state_year.csv
#            (country, unit, unit_label, year, sex, age_band, cause, deaths)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(data.table)

sim_dir <- "D:/data/brazil_mortality/"
years <- 1979:2020
dbc_dir <- paste0(sim_dir, "sim_cid9_1979_1989/")
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

uf <- c("11" = "Rondônia", "12" = "Acre", "13" = "Amazonas", "14" = "Roraima", "15" = "Pará", "16" = "Amapá",
        "21" = "Maranhão", "22" = "Piauí", "23" = "Ceará", "24" = "Rio Grande do Norte", "25" = "Paraíba", "26" = "Pernambuco",
        "27" = "Alagoas", "28" = "Sergipe", "29" = "Bahia", "31" = "Minas Gerais", "32" = "Espírito Santo", "33" = "Rio de Janeiro",
        "35" = "São Paulo", "41" = "Paraná", "42" = "Santa Catarina", "43" = "Rio Grande do Sul", "50" = "Mato Grosso do Sul",
        "51" = "Mato Grosso", "52" = "Goiás + Tocantins", "53" = "Distrito Federal")
merge_uf <- c("17" = "52", "20" = "26")

read_year <- function(y) {
  if (y <= 1989) {
    f <- sprintf("%sDORBR%02d.dbc", dbc_dir, y %% 100)
    x <- as.data.table(microdatasus::read_dbc(f))
    stopifnot(all(c("MUNIRES", "SEXO", "IDADE", "CAUSABAS", "TIPOBITO") %in% names(x)))
    x <- x[, .(res = as.character(MUNIRES), SEXO = as.character(SEXO), IDADE = as.character(IDADE),
               CAUSABAS = as.character(CAUSABAS), TIPOBITO = as.character(TIPOBITO))]
    return(aggregate_year(x, y, dropped = 0))
  }
  f <- paste0(sim_dir, "Mortalidade_Geral_", y, ".csv")
  h <- names(fread(f, nrows = 0, sep = ";"))
  res <- intersect(c("MUNIRES", "CODMUNRES"), h)
  stopifnot(length(res) == 1, all(c("SEXO", "IDADE", "CAUSABAS") %in% h))
  sel <- c(res, "SEXO", "IDADE", "CAUSABAS", intersect("TIPOBITO", h))
  dropped <- 0
  x <- tryCatch(fread(f, sep = ";", select = sel, colClasses = "character", showProgress = FALSE),
                warning = function(w) NULL)
  if (is.null(x)) {
    # a few lines are broken (a record cut in two, or two glued together) and
    # fread stops at the first one. read line by line, keep the lines with
    # the number of separators of the header and count the rest
    l <- fread(f, sep = "\n", header = FALSE, quote = "", showProgress = FALSE)[[1]]
    ok <- stringi::stri_count_fixed(l, ";") == stringi::stri_count_fixed(l[1], ";")
    dropped <- sum(!ok)
    x <- fread(text = l[ok], sep = ";", select = sel, colClasses = "character", showProgress = FALSE)
    rm(l); gc()
  }
  setnames(x, res, "res")
  aggregate_year(x, y, dropped)
}

aggregate_year <- function(x, y, dropped) {
  n0 <- nrow(x)
  if ("TIPOBITO" %in% names(x)) x <- x[is.na(TIPOBITO) | TIPOBITO != "1"]
  x[, unit := substr(res, 1, 2)]
  x[unit %in% names(merge_uf), unit := merge_uf[unit]]
  x[, sex := fcase(SEXO == "1", "m", SEXO == "2", "f", default = "u")]
  a_unit <- substr(IDADE <- x$IDADE, 1, 1); a_val <- suppressWarnings(as.integer(substr(IDADE, 2, 3)))
  x[, age_band := fcase(nchar(IDADE) != 3 | !(a_unit %in% as.character(0:5)), "unknown",
                        a_unit %in% as.character(0:3), "0-14",
                        a_unit == "5", "45+",
                        is.na(a_val), "unknown",
                        a_val <= 14, "0-14", a_val <= 44, "15-44", default = "45+")]
  x[, cause := if (y <= 1995) intl_cause_icd9(CAUSABAS) else intl_cause_icd10(CAUSABAS)]
  out <- x[, .(deaths = .N), by = .(unit, sex, age_band, cause)]
  out[, year := y]
  say(y, "| records", n0, "| broken lines dropped", dropped, "| kept", nrow(x), "| unit outside the 26:", sum(!(x$unit %in% names(uf))),
      "| unknown sex", sum(x$sex == "u"), "| unknown age", sum(x$age_band == "unknown"),
      "| homicide", sum(x$cause == "homicide"), "| legal", sum(x$cause == "legal"), "| undetermined", sum(x$cause == "undetermined"))
  out
}

panel <- rbindlist(lapply(years, read_year))
panel <- panel[unit %in% names(uf)]
panel[, `:=`(country = "brazil", unit_label = uf[unit])]
setcolorder(panel, c("country", "unit", "unit_label", "year", "sex", "age_band", "cause", "deaths"))
setorder(panel, unit, year, sex, age_band, cause)
fwrite(panel, "output/tables/intl_brazil_deaths_state_year.csv")

cat("\n== national, by year: deaths and the three violent groups ==\n")
print(as.data.frame(dcast(panel[, .(deaths = sum(deaths)), by = .(year, grp = ifelse(cause %in% c("homicide", "legal", "undetermined"), cause, "all_other"))],
                          year ~ grp, value.var = "deaths")[, total := all_other + homicide + legal + undetermined][
                            , violent_pct := round(100 * (homicide + legal + undetermined) / total, 2)][]), row.names = FALSE)
say("rows written:", nrow(panel))
