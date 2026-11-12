# 29_dane_boletin314_migracion.R ---------------------------------------------------
# DANE, Boletin Mensual de Estadistica No. 314 (Sept. 1977), "La migracion interna y el
# proceso de concentracion de la poblacion en los departamentos" (pp. 8-46 of the PDF):
# data_input/dane_pdfs/boletines/BOL_314_1977-141.pdf (not versioned). Library scan with a text layer
# (digits mostly right; glued columns and some wrong characters). Source of the figures: muestra
# de avance of the 1973 census (populations adjusted with the post-census coverage rates) and
# the 1964 census. Catalogue: documents/catalogo_migracion_interdepartamental.md.
#
# Tables extracted (PDF pages)
#   Cuadro 10 (p. 39)  resident, native, non-native and inmigrant population by department, 1964
#                      and 1973, and the change 1964-73 (18 units, footnoted aggregates)
#   Cuadro 11 (p. 39)  population by department of ORIGIN, 1964 and 1973
#   Cuadro 12 (p. 40)  inmigrantes, emigrantes, saldo and migration index (thousands)
#   Cuadro 13 (p. 40)  migration index by period: 1951, 1951-64, 1964, 1964-73, 1973
#   Cuadro 6  (pp. 32-34)  1973 population by place of birth (25 columns) and place of residence
#                      (23 departments and 22 capitals)
# Units in Cuadros 10-13: Bolivar includes Sucre, Caldas includes Quindio and Risaralda,
# Magdalena includes Cesar (footnotes); the territories and La Guajira are outside the flows.
#
# output: data_input/migration/dane_internal/
#   bol314_cuadros10_11_dept_1964_1973.csv, bol314_cuadro12_saldo_indice_dept.csv,
#   bol314_cuadro13_indice_periodos.csv, bol314_cuadro6_nacimiento_residencia_1973.csv,
#   bol314_cuadro14_saldos_pares_1973.csv (computed from Cuadro 6)

library(pdftools)
pdf  <- "data_input/dane_pdfs/boletines/BOL_314_1977-141.pdf"
out  <- "data_input/migration/dane_internal"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
pages <- pdf_text(pdf)
lines <- function(p) unlist(strsplit(pages[p], "\n"))
stopifnot_msg <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

# ---- number tokenizer: groups of 3 digits after a dot are thousands, 1-2 digits decimals ----
tok <- function(s) {
  s <- gsub("[~—–]", "-", s)
  m <- gregexpr("-?\\s*\\d{1,3}(?:\\.\\d{3})*(?:\\.\\d{1,2})?(?![0-9])|-?\\s*\\d+(?![0-9.])", s, perl = TRUE)
  v <- gsub("\\s", "", regmatches(s, m)[[1]])
  suppressWarnings(as.numeric(gsub("\\.(\\d{3})", "\\1", v)))
}
# label = text before the first number; footnote markers like "1/" are removed first
split_row <- function(l) {
  l <- gsub("[0-9]\\s?[/|!]", "", l)
  b <- regexpr("[-~]?\\s*\\d", l)
  if (b < 0) return(NULL)
  list(label = trimws(substr(l, 1, b - 1)), nums = tok(substr(l, b, nchar(l))))
}

depts18 <- c("Antioquia","Atlántico","Bogotá D.E.","Bolívar (con Sucre)","Boyacá",
  "Caldas (con Quindío y Risaralda)","Cauca","Córdoba","Cundinamarca","Chocó","Huila",
  "Magdalena (con Cesar)","Meta","Nariño","Norte de Santander","Santander","Tolima","Valle del Cauca")

read_block <- function(ls, from_re, ncol, n = 18, total = TRUE) {
  i0 <- grep(from_re, ls)[1]
  rows <- list()
  for (i in (i0 + 1):length(ls)) {
    r <- split_row(ls[i])
    if (is.null(r) || grepl("^(Fuente|Cuadro)", r$label)) next
    if (grepl("Departamentos|1951|1964", ls[i]) && !grepl("[A-Za-zÁ-ú]{4,}", sub("Departamentos", "", ls[i]))) next
    if (grepl("^\\s*Departamentos", ls[i])) next
    if (grepl("^TOTAL", r$label) || length(rows) > 0 || nchar(r$label) > 2) {
      if (grepl("^TOTAL", r$label) || length(r$nums) >= ncol - 2) rows[[length(rows) + 1]] <- c(list(raw = ls[i]), r)
    }
    if (length(rows) == n + as.integer(total)) break
  }
  rows
}
report_counts <- function(rows, ncol, name) {
  cnt <- vapply(rows, function(r) length(r$nums), 0L)
  cat(name, ": rows =", length(rows), "; rows with", ncol, "numbers =", sum(cnt == ncol), "\n")
  for (k in which(cnt != ncol)) cat("   ", k, ":", rows[[k]]$label, "n =", cnt[k], "|", trimws(rows[[k]]$raw), "\n")
}

# Known print/OCR defects of these two pages, repaired before tokenizing. Each correction is the
# value that the identities below ask for (pop = native + non-native, changes = 1973 - 1964,
# inmigrantes of the period = 1973 - 1964 stocks, Cuadro 12 = Cuadros 10-11 in thousands) and
# is listed in ocr_support/corrections_bol314.csv. The script stops if one does not apply.
corr <- data.frame(
  line = c("^\\s*Antioquia", "^\\s*Boyac", "^\\s*Huita|^\\s*Huila\\s+416", "^\\s*Huita|^\\s*Huila\\s+416",
           "^\\s*N\\.\\s?deSantander\\s+534", "^\\s*N\\.\\s?deSantander\\s+534", "^\\s*Atl.ntico\\s+601", "^\\s*Cundinamarca\\s+1\\.418",
           "^\\s*N\\.\\s?de Santander\\s+-\\s31"),
  from = c("665.897", "-67.991", "-8.433", "53.331", "91.990-78.220195.111162.742", "28.8242.74", "601.765", "461.407", "- 49"),
  to   = c("655.897", "67.991", "8.433", "63.331", "91.990 78.220 195.111 162.742", "28.824 2.74", "601.755", "451.407", "49"),
  why  = c("change in population = 1973 - 1964 (655 897) and = native + non-native changes",
           "native change = 1 048 107 - 980 116, a stray minus", "non-native change = 72 665 - 64 232, a stray minus",
           "inmigrantes 1973 = 63 331 (Cuadro 12 gives 63 thousand; 63 331 - 61 266 = 2 065 printed)",
           "glued columns (Cuadro 10, 1973 non-native, inmigrantes, changes)", "glued: 28.824 and 2.74 per cent",
           "origin population 1964 = 543 937 + 57 818 = 601 755", "emigrants 1964 = 451 407 (Cuadro 12: 451; 607 507 - 451 407 = 156 100 printed)",
           "Cuadro 13: 1964-73 index of Norte de Santander is +49 (Cuadro 12: inm 29, emi 10, saldo +19), printed -49"),
  stringsAsFactors = FALSE)
corr_hit <- rep(FALSE, nrow(corr))
fix_line <- function(l) {
  l <- gsub("(\\d),(\\d{3})", "\\1.\\2", l)          # 1,551.960 / 69,553 -> thousands dot
  l <- gsub("(\\d) (\\d{3})(\\s|$)", "\\1.\\2\\3", l)  # 456 312 -> 456.312
  l <- gsub("\\s\\.\\s", "  ", l)                    # stray dots between columns
  l <- sub("^(\\s*)3olivar", "\\1Bolivar", l)
  l <- gsub("(\\d)-(\\s)", "\\1\\2", l)              # "17.102.670-" trailing dash glued to a number
  for (k in seq_len(nrow(corr))) {                   # row-specific corrections (table below)
    if (grepl(corr$line[k], l) && grepl(corr$from[k], l, fixed = TRUE)) {
      l <- sub(corr$from[k], corr$to[k], l, fixed = TRUE); corr_hit[k] <<- TRUE
    }
  }
  l
}
lines <- function(p) vapply(unlist(strsplit(pages[p], "\n")), fix_line, "", USE.NAMES = FALSE)
l39 <- lines(39); l40 <- lines(40)
i11 <- grep("^\\s*Cuadro 11", l39)[1]
r10 <- read_block(l39[1:(i11 - 1)], "^\\s*Cuadro 10", 13)
r11 <- read_block(l39[i11:length(l39)], "^\\s*Cuadro 11", 13)
i13 <- grep("^\\s*Cuadro 13", l40)[1]
r12 <- read_block(l40[1:(i13 - 1)], "^\\s*Cuadro 12", 12)
r13 <- read_block(l40[i13:length(l40)], "^\\s*Cuadro 13", 5, total = FALSE)
report_counts(r10, 13, "Cuadro 10"); report_counts(r11, 13, "Cuadro 11")
report_counts(r12, 12, "Cuadro 12"); report_counts(r13, 5, "Cuadro 13")

# ---- assemble Cuadros 10-13 ----
unit_names <- c("TOTAL", depts18)
mat <- function(rows, ncol, pad_front = FALSE) {
  t(vapply(rows, function(r) {
    v <- r$nums
    if (pad_front && length(v) < ncol) v <- c(rep(NA_real_, ncol - length(v)), v)
    v[seq_len(ncol)]
  }, numeric(ncol)))
}
# Cuadro 13: a lone dash is a missing value (Bogota 1951 and 1951-64, Cordoba, Meta: no flow
# measured); "- 53" is minus 53
parse13 <- function(raw) {
  s <- sub("^[^A-Za-zÁ-ú]*[A-Za-zÁ-ú][A-Za-zÁ-ú.,x ]*?(?=\\s{2,})", "", raw, perl = TRUE)  # drop the label (and a stray leading dash)
  s <- gsub("\\s*[.·x]\\s+(?=[-0-9])", "  ", s, perl = TRUE)
  s <- gsub("-\\s{1,4}(?=\\d)", "-", s, perl = TRUE)  # a minus sign is 1-4 spaces from its number; a lone dash is 8+
  tk <- strsplit(trimws(s), "\\s+")[[1]]
  tk[tk == "-"] <- NA
  as.numeric(tk)
}
m13 <- t(vapply(r13, function(r) parse13(r$raw), numeric(5)))
m10 <- mat(r10, 13); m11 <- mat(r11, 13); m12 <- mat(r12, 12)
stopifnot_msg(nrow(m10) == 19 && nrow(m11) == 19 && nrow(m12) == 19 && nrow(m13) == 18, "row counts")
c10 <- c("pop_1964","native_1964","nonnative_1964","inm_dept_1964",
         "pop_1973","native_1973","nonnative_1973","inm_dept_1973",
         "chg_pop","chg_native","chg_nonnative","inm_dept_period","inm_dept_period_pct")
c11 <- c("origin_pop_1964","resident_in_dept_1964","resident_outside_1964","emigrants_dept_1964",
         "origin_pop_1973","resident_in_dept_1973","resident_outside_1973","emigrants_dept_1973",
         "chg_origin_pop","chg_resident_in_dept","chg_resident_outside","emigrants_dept_period","emigrants_dept_period_pct")
colnames(m10) <- c10; colnames(m11) <- c11
c12n <- c("inm_1964","emi_1964","saldo_1964","index_1964","inm_1973","emi_1973","saldo_1973","index_1973",
          "inm_period","emi_period","saldo_period","index_period")
colnames(m12) <- c12n
colnames(m13) <- c("index_stock_1951","index_period_1951_64","index_stock_1964","index_period_1964_73","index_stock_1973")
rownames(m10) <- rownames(m11) <- rownames(m12) <- unit_names; rownames(m13) <- depts18

# identities
chk_eq <- function(a, b, tol, what) {
  bad <- which(abs(a - b) > tol)
  if (length(bad)) {
    cat("IDENTITY FAILS:", what, "\n"); print(data.frame(unit = unit_names[bad], a = a[bad], b = b[bad]))
  }
  invisible(length(bad))
}
nbad <- 0
nbad <- nbad + chk_eq(m10[, "pop_1964"], m10[, "native_1964"] + m10[, "nonnative_1964"], 2, "C10 1964 pop = native + non-native")
nbad <- nbad + chk_eq(m10[, "pop_1973"], m10[, "native_1973"] + m10[, "nonnative_1973"], 2, "C10 1973 pop = native + non-native")
nbad <- nbad + chk_eq(m10[, "chg_pop"], m10[, "pop_1973"] - m10[, "pop_1964"], 2, "C10 change in population")
nbad <- nbad + chk_eq(m10[, "chg_native"], m10[, "native_1973"] - m10[, "native_1964"], 2, "C10 change in natives")
nbad <- nbad + chk_eq(m10[, "chg_nonnative"], m10[, "nonnative_1973"] - m10[, "nonnative_1964"], 2, "C10 change in non-natives")
nbad <- nbad + chk_eq(m10[-1, "inm_dept_period"], m10[-1, "inm_dept_1973"] - m10[-1, "inm_dept_1964"], 2, "C10 inmigrantes period = 1973 - 1964")
# TOTAL row minus the 18 units: La Guajira (a separate unit in 1973 but inside Magdalena in 1964)
# and the territories are in the total but not in the rows; reported, not asserted
tot_gap <- function(m) m[1, ] - colSums(m[-1, ])
nbad <- nbad + chk_eq(m11[, "origin_pop_1964"], m11[, "resident_in_dept_1964"] + m11[, "resident_outside_1964"], 2, "C11 1964")
nbad <- nbad + chk_eq(m11[, "origin_pop_1973"], m11[, "resident_in_dept_1973"] + m11[, "resident_outside_1973"], 2, "C11 1973")
nbad <- nbad + chk_eq(m11[, "chg_origin_pop"], m11[, "origin_pop_1973"] - m11[, "origin_pop_1964"], 2, "C11 change")
# Cuadro 12 (thousands): inmigrantes - emigrantes = saldo (+-1 for rounding)
for (s in c("1964","1973","period")) nbad <- nbad + chk_eq(m12[, paste0("inm_", s)] - m12[, paste0("emi_", s)], m12[, paste0("saldo_", s)], 1.5, paste("C12 saldo", s))
# Cuadro 12 = Cuadros 10-11 / 1000 (inmigrantes of other departments, emigrants)
nbad <- nbad + chk_eq(m12[, "inm_1964"], round(m10[, "inm_dept_1964"] / 1000), 1.1, "C12 inm 1964 = C10")
nbad <- nbad + chk_eq(m12[, "inm_1973"], round(m10[, "inm_dept_1973"] / 1000), 1.1, "C12 inm 1973 = C10")
nbad <- nbad + chk_eq(m12[, "inm_period"], round(m10[, "inm_dept_period"] / 1000), 1.1, "C12 inm period = C10")
nbad <- nbad + chk_eq(m12[, "emi_1964"], round(m11[, "emigrants_dept_1964"] / 1000), 1.1, "C12 emi 1964 = C11")
nbad <- nbad + chk_eq(m12[, "emi_1973"], round(m11[, "emigrants_dept_1973"] / 1000), 1.1, "C12 emi 1973 = C11")
nbad <- nbad + chk_eq(m12[, "emi_period"], round(m11[, "emigrants_dept_period"] / 1000), 1.1, "C12 emi period = C11")
# index = 100 saldo / (inm + emi) (Cuadro 12 and the period columns of Cuadro 13)
for (s in c("1964","1973","period")) {
  ix <- 100 * m12[, paste0("saldo_", s)] / (m12[, paste0("inm_", s)] + m12[, paste0("emi_", s)])
  nbad <- nbad + chk_eq(m12[-1, paste0("index_", s)], ix[-1], 3, paste("C12 index", s))
}
nbad <- nbad + chk_eq(m13[, "index_stock_1964"], m12[-1, "index_1964"], 1.1, "C13 1964 = C12")
nbad <- nbad + chk_eq(m13[, "index_period_1964_73"], m12[-1, "index_period"], 1.1, "C13 1964-73 = C12")
nbad <- nbad + chk_eq(m13[, "index_stock_1973"], m12[-1, "index_1973"], 1.1, "C13 1973 = C12")
cat("identity failures (Cuadros 10-13):", nbad, "\n")
stopifnot_msg(nbad == 0, "identities fail in Cuadros 10-13")
stopifnot_msg(all(corr_hit), paste("a correction did not apply:", paste(which(!corr_hit), collapse = ",")))
cat("TOTAL row minus the 18 units (La Guajira in 1973 and territories):\n")
print(round(tot_gap(m10)[c("pop_1973","native_1973","nonnative_1973","inm_dept_1973")]))

dir.create(file.path(out, "ocr_support"), showWarnings = FALSE)
write.csv(corr[, c("line","from","to","why")], file.path(out, "ocr_support", "corrections_bol314.csv"), row.names = FALSE)
c1011 <- data.frame(unit = rownames(m10), m10, m11, check.names = FALSE, row.names = NULL)
write.csv(c1011, file.path(out, "bol314_cuadros10_11_dept_1964_1973.csv"), row.names = FALSE)
write.csv(data.frame(unit = rownames(m12), m12, row.names = NULL), file.path(out, "bol314_cuadro12_saldo_indice_dept.csv"), row.names = FALSE)
write.csv(data.frame(unit = rownames(m13), m13, row.names = NULL), file.path(out, "bol314_cuadro13_indice_periodos.csv"), row.names = FALSE)

# ============================================================================
# Cuadro 6 (pp. 32-34): 1973 residence (rows) x place of birth (columns)
# ============================================================================
units23 <- c("Bogotá D.E.","Antioquia","Atlántico","Bolívar","Boyacá","Caldas","Cauca","Cesar",
  "Córdoba","Cundinamarca","Chocó","La Guajira","Huila","Magdalena","Meta","Nariño",
  "Norte de Santander","Quindío","Risaralda","Santander","Sucre","Tolima","Valle del Cauca")
cap_of <- c("Bogotá D.E."="Bogotá","Antioquia"="Medellín","Atlántico"="Barranquilla","Bolívar"="Cartagena",
  "Boyacá"="Tunja","Caldas"="Manizales","Cauca"="Popayán","Cesar"="Valledupar","Córdoba"="Montería",
  "Chocó"="Quibdó","La Guajira"="Riohacha","Huila"="Neiva","Magdalena"="Santa Marta","Meta"="Villavicencio",
  "Nariño"="Pasto","Norte de Santander"="Cúcuta","Quindío"="Armenia","Risaralda"="Pereira",
  "Santander"="Bucaramanga","Sucre"="Sincelejo","Tolima"="Ibagué","Valle del Cauca"="Cali")
row_key <- c("TOTAL DEPARTAMENTOS","TOTAL CAPITALES"); row_type <- c("total","total")
for (u in units23) {
  row_key <- c(row_key, u); row_type <- c(row_type, "department")
  if (u %in% names(cap_of)) { row_key <- c(row_key, cap_of[[u]]); row_type <- c(row_type, "capital") }
}
stopifnot_msg(length(row_key) == 47, "row order")

clean_tok <- function(t) {
  t <- gsub("\\(\\)", "0", t)
  t <- gsub("^[.,:;']+", "", t)
  if (t %in% c("-", "—", "–", "_")) return(0)
  t <- gsub("(?<=\\d)[,.](?=\\d{3}(?!\\d))", "", t, perl = TRUE)     # thousands separator (a comma is a typo)
  t <- gsub("[^0-9-]", "", t)
  if (t == "" || t == "-") return(NA_real_)
  as.numeric(t)
}
# Cell-level corrections of Cuadro 6 (text-layer misreads), each the value the row and column
# identities ask for; listed in ocr_support/corrections_bol314_cuadro6.csv
c6_corr <- data.frame(
  page = c(33, 34, 34, 33, 34, 34),
  line = c("^\\s*Tolima\\s", "^Nari.o\\s|^Nari.lo\\s|^\\s*Nari", "^\\s*N\\. de Santander", "^\\s*Boyac", "^\\s*Armenia", "^\\s*Cali"),
  from = c("44D", "3.74Ž", "38.31B", "(?<=\\s)259(?=\\s*$)", "(1\\.212\\s+)81", "34\\.055"),
  to   = c("440", "3.742", "38.318", "269", "\\171", "34.045"),
  why  = c("Tolima x Cordoba: 44D -> 440 (row and column Cordoba identities, diff 396)",
           "Narino x Extranjeros: 3.74Z -> 3.742 (diff 3 368)",
           "N. de Santander x Santander: 38.31B -> 38.318 (diff 34 487)",
           "Boyaca x Narino: 259 -> 269 (diff 10 in the row and in the column)",
           "Armenia x Sucre: 81 -> 71 (row and capitals column Sucre, diff 10)",
           "Cali x Tolima: 34.055 -> 34.045 (row and capitals column Tolima, diff 10)"),
  stringsAsFactors = FALSE)
c6_hit <- rep(FALSE, nrow(c6_corr))
c6_rows <- function(p, ncol) {
  ls <- unlist(strsplit(pages[p], "\n"))
  for (k in which(c6_corr$page == p)) {
    for (i in seq_along(ls)) if (grepl(c6_corr$line[k], ls[i]) && grepl(c6_corr$from[k], ls[i], perl = TRUE)) {
      ls[i] <- sub(c6_corr$from[k], c6_corr$to[k], ls[i], perl = TRUE); c6_hit[k] <<- TRUE; break
    }
  }
  i0 <- grep("^\\s*TOTAL\\s*(DEPTOS|DEPARTAMENTOS|$)", ls)[1]
  ls <- ls[i0:length(ls)]
  if (grepl("^\\s*TOTAL\\s*$", ls[1])) {                    # p. 34: "TOTAL" / "DEPARTAMENTOS" on two lines
    ls[2] <- sub("^\\s*DEPARTAMENTOS", "TOTAL DEPARTAMENTOS", ls[2]); ls <- ls[-1]
  }
  rows <- list()
  for (l in ls) {
    if (grepl("^1/|^Fuente", trimws(l))) break
    if (!nzchar(trimws(l))) next
    m <- regmatches(l, regexec("^(\\s*)(\\S.*?)\\s{2,}(\\S.*)$", l, perl = TRUE))[[1]]
    if (length(m) == 0) next
    tk <- strsplit(trimws(m[4]), "\\s+")[[1]]
    tk <- tk[!grepl("^[.,;']+-?$", tk)]
    rows[[length(rows) + 1]] <- list(label = trimws(m[3]), v = unname(vapply(tk, clean_tok, 0)), raw = l)
  }
  rows
}
birth_cols <- list(`32` = c("born_total","born_own_dept","born_other_dept","Bogotá D.E.","Antioquia","Atlántico","Bolívar","Boyacá","Caldas"),
                   `33` = c("Cauca","Cesar","Córdoba","Cundinamarca","Chocó","La Guajira","Huila","Magdalena","Meta","Nariño"),
                   `34` = c("Norte de Santander","Quindío","Risaralda","Santander","Sucre","Tolima","Valle del Cauca","Intendencias y comisarías","Extranjeros"))
c6 <- list()
for (p in names(birth_cols)) {
  rr <- c6_rows(as.integer(p), length(birth_cols[[p]]))
  cat("Cuadro 6, p.", p, ": rows", length(rr), "\n")
  stopifnot_msg(length(rr) == 47, paste("p.", p, "rows != 47"))
  bad <- which(vapply(rr, function(r) length(r$v), 0L) != length(birth_cols[[p]]))
  for (b in bad) cat("   token count", length(rr[[b]]$v), "!=", length(birth_cols[[p]]), ":", trimws(rr[[b]]$raw), "\n")
  c6[[p]] <- rr
}

# ---- assemble the 47 x (3 + 25) matrix and check it ----
all_cols <- c("total","born_own_dept","born_other_dept", unlist(birth_cols[-1]), birth_cols[[1]][4:9])
all_cols <- c("total","born_own_dept","born_other_dept", birth_cols[[1]][4:9], birth_cols[[2]], birth_cols[[3]])
M <- do.call(rbind, lapply(seq_len(47), function(i) c(c6[["32"]][[i]]$v, c6[["33"]][[i]]$v, c6[["34"]][[i]]$v)))
M[, 1:3] <- M[, 1:3]
colnames(M) <- c("born_total", "born_own_dept", "born_other_dept", all_cols[-(1:3)])
rownames(M) <- row_key
birth <- M[, 4:ncol(M)]
cat("NA cells:", sum(is.na(M)), "\n")
if (any(is.na(M))) print(which(is.na(M), arr.ind = TRUE))

# Row identities. The birth columns are 25 (23 units, intendencias/comisarias, extranjeros).
birth_unit <- colnames(M)[4:ncol(M)]
own_col <- function(r) {                                       # column of the department of a row
  k <- row_key[r]
  d <- if (row_type[r] == "capital") names(cap_of)[match(k, cap_of)] else k
  match(d, birth_unit)
}
# fill the single unreadable cell from its row identity (population = sum of places of birth)
for (ij in which(is.na(M), arr.ind = FALSE)) {
  r <- ((ij - 1) %% nrow(M)) + 1; cc <- ((ij - 1) %/% nrow(M)) + 1
  M[r, cc] <- M[r, 1] - sum(M[r, -c(1, cc)][-(1:2)], na.rm = TRUE)
  cat("filled from the row identity:", row_key[r], colnames(M)[cc], "=", M[r, cc], "\n")
}
birth <- M[, 4:ncol(M)]
bad <- 0
for (r in 1:47) {
  rs <- sum(birth[r, ])
  if (abs(rs - M[r, "born_total"]) > 2 && !grepl("^TOTAL", row_key[r])) {
    bad <- bad + 1; cat("ROW SUM FAILS:", row_key[r], "total", M[r, "born_total"], "sum of birth columns", rs, "diff", M[r, "born_total"] - rs, "\n")
  }
  if (row_type[r] != "total") {
    ow <- birth[r, own_col(r)]
    if (abs(ow - M[r, "born_own_dept"]) > 2) { bad <- bad + 1; cat("DIAGONAL FAILS:", row_key[r], "born_own_dept", M[r, "born_own_dept"], "diagonal", ow, "\n") }
    if (abs(M[r, "born_total"] - M[r, "born_own_dept"] - M[r, "born_other_dept"]) > 2) { bad <- bad + 1; cat("OWN+OTHER FAILS:", row_key[r], "\n") }
  }
}
cat("row identity failures:", bad, "\n")
dep_rows <- which(row_type == "department"); cap_rows <- which(row_type == "capital")
cs_dep <- colSums(M[dep_rows, ]); cs_cap <- colSums(M[cap_rows, ])
d1 <- M["TOTAL DEPARTAMENTOS", ] - cs_dep; d2 <- M["TOTAL CAPITALES", ] - cs_cap
cat("column sums vs TOTAL DEPARTAMENTOS, differences != 0:\n"); print(d1[abs(d1) > 2])
cat("column sums vs TOTAL CAPITALES, differences != 0:\n"); print(d2[abs(d2) > 2])
stopifnot_msg(all(c6_hit), "a Cuadro 6 correction did not apply")
stopifnot_msg(bad == 0, "Cuadro 6 row identities fail")
# The only mismatch left is a printed cell of the TOTAL CAPITALES row: Magdalena 189.748, while the
# 22 capitals add to 169.748 and the row of TOTAL CAPITALES adds to the printed population with 169.748.
stopifnot_msg(identical(names(d1[abs(d1) > 2]), character(0)) && identical(names(d2[abs(d2) > 2]), "Magdalena") && d2[["Magdalena"]] == 20000,
              "unexpected column-sum differences in Cuadro 6")
cat("TOTAL CAPITALES: sum of its birth cells =", sum(M["TOTAL CAPITALES", 4:ncol(M)]),
    "; printed population =", M["TOTAL CAPITALES", "born_total"], "\n")
cat("TOTAL DEPARTAMENTOS: sum of its birth cells =", sum(M["TOTAL DEPARTAMENTOS", 4:ncol(M)]),
    "; printed population =", M["TOTAL DEPARTAMENTOS", "born_total"], "\n")

# ---- outputs ----
c6_long <- do.call(rbind, lapply(seq_len(47), function(i) data.frame(
  residence = row_key[i], residence_type = row_type[i], birth_place = colnames(birth), population = unname(birth[i, ]),
  stringsAsFactors = FALSE)))
c6_tot <- data.frame(residence = row_key, residence_type = row_type, born_total = M[, "born_total"],
  born_own_dept = M[, "born_own_dept"], born_other_dept = M[, "born_other_dept"], row.names = NULL)
write.csv(c6_long, file.path(out, "bol314_cuadro6_nacimiento_residencia_1973.csv"), row.names = FALSE)
write.csv(c6_tot, file.path(out, "bol314_cuadro6_totales_residencia_1973.csv"), row.names = FALSE)
write.csv(c6_corr[, c("page","line","from","to","why")], file.path(out, "ocr_support", "corrections_bol314_cuadro6.csv"), row.names = FALSE)
write.csv(data.frame(table = "Cuadro 6 (p. 33)", cell = "TOTAL CAPITALES x Magdalena", printed = 189748, sum_of_22_capitals = 169748,
  note = "the printed cell exceeds the sum of the capitals by 20 000; the 22 capital rows and the other 24 columns are consistent"),
  file.path(out, "ocr_support", "source_inconsistencies_bol314.csv"), row.names = FALSE)

# ---- Cuadro 14 (p. 41), recomputed: net balance between pairs of departments, 1973 ----
# printed cell (row i, column j) = people born in i living in j minus people born in j living in i
# (= + for j when j gains from i); checked against the printed page below
dep_names <- units23
net <- outer(seq_along(dep_names), seq_along(dep_names), Vectorize(function(i, j) {
  ri <- which(row_key == dep_names[i] & row_type == "department"); rj <- which(row_key == dep_names[j] & row_type == "department")
  unname(M[rj, 3 + match(dep_names[i], birth_unit)] - M[ri, 3 + match(dep_names[j], birth_unit)])
}))
dimnames(net) <- list(origin_row = dep_names, column = dep_names)
net_long <- data.frame(row_unit = rep(dep_names, times = length(dep_names)),
                       column_unit = rep(dep_names, each = length(dep_names)), net_gain_of_column = as.vector(net))
write.csv(net_long, file.path(out, "bol314_cuadro14_saldos_pares_1973.csv"), row.names = FALSE)
stopifnot_msg(net["Antioquia", "Bogotá D.E."] == 32011 && net["Antioquia", "Atlántico"] == 9805 && net["Bogotá D.E.", "Antioquia"] == -32011,
              "Cuadro 14 spot checks vs the printed page")
cat("Cuadro 14 recomputed; spot checks vs the printed page (Antioquia-Bogotá 32 011, Antioquia-Atlántico 9 805) hold\n")

# ============================================================================
# Cuadro 15 (p. 42): migrants of 1964-73, origin x destination (18 x 18, signed)
# ============================================================================
# The printed cell (row i = residence, column j = origin) is the number of people born in j living
# in i in 1973 minus the same number in 1964 (NOTA of the table): negative when i had fewer in 1973.
# Rows of the page are read by position (pdf_data): the numbers are right-aligned under 9 + 9 column
# anchors fixed by the "TOTAL DE EMIGRANTES" row of each block; a short dash left of a number is its
# minus sign, a long dash alone is a zero cell, the diagonal is empty. The row total (migrants of the
# residence department) and the column total (emigrants of the origin) are printed, so every row and
# every column is an identity; cells that the text layer misreads are solved from those identities and
# checked on a 260 dpi crop of the page (ocr_support/corrections_bol314_cuadro15.csv).
d15 <- pdf_data(pdf)[[42]]
d15$x1 <- d15$x + d15$width
tx <- gsub("(?<=\\d),(?=\\d{3})", ".", d15$text, perl = TRUE)          # 1,666 -> 1.666
tx <- gsub("[^0-9.-]", "", tx); tx <- gsub("\\.+$", "", tx)             # stray dots, 252. 252- ...
tx <- sub("^(\\d[0-9.]*)-$", "\\1", tx)
isnum15 <- grepl("^-?[0-9]{1,3}(\\.[0-9]{3})*$|^-?[0-9]+$", tx) & d15$x >= 100
num15 <- d15[isnum15, ]; num15$val <- as.numeric(gsub("\\.", "", tx[isnum15]))
num15$neg_attached <- grepl("^-", tx[isnum15]); num15$val <- abs(num15$val)
dash15 <- d15[d15$text %in% c("-", "—", "–") & d15$x >= 100, ]
dest18 <- c("Antioquia","Atlántico","Bogotá D.E.","Bolívar","Boyacá","Caldas","Cauca","Córdoba","Cundinamarca",
            "Chocó","Huila","Magdalena","Meta","Nariño","Norte de Santander","Santander","Tolima","Valle del Cauca")
y_b1 <- sort(unique(d15$y[d15$x < 60 & d15$y > 95 & d15$y < 230]))
y_b2 <- sort(unique(d15$y[d15$x < 60 & d15$y > 305 & d15$y < 435]))
stopifnot_msg(length(y_b1) == 18 && length(y_b2) == 18, "Cuadro 15: expected 18 + 18 rows by position")
a1 <- num15[abs(num15$y - 88) <= 2, ]; a1 <- a1[order(a1$x1), ]
a2 <- num15[abs(num15$y - 296) <= 2, ]; a2 <- a2[order(a2$x1), ]
stopifnot_msg(nrow(a1) == 10 && nrow(a2) == 9, "Cuadro 15: expected 10 + 9 anchors")
M15 <- matrix(NA_real_, 18, 18, dimnames = list(residence = dest18, origin = dest18))
tot_row15 <- rep(NA_real_, 18); tot_col15 <- c(a1$val[-1], a2$val)
fill15 <- function(ys, anch, cols, has_total) {
  for (r in seq_along(ys)) {
    rown <- if (ys[1] > 200) r + 0 else r
    ridx <- if (identical(ys, y_b1)) r else r
    row <- num15[abs(num15$y - ys[r]) <= 2, ]; dr <- dash15[abs(dash15$y - ys[r]) <= 2, ]
    for (k in seq_len(nrow(row))) {
      j <- which.min(abs(anch$x1 - row$x1[k]))
      if (abs(anch$x1[j] - row$x1[k]) > 6) next          # the split total of Antioquia "74 622" is set by hand below
      left <- dr[dr$width < 6 & dr$x1 <= row$x[k] + 1 & row$x[k] - dr$x1 < 30, ]
      neg <- row$neg_attached[k] || nrow(left) > 0
      v <- if (neg) -row$val[k] else row$val[k]
      if (has_total && j == 1) tot_row15[ridx] <<- v else M15[ridx, cols[if (has_total) j - 1 else j]] <<- v
    }
    zero <- dr[dr$width >= 6, ]                          # a long dash alone: zero cell
    for (k in seq_len(nrow(zero))) {
      j <- which.min(abs(anch$x1 - zero$x1[k]))
      if (abs(anch$x1[j] - zero$x1[k]) <= 8 && !(has_total && j == 1)) {
        cc <- cols[if (has_total) j - 1 else j]
        if (is.na(M15[ridx, cc])) M15[ridx, cc] <<- 0
      }
    }
  }
}
fill15(y_b1, a1, 1:9, TRUE); fill15(y_b2, a2, 10:18, FALSE)
diag(M15) <- 0
tot_row15[1] <- 74622                                    # printed "74 622" (two tokens)
row_res <- function() tot_row15 - rowSums(M15, na.rm = TRUE)
col_res <- function() tot_col15 - colSums(M15, na.rm = TRUE)
cat("Cuadro 15: NA cells before the identity solver:", sum(is.na(M15) & !diag(18) == 1), "\n")
# (a) cells read on the 260 dpi crop of the page where the text layer is wrong in a way that the
#     identities cannot place alone (two errors in one column, or an error of 1)
img_fix <- data.frame(
  residence = c("Chocó", "Tolima", "Tolima", "Bolívar"), origin = c("Atlántico", "Atlántico", "Cundinamarca", "Cundinamarca"),
  set = c(25, 125, -5570, -1),
  why = c("page shows 25 (text layer: 26)", "page shows 125 (text layer: 126)", "page shows - 5.570 (the minus sign is detached)",
          "page shows - 1 (the minus sign is detached; residual of 2 in row and column)"),
  stringsAsFactors = FALSE)
corr15 <- NULL
for (k in seq_len(nrow(img_fix))) {
  i <- match(img_fix$residence[k], dest18); j <- match(img_fix$origin[k], dest18)
  corr15 <- rbind(corr15, data.frame(residence = img_fix$residence[k], origin = img_fix$origin[k], read = M15[i, j],
                                     set = img_fix$set[k], residual = NA, how = "read on the page image", why = img_fix$why[k]))
  M15[i, j] <- img_fix$set[k]
}
# (b) a cell whose row residual equals its column residual (|residual| > 2) is set to the value both
#     identities ask for; each was compared with the page image
repeat {
  rr <- row_res(); cc <- col_res(); done <- FALSE
  for (i in which(abs(rr) > 2)) for (j in which(abs(cc) > 2)) if (i != j && rr[i] == cc[j]) {
    old <- M15[i, j]; new <- if (is.na(old)) rr[i] else old + rr[i]
    corr15 <- rbind(corr15, data.frame(residence = dest18[i], origin = dest18[j], read = old, set = new, residual = rr[i],
                                       how = "row and column identities", why = ""))
    M15[i, j] <- new; done <- TRUE; break
  }
  if (!done) break
}
print(corr15)
rr <- row_res(); cc <- col_res()
cat("remaining row residuals:\n"); print(rr[rr != 0]); cat("remaining column residuals:\n"); print(cc[cc != 0])
cat("NA cells:", sum(is.na(M15) & !diag(18) == 1), "\n")
# cells with no number whose row and column already add up: printed as a long dash (zero), e.g. Huila x Bolívar
na_cells <- which(is.na(M15), arr.ind = TRUE)
if (nrow(na_cells)) {
  cat("long-dash (zero) cells:\n")
  for (k in seq_len(nrow(na_cells))) {
    cat("   ", dest18[na_cells[k, 1]], "x", dest18[na_cells[k, 2]], "\n")
    corr15 <- rbind(corr15, data.frame(residence = dest18[na_cells[k, 1]], origin = dest18[na_cells[k, 2]], read = NA, set = 0,
                                       residual = 0, how = "printed as a long dash (zero)", why = "row and column already add to the printed totals"))
    M15[na_cells[k, 1], na_cells[k, 2]] <- 0
  }
}
stopifnot_msg(all(rr == 0) && all(cc == 0), "Cuadro 15: rows or columns do not add to the printed totals")
stopifnot_msg(sum(is.na(M15) & !diag(18) == 1) == 0, "Cuadro 15: NA cells left")
stopifnot_msg(sum(M15[M15 > 0]) + sum(M15[M15 < 0]) == sum(M15), "sanity")
# Cuadro 15 total = Cuadro 10-11 inmigrants of the period (1 052 321 in the 18 units)
cat("sum of the row totals:", sum(tot_row15), "; grand total printed 1052321 (the 18 units of Cuadros 10-11, La Guajira and the territories excluded)\n")
c15_long <- data.frame(residence = rep(dest18, times = 18), origin = rep(dest18, each = 18),
                       net_change_1964_73 = as.vector(M15), stringsAsFactors = FALSE)
write.csv(c15_long, file.path(out, "bol314_cuadro15_flujos_1964_73.csv"), row.names = FALSE)
write.csv(data.frame(residence = dest18, printed_total = tot_row15, sum_of_cells = rowSums(M15)),
          file.path(out, "bol314_cuadro15_totales_destino.csv"), row.names = FALSE)
write.csv(data.frame(origin = dest18, printed_total_emigrants = tot_col15, sum_of_cells = colSums(M15)),
          file.path(out, "bol314_cuadro15_totales_origen.csv"), row.names = FALSE)
write.csv(corr15, file.path(out, "ocr_support", "corrections_bol314_cuadro15.csv"), row.names = FALSE)
cat("Cuadro 15 written: all 18 rows and 18 columns add to the printed totals\n")
