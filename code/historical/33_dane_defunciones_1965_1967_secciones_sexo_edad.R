# 33_dane_defunciones_1965_1967_secciones_sexo_edad.R ----------------------------
# Deaths by sección del país, sex and age group, 1965-1967, from the DANE Anuario
# General de Estadística: 1965 Cuadro 46 (pdf pp. 111-113,
# LD_70104_1965_EJ_3.pdf) and 1966-1967 Cuadros 66 and 67 (pdf pp. 83-88,
# LD_70104_1966_1967_EJ_3.pdf), in the dane_biblioteca collection
# (D:/data/colombia/dane_pdfs/anuarios/nacionales, not versioned). They extend
# 26_dane_defunciones_1968_1969.R three years back, in the same layout.
#
# Method
#   The pages were transcribed from 200-300 dpi renders into
#   data_input/historical/dane_defunciones_1965_1967_support/transcripcion_<year>.csv
#   (anio, cuadro, pagina_pdf, unidad, edad, total, hombres, mujeres, nota).
#   This script checks the three identities of the table and stops if any
#   fails outside the list of inconsistencies of the printed source
#   (support/source_inconsistencies.csv, may be absent). Where a printed
#   figure breaks two identities that both point to the same value, the
#   transcription carries that value and the printed one is listed in
#   support/misprints_in_source.csv (1967: nine cells, checked on 250-dpi
#   crops). The identities are:
#     total = men + women (every row); age rows = TOTAL row (every unit and
#     sex); units = TOTAL GENERAL (every age and sex).
#   It also compares each unit's TOTAL with the department deaths series
#   (col_gap_analysis_..._department_deaths_clean_v06).
#
# Output
#   data_input/historical/dane_defunciones_1965_1967_secciones_sexo_edad.csv
#     year, unit, cod_dpto, age, male, female, total  (as the 1968-1969 file)
#   data_input/historical/dane_defunciones_1965_1967_support/verification_identities.csv
#
# Run from the project root.

sup <- "data_input/historical/dane_defunciones_1965_1967_support"
out <- "data_input/historical/dane_defunciones_1965_1967_secciones_sexo_edad.csv"

files <- list.files(sup, pattern = "^transcripcion_[0-9]{4}[.]csv$", full.names = TRUE)
stopifnot(length(files) > 0)
tr <- do.call(rbind, lapply(files, function(f) {
  x <- read.csv(f, encoding = "UTF-8", stringsAsFactors = FALSE, colClasses = "character")
  if (!"nota" %in% names(x)) x$nota <- ""
  x[, c("anio", "cuadro", "pagina_pdf", "unidad", "edad", "total", "hombres", "mujeres", "nota")]
}))
for (v in c("total", "hombres", "mujeres")) tr[[v]] <- suppressWarnings(as.integer(gsub("[^0-9]", "", tr[[v]])))

# units: the names and codes of the 1968-1969 file
# matching key: letters only ("BOGOTA, D. E." = "Bogotá D.E." = "BOGOTADE")
strip <- function(x) gsub("[^A-Z]", "", toupper(iconv(x, "UTF-8", "ASCII//TRANSLIT")))
ref <- unique(read.csv("data_input/historical/dane_defunciones_1968_1969_secciones_sexo_edad.csv",
                       encoding = "UTF-8", stringsAsFactors = FALSE, colClasses = "character")[, c("unit", "cod_dpto")])
ref$k <- strip(ref$unit)
ref <- rbind(ref, data.frame(unit = "Total nacional", cod_dpto = "00", k = "TOTALGENERAL"),
             data.frame(unit = "Bogotá D.E.", cod_dpto = ref$cod_dpto[ref$k == "BOGOTADE"][1], k = "BOGOTA"))
ref <- rbind(ref, data.frame(unit = "Valle del Cauca", cod_dpto = ref$cod_dpto[ref$k == "VALLEDELCAUCA"][1], k = "VALLE"),
             data.frame(unit = "La Guajira", cod_dpto = ref$cod_dpto[ref$k == "LAGUAJIRA"][1], k = "GUAJIRA"),
             data.frame(unit = "Norte de Santander", cod_dpto = ref$cod_dpto[ref$k == "NORTEDESANTANDER"][1], k = "NDESANTANDER"))
k <- strip(tr$unidad)
j <- match(k, ref$k)
if (anyNA(j)) {
  # units printed in the 1960s that 1968-1969 no longer has (e.g. grouped territories) keep their printed name
  message("units without a 1968-1969 match: ", paste(unique(tr$unidad[is.na(j)]), collapse = ", "))
}
tr$unit <- ifelse(is.na(j), tools::toTitleCase(tolower(tr$unidad)), ref$unit[j])
tr$cod_dpto <- ifelse(is.na(j), "", ref$cod_dpto[j])

ages <- c("TOTAL" = "all", "<1" = "under 1 year", "1-4" = "1-4", "desconocida" = "not stated")
tr$age <- ifelse(tr$edad %in% names(ages), ages[tr$edad], tr$edad)
tr$year <- as.integer(tr$anio)

# ---- identities ---------------------------------------------------------------
fails <- list()
a <- tr[!is.na(tr$total) & !is.na(tr$hombres) & !is.na(tr$mujeres) & tr$total != tr$hombres + tr$mujeres, ]
if (nrow(a)) fails$tmf <- data.frame(identity = "total = male + female", year = a$year, unit = a$unit, age = a$age,
                                     sex = "", value = a$total, expected = a$hombres + a$mujeres)
long <- rbind(data.frame(year = tr$year, unit = tr$unit, age = tr$age, sex = "male", v = tr$hombres),
              data.frame(year = tr$year, unit = tr$unit, age = tr$age, sex = "female", v = tr$mujeres),
              data.frame(year = tr$year, unit = tr$unit, age = tr$age, sex = "total", v = tr$total))
ag <- aggregate(v ~ year + unit + sex, long[long$age != "all", ], sum)
tt <- long[long$age == "all", c("year", "unit", "sex", "v")]
m <- merge(ag, tt, by = c("year", "unit", "sex"), suffixes = c("_ages", "_total"))
b <- m[m$v_ages != m$v_total, ]
if (nrow(b)) fails$ages <- data.frame(identity = "age rows = TOTAL", year = b$year, unit = b$unit, age = "all",
                                      sex = b$sex, value = b$v_total, expected = b$v_ages)
un <- aggregate(v ~ year + age + sex, long[long$unit != "Total nacional", ], sum)
tn <- long[long$unit == "Total nacional", c("year", "age", "sex", "v")]
m2 <- merge(un, tn, by = c("year", "age", "sex"), suffixes = c("_units", "_total"))
c2 <- m2[m2$v_units != m2$v_total, ]
if (nrow(c2)) fails$units <- data.frame(identity = "units = TOTAL GENERAL", year = c2$year, unit = "Total nacional",
                                        age = c2$age, sex = c2$sex, value = c2$v_total, expected = c2$v_units)
fails <- if (length(fails)) do.call(rbind, fails) else
  data.frame(identity = character(0), year = integer(0), unit = character(0), age = character(0),
             sex = character(0), value = integer(0), expected = integer(0))
write.csv(fails, file.path(sup, "verification_identities.csv"), row.names = FALSE, fileEncoding = "UTF-8")

known_f <- file.path(sup, "source_inconsistencies.csv")
known <- if (file.exists(known_f)) read.csv(known_f, stringsAsFactors = FALSE) else fails[0, ]
new_fail <- fails[!paste(fails$identity, fails$year, fails$unit, fails$age, fails$sex) %in%
                    paste(known$identity, known$year, known$unit, known$age, known$sex), ]
cat(sprintf("rows %d, years %s; identities failing: %d (%d not listed as source inconsistencies)\n",
            nrow(tr), paste(sort(unique(tr$year)), collapse = ","), nrow(fails), nrow(new_fail)))
if (nrow(new_fail)) { print(new_fail); stop("identities fail: check the transcription") }

# ---- comparison with the department deaths series ---------------------------
d <- read.csv("data_input/historical/col_gap_analysis_1920_1985_department_deaths_clean_v06.csv",
              sep = ";", stringsAsFactors = FALSE)
d$k <- strip(gsub("_", " ", d$department))
t1 <- tr[tr$age == "all", ]; t1$k <- strip(t1$unidad)
cmp <- merge(t1[, c("year", "unit", "k", "total", "hombres", "mujeres")], d[, c("year", "k", "total", "male", "female")],
             by = c("year", "k"), suffixes = c("", "_v06"))
cat(sprintf("TOTAL vs department deaths v06: %d units compared, %d equal\n", nrow(cmp), sum(cmp$total == cmp$total_v06, na.rm = TRUE)))
diffs <- cmp[!is.na(cmp$total_v06) & cmp$total != cmp$total_v06, ]
if (nrow(diffs)) print(diffs[, c("year", "unit", "total", "total_v06")], row.names = FALSE)

res <- data.frame(year = tr$year, unit = tr$unit, cod_dpto = tr$cod_dpto, age = tr$age,
                  male = tr$hombres, female = tr$mujeres, total = tr$total)
ord <- c("all", "under 1 year", "1-4", paste(seq(5, 80, 5), seq(9, 84, 5), sep = "-"), "85+", "not stated")
res <- res[order(res$year, res$cod_dpto == "00", res$cod_dpto, match(res$age, ord)), ]
write.csv(res, out, row.names = FALSE, na = "", fileEncoding = "UTF-8")
cat("written:", out, "\n")
