# 24_dane_vitales_1958_1960.R ---------------------------------------------------
# DANE, Sección IV Demografía (1962) "Estadística Vital: matrimonios,
# nacimientos (bautizos) y defunciones por municipios, durante los años 1958
# a 1960", Bogotá, marzo de 1962, 90 pp. Library scan (Atalasoft OCR layer,
# 2008): data_input/historical/LD_558_1958_1960_EJ_2.pdf (not versioned).
#
# Contents (same layout for the three years)
#   departmental summary (pdf p. 5, 33, 62): mid-year population, marriages,
#     baptisms, deaths, deaths under one year, and rates, by "sección del
#     país" (16 departments + intendencias y comisarías pooled; Meta as a
#     department in 1960)
#   municipal tables (pp. 6-31, 34-60, 63-90): marriages; baptisms H/M/T;
#     deaths under one year H/M/T; deaths at all ages H/M/T, by municipality
#     within department, intendencia or comisaría, with a TOTAL row per unit
#
# Births are parish baptisms, not registered births (the 1959 table adds 4 %
# for under-registration, 1958 and 1960 are "sin ajuste"); they undercount
# and are inflated where a parish seat serves several municipalities. Only
# the two death columns are registered deaths.
#
# Method
#   1. The departmental tables are transcribed by hand from the page renders
#      and verified: every column adds up to the published TOTAL.
#   2. The municipal tables are read from three machine sources and one
#      human one, cell by cell:
#        - the PDF text layer (pdftools::pdf_data, word boxes used to place
#          each number in its column),
#        - tesseract on each cell, 500 dpi black and white, line mode,
#        - tesseract on each cell, 400 dpi grey, word mode,
#        - for the death columns, the earlier transcription of the same
#          publication in col_gap_analysis_1920_1985_municipal_deaths_clean_v03
#          (matched by department, name and values).
#      For each H/M/T triple the combination of sources that satisfies
#      H + M = T is kept (the most supported one if several; the
#      transcription alone cannot decide a triple); for the lone marriages
#      column the text layer is kept when an OCR pass agrees with it, two
#      agreeing OCR passes beat it, otherwise a clean text token. The TOTAL
#      rows of the 16 departments are replaced by the verified departmental
#      table; one missing cell of a triple is completed from H + M = T and a
#      single missing cell of a unit-column from the unit TOTAL. Cells printed
#      "..." are "no information" and stay NA (column nodata_in_source); "-"
#      is zero. Cells still unresolved, units without TOTAL and columns whose
#      municipalities do not add up to the TOTAL were read by eye from 150
#      and 300 dpi crops of the page and recorded in the support folder:
#        headers.csv      unit headers the text layer lost (page, y, unit)
#        corrections.csv  one line per cell (page, y of the row, column 1-10
#                         or "name"/"is_total", value; "." = no data)
#        additions.csv    whole rows absent from the text layer (TOTAL rows,
#                         merged digits, rows printed with dots only)
#        rows_read.csv    whole pages read by eye (skewed p. 76, p. 39)
#        codes.csv        DIVIPOLA codes that the name match cannot give
#      After corrections 674 of the 700 unit-columns add up to their TOTAL
#      (142 of them with "..." cells excluded); the rest are inconsistencies
#      of the printed source (Antioquia 1958 marriages 30 and infant F 2;
#      Tolima 1958 marriages, TOTAL row 4002 vs departmental 4005;
#      Cundinamarca 1959 baptisms 800 and 1960 baptisms and deaths, 38;
#      Huila 1959 baptisms, Agrado row 126 + 193 printed 324), unresolved
#      columns with "..." cells (Boyacá, Cauca, Chocó 1959, Antioquia 1960
#      marriages) and the 1958 Vichada table without TOTAL. They are listed
#      in verification_unit_columns.csv and in the flag column of the output.
#   3. Municipality codes come from the matched transcription (DIVIPOLA),
#      then codes.csv, then the nearest DIVIPOLA name within the department
#      (one to one). Without code: the six municipalities annexed to Bogotá
#      in 1954 but still listed in 1960 (Bosa, Engativá, Fontibón, Suba,
#      Usaquén, Usme), the suppressed Bodega Central / Olaya Herrera
#      (Bolívar), Manare and Ten (Casanare), Umpalá (Santander), and the
#      Amazonas corregimientos Araracuara and Atacuarí.
#
# Facts about the source worth knowing: the 1959 municipal tables omit the
# comisarías (Amazonas, Putumayo, Vaupés, Vichada) and 1960 omits Putumayo;
# the intendencias and comisarías have no published departmental figures, so
# their TOTAL rows are taken as read; Casanare municipalities are listed
# under Boyacá, Guaviare and Guainía ones under Vaupés.
#
# output: data_input/historical/dane_vitales_1958_1960_departamental.csv
#         data_input/historical/dane_vitales_1958_1960_municipal.csv
#         data_input/historical/vitales_1958_1960_support/  (manual files
#           above plus verification_unit_columns.csv,
#           total_rows_vs_departmental.csv and
#           differences_vs_col_gap_analysis.csv; the OCR cache is in
#           data_inter/, not versioned)
# runtime: ~40 min for the two tesseract passes the first time (cached in
#          data_inter/vitales_1958_1960_ocr_pass{1,2}.rds), ~1 min after.
# -------------------------------------------------------------------------------
suppressMessages({library(tidyverse); library(magick); library(tesseract)})
options(width = 200)

pdf <- "data_input/historical/LD_558_1958_1960_EJ_2.pdf"
sup <- "data_input/historical/vitales_1958_1960_support/"
dir.create(sup, showWarnings = FALSE); dir.create("data_inter", showWarnings = FALSE)
stopifnot(file.exists(pdf))

# ---------------------------------------------------------------------------
# 1. departmental summaries (transcribed from the renders of pp. 5, 33, 62) ====
# ---------------------------------------------------------------------------
dep <- tribble(
  ~year, ~unit, ~population, ~marriages, ~baptisms, ~deaths, ~infant_deaths,
  1958, "Antioquia", 1820140, 12332, 90854, 25297, 9382,
  1958, "Atlántico", 551880, 2834, 29376, 5633, 1650,
  1958, "Bolívar", 766210, 3547, 25903, 5174, 1324,
  1958, "Boyacá", 833240, 5210, 34255, 10224, 2992,
  1958, "Caldas", 1272470, 8080, 59347, 21283, 8301,
  1958, "Cauca", 497410, 2734, 19339, 7958, 2537,
  1958, "Córdoba", 370700, 2247, 18329, 1699, 415,
  1958, "Cundinamarca", 1930990, 13617, 91857, 24382, 7836,
  1958, "Chocó", 142620, 397, 3371, 1327, 346,
  1958, "Huila", 345350, 1910, 15998, 4798, 1663,
  1958, "Magdalena", 470470, 2125, 15949, 4250, 1273,
  1958, "Nariño", 594280, 2752, 26012, 9349, 2941,
  1958, "Norte de Santander", 409460, 2637, 22583, 6763, 2397,
  1958, "Santander", 826970, 4982, 36857, 11333, 3410,
  1958, "Tolima", 818760, 4005, 29504, 11655, 3757,
  1958, "Valle del Cauca", 1527110, 7772, 54183, 19327, 7280,
  1958, "Intendencias y comisarías", 344200, 1335, 11844, 3229, 1049,
  1959, "Antioquia", 1857230, 13158, 94674, 26112, 9290,
  1959, "Atlántico", 571490, 2882, 29726, 5280, 1482,
  1959, "Bolívar", 754850, 3543, 27011, 5255, 1372,
  1959, "Boyacá", 837380, 5488, 35736, 11461, 3380,
  1959, "Caldas", 1303340, 7879, 60873, 21078, 8407,
  1959, "Cauca", 505220, 2717, 20315, 7905, 2392,
  1959, "Córdoba", 403490, 1887, 19834, 2120, 526,
  1959, "Cundinamarca", 1977330, 14387, 94335, 24992, 7839,
  1959, "Chocó", 144240, 415, 3669, 1189, 375,
  1959, "Huila", 353090, 2244, 16484, 4517, 1580,
  1959, "Magdalena", 480480, 2092, 17331, 3951, 1174,
  1959, "Nariño", 600870, 3213, 26823, 9107, 3093,
  1959, "Norte de Santander", 412440, 3283, 22692, 7151, 2358,
  1959, "Santander", 838310, 5158, 37565, 12801, 3642,
  1959, "Tolima", 834430, 4302, 30926, 11586, 3679,
  1959, "Valle del Cauca", 1596570, 7633, 57975, 19148, 7393,
  1959, "Intendencias y comisarías", 352840, 1443, 12701, 3181, 1014,
  1960, "Antioquia", 1894860, 12897, 97082, 28521, 9925,
  1960, "Atlántico", 591720, 2984, 23079, 4941, 1423,
  1960, "Bolívar", 768970, 3653, 25382, 5189, 1290,
  1960, "Boyacá", 841470, 5176, 36218, 11938, 3313,
  1960, "Caldas", 1334830, 6906, 58760, 21470, 8476,
  1960, "Cauca", 513100, 2641, 21143, 8704, 2568,
  1960, "Córdoba", 411040, 2056, 19782, 2122, 479,
  1960, "Cundinamarca", 2024560, 14519, 96231, 26495, 8043,
  1960, "Chocó", 145850, 532, 3625, 1380, 390,
  1960, "Huila", 360970, 2025, 15027, 4725, 1571,
  1960, "Magdalena", 490650, 1862, 17631, 3570, 1040,
  1960, "Meta", 80790, 764, 4989, 1243, 409,
  1960, "Nariño", 607470, 3507, 24427, 10032, 3363,
  1960, "Norte de Santander", 415390, 2883, 21480, 6456, 2030,
  1960, "Santander", 849690, 5258, 37981, 12533, 3606,
  1960, "Tolima", 850310, 6568, 28791, 11363, 3675,
  1960, "Valle del Cauca", 1669010, 9565, 58649, 20508, 7566,
  1960, "Intendencias y comisarías", 280980, 807, 8253, 1912, 554)
dep_total <- tribble(
  ~year, ~population, ~marriages, ~baptisms, ~deaths, ~infant_deaths,
  1958, 13522260, 78516, 585561, 173681, 58553,
  1959, 13823600, 81724, 608670, 176834, 58996,
  1960, 14131660, 84603, 598530, 183102, 59721)
chk <- dep |> group_by(year) |> summarise(across(population:infant_deaths, sum)) |> inner_join(dep_total, by = "year", suffix = c("", "_pub"))
stopifnot(all(chk$population == chk$population_pub), all(chk$marriages == chk$marriages_pub), all(chk$baptisms == chk$baptisms_pub),
          all(chk$deaths == chk$deaths_pub), all(chk$infant_deaths == chk$infant_deaths_pub))
dep <- bind_rows(dep, dep_total |> mutate(unit = "Total nacional")) |>
  mutate(baptisms_note = if_else(year == 1959, "baptisms raised 4 % for under-registration (published note)", "baptisms as reported by parishes"),
         marriage_rate = round(1000 * marriages / population, 2), baptism_rate = round(1000 * baptisms / population, 2),
         death_rate = round(1000 * deaths / population, 2), infant_mortality = round(1000 * infant_deaths / baptisms, 2)) |>
  arrange(year, unit != "Total nacional", unit)
write_csv(dep, "data_input/historical/dane_vitales_1958_1960_departamental.csv")
cat("departmental table: 3 years, columns add up to the published totals\n")

# ---------------------------------------------------------------------------
# 2. text layer of the municipal pages ====
# ---------------------------------------------------------------------------
year_pages <- list(`1958` = 6:31, `1959` = 34:60, `1960` = 63:90)
page_year <- setNames(rep(as.integer(names(year_pages)), lengths(year_pages)), unlist(year_pages))
num_chars <- "0-9lIiOoSsgJ)}(.,;:'~•·\\-\\$"
is_numtok <- function(t) grepl(paste0("^[", num_chars, "]+$"), t) & grepl("[0-9]", t)
is_dots <- function(t) grepl("^[.•·,]{2,}$", t) | t %in% c("-", "–", "—")
to_num <- function(t) { y <- gsub("[.,;: '~•·]", "", t); y <- chartr("lIiOoSsgJ)}(\\$", "11100559330005", y); suppressWarnings(as.integer(y)) }
tok_to_int <- function(x) { n <- to_num(x); n[!is.na(x) & is_dots(x)] <- NA; n[!is.na(x) & x %in% c("-", "–", "—")] <- 0L; n }
hdr_re <- "DEPARTAM|DEPART|TENDENC|TWDENC|TENDEC|COMISAR|OOMISAR|00MISAR|COMISRRIA|C0MISAR|COMISARLA"
# "TOTAL", "T 0 T A L", "ToT A L", "I TOTAL", "TOTAL ' ' *", "TOTAL •••a"; not "Tota" (a municipality of Boyacá)
is_total_name <- function(name) { s <- toupper(gsub("[^A-Za-z0-9]", "", name)); grepl("^[A-Z0-9]?T?[O0]TAL[A-Z]{0,2}$", s) | (nchar(s) == 5 & substr(s, 1, 1) == "T" & adist(s, "TOTAL")[, 1] <= 1) }

parse_page <- function(words, p) {
  # a word box two lines high (height > 16) belongs to the lower line: pdftools reports the top of the box
  w <- words[[p]] |> mutate(y = ifelse(height > 16, y + height - 11L, y), xr = x + width) |> arrange(y, x)
  if (nrow(w) == 0) return(NULL)
  w <- w |> mutate(row = cumsum(c(1, diff(y) > 5)))
  # two consecutive municipalities 4-5 pt apart end up in one cluster (the second with a two-line-high box): re-split by name tokens
  w <- w |> group_by(row) |> group_modify(function(g, k) {
    nm <- which(grepl("[A-Za-z]{3}", g$text) & g$xr < 200)
    if (length(nm) >= 2 && diff(range(g$y[nm])) >= 3) g$row2 <- cumsum(c(1, diff(g$y) > 2)) else g$row2 <- 1L
    g
  }) |> ungroup() |> mutate(row = row * 10 + row2) |> arrange(y, x)
  w |> group_by(row) |> group_map(function(g, k) {
    g <- g |> arrange(x); tt <- toupper(g$text)
    for (kk in 5:2) if (nrow(g) >= kk && all(nchar(tt[1:kk]) <= 3) && grepl("^[A-Z0-9.]{0,2}[O0]?T\\.?AL$", paste(tt[1:kk], collapse = ""))) { g$text[1] <- "TOTAL"; g <- g[-(2:kk), ]; break }
    hdr <- grepl(hdr_re, paste(g$text, collapse = " "), ignore.case = TRUE)
    nt <- is_numtok(g$text) | is_dots(g$text)
    nt[g$text %in% c("-", "–", "—") & g$xr < 160 & cumsum(is_numtok(g$text)) == 0] <- FALSE   # a dash before the name is not a cell
    first_num <- suppressWarnings(min(which(nt)))
    name <- if (is.finite(first_num)) paste(g$text[seq_len(first_num - 1)], collapse = " ") else paste(g$text, collapse = " ")
    sel <- nt & seq_len(nrow(g)) >= first_num
    tibble(page = p, y = round(mean(g$y)), hdr = hdr, name = str_remove(name, "[\\s.·•,;:'\\-]+$"),
           n_tok = sum(sel), tok = list(g$text[sel]), xl = list(g$x[sel]), xr = list(g$xr[sel]))
  }) |> bind_rows()
}
words <- pdftools::pdf_data(pdf)
all_rows <- map_dfr(unlist(year_pages), \(p) parse_page(words, p)) |> mutate(year = page_year[as.character(page)])
data_rows <- all_rows |> filter(!hdr, n_tok >= 6, !grepl("^[HMTK]( |$)|MUNICIPIOS|NACIMIENTOS|DEFUNCION|Menores|Todas|Bautizos", name))
# column positions per page: clusters of the right edges of the numeric tokens
col_centres <- data_rows |> select(page, tok, xr) |> unnest(c(tok, xr)) |> filter(is_numtok(tok)) |> arrange(page, xr) |>
  group_by(page) |> mutate(cl = cumsum(c(1, diff(xr) > 18))) |> group_by(page, cl) |> summarise(c = median(xr), n = n(), .groups = "drop") |>
  filter(n >= 3) |> group_by(page) |> mutate(rank = row_number(), k = n()) |> ungroup()
# a sparse page (p. 90: comisarías, mostly "...") can leave a column with < 3 numbers: fill the widest gap with its midpoint
col_centres <- col_centres |> group_by(page) |> group_modify(function(g, k) {
  cc <- sort(g$c)
  while (length(cc) < 10 && length(cc) >= 7) { d <- diff(cc); j <- which.max(d); if (d[j] < 1.6 * median(d)) break; cc <- sort(c(cc, mean(cc[j:(j + 1)]))) }
  tibble(c = cc, n = NA_integer_, rank = seq_along(cc), k = length(cc))
}) |> ungroup()
assign_cols <- function(page_i, tok, xl, xr) {
  cc <- col_centres |> filter(page == page_i) |> arrange(rank) |> pull(c)
  v <- rep(NA_character_, 10); bl <- rep(NA_real_, 10); br <- rep(NA_real_, 10)
  if (length(cc) != 10) return(list(v = v, xl = bl, xr = br, status = sprintf("centres_%d", length(cc))))
  col <- map_int(xr, \(r) which.min(abs(cc - r))); dist <- abs(cc[col] - xr)
  keep <- !(is_dots(tok) & dist > 14)                       # dotted leaders after the name are not cells
  tok <- tok[keep]; col <- col[keep]; dist <- dist[keep]; xl <- xl[keep]; xr <- xr[keep]
  if (any(duplicated(col)) || any(dist > 14)) return(list(v = v, xl = bl, xr = br, status = "misaligned"))
  v[col] <- tok; bl[col] <- xl; br[col] <- xr
  list(v = v, xl = bl, xr = br, status = "ok")
}
parsed <- data_rows |> mutate(a = pmap(list(page, tok, xl, xr), assign_cols), status = map_chr(a, "status"),
                              v = map(a, "v"), bxl = map(a, "xl"), bxr = map(a, "xr")) |> select(-a)
cat(sprintf("text layer: %d rows on %d pages; %d placed in the 10 columns, %d misaligned, %d on pages without 10 column positions\n",
            nrow(parsed), n_distinct(parsed$page), sum(parsed$status == "ok"), sum(parsed$status == "misaligned"), sum(grepl("centres", parsed$status))))

# ---------------------------------------------------------------------------
# 3. tesseract, cell by cell, two passes (cached) ====
# ---------------------------------------------------------------------------
ocr_pass <- function(dens, bw, psm, cache) {
  done <- if (file.exists(cache)) read_rds(cache) else tibble(page = integer(), y = numeric(), ocr = list())
  todo <- parsed |> anti_join(done, by = c("page", "y"))          # incremental: only rows not in the cache
  if (!nrow(todo)) return(done)
  sc <- dens / 72
  eng <- tesseract("eng", options = list(tessedit_pageseg_mode = as.character(psm), tessedit_char_whitelist = "0123456789."))
  res <- list(done)
  for (pg in sort(unique(todo$page))) {
    img <- image_read_pdf(pdf, pages = pg, density = dens) |> image_convert(colorspace = "gray")
    if (bw) img <- img |> image_threshold("white", "60%") |> image_threshold("black", "40%")
    H <- image_info(img)$height; W <- image_info(img)$width
    cc <- col_centres |> filter(page == pg) |> arrange(rank) |> pull(c)
    rows <- todo |> filter(page == pg)
    if (length(cc) != 10) next
    ocr_cell <- function(x1p, x2p, yp) {
      x1 <- max(1, round(x1p * sc)); x2 <- min(W, round(x2p * sc)); y1 <- max(1, round((yp - 3) * sc)); y2 <- min(H, round((yp + 13) * sc))
      crop <- image_crop(img, sprintf("%dx%d+%d+%d", x2 - x1, y2 - y1, x1, y1)) |> image_border("white", "40x40")
      if (!bw) crop <- image_resize(crop, "150%")
      trimws(ocr(crop, engine = eng))
    }
    out <- map(seq_len(nrow(rows)), function(i) {
      r <- rows[i, ]
      map_chr(1:10, function(j) {
        xl <- r$bxl[[1]][j]; xr <- r$bxr[[1]][j]
        if (is.na(xr) || is_dots(r$v[[1]][j])) { xl <- cc[j] - 30; xr <- cc[j] }
        ocr_cell(xl - 3, xr + 3, r$y)
      })
    })
    res[[as.character(pg)]] <- tibble(page = pg, y = rows$y, ocr = out)
    cat(sprintf("  tesseract %d dpi, page %d (%d rows)\n", dens, pg, nrow(rows)))
  }
  out <- bind_rows(res) |> distinct(page, y, .keep_all = TRUE); write_rds(out, cache); out
}
oc1 <- ocr_pass(500, TRUE, 7, "data_inter/vitales_1958_1960_ocr_pass1.rds") |> rename(ocr1 = ocr)
oc2 <- ocr_pass(400, FALSE, 8, "data_inter/vitales_1958_1960_ocr_pass2.rds") |> rename(ocr2 = ocr)
parsed <- parsed |> left_join(oc1, by = c("page", "y")) |> left_join(oc2, by = c("page", "y"))

# ---------------------------------------------------------------------------
# 4. units, TOTAL rows, match to the earlier transcription ====
# ---------------------------------------------------------------------------
units <- c("Antioquia", "Atlántico", "Bolívar", "Boyacá", "Caldas", "Cauca", "Córdoba", "Cundinamarca", "Chocó", "Huila", "Magdalena",
           "Nariño", "Norte de Santander", "Santander", "Tolima", "Valle del Cauca", "Meta", "Arauca", "Caquetá", "La Guajira",
           "San Andrés y Providencia", "Amazonas", "Putumayo", "Vaupés", "Vichada")
ascii <- \(x) iconv(x, to = "ASCII//TRANSLIT")
unit_key <- toupper(ascii(units)) |> str_remove_all("[^A-Z ]")
unit_slug <- setNames(tolower(ascii(units)) |> str_replace_all(" ", "_"), units)
hdr_unit <- function(txt) {
  s <- toupper(txt) |> str_remove("(?i)^.*?(DEPART[^ ]*|[^ ]*TENDENC[^ ]*|[^ ]*TWDENC[^ ]*|[^ ]*TENDEC[^ ]*|COMISAR[^ ]*|OOMISAR[^ ]*|00MISAR[^ ]*|COMISRRIA|C0MISAR[^ ]*)\\s*") |>
    str_remove("^(DE|DEL|DLL|DE LA|DEL,|DE,|D[A-Z]{1,2},?)\\s+") |> str_remove_all("[^A-Z ]") |> str_squish()
  s <- str_replace(s, "^NORTE.*", "NORTE DE SANTANDER") |> str_replace("^VALLE.*|^YALL.*", "VALLE DEL CAUCA") |> str_replace("^SAN ANDRES.*", "SAN ANDRES Y PROVIDENCIA") |> str_replace("^(LA |IA )?GUAJIRA", "LA GUAJIRA")
  units[apply(adist(s, unit_key), 1, which.min)]
}
hdrs <- all_rows |> filter(grepl(hdr_re, name, ignore.case = TRUE), !is_total_name(name), n_tok < 6) |>
  mutate(unit = hdr_unit(name)) |> select(year, page, y, hdr_text = name, unit)
# headers the text layer lost or garbled beyond recognition (checked on the page renders)
hdr_file <- paste0(sup, "headers.csv")
if (file.exists(hdr_file)) {
  hdr_add <- read_csv(hdr_file, show_col_types = FALSE) |> mutate(hdr_text = paste0("[added] ", note)) |> select(year, page, y, hdr_text, unit)
  stopifnot(all(hdr_add$unit %in% units)); hdrs <- bind_rows(hdrs, hdr_add); cat("manual headers:", nrow(hdr_add), "\n")
}
hdrs <- hdrs |> arrange(page, y)
rows <- parsed |> mutate(is_total = is_total_name(name)) |> arrange(page, y) |> mutate(ord = row_number())
rows$unit <- map2_chr(rows$page, rows$y, function(p, yy) { h <- hdrs |> filter(page < p | (page == p & y < yy)) |> slice_tail(n = 1); if (nrow(h)) h$unit else NA_character_ })

ex <- read_csv("data_input/historical/col_gap_analysis_1920_1985_municipal_deaths_clean_v03.csv", show_col_types = FALSE) |>
  filter(year %in% 1958:1960, data_available == 1) |>
  mutate(nkey = tolower(ascii(municipality)) |> str_remove_all("[^a-z]"))
rows <- rows |> mutate(nkey = coalesce(tolower(ascii(name)) |> str_remove_all("[^a-z]"), ""), dslug = unit_slug[unit])
num_or_na <- \(x) if (is.null(x)) rep(NA_integer_, 10) else suppressWarnings(as.integer(gsub("[^0-9]", "", x)))
S_text <- map(rows$v, tok_to_int); S_o1 <- map(rows$ocr1, num_or_na); S_o2 <- map(rows$ocr2, num_or_na)
# one-to-one within each year and department: first the rows whose deaths triple (text or OCR) equals the transcription, then by name distance
rows$ex_code <- NA_real_
for (yr in unique(rows$year)) for (ds in unique(na.omit(rows$dslug[rows$year == yr]))) {
  ri <- which(rows$year == yr & rows$dslug == ds & !rows$is_total); cand <- ex |> filter(year == yr, department == ds, !is.na(dane_code)) |> distinct(dane_code, .keep_all = TRUE)
  if (!length(ri) || !nrow(cand)) next
  D <- adist(rows$nkey[ri], cand$nkey)
  hit <- matrix(FALSE, length(ri), nrow(cand))
  for (a in seq_along(ri)) { tri <- rbind(S_text[[ri[a]]][8:10], S_o1[[ri[a]]][8:10], S_o2[[ri[a]]][8:10]); tri <- tri[!apply(tri, 1, anyNA), , drop = FALSE]
    if (nrow(tri)) for (k in seq_len(nrow(cand))) hit[a, k] <- any(apply(tri, 1, \(x) all(x == c(cand$male[k], cand$female[k], cand$total[k])))) }
  score <- ifelse(hit, D - 100, D)                               # a triple hit beats any name distance
  nch <- nchar(rows$nkey[ri]); ok <- hit | D <= 2 | (D <= 4 & nch >= 6 & D / pmax(nch, 1) < 0.4)
  score[!ok | is.na(score)] <- Inf
  while (any(is.finite(score))) {                                 # greedy one-to-one assignment by best score
    b <- which(score == min(score), arr.ind = TRUE)[1, ]
    rows$ex_code[ri[b[1]]] <- cand$dane_code[b[2]]; score[b[1], ] <- Inf; score[, b[2]] <- Inf
  }
}
exj <- rows |> select(year, ex_code) |>
  left_join(ex |> filter(!is.na(dane_code)) |> distinct(year, dane_code, .keep_all = TRUE) |> select(year, dane_code, ex_name = municipality, ex_m = male, ex_f = female, ex_t = total),
            by = c("year", "ex_code" = "dane_code"), na_matches = "never")
rows$ex_name <- exj$ex_name
S_ex <- pmap(list(exj$ex_m, exj$ex_f, exj$ex_t), \(m, f, t) { v <- rep(NA_integer_, 10); v[8:10] <- c(m, f, t); v })

# ---------------------------------------------------------------------------
# 5. fusion by identities, unit residuals, manual corrections ====
# ---------------------------------------------------------------------------
fuse_triple <- function(S, idx, aux = integer()) {   # aux: sources that may support a solution but not form one on their own
  M <- do.call(rbind, lapply(S, \(s) s[idx])); combos <- expand.grid(rep(list(seq_along(S)), 3))
  combos <- combos[!apply(combos, 1, \(cb) all(cb %in% aux)), ]
  sols <- list(); votes <- c()
  for (k in seq_len(nrow(combos))) {
    x <- c(M[combos[k, 1], 1], M[combos[k, 2], 2], M[combos[k, 3], 3])
    if (!anyNA(x) && x[1] + x[2] == x[3]) { kx <- paste(x, collapse = "_"); sols[[kx]] <- x; votes[kx] <- sum(sapply(seq_along(S), \(s) sum(!is.na(M[s, ]) & M[s, ] == x))) }
  }
  if (!length(sols)) {
    agree <- apply(M, 2, \(col) { u <- unique(col[!is.na(col)]); if (length(u) == 1 && sum(!is.na(col)) >= 2) u else NA_integer_ })
    return(list(v = as.integer(agree), src = if (all(is.na(M))) "empty" else "unresolved"))
  }
  if (length(sols) == 1) return(list(v = sols[[1]], src = "solved"))
  o <- order(-votes); if (votes[o[1]] > votes[o[2]]) return(list(v = sols[[o[1]]], src = "voted"))
  list(v = rep(NA_integer_, 3), src = "ambiguous")
}
# single column (marriages): tesseract often returns nothing for this narrow column, so the text layer decides unless both OCR passes agree against it
fuse_single <- function(S, j, txt_tok = NA_character_) {
  x <- sapply(S, \(s) s[j]); tx <- x[1]; oc <- x[-1]; oc <- oc[!is.na(oc)]
  if (all(is.na(x))) return(list(v = NA_integer_, src = "empty"))
  clean_text <- !is.na(tx) && (grepl("^[0-9]{1,3}(\\.[0-9]{3})?$", txt_tok) || txt_tok %in% c("-", "–", "—"))
  if (length(oc) >= 2 && length(unique(oc)) == 1 && (is.na(tx) || oc[1] != tx)) return(list(v = oc[1], src = if (is.na(tx)) "ocr" else "ocr over text"))
  if (!is.na(tx) && any(oc == tx)) return(list(v = tx, src = "majority"))
  if (clean_text) return(list(v = tx, src = "text"))
  if (is.na(tx) && length(oc) == 1) return(list(v = oc, src = "ocr single"))
  list(v = NA_integer_, src = "disagree")
}
fused <- map(seq_len(nrow(rows)), function(i) {
  S <- list(S_text[[i]], S_o1[[i]], S_o2[[i]], S_ex[[i]])
  m <- fuse_single(S, 1, rows$v[[i]][1]); b <- fuse_triple(S, 2:4); f <- fuse_triple(S, 5:7); d <- fuse_triple(S, 8:10, aux = 4)
  list(v = c(m$v, b$v, f$v, d$v), src = c(m$src, b$src, f$src, d$src))
})
fv <- do.call(rbind, map(fused, "v")); colnames(fv) <- paste0("c", 1:10)
src <- do.call(rbind, map(fused, "src")); colnames(src) <- c("src_marriages", "src_baptisms", "src_infant", "src_deaths")
rows <- bind_cols(rows, as_tibble(fv), as_tibble(src)) |> mutate(manual = "")
# cells printed as "..." (no information; "-" is zero) that no source could read: no data in the source, not a missing reading
nd_cols <- function(flags) if (any(flags, na.rm = TRUE)) paste0("c", which(flags), collapse = ";") else ""
rows$nodata <- map_chr(seq_len(nrow(rows)), \(i) { v <- rows$v[[i]]; nd_cols(!is.na(v) & grepl("^[.•·,]{2,}$", v) & is.na(unlist(rows[i, paste0("c", 1:10)]))) })
nd_add <- function(nd, cn) { x <- strsplit(coalesce(nd, ""), ";")[[1]]; paste(unique(c(x[nzchar(x)], cn)), collapse = ";") }
nd_mat <- function(df) sapply(1:10, \(j) str_detect(coalesce(df$nodata, ""), paste0("(^|;)c", j, "(;|$)")))
cat("fusion of the sources (marriages | baptisms | infant deaths | deaths):\n")
for (k in colnames(src)) { cat("  ", k, ": "); print(table(rows[[k]])) }

# manual additions: rows the text layer lost (one line per row, values already verified)
add_file <- paste0(sup, "additions.csv")
if (file.exists(add_file)) {
  add <- read_csv(add_file, show_col_types = FALSE, col_types = cols(.default = "c"))
  add$nodata <- apply(add[paste0("c", 1:10)], 1, \(r) nd_cols(r == "."))
  add <- add |> mutate(across(c(c1:c10), ~ suppressWarnings(as.integer(.x))), across(c(page, y, year), as.integer), is_total = as.logical(is_total), manual = "added row") |> select(-note)
  rows <- bind_rows(rows, add |> mutate(status = "manual")) |> arrange(page, y)
  cat("manual additions:", nrow(add), "rows\n")
}
# manual corrections: one line per cell read from the page render
cor_file <- paste0(sup, "corrections.csv")
if (file.exists(cor_file)) {
  cor <- read_csv(cor_file, show_col_types = FALSE, col_types = cols(.default = "c")) |> mutate(across(c(page, y), as.integer))
  for (i in seq_len(nrow(cor))) {
    k <- which(rows$page == cor$page[i] & abs(rows$y - cor$y[i]) <= 3)
    if (length(k) != 1) { cat("correction not matched:", cor$page[i], cor$y[i], "\n"); next }
    if (cor$col[i] == "is_total") { rows$is_total[k] <- as.logical(cor$value[i]); next }   # TOTAL rows whose label the text layer lost
    if (cor$col[i] == "name") { rows$name[k] <- cor$value[i]; next }                     # names lost or garbled
    cn <- paste0("c", cor$col[i])
    if (cor$value[i] == ".") { rows[[cn]][k] <- NA; rows$nodata[k] <- nd_add(rows$nodata[k], cn); next }   # "..." in the source
    rows[[cn]][k] <- as.integer(cor$value[i])
    rows$manual[k] <- paste0(rows$manual[k], if (rows$manual[k] != "") ";", cn)
  }
  cat("manual corrections:", nrow(cor), "cells\n")
}
# whole rows read on a page render (pages whose scan defeats the text layer and tesseract alike)
rr_file <- paste0(sup, "rows_read.csv")
if (file.exists(rr_file)) {
  rr <- read_csv(rr_file, show_col_types = FALSE, col_types = cols(.default = "c")) |> mutate(across(c(page, y), as.integer))
  for (i in seq_len(nrow(rr))) {
    k <- which(rows$page == rr$page[i] & abs(rows$y - rr$y[i]) <= 3)
    if (length(k) != 1) { cat("row read not matched:", rr$page[i], rr$y[i], rr$name[i], "\n"); next }
    rows$name[k] <- rr$name[i]; rows$nodata[k] <- ""
    for (j in 1:10) { cn <- paste0("c", j); v <- rr[[cn]][i]
      if (v == ".") { rows[[cn]][k] <- NA; rows$nodata[k] <- nd_add(rows$nodata[k], cn) } else rows[[cn]][k] <- as.integer(v) }
    rows$manual[k] <- "row read on the page render"
  }
  cat("rows read on the page render:", nrow(rr), "\n")
}
# the TOTAL rows repeat the departmental table (validated above): anchor marriages, baptisms, infant deaths and deaths to it
tot_i <- which(rows$is_total & !is.na(rows$unit))
tot_pub <- rows[tot_i, ] |> select(year, unit) |> left_join(dep |> select(year, unit, marriages, baptisms, infant_deaths, deaths), by = c("year", "unit"))
tot_cmp <- tibble(year = rows$year[tot_i], unit = rows$unit[tot_i], page = rows$page[tot_i], y = rows$y[tot_i],
                  marriages_row = rows$c1[tot_i], marriages_dep = tot_pub$marriages, baptisms_row = rows$c4[tot_i], baptisms_dep = tot_pub$baptisms,
                  infant_row = rows$c7[tot_i], infant_dep = tot_pub$infant_deaths, deaths_row = rows$c10[tot_i], deaths_dep = tot_pub$deaths)
write_csv(tot_cmp, paste0(sup, "total_rows_vs_departmental.csv"))
cat(sprintf("TOTAL rows vs departmental table: %d rows; read values differing from the published ones (NA excluded): marriages %d, baptisms %d, infant %d, deaths %d\n", nrow(tot_cmp),
            sum(tot_cmp$marriages_row != tot_cmp$marriages_dep, na.rm = TRUE), sum(tot_cmp$baptisms_row != tot_cmp$baptisms_dep, na.rm = TRUE),
            sum(tot_cmp$infant_row != tot_cmp$infant_dep, na.rm = TRUE), sum(tot_cmp$deaths_row != tot_cmp$deaths_dep, na.rm = TRUE)))
ok <- !is.na(tot_pub$deaths)
rows$c1[tot_i[ok]] <- tot_pub$marriages[ok]; rows$c4[tot_i[ok]] <- tot_pub$baptisms[ok]; rows$c7[tot_i[ok]] <- tot_pub$infant_deaths[ok]; rows$c10[tot_i[ok]] <- tot_pub$deaths[ok]
rows$manual[tot_i[ok]] <- "totals from the departmental table"
# a triple with exactly one missing value is completed by the identity H + M = T
fill_identity <- function(df) {
  for (g in list(2:4, 5:7, 8:10)) {
    H <- df[[paste0("c", g[1])]]; M <- df[[paste0("c", g[2])]]; Tt <- df[[paste0("c", g[3])]]
    one <- (is.na(H) + is.na(M) + is.na(Tt)) == 1
    fH <- one & is.na(H) & (Tt - M) >= 0; fM <- one & is.na(M) & (Tt - H) >= 0; fT <- one & is.na(Tt)
    fH[is.na(fH)] <- FALSE; fM[is.na(fM)] <- FALSE
    H[fH] <- Tt[fH] - M[fH]; M[fM] <- Tt[fM] - H[fM]; Tt[fT] <- H[fT] + M[fT]
    df[[paste0("c", g[1])]] <- H; df[[paste0("c", g[2])]] <- M; df[[paste0("c", g[3])]] <- Tt
  }
  df
}
n_before <- sum(is.na(rows[paste0("c", 1:10)]))
ND <- nd_mat(rows)
rows <- fill_identity(rows)
for (j in 1:10) rows[[paste0("c", j)]][ND[, j]] <- NA          # "..." stays empty even when the identity could fill it
cat("cells completed by the identity H + M = T:", n_before - sum(is.na(rows[paste0("c", 1:10)])), "\n")
# a single missing cell in a unit-column is the TOTAL minus the rest
fill_log <- list()
for (yr in unique(rows$year)) for (u in unique(na.omit(rows$unit[rows$year == yr]))) {
  idx <- which(rows$year == yr & rows$unit == u); tot <- idx[rows$is_total[idx]]; mun <- idx[!rows$is_total[idx]]
  if (length(tot) != 1) next
  for (j in 1:10) { cn <- paste0("c", j); tv <- rows[[cn]][tot]; mv <- rows[[cn]][mun]
    if (is.na(tv) || any(ND[mun, j]) || sum(is.na(mv)) != 1) next          # not when the source has "..." cells in the column
    k <- mun[is.na(mv)]; val <- tv - sum(mv, na.rm = TRUE)
    if (val >= 0) { rows[[cn]][k] <- val; rows$manual[k] <- paste0(rows$manual[k], if (rows$manual[k] != "") ";", "c", j, "=residual")
      fill_log[[length(fill_log) + 1]] <- tibble(year = yr, unit = u, name = rows$name[k], col = j, value = val) }
  }
}
cat("cells filled from the unit residual:", length(fill_log), "\n")
# verification per unit and column
ND <- nd_mat(rows)
blk <- rows |> mutate(.nd = asplit(ND, 1)) |> filter(!is.na(unit)) |> group_by(year, unit) |> group_map(function(g, k) {
  tot <- g |> filter(is_total); mun <- g |> filter(!is_total); ndm <- do.call(rbind, mun$.nd)
  if (nrow(tot) != 1) return(tibble(year = k$year, unit = k$unit, col = 1:10, total = NA_integer_, sum = NA_integer_, n_na = NA_integer_, n_nodata = NA_integer_, n_mun = nrow(mun), state = sprintf("%d TOTAL rows", nrow(tot))))
  map_dfr(1:10, \(j) { cn <- paste0("c", j); tibble(year = k$year, unit = k$unit, col = j, total = tot[[cn]], sum = sum(mun[[cn]], na.rm = TRUE),
                                                   n_na = sum(is.na(mun[[cn]]) & !ndm[, j]), n_nodata = sum(ndm[, j]), n_mun = nrow(mun), state = "") })
}) |> bind_rows() |> mutate(resid = total - sum,
                            state = case_when(state != "" ~ state, is.na(total) ~ "total unknown", n_na > 0 ~ "cells missing",
                                              n_nodata > 0 & resid == 0 ~ "verified (cells printed as no data excluded)",
                                              n_nodata > 0 ~ "no data in source for some cells", resid == 0 ~ "verified", TRUE ~ "does not add up"))
cat("unit-columns by state:\n"); print(table(blk$state))
write_csv(blk, paste0(sup, "verification_unit_columns.csv"))
# published departmental deaths vs the sum of the municipal rows (occurrence, all units)
dep_chk <- rows |> filter(!is_total, !is.na(unit)) |> group_by(year, unit) |> summarise(deaths_munic = sum(c10, na.rm = TRUE), infant_munic = sum(c7, na.rm = TRUE), .groups = "drop") |>
  inner_join(dep |> select(year, unit, deaths, infant_deaths), by = c("year", "unit")) |> mutate(d_deaths = deaths_munic - deaths, d_infant = infant_munic - infant_deaths)
cat("departments where the municipal sum differs from the published departmental total (deaths / infant deaths):\n"); print(dep_chk |> filter(d_deaths != 0 | d_infant != 0), n = 60)

# ---------------------------------------------------------------------------
# 6. codes and output ====
# ---------------------------------------------------------------------------
divi <- read_csv("data_input/reference/DIVIPOLA-_Códigos_municipios_20260307.csv", show_col_types = FALSE) |>
  transmute(cod_dpto = `Código Departamento`, dpto = `Nombre Departamento`, cod_munic = `Código Municipio`, munic = `Nombre Municipio`,
            nkey = tolower(ascii(munic)) |> str_remove_all("[^a-z]"),
            # the source abbreviates the official long forms: San José de Cúcuta -> Cúcuta, Santa Fe de Antioquia -> Antioquia, Santa Cruz de Mompox -> Mompós...
            nkey2 = str_remove(toupper(ascii(munic)), "^(SAN JOSE DE|SANTIAGO DE|SANTA FE DE|SANTA CRUZ DE|SAN JUAN DE|SAN LUIS DE|SAN SEBASTIAN DE|SAN VICENTE DE|SAN ANDRES DE|SAN PEDRO DE|SAN MIGUEL DE|SAN MARTIN DE|SANTA BARBARA DE) ") |> tolower() |> str_remove_all("[^a-z]"))
unit_dpto <- c(Antioquia = "05", Atlántico = "08", Bolívar = "13", Boyacá = "15", Caldas = "17", Cauca = "19", Córdoba = "23", Cundinamarca = "25", Chocó = "27",
               Huila = "41", Magdalena = "47", Nariño = "52", `Norte de Santander` = "54", Santander = "68", Tolima = "73", `Valle del Cauca` = "76", Meta = "50",
               Arauca = "81", Caquetá = "18", `La Guajira` = "44", `San Andrés y Providencia` = "88", Amazonas = "91", Putumayo = "86", Vaupés = "97", Vichada = "99")
rows <- rows |> mutate(nkey = coalesce(tolower(ascii(name)) |> str_remove_all("[^a-z]"), ""))   # added rows too
rows <- rows |> mutate(cod_munic = if_else(!is.na(ex_code), sprintf("%05d", as.integer(ex_code)), NA_character_))
# manual codes (codes.csv): municipalities that belong to another department today (Casanare, Guaviare, Guainía) or whose
# name changed (Zapatosa = Aguazul, Moreno = Paz de Ariporo, Palomino = Pinillos, Darién = Calima, El Valle = Valle del Guamuez, Rafael Reyes = Apulo)
mcodes <- read_csv(paste0(sup, "codes.csv"), show_col_types = FALSE, col_types = cols(.default = "c")) |> mutate(year = as.integer(year))
stopifnot(all(mcodes$cod_munic %in% divi$cod_munic))
for (i in seq_len(nrow(mcodes))) {
  hit <- which(rows$unit == mcodes$unit[i] & rows$nkey == mcodes$name_key[i] & !rows$is_total & (is.na(mcodes$year[i]) | rows$year == mcodes$year[i]))
  if (!length(hit)) warning("codes.csv: no row for ", mcodes$unit[i], " ", mcodes$name_key[i], " ", mcodes$year[i])
  rows$cod_munic[hit] <- mcodes$cod_munic[i]
}
# rows without a transcription code: nearest DIVIPOLA name of the department (both keys), one-to-one, codes already taken excluded
for (yr in unique(rows$year)) for (u in unique(na.omit(rows$unit[rows$year == yr]))) {
  ri <- which(rows$year == yr & rows$unit == u & !rows$is_total & is.na(rows$cod_munic) & rows$nkey != "")
  taken <- rows$cod_munic[rows$year == yr & rows$unit == u & !is.na(rows$cod_munic)]
  cand <- divi |> filter(cod_dpto == unit_dpto[u] | (u == "Cundinamarca" & cod_dpto == "11"), !cod_munic %in% taken)
  if (!length(ri) || !nrow(cand)) next
  D <- pmin(adist(rows$nkey[ri], cand$nkey), adist(rows$nkey[ri], cand$nkey2)); nch <- nchar(rows$nkey[ri])
  D[!(D <= 1 | (D <= 2 & nch >= 5) | (D <= 4 & nch >= 7 & D / nch < 0.4))] <- Inf
  while (any(is.finite(D))) { b <- which(D == min(D), arr.ind = TRUE)[1, ]; rows$cod_munic[ri[b[1]]] <- cand$cod_munic[b[2]]; D[b[1], ] <- Inf; D[, b[2]] <- Inf }
}
rows <- rows |> left_join(divi |> select(cod_munic, munic_divipola = munic), by = "cod_munic")
mun <- rows |> filter(!is_total, !is.na(unit)) |>
  transmute(year, unit, cod_dpto = unit_dpto[unit], cod_munic, municipio = coalesce(munic_divipola, ex_name, name), name_in_source = name,
            marriages = c1, baptisms_m = c2, baptisms_f = c3, baptisms_t = c4, infant_deaths_m = c5, infant_deaths_f = c6, infant_deaths_t = c7,
            deaths_m = c8, deaths_f = c9, deaths_t = c10,
            src_marriages, src_baptisms, src_infant, src_deaths, manual, nodata_in_source = nodata, page, y)
# flags: unit-column not verified
flag <- blk |> filter(!state %in% c("verified", "verified (cells printed as no data excluded)", "no data in source for some cells")) |> group_by(year, unit) |> summarise(flag = paste0("col", col, ":", state, collapse = "; "), .groups = "drop")
mun <- mun |> left_join(flag, by = c("year", "unit")) |> mutate(flag = replace_na(flag, ""))
write_csv(mun, "data_input/historical/dane_vitales_1958_1960_municipal.csv")
write_rds(list(rows = rows, blk = blk, hdrs = hdrs, ex = ex), "data_inter/vitales_1958_1960_state.rds")   # for the review crops (not versioned)
cat(sprintf("\nmunicipal table: %d rows (%s); %d with a DIVIPOLA code; %d cells still NA; %d rows in units not fully verified\n",
            nrow(mun), paste(table(mun$year), collapse = "/"), sum(!is.na(mun$cod_munic)), sum(is.na(mun[, 7:16])), sum(mun$flag != "")))

# ---------------------------------------------------------------------------
# 7. comparison with the earlier transcription of the death columns ====
# ---------------------------------------------------------------------------
cmp <- mun |> filter(!is.na(cod_munic)) |> inner_join(ex |> mutate(cod_munic = sprintf("%05d", as.integer(dane_code))) |> select(year, cod_munic, ex_t = total, ex_m = male, ex_f = female), by = c("year", "cod_munic")) |>
  mutate(diff_t = deaths_t - ex_t, diff_m = deaths_m - ex_m, diff_f = deaths_f - ex_f)
cat(sprintf("\ncomparison with col_gap_analysis municipal deaths: %d matched rows; total deaths differ in %d, male in %d, female in %d\n",
            nrow(cmp), sum(cmp$diff_t != 0, na.rm = TRUE), sum(cmp$diff_m != 0, na.rm = TRUE), sum(cmp$diff_f != 0, na.rm = TRUE)))
print(cmp |> filter(diff_t != 0 | diff_m != 0 | diff_f != 0) |> select(year, unit, municipio, deaths_t, ex_t, deaths_m, ex_m, deaths_f, ex_f), n = 80)
write_csv(cmp |> filter(diff_t != 0 | diff_m != 0 | diff_f != 0) |> select(year, unit, cod_munic, municipio, deaths_t, ex_t, deaths_m, ex_m, deaths_f, ex_f, manual),
          paste0(sup, "differences_vs_col_gap_analysis.csv"))
