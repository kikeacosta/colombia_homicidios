# 30_censo_1951_lugar_nacimiento.R -------------------------------------------------
# Censo de 1951, Cuadro 15 "Poblacion colombiana por departamento de nacimiento y sexo
# (departamentos y territorios nacionales)": data_input/dane_pdfs/censos/1951/LD_771_1951.pdf, pdf pages
# 60-63 (folio 64-67; library scan, typeset, no usable text layer). Pages 60 and 62 hold the
# left half of the table (TOTAL + 8 departments of birth: Antioquia, Atlantico, Bolivar, Boyaca, Caldas,
# Cauca, Cundinamarca, Choco), pages 61 and 63 the right half (Huila, Magdalena, Narino, Norte de
# Santander, Santander, Tolima, Valle, Intendencias y comisarias, Sin informacion) of the same rows;
# 60/61 carry the nation, departamentos, intendencias, comisarias and the departments from Antioquia
# to Narino, 62/63 the rest. Each unit has three lines: total, hombres, mujeres. The row labels of the
# right-hand pages are on the right.
# Catalogue: documents/catalogo_migracion_interdepartamental.md.
#
# Method: the OCR helpers (grid_page, merge_split, cell_ocr ...) are those of 23_census_tables_ocr.R
# (stage A, tesseract on 300 dpi and 500 dpi thresholded pages), loaded from that file; each page gives
# a grid of 9 numeric columns. The readings are reconciled with the accounting identities of the table
# (ocr_support/ocr_grid_1951_c15_*.csv hold the raw grids), and what the identities cannot place is
# read on the page image (ocr_support/corrections_1951_cuadro15.csv).

suppressMessages(library(tidyverse))
options(width = 160)
run_ocr <- FALSE
pdf_path <- "data_input/dane_pdfs/censos/1951/LD_771_1951.pdf"
sup_dir  <- "data_input/historical/census_tables/ocr_support/"
out_dir  <- "data_input/historical/census_tables/"

if (run_ocr) {
  suppressPackageStartupMessages({library(tesseract); library(magick); library(pdftools)})
  src <- readLines("code/historical/23_census_tables_ocr.R")
  a <- grep("eng6 <- tesseract", src)[1]; b <- grep("tmp <- file.path\\(tempdir", src)[1] - 1
  eval(parse(text = src[a:b]))                     # eng6, eng7 and the helper functions
  tmp <- file.path(tempdir(), "census_ocr"); dir.create(tmp, showWarnings = FALSE)
  for (pass in c("500dpi_bw", "300dpi", "400dpi", "600dpi", "500dpi", "600dpi_bw")) {
    if (file.exists(paste0(sup_dir, "ocr_grid_1951_c15_", pass, ".csv"))) next
    dpi <- as.integer(sub("dpi.*", "", pass))
    grids <- map_dfr(60:63, \(p) {
      png <- sprintf("%s/c1951_c15_p%03d_%d.png", tmp, p, dpi)
      if (!file.exists(png)) suppressWarnings(pdf_convert(pdf_path, format = "png", pages = p, dpi = dpi, filenames = png, verbose = FALSE))
      x <- image_read(png) |> image_convert(colorspace = "gray") |> image_deskew(threshold = 40) |> image_background("white")
      if (grepl("_bw$", pass)) x <- x |> image_threshold("white", "60%") |> image_threshold("black", "40%")
      f <- sub(".png$", paste0("_", pass, ".png"), png); image_write(x, f)
      cat("  OCR", pass, "page", p, "\n")
      grid_page(f, ncol = 9) |> mutate(page = p, .before = 1)
    })
    write_csv(grids, paste0(sup_dir, "ocr_grid_1951_c15_", pass, ".csv"), na = "NA")
  }
}

# ============================================================================
# Stage B: assemble the 87 lines x 18 columns and reconcile with the identities
# ============================================================================
births <- c("Antioquia","Atlántico","Bolívar","Boyacá","Caldas","Cauca","Cundinamarca","Chocó",
            "Huila","Magdalena","Nariño","Norte de Santander","Santander","Tolima","Valle del Cauca",
            "Intendencias y comisarías","Sin información")
col_names <- c("total", births)                                   # 18 columns: 9 left page + 9 right page
groups_a <- c("NACION","DEPARTAMENTOS","INTENDENCIAS","COMISARIAS","Antioquia","Atlántico","Bolívar","Boyacá","Caldas",
              "Cauca","Cundinamarca","Chocó","Huila","Magdalena","Nariño")                      # pages 60 / 61
groups_b <- c("Norte de Santander","Santander","Tolima","Valle del Cauca","Caquetá","Meta","San Andrés y Providencia",
              "Amazonas","Arauca","Casanare","La Guajira","Putumayo","Vaupés","Vichada")        # pages 62 / 63
groups <- c(groups_a, groups_b)
unit_type <- c(rep("total", 4), rep("departamento", 11), rep("departamento", 4), rep("intendencia", 3), rep("comisaría", 7))
lines_id <- expand_grid(group = groups, sex = c("total","hombres","mujeres"))
lines_id$line <- seq_len(nrow(lines_id))
stopifnot(nrow(lines_id) == 87)

grid <- function(pass) read_csv(paste0(sup_dir, "ocr_grid_1951_c15_", pass, ".csv"), show_col_types = FALSE) |>
  mutate(n = rowSums(!is.na(across(c1:c9)))) |> filter(n >= 3)
passes <- c("500dpi_bw", "600dpi_bw", "300dpi", "400dpi", "500dpi", "600dpi")
G <- setNames(lapply(passes, grid), passes)
# expected data lines per page pair: 45 (60/61) and 39 (62/63; the three Vichada lines are all dashes)
align_to <- function(xa, xb) {                 # another pass (other y scale) on the nearest line, y rescaled to [0, 1]
  ra <- (xa$yc - min(xa$yc)) / diff(range(xa$yc)); rb <- (xb$yc - min(xb$yc)) / diff(range(xb$yc))
  idx <- vapply(ra, \(y) which.min(abs(rb - y)), 1L); xb[idx, ] }
cube <- array(NA_real_, c(length(passes), 87, 18), dimnames = list(passes, NULL, NULL))
for (half in c("left", "right")) for (pp in list(c(60, 61, 45, 1), c(62, 63, 39, 46))) {
  p <- if (half == "left") pp[1] else pp[2]; cols <- if (half == "left") 1:9 else 10:18
  base <- G[[1]] |> filter(page == p) |> arrange(yc); stopifnot(nrow(base) == pp[3])
  rows <- pp[4] - 1 + seq_len(pp[3])
  for (k in seq_along(passes)) {
    xk <- if (k == 1) base else align_to(base, G[[k]] |> filter(page == p) |> arrange(yc))
    cube[k, rows, cols] <- as.matrix(xk[paste0("c", 1:9)])
  }
}
cube[, 85:87, ] <- 0                           # Vichada: the page prints a dash in every cell
# vote: the reading that most passes agree on; no clear winner -> unknown (resolved by the identities)
vote <- function(x) {
  x <- x[!is.na(x)]; if (!length(x)) return(c(NA, NA, 0))
  t <- sort(table(x), decreasing = TRUE); w <- as.numeric(names(t)[1])
  if (length(t) > 1 && t[1] == t[2]) return(c(NA, w, 0))
  c(w, if (length(t) > 1) as.numeric(names(t)[2]) else NA, as.numeric(t[1]))
}
vv <- apply(cube, c(2, 3), vote)               # 3 x 87 x 18
cells_a <- vv[1, , ]; cells_b <- vv[2, , ]; nvote <- vv[3, , ]
cat("cells with a clear majority:", sum(!is.na(cells_a)), "of", length(cells_a), "; with all", length(passes), "passes equal:",
    sum(nvote == length(passes)), "; unknown (no majority):", sum(is.na(cells_a)), "\n")

# Cells read on the page images (260 dpi crops) where the OCR passes agree on a wrong value or have no
# majority; format: group, column, then the (total, hombres, mujeres) values read.
IC <- "Intendencias y comisarías"; SI <- "Sin información"
img_fix <- tribble(
  ~group, ~column, ~t, ~h, ~m,
  "NACION", "Cauca", 426591, 212446, NA,   "NACION", "Cundinamarca", NA, 722952, NA,
  "DEPARTAMENTOS", "Boyacá", 952262, NA, NA,   "COMISARIAS", "Nariño", NA, NA, 3182,
  "Antioquia", SI, NA, 854, 172,
  "Atlántico", "Santander", 4150, 1930, 2220,   "Atlántico", SI, 0, 0, 0,   "Atlántico", IC, 346, 188, 158,
  "Bolívar", SI, 4847, 2486, 2361,   "Caldas", "Caldas", 833667, 419251, 414416,
  "Cauca", "Cundinamarca", 1112, 619, 493,   "Cauca", "Huila", 2002, 1091, 911,   "Cauca", SI, 597, 591, 6,
  "Cundinamarca", "total", 1595395, NA, NA,   "Cundinamarca", "Boyacá", NA, NA, 77171,
  "Cundinamarca", "Cauca", NA, NA, 1012,   "Cundinamarca", "Chocó", NA, NA, 198,   "Cundinamarca", SI, 2115, 951, 1164,
  "Huila", "Cundinamarca", 7234, NA, NA,   "Huila", "Magdalena", 35, 18, 17,   "Huila", "Norte de Santander", 121, 71, 50,
  "Huila", "Santander", 724, 431, 293,   "Huila", SI, 2321, 1208, 1113,
  "Magdalena", "Chocó", 49, 37, 12,   "Nariño", "Huila", 164, 90, 74,
  "Norte de Santander", "Bolívar", 315, 174, 141,   "Norte de Santander", "Cauca", 51, 33, 18,
  "Tolima", "Chocó", 59, 30, 29,   "Meta", "Chocó", 51, 30, 21,   "Amazonas", "Antioquia", 82, 67, 15,
  "DEPARTAMENTOS", "Tolima", NA, NA, 350636,   "DEPARTAMENTOS", "Santander", NA, 372548, NA,   "Tolima", "Tolima", NA, NA, 275508,
  "Caquetá", "Cundinamarca", NA, 949, NA,   "San Andrés y Providencia", "Nariño", 0, 0, 0,   "Magdalena", "Norte de Santander", 16001, 8700, 7301,
  # La Guajira, Putumayo and Vaupés (comisarías): the whole line read on the page crops
  "La Guajira", "Antioquia", 104, 64, 40,   "La Guajira", "Atlántico", 114, 71, 43,   "La Guajira", "Bolívar", 135, 90, 45,
  "La Guajira", "Boyacá", 37, 28, 9,   "La Guajira", "Caldas", 14, 10, 4,   "La Guajira", "Cauca", 10, 6, 4,
  "La Guajira", "Cundinamarca", 71, 53, 18,   "La Guajira", "Chocó", 0, 0, 0,   "La Guajira", "Magdalena", 3324, 1658, 1666,
  "La Guajira", "Nariño", 6, 4, 2,   "La Guajira", "Norte de Santander", 60, 50, 10,   "La Guajira", "Santander", 34, 20, 14,
  "La Guajira", "Tolima", 28, 18, 10,   "La Guajira", "Valle del Cauca", 16, 11, 5,   "La Guajira", IC, 3353, 1493, 1860,   "La Guajira", SI, 72, 32, 40,
  "Putumayo", "Antioquia", 116, 77, 39,   "Putumayo", "Atlántico", 1, 1, 0,   "Putumayo", "Bolívar", 3, 1, 2,
  "Putumayo", "Boyacá", 25, 21, 4,   "Putumayo", "Caldas", 311, 171, 140,   "Putumayo", "Cauca", 381, 190, 191,
  "Putumayo", "Cundinamarca", 88, 63, 25,   "Putumayo", "Chocó", 1, 1, 0,   "Putumayo", "Magdalena", 3, 3, 0,
  "Putumayo", "Nariño", 7132, 3982, 3150,   "Putumayo", "Norte de Santander", 8, 4, 4,   "Putumayo", "Santander", 43, 23, 20,
  "Putumayo", "Tolima", 99, 55, 44,   "Putumayo", "Valle del Cauca", 386, 196, 190,   "Putumayo", IC, 12575, 6132, 6443,   "Putumayo", SI, 67, 37, 30,
  "Vaupés", "Antioquia", 32, 22, 10,   "Vaupés", "Atlántico", 3, 3, 0,   "Vaupés", "Bolívar", 4, 4, 0,
  "Vaupés", "Boyacá", 36, 24, 12,   "Vaupés", "Caldas", 11, 9, 2,   "Vaupés", "Cauca", 3, 2, 1,
  "Vaupés", "Cundinamarca", 65, 43, 22,   "Vaupés", "Chocó", 3, 2, 1,   "Vaupés", "Magdalena", 2, 1, 1,
  "Vaupés", "Nariño", 4, 4, 0,   "Vaupés", "Norte de Santander", 4, 3, 1,   "Vaupés", "Santander", 27, 26, 1,
  "Vaupés", "Tolima", 26, 24, 2,   "Vaupés", "Valle del Cauca", 3, 2, 1,   "Vaupés", IC, 471, 253, 218,   "Vaupés", SI, 20, 8, 12)
img_fix_log <- NULL
for (k in seq_len(nrow(img_fix))) for (s in c("t", "h", "m")) {
  v <- img_fix[[s]][k]; if (is.na(v)) next
  sx <- c(t = "total", h = "hombres", m = "mujeres")[[s]]
  l <- lines_id$line[lines_id$group == img_fix$group[k] & lines_id$sex == sx]; cc <- match(img_fix$column[k], col_names)
  img_fix_log <- rbind(img_fix_log, tibble(group = img_fix$group[k], sex = sx, column = img_fix$column[k], ocr_vote = cells_a[l, cc], set = v))
  cells_a[l, cc] <- v
}


# ---- identities as linear constraints sum(coef * cell) = 0 ----
li <- function(g, s) lines_id$line[lines_id$group == g & lines_id$sex == s]
cid <- function(l, c) (l - 1) * 18 + c
cons <- list()
add <- function(cells, coef) cons[[length(cons) + 1]] <<- list(cells = cells, coef = coef)
for (g in groups) for (c in 1:18) add(c(cid(li(g, "total"), c), cid(li(g, "hombres"), c), cid(li(g, "mujeres"), c)), c(1, -1, -1))   # total = men + women
for (l in 1:87) add(cid(l, 1:18), c(1, rep(-1, 17)))                                                                                  # total column = sum of the places of birth
for (s in c("total", "hombres", "mujeres")) for (c in 1:18) {
  dep <- groups[5:19]; ints <- groups[20:22]; com <- groups[23:29]
  add(c(cid(li("NACION", s), c), cid(li("DEPARTAMENTOS", s), c), cid(li("INTENDENCIAS", s), c), cid(li("COMISARIAS", s), c)), c(1, -1, -1, -1))
  add(c(cid(li("DEPARTAMENTOS", s), c), cid(vapply(dep, li, 1L, s = s), c)), c(1, rep(-1, length(dep))))
  add(c(cid(li("INTENDENCIAS", s), c), cid(vapply(ints, li, 1L, s = s), c)), c(1, rep(-1, length(ints))))
  add(c(cid(li("COMISARIAS", s), c), cid(vapply(com, li, 1L, s = s), c)), c(1, rep(-1, length(com))))
}
cat("constraints:", length(cons), "\n")
V <- as.vector(t(cells_a)); Vb <- as.vector(t(cells_b))        # cell (l, c) at index (l - 1) * 18 + c
read0 <- V; log51 <- NULL
violations <- function(v) which(vapply(cons, \(k) { x <- v[k$cells]; !anyNA(x) && sum(k$coef * x) != 0 }, TRUE))
propagate <- function(v) {
  repeat {
    ch <- FALSE
    for (k in cons) { x <- v[k$cells]; if (sum(is.na(x)) == 1) { i <- which(is.na(x)); v[k$cells[i]] <- -sum(k$coef[-i] * x[-i]) / k$coef[i]; ch <- TRUE } }
    if (!ch) return(v)
  }
}
V <- propagate(V)
cat("after propagating the unknown cells:", sum(is.na(V)), "unknown;", length(violations(V)), "violated identities\n")
use_heuristic <- FALSE
for (it in seq_len(if (use_heuristic) 200 else 0)) {                                               # cell in the most violated identities is re-derived
  vi <- violations(V); if (!length(vi)) break
  cnt <- table(unlist(lapply(cons[vi], `[[`, "cells")))
  tot <- table(unlist(lapply(cons, `[[`, "cells")))[names(cnt)]
  cand <- names(cnt)[cnt == max(cnt) & cnt >= 2]
  if (!length(cand)) break
  i <- as.integer(cand[which.max(cnt[cand] / tot[cand])]); old <- V[i]
  V2 <- V; V2[i] <- NA; V2 <- propagate(V2)
  if (length(violations(V2)) >= length(vi)) { V[i] <- old; break }
  log51 <- rbind(log51, tibble(line = (i - 1) %/% 18 + 1, col = (i - 1) %% 18 + 1, read = old, second_pass = Vb[i], set = V2[i]))
  V <- V2
}
cat("violated identities left:", length(violations(V)), "; unknown cells:", sum(is.na(V)), "; cells changed by the identities:", nrow(log51), "\n")
if (!is.null(log51)) print(log51 |> mutate(group = lines_id$group[line], sex = lines_id$sex[line], column = col_names[col]) |> select(group, sex, column, read, second_pass, set), n = 60)
stopifnot(length(violations(V)) == 0, !anyNA(V), all(V >= 0))
cat("all", length(cons), "identities hold; cells changed on the page images:", nrow(img_fix_log),
    "(of which differ from the OCR vote:", sum(img_fix_log$ocr_vote != img_fix_log$set | is.na(img_fix_log$ocr_vote)), ")\n")

Mfin <- matrix(V, 87, 18, byrow = TRUE)
long <- map_dfr(1:87, \(l) tibble(unit = lines_id$group[l], unit_type = unit_type[(l - 1) %/% 3 + 1], sex = lines_id$sex[l],
                                  birth_place = col_names[-1], population = Mfin[l, -1], total_born_in_country = Mfin[l, 1])) |>
  mutate(unit = recode(unit, NACION = "Total nación", DEPARTAMENTOS = "Total departamentos", INTENDENCIAS = "Total intendencias",
                       COMISARIAS = "Total comisarías"), census_year = 1951, .before = 1)
write_csv(long, paste0(out_dir, "census1951_birthplace_by_residence.csv"))
write_csv(img_fix_log |> filter(is.na(ocr_vote) | ocr_vote != set), paste0(sup_dir, "corrections_1951_cuadro15.csv"))
cat("written:", nrow(long), "rows\n")

# ---- check against the 1951 stock index printed in BOL_314 Cuadro 13 (data_input/migration/dane_internal) ----
ix <- long |> filter(unit_type == "departamento", sex == "total") |> group_by(unit) |>
  summarise(own = population[birth_place == first(unit)], residents = first(total_born_in_country), .groups = "drop")
born <- long |> filter(unit == "Total nación", sex == "total") |> select(birth_place, born = population)
ix <- ix |> left_join(born, by = c("unit" = "birth_place")) |> mutate(inm = residents - own, emi = born - own, index = round(100 * (inm - emi) / (inm + emi)))
b314 <- read_csv("data_input/migration/dane_internal/bol314_cuadro13_indice_periodos.csv", show_col_types = FALSE)
cmp <- ix |> mutate(key = recode(unit, "Antioquia" = "Antioquia", "Bolívar" = "Bolívar (con Sucre)", "Caldas" = "Caldas (con Quindío y Risaralda)",
                                 "Magdalena" = "Magdalena (con Cesar)", "Valle del Cauca" = "Valle del Cauca")) |>
  inner_join(b314 |> select(unit, bol314 = index_stock_1951), by = c("key" = "unit"))
cat("1951 stock index from the matrix vs printed in BOL_314 Cuadro 13 (percent):\n"); print(cmp |> select(unit, index, bol314), n = 20)
