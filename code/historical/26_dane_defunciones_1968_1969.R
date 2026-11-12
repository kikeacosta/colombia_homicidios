# 26_dane_defunciones_1968_1969.R -----------------------------------------------
# DANE, Anuario de Estadísticas Vitales 1968-1969, library scan with an OCR text layer:
# data_input/dane_pdfs/anuarios/LD_70106_1968_1969_EJ_3.pdf (not versioned).
#
# Tables extracted (pdf pages)
#   Cuadro 30 (pp. 56-63)    deaths by sección del país, sex and age group, 1968
#   Cuadro 76 (pp. 143-153)  the same for 1969
# 31 secciones per year: 23 departments (with Bogotá D.E.), 4 intendencias and 4 comisarías printed one by
# one (Putumayo is a comisaría in 1968 and an intendencia in 1969), and TOTAL NACIONAL. Each block is a TOTAL
# row and 25 age rows (under 1 day, 1-6 days, 7-29 days, 1-5 and 6-11 months, 12-23 months, 2-4, 5-9 ... 80-84,
# 85+, not stated: the same groups as 1970-1978) by Total, Hombres, Mujeres. Putumayo 1968 has no "not
# stated" row (0). Not extracted: the cause tables (Cuadros 29, 29A-E and 75, 75A-E; see the README).
#
# Method (as in 25_dane_defunciones_1970_1978.R)
#   1. Words with their boxes from pdftools::pdf_data (cached). A block starts at its "TOTAL ..." word; its
#      unit is the printed title matched to the names by edit distance (one name per block and year). Rows are
#      placed by the vertical distance to the TOTAL line (the age rows start one "gap" below it and are one
#      "pitch" apart, both measured on the complete blocks of the page), columns by the clusters of the right
#      edges of the numbers of each half page; tokens of one cell are joined and a cell without digits is 0.
#   2. Identities: total = men + women (every row), age rows = TOTAL row (every block and sex), secciones =
#      TOTAL NACIONAL (every sex and age row). Every cell is in three. A cell is corrected only when none of
#      its identities holds and two ask for the same value; repeated until nothing changes. Before that, the
#      cells the identities cannot settle were read on 300-dpi crops (support/corrections.csv), and every cell
#      the identities corrected was checked by eye on a crop (3 are misprints of the print: support/
#      misprints_in_source.csv). TOTAL NACIONAL equals Cuadro 1 of the 1970-1978 volume.
#   3. The identities that still fail are inconsistencies of the printed source, listed in
#      support/source_inconsistencies.csv; the script stops if the failing set differs from that list.
#
# output: data_input/historical/dane_defunciones_1968_1969_secciones_sexo_edad.csv
#           year, unit, cod_dpto, age, male, female, total
#         data_input/historical/dane_defunciones_1968_1969_support/
#           manual inputs: corrections.csv, misprints_in_source.csv, source_inconsistencies.csv
#           reports: verification_identities.csv, cells_corrected.csv, differences_vs_col_gap_analysis.csv
#         (word cache and state for the crop helpers in data_inter/, not versioned)
# runtime: about 10 s (1 minute the first time, to build the text cache from the PDF).
# -------------------------------------------------------------------------------
suppressMessages({library(tidyverse)})
options(width = 220)

pdf <- "data_input/dane_pdfs/anuarios/LD_70106_1968_1969_EJ_3.pdf"
out <- "data_input/historical/dane_defunciones_1968_1969_"
sup <- "data_input/historical/dane_defunciones_1968_1969_support/"
cache <- "data_inter/dane_defunciones_1968_1969_words.rds"
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
stopifnot(n_distinct(W$page) == 178)
W <- split(W, W$page)

ascii <- \(x) iconv(x, to = "ASCII//TRANSLIT")
has_digit <- \(t) grepl("[0-9]", t)
is_dash <- \(t) grepl("^[-_~=]+$", t)
to_int <- function(t) { s <- chartr("lIOoSsBZG", "110055826", t); s <- gsub("[^0-9]", "", s); suppressWarnings(as.integer(ifelse(s == "", NA, s))) }

ages <- c("under 1 day", "1-6 days", "7-29 days", "1-5 months", "6-11 months", "12-23 months", "2-4", "5-9", "10-14", "15-19", "20-24", "25-29",
          "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80-84", "85+", "not stated")
NAT <- "Total nacional"
sexes <- c("total", "male", "female")
units <- tribble(~unit, ~cod_dpto, ~pat,
  "Antioquia", "05", "antioquia", "Atlántico", "08", "atlantico", "Bogotá D.E.", "11", "bogotade", "Bolívar", "13", "bolivar", "Boyacá", "15", "boyaca",
  "Caldas", "17", "caldas", "Cauca", "19", "cauca", "Cesar", "20", "cesar", "Córdoba", "23", "cordoba", "Cundinamarca", "25", "cundinamarca", "Chocó", "27", "choco",
  "Huila", "41", "huila", "La Guajira", "44", "laguajira", "Magdalena", "47", "magdalena", "Meta", "50", "meta", "Nariño", "52", "narino",
  "Norte de Santander", "54", "nortedesantander", "Quindío", "63", "quindio", "Risaralda", "66", "risaralda", "Santander", "68", "santander", "Sucre", "70", "sucre",
  "Tolima", "73", "tolima", "Valle del Cauca", "76", "valledelcauca",
  "Arauca", "81", "arauca", "Caquetá", "18", "caqueta", "Putumayo", "86", "putumayo", "San Andrés y Providencia", "88", "sanandresyprovidencia",
  "Amazonas", "91", "amazonas", "Guainía", "94", "guainia", "Vaupés", "97", "vaupes", "Vichada", "99", "vichada")
terr <- c("Arauca", "Caquetá", "Putumayo", "San Andrés y Providencia", "Amazonas", "Guainía", "Vaupés", "Vichada")
unit_order <- c(NAT, units$unit)
cand <- bind_rows(units |> transmute(unit, pat),
                  units |> filter(unit %in% terr) |> transmute(unit, pat = paste0("intendenciadel", pat)),
                  units |> filter(unit %in% terr) |> transmute(unit, pat = paste0("comisariadel", pat)),
                  units |> filter(unit %in% terr) |> transmute(unit, pat = paste0("intendenciade", pat)))

pg <- tibble(page = c(56:63, 143:153), year = c(rep(1968L, 8), rep(1969L, 11)))

# ---------------------------------------------------------------------------
# 2. Cuadro 30 (1968, pp. 56-63) and Cuadro 76 (1969, pp. 143-153): blocks of 26 rows x 3 columns ====
# ---------------------------------------------------------------------------
# A block starts at its "TOTAL ..." line (found by its label, which survives in the text layer). Rows are placed by the
# vertical distance to that line (the labels of the ages are too garbled to rely on and a row of dashes may be missing),
# columns by the clusters of the right edges of the numbers of each half of the page.
find_blocks <- function(p) {
  d <- W[[as.character(p)]] |> arrange(yc, x); d$row <- cumsum(c(1, diff(d$yc) > 4))
  a <- d |> filter(grepl("^T[O0Q]T", text), x < 400)
  bl <- pmap_dfr(list(a$x, a$yc, a$row), function(xa, ya, rw) {
    half <- xa > 220
    nxt <- a$yc[(a$x > 220) == half & a$yc > ya + 20]; end <- if (length(nxt)) min(nxt) - 12 else 560
    w <- d |> filter(yc >= ya - 3, yc < end, x >= xa - 5, x < xa + 248)
    ln <- w |> group_by(row) |> summarise(yc = mean(yc), .groups = "drop") |> arrange(yc)
    nat <- any(grepl("^NAC", d$text[d$row == rw & d$x > xa & d$x < xa + 200]))
    tt <- d |> filter(yc >= ya - 24, yc <= ya - 4, x >= xa + 50, x < xa + 270, grepl("[A-Za-z]", text)) |> arrange(x)
    tibble(page = p, x0 = xa, y0 = ya, half = half, end = end, n_lines = nrow(ln), gap1 = if (nrow(ln) >= 2) ln$yc[2] - ya else NA_real_, last = max(ln$yc), is_nat = nat, title = paste(tt$text, collapse = " "))
  })
  # row model: the TOTAL row, then the 25 age rows from gap1 below it, one pitch apart (gap1 is larger than the pitch)
  full <- bl |> filter(n_lines == 26) |> mutate(pa = (last - (y0 + gap1)) / 24) |> filter(pa > 7, pa < 14)
  if (!nrow(full)) stop("page ", p, ": no complete block to give the row pitch")
  bl |> mutate(pitch = median(full$pa), gap1 = median(full$gap1))
}
blocks <- map_dfr(pg$page, find_blocks) |> left_join(pg, by = "page")
# unit of each block: the printed title against the names (letters only), one name per block and year
norm <- \(x) gsub("[^a-z]", "", tolower(ascii(x)))
blocks <- blocks |> mutate(title = str_squish(gsub("(grupo )?(de )?edad|total|hombres|mujeres", "", title, ignore.case = TRUE)), tn = norm(title)) |> rowwise() |>
  mutate(best = if (is_nat) NAT else cand$unit[which.min(adist(tn, cand$pat))], dist = if (is_nat) 0 else min(adist(tn, cand$pat))) |> ungroup()
bad <- blocks |> group_by(year) |> filter(duplicated(best) | duplicated(best, fromLast = TRUE))
if (nrow(bad)) { print(bad |> select(page, x0, y0, title, best, dist)); stop("the same unit is assigned to two blocks") }
chk <- blocks |> group_by(year) |> summarise(n = n(), missing = paste(setdiff(unit_order, best), collapse = ", "), .groups = "drop")
print(chk)
cat("titles that needed more than 3 edits (checked against the position):\n"); print(blocks |> filter(dist > 3) |> select(page, year, title, best, dist))
blocks <- blocks |> mutate(unit = best, id_blk = row_number())

read_block <- function(b, cc) {
  d <- W[[as.character(b$page)]]
  tok <- d |> filter(yc >= b$y0 - 3, yc < b$end, x >= b$x0 + 104, x < b$x0 + 248, has_digit(text) | is_dash(text)) |>
    mutate(k = if_else(yc < b$y0 + b$gap1 / 2, 0, 1 + round((yc - (b$y0 + b$gap1)) / b$pitch))) |> filter(k >= 0, k <= 25)
  cen <- cc[[paste(b$page, b$half)]]
  tok <- tok |> filter(has_digit(text)) |> mutate(col = map_int(xr, \(e) which.min(abs(cen - e))), dx = xr - cen[col])
  cell <- tok |> group_by(k, col) |> summarise(raw = paste(text, collapse = ""), dx = max(abs(dx)), yc = mean(yc), .groups = "drop")
  expand_grid(k = 0:25, col = 1:3) |> left_join(cell, by = c("k", "col")) |> mutate(value = coalesce(to_int(raw), 0L), id_blk = b$id_blk)
}
# column positions of each half page: clusters of the right edges of the numbers (and single dashes) of its blocks
col_centres <- function(p, h) {
  e <- map(which(blocks$page == p & blocks$half == h), \(i) { b <- blocks[i, ]
    W[[as.character(p)]] |> filter(yc >= b$y0 - 3, yc < b$end, x >= b$x0 + 104, x < b$x0 + 248, has_digit(text) | (is_dash(text) & nchar(text) == 1)) |> pull(xr) }) |> unlist() |> sort()
  cl <- cumsum(c(1, diff(e) > 9)); t <- tibble(e, cl) |> group_by(cl) |> summarise(c = median(e), n = n(), .groups = "drop") |> filter(n >= 2)
  while (nrow(t) > 3) t <- t[-which.min(t$n), ]
  if (nrow(t) != 3) stop(sprintf("page %d half %s: %d column positions", p, h, nrow(t)))
  sort(t$c)
}
cc <- list(); for (i in seq_len(nrow(pg))) for (h in unique(blocks$half[blocks$page == pg$page[i]])) cc[[paste(pg$page[i], h)]] <- col_centres(pg$page[i], h)
cells <- map_dfr(seq_len(nrow(blocks)), \(i) read_block(blocks[i, ], cc)) |>
  left_join(blocks |> select(id_blk, page, year, unit, y0, pitch, gap1), by = "id_blk") |>
  mutate(sex = sexes[col], age = c("all", ages)[k + 1L], table = "c30_76", yc = coalesce(yc, y0 + if_else(k == 0, 0, gap1 + (k - 1) * pitch)))
cat(sprintf("blocks: %d (%s); cells: %d; cells with a token whose edge is more than 6 px from its column centre: %d\n", nrow(blocks), paste(table(blocks$year), collapse = " + "), nrow(cells), sum(abs(cells$dx) > 6, na.rm = TRUE)))
cells <- cells |> mutate(id = row_number(), read = value, how = "") |> select(id, table, year, unit, sex, age, page, yc, dx, raw, read, value, how)
stopifnot(!anyDuplicated(cells[c("year", "unit", "sex", "age")]), nrow(cells) == 2 * 32 * 26 * 3)

# cells read by eye on the page render override the text layer before the identities are applied
cor_file <- paste0(sup, "corrections.csv")
if (file.exists(cor_file)) {
  cor <- read_csv(cor_file, show_col_types = FALSE, col_types = cols(year = "i", value = "i", .default = "c"))
  k <- cor |> left_join(cells |> select(year, unit, sex, age, id), by = c("year", "unit", "sex", "age"))
  if (anyNA(k$id)) { print(k |> filter(is.na(id))); stop("corrections.csv: rows that match no cell") }
  cells$value[k$id] <- k$value; cells$how[k$id] <- "read on the page render"
  cat("manual readings applied:", nrow(cor), "\n")
}

# ---------------------------------------------------------------------------
# 3. accounting identities ====
# ---------------------------------------------------------------------------
con_of <- function(d, by, type) d |> filter(sgn != 0) |> mutate(type = type, key = do.call(paste, c(list(type), pick(all_of(by)), sep = "|"))) |> select(type, key, id, sgn)
con <- bind_rows(
  cells |> mutate(sgn = if_else(sex == "total", 1L, -1L)) |> con_of(c("year", "unit", "age"), "sexes"),                       # total = men + women
  cells |> mutate(sgn = if_else(age == "all", 1L, -1L)) |> con_of(c("year", "unit", "sex"), "ages"),                        # the age rows add up to the TOTAL row
  cells |> mutate(sgn = if_else(unit == NAT, 1L, -1L)) |> con_of(c("year", "sex", "age"), "units"))                         # the secciones add up to the national total
stopifnot(!anyDuplicated(con[c("key", "id")]))
con$con <- as.integer(factor(con$key))
con_info <- con |> distinct(con, type, key) |> arrange(con)
cat(sprintf("identities: %d over %d cells; by type:\n", nrow(con_info), n_distinct(con$id))); print(table(con_info$type))

cells$value <- as.numeric(cells$value)
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
fail <- con_info |> mutate(resid = r1) |> filter(resid != 0)
write_rds(list(cells = cells, con = con, con_info = con_info, fail = fail, sol = sol, blocks = blocks), "data_inter/dane_defunciones_1968_1969_state.rds")
print(fail |> select(type, key, resid), n = 100)

# ---------------------------------------------------------------------------
# 4. assertions and verification reports ====
# ---------------------------------------------------------------------------
n_con <- tabulate(con$id, nbins = nrow(cells))
stopifnot(all(n_con >= 3), all(cells$value >= 0), all(cells$value == round(cells$value)))
# the identities that still fail must be exactly the documented inconsistencies of the printed source
doc <- read_csv(paste0(sup, "source_inconsistencies.csv"), show_col_types = FALSE)
new_fail <- fail |> anti_join(doc, by = c("key" = "identity")); gone <- doc |> anti_join(fail, by = c("identity" = "key"))
chg <- fail |> inner_join(doc, by = c("key" = "identity")) |> filter(resid != residual)
if (nrow(new_fail) || nrow(gone) || nrow(chg)) {
  cat("identities failing and not documented:\n"); print(new_fail, n = 100); cat("documented and no longer failing:\n"); print(gone, n = 100); cat("residual changed:\n"); print(chg, n = 100)
  stop("the failing identities are not the ones documented in source_inconsistencies.csv")
}
cat(sprintf("identities: %d hold; %d fail, all documented as inconsistencies of the printed source\n", nrow(con_info) - nrow(fail), nrow(fail)))
id_name <- c(sexes = "total = men + women", ages = "age rows = TOTAL row", units = "secciones = TOTAL NACIONAL")
ver <- con_info |> mutate(fails = r1 != 0, year = as.integer(str_match(key, "[|](19[0-9]{2})[|]")[, 2]), identity = unname(id_name[type])) |>
  group_by(year, identity) |> summarise(n_identities = n(), n_failing_in_source = sum(fails), .groups = "drop")
write_csv(ver, paste0(sup, "verification_identities.csv")); print(ver)

# every cell not taken as the text layer gives it: the manual readings and what the identities corrected
mis <- read_csv(paste0(sup, "misprints_in_source.csv"), show_col_types = FALSE, col_types = cols(year = "i", .default = "c"))
stopifnot(all(inner_join(mis, cells, by = c("year", "unit", "sex", "age"))$how == "identities"), nrow(inner_join(mis, cells, by = c("year", "unit", "sex", "age"))) == nrow(mis))
corr <- cells |> filter(read != value | how != "") |>
  left_join(sol$log |> group_by(id) |> summarise(identities_agreeing = max(witnesses), .groups = "drop"), by = "id") |>
  left_join(mis, by = c("year", "unit", "sex", "age")) |>
  transmute(year, unit, sex, age, page, text_layer = coalesce(raw, ""), text_layer_value = read, value = as.integer(value),
            method = case_when(!is.na(printed) ~ "identities; the print itself is wrong", how == "read on the page render" ~ "read on the 300-dpi crop (the identities do not settle it)",
                               TRUE ~ "identities; the print agrees (text layer misread)"), identities_agreeing, printed, note)
write_csv(corr, paste0(sup, "cells_corrected.csv"), na = "")
cat("cells not taken as the text layer gives them:\n"); print(count(corr, method))

# the national row against the other sources
slug <- \(x) tolower(ascii(x)) |> str_replace_all("[^a-z]+", "_") |> str_remove("_$")
nat <- cells |> filter(unit == NAT, age == "all") |> select(year, sex, value) |> pivot_wider(names_from = sex, values_from = value)
c1 <- read_csv("data_input/historical/dane_defunciones_1970_1978_cuadro01_nacional_1915_1984.csv", show_col_types = FALSE)
gap <- read_delim("data_input/historical/col_gap_analysis_1920_1985_department_deaths_clean_v06_territories_split.csv", delim = ";", show_col_types = FALSE, name_repair = "minimal") |>
  select(department, year, total, male, female) |> filter(year %in% 1968:1969)
stopifnot(all(nat$total == c1$deaths[match(nat$year, c1$year)]))
cat("national total of Cuadros 30 and 76 = Cuadro 1 of the 1970-1978 volume (169.007 and 153.882)\n")
cmp <- cells |> filter(unit != NAT, age == "all") |> select(year, unit, sex, value) |> pivot_wider(names_from = sex, values_from = value) |>
  mutate(department = recode(slug(unit), bogota_d_e = "bogota")) |> full_join(gap, by = c("department", "year"), suffix = c("", "_gap"))
dif <- cmp |> filter(!is.na(unit), !is.na(total_gap) | !is.na(male_gap)) |>
  filter(total != coalesce(total_gap, -1) | male != coalesce(male_gap, -1) | female != coalesce(female_gap, -1)) |> select(year, unit, total, male, female, total_gap, male_gap, female_gap)
write_csv(dif, paste0(sup, "differences_vs_col_gap_analysis.csv"), na = "")
cat(sprintf("col_gap_analysis department deaths, territories split: %d unit-years in both, %d differ; units only there: %s\n",
            sum(!is.na(cmp$unit) & !is.na(cmp$total_gap)), nrow(dif), paste(setdiff(unique(gap$department[!is.na(gap$total)]), cmp$department[!is.na(cmp$unit)]), collapse = ", "))); print(dif, n = 40)

# ---------------------------------------------------------------------------
# 5. output ====
# ---------------------------------------------------------------------------
cod <- c(setNames("00", NAT), setNames(units$cod_dpto, units$unit))
o <- cells |> select(year, unit, sex, age, value) |> pivot_wider(names_from = sex, values_from = value) |>
  mutate(across(c(male, female, total), as.integer), cod_dpto = unname(cod[unit])) |>
  arrange(year, match(unit, unit_order), match(age, c("all", ages))) |> select(year, unit, cod_dpto, age, male, female, total)
stopifnot(nrow(o) == 2 * 32 * 26, !anyNA(o))
write_csv(o, paste0(out, "secciones_sexo_edad.csv"))
cat(sprintf("rows written: %d (2 years x 32 units x 26 rows)\n", nrow(o)))
