# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 23. Census summary tables 1938, 1951, 1964 and 1973 from the DANE PDFs
#     (tesseract OCR reconciled by accounting identities + visual transcription)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Sources (data_input/historical/, PDFs not versioned, 35 MB):
#   LD_771_1964.pdf      XIII Censo nacional de población (15 de julio de
#                        1964), resumen general. Cuadro 7 (pdf pp. 26-32):
#                        población por sexo, cabeceras y resto de los
#                        municipios, según grupos de edad, país, departamentos
#                        y territorios nacionales; Cuadro 9 (pdf pp. 35-36):
#                        the same for the country by single years of age;
#                        Cuadro 14 (pdf pp. 49-61 and 63): población nacida en
#                        el país y en el extranjero por lugar de nacimiento y
#                        sexo, según lugar de residencia y grandes grupos de
#                        edad (0-14, 15-59, 60+).
#   LD_771_1938_V_1.pdf  Censo general de población 1938, resumen general.
#                        Cuadro 28 (pdf pp. 105-107): población por edades
#                        simples, sexo y estado civil. Only the "totales"
#                        block (hombres, mujeres, total) is kept.
#   LD_771_1951.pdf      Censo de población 1951, resumen. Cuadro 10 (pdf
#                        pp. 22-32): población por grupos quinquenales de edad
#                        y sexo en 1938 y 1951, por departamentos,
#                        intendencias y comisarías.
#   LB_771_1973.pdf      XIV Censo nacional de población 1973, resumen
#                        nacional. Cuadro 2 (pdf pp. 316-317): población
#                        censada por edades simples y sexo, total / cabecera /
#                        resto; capítulo VIII (pdf pp. 115-197): población
#                        ajustada por cobertura por sección territorial y
#                        municipio; Cuadro VIII.20 (pdf p. 94): national
#                        summary of the adjustment; Cuadros 21 and 21A (pdf
#                        pp. 381-384): women aged 15+ by children ever born
#                        and surviving, by age group and by sección.
#
# Method
#   1951  Each page is rendered at 500 dpi (grey, thresholded to b/w) and at
#         300 dpi and read with tesseract (page mode 6). Words with bounding
#         boxes are clustered into rows (y centre) and into the six rightmost
#         numeric columns (right edge); tokens split at a thousands separator
#         are merged; low-confidence or malformed cells are re-read one by one
#         (page mode 7, digit whitelist). The two passes are reconciled with
#         the identities total = hombres + mujeres (each row), sum of the 21
#         age rows = section header, and departamentos + intendencias +
#         comisarías = nación. The cells that no identity could settle were
#         read visually from the page crops and are listed in
#         ocr_support/corrections_1951.csv (section, age, column, value).
#   1964  Same grid OCR, with two changes for a denser table in a typeface
#         that tesseract misreads often (5/6, 3/8, 7/1): rows come from the
#         baseline of the numeric tokens on the deskewed page, and five passes
#         are run (300, 400, 500 and 600 dpi grey, 500 dpi thresholded). Every
#         printed row has nine cells, (total, cabecera, resto) x (total,
#         hombres, mujeres), tied by six identities; a row is the combination
#         of readings that satisfies all six, or the majority reading with one
#         or two cells replaced by what the identities imply. 34 rows that
#         stayed open were read by eye (ocr_support/corrections_1964_rows.csv).
#         Then the age rows must add to the section header in the nine
#         columns, the 27 units to the national section, and the single ages
#         of Cuadro 9 to the age groups of Cuadro 7.
#         Cuadro 14 (place of birth x place of residence): three passes (300 and
#         400 dpi grey, 500 dpi thresholded) on the deskewed pages, the
#         right-hand pages cropped to drop the repeated labels. 420 blocks
#         (20 residences x 21 birthplace groups) of 4 lines x 3 columns
#         (total, hombres, mujeres), each tied by seven identities; a block is
#         the combination of readings that satisfies them, the 50 that stayed
#         open were read by eye (ocr_support/corrections_1964_cuadro14.csv).
#         Then Totales = sum of the 20 birthplaces for every residence, the
#         national row = sum of the 19 other residences for every birthplace,
#         and the Totales group = Cuadro 7 (ages grouped, intendencias and
#         comisarías summed).
#   1938 The 12-column typeset table defeated the column clustering (OCR
#         draft with ~30 wrong cells); the totales block was transcribed
#         visually from 500 dpi crops (ocr_support/transcription_1938_cuadro28.csv)
#         and validated row by row (T = H + M) and against the published
#         grand totals 4,312,763 / 4,389,053 / 8,701,816.
#   1973  Chain-printer scan unreadable by tesseract (6/E, 0/C, 9/S
#         confusions in every preprocessing variant). Cuadro 2 (national
#         columns) and the TOTAL / CABECERA / RESTO rows of each sección in
#         chapter VIII were transcribed visually and validated against the
#         printed 5-year rows, the grand total and Cuadro VIII.20. Cuadros 21
#         and 21A likewise: every row, every zone split and the sum of the 31
#         secciones against the national rows hold exactly.
#
# Stage A (run_ocr <- TRUE) repeats the 1951 and 1964 OCR from the PDFs and
#   rewrites ocr_support/ocr_grid_1951_*.csv and ocr_grid_1964_*.csv (needs
#   the PDFs, tesseract, magick and pdftools; about 10 minutes for 1951, 40
#   for the five passes of 1964 Cuadros 7 and 9 and the same for the three
#   passes of Cuadro 14).
# Stage B (always) builds the tables from ocr_support/ and stops if any
#   identity fails.
#
# output: data_input/historical/census_tables/
#   census1938_single_age_sex.csv            national, ages 0-98, 99+, indígena
#   census1951_dept_age5_sex_1938_1951.csv   1938 and 1951, 29 territorial rows
#   census1964_dept_age5_sex_zone.csv        1964, 28 territorial rows x 3 zones
#   census1964_single_age_sex_zone.csv       1964, national, ages 0-98, 99+, 3 zones
#   census1964_birthplace_by_residence.csv   1964, place of birth x place of residence
#                                            x sex x 3 broad ages (+ total)
#   census1973_single_age_sex.csv            national censused population
#   census1973_adjusted_population_units.csv coverage-adjusted, 31 units x 3 zones
#   census1973_children_ever_born_age.csv    women 15+, children ever born and
#                                            surviving, 8 age groups x 3 zones
#   census1973_children_ever_born_units.csv  same, 31 units x 3 zones (no age)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))
options(width = 160)

run_ocr <- FALSE
pdf_dir <- "data_input/dane_pdfs/censos/"
out_dir <- "data_input/historical/census_tables/"
sup_dir <- paste0(out_dir, "ocr_support/")
dir.create(sup_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# Stage A: OCR of the 1951 Cuadro 10 pages (optional)
# ============================================================================
if (run_ocr) {
  suppressPackageStartupMessages({library(tesseract); library(magick); library(pdftools)})
  eng6 <- tesseract("eng", options = list(preserve_interword_spaces = "1", tessedit_pageseg_mode = "6"))
  eng7 <- tesseract("eng", options = list(tessedit_pageseg_mode = "7", tessedit_char_whitelist = "0123456789.,"))

  clean_num   <- function(w) { w <- gsub("[^0-9.,]", "", w); gsub("^[.,]+|[.,]+$", "", w) }
  well_formed <- function(w) grepl("^[0-9]{1,3}([.,][0-9]{3})*$", w)
  to_num      <- function(w) suppressWarnings(as.numeric(gsub("[.,]", "", w)))
  cluster     <- function(v, tol) { o <- order(v); g <- cumsum(c(1, diff(v[o]) > tol)); r <- integer(length(v)); r[o] <- g; r }

  # one cell re-read with the digit-only engine
  cell_ocr <- function(img, x1, y1, x2, y2, pad = 8) {
    info <- image_info(img)
    x1 <- max(1, x1 - pad); y1 <- max(1, y1 - pad); x2 <- min(info$width, x2 + pad); y2 <- min(info$height, y2 + pad)
    crop <- image_crop(img, sprintf("%dx%d+%d+%d", x2 - x1, y2 - y1, x1, y1)) |> image_border("white", "20x20")
    clean_num(str_trim(ocr(crop, engine = eng7)))
  }
  # words with boxes; rows by y centre, clusters spanning more than a line are split in two
  words_page <- function(img) {
    d <- ocr_data(img, engine = eng6) |>
      separate(bbox, c("x1", "y1", "x2", "y2"), sep = ",", convert = TRUE) |>
      mutate(h = y2 - y1, yc = (y1 + y2) / 2, raw = word, word = gsub("[^0-9.,]", "", word), numeric = grepl("[0-9]", word)) |>
      filter(h > 8)
    hh <- median(d$h[d$numeric])
    d <- d |> mutate(row = cluster(yc, hh * 0.5))
    spread <- d |> group_by(row) |> summarise(s = max(yc) - min(yc), .groups = "drop") |> filter(s > 0.9 * hh)
    for (r in spread$row) { i <- which(d$row == r); k <- kmeans(d$yc[i], centers = 2)$cluster; d$row[i] <- r + (k - 1) * 0.5 }
    d |> mutate(row = as.integer(factor(row))) |> arrange(row, x1)
  }
  # numeric tokens split at a thousands separator: same row and line, small positive gap
  merge_split <- function(w, hh) {
    w <- w |> arrange(row, x1)
    repeat {
      merged <- FALSE
      for (i in seq_len(nrow(w) - 1)) {
        if (!w$numeric[i] || !w$numeric[i + 1] || w$row[i] != w$row[i + 1]) next
        gap <- w$x1[i + 1] - w$x2[i]; dy <- abs(w$yc[i + 1] - w$yc[i])
        a <- clean_num(w$word[i]); b <- clean_num(w$word[i + 1])
        sep <- grepl("[.,]$", w$word[i]) || grepl("^[.,]", w$word[i + 1])
        cond <- (sep && gap >= -2 && gap <= 2.2 * hh) ||
          (grepl("^[0-9]{1,3}$", a) && grepl("^[0-9]{3}([.,][0-9]{3})*$", b) && gap >= 0 && gap <= 1.1 * hh)
        if (dy < 0.5 * hh && cond) {
          w$word[i] <- paste0(a, ".", b); w$raw[i] <- paste(w$raw[i], w$raw[i + 1])
          w$x2[i] <- w$x2[i + 1]; w$y1[i] <- min(w$y1[i], w$y1[i + 1]); w$y2[i] <- max(w$y2[i], w$y2[i + 1])
          w$confidence[i] <- min(w$confidence[i], w$confidence[i + 1])
          w <- w[-(i + 1), ]; merged <- TRUE; break
        }
      }
      if (!merged) break
    }
    w |> mutate(word = clean_num(word))
  }
  # grid of one page: the `ncol` rightmost numeric columns, label = words left of them
  # dense tables (1964, line pitch ~1.1 x digit height): rows from the baseline of the numeric tokens,
  # the other words join the nearest row
  words_page_dense <- function(img) {
    d <- ocr_data(img, engine = eng6) |>
      separate(bbox, c("x1", "y1", "x2", "y2"), sep = ",", convert = TRUE) |>
      mutate(h = y2 - y1, yc = (y1 + y2) / 2, raw = word, word = gsub("[^0-9.,]", "", word), numeric = grepl("[0-9]", word)) |>
      filter(h > 8)
    hh <- median(d$h[d$numeric & nchar(d$word) >= 3])
    big <- d$numeric & d$h > 0.7 * hh & d$h < 1.4 * hh
    rid <- rep(NA_integer_, nrow(d)); rid[big] <- cluster(d$y2[big], hh * 0.3)
    rc <- tapply(d$y2[big], rid[big], median)
    for (i in which(!big)) { k <- which.min(abs(rc - d$y2[i])); if (abs(rc[k] - d$y2[i]) < 0.45 * hh) rid[i] <- as.integer(names(rc)[k]) }
    d <- d[!is.na(rid), ]; d$row <- as.integer(factor(rank(rc)[as.character(rid[!is.na(rid)])]))
    d |> arrange(row, x1)
  }
  grid_page <- function(png, ncol, col_tol = 40, min_conf = 80, min_share = 0.25, words_fun = words_page) {
    img <- image_read(png)
    w <- words_fun(img); hh <- median(w$h[w$numeric]); w <- merge_split(w, hh)
    v <- w |> filter(numeric, nchar(word) > 0) |> mutate(col0 = cluster(x2, col_tol))
    nrows <- n_distinct(v$row)
    centres <- v |> group_by(col0) |> summarise(xr = median(x2), n = n(), .groups = "drop") |> filter(n >= min_share * nrows) |>
      arrange(desc(xr)) |> slice_head(n = ncol) |> arrange(xr) |> mutate(col = row_number())
    v <- v |> mutate(col = map_int(x2, \(x) { d <- abs(centres$xr - x); if (min(d) <= 2.5 * col_tol) centres$col[which.min(d)] else NA_integer_ })) |>
      filter(!is.na(col)) |> mutate(redo = confidence < min_conf | !well_formed(word), word2 = NA_character_)
    for (i in which(v$redo)) v$word2[i] <- cell_ocr(img, v$x1[i], v$y1[i], v$x2[i], v$y2[i])
    v <- v |> mutate(word_final = case_when(well_formed(word) & confidence >= min_conf ~ word,
                                            well_formed(word2) & !well_formed(word) ~ word2,
                                            well_formed(word) ~ word, TRUE ~ coalesce(word2, word)),
                     value = to_num(word_final), ok = well_formed(word_final))
    xlab <- v |> filter(col == 1) |> summarise(q = quantile(x1, 0.1)) |> pull(q)
    labels <- w |> filter(x2 < xlab) |> group_by(row) |> summarise(label = paste(raw, collapse = " "), .groups = "drop")
    wide <- v |> group_by(row, col) |> summarise(value = if (n() == 1 && first(ok)) first(value) else NA_real_, .groups = "drop") |>
      pivot_wider(names_from = col, values_from = value, names_prefix = "c") |> left_join(labels, by = "row") |> arrange(row)
    for (k in seq_len(ncol)) if (!paste0("c", k) %in% names(wide)) wide[[paste0("c", k)]] <- NA_real_
    yc <- v |> group_by(row) |> summarise(yc = mean((y1 + y2) / 2), .groups = "drop")
    wide |> left_join(yc, by = "row") |> mutate(hh = median(v$y2 - v$y1)) |> select(row, label, all_of(paste0("c", 1:ncol)), yc, hh)
  }

  tmp <- file.path(tempdir(), "census_ocr"); dir.create(tmp, showWarnings = FALSE)
  pdf <- paste0(pdf_dir, "1951/LD_771_1951.pdf"); stopifnot(file.exists(pdf))
  for (pass in c("500dpi_bw", "300dpi")) {
    dpi <- if (pass == "300dpi") 300 else 500
    grids <- map_dfr(22:32, \(p) {
      png <- sprintf("%s/c1951_p%03d_%d.png", tmp, p, dpi)
      if (!file.exists(png)) suppressWarnings(pdf_convert(pdf, format = "png", pages = p, dpi = dpi, filenames = png, verbose = FALSE))
      if (pass == "500dpi_bw") {
        bw <- sub(".png$", "_bw.png", png)
        image_read(png) |> image_convert(colorspace = "gray") |> image_threshold("white", "60%") |> image_threshold("black", "40%") |> image_write(bw)
        png <- bw
      }
      cat("  OCR", pass, "page", p, "\n")
      grid_page(png, ncol = 6) |> mutate(page = p, .before = 1)
    })
    write_csv(grids, paste0(sup_dir, "ocr_grid_1951_", pass, ".csv"), na = "NA")
  }

  # 1964, Cuadros 7 (pp. 26-32) and 9 (pp. 35-36): five passes on the deskewed page, nine numeric columns
  pdf <- paste0(pdf_dir, "1964/LD_771_1964.pdf"); stopifnot(file.exists(pdf))
  for (pass in c("500dpi_bw", "600dpi", "500dpi", "400dpi", "300dpi")) {
    dpi <- as.integer(sub("dpi.*", "", pass))
    grids <- map_dfr(c(26:32, 35, 36), \(p) {
      raw <- sprintf("%s/c1964_p%03d_%d.png", tmp, p, dpi); png <- sprintf("%s/c1964_p%03d_%s_dsk.png", tmp, p, pass)
      if (!file.exists(raw)) suppressWarnings(pdf_convert(pdf, format = "png", pages = p, dpi = dpi, filenames = raw, verbose = FALSE))
      x <- image_read(raw) |> image_convert(colorspace = "gray") |> image_deskew(threshold = 40) |> image_background("white")
      if (grepl("bw", pass)) x <- x |> image_threshold("white", "60%") |> image_threshold("black", "40%")
      image_write(x, png)
      cat("  OCR 1964", pass, "page", p, "\n")
      grid_page(png, ncol = 9, words_fun = words_page_dense) |> mutate(page = p, .before = 1)
    })
    write_csv(grids, paste0(sup_dir, "ocr_grid_1964_", pass, ".csv"), na = "NA")
  }

  # 1964, Cuadro 14 (pp. 49-61 and 63; p. 62 is a chart): three passes, nine numeric columns. The right-hand pages (even)
  # repeat the row labels on the right: the deskewed page is cropped to 76.5 % of its width before the OCR.
  right14 <- c(50, 52, 54, 56, 58, 60)
  for (pass in c("500dpi_bw", "400dpi", "300dpi")) {
    dpi <- as.integer(sub("dpi.*", "", pass))
    grids <- map_dfr(c(49:61, 63), \(p) {
      raw <- sprintf("%s/c1964_p%03d_%d.png", tmp, p, dpi); png <- sprintf("%s/c1964_p%03d_%s_dsk.png", tmp, p, pass)
      if (!file.exists(raw)) suppressWarnings(pdf_convert(pdf, format = "png", pages = p, dpi = dpi, filenames = raw, verbose = FALSE))
      x <- image_read(raw) |> image_convert(colorspace = "gray") |> image_deskew(threshold = 40) |> image_background("white")
      if (p %in% right14) { ii <- image_info(x); x <- image_crop(x, sprintf("%dx%d+0+0", round(0.765 * ii$width), ii$height)) }
      if (grepl("bw", pass)) x <- x |> image_threshold("white", "60%") |> image_threshold("black", "40%")
      image_write(x, png)
      cat("  OCR 1964 Cuadro 14", pass, "page", p, "\n")
      grid_page(png, ncol = 9, words_fun = words_page_dense) |> mutate(page = p, .before = 1)
    })
    write_csv(grids, paste0(sup_dir, "ocr_grid_1964_c14_", pass, ".csv"), na = "NA")
  }
}

# ============================================================================
# Stage B: build and validate the tables
# ============================================================================
chk <- function(ok, msg) { if (!isTRUE(all(ok))) stop("identity failed: ", msg) else cat("  ok:", msg, "\n") }

# ---- 1938, Cuadro 28: single ages x sex (visual transcription) --------------
cat("1938 Cuadro 28\n")
c38 <- read_csv(paste0(sup_dir, "transcription_1938_cuadro28.csv"), show_col_types = FALSE, col_types = "cddd") |>
  rename(male = h, female = m, total = t) |>
  mutate(age_start = suppressWarnings(as.integer(if_else(age == "99+", "99", age))), .after = age)
chk(c38$total == c38$male + c38$female, "1938 total = hombres + mujeres in every age")
chk(colSums(c38[, c("male", "female", "total")]) == c(4312763, 4389053, 8701816), "1938 column sums = published grand totals")
write_csv(c38 |> mutate(census_year = 1938, .before = 1), paste0(out_dir, "census1938_single_age_sex.csv"), na = "")

# ---- 1951, Cuadro 10: department x 5-year age x sex, 1938 and 1951 -----------
cat("1951 Cuadro 10\n")
ages <- c("<1", "1-4", paste(seq(5, 90, 5), seq(9, 94, 5), sep = "-"), "95+")
cols <- c("t1938", "t1951", "h1938", "h1951", "f1938", "f1951")
sections <- tribble(~section, ~unit_type,
  "Total nacional", "total", "Total departamentos", "total", "Total intendencias", "total", "Total comisarías", "total",
  "Antioquia", "departamento", "Atlántico", "departamento", "Bolívar", "departamento", "Boyacá", "departamento",
  "Caldas", "departamento", "Cauca", "departamento", "Cundinamarca", "departamento", "Chocó", "departamento",
  "Huila", "departamento", "Magdalena", "departamento", "Nariño", "departamento", "Norte de Santander", "departamento",
  "Santander", "departamento", "Tolima", "departamento", "Valle del Cauca", "departamento",
  "Caquetá", "intendencia", "Meta", "intendencia", "San Andrés y Providencia", "intendencia",
  "Amazonas", "comisaría", "Arauca", "comisaría", "Casanare", "comisaría", "Guajira", "comisaría",
  "Putumayo", "comisaría", "Vaupés", "comisaría", "Vichada", "comisaría")

# rows of one OCR pass: merge rows split in two lines, drop footnotes and year rows, locate the 29 headers
rows_from <- function(all) {
  all <- all |>
    mutate(nval = rowSums(!is.na(across(c1:c6))),
           yearrow = rowSums(across(c1:c6, \(v) !is.na(v) & v %in% c(1938, 1951, 195, 193, 19381951))) >= 3,
           nwords = str_count(coalesce(label, ""), "[A-Za-z]{3,}"),
           footnote = nval <= 2 & nwords >= 3) |>
    filter(nval >= 1, !yearrow, !footnote) |> arrange(page, yc)
  i <- 1
  while (i < nrow(all)) {
    j <- i + 1
    if (all$page[i] == all$page[j] && (all$yc[j] - all$yc[i]) < 0.9 * all$hh[i]) {
      a <- unlist(all[i, paste0("c", 1:6)]); b <- unlist(all[j, paste0("c", 1:6)])
      if (!any(!is.na(a) & !is.na(b))) {
        all[i, paste0("c", 1:6)] <- as.list(coalesce(a, b)); all$label[i] <- paste(coalesce(all$label[i], ""), coalesce(all$label[j], ""))
        all$nval[i] <- sum(!is.na(coalesce(a, b))); all <- all[-j, ]; next
      }
    }
    i <- i + 1
  }
  all <- all |> mutate(seq = row_number())
  hdr <- which(grepl("[A-Z]{4,}", all$label) & all$nval >= 3 & !is.na(all$c1) & all$c1 > 3000)
  if (length(hdr) != nrow(sections)) stop("1951: ", length(hdr), " section headers found instead of ", nrow(sections))
  hdr_seq <- all$seq[hdr]
  all |> filter(seq >= hdr_seq[1]) |> mutate(section = sections$section[findInterval(seq, hdr_seq)], is_header = seq %in% hdr_seq)
}
age_from_label <- function(lab) {
  lab <- tolower(coalesce(lab, ""))
  if (grepl("menores", lab)) return("<1")
  if (grepl("95", lab)) return("95+")
  d <- as.integer(str_extract_all(gsub("[^0-9 ]", " ", lab), "[0-9]+")[[1]])
  for (a in ages[-c(1, 21)]) { b <- as.integer(str_split(a, "-")[[1]]); if (length(d) >= 2 && d[1] == b[1] && d[2] == b[2]) return(a) }
  for (a in ages[-c(1, 21)]) { b <- as.integer(str_split(a, "-")[[1]]); if (length(d) >= 1 && d[1] == b[1] && b[1] >= 5) return(a) }
  NA_character_
}
# 21 x 6 matrix and header of one section
block <- function(all, s) {
  blk <- all |> filter(section == s); hdr <- blk |> filter(is_header); rows <- blk |> filter(!is_header)
  rows$age <- map_chr(rows$label, age_from_label)
  if (nrow(rows) == 21) rows$age <- ages else {
    known <- rows$age; miss <- setdiff(ages, known[!is.na(known)]); k <- which(is.na(known))
    rows$age[k] <- c(miss, rep(NA, length(k)))[seq_along(k)]
    rows <- rows |> filter(!is.na(age)) |> group_by(age) |> slice(1) |> ungroup()
  }
  m <- matrix(NA_real_, 21, 6, dimnames = list(ages, cols))
  for (i in seq_len(nrow(rows))) m[rows$age[i], ] <- unlist(rows[i, paste0("c", 1:6)])
  tot <- unlist(hdr[1, paste0("c", 1:6)]); names(tot) <- cols
  list(m = m, tot = tot)
}

grid_types <- cols(label = col_character(), .default = col_double())
allA <- rows_from(read_csv(paste0(sup_dir, "ocr_grid_1951_500dpi_bw.csv"), show_col_types = FALSE, col_types = grid_types))
allB <- rows_from(read_csv(paste0(sup_dir, "ocr_grid_1951_300dpi.csv"), show_col_types = FALSE, col_types = grid_types))
corr <- read_csv(paste0(sup_dir, "corrections_1951.csv"), show_col_types = FALSE, col_types = "cccd")

res51 <- list(); problems <- character()
for (s in sections$section) {
  A <- block(allA, s); B <- block(allB, s); m <- A$m; tot <- A$tot
  cs <- corr |> filter(section == s)
  for (k in seq_len(nrow(cs))) if (cs$age[k] == "total") tot[cs$col[k]] <- cs$value[k] else m[cs$age[k], cs$col[k]] <- cs$value[k]
  fixed <- if (nrow(cs)) paste(cs$age, cs$col) else character()
  years <- if (s == "Vichada") "1938" else c("1938", "1951")     # Vichada: dashes in 1951
  for (it in 1:8) for (yr in years) {
    tc <- paste0("t", yr); hc <- paste0("h", yr); fc <- paste0("f", yr); trio <- c(tc, hc, fc)
    # candidates from the second pass: the unique combination satisfying t = h + f
    for (a in ages) {
      v <- m[a, trio]
      if (!any(is.na(v)) && v[1] == v[2] + v[3]) next
      cand <- map(trio, \(cc) if (paste(a, cc) %in% fixed) m[a, cc] else unique(na.omit(c(m[a, cc], B$m[a, cc]))))
      if (any(lengths(cand) == 0)) next
      combos <- expand.grid(cand) |> filter(Var1 == Var2 + Var3)
      if (nrow(combos) == 1) m[a, trio] <- unlist(combos)
    }
    # one missing cell in a row
    for (a in ages) { v <- m[a, trio]
      if (sum(is.na(v)) == 1) { if (is.na(v[1])) m[a, tc] <- v[2] + v[3] else if (is.na(v[2])) m[a, hc] <- v[1] - v[3] else m[a, fc] <- v[1] - v[2] } }
    for (cc in trio) if (is.na(tot[cc]) && !is.na(B$tot[cc])) tot[cc] <- B$tot[cc]
    res <- sapply(trio, \(cc) if (any(is.na(m[, cc])) || is.na(tot[cc])) NA else tot[cc] - sum(m[, cc]))
    for (cc in trio) if (!is.na(res[cc]) && res[cc] != 0 && !is.na(B$tot[cc]) && B$tot[cc] == sum(m[, cc])) { tot[cc] <- B$tot[cc]; res[cc] <- 0 }
    # a row failing t = h + f whose difference equals the column residual: fix that cell
    bad <- which(!is.na(m[, tc]) & !is.na(m[, hc]) & !is.na(m[, fc]) & m[, tc] != m[, hc] + m[, fc])
    for (a in names(bad)) {
      d <- m[a, tc] - m[a, hc] - m[a, fc]; nz <- sum(res != 0, na.rm = TRUE)
      if (nz == 1 && !is.na(res[tc]) && res[tc] == -d) m[a, tc] <- m[a, tc] - d
      else if (nz == 1 && !is.na(res[hc]) && res[hc] == d) m[a, hc] <- m[a, hc] + d
      else if (nz == 1 && !is.na(res[fc]) && res[fc] == d) m[a, fc] <- m[a, fc] + d
      res <- sapply(trio, \(cc) if (any(is.na(m[, cc])) || is.na(tot[cc])) NA else tot[cc] - sum(m[, cc]))
    }
    for (cc in trio) if (sum(is.na(m[, cc])) == 1 && !is.na(tot[cc])) m[which(is.na(m[, cc])), cc] <- tot[cc] - sum(m[, cc], na.rm = TRUE)
    for (cc in trio) if (is.na(tot[cc]) && !any(is.na(m[, cc]))) tot[cc] <- sum(m[, cc])
  }
  for (yr in years) {
    tc <- paste0("t", yr); hc <- paste0("h", yr); fc <- paste0("f", yr)
    if (any(is.na(m[, c(tc, hc, fc)])) || any(m[, tc] != m[, hc] + m[, fc])) problems <- c(problems, paste(s, yr, "rows"))
    for (cc in c(tc, hc, fc)) if (is.na(tot[cc]) || tot[cc] != sum(m[, cc])) problems <- c(problems, paste(s, cc, "header"))
  }
  res51[[s]] <- as_tibble(m, rownames = "age") |> mutate(section = s, .before = 1) |>
    bind_rows(tibble(section = s, age = "total", !!!as.list(tot)))
}
if (length(problems)) stop("1951 unresolved: ", paste(problems, collapse = "; "))
cat("  ok: 1951 every row has total = hombres + mujeres and every section adds to its header\n")
res51 <- bind_rows(res51)
hd <- res51 |> filter(age == "total") |> left_join(sections, by = "section")
for (cc in cols) {
  chk(sum(hd[[cc]][hd$unit_type == "departamento"]) == hd[[cc]][hd$section == "Total departamentos"], paste("1951", cc, "departamentos = total departamentos"))
  chk(sum(hd[[cc]][hd$unit_type == "intendencia"]) == hd[[cc]][hd$section == "Total intendencias"], paste("1951", cc, "intendencias = total intendencias"))
  chk(sum(hd[[cc]][hd$unit_type == "comisaría"], na.rm = TRUE) == hd[[cc]][hd$section == "Total comisarías"], paste("1951", cc, "comisarías = total comisarías"))
  chk(sum(hd[[cc]][hd$section %in% c("Total departamentos", "Total intendencias", "Total comisarías")]) == hd[[cc]][hd$section == "Total nacional"], paste("1951", cc, "three groups = total nacional"))
}
c51 <- res51 |> left_join(sections, by = "section") |>
  pivot_longer(all_of(cols), names_to = c("sex", "census_year"), names_pattern = "([thf])(19..)", values_to = "pop") |>
  mutate(sex = c(t = "total", h = "male", f = "female")[sex], census_year = as.integer(census_year)) |>
  pivot_wider(names_from = sex, values_from = pop) |>
  transmute(census_year, unit = section, unit_type, age,
            age_start = case_when(age == "<1" ~ 0L, age == "total" ~ NA_integer_, TRUE ~ as.integer(str_extract(age, "^[0-9]+"))),
            male, female, total) |>
  arrange(census_year, factor(unit, sections$section), factor(age, c(ages, "total")))
write_csv(c51, paste0(out_dir, "census1951_dept_age5_sex_1938_1951.csv"), na = "")

# ---- 1973, Cuadro 2: single ages x sex, censused population (transcription) --
cat("1973 Cuadro 2\n")
c73 <- read_csv(paste0(sup_dir, "transcription_1973_cuadro2.csv"), show_col_types = FALSE, col_types = "cddd") |>
  rename(total = t, male = h, female = m) |>
  mutate(age_start = as.integer(if_else(age == "99+", "99", age)), .after = age)
g73 <- read_csv(paste0(sup_dir, "transcription_1973_cuadro2_groups.csv"), show_col_types = FALSE, col_types = "cddd")
chk(c73$total == c73$male + c73$female, "1973 total = hombres + mujeres in every age")
chk(g73$t == g73$h + g73$m, "1973 printed group rows: total = hombres + mujeres")
grp <- c73 |> mutate(group = case_when(age_start == 0 ~ "0", age_start <= 4 ~ "1-4", age_start >= 95 ~ "95+",
                                       TRUE ~ paste0(age_start %/% 5 * 5, "-", age_start %/% 5 * 5 + 4))) |>
  group_by(group) |> summarise(across(c(total, male, female), sum)) |> inner_join(g73, by = "group")
chk(grp$total == grp$t & grp$male == grp$h & grp$female == grp$m, "1973 single ages add to every printed 5-year row")
chk(colSums(c73[, c("total", "male", "female")]) == unlist(g73[g73$group == "total", c("t", "h", "m")]), "1973 column sums = printed grand total 20,666,920")
write_csv(c73 |> mutate(census_year = 1973, .before = 1) |> select(census_year, age, age_start, male, female, total),
          paste0(out_dir, "census1973_single_age_sex.csv"))

# ---- 1973, chapter VIII: coverage-adjusted population by unit and zone -------
cat("1973 capítulo VIII\n")
units73 <- read_csv(paste0(sup_dir, "transcription_1973_cap8_units.csv"), show_col_types = FALSE, col_types = "ccdddd") |>
  rename(private_households = particulares, collective_households = colectivos, indigenous_areas = indigenas) |>
  mutate(unit_type = case_when(unit == "Bogotá D.E." ~ "distrito especial",
                               unit %in% c("Arauca", "Caquetá", "Putumayo", "San Andrés y Providencia") ~ "intendencia",
                               unit %in% c("Amazonas", "Guainía", "Vaupés", "Vichada") ~ "comisaría",
                               TRUE ~ "departamento"), .after = unit)
chk(units73$total == units73$private_households + units73$collective_households + units73$indigenous_areas, "1973 adjusted total = particulares + colectivos + indígenas")
zz <- units73 |> group_by(unit) |> summarise(across(c(total, private_households, collective_households, indigenous_areas),
                                                     \(v) v[zone == "total"] - v[zone == "cabecera"] - v[zone == "resto"]))
chk(unlist(zz[, -1]) == 0, "1973 adjusted total = cabecera + resto in every unit")
nat <- units73 |> filter(zone == "total") |> mutate(g = if_else(unit_type %in% c("departamento", "distrito especial"), "dep", "ic")) |>
  group_by(g) |> summarise(across(c(total, private_households, collective_households, indigenous_areas), sum))
chk(unlist(nat[nat$g == "dep", -1]) == c(22487118, 21739428, 384257, 363433), "1973 departamentos + D.E. = Cuadro VIII.20 (22,487,118)")
chk(unlist(nat[nat$g == "ic", -1]) == c(375000, 281129, 4658, 89213), "1973 intendencias + comisarías = Cuadro VIII.20 (375,000)")
write_csv(units73 |> mutate(census_year = 1973, .before = 1), paste0(out_dir, "census1973_adjusted_population_units.csv"))
# ---- 1973, Cuadros 21 and 21A: children ever born and surviving --------------
# Women aged 15+ in private and collective households (indigenous areas are
# not in this tabulation, hence the very small comisarías), censused counts.
cat("1973 Cuadros 21 y 21A\n")
ceb_cols <- c("women", "not_stated", "childless", "mothers", "children_ever_born", "children_surviving")
ceb_age <- read_csv(paste0(sup_dir, "transcription_1973_cuadro21.csv"), show_col_types = FALSE, col_types = "ccdddddd")
ceb_unit <- read_csv(paste0(sup_dir, "transcription_1973_cuadro21A.csv"), show_col_types = FALSE, col_types = "ccdddddd")
chk(ceb_age$women == ceb_age$not_stated + ceb_age$childless + ceb_age$mothers, "1973 C21 women = no informan + sin hijos + con hijos")
nat21 <- ceb_age |> filter(age == "total") |> arrange(zone)
age21 <- ceb_age |> filter(age != "total") |> group_by(zone) |> summarise(across(all_of(ceb_cols), sum)) |> arrange(zone)
chk(as.matrix(age21[, ceb_cols]) == as.matrix(nat21[, ceb_cols]), "1973 C21 the eight age groups add to the TOTAL row in every zone")
zone_gap <- function(d, by) d |> group_by(.data[[by]]) |>
  summarise(across(all_of(ceb_cols), \(v) v[zone == "total"] - v[zone == "cabecera"] - v[zone == "resto"]))
chk(as.matrix(zone_gap(ceb_age, "age")[, ceb_cols]) == 0, "1973 C21 total = cabecera + resto in every age group")
chk(ceb_unit$women == ceb_unit$not_stated + ceb_unit$childless + ceb_unit$mothers, "1973 C21A women = no informan + sin hijos + con hijos")
chk(as.matrix(zone_gap(ceb_unit, "unit")[, ceb_cols]) == 0, "1973 C21A total = cabecera + resto in every unit")
unit21 <- ceb_unit |> group_by(zone) |> summarise(across(all_of(ceb_cols), sum)) |> arrange(zone)
chk(as.matrix(unit21[, ceb_cols]) == as.matrix(nat21[, ceb_cols]), "1973 C21A the 31 units add to the national rows of Cuadro 21 in every zone")
write_csv(ceb_age |> mutate(census_year = 1973, .before = 1) |>
            mutate(age_start = if_else(age == "total", NA_integer_, as.integer(str_extract(age, "^[0-9]+"))), .after = age),
          paste0(out_dir, "census1973_children_ever_born_age.csv"), na = "")
write_csv(ceb_unit |> mutate(census_year = 1973, .before = 1) |>
            mutate(unit_type = case_when(unit == "Bogotá D.E." ~ "distrito especial",
                                         unit %in% c("Arauca", "Caquetá", "Putumayo", "San Andrés y Providencia") ~ "intendencia",
                                         unit %in% c("Amazonas", "Guainía", "Vaupés", "Vichada") ~ "comisaría",
                                         TRUE ~ "departamento"), .after = unit),
          paste0(out_dir, "census1973_children_ever_born_units.csv"))
# ---- 1964, Cuadros 7 and 9: age x sex x zone, by unit and by single age -------
# Each printed row has nine cells, (total, cabecera, resto) x (total, hombres, mujeres), tied by six
# identities: total = hombres + mujeres in each zone and total = cabecera + resto for each sex. The five
# OCR passes give the candidate readings of every cell; the row is the combination that satisfies the
# six identities (the best supported one if several do), or the majority reading with one or two cells
# replaced by what the identities imply. Rows that stay open were read by eye (corrections_1964_rows.csv).
cat("1964 Cuadros 7 y 9\n")
passes64 <- c("500dpi_bw", "600dpi", "500dpi", "400dpi", "300dpi")
dpi64 <- setNames(as.numeric(sub("dpi.*", "", passes64)), passes64)
cols9 <- c("tot_t", "tot_h", "tot_m", "cab_t", "cab_h", "cab_m", "res_t", "res_h", "res_m")
cc9 <- paste0("c", 1:9)
ages64 <- c("<1", "1-4", paste(seq(5, 80, 5), seq(9, 84, 5), sep = "-"), "85+")
single64 <- c(0:98, "99+")
units64 <- tribble(~unit, ~unit_type,
  "Total en el País", "total", "Antioquia", "departamento", "Atlántico", "departamento", "Bolívar", "departamento", "Boyacá", "departamento",
  "Caldas", "departamento", "Cauca", "departamento", "Córdoba", "departamento", "Bogotá D.E.", "distrito especial", "Cundinamarca", "departamento",
  "Chocó", "departamento", "Huila", "departamento", "Magdalena", "departamento", "Meta", "departamento", "Nariño", "departamento",
  "Norte de Santander", "departamento", "Santander", "departamento", "Tolima", "departamento", "Valle del Cauca", "departamento",
  "Arauca", "intendencia", "Caquetá", "intendencia", "Guajira", "intendencia", "San Andrés y Providencia", "intendencia",
  "Amazonas", "comisaría", "Guainía", "comisaría", "Putumayo", "comisaría", "Vaupés", "comisaría", "Vichada", "comisaría")
G64 <- map(setNames(passes64, passes64), \(p) read_csv(paste0(sup_dir, "ocr_grid_1964_", p, ".csv"), show_col_types = FALSE, col_types = grid_types))
# data rows of one page per pass: a pass with the expected number of rows is taken in page order, the
# others are matched to the first such pass by vertical position (in inches)
page_mats <- function(page, expected) {
  R <- map(passes64, \(p) { r <- G64[[p]]; r <- r[r$page == page, ]; r$n <- rowSums(!is.na(r[, cc9])); r <- r[r$n >= 1, ]; r$y <- r$yc / dpi64[[p]]; r[order(r$y), ] })
  ok <- map_lgl(R, \(r) sum(r$n >= 3) == expected); stopifnot(any(ok))
  ref_y <- { r <- R[[which(ok)[1]]]; r$y[r$n >= 3] }; pitch <- median(diff(ref_y))
  near <- \(y) ref_y[max(1, findInterval(y, (ref_y[-1] + ref_y[-length(ref_y)]) / 2) + 1)]
  map(seq_along(passes64), \(i) { r <- R[[i]]
    if (ok[i]) return(as.matrix(r[r$n >= 3, cc9]))
    r$y <- r$y - median(r$y[r$n >= 3] - map_dbl(r$y[r$n >= 3], near))
    m <- matrix(NA_real_, expected, 9)
    for (k in seq_len(expected)) { j <- which(abs(r$y - ref_y[k]) < 0.4 * pitch); if (!length(j)) next
      m[k, ] <- apply(as.matrix(r[j, cc9]), 2, \(z) { z <- unique(na.omit(z)); if (length(z) == 1) z else NA_real_ }) }
    m })
}
eqs <- list(c(1, 2, 3), c(4, 5, 6), c(7, 8, 9), c(1, 4, 7), c(2, 5, 8), c(3, 6, 9))      # x[a] = x[b] + x[c]
propagate <- function(x) {
  repeat { ch <- FALSE
    for (e in eqs) { v <- x[e]
      if (sum(is.na(v)) == 1) { k <- which(is.na(v)); x[e[k]] <- if (k == 1) v[2] + v[3] else v[1] - v[5 - k]; ch <- TRUE } }
    if (!ch) break }
  x
}
valid33 <- function(x) !anyNA(x) && all(x >= 0) && all(vapply(eqs, \(e) x[e[1]] == x[e[2]] + x[e[3]], logical(1)))
solve33 <- function(P, fixed) {                              # P: passes x 9 readings of one row
  cand <- lapply(1:9, \(i) if (!is.na(fixed[i])) fixed[i] else { v <- na.omit(P[, i]); if (length(v)) head(as.numeric(names(sort(table(v), decreasing = TRUE))), 3) else NA_real_ })
  mode1 <- vapply(cand, \(v) v[1], numeric(1)); free <- which(is.na(fixed))
  support <- \(x) sum(vapply(1:9, \(i) sum(P[, i] == x[i], na.rm = TRUE), numeric(1)))
  best <- function(S, margin = 0) { if (is.null(S)) return(NULL); if (nrow(S) == 1) return(as.numeric(S))
    sc <- apply(S, 1, support); o <- order(sc, decreasing = TRUE); if (sc[o[1]] - sc[o[2]] > margin) as.numeric(S[o[1], ]) else NULL }
  try_cells <- \(x0, cells) { x <- x0; x[cells] <- NA; x <- propagate(x); if (valid33(x)) x else NULL }
  gr <- as.matrix(expand.grid(cand))
  s <- best(unique(do.call(rbind, lapply(seq_len(nrow(gr)), \(r) try_cells(gr[r, ], integer())))))
  if (!is.null(s)) return(list(x = s, how = "direct"))
  s <- unique(do.call(rbind, lapply(free, \(i) try_cells(mode1, i))))
  if (!is.null(s) && nrow(s) == 1) return(list(x = as.numeric(s), how = "one cell"))
  if (nrow(gr) > 1 && nrow(gr) <= 1500) {
    s <- best(unique(do.call(rbind, lapply(seq_len(nrow(gr)), \(r) do.call(rbind, lapply(free, \(i) try_cells(gr[r, ], i)))))), margin = 1)
    if (!is.null(s)) return(list(x = s, how = "one cell"))
  }
  if (length(free) >= 2) {
    pr <- combn(free, 2); s <- unique(do.call(rbind, lapply(seq_len(ncol(pr)), \(k) try_cells(mode1, pr[, k]))))
    if (!is.null(s) && nrow(s) == 1) return(list(x = as.numeric(s), how = "two cells"))
  }
  list(x = rep(NA_real_, 9), how = "unsolved")
}
corr64 <- read_csv(paste0(sup_dir, "corrections_1964_rows.csv"), show_col_types = FALSE, col_types = "cccddddddddd")
build64 <- function(A, tab, ages, unit_names) {              # A[[pass]][unit, row, cell]
  rn <- c("total", ages)
  map_dfr(seq_along(unit_names), \(s) {
    m <- matrix(NA_real_, length(rn), 9, dimnames = list(rn, cols9)); how <- character(length(rn))
    for (r in seq_along(rn)) {
      fx <- corr64 |> filter(table == tab, unit == unit_names[s], age == rn[r])
      fixed <- if (nrow(fx)) unlist(fx[1, cols9]) else rep(NA_real_, 9)
      z <- solve33(do.call(rbind, map(A, \(a) a[s, r, ])), fixed); m[r, ] <- z$x; how[r] <- if (nrow(fx)) "read by eye" else z$how
    }
    bad <- which(is.na(m[-1, 1])) + 1                        # one open age row: header minus the others
    if (length(bad) == 1 && !is.na(m[1, 1])) { x <- m[1, ] - colSums(m[-c(1, bad), , drop = FALSE]); if (valid33(x)) { m[bad, ] <- x; how[bad] <- "column residual" } }
    as_tibble(m, rownames = "age") |> mutate(unit = unit_names[s], how = how, .before = 1)
  })
}
A7 <- map(passes64, \(p) array(NA_real_, c(28, 20, 9)))
for (pg in 26:32) { M <- page_mats(pg, 80); for (i in seq_along(passes64)) for (s in 1:4) A7[[i]][(pg - 26) * 4 + s, , ] <- M[[i]][(s - 1) * 20 + 1:20, ] }
A9 <- map(passes64, \(p) array(NA_real_, c(1, 101, 9))); M1 <- page_mats(35, 51); M2 <- page_mats(36, 50)
for (i in seq_along(passes64)) { A9[[i]][1, 1:51, ] <- M1[[i]]; A9[[i]][1, 52:101, ] <- M2[[i]] }
c7 <- build64(A7, "c7", ages64, units64$unit)
c9 <- build64(A9, "c9", single64, "Total en el País")
cat("  rows by way of resolution, Cuadro 7:", paste(names(table(c7$how)), table(c7$how), collapse = ", "), "\n")
cat("  rows by way of resolution, Cuadro 9:", paste(names(table(c9$how)), table(c9$how), collapse = ", "), "\n")
id64 <- \(d) with(d, tot_t == tot_h + tot_m & cab_t == cab_h + cab_m & res_t == res_h + res_m & tot_t == cab_t + res_t & tot_h == cab_h + res_h & tot_m == cab_m + res_m)
chk(!anyNA(c7[, cols9]) && !anyNA(c9[, cols9]), "1964 every row of Cuadros 7 and 9 is resolved")
chk(c(id64(c7), id64(c9)), "1964 the six identities hold in every row (total = hombres + mujeres, total = cabecera + resto)")
sums7 <- c7 |> group_by(unit) |> summarise(across(all_of(cols9), \(v) v[age == "total"] - sum(v[age != "total"])))
chk(as.matrix(sums7[, cols9]) == 0, "1964 C7 the 19 age groups add to the header in all nine columns of the 28 sections")
nat7 <- c7 |> filter(unit == "Total en el País") |> arrange(match(age, c("total", ages64)))
un7 <- c7 |> filter(unit != "Total en el País") |> group_by(age) |> summarise(across(all_of(cols9), sum)) |> arrange(match(age, c("total", ages64)))
chk(as.matrix(un7[, cols9]) == as.matrix(nat7[, cols9]), "1964 C7 the 27 units add to the national section, every age and column")
chk(unlist(nat7[1, c("tot_t", "tot_h", "tot_m")]) == c(17484508, 8614652, 8869856), "1964 national total 17,484,508")
chk(unlist(c9[c9$age == "total", cols9]) == colSums(c9[c9$age != "total", cols9]), "1964 C9 the single ages add to the header in all nine columns")
g9 <- c9 |> filter(age != "total") |> mutate(a = as.integer(sub("[+]", "", age)), age = case_when(a == 0 ~ "<1", a <= 4 ~ "1-4", a >= 85 ~ "85+", TRUE ~ paste0(a %/% 5 * 5, "-", a %/% 5 * 5 + 4))) |>
  group_by(age) |> summarise(across(all_of(cols9), sum)) |> arrange(match(age, ages64))
chk(as.matrix(g9[, cols9]) == as.matrix(nat7[-1, cols9]), "1964 C9 single ages grouped = national age groups of Cuadro 7")
long64 <- \(d) d |> select(-how) |> pivot_longer(all_of(cols9), names_to = c("zone", "sex"), names_sep = "_") |>
  mutate(zone = c(tot = "total", cab = "cabecera", res = "resto")[zone], sex = c(t = "total", h = "male", m = "female")[sex]) |>
  pivot_wider(names_from = sex, values_from = value)
write_csv(long64(c7) |> left_join(units64, by = "unit") |>
            transmute(census_year = 1964, unit, unit_type, zone, age,
                      age_start = case_when(age == "<1" ~ 0L, age == "total" ~ NA_integer_, TRUE ~ as.integer(str_extract(age, "^[0-9]+"))), male, female, total),
          paste0(out_dir, "census1964_dept_age5_sex_zone.csv"), na = "")
write_csv(long64(c9) |> transmute(census_year = 1964, zone, age, age_start = as.integer(str_extract(age, "^[0-9]+")), male, female, total),
          paste0(out_dir, "census1964_single_age_sex_zone.csv"), na = "")

# ---- 1964, Cuadro 14: place of birth x place of residence x sex x broad age ----
# pdf pp. 49-61 and 63 (p. 62 is a chart). Rows: 20 places of residence (Total en el País, 18 departments in census
# order, Intendencias y comisarías), each with four lines (total, 0-14, 15-59, 60+). Columns: 21 groups of
# (total, hombres, mujeres): Totales, the 18 departments, Intendencias y comisarías, Exterior; three groups per page,
# so seven pages per half. Dashes are zeros. A (residence, birthplace) block is 4 lines x 3 columns tied by seven
# identities (total = hombres + mujeres in each line, total line = sum of the three age lines in each column).
# Three tesseract passes (300 and 400 dpi grey, 500 dpi thresholded) give candidate readings; a block is the
# combination that satisfies the seven identities (the best supported one if several do), or the majority reading
# with one or two cells replaced by what the identities imply. Blocks that stay open are the ones read by eye from
# the page crops (ocr_support/corrections_1964_cuadro14.csv), or a residual (row or column of the matrix).
cat("1964 Cuadro 14\n")
passes14 <- c("500dpi_bw", "400dpi", "300dpi")
dpi14 <- setNames(as.numeric(sub("dpi.*", "", passes14)), passes14)
cc14 <- paste0("c", 1:9)
births14 <- c("Totales", "Antioquia", "Atlántico", "Bolívar", "Boyacá", "Caldas", "Cauca", "Córdoba", "Bogotá D.E.", "Cundinamarca", "Chocó", "Huila",
              "Magdalena", "Meta", "Nariño", "Norte de Santander", "Santander", "Tolima", "Valle del Cauca", "Intendencias y comisarías", "Exterior")
resid14 <- c("Total en el País", births14[2:19], "Intendencias y comisarías")       # same order as pages 49 / 51
ages14 <- c("total", "0-14", "15-59", "60+")
pages14 <- list(c(49, 50, 53, 54, 57, 58, 61), c(51, 52, 55, 56, 59, 60, 63))      # residences 1-10 / 11-20
G14 <- map(setNames(passes14, passes14), \(p) read_csv(paste0(sup_dir, "ocr_grid_1964_c14_", p, ".csv"), show_col_types = FALSE, col_types = grid_types))
rows14 <- \(p, page) { r <- G14[[p]][G14[[p]]$page == page, ]; r$n <- rowSums(!is.na(r[, cc14])); r <- r[r$n >= 1, ]; r$y <- r$yc / dpi14[[p]]; r[order(r$y), ] }
# the template of row positions of a page: a pass that found all 40 rows (10 residences x 4 lines)
template14 <- \(page) { for (p in passes14) { r <- rows14(p, page); r <- r[r$n >= 3, ]; if (nrow(r) == 40) return(r$y - r$y[1]) }; stop("no pass with 40 rows on page ", page) }
match14 <- \(r, tpl) {                                         # rows of a pass matched to the template by position
  tol <- 0.3 * min(diff(tpl)); if (!nrow(r)) return(rep(NA_integer_, length(tpl)))
  sh <- as.vector(outer(r$y, tpl, "-")); sc <- map_dbl(sh, \(s) sum(map_lgl(r$y - s, \(v) min(abs(v - tpl)) < tol)))
  s <- median(sh[sc == max(sc)])
  map_int(tpl, \(t) { d <- abs(r$y - s - t); j <- which(d < tol); if (length(j) == 1) j else if (length(j) > 1) j[which.min(d[j])] else NA_integer_ })
}
A14 <- map(passes14, \(p) matrix(NA_real_, 80, 63))             # [pass][residence line (20 x 4), birthplace column (21 x 3)]
for (h in 1:2) for (k in 1:7) {
  tpl <- template14(pages14[[h]][k]); off <- (h - 1) * 40
  for (i in seq_along(passes14)) {
    r <- rows14(passes14[i], pages14[[h]][k]); r3 <- r[r$n >= 3, ]
    A14[[i]][off + 1:40, (k - 1) * 9 + 1:9] <- if (nrow(r3) == 40) as.matrix(r3[, cc14]) else as.matrix(r[match14(r, tpl), cc14])
  }
}
E14 <- c(lapply(0:3, \(r) list(l = r * 3 + 1, r = r * 3 + 2:3)), lapply(1:3, \(s) list(l = s, r = s + c(3, 6, 9))))   # x = 4 lines x 3 columns, by row
propagate14 <- \(x) { repeat { ch <- FALSE
    for (e in E14) { v <- c(x[e$l], x[e$r]); if (sum(is.na(v)) == 1) { if (is.na(x[e$l])) x[e$l] <- sum(x[e$r]) else { k <- e$r[is.na(x[e$r])]; x[k] <- x[e$l] - sum(x[e$r], na.rm = TRUE) }; ch <- TRUE } }
    if (!ch) break }
  x }
valid14 <- \(x) !anyNA(x) && all(x >= 0) && all(map_lgl(E14, \(e) x[e$l] == sum(x[e$r])))
finish14 <- \(x) { x <- propagate14(x)
  if (!valid14(x) && anyNA(x)) { y <- x; y[is.na(y)] <- 0; y <- propagate14(y); if (valid14(y)) x <- y }   # dashes are zeros
  if (valid14(x)) x else NULL }
solve14 <- \(P, fixed) {                                        # P: passes x 12 readings of one block
  cand <- lapply(1:12, \(i) if (!is.na(fixed[i])) fixed[i] else { v <- na.omit(P[, i]); if (length(v)) head(as.numeric(names(sort(table(v), decreasing = TRUE))), 3) else NA_real_ })
  if (prod(lengths(cand)) > 4000) cand <- lapply(cand, head, 2)
  if (prod(lengths(cand)) > 4000) cand <- lapply(cand, head, 1)
  mode1 <- map_dbl(cand, 1); free <- which(is.na(fixed))
  support <- \(x) sum(map_dbl(1:12, \(i) sum(P[, i] == x[i], na.rm = TRUE)))
  best <- \(S, margin = 0) { if (is.null(S)) return(NULL); if (nrow(S) == 1) return(as.numeric(S))
    sc <- apply(S, 1, support); o <- order(sc, decreasing = TRUE); if (sc[o[1]] - sc[o[2]] > margin) as.numeric(S[o[1], ]) else NULL }
  gr <- as.matrix(expand.grid(cand))
  s <- best(unique(do.call(rbind, lapply(seq_len(nrow(gr)), \(r) finish14(gr[r, ])))))
  if (!is.null(s)) return(list(x = s, how = "direct"))
  s <- unique(do.call(rbind, lapply(free, \(i) { x <- mode1; x[i] <- NA; finish14(x) })))
  if (!is.null(s) && nrow(s) == 1) return(list(x = as.numeric(s), how = "one cell"))
  if (nrow(gr) > 1 && nrow(gr) <= 600) {
    s <- best(unique(do.call(rbind, lapply(seq_len(nrow(gr)), \(r) do.call(rbind, lapply(free, \(i) { x <- gr[r, ]; x[i] <- NA; finish14(x) }))))), margin = 1)
    if (!is.null(s)) return(list(x = s, how = "one cell"))
  }
  if (length(free) >= 2) { pr <- combn(free, 2)
    s <- unique(do.call(rbind, lapply(seq_len(ncol(pr)), \(k) { x <- mode1; x[pr[, k]] <- NA; finish14(x) })))
    if (!is.null(s) && nrow(s) == 1) return(list(x = as.numeric(s), how = "two cells")) }
  list(x = rep(NA_real_, 12), how = "unsolved")
}
# Cuadro 7 (zone total) with ages grouped 0-14 / 15-59 / 60+ and the nine intendencias and comisarías summed: the Totales group
c7g <- c7 |> left_join(units64, by = "unit") |>
  mutate(res = if_else(unit_type %in% c("intendencia", "comisaría"), "Intendencias y comisarías", unit), a0 = suppressWarnings(as.integer(str_extract(age, "^[0-9]+"))),
         ager = case_when(age == "total" ~ "total", age == "<1" | a0 < 15 ~ "0-14", a0 < 60 ~ "15-59", TRUE ~ "60+")) |>
  group_by(res, ager) |> summarise(t = sum(tot_t), h = sum(tot_h), m = sum(tot_m), .groups = "drop")
c7blk <- \(u) { z <- c7g[c7g$res == resid14[u], ]; z <- z[match(ages14, z$ager), ]; as.vector(t(as.matrix(z[, c("t", "h", "m")]))) }
corr14 <- read_csv(paste0(sup_dir, "corrections_1964_cuadro14.csv"), show_col_types = FALSE, col_types = "cccddd")
X14 <- array(NA_real_, c(20, 21, 12), dimnames = list(resid14, births14, NULL)); how14 <- matrix("", 20, 21, dimnames = list(resid14, births14))
for (u in 1:20) for (g in 1:21) {
  P <- do.call(rbind, map(A14, \(a) as.vector(t(a[(u - 1) * 4 + 1:4, (g - 1) * 3 + 1:3]))))
  cz <- corr14[corr14$residence == resid14[u] & corr14$birthplace == births14[g], ]
  if (nrow(cz)) {                                               # read by eye: four lines
    stopifnot(setequal(cz$age, ages14)); cz <- cz[match(ages14, cz$age), ]
    X14[u, g, ] <- as.vector(t(as.matrix(cz[, c("t", "h", "m")]))); how14[u, g] <- "read by eye"
  } else { z <- solve14(P, rep(NA_real_, 12)); X14[u, g, ] <- z$x; how14[u, g] <- z$how }
}
# Totales blocks the OCR could not settle by itself are Cuadro 7; the others must agree with it
tot7 <- t(sapply(1:20, c7blk)); cl <- which(how14[, 1] == "unsolved")
agree14 <- sapply(setdiff(1:20, cl), \(u) all(X14[u, 1, ] == tot7[u, ]))
for (u in cl) { X14[u, 1, ] <- tot7[u, ]; how14[u, 1] <- "Cuadro 7" }
# residuals: a single open birthplace of a residence = Totales - the others; a single open residence of a birthplace = national - the others
repeat { ch <- FALSE
  for (u in 1:20) { op <- which(is.na(X14[u, , 1])); if (length(op) == 1 && op != 1) { x <- X14[u, 1, ] - colSums(X14[u, -c(1, op), , drop = FALSE]); if (valid14(x)) { X14[u, op, ] <- x; how14[u, op] <- "residual"; ch <- TRUE } } }
  for (g in 1:21) { op <- which(is.na(X14[, g, 1])); if (length(op) == 1 && op != 1) { x <- X14[1, g, ] - colSums(X14[-c(1, op), g, , drop = FALSE]); if (valid14(x)) { X14[op, g, ] <- x; how14[op, g] <- "residual"; ch <- TRUE } } }
  if (!ch) break }
cat("  blocks by way of resolution:", paste(names(table(how14)), table(how14), collapse = ", "), "\n")
chk(!anyNA(X14), "1964 C14 every one of the 420 blocks is resolved")
chk(all(agree14), sprintf("1964 C14 the %d Totales blocks read from the page agree with Cuadro 7 (the other %d are taken from it)", length(agree14), length(cl)))
chk(apply(X14, c(1, 2), \(x) valid14(x)), "1964 C14 the seven identities hold in each of the 420 blocks")
chk(X14[, 1, ] == apply(X14[, -1, , drop = FALSE], c(1, 3), sum), "1964 C14 Totales = sum of the 20 birthplaces, every residence, line and sex")
chk(X14[1, , ] == apply(X14[-1, , , drop = FALSE], c(2, 3), sum), "1964 C14 national row = sum of the 19 other residences, every birthplace, line and sex")
chk(sapply(1:20, \(u) all(X14[u, 1, ] == tot7[u, ])), "1964 C14 Totales group = Cuadro 7 (zone total, ages grouped, intendencias and comisarías summed)")
chk(X14[1, 1, c(1, 2, 3)] == c(17484508, 8614652, 8869856), "1964 C14 national total 17,484,508")
c14 <- map_dfr(1:20, \(u) map_dfr(1:21, \(g) tibble(census_year = 1964, residence = resid14[u], birthplace = births14[g], age = ages14,
          male = X14[u, g, seq(2, 11, 3)], female = X14[u, g, seq(3, 12, 3)], total = X14[u, g, seq(1, 10, 3)])))
chk(nrow(c14) == 20 * 21 * 4, "1964 C14 20 residences x 21 birthplace groups x 4 lines")
write_csv(c14, paste0(out_dir, "census1964_birthplace_by_residence.csv"), na = "")
cat("done:", out_dir, "\n")
