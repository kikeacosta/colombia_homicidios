# 27_censo_1973_muestra_avance.R ---------------------------------------------------
# DANE, "La poblacion en Colombia 1973. XIV Censo Nacional de Poblacion y III de
# Vivienda, muestra de avance. Resumen por departamentos, capitales de mas de
# 200 000 habitantes y agregados" (425 pp., phototypeset, library scan with a clean
# OCR text layer): data_input/dane_pdfs/censos/1973/LD_1007_1973_EJ_4.pdf (not versioned).
#
# These are SAMPLE-EXPANDED figures (muestra de avance), not the final census count
# and not the coverage-adjusted population. Per the publication (pp. 7-11): one
# private household in 25 of the 22 departments and Bogota D.E., expanded by 25 (by
# 28 in Bogota, adjusted with the post-census coverage survey); excluded: collective
# households, floating population, armed forces, the indigenous population and the
# territorios nacionales (no intendencias or comisarias at all). Every printed cell
# is therefore a multiple of 25 (28 in Bogota), a check used below. Sampling error:
# 10 % for cells around 12,000 persons, 25 % or more under 1,500.
#
# Tables extracted (pdf pages)
#   Cuadro 1 (p. 40)   the 23 sections added: population by sex, 5-year age group and
#                      zone (total, cabecera, resto), with the masculinity index
#   Cuadro 2 (p. 41)   the 23 sections added: population by sex and single age (0-84, 85+)
#   per section (22 departments and Bogota D.E.), section k = 0..22 from page 72 + 11 k:
#     Cuadro 1 (p. 72 + 11 k)  population by sex and 5-year age group, masculinity index
#     Cuadro 2 (p. 73 + 11 k)  population by sex and single age (0-84, 85+), in two column
#                              groups side by side (ages 0-41 or 0-42 | the rest, split varies)
#   The department of each section is the large heading of its first page (read on the
#   page images: Antioquia, Atlantico, Bogota D.E., Bolivar, Boyaca, Caldas, Cauca, Cesar,
#   Cordoba, Choco, Cundinamarca, Huila, La Guajira, Magdalena, Meta, Narino, Norte de
#   Santander, Quindio, Risaralda, Santander, Sucre, Tolima, Valle del Cauca).
# Not extracted: Cuadros 3 onward of each section (literacy, schooling, activity,
# children ever born), the 9 city sections (pp. 326-428) and Cuadro 3A (marital status).
#
# Method
#   1. The text layer is read once with pdftools::pdf_data and cached. Numbers are right-
#      aligned: the right edges of the numeric tokens are clustered into columns, lines
#      are clusters of the vertical centres. Cuadro 2 has two groups of columns; both end
#      on the last line (85+) and the split of the ages between them varies by page, so
#      the first line of the right-hand group fixes which line holds which age. A cell is
#      read only if its text is a well formed number; otherwise it stays empty.
#   2. 7,824 cells are tied by 4,579 linear identities: total = men + women in every row;
#      ages (or age groups) add up to the TOTAL row; Cuadro 1 header = Cuadro 2 header;
#      Cuadro 1 age groups = their single ages of Cuadro 2; national total = cabecera +
#      resto; national = the 23 sections added (every single age and age group, 3 sexes).
#      Every cell is in 3-6 identities. A cell is also a multiple of 25 (28 in Bogota).
#   3. 174 cells of the text layer are wrong or empty (ocr_support/corrections_1973_muestra.csv):
#      each takes the value that two or more identities ask for and was compared with a
#      300 dpi crop of the page (find_corrections <- TRUE proposes them). Each repairs 3 to
#      5 identities. One is a misprint of the print (Boyaca, age 56, total).
#   4. The identities that fail in the print, text layer repaired, are listed in
#      ocr_support/source_inconsistencies_1973_muestra.csv (4, all that one misprint);
#      the script stops if the failing set differs from the list. After the correction of
#      the misprint all 4,579 hold.
#   5. The national single ages of the muestra are compared with census1973_single_age_sex.csv
#      (the complete count) in ocr_support/compare_1973_census_vs_muestra_single_age.csv.
#
# output: data_input/historical/census_tables/
#           census_1973_muestra_single_age_sex_dept.csv  cod_dpto, department, sex, age, age_start, population
#           census_1973_muestra_age5_sex_dept.csv        census_year, unit, cod_dpto, unit_type, zone, age, age_start, male, female, total
#         data_input/historical/census_tables/ocr_support/
#           corrections_1973_muestra.csv, source_inconsistencies_1973_muestra.csv,
#           compare_1973_census_vs_muestra_single_age.csv
#         (word-box cache in data_inter/, not versioned)
# runtime: about 10 seconds (the first run also reads the PDF to build the cache; the PDF is not needed afterwards).
# -------------------------------------------------------------------------------
suppressMessages(library(tidyverse))
options(width = 200)

pdf <- "data_input/dane_pdfs/censos/1973/LD_1007_1973_EJ_4.pdf"
out <- "data_input/historical/census_tables/"
sup <- paste0(out, "ocr_support/")
cache <- "data_inter/censo_1973_muestra_words.rds"
find_corrections <- FALSE      # TRUE: propose the corrections list from the identities (data_inter/corrections_1973_muestra_proposed.csv) and stop
dir.create("data_inter", showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1. units and pages ====
# ---------------------------------------------------------------------------
units <- c("Antioquia", "Atlántico", "Bogotá D.E.", "Bolívar", "Boyacá", "Caldas", "Cauca", "Cesar", "Córdoba", "Chocó", "Cundinamarca", "Huila",
           "La Guajira", "Magdalena", "Meta", "Nariño", "Norte de Santander", "Quindío", "Risaralda", "Santander", "Sucre", "Tolima", "Valle del Cauca")
divi <- read_csv("data_input/reference/DIVIPOLA-_Códigos_municipios_20260307.csv", show_col_types = FALSE) |>
  transmute(cod = `Código Departamento`, name = `Nombre Departamento`) |> distinct()
norm <- \(x) toupper(gsub("[^A-Za-z]", "", iconv(sub(",.*", "", x), to = "ASCII//TRANSLIT")))
cod_of <- \(u) divi$cod[match(norm(sub(" D\\.E\\.$", "", u)), norm(divi$name))]
cod <- c("Total departamentos" = "00", setNames(map_chr(units, cod_of), units))
stopifnot(!anyNA(cod), length(unique(cod)) == 24)
NAT <- "Total departamentos"
page1 <- \(k) 72L + 11L * k      # Cuadro 1 of section k (k = 0..22)
page2 <- \(k) 73L + 11L * k      # Cuadro 2 of section k
f_exp <- setNames(ifelse(units == "Bogotá D.E.", 28L, 25L), units)

ages5 <- c("<1", "1-4", paste(seq(5, 80, 5), seq(9, 84, 5), sep = "-"), "85+")
stopifnot(length(ages5) == 19)
age5_start <- c(0L, 1L, seq(5L, 85L, 5L))
ages1 <- c(as.character(0:84), "85+")

# ---------------------------------------------------------------------------
# 2. text layer (cached) ====
# ---------------------------------------------------------------------------
need <- sort(c(40L, 41L, page1(0:22), page2(0:22)))
if (!file.exists(cache)) {
  stopifnot(file.exists(pdf))
  wl <- pdftools::pdf_data(pdf)
  stopifnot(length(wl) == 425)
  write_rds(map(set_names(wl[need], need), identity), cache, compress = "gz")
}
W <- read_rds(cache)
# the page of each Cuadro: titles "Poblacion por sexo, segun grupos de edad" (Cuadro 1) and "... segun edades simples" (Cuadro 2)
top_words <- \(p) tolower(paste(W[[as.character(p)]]$text[W[[as.character(p)]]$y < 70], collapse = " "))
stopifnot(all(grepl("grupos", map_chr(page1(0:22), \(p) tolower(paste(W[[as.character(p)]]$text[W[[as.character(p)]]$y < 240], collapse = " "))))),
          all(grepl("simples", map_chr(page2(0:22), top_words))), grepl("simples", top_words(41L)), grepl("zona", top_words(40L)))

has_digit <- \(t) grepl("[0-9]", t)
# a cell is the tokens of one line that fall in one column; its value is read only if the text is a well formed
# number (thousands separators ., or space) with no letters: anything else is left NA for the identities
cell_value <- function(txt) {
  s <- gsub("[^0-9., ]", "", txt); s <- trimws(gsub("[., ]+$|^[., ]+", "", s)); s <- gsub(" ", ".", s)
  ok <- !grepl("[A-Za-z]", txt) & grepl("^[0-9]{1,3}([.,][0-9]{3})*$", s)
  ifelse(ok, suppressWarnings(as.integer(gsub("[.,]", "", s))), NA_integer_)
}
# masculinity index: two decimals, kept in hundredths
index_value <- function(txt) { s <- gsub("[^0-9.,]", "", txt); ifelse(!grepl("[A-Za-z]", txt) & grepl("^[0-9]{2,3}[.,][0-9]{2}$", s), suppressWarnings(as.integer(gsub("[.,]", "", s))), NA_integer_) }
# grid of a page: K numeric columns (right-aligned: clusters of the right edges of the numeric tokens, the K rightmost
# or the ones given), the last nrows lines; label columns are dropped by the caller
read_grid <- function(p, nrows, cols = NULL, K = NULL, min_n = 12, xlim = c(0, 1e4), ylim = c(0, 1e4), labels = FALSE) {
  d <- W[[as.character(p)]] |> mutate(xr = x + width, yc = y + height / 2) |>
    filter(has_digit(text), height <= 9, xr >= xlim[1], xr <= xlim[2], yc >= ylim[1], yc <= ylim[2]) |> arrange(yc)
  d$row <- cumsum(c(1, diff(d$yc) > 3)); d <- d |> filter(row > max(row) - nrows) |> mutate(row = row - min(row) + 1L)
  e <- sort(d$xr); cl <- cumsum(c(1, diff(e) > 12))
  cc <- tibble(e, cl) |> group_by(cl) |> summarise(c = median(e), n = n(), .groups = "drop") |> filter(n >= min_n) |> pull(c)
  if (!is.null(K)) cc <- tail(cc, K)
  if (!is.null(cols) && length(cc) != cols) stop(sprintf("page %d: %d columns found, %d expected (%s)", p, length(cc), cols, paste(round(cc), collapse = " ")))
  if (max(d$row) != nrows) stop(sprintf("page %d: %d rows found, %d expected", p, max(d$row), nrows))
  # tokens more than 45 pt from every column are row labels: dropped, or kept as column 0 (left labels) when asked
  ry <- d |> group_by(row) |> summarise(yc = mean(yc), .groups = "drop")      # vertical centre of each line, for the review crops
  d <- d |> mutate(col = map_int(xr, \(e) which.min(abs(cc - e))), dist = abs(xr - cc[col]))
  d <- if (labels) d |> mutate(col = if_else(dist >= 45 & xr < cc[1], 0L, col)) |> filter(dist < 45 | col == 0L) else d |> filter(dist < 45)
  d |> arrange(row, x) |> group_by(row, col) |> summarise(raw = paste(text, collapse = " "), v = cell_value(paste(text, collapse = " ")), .groups = "drop") |>
    complete(row = 1:nrows, col = if (labels) 0:length(cc) else seq_along(cc)) |> left_join(ry, by = "row") |> mutate(page = p, xc = c(NA, cc)[col + 1L])
}

# ---------------------------------------------------------------------------
# 3. read the pages into one table of cells ====
# ---------------------------------------------------------------------------
MEAS <- c("t", "h", "m")
# Cuadro 2 layout (department sections and p. 41): the line TOTAL, then the single ages in two groups side by side. Both groups end
# on the last line (right-hand group: 85+, so line r holds age r + 41); the left group starts after the blank line under TOTAL and
# the right-hand group on line r_fr (1 or 2: ages 42-85+ or 43-85+), so the split of the ages between the groups varies by page
read_c2 <- function(p, unit) {
  g <- read_grid(p, 44, K = 7, min_n = 15, labels = TRUE)     # cols: 0 left age label | 1-3 T H M | 4 right age label | 5-7 T H M
  r_fr <- min(g$row[g$col >= 4 & !is.na(g$raw)])
  n_left <- 41L + r_fr
  stopifnot(r_fr %in% 1:3)
  r_l <- 44L - n_left + 1L                                   # first line of the left group (age 0)
  chk <- bind_rows(g |> filter(col == 4, !is.na(v)) |> transmute(row, lab = v, age = row + 41L),
                   g |> filter(col == 0, row >= r_l + 2L, !is.na(v)) |> transmute(row, lab = v, age = row - r_l)) |> filter(lab != age)
  if (nrow(chk)) cat(sprintf("page %d: %d age labels differ from the line order (lines %s)\n", p, nrow(chk), paste(chk$row, collapse = ",")))
  bind_rows(g |> filter(col %in% 1:3, row >= r_l) |> transmute(key = ages1[row - r_l + 1L], meas = MEAS[col], raw, v, yc, xc),
            g |> filter(col >= 5, row >= r_fr) |> transmute(key = ages1[row + 41L + 1L], meas = MEAS[col - 4L], raw, v, yc, xc),
            g |> filter(col %in% 1:3, row == 1) |> transmute(key = "total", meas = MEAS[col], raw, v, yc, xc)) |>
    mutate(unit = unit, page = p, tbl = "c2", zone = "total", n_left = n_left, .before = 1)
}
# Cuadro 1 layout of the sections: header row TOTAL, 19 age groups; columns total, men, women, masculinity index
read_c1 <- function(p, unit) {
  g <- read_grid(p, 20, K = 4, min_n = 15)
  g |> transmute(key = if_else(row == 1, "total", ages5[pmax(row - 1L, 1L)]), meas = c("t", "h", "m", "i")[col], raw, v, yc, xc) |>
    mutate(unit = unit, page = p, tbl = "c1", zone = "total", .before = 1)
}
C <- bind_rows(map_dfr(0:22, \(k) bind_rows(read_c1(page1(k), units[k + 1]), read_c2(page2(k), units[k + 1]))),
               read_c2(41L, NAT))
# Cuadro 1 national (p. 40): three blocks (total, cabecera, resto), 20 lines each; the first block has no right-hand copy
gL <- read_grid(40, 40, cols = 4, xlim = c(120, 330), min_n = 18)      # total block (rows 1-20) and cabecera block (21-40)
gR <- read_grid(40, 20, cols = 4, xlim = c(400, 1e4), min_n = 15)       # resto block, on the lines of the cabecera block
c1n <- bind_rows(
  gL |> filter(row <= 20) |> mutate(zone = "total", r = row),
  gL |> filter(row > 20) |> mutate(zone = "cabecera", r = row - 20L),
  gR |> mutate(zone = "resto", r = row)) |>
  transmute(unit = NAT, page = 40L, tbl = "c1", zone, key = if_else(r == 1, "total", ages5[pmax(r - 1L, 1L)]), meas = c("t", "h", "m", "i")[col], raw, v, yc, xc)
C <- bind_rows(C, c1n) |> mutate(v = if_else(meas == "i", index_value(raw), v)) |> mutate(cod_dpto = cod[unit], id = paste(tbl, unit, zone, key, meas, sep = "|"), v_read = v, .after = unit)
stopifnot(!anyDuplicated(C$id))
cat(sprintf("cells read: %d; with no readable value: %d\n", nrow(C), sum(is.na(C$v))))

# ---------------------------------------------------------------------------
# 4. identities ====
# ---------------------------------------------------------------------------
# every identity is a linear form  sum(coef * cell) = 0  over the cells of C
grp5 <- c(`0` = "<1", set_names(rep("1-4", 4), 1:4), set_names(rep(ages5[3:18], each = 5), 5:84), `85+` = "85+")
stopifnot(length(grp5) == 86)
idents <- bind_rows(
  # total = men + women, in every row of every table
  C |> filter(meas %in% MEAS) |> transmute(iid = paste("row", tbl, unit, zone, key, sep = "|"), id, coef = if_else(meas == "t", 1L, -1L)),
  # the age rows add up to the TOTAL row
  C |> filter(meas %in% MEAS) |> transmute(iid = paste("col", tbl, unit, zone, meas, sep = "|"), id, coef = if_else(key == "total", -1L, 1L)),
  # Cuadro 1 header = Cuadro 2 header
  C |> filter(meas %in% MEAS, key == "total", zone == "total") |> transmute(iid = paste("hdr", unit, meas, sep = "|"), id, coef = if_else(tbl == "c1", 1L, -1L)),
  # Cuadro 1 age groups = the single ages of the group in Cuadro 2
  C |> filter(meas %in% MEAS, tbl == "c2", key != "total") |> transmute(iid = paste("grp", unit, grp5[key], meas, sep = "|"), id, coef = -1L),
  C |> filter(meas %in% MEAS, tbl == "c1", key != "total", zone == "total") |> transmute(iid = paste("grp", unit, key, meas, sep = "|"), id, coef = 1L),
  # national: total = cabecera + resto
  C |> filter(meas %in% MEAS, tbl == "c1", unit == NAT) |> transmute(iid = paste("zone", key, meas, sep = "|"), id, coef = if_else(zone == "total", 1L, -1L)),
  # national = sum of the 23 sections (single ages, and 5-year groups of the total zone)
  C |> filter(meas %in% MEAS, zone == "total") |>
    transmute(iid = paste("dept", tbl, key, meas, sep = "|"), id, coef = if_else(unit == NAT, 1L, -1L))
) |> filter(!is.na(iid))
idents <- idents |> group_by(iid) |> filter(n() > 1) |> ungroup()
cat(sprintf("identities: %d, over %d cells\n", n_distinct(idents$iid), n_distinct(idents$id)))

# ---------------------------------------------------------------------------
# 5. residuals of the identities and the values they imply ====
# ---------------------------------------------------------------------------
nC <- nrow(C)
E <- idents |> mutate(g = match(iid, unique(iid)), cix = match(id, C$id)) |> select(g, cix, coef)
G <- length(unique(E$g)); giid <- unique(idents$iid)
fvec <- ifelse(C$unit == NAT, 1L, f_exp[C$unit])
# a cell is suspect when it is unreadable or not a multiple of the expansion factor of its department
suspect <- function(vals) is.na(vals) | (!is.na(vals) & vals %% fvec != 0)
residuals_of <- function(vals) {
  v <- vals[E$cix]
  tibble(g = seq_len(G), res = as.vector(rowsum(E$coef * ifelse(is.na(v), 0, v), E$g)), nna = as.vector(rowsum(as.integer(is.na(v)), E$g)))
}
solve_cells <- function(vals, maxit = 30) {
  log <- list()
  for (it in seq_len(maxit)) {
    rs <- residuals_of(vals); R <- rs[E$g, ]; v <- vals[E$cix]
    holds <- rs$nna == 0 & rs$res == 0
    n_ok <- tapply(holds[E$g], E$cix, sum); n_ok <- replace(rep(0, nC), as.integer(names(n_ok)), n_ok)
    im <- E |> mutate(res = R$res, nna = R$nna, v = v) |> filter((nna == 0 & res != 0) | (nna == 1 & is.na(v))) |>
      mutate(imp = ifelse(nna == 0, v - res / coef, -res / coef)) |>
      filter(imp >= 0, imp == round(imp), imp %% fvec[cix] == 0)
    votes <- im |> count(cix, imp, name = "votes") |> mutate(sus = suspect(vals)[cix], n_ok = n_ok[cix])
    acc <- votes |> filter(sus | (n_ok == 0 & votes >= 2)) |> group_by(cix) |> arrange(desc(votes), .by_group = TRUE) |>
      filter(n() == 1 | votes[1] > votes[2]) |> slice(1) |> ungroup() |> filter(is.na(vals[cix]) | imp != vals[cix])
    if (!nrow(acc)) break
    log[[length(log) + 1]] <- acc |> mutate(from = vals[cix], round = it)
    vals[acc$cix] <- acc$imp
  }
  list(vals = vals, log = bind_rows(log), rs = rs)
}


# ---------------------------------------------------------------------------
# 6. corrections ====
# ---------------------------------------------------------------------------
# What the text layer got wrong (a digit read as another, a digit missing, a cell left out) is listed in
# ocr_support/corrections_1973_muestra.csv: one row per cell with the text-layer reading, the value, and the kind:
#   misread         the text layer has a well formed number that is not the printed one (5 for 6, a stray digit, ...)
#   unreadable      the text layer has no usable number (garbled, split, or the token is missing; a dash is a zero)
#   print_misprint  the PRINTED cell disagrees with four identities (Boyaca, age 56, total: printed 5.550, men + women 4.550)
# Each cell was compared with a 300 dpi crop of the page. find_corrections = TRUE proposes the list: a cell that is
# unreadable or not a multiple of the expansion factor takes the value that an identity asks for; a readable cell whose
# identities all fail takes the value that two or more of them ask for. The proposals are then checked by eye.
isI <- C$meas == "i"
corr_file <- paste0(sup, "corrections_1973_muestra.csv")
incons_file <- paste0(sup, "source_inconsistencies_1973_muestra.csv")
tbl_name <- c(c1 = "Cuadro 1", c2 = "Cuadro 2"); sex_name <- c(t = "total", h = "male", m = "female", i = "index")
cell_table <- function(ix) C[ix, ] |> transmute(table = tbl_name[tbl], page, unit, cod_dpto, zone, age = key, sex = sex_name[meas], text_layer = raw)
if (find_corrections) {
  sol <- solve_cells(replace(C$v_read, isI, 0L))
  p0 <- sol$log |> group_by(cix) |> summarise(value_read = first(from), value = last(imp), votes = last(votes), .groups = "drop")
  prop <- bind_cols(cell_table(p0$cix), p0 |> select(value_read, value, votes)) |> arrange(page, unit, age, sex)
  write_csv(prop, "data_inter/corrections_1973_muestra_proposed.csv", na = "")
  cat(sprintf("proposed: %d cells (%d unreadable, %d misread); identities failing afterwards: %d\n", nrow(prop), sum(is.na(prop$value_read)), sum(!is.na(prop$value_read)),
              sum(sol$rs$nna > 0 | sol$rs$res != 0)))
  stop("find_corrections: proposals in data_inter/corrections_1973_muestra_proposed.csv")
}
corr <- read_csv(corr_file, col_types = cols(.default = col_character()), na = "") |> mutate(page = as.integer(page), value_read = as.integer(value_read), value = as.integer(value))
corr <- corr |> mutate(id = paste(c(`Cuadro 1` = "c1", `Cuadro 2` = "c2")[table], unit, zone, age, c(total = "t", male = "h", female = "m")[sex], sep = "|"))
stopifnot(!anyDuplicated(corr$id), all(corr$id %in% C$id), all(corr$kind %in% c("misread", "unreadable", "print_misprint")))
ix <- match(corr$id, C$id)
stopifnot(identical(C$page[ix], corr$page), identical(coalesce(C$raw[ix], ""), coalesce(corr$text_layer, "")),
          identical(C$v_read[ix], corr$value_read))       # the corrections list refers to this reading of the text layer
vals_printed <- C$v_read; vals_printed[ix[corr$kind != "print_misprint"]] <- corr$value[corr$kind != "print_misprint"]   # the print, text layer repaired
vals <- vals_printed; vals[ix] <- corr$value                                                                              # and its misprint corrected
cat(sprintf("corrections: %d cells of %d (%d unreadable in the text layer, %d misread, %d misprint of the print)\n", nrow(corr), sum(!isI),
            sum(corr$kind == "unreadable"), sum(corr$kind == "misread"), sum(corr$kind == "print_misprint")))

# ---------------------------------------------------------------------------
# 7. identities ====
# ---------------------------------------------------------------------------
type_of <- \(x) sub("\\|.*", "", x)
rs_p <- residuals_of(replace(vals_printed, isI, 0L)) |> mutate(iid = giid[g])
rs <- residuals_of(replace(vals, isI, 0L)) |> mutate(iid = giid[g])
stopifnot(!anyNA(vals[!isI]), !any(rs$nna > 0), !any(rs_p$nna > 0))
cat("\nidentities, by type (failing in the print as corrected for the text layer / after the correction of the misprint):\n")
print(left_join(rs_p |> mutate(type = type_of(iid)) |> group_by(type) |> summarise(n = n(), failing_print = sum(res != 0), .groups = "drop"),
                rs |> mutate(type = type_of(iid)) |> group_by(type) |> summarise(failing_final = sum(res != 0), .groups = "drop"), by = "type"))
# every corrected cell: how many identities fail with the text-layer reading and hold with the value
fixed <- map_int(seq_along(ix), \(i) { gs <- E$g[E$cix == ix[i]]
  v1 <- vals; v1[ix[i]] <- C$v_read[ix[i]]; v1 <- replace(v1, isI, 0L)
  r1 <- residuals_of(v1); sum((r1$res[gs] != 0 | r1$nna[gs] > 0) & rs$res[gs] == 0) })
cat(sprintf("identities that a correction repairs: min %d, median %g, max %d; corrections repairing only one identity: %d\n", min(fixed), median(fixed), max(fixed), sum(fixed == 1)))
# every population cell of a department is a multiple of its expansion factor
dv <- C |> mutate(v = vals) |> filter(unit != NAT, meas %in% MEAS, v %% f_exp[unit] != 0)
cat(sprintf("population cells of the departments that are not a multiple of the expansion factor (1/25, Bogota 1/28): %d\n", nrow(dv)))
# masculinity index of Cuadro 1 = 100 men / women, two decimals; the printed index is read from the text layer and is a check only
ix_chk <- C |> mutate(v = vals) |> filter(tbl == "c1") |> select(unit, zone, key, meas, v) |> pivot_wider(names_from = meas, values_from = v) |>
  mutate(calc = round(1e4 * h / m), diff = i - calc)
cat(sprintf("masculinity index: %d printed, %d readable, %d agree with 100 H / M within 0.01, %d differ (text-layer misreads of a check column, not corrected)\n",
            nrow(ix_chk), sum(!is.na(ix_chk$i)), sum(abs(ix_chk$diff) <= 1, na.rm = TRUE), sum(abs(ix_chk$diff) > 1, na.rm = TRUE)))
fail_p <- rs_p |> filter(res != 0) |> transmute(identity = iid, residual = res) |> arrange(identity)
if (!file.exists(incons_file)) { print(fail_p); stop("source inconsistencies not listed yet: ", incons_file) }
listed <- read_csv(incons_file, show_col_types = FALSE) |> arrange(identity)
if (!identical(fail_p$identity, listed$identity) || !identical(as.numeric(fail_p$residual), as.numeric(listed$residual))) {
  print(fail_p); print(listed); stop("the identities that fail in the print differ from ", incons_file)
}
stopifnot(all(rs$res == 0))
cat(sprintf("failing identities in the print: %d, all listed in source_inconsistencies_1973_muestra.csv; none after the correction of the misprint (%d identities, %d cells)\n",
            nrow(fail_p), nrow(rs), sum(!isI)))
C$v <- vals

# ---------------------------------------------------------------------------
# 8. output files ====
# ---------------------------------------------------------------------------
unit_order <- c(NAT, units)
sex_long <- c(male = "h", female = "m", total = "t")
# single ages: long, one row per section x sex x age (the national block is the 23 sections added)
o1 <- C |> filter(tbl == "c2", key != "total", meas %in% MEAS) |>
  transmute(cod_dpto, department = unit, sex = names(sex_long)[match(meas, sex_long)], age = key, age_start = as.integer(sub("\\+", "", key)), population = v) |>
  arrange(match(department, unit_order), match(sex, names(sex_long)), age_start)
stopifnot(nrow(o1) == 24 * 3 * 86, !anyNA(o1$population))
# 5-year age groups: same layout as census1964_dept_age5_sex_zone.csv, with cod_dpto added (zones only for the national block)
o5 <- C |> filter(tbl == "c1", meas %in% MEAS) |> select(unit, cod_dpto, zone, key, meas, v) |> pivot_wider(names_from = meas, values_from = v) |>
  transmute(census_year = 1973L, unit, cod_dpto, unit_type = case_when(unit == NAT ~ "total", unit == "Bogotá D.E." ~ "distrito especial", TRUE ~ "departamento"),
            zone, age = key, age_start = c(setNames(age5_start, ages5), total = NA_integer_)[key], male = h, female = m, total = t) |>
  arrange(match(unit, unit_order), match(zone, c("total", "cabecera", "resto")), match(age, c("total", ages5)))
stopifnot(nrow(o5) == 20 * (24 + 2), identical(o5$total, o5$male + o5$female))
write_csv(o1, paste0(out, "census_1973_muestra_single_age_sex_dept.csv"))
write_csv(o5, paste0(out, "census_1973_muestra_age5_sex_dept.csv"), na = "")
cat(sprintf("\nwritten: census_1973_muestra_single_age_sex_dept.csv (%d rows), census_1973_muestra_age5_sex_dept.csv (%d rows)\n", nrow(o1), nrow(o5)))

# ---------------------------------------------------------------------------
# 9. comparison with the national census table already in the folder ====
# ---------------------------------------------------------------------------
# census1973_single_age_sex.csv is the complete count of the whole country (departamentos, intendencias, comisarias, armed
# forces; Cuadro 2 of the resumen nacional, 20,666,920 censused); the muestra covers the 23 sections only
cen <- read_csv(paste0(out, "census1973_single_age_sex.csv"), show_col_types = FALSE) |>
  mutate(age = if_else(age_start >= 85, "85+", as.character(age_start))) |> group_by(age) |> summarise(across(c(male, female, total), sum), .groups = "drop")
mu <- o1 |> filter(department == NAT) |> select(age, sex, population) |> pivot_wider(names_from = sex, values_from = population)
cmp <- left_join(cen, mu, by = "age", suffix = c("_census", "_muestra")) |> arrange(match(age, ages1)) |>
  mutate(diff_total = total_muestra - total_census, ratio_total = total_muestra / total_census, diff_male = male_muestra - male_census, diff_female = female_muestra - female_census,
         ratio_male = male_muestra / male_census, ratio_female = female_muestra / female_census)
stopifnot(nrow(cmp) == 86, sum(cmp$total_census) == 20666920, sum(cmp$total_muestra) == 19735286)
write_csv(cmp |> mutate(across(starts_with("ratio"), \(x) round(x, 4))), paste0(sup, "compare_1973_census_vs_muestra_single_age.csv"))
cat(sprintf("national total: census %s, muestra %s (%s, %.1f%% of the census)\n", format(sum(cmp$total_census), big.mark = ","), format(sum(cmp$total_muestra), big.mark = ","),
            format(sum(cmp$diff_total), big.mark = ","), 100 * sum(cmp$total_muestra) / sum(cmp$total_census)))
grp_cmp <- cmp |> mutate(g = factor(grp5[age], levels = ages5)) |> group_by(g) |> summarise(across(c(total_census, total_muestra), sum), .groups = "drop") |>
  mutate(diff = total_muestra - total_census, pct = round(100 * diff / total_census, 1))
cat("muestra minus census, by 5-year group (total):\n"); print(as.data.frame(grp_cmp), row.names = FALSE)
cat(sprintf("share of the muestra in the census, single ages: min %.3f (age %s), max %.3f (age %s); sex ratio of the difference: men %s, women %s\n",
            min(cmp$ratio_total), cmp$age[which.min(cmp$ratio_total)], max(cmp$ratio_total), cmp$age[which.max(cmp$ratio_total)],
            format(sum(cmp$diff_male), big.mark = ","), format(sum(cmp$diff_female), big.mark = ",")))
# the sections against the coverage-adjusted population of chapter VIII
adj <- read_csv(paste0(out, "census1973_adjusted_population_units.csv"), show_col_types = FALSE) |> filter(zone == "total") |> select(unit, adjusted = total) |> mutate(unit = recode(unit, Valle = "Valle del Cauca"))
dep <- o5 |> filter(age == "total", zone == "total", unit != NAT) |> select(unit, muestra = total) |> left_join(adj, by = "unit") |> mutate(ratio = round(muestra / adjusted, 3))
cat("\nmuestra / adjusted population, by department (lowest five):\n"); print(as.data.frame(dep |> arrange(ratio) |> head(5)), row.names = FALSE)
stopifnot(all(dep$ratio > 0.4 & dep$ratio < 1.05))     # a section assigned to the wrong department would break this
cat(sprintf("23 sections: muestra %s, adjusted %s (%.1f%%)\n", format(sum(dep$muestra), big.mark = ","), format(sum(dep$adjusted), big.mark = ","), 100 * sum(dep$muestra) / sum(dep$adjusted)))
cat("done\n")
