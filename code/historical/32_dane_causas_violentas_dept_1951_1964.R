# 32_dane_causas_violentas_dept_1951_1964.R ------------------------------------
# Violent deaths by cause, sex and department, 1951-1964, from the DANE Anuario
# General de Estadística, table "Defunciones por causas, sexo y secciones del
# país" (1951-52 cuadros 48-49, 1953 c. 41, 1954-55 c. 40, 1957 c. 54, 1958
# c. 51, 1959-61 c. 46, 1962 c. 45, 1963 c. 41, 1964 c. 39). PDFs in the
# dane_biblioteca collection (D:/data/colombia/dane_pdfs/anuarios/nacionales,
# not versioned).
#
# Method
#   The OCR text layer of these tables misaligns the columns, so the rows of
#   violent causes (every row with an ICD "E" code: accidents, suicide,
#   homicide, war operations, legal intervention) and the TOTAL row were
#   transcribed from page images (150-250 dpi renders), one csv per year in
#   data_input/historical/dane_causas_violentas_support/transcripcion_<year>.csv
#   (anio, cuadro, pagina_pdf, unidad, num_causa, causa, codigos, sexo, valor,
#   nota). This script only reads, groups and verifies them.
#
# Checks (written to ..._verification.csv)
#   1. units add up to the national TOTAL column, per cause and sex, where the
#      table prints one;
#   2. homicides against col_gap_analysis_..._department_homicides_clean_v02
#      (the earlier transcription of the same yearbooks), per department, year
#      and sex;
#   3. TOTAL (all causes) against ..._department_deaths_clean_v06.
#
# Output
#   data_input/historical/dane_causas_violentas_dept_1951_1964.csv
#     year, unit (as printed), department (project name), cause_group
#     (homicide, suicide, war, legal_intervention, accident, all_causes),
#     num_causa, causa, codigos, sex (male/female/total), deaths, page, note
#
# Run from the project root: Rscript code/historical/32_dane_causas_violentas_dept_1951_1964.R

sup <- "data_input/historical/dane_causas_violentas_support"
out <- "data_input/historical/dane_causas_violentas_dept_1951_1964.csv"
ver_out <- "data_input/historical/dane_causas_violentas_dept_1951_1964_verification.csv"

files <- list.files(sup, pattern = "^transcripcion_[0-9]{4}[.]csv$", full.names = TRUE)
stopifnot(length(files) > 0)
tr <- do.call(rbind, lapply(files, function(f) {
  x <- read.csv(f, encoding = "UTF-8", stringsAsFactors = FALSE, colClasses = "character")
  x[, c("anio", "cuadro", "pagina_pdf", "unidad", "num_causa", "causa", "codigos", "sexo", "valor", "nota")]
}))
tr$valor <- suppressWarnings(as.integer(gsub("[^0-9]", "", tr$valor)))

strip <- function(x) toupper(trimws(gsub("\\s+", " ", iconv(x, "UTF-8", "ASCII//TRANSLIT"))))
u <- trimws(gsub("\\([0-9]+\\)", "", gsub("[.]", "", strip(tr$unidad))))   # "CORDOBA (1)": footnote mark
map <- c("VALLE" = "VALLE DEL CAUCA", "N DE SANTANDER" = "NORTE DE SANTANDER", "BOGOTA D E" = "BOGOTA",
         "BOGOTA DE" = "BOGOTA", "DISTRITO ESPECIAL DE BOGOTA" = "BOGOTA", "GUAJIRA" = "LA GUAJIRA",
         "SAN ANDRES" = "SAN ANDRES Y PROVIDENCIA", "COLOMBIA" = "TOTAL", "TOTAL GENERAL" = "TOTAL")
tr$department <- ifelse(u %in% names(map), map[u], u)

cg <- function(causa, cod) {
  # parentheses hold exclusions ("excepto suicidios, homicidios ...") and
  # qualifiers, not the cause itself
  k <- toupper(paste(gsub("\\([^)]*\\)", "", causa), cod))
  ifelse(grepl("^TOTAL", toupper(trimws(causa))), "all_causes",
  ifelse(grepl("HOMICID|E964|E98[0-5]", k), "homicide",
  ifelse(grepl("SUICID|E963|E97[0-9]", k), "suicide",
  ifelse(grepl("GUERRA|E99[0-9]", k), "war",
  ifelse(grepl("INTERVENCI.N LEGAL|E96[5-9]|E98[6-9]", k), "legal_intervention", "accident")))))
}
tr$cause_group <- cg(tr$causa, tr$codigos)
tr$sex <- c(H = "male", M = "female", T = "total")[toupper(tr$sexo)]

res <- data.frame(year = as.integer(tr$anio), unit = tr$unidad, department = tr$department,
                  cause_group = tr$cause_group, num_causa = tr$num_causa, causa = tr$causa,
                  codigos = tr$codigos, sex = tr$sex, deaths = tr$valor,
                  page = as.integer(tr$pagina_pdf), note = tr$nota, stringsAsFactors = FALSE)
res <- res[order(res$year, res$cause_group, res$department, res$sex), ]
write.csv(res, out, row.names = FALSE, na = "", fileEncoding = "UTF-8")

# ---- verification ------------------------------------------------------------
ver <- list()
# 1. units vs national total column
units <- res[res$department != "TOTAL", ]; tot <- res[res$department == "TOTAL", ]
if (nrow(tot)) {
  s <- aggregate(deaths ~ year + num_causa + causa + sex, units, sum)
  m <- merge(s, tot[, c("year", "num_causa", "causa", "sex", "deaths")],
             by = c("year", "num_causa", "causa", "sex"), suffixes = c("_units", "_total"))
  ver$suma <- data.frame(check = "units_vs_total_column", year = m$year,
                         item = paste(m$num_causa, m$causa, m$sex), department = "TOTAL",
                         ours = m$deaths_units, reference = m$deaths_total,
                         diff = m$deaths_units - m$deaths_total)
}
# 2. homicides vs v02
h <- read.csv("data_input/historical/col_gap_analysis_1920_1985_department_homicides_clean_v02.csv",
              stringsAsFactors = FALSE)
hom <- aggregate(deaths ~ year + department + sex, res[res$cause_group == "homicide" & res$department != "TOTAL", ], sum)
hl <- rbind(data.frame(year = h$year, department = h$department, sex = "male", v02 = h$male),
            data.frame(year = h$year, department = h$department, sex = "female", v02 = h$female))
m2 <- merge(hom, hl, by = c("year", "department", "sex"), all.x = TRUE)
ver$hom <- data.frame(check = "homicide_vs_v02", year = m2$year, item = m2$sex, department = m2$department,
                      ours = m2$deaths, reference = m2$v02, diff = m2$deaths - m2$v02)
# 3. all-cause deaths vs v06
d <- read.csv("data_input/historical/col_gap_analysis_1920_1985_department_deaths_clean_v06.csv",
              sep = ";", stringsAsFactors = FALSE)
d$department <- strip(gsub("_", " ", d$department))   # v06 writes norte_de_santander
dl <- rbind(data.frame(year = d$year, department = d$department, sex = "male", v06 = d$male),
            data.frame(year = d$year, department = d$department, sex = "female", v06 = d$female))
tot_u <- res[res$cause_group == "all_causes" & res$department != "TOTAL", c("year", "department", "sex", "deaths")]
m3 <- merge(tot_u, dl, by = c("year", "department", "sex"), all.x = TRUE)
ver$tot <- data.frame(check = "all_causes_vs_v06", year = m3$year, item = m3$sex, department = m3$department,
                      ours = m3$deaths, reference = m3$v06, diff = m3$deaths - m3$v06)
ver <- do.call(rbind, ver)
write.csv(ver, ver_out, row.names = FALSE, na = "")

cat(sprintf("rows: %d, years: %s\n", nrow(res), paste(sort(unique(res$year)), collapse = ",")))
for (k in unique(ver$check)) {
  v <- ver[ver$check == k, ]
  cat(sprintf("%-22s compared: %4d  equal: %4d  differ: %4d  no reference: %4d\n", k,
              nrow(v), sum(v$diff == 0, na.rm = TRUE), sum(v$diff != 0, na.rm = TRUE), sum(is.na(v$reference))))
}
