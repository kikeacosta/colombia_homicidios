# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 23. Census summary tables 1938, 1951 and 1973 from the DANE PDFs
#     (tesseract OCR reconciled by accounting identities + visual transcription)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Sources (data_input/historical/, PDFs not versioned, 29 MB):
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
#                        summary of the adjustment.
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
#   1938  The 12-column typeset table defeated the column clustering (OCR
#         draft with ~30 wrong cells); the totales block was transcribed
#         visually from 500 dpi crops (ocr_support/transcription_1938_cuadro28.csv)
#         and validated row by row (T = H + M) and against the published
#         grand totals 4,312,763 / 4,389,053 / 8,701,816.
#   1973  Chain-printer scan unreadable by tesseract (6/E, 0/C, 9/S
#         confusions in every preprocessing variant). Cuadro 2 (national
#         columns) and the TOTAL / CABECERA / RESTO rows of each sección in
#         chapter VIII were transcribed visually and validated against the
#         printed 5-year rows, the grand total and Cuadro VIII.20.
#
# Stage A (run_ocr <- TRUE) repeats the 1951 OCR from the PDF and rewrites
#   ocr_support/ocr_grid_1951_500dpi_bw.csv and ocr_grid_1951_300dpi.csv
#   (needs the PDF, tesseract, magick and pdftools; about 10 minutes).
# Stage B (always) builds the tables from ocr_support/ and stops if any
#   identity fails.
#
# output: data_input/historical/census_tables/
#   census1938_single_age_sex.csv            national, ages 0-98, 99+, indígena
#   census1951_dept_age5_sex_1938_1951.csv   1938 and 1951, 29 territorial rows
#   census1973_single_age_sex.csv            national censused population
#   census1973_adjusted_population_units.csv coverage-adjusted, 31 units x 3 zones
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))
options(width = 160)

run_ocr <- FALSE
pdf_dir <- "data_input/historical/"
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
  grid_page <- function(png, ncol, col_tol = 40, min_conf = 80, min_share = 0.25) {
    img <- image_read(png)
    w <- words_page(img); hh <- median(w$h[w$numeric]); w <- merge_split(w, hh)
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
  pdf <- paste0(pdf_dir, "LD_771_1951.pdf"); stopifnot(file.exists(pdf))
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
cat("done:", out_dir, "\n")
