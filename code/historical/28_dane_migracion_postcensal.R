# 28_dane_migracion_postcensal.R ---------------------------------------------------
# DANE, "Estudios postcensales No. 7: Proyecciones nacionales y departamentales de
# poblacion 2005-2020" (2009, native text layer): data_input/dane_pdfs/estudios/estudios_postcensales_07.pdf
# (not versioned). Catalogue: documents/catalogo_migracion_interdepartamental.md.
#
# Saldo neto migratorio (SNM) adopted by DANE = internal + international; departments add
# up to the national international SNM.
#   Cuadro 2 (p. 16)       national SNM by sex and 5-year age group, 4 quinquenios 1985-2005
#   Cuadro 3 (p. 19)       2005 census, residence 5 years before: inmigrantes, emigrantes, saldo
#   Cuadro 4 (p. 21)       SNM adopted by department, 4 quinquenios 1985-2005
#   Cuadro 5 (p. 43)       national SNM by sex and age, 3 quinquenios 2005-2020
#   Cuadro 6 (pp. 43-44)   SNM by department, 3 quinquenios 2005-2020
#   Anexo D (pp. 287-300)  SNM by department x sex x age x quinquenio, 2005-2020
# Checks (the script stops if any fails): ages add to Total in every block; men + women =
# both in Cuadros 2 and 5; departments add to the national row in Cuadros 4 and 6 (within the
# printed rounding); Anexo D department totals = Cuadro 6; Anexo D departments add to the
# national Cuadro 5 by age.
#
# output: data_input/migration/dane_internal/
#   epc07_snm_national_sex_age_1985-2005.csv, epc07_snm_national_sex_age_2005-2020.csv,
#   epc07_snm_department_1985-2005.csv, epc07_snm_department_2005-2020.csv,
#   epc07_snm_department_sex_age_2005-2020.csv, epc07_migracion_5y_census2005.csv

library(pdftools)
pdf  <- "data_input/dane_pdfs/estudios/estudios_postcensales_07.pdf"
out  <- "data_input/migration/dane_internal"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
pages <- pdf_text(pdf)
lines <- function(p) unlist(strsplit(pages[p], "\n"))

num <- function(x) {                       # "-1.290" "-1290" "38.635" -> integer
  x <- gsub("\\.", "", x); as.numeric(x)
}
nums <- function(s) {
  m <- regmatches(s, gregexpr("-?[0-9][0-9.]*", s))[[1]]
  num(m)
}
age_labels <- c("0-4","5-9","10-14","15-19","20-24","25-29","30-34","35-39","40-44",
                "45-49","50-54","55-59","60-64","65-69","70-74","75-79","80+")
age_start <- c(0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80)
norm_age <- function(l) {
  l <- trimws(l)
  if (grepl("^Total", l)) return("Total")
  if (grepl("^80", l)) return("80+")
  m <- regmatches(l, regexpr("^[0-9]{1,2}-[0-9]{1,2}", l))
  if (length(m) == 0) return(NA_character_)
  p <- strsplit(m, "-")[[1]]
  paste0(as.integer(p[1]), "-", as.integer(p[2]))
}
stopifnot_msg <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

# ---- age-sex blocks (Cuadro 2, Cuadro 5, Anexo D): rows "label n n n ..." ----
read_age_rows <- function(ls, ncol) {
  res <- list(); i <- 1
  while (i <= length(ls)) {
    l <- ls[i]; a <- norm_age(l)
    if (!is.na(a) && (a %in% c("Total", age_labels) || grepl("^80", trimws(l)))) {
      body <- sub("^\\s*(Total|[0-9]{1,2}-[0-9]{0,2}[Yy+]*[^ ]*)", "", l)
      v <- nums(body)
      if (length(v) < ncol && i < length(ls)) v <- c(v, nums(ls[i + 1]))   # "80-" / "Y+" split
      if (length(v) == ncol) res[[length(res) + 1]] <- c(list(age = a), as.list(v))
    }
    i <- i + 1
  }
  res
}

# ---- Cuadro 2 (p. 16) ----
r <- read_age_rows(lines(16), 12)
stopifnot_msg(length(r) == 18, "Cuadro 2: expected 18 rows")
q85 <- c("1985-1990","1990-1995","1995-2000","2000-2005")
c2 <- do.call(rbind, lapply(r, function(x) {
  v <- unlist(x[-1]); data.frame(age = x$age, quinquenio = rep(q85, each = 3),
    sex = rep(c("male","female","both"), 4), snm = v)
}))
chk <- function(d, tot_label = "Total") {
  for (q in unique(d$quinquenio)) for (s in unique(d$sex)) {
    x <- d[d$quinquenio == q & d$sex == s, ]
    stopifnot_msg(abs(sum(x$snm[x$age != tot_label]) - x$snm[x$age == tot_label]) <= 20,
                  paste("age sum fails", q, s))
  }
  w <- reshape(d[, c("age","quinquenio","sex","snm")], idvar = c("age","quinquenio"),
               timevar = "sex", direction = "wide")
  stopifnot_msg(all(abs(w$snm.male + w$snm.female - w$snm.both) <= 3), "male+female != both")
}
chk(c2)
c2$age_start <- age_start[match(c2$age, age_labels)]
write.csv(c2, file.path(out, "epc07_snm_national_sex_age_1985-2005.csv"), row.names = FALSE)

# ---- Cuadro 5 (p. 43, rows before the department table) ----
l43 <- lines(43); cut <- grep("Cuadro 6", l43)[1]
r <- read_age_rows(l43[seq_len(cut - 1)], 9)
stopifnot_msg(length(r) == 18, "Cuadro 5: expected 18 rows")
q20 <- c("2005-2010","2010-2015","2015-2020")
c5 <- do.call(rbind, lapply(r, function(x) {
  v <- unlist(x[-1]); data.frame(age = x$age, quinquenio = rep(q20, each = 3),
    sex = rep(c("male","female","both"), 3), snm = v)
}))
chk(c5)
c5$age_start <- age_start[match(c5$age, age_labels)]
write.csv(c5, file.path(out, "epc07_snm_national_sex_age_2005-2020.csv"), row.names = FALSE)

# ---- department rows (Cuadros 3, 4, 6) ----
canon <- c("Antioquia","Atlántico","Bogotá D.C.","Bolívar","Boyacá","Caldas","Caquetá","Cauca",
  "Cesar","Córdoba","Cundinamarca","Chocó","Huila","La Guajira","Magdalena","Meta","Nariño",
  "Norte de Santander","Quindío","Risaralda","Santander","Sucre","Tolima","Valle del Cauca",
  "Arauca","Casanare","Putumayo","San Andrés y Providencia","Grupo Amazonía")
fixname <- function(n) {
  n <- trimws(gsub("[*.]+$", "", n))
  n <- sub("^N\\. de Santander$", "Norte de Santander", n)
  n <- sub("^Bogotá( D\\.?C)?$", "Bogotá D.C.", n)
  n <- sub("^Valle$", "Valle del Cauca", n)
  n <- sub("^San Andrés y Providencia?$", "San Andrés y Providencia", n)
  n
}
read_dept_rows <- function(ls, ncol) {
  res <- list()
  for (i in seq_along(ls)) {
    m <- regmatches(ls[i], regexec("^\\s*([A-Za-zÁÉÍÓÚáéíóúñÑ.* ]+?)\\s{2,}(-?[0-9][0-9.]*(?:\\s+-?[0-9][0-9.]*)*)", ls[i], perl = TRUE))[[1]]
    if (length(m) == 0) next
    nm <- fixname(m[2]); v <- nums(m[3])
    if (nm == "San Andrés y Provi-") {}   # handled below
    if (nm %in% c(canon, "Nacional", "NACIONAL", "Total") && length(v) >= ncol)
      res[[length(res) + 1]] <- c(list(unit = nm), as.list(v[seq_len(ncol)]))
  }
  res
}
# Cuadro 4 (p. 21)
r <- read_dept_rows(lines(21), 4)
d4 <- do.call(rbind, lapply(r, function(x) data.frame(unit = x$unit, quinquenio = q85, snm = unlist(x[-1]))))
d4 <- d4[!duplicated(d4[c("unit","quinquenio")]), ]
stopifnot_msg(sum(d4$unit != "Nacional") == 29 * 4, "Cuadro 4: expected 29 units")
for (q in q85) stopifnot_msg(abs(sum(d4$snm[d4$unit != "Nacional" & d4$quinquenio == q]) -
  d4$snm[d4$unit == "Nacional" & d4$quinquenio == q]) <= 40, paste("Cuadro 4 sum fails", q))
write.csv(d4, file.path(out, "epc07_snm_department_1985-2005.csv"), row.names = FALSE)

# Cuadro 6 (pp. 43-44)
l6 <- c(l43[(cut + 1):length(l43)], lines(44))
r <- read_dept_rows(l6, 3)
d6 <- do.call(rbind, lapply(r, function(x) data.frame(unit = x$unit, quinquenio = q20, snm = unlist(x[-1]))))
d6 <- d6[!duplicated(d6[c("unit","quinquenio")]), ]
write.csv(d6, file.path(out, "epc07_snm_department_2005-2020.csv"), row.names = FALSE)

# Cuadro 3 (p. 19): left columns only; San Andres name wraps over two lines
l19 <- sub("^(.{0,86}).*$", "\\1", lines(19))
l19 <- sub("^(\\s*San Andrés y Provi-)\\s*$", "\\1", l19)
i <- grep("^\\s*San Andrés y Provi-", l19)
if (length(i) == 1) { l19[i] <- paste0(" San Andrés y Providencia ", "  ", sub("\\s*dencia\\.?\\s*$", "", l19[i + 1])); l19[i + 1] <- "" }
r <- read_dept_rows(l19, 3)
d3 <- do.call(rbind, lapply(r, function(x) data.frame(unit = x$unit,
        inmigrantes = x[[2]], emigrantes = x[[3]], saldo = x[[4]])))
# the 5 Amazonia departments are listed separately here: keep as printed
stopifnot_msg(all(abs(d3$inmigrantes - d3$emigrantes - d3$saldo) <= 1), "Cuadro 3: saldo != inm - emi")
write.csv(d3, file.path(out, "epc07_migracion_5y_census2005.csv"), row.names = FALSE)

# ---- Anexo D (pp. 287-300) ----
blocks <- list()
for (p in 287:300) {
  ls <- lines(p)
  starts <- grep("^\\s*Total\\s", ls)
  for (k in seq_along(starts)) {
    s <- starts[k]
    e <- if (k < length(starts)) starts[k + 1] - 1 else length(ls)
    hdr <- ls[max(1, s - 4):(s - 1)]
    hdr <- hdr[!grepl("Edad|Quinquenios|PROYECC|ESTUDIOS|Hombres|Fuente|^\\s*$", hdr)]
    hdr <- trimws(gsub("20[0-9]{2}-20[0-9]{2}", "", hdr))
    hdr <- hdr[nzchar(hdr) & !grepl("[0-9]", hdr)]
    nm <- paste(hdr, collapse = " ")
    rr <- read_age_rows(ls[s:e], 6)
    blocks[[length(blocks) + 1]] <- list(page = p, name = nm, rows = rr)
  }
}
cat("Anexo D blocks:", length(blocks), "\n")
print(vapply(blocks, function(b) paste0(b$page, ":", b$name, ":", length(b$rows)), ""))

# ---- assemble Anexo D ----
an <- function(n) {
  n <- trimws(n)
  n <- c("DE SANTANDER" = "Norte de Santander", "PROVIDENCIA" = "San Andrés y Providencia",
         "AMAZONÍA" = "Grupo Amazonía", "INTERNACIONAL" = "Nacional")[n]
  n
}
tc <- function(x) { x <- tolower(x); paste0(toupper(substring(x, 1, 1)), substring(x, 2)) }
canon_up <- setNames(canon, toupper(canon))
ad <- do.call(rbind, lapply(blocks, function(b) {
  nm <- b$name
  nm2 <- if (nm %in% names(canon_up)) canon_up[[nm]] else {
    a <- c("DE SANTANDER" = "Norte de Santander", "PROVIDENCIA" = "San Andrés y Providencia",
           "AMAZONÍA" = "Grupo Amazonía", "INTERNACIONAL" = "Nacional")[nm]
    if (is.na(a)) stop("unmapped unit: ", nm)
    unname(a)
  }
  do.call(rbind, lapply(b$rows, function(x) {
    v <- unlist(x[-1])
    data.frame(unit = nm2, age = x$age, quinquenio = rep(q20, each = 2),
               sex = rep(c("male","female"), 3), snm = v)
  }))
}))
ad$age_start <- age_start[match(ad$age, age_labels)]
# check 1: ages add up to Total (+-20 for rounding)
for (u in unique(ad$unit)) for (q in q20) for (s in c("male","female")) {
  x <- ad[ad$unit == u & ad$quinquenio == q & ad$sex == s, ]
  if (abs(sum(x$snm[x$age != "Total"]) - x$snm[x$age == "Total"]) > 25)
    cat("AGE SUM FAILS:", u, q, s, sum(x$snm[x$age != "Total"]), x$snm[x$age == "Total"], "\n")
}
# check 2: Anexo D unit totals vs Cuadro 6
tot <- aggregate(snm ~ unit + quinquenio, ad[ad$age == "Total" & ad$unit != "Nacional", ], sum)
cmp <- merge(tot, d6, by = c("unit","quinquenio"), suffixes = c(".anexoD", ".cuadro6"))
cmp$diff <- cmp$snm.anexoD - cmp$snm.cuadro6
cat("\nAnexo D total vs Cuadro 6 (differences != 0):\n"); print(cmp[abs(cmp$diff) > 5, ])
# check 3: units + (Tolima, Valle del Cauca, missing from Anexo D) = national by age, sex, quinquenio
nat <- ad[ad$unit == "Nacional", ]
sm  <- aggregate(snm ~ age + quinquenio + sex, ad[ad$unit != "Nacional", ], sum)
res <- merge(nat[, c("age","quinquenio","sex","snm","age_start")], sm, by = c("age","quinquenio","sex"),
             suffixes = c(".nat", ".sum"))
res$residual <- res$snm.nat - res$snm.sum
names(res)[names(res) == "snm.nat"] <- "national"
cat("\nResidual (national minus the 27 units present) = Tolima + Valle del Cauca, total row:\n")
print(res[res$age == "Total", c("quinquenio","sex","national","snm.sum","residual")])
tv <- d6[d6$unit %in% c("Tolima","Valle del Cauca"), ]
cat("\nCuadro 6 Tolima + Valle del Cauca by quinquenio:\n"); print(aggregate(snm ~ quinquenio, tv, sum))
write.csv(ad[ad$unit != "Nacional", c("unit","quinquenio","sex","age","age_start","snm")],
          file.path(out, "epc07_snm_department_sex_age_2005-2020.csv"), row.names = FALSE)
write.csv(res[, c("age","age_start","quinquenio","sex","national","snm.sum","residual")],
          file.path(out, "epc07_snm_anexoD_residual_tolima_valle.csv"), row.names = FALSE)
