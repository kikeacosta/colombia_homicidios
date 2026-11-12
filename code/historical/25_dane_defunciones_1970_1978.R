# 25_dane_defunciones_1970_1978.R -----------------------------------------------
# DANE / UNICEF, "Registro de defunciones en Colombia, 1970-1978", 472 pp.,
# typeset. Library scan with an OCR text layer:
# data_input/dane_pdfs/vitales/LD_8789_1970_1978_EJ_3.pdf (not versioned).
#
# Tables extracted (pdf pages)
#   Cuadro 1  (p. 5)        registered deaths, national, 1915-1984
#   Cuadro 2  (pp. 6-8)     deaths by sex and sección del país, 1970-1984
#   Cuadro 3  (pp. 9-17)    national deaths by zone, sex and age group, 1970-1978
#   Cuadro 6  (pp. 35-336)  national deaths by age group, sex and cause (ICD-8
#                           list A, "150 causas"), 1973-1978
#   Cuadro 10 (pp. 364-390) deaths under five by detailed age and sex, by
#                           sección, 1970-1978
#   Cuadro 11 (pp. 391-471) deaths by sex and age group, national and by
#                           sección, 1970-1978
# Not extracted: Cuadros 4-5 and 7-9 (marital status, medical certification
# and zone by sección).
#
# The secciones are 22 departments, Bogotá D.E. and "Intendencias y
# comisarías" pooled in one row (24 units; Cuadro 2 adds Caquetá, printed as a
# dash until 1981). Age groups as printed: under 1 day, 1-6 days, 7-29 days,
# 1-5 and 6-11 months, 12-23 months, 2-4 years, 5-9 ... 80-84, 85+, not stated.
#
# Method
#   1. The text layer is read once with pdftools::pdf_data and cached. Words
#      are grouped in lines by the vertical centre of their boxes; each number
#      goes to the column whose right edge is nearest (column positions are the
#      clusters of the right edges of the numbers and of the dashes that stand
#      for zero). Rows are identified by their order on the page (the labels
#      are too garbled to rely on); years and unit headers are checked against
#      the page order.
#   2. Cuadro 6 is printed in sets of pages: the causes of a set with the ages
#      under 35 (13 ages + "Total general"), then the same causes with the ages
#      35 and over (12 ages + "Total general"). Lines are classed as cause
#      header (code + name), data (Hombres, Mujeres, Total) or text. A row of
#      one-digit numbers often comes out of the text layer as one run-together
#      token ("4371131211-1"): with one character per column it is split by
#      column; a longer run is accepted when it spells what the other two lines
#      of the cause ask for; a "Total general" missing in one half is taken
#      from the other half.
#   3. All cells go into one table with the accounting identities that tie
#      them: total = men + women; age rows = TOTAL row; secciones = national
#      total; urban + rural = total; the sub-totals of Cuadro 10; in Cuadro 6
#      the ages of both halves = Total general, Total general equal in both
#      halves, causes = TOTAL NACIONAL; and between tables Cuadro 11 = Cuadro 2
#      = Cuadro 1 (totals), Cuadro 3 = Cuadro 11 (national), Cuadro 10 =
#      Cuadro 11 (under five), Cuadro 6 TOTAL NACIONAL = Cuadro 3. Every cell
#      outside Cuadro 1 is in at least two identities. A cell is corrected only
#      when none of its identities holds and at least two of them ask for the
#      same value; this is repeated until nothing changes.
#   4. What the identities could not settle was read by eye on page renders
#      (support/corrections.csv, cuadro6_codes.csv). Every cell the identities
#      corrected was then compared by eye with a crop of the page: 126 are
#      misreadings of the text layer and 20 are misprints, smudges or blanks of
#      the print itself (support/misprints_in_source.csv; e.g. Valle 1979
#      printed 4.818 for 14.818). Cuadro 1, which has no internal identity,
#      was read against the page (one text-layer error, 1982).
#   5. The identities that still fail are inconsistencies of the printed
#      source and are left as printed. They are listed, one line per identity,
#      in support/source_inconsistencies.csv, and the script stops if the
#      failing set differs from that list:
#        - Cuadro 11, Intendencias y comisarías, 1973, 1976 and 1977: the age
#          rows differ from Cuadro 10 and the secciones do not add up to the
#          national row (the block adds up to its own TOTAL, which is right);
#        - Cuadro 6, 1977: for nine causes (055, 064, 069, 070, 081, 085, 103,
#          117, 121) the Total general exceeds the age detail, 129 deaths in
#          all, while the age columns add up to TOTAL NACIONAL;
#        - Cuadro 6, 1973 and 1976: the causes differ from TOTAL NACIONAL by
#          one death moved between two cells;
#        - Cuadro 1 vs Cuadro 2, 1981: 139.505 vs 139.525.
#      Cuadro 6 lists only causes with deaths (134-139 per year; 001, 011, 024,
#      040, 118, 124 and 150 never appear; 076 Catarata is printed once, 1977,
#      as a block of dashes, and dropped).
#
# output: data_input/historical/dane_defunciones_1970_1978_
#           cuadro01_nacional_1915_1984.csv       year, deaths
#           cuadro02_secciones_sexo_1970_1984.csv year, unit, cod_dpto, total,
#                                                 male, female, mark, mark_note, note
#           cuadro03_nacional_zona_edad.csv       year, zone, age, male, female, total
#           cuadro06_causas_edad_1973_1978.csv    year, cause_code, cause_name, age,
#                                                 male, female, total
#           cuadro10_menores5_secciones.csv       year, unit, cod_dpto, age, male, female, total
#           cuadro11_secciones_edad.csv           year, unit, cod_dpto, age, male, female, total
#         data_input/historical/dane_defunciones_1970_1978_support/
#           manual inputs: corrections.csv, cuadro6_codes.csv,
#             cuadro6_cause_names.csv, misprints_in_source.csv,
#             source_inconsistencies.csv
#           reports: verification_identities.csv, cells_corrected.csv,
#             differences_vs_col_gap_analysis.csv
#         (text cache and state for review crops in data_inter/, not versioned)
# runtime: about 1 minute (2 the first time, to build the text cache from the PDF).
#          The PDF is needed only for that first run.
# -------------------------------------------------------------------------------
suppressMessages({library(tidyverse)})
options(width = 220)

pdf <- "data_input/dane_pdfs/vitales/LD_8789_1970_1978_EJ_3.pdf"
out <- "data_input/historical/dane_defunciones_1970_1978_"
sup <- "data_input/historical/dane_defunciones_1970_1978_support/"
cache <- "data_inter/dane_defunciones_1970_1978_words.rds"
dir.create(sup, showWarnings = FALSE); dir.create("data_inter", showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1. text layer (cached) and reading helpers ====
# ---------------------------------------------------------------------------
if (!file.exists(cache)) {
  stopifnot(file.exists(pdf))
  wl <- pdftools::pdf_data(pdf)
  write_rds(map2_dfr(wl, seq_along(wl), \(d, p) if (nrow(d)) mutate(d, page = p) else NULL), cache, compress = "gz")
}
W <- read_rds(cache) |> mutate(xr = x + width, yc = y + height / 2)
stopifnot(n_distinct(W$page) == 472)
W <- split(W, W$page)

ascii <- \(x) iconv(x, to = "ASCII//TRANSLIT")
has_digit <- \(t) grepl("[0-9]", t)
is_dash <- \(t) grepl("^[-–—_~=]+$", t)
# digits of a cell: thousands dots and stray marks dropped, the usual letter-for-digit confusions undone
to_int <- function(t) { s <- chartr("lIOoSsBZG", "110055826", t); s <- gsub("[^0-9]", "", s); suppressWarnings(as.integer(ifelse(s == "", NA, s))) }

# words of a page with a line number: lines are clusters of the vertical centres of the word boxes
page_lines <- function(p) { d <- W[[as.character(p)]] |> arrange(yc, x); d$row <- cumsum(c(1, diff(d$yc) > 4)); d }
line_text <- function(d) d |> group_by(row) |> arrange(x, .by_group = TRUE) |> summarise(yc = mean(yc), x0 = min(x), txt = paste(text, collapse = " "), .groups = "drop")

# K column positions of a page: clusters of the right edges of the cell tokens (numbers are right-aligned and
# the dashes that stand for zero end where the numbers end); a run of dashes read as one token gives its two ends
col_centres <- function(tok, K, page) {
  e <- c(tok$xr[has_digit(tok$text) | (is_dash(tok$text) & nchar(tok$text) == 1)],
         tok$x[is_dash(tok$text) & nchar(tok$text) > 1] + 6, tok$xr[is_dash(tok$text) & nchar(tok$text) > 1])
  e <- sort(e); cl <- cumsum(c(1, diff(e) > 9))
  cc <- tibble(e, cl) |> group_by(cl) |> summarise(c = median(e), n = n()) |> filter(n >= 2)
  while (nrow(cc) > K) cc <- cc[-which.min(cc$n), ]
  if (nrow(cc) != K) stop(sprintf("page %d: %d column positions found, %d expected (%s)", page, nrow(cc), K, paste(round(cc$c), collapse = " ")))
  sort(cc$c)
}
# grid of a page: the lines with at least min_tok cell tokens to the right of xlim, each number placed in the
# column whose right edge is nearest to its own; tokens sharing a column are joined; a cell without digits is 0
read_grid <- function(p, xlim, K, min_tok = NULL, ylim = c(0, 1e4), data_rows = NULL) {
  d <- page_lines(p) |> filter(yc > ylim[1], yc < ylim[2])
  lt <- line_text(d)
  tok <- d |> filter(xr > xlim, has_digit(text) | is_dash(text))
  if (is.null(data_rows)) {
    n_tok <- tok |> group_by(row) |> summarise(n = sum(ifelse(is_dash(text), nchar(text), 1L)), .groups = "drop")
    rows <- lt |> inner_join(n_tok, by = "row") |> filter(n >= min_tok)
  } else rows <- lt |> filter(row %in% data_rows)       # the caller says which lines are data (Cuadro 6)
  tok <- tok |> filter(row %in% rows$row)
  cc <- col_centres(tok, K, p)
  tok <- tok |> filter(has_digit(text)) |> mutate(col = map_int(xr, \(e) which.min(abs(cc - e))), lo = findInterval(x - 2, cc) + 1L, hi = findInterval(xr + 4, cc),
                                                  is_run = hi - lo >= 1 & grepl("^[0-9-]+$", text)) |> arrange(row, x)
  # a row of one-digit numbers and dashes can come out of the text layer as a single token that spans several
  # columns: with one character per column it is split; otherwise its cells are left to the identities (run_open)
  rt <- tok |> filter(is_run)
  runs <- pmap_dfr(list(rt$row, rt$lo, rt$hi, rt$text), function(row, lo, hi, text) { n <- hi - lo + 1L; open <- nchar(text) != n
    tibble(row, col = lo:hi, raw = if (open) rep(NA_character_, n) else strsplit(text, "")[[1]], run = text, run_k = seq_len(n), run_n = n, run_open = open) })
  cell <- tok |> filter(!is_run) |> group_by(row, col) |> summarise(raw = paste(text, collapse = ""), dx = max(xr) - cc[col[1]], .groups = "drop")
  cell <- if (nrow(runs)) cell |> anti_join(runs, by = c("row", "col")) |> bind_rows(runs) else
    cell |> mutate(run = NA_character_, run_k = NA_integer_, run_n = NA_integer_, run_open = NA)
  lab <- d |> filter(row %in% rows$row, xr <= xlim) |> group_by(row) |> arrange(x, .by_group = TRUE) |> summarise(label = paste(text, collapse = " "), .groups = "drop")
  g <- expand_grid(row = rows$row, col = seq_len(K)) |> left_join(cell, by = c("row", "col")) |> left_join(rows |> select(row, yc), by = "row") |>
    left_join(lab, by = "row") |> mutate(page = p, xc = cc[col], value = coalesce(to_int(raw), 0L), r = match(row, rows$row), label = coalesce(label, ""))
  g |> mutate(run_open = coalesce(run_open, FALSE)) |> select(page, r, col, yc, xc, dx, label, raw, value, run, run_k, run_n, run_open)
}
# the year printed at the top of a page ("1 9 7 3", "19782" with a footnote mark)
page_year <- function(p) {
  lt <- line_text(page_lines(p) |> filter(yc < 150))
  s <- gsub("[^0-9]", "", lt$txt[grepl("^[ ',.]*1[ ]?9[ ]?[78][ ]?[0-9][ ]?[0-9]?[ ',.]*$", lt$txt)])
  if (length(s)) as.integer(substr(s[1], 1, 4)) else NA_integer_
}
check_years <- function(pages, years, what) {
  py <- map_int(pages, page_year); bad <- which(!is.na(py) & py != years)
  cat(sprintf("%s: year read on %d of %d pages; %d differ from the page order%s\n", what, sum(!is.na(py)), length(pages), length(bad),
              if (length(bad)) paste0(" (pages ", paste(pages[bad], collapse = ", "), ")") else ""))
  invisible(py)
}

ages <- c("under 1 day", "1-6 days", "7-29 days", "1-5 months", "6-11 months", "12-23 months", "2-4", "5-9", "10-14", "15-19", "20-24", "25-29",
          "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80-84", "85+", "not stated")
units24 <- c("Antioquia", "Atlántico", "Bogotá D.E.", "Bolívar", "Boyacá", "Caldas", "Cauca", "Cesar", "Córdoba", "Cundinamarca", "Chocó", "Huila",
             "La Guajira", "Magdalena", "Meta", "Nariño", "Norte de Santander", "Quindío", "Risaralda", "Santander", "Sucre", "Tolima",
             "Valle del Cauca", "Intendencias y comisarías")
NAT <- "Total nacional"
sexes <- c("total", "male", "female")

# ---------------------------------------------------------------------------
# 2. Cuadro 1: registered deaths, national, 1915-1984 (p. 5) ====
# ---------------------------------------------------------------------------
lt <- line_text(page_lines(5))
m <- str_match(lt$txt, "^[^0-9]*(19[0-9]{2})\\s+([0-9.]+)\\s+(19[0-9]{2})[ ,.']+([0-9.]+)")
c1 <- bind_rows(tibble(year = as.integer(m[, 2]), deaths = to_int(m[, 3])), tibble(year = as.integer(m[, 4]), deaths = to_int(m[, 5]))) |> filter(!is.na(year)) |> arrange(year)
stopifnot(identical(c1$year, 1915:1984))

# ---------------------------------------------------------------------------
# 3. Cuadro 2: deaths by sex and sección, 1970-1984 (pp. 6-8) ====
# ---------------------------------------------------------------------------
units2 <- c(NAT, units24[1:6], "Caquetá", units24[7:24])
c2 <- map_dfr(6:8, function(p) {
  g <- read_grid(p, 150, 15, 10)
  stopifnot(max(g$r) == 26)
  g |> mutate(table = "c2", unit = units2[r], year = 1970L + (p - 6L) * 5L + (col - 1L) %/% 3L, sex = sexes[(col - 1L) %% 3L + 1L], age = "all")
})
# the row label of the national total is printed on two lines; marks (* and **) are kept as printed on each page
c2_marks <- c2 |> distinct(page, unit, label) |> mutate(mark = str_extract(label, "\\*+"))

# ---------------------------------------------------------------------------
# 4. Cuadro 3: national deaths by zone, sex and age group, 1970-1978 (pp. 9-17) ====
# ---------------------------------------------------------------------------
check_years(9:17, 1970:1978, "Cuadro 3")
c3 <- map_dfr(9:17, function(p) {
  g <- read_grid(p, 200, 9, 6)
  stopifnot(max(g$r) == 26)
  g |> mutate(table = "c3", unit = NAT, year = 1961L + p, zone = c("total", "urban", "rural")[(col - 1L) %/% 3L + 1L], sex = sexes[(col - 1L) %% 3L + 1L], age = c("all", ages)[r])
})

# ---------------------------------------------------------------------------
# 5. Cuadro 11: deaths by sex and age group, national and secciones, 1970-1978 (pp. 391-471) ====
# ---------------------------------------------------------------------------
check_years(391:471, rep(1970:1978, each = 9), "Cuadro 11")
c11 <- map_dfr(391:471, function(p) {
  pos <- (p - 391L) %% 9L; yr <- 1970L + (p - 391L) %/% 9L
  g <- if (pos == 0) read_grid(p, 200, 3, 2, ylim = c(190, 700)) else read_grid(p, 140, 9, 6, ylim = c(185, 700))
  if (max(g$r) != 26) stop(sprintf("Cuadro 11, page %d: %d rows", p, max(g$r)))
  u <- if (pos == 0) rep(NAT, 3) else units24[(3 * pos - 2):(3 * pos)]
  g |> mutate(table = "c11", unit = u[(col - 1L) %/% 3L + 1L], year = yr, sex = sexes[(col - 1L) %% 3L + 1L], age = c("all", ages)[r])
})
# the unit names printed at the head of each page, against the expected order
hd <- map_dfr(setdiff(391:471, seq(391, 471, 9)), function(p) {
  lt <- line_text(page_lines(p) |> filter(yc > 150, yc < 185))
  tibble(page = p, printed = str_squish(str_remove(toupper(ascii(lt$txt[which.max(nchar(lt$txt) * grepl("[A-Z]{4}", lt$txt))])), "^SECCI.N\\s*DEL\\s*PA.S")),
         expected = toupper(ascii(paste(units24[(3 * ((p - 391L) %% 9L) - 2):(3 * ((p - 391L) %% 9L))], collapse = " "))))
}) |> mutate(d = diag(adist(gsub("[^A-Z]", "", printed), gsub("[^A-Z]", "", expected))) - abs(nchar(gsub("[^A-Z]", "", printed)) - nchar(gsub("[^A-Z]", "", expected))))
cat("Cuadro 11: unit headers that do not match the expected order (edit distance beyond the length difference > 4):", sum(hd$d > 4), "\n")
if (any(hd$d > 4)) print(hd |> filter(d > 4))

# ---------------------------------------------------------------------------
# 6. Cuadro 10: deaths under five by detailed age and sex, by sección, 1970-1978 (pp. 364-390) ====
# ---------------------------------------------------------------------------
check_years(364:390, rep(1970:1978, each = 3), "Cuadro 10")
cols10 <- c("under 5", "under 1", ages[1:5], "1-4", ages[6:7])
c10 <- map_dfr(364:390, function(p) {
  pos <- (p - 364L) %% 3L; yr <- 1970L + (p - 364L) %/% 3L
  g <- read_grid(p, 130, 10, 7, ylim = c(195, 745))
  u <- list(c(NAT, units24[1:8]), units24[9:17], units24[18:24])[[pos + 1]]
  if (max(g$r) != 3 * length(u)) stop(sprintf("Cuadro 10, page %d: %d rows, %d expected", p, max(g$r), 3 * length(u)))
  sx <- rep(c("male", "female", "total"), length(u)); if (pos == 0) sx[1:3] <- c("total", "male", "female")
  g |> mutate(table = "c10", unit = rep(u, each = 3)[r], year = yr, sex = sx[r], age = cols10[col])
})

# ---------------------------------------------------------------------------
# 7. Cuadro 6: national deaths by age group, sex and cause (list A), 1973-1978 (pp. 35-336) ====
# ---------------------------------------------------------------------------
# Each year is printed in sets of pages: the causes of a set with the ages under 35 (half A, 13 ages + total)
# and then the same causes with the ages 35 and over (half B, 12 ages + total). A cause is a header line (code and
# name) followed by the lines Hombres, Mujeres, Total; the year closes with a TOTAL NACIONAL block.
c6_years <- rep(1973:1978, times = c(52, 50, 50, 50, 50, 50))
check_years(35:336, c6_years, "Cuadro 6")
lab_like <- function(t) { s <- tolower(gsub("[^A-Za-z]", "", ascii(t))); d <- adist(s, c("hombres", "mujeres", "total")); nchar(s) >= 3 & (d[, 1] <= 3 | d[, 2] <= 3 | d[, 3] <= 2) }
c6_page <- function(p) {
  d <- page_lines(p) |> filter(x >= 60); lt <- line_text(d)     # the page number is printed sideways in the left margin
  h <- max(which((str_count(lt$txt, "\\ba[^ ]{1,3}os\\b") >= 4 | grepl("Causas|sexo|general", lt$txt)) & lt$yc < 165))
  if (!is.finite(h)) stop("Cuadro 6, page ", p, ": column header not found")
  half <- if (any(grepl("Menores|meses", lt$txt[(h - 1):h]))) "A" else "B"
  K <- if (half == "A") 14L else 13L
  y0 <- lt$yc[h] + 5
  # stray marks left of the labels are dropped; the label of a data line is what stands left of the first column
  ln <- d |> filter(yc > y0, !(x < 102 & !grepl("[A-Za-z0-9]", text))) |> group_by(row) |> arrange(x, .by_group = TRUE) |>
    summarise(yc = mean(yc), first = first(text), x0 = first(x), txt = paste(text, collapse = " "), label = paste(text[xr < 165], collapse = ""),
              words = sum(nchar(gsub("[^A-Za-zÀ-ÿ]", "", text[x >= 150])) >= 4), cells = sum((has_digit(text) | is_dash(text)) & xr > 165), .groups = "drop") |>
    mutate(code = if_else(grepl("^[0-9OolIGSB]{3}$", first) & x0 < 102, to_int(first), NA_integer_), tot = grepl("TOTAL\\s*NAC", txt),
           type = case_when(tot ~ "head", !is.na(code) ~ "head",
                            words == 0 & (lab_like(label) | cells >= 3 | (cells > 0 & nchar(gsub("[^A-Za-z]", "", label)) < 4)) ~ "data", TRUE ~ "text")) |> arrange(yc)
  # a block starts at a header, or at a text line that follows data lines (a header whose code the text layer lost)
  seen <- 0L; blk <- integer(nrow(ln)); b <- 0L
  for (i in seq_len(nrow(ln))) {
    if (ln$type[i] == "head" || (ln$type[i] == "text" && (seen > 0 || b == 0))) { b <- b + 1L; seen <- 0L }
    if (ln$type[i] == "data") seen <- seen + 1L
    blk[i] <- b
  }
  ln$block <- blk
  blocks <- ln |> group_by(block) |> summarise(y = first(yc), code = if_else(first(tot), 0L, first(code)), n_data = sum(type == "data"), name = first(txt), .groups = "drop") |>
    filter(n_data > 0 | !is.na(code)) |> mutate(page = p, half = half)
  dl <- ln |> filter(type == "data", block %in% blocks$block) |> group_by(block) |> mutate(k = row_number()) |> ungroup()
  g <- read_grid(p, 165, K, data_rows = dl$row) |> mutate(row_id = dl$row[r]) |> left_join(dl |> select(row_id = row, block, k), by = "row_id")
  list(blocks = blocks, cells = g |> mutate(half = half))
}
c6_raw <- map(35:336, c6_page)
c6_blocks <- map2_dfr(c6_raw, c6_years, \(r, yr) r$blocks |> mutate(year = yr))
cat(sprintf("cells read: Cuadro 2 %d, Cuadro 3 %d, Cuadro 10 %d, Cuadro 11 %d; Cuadro 6: %d cause blocks on 302 pages\n",
            nrow(c2), nrow(c3), nrow(c10), nrow(c11), nrow(c6_blocks)))

# ---------------------------------------------------------------------------
# 8. one table of cells, manual readings ====
# ---------------------------------------------------------------------------
# cause codes the text layer lost or garbled (read on the page render)
code_file <- paste0(sup, "cuadro6_codes.csv")
if (file.exists(code_file)) {
  cf <- read_csv(code_file, show_col_types = FALSE)
  for (i in seq_len(nrow(cf))) {
    k <- which(c6_blocks$page == cf$page[i] & abs(c6_blocks$y - cf$y[i]) <= 4)
    if (length(k) != 1) stop("cuadro6_codes.csv: no single block at page ", cf$page[i], ", y ", cf$y[i])
    c6_blocks$code[k] <- cf$code[i]
  }
}
bad <- c6_blocks |> filter(n_data != 3 | is.na(code) | code > 150)
if (nrow(bad)) { print(bad |> mutate(name = str_sub(name, 1, 60))); stop("Cuadro 6: blocks without three data lines or without a valid code") }
c6 <- map2_dfr(c6_raw, c6_years, \(r, yr) r$cells |> mutate(year = yr)) |> inner_join(c6_blocks |> select(page, block, code), by = c("page", "block"))
# a cause without deaths printed in one half only (1977: 076 Catarata, a block of dashes in the first half) is dropped
lone <- c6_blocks |> group_by(year, code) |> filter(n() == 1) |> ungroup() |> left_join(c6 |> group_by(page, block) |> summarise(s = sum(value), .groups = "drop"), by = c("page", "block"))
if (nrow(lone)) { cat("Cuadro 6: causes printed in one half only:\n"); print(lone |> select(year, half, page, code, name, sum_of_cells = s))
  stopifnot(all(lone$s == 0)); c6_blocks <- c6_blocks |> anti_join(lone, by = c("page", "block")); c6 <- c6 |> anti_join(lone, by = c("page", "block")) }
chk <- c6_blocks |> group_by(year, half) |> summarise(n = n(), dup = anyDuplicated(code), codes = list(sort(code)), .groups = "drop") |>
  pivot_wider(names_from = half, values_from = c(n, dup, codes))
stopifnot(all(chk$dup_A == 0), all(chk$dup_B == 0))
same <- map2_lgl(chk$codes_A, chk$codes_B, identical)
if (!all(same)) { for (i in which(!same)) cat(chk$year[i], ": only in A:", setdiff(chk$codes_A[[i]], chk$codes_B[[i]]), "; only in B:", setdiff(chk$codes_B[[i]], chk$codes_A[[i]]), "\n")
  stop("Cuadro 6: the two halves of a year do not list the same causes") }
c6 <- c6 |>
  mutate(table = "c6", unit = sprintf("%03d", code), sex = c("male", "female", "total")[k],
         age = if_else(half == "A", c(ages[1:13], "all")[col], c(ages[14:25], "all", NA)[col]))
stopifnot(!anyNA(c6$age))
# open runs: the characters are accepted when they spell exactly what the other two lines of the cause ask for
c6$how <- if_else(!is.na(c6$run) & !c6$run_open, "run split by column", "")
open <- c6 |> filter(run_open) |> mutate(lo = col - run_k + 1L) |> distinct(page, block, k, run, lo, run_n)
n_ok <- 0L
for (i in seq_len(nrow(open))) {
  b <- which(c6$page == open$page[i] & c6$block == open$block[i] & c6$col %in% (open$lo[i] + seq_len(open$run_n[i]) - 1L))
  b <- b[order(c6$k[b], c6$col[b])]; M <- matrix(c6$value[b], nrow = 3, byrow = TRUE); k <- open$k[i]
  if (any(c6$run_open[b] & c6$k[b] != k)) next
  e <- if (k == 3) M[1, ] + M[2, ] else M[3, ] - M[3 - k, ]
  if (all(e >= 0) && identical(paste(ifelse(e == 0, "-", e), collapse = ""), open$run[i])) {
    j <- b[c6$k[b] == k]; c6$value[j] <- as.integer(e); c6$run_open[j] <- FALSE; c6$how[j] <- "run split by the sex identity"; n_ok <- n_ok + 1L }
}
cat(sprintf("Cuadro 6: %d cells in runs split by column; %d longer runs, %d of them spelled out by the other two lines\n",
            sum(c6$how == "run split by column"), nrow(open), n_ok))
# the "Total general" is printed in both halves: where the text layer has nothing in one of them, the other is taken
tg <- which(c6$age == "all")
oth <- tg[match(paste(c6$year[tg], c6$unit[tg], c6$sex[tg], if_else(c6$half[tg] == "A", "B", "A")), paste(c6$year[tg], c6$unit[tg], c6$sex[tg], c6$half[tg]))]
lost <- is.na(c6$raw[tg]) & c6$value[tg] == 0 & !is.na(c6$raw[oth]) & c6$value[oth] > 0
c6$value[tg[lost]] <- c6$value[oth[lost]]; c6$how[tg[lost]] <- "total general taken from the other half"
cat("Cuadro 6: totals taken from the other half:", sum(lost), "\n")
cat(sprintf("Cuadro 6: %d cells, causes per year: %s\n", nrow(c6), paste(chk$n_A - 1, collapse = " ")))

cells <- bind_rows(tibble(table = "c1", year = c1$year, unit = NAT, sex = "total", age = "all", page = 5L, raw = as.character(c1$deaths), value = c1$deaths),
                   c2, c3, c10, c11, c6) |>
  mutate(zone = coalesce(zone, ""), half = coalesce(half, ""), id = row_number(), read = value, how = coalesce(how, "")) |>
  select(id, table, year, unit, zone, sex, age, half, page, yc, xc, dx, raw, read, value, how)
stopifnot(!anyDuplicated(cells[c("table", "year", "unit", "zone", "sex", "age", "half")]))

# cells read by eye on the page render: they override the text layer before the identities are applied
cor_file <- paste0(sup, "corrections.csv")
if (file.exists(cor_file)) {
  cor <- read_csv(cor_file, show_col_types = FALSE, col_types = cols(year = "i", value = "i", .default = "c")) |> mutate(across(c(zone, half), \(x) replace_na(x, "")))
  k <- cor |> left_join(cells |> select(table, year, unit, zone, sex, age, half, id), by = c("table", "year", "unit", "zone", "sex", "age", "half"))
  if (anyNA(k$id)) { print(k |> filter(is.na(id))); stop("corrections.csv: rows that match no cell") }
  cells$value[k$id] <- k$value; cells$how[k$id] <- "read on the page render"
  cat("manual readings applied:", nrow(cor), "\n")
}

# ---------------------------------------------------------------------------
# 9. accounting identities ====
# ---------------------------------------------------------------------------
con_of <- function(d, by, type) d |> filter(sgn != 0) |> mutate(type = type, key = do.call(paste, c(list(type), pick(all_of(by)), sep = "|"))) |> select(type, key, id, sgn)
con_eq <- function(a, b, by, type) inner_join(a |> select(all_of(by), ia = id), b |> select(all_of(by), ib = id), by = by) |>
  mutate(type = type, key = do.call(paste, c(list(type), pick(all_of(by)), sep = "|"))) |> pivot_longer(c(ia, ib), values_to = "id") |> mutate(sgn = if_else(name == "ia", 1L, -1L)) |> select(type, key, id, sgn)
cc <- cells
con <- bind_rows(
  # total = men + women, every cell of every table
  cc |> filter(table != "c1") |> mutate(sgn = if_else(sex == "total", 1L, -1L)) |> con_of(c("table", "year", "unit", "zone", "age", "half"), "sexes"),
  # the age rows add up to the TOTAL row (Cuadros 3 and 11)
  cc |> filter(table %in% c("c3", "c11")) |> mutate(sgn = if_else(age == "all", 1L, -1L)) |> con_of(c("table", "year", "unit", "zone", "sex"), "ages"),
  # Cuadro 3: urban + rural = total (a footnote says the total includes deaths without zone; there are none in any cell)
  cc |> filter(table == "c3") |> mutate(sgn = if_else(zone == "total", 1L, -1L)) |> con_of(c("table", "year", "sex", "age"), "zones"),
  # the secciones add up to the national total (Cuadros 2, 10 and 11)
  cc |> filter(table %in% c("c2", "c10", "c11")) |> mutate(sgn = if_else(unit == NAT, 1L, -1L)) |> con_of(c("table", "year", "sex", "age"), "units"),
  # Cuadro 10: under 5 = under 1 + 1-4; under 1 and 1-4 are the sums of their detailed ages
  cc |> filter(table == "c10") |> mutate(sgn = case_when(age == "under 5" ~ 1L, age %in% c("under 1", "1-4") ~ -1L, TRUE ~ 0L)) |> con_of(c("table", "year", "unit", "sex"), "under5"),
  cc |> filter(table == "c10") |> mutate(sgn = case_when(age == "under 1" ~ 1L, age %in% ages[1:5] ~ -1L, TRUE ~ 0L)) |> con_of(c("table", "year", "unit", "sex"), "under1"),
  cc |> filter(table == "c10") |> mutate(sgn = case_when(age == "1-4" ~ 1L, age %in% ages[6:7] ~ -1L, TRUE ~ 0L)) |> con_of(c("table", "year", "unit", "sex"), "age1to4"),
  # Cuadro 6: the 25 ages of the two halves add up to the "Total general", printed in both halves; the causes add up to TOTAL NACIONAL
  cc |> filter(table == "c6") |> mutate(sgn = case_when(age == "all" & half == "A" ~ 1L, age != "all" ~ -1L, TRUE ~ 0L)) |> con_of(c("table", "year", "unit", "sex"), "ages"),
  cc |> filter(table == "c6", age == "all") |> mutate(sgn = if_else(half == "A", 1L, -1L)) |> con_of(c("table", "year", "unit", "sex"), "halves"),
  cc |> filter(table == "c6") |> mutate(sgn = if_else(unit == "000", 1L, -1L)) |> con_of(c("table", "year", "sex", "age", "half"), "causes"),
  # between tables
  con_eq(cc |> filter(table == "c2", unit == NAT, sex == "total"), cc |> filter(table == "c1"), "year", "c2=c1"),
  con_eq(cc |> filter(table == "c11", age == "all"), cc |> filter(table == "c2"), c("year", "unit", "sex"), "c11=c2"),
  con_eq(cc |> filter(table == "c3", zone == "total"), cc |> filter(table == "c11", unit == NAT), c("year", "sex", "age"), "c3=c11"),
  con_eq(cc |> filter(table == "c10"), cc |> filter(table == "c11"), c("year", "unit", "sex", "age"), "c10=c11"),
  con_eq(cc |> filter(table == "c6", unit == "000"), cc |> filter(table == "c3", zone == "total") |> select(-half) |> crossing(half = c("A", "B")), c("year", "sex", "age", "half"), "c6=c3"))
stopifnot(!anyDuplicated(con[c("key", "id")]))
con$con <- as.integer(factor(con$key))
con_info <- con |> distinct(con, type, key) |> arrange(con)
cat(sprintf("identities: %d over %d cells; by type:\n", nrow(con_info), n_distinct(con$id))); print(table(con_info$type))

cells$value <- as.numeric(cells$value)       # run-together digits can exceed the integer range before they are corrected
residuals <- function(v) as.vector(rowsum(con$sgn * v[con$id], con$con))
# A cell is corrected when none of its identities holds and at least two of them ask for the same value
solve_identities <- function(v, max_iter = 500) {
  log <- list()
  for (it in seq_len(max_iter)) {
    res <- residuals(v)[con$con]; viol <- res != 0
    if (!any(viol)) break
    n_sat <- tabulate(con$id[!viol], nbins = length(v))
    cand <- tibble(id = con$id[viol], d = -res[viol] * con$sgn[viol], con = con$con[viol])
    agg <- cand |> count(id, d, name = "n") |> group_by(id) |> mutate(n_viol = sum(n)) |> filter(n >= 2) |> filter(n() == 1) |> ungroup() |>
      filter(n_sat[id] == 0, v[id] + d >= 0) |> arrange(desc(n), id)
    if (!nrow(agg)) break
    used <- integer(); done <- 0L
    for (i in seq_len(nrow(agg))) {
      ci <- cand$con[cand$id == agg$id[i] & cand$d == agg$d[i]]
      if (any(ci %in% used)) next
      log[[length(log) + 1]] <- tibble(id = agg$id[i], from = v[agg$id[i]], to = v[agg$id[i]] + agg$d[i], witnesses = agg$n[i], identities = agg$n_viol[i], iter = it)
      v[agg$id[i]] <- v[agg$id[i]] + agg$d[i]; used <- c(used, ci); done <- done + 1L
    }
    if (!done) break
  }
  list(v = v, log = bind_rows(log))
}
r0 <- residuals(cells$value)
cat(sprintf("before the identities: %d of %d fail\n", sum(r0 != 0), length(r0))); print(table(con_info$type[r0 != 0]))
sol <- solve_identities(cells$value)
cells$value <- sol$v
if (nrow(sol$log)) cells$how[unique(sol$log$id)] <- paste0(cells$how[unique(sol$log$id)], ifelse(cells$how[unique(sol$log$id)] == "", "", "; "), "identities")
r1 <- residuals(cells$value)
cat(sprintf("after the identities: %d cells corrected in %d steps; %d identities still fail\n", n_distinct(sol$log$id), nrow(sol$log), sum(r1 != 0))); print(table(con_info$type[r1 != 0]))
cat("cells whose value differs from the text layer, by table:\n"); print(table(cells$table[cells$read != cells$value]))
fail <- con_info |> mutate(resid = r1) |> filter(resid != 0)
write_rds(list(cells = cells, con = con, con_info = con_info, fail = fail, sol = sol), "data_inter/dane_defunciones_1970_1978_state.rds")   # for review crops (not versioned)

# ---------------------------------------------------------------------------
# 10. assertions and verification reports ====
# ---------------------------------------------------------------------------
# every cell outside Cuadro 1 is covered by at least two identities (Cuadro 1 was read against the page render)
n_con <- tabulate(con$id, nbins = nrow(cells))
stopifnot(all(n_con[cells$table != "c1"] >= 2), all(cells$value >= 0), all(cells$value == round(cells$value)))
# the identities that still fail must be exactly the documented inconsistencies of the printed source
doc <- read_csv(paste0(sup, "source_inconsistencies.csv"), show_col_types = FALSE)
new_fail <- fail |> anti_join(doc, by = c("key" = "identity")); gone <- doc |> anti_join(fail, by = c("identity" = "key"))
chg <- fail |> inner_join(doc, by = c("key" = "identity")) |> filter(resid != residual)
if (nrow(new_fail) || nrow(gone) || nrow(chg)) {
  cat("identities failing and not documented:\n"); print(new_fail, n = 100); cat("documented and no longer failing:\n"); print(gone, n = 100); cat("residual changed:\n"); print(chg, n = 100)
  stop("the failing identities are not the ones documented in source_inconsistencies.csv")
}
cat(sprintf("identities: %d hold; %d fail, all documented as inconsistencies of the printed source\n", nrow(con_info) - nrow(fail), nrow(fail)))
id_name <- c(sexes = "total = men + women", ages = "age rows = total", units = "secciones = national total", zones = "total = urban + rural",
             under5 = "under 5 = under 1 + 1-4", under1 = "under 1 = its five ages", age1to4 = "1-4 = 12-23 months + 2-4",
             halves = "Total general equal in both halves", causes = "causes = TOTAL NACIONAL")
ver <- con_info |> mutate(fails = r1 != 0, tables = if_else(grepl("=", type), type, str_match(key, "\\|(c[0-9]+)\\|")[, 2]),
                          identity = coalesce(unname(id_name[type]), "the same cell in two tables")) |>
  group_by(tables, identity) |> summarise(n_identities = n(), n_failing_in_source = sum(fails), .groups = "drop")
write_csv(ver, paste0(sup, "verification_identities.csv")); print(ver, n = 40)

# misprints, smudges and blanks of the print among the cells the identities corrected (each crop was read by eye)
mis <- read_csv(paste0(sup, "misprints_in_source.csv"), show_col_types = FALSE, col_types = cols(year = "i", .default = "c")) |> mutate(across(c(zone, half), \(x) replace_na(x, "")))
mk <- mis |> left_join(cells |> select(table, year, unit, zone, sex, age, half, id, read, value, how), by = c("table", "year", "unit", "zone", "sex", "age", "half"))
stopifnot(!anyNA(mk$id), all(grepl("identities", mk$how)))
corr <- cells |> filter(read != value | how %in% c("read on the page render", "run split by the sex identity", "total general taken from the other half")) |>
  left_join(mis |> select(table, year, unit, zone, sex, age, half, printed, note), by = c("table", "year", "unit", "zone", "sex", "age", "half")) |>
  left_join(sol$log |> group_by(id) |> summarise(witnesses = max(witnesses), .groups = "drop"), by = "id") |>
  mutate(method = case_when(!is.na(printed) ~ "identities; the print itself is wrong, smudged or blank", grepl("identities", how) & how != "identities" ~ how,
                            how == "identities" ~ "identities; the print agrees (text layer misread)", TRUE ~ how)) |>
  transmute(table, year, unit, zone, sex, age, half, page, text_layer = coalesce(raw, ""), text_layer_value = read, value, method, identities_agreeing = witnesses, printed, note)
write_csv(corr, paste0(sup, "cells_corrected.csv"), na = "")
cat("cells not taken as the text layer gives them, by method:\n"); print(count(corr, method))
cat(sprintf("Cuadro 6 cells read from run-together tokens split by column: %d\n", sum(cells$how == "run split by column")))

# ---------------------------------------------------------------------------
# 11. outputs ====
# ---------------------------------------------------------------------------
cod_dpto <- c(`Total nacional` = "00", Antioquia = "05", `Atlántico` = "08", `Bogotá D.E.` = "11", `Bolívar` = "13", `Boyacá` = "15", Caldas = "17", `Caquetá` = "18", Cauca = "19",
              Cesar = "20", `Córdoba` = "23", Cundinamarca = "25", `Chocó` = "27", Huila = "41", `La Guajira` = "44", Magdalena = "47", Meta = "50", `Nariño` = "52",
              `Norte de Santander` = "54", `Quindío` = "63", Risaralda = "66", Santander = "68", Sucre = "70", Tolima = "73", `Valle del Cauca` = "76")
wide <- function(tb, keys) cells |> filter(table == tb) |> select(all_of(keys), sex, value) |> pivot_wider(names_from = sex, values_from = value) |> mutate(across(c(male, female, total), as.integer))
age_levels <- c("all", "under 5", "under 1", ages[1:5], "1-4", ages[6:25])
by_unit <- function(d) d |> mutate(cod_dpto = unname(cod_dpto[unit]), .after = unit) |> arrange(year, match(unit, c(NAT, units2)), match(age, age_levels))

o1 <- cells |> filter(table == "c1") |> transmute(year, deaths = as.integer(value))
# Cuadro 2: marks as printed beside the names on the three pages; a dash (Caquetá before 1982) is "not listed apart"
marks <- c(Antioquia = "**", `Atlántico` = "**", `Córdoba` = "**", Cauca = "*", `Nariño` = "*", `Valle del Cauca` = "*")
mark_note <- c(`*` = "El subregistro que presentan Cauca, Nariño y Valle se debe a problemas de recolección y procesamiento",
               `**` = "Existe subregistro por problemas de cobertura")
dash2 <- cells |> filter(table == "c2") |> group_by(year, unit) |> summarise(dash = all(is.na(raw) & value == 0), .groups = "drop")
o2 <- wide("c2", c("year", "unit")) |> left_join(dash2, by = c("year", "unit")) |>
  mutate(across(c(total, male, female), \(x) if_else(dash, NA_integer_, x)), mark = unname(marks[unit]), mark_note = unname(mark_note[mark]),
         note = if_else(dash, "printed as a dash: not listed apart from the intendencias and comisarías", NA_character_)) |> select(-dash) |>
  mutate(cod_dpto = unname(cod_dpto[unit]), .after = unit) |> arrange(year, match(unit, c(NAT, units2))) |> select(year, unit, cod_dpto, total, male, female, mark, mark_note, note)
stopifnot(sum(is.na(o2$total)) == 12, all(o2$unit[is.na(o2$total)] == "Caquetá"))
o3 <- wide("c3", c("year", "zone", "age")) |> arrange(year, match(zone, c("total", "urban", "rural")), match(age, age_levels)) |> select(year, zone, age, male, female, total)
o10 <- wide("c10", c("year", "unit", "age")) |> by_unit() |> select(year, unit, cod_dpto, age, male, female, total)
o11 <- wide("c11", c("year", "unit", "age")) |> by_unit() |> select(year, unit, cod_dpto, age, male, female, total)
cn <- read_csv(paste0(sup, "cuadro6_cause_names.csv"), show_col_types = FALSE, col_types = "cc")
o6 <- cells |> filter(table == "c6", !(age == "all" & half == "B")) |> select(year, cause_code = unit, age, sex, value) |> pivot_wider(names_from = sex, values_from = value) |>
  mutate(across(c(male, female, total), as.integer)) |> left_join(cn, by = "cause_code") |>
  mutate(cause_name = if_else(cause_code == "000", "TOTAL NACIONAL", cause_name), cause_code = if_else(cause_code == "000", "TOTAL", cause_code)) |>
  arrange(year, cause_code == "TOTAL", cause_code, match(age, age_levels)) |> select(year, cause_code, cause_name, age, male, female, total)
stopifnot(!anyNA(o6$cause_name), !anyNA(o10 |> select(-cod_dpto)), !anyNA(o11 |> select(-cod_dpto)), !anyNA(o3), nrow(o11) == 9 * 25 * 26, nrow(o10) == 9 * 25 * 10, nrow(o3) == 9 * 3 * 26, nrow(o2) == 15 * 26)
write_csv(o1, paste0(out, "cuadro01_nacional_1915_1984.csv"))
write_csv(o2, paste0(out, "cuadro02_secciones_sexo_1970_1984.csv"), na = "")
write_csv(o3, paste0(out, "cuadro03_nacional_zona_edad.csv"))
write_csv(o6, paste0(out, "cuadro06_causas_edad_1973_1978.csv"))
write_csv(o10, paste0(out, "cuadro10_menores5_secciones.csv"), na = "")
write_csv(o11, paste0(out, "cuadro11_secciones_edad.csv"), na = "")
cat(sprintf("\nrows written: Cuadro 1 %d, Cuadro 2 %d, Cuadro 3 %d, Cuadro 6 %d (%d cause-years), Cuadro 10 %d, Cuadro 11 %d\n",
            nrow(o1), nrow(o2), nrow(o3), nrow(o6), n_distinct(paste(o6$year, o6$cause_code)), nrow(o10), nrow(o11)))
ext <- o6 |> filter(age == "all", cause_code %in% c("147", "148", "149")) |> select(year, cause_code, total) |> pivot_wider(names_from = cause_code, values_from = total)
cat("Cuadro 6, suicide (147), homicide and legal intervention (148), undetermined intent (149), all ages:\n"); print(ext)

# ---------------------------------------------------------------------------
# 12. comparison with the transcribed departmental series ====
# ---------------------------------------------------------------------------
slug <- \(x) tolower(ascii(x)) |> str_replace_all("[^a-z]+", "_") |> str_remove("_$")
gap <- read_delim("data_input/historical/col_gap_analysis_1920_1985_department_deaths_clean_v06.csv", delim = ";", show_col_types = FALSE, name_repair = "minimal") |>
  select(department, year, total, male, female, data_available) |> filter(year %in% 1970:1984)
cmp <- o2 |> filter(unit != NAT) |> mutate(department = recode(slug(unit), bogota_d_e = "bogota", intendencias_y_comisarias = "intendencias_y_comisarias")) |>
  full_join(gap, by = c("department", "year"), suffix = c("", "_gap"))
cat(sprintf("\ncol_gap_analysis department deaths v06, 1970-1984: %d unit-years in both; units only there: %s\n", sum(!is.na(cmp$unit) & !is.na(cmp$data_available)),
            paste(setdiff(unique(gap$department), cmp$department[!is.na(cmp$unit)]), collapse = ", ")))
dif <- cmp |> filter(!is.na(unit), !is.na(data_available)) |>
  filter(coalesce(total, -1L) != coalesce(total_gap, -1) | coalesce(male, -1L) != coalesce(male_gap, -1) | coalesce(female, -1L) != coalesce(female_gap, -1)) |>
  transmute(year, unit, total, male, female, total_gap, male_gap, female_gap, in_1970_1978 = year <= 1978) |> arrange(year, unit)
write_csv(dif, paste0(sup, "differences_vs_col_gap_analysis.csv"), na = "")
cat(sprintf("unit-years that differ: %d in 1970-1978, %d in 1979-1984\n", sum(dif$in_1970_1978), sum(!dif$in_1970_1978))); print(dif, n = 60)
