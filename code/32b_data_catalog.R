# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 32b. Data catalog: sources, input files and source documents, checked
#      against the disk
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The inventory as data. Two tables are kept by hand in documents/inventory/:
#
#   fuentes.csv    one row per source (institution, title, url, access)
#   archivos.csv   one row per input file or group of files (`patron`, a path
#                  relative to the project root where `*` stands for any run
#                  of characters inside one folder): type, source, geographic
#                  level, domain, years, detail, use, scripts and, for source
#                  documents, the url of the original. Entries with
#                  uso = "no descargado" are documents cited by the
#                  transcriptions that are not held locally.
#
# This script lists every file under data_input/, literature/ and
# documents/metadata/, assigns it to the first catalog entry whose pattern
# matches, and adds what can be read from the disk: size, modification time,
# sha256 and whether git tracks it. It reports
#   - files on disk that no entry covers (to be added to archivos.csv)
#   - entries with no file on disk (other than "no descargado")
#   - the source documents and papers that exist only on this disk
#
# Most inputs are not versioned, so a git worktree does not have them: set
# COL_PROJECT_ROOT to the main checkout to scan it from a worktree.
#
# Backup. With COL_BACKUP_DIR set, the source documents and papers that git
# does not track are copied there under the same relative paths and checked
# by sha256 (COL_BACKUP_SCOPE=all copies every unversioned input instead,
# 2.9 GB). Nothing is copied otherwise.
#
# input:  documents/inventory/fuentes.csv, documents/inventory/archivos.csv
# output: output/tables/data_catalog.csv        one row per catalog entry
#         output/tables/data_catalog_files.csv  one row per file, with sha256
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))

root <- Sys.getenv("COL_PROJECT_ROOT", ".")
backup_dir <- Sys.getenv("COL_BACKUP_DIR", "")
backup_all <- Sys.getenv("COL_BACKUP_SCOPE", "") == "all"
scan_dirs <- c("data_input", "literature", "documents/metadata")
scan_files <- c("documents/Lista_105_Colombia_CIE9-y-CIE10.xls", "documents/datos_mortalidad_colombia_03_2026.xlsx")
f_files <- "output/tables/data_catalog_files.csv"

fuentes <- read_csv("documents/inventory/fuentes.csv", col_types = cols(.default = "c"))
arch <- read_csv("documents/inventory/archivos.csv", col_types = cols(.default = "c"))
stopifnot(nrow(problems(fuentes)) == 0, nrow(problems(arch)) == 0,
          !anyDuplicated(fuentes$fuente_id), !anyDuplicated(arch$patron),
          all(arch$fuente_id %in% fuentes$fuente_id))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# files on disk ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
on_disk <- c(unlist(map(scan_dirs, \(d) file.path(d, list.files(file.path(root, d), recursive = TRUE)))),
             scan_files[file.exists(file.path(root, scan_files))])
tracked <- system2("git", c("-C", shQuote(root), "-c", "core.quotepath=off", "ls-files"), stdout = TRUE)
Encoding(tracked) <- "UTF-8"

# a pattern becomes a regular expression: `*` is any run of characters other
# than `/`; matching ignores case (LD_771_1964.PDF in the library, .pdf here)
glob_rx <- function(g) {
  x <- gsub("([.+^$(){}|\\[\\]\\\\])", "\\\\\\1", g, perl = TRUE)
  paste0("^", gsub("*", "[^/]*", x, fixed = TRUE), "$")
}
is_abs <- str_detect(arch$patron, "^([A-Za-z]:|/)")
rx <- map_chr(arch$patron, glob_rx)
first_match <- function(f) {
  hit <- which(!is_abs & map_lgl(rx, \(r) grepl(r, f, ignore.case = TRUE, perl = TRUE)))
  if (length(hit)) arch$patron[hit[1]] else NA_character_
}

files <- tibble(ruta = on_disk) |>
  mutate(patron = map_chr(ruta, first_match),
         bytes = file.size(file.path(root, ruta)),
         modificado = format(file.mtime(file.path(root, ruta)), "%Y-%m-%d %H:%M"),
         en_git = ruta %in% tracked)

# sha256, reusing the previous run where size and time have not changed
sha256 <- function(p) {
  if (exists("sha256sum", asNamespace("tools"))) unname(tools::sha256sum(p))
  else map_chr(p, \(x) digest::digest(x, algo = "sha256", file = TRUE))
}
old <- if (file.exists(f_files)) {
  read_csv(f_files, col_types = cols(.default = "c", bytes = "d")) |>
    filter(!is.na(sha256)) |> select(ruta, bytes, modificado, sha256)
} else tibble(ruta = character(), bytes = numeric(), modificado = character(), sha256 = character())
files <- files |> left_join(old, by = c("ruta", "bytes", "modificado"))
todo <- is.na(files$sha256)
cat(sprintf("hashing %d of %d files (%.1f GB)\n", sum(todo), nrow(files), sum(files$bytes[todo]) / 1e9))
files$sha256[todo] <- sha256(file.path(root, files$ruta[todo]))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# catalog entries ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
per_entry <- files |> filter(!is.na(patron)) |>
  summarise(n_archivos = n(), bytes = sum(bytes), modificado = max(modificado),
            en_git = case_when(all(en_git) ~ "sí", any(en_git) ~ "parcial", TRUE ~ "no"), .by = patron)
# entries outside the project (absolute paths): existence and size only
outside <- arch |> filter(is_abs) |>
  transmute(patron, n_archivos = if_else(file.exists(patron), 1L, 0L),
            bytes = if_else(dir.exists(patron), NA_real_, file.size(patron)),
            modificado = format(file.mtime(patron), "%Y-%m-%d %H:%M"), en_git = "no")
catalog <- arch |>
  left_join(bind_rows(per_entry, outside), by = "patron") |>
  left_join(fuentes |> select(fuente_id, institucion, titulo), by = "fuente_id") |>
  mutate(n_archivos = coalesce(n_archivos, 0L), en_disco = n_archivos > 0,
         en_git = if_else(en_disco, en_git, NA_character_)) |>
  select(patron, tipo, fuente_id, institucion, titulo, nivel, dominio, anios, detalle, uso, scripts,
         en_disco, n_archivos, bytes, modificado, en_git, url, notas)

write_csv(catalog, "output/tables/data_catalog.csv", na = "")
write_csv(files |> left_join(arch |> select(patron, tipo, fuente_id, uso), by = "patron") |>
            select(ruta, patron, tipo, fuente_id, uso, bytes, modificado, en_git, sha256) |> arrange(ruta),
          f_files, na = "")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# report ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
mb <- \(x) sprintf("%.1f MB", sum(x, na.rm = TRUE) / 1e6)
cat(sprintf("\n%d sources, %d catalog entries, %d files on disk (%s), %d tracked by git\n",
            nrow(fuentes), nrow(arch), nrow(files), mb(files$bytes), sum(files$en_git)))

uncatalogued <- files |> filter(is.na(patron))
cat(sprintf("\nfiles on disk not covered by archivos.csv: %d\n", nrow(uncatalogued)))
if (nrow(uncatalogued)) print(uncatalogued |> select(ruta, bytes, modificado), n = 100, width = 200)

missing <- catalog |> filter(!en_disco, uso != "no descargado")
cat(sprintf("\ncatalog entries with no file on disk: %d\n", nrow(missing)))
if (nrow(missing)) print(missing |> select(patron, uso), n = 100, width = 200)

docs <- files |> left_join(arch |> select(patron, tipo), by = "patron") |>
  filter(tipo %in% c("documento fuente", "literatura"))
cat(sprintf("\nsource documents and papers on disk: %d (%s); only on this disk (not in git): %d (%s)\n",
            nrow(docs), mb(docs$bytes), sum(!docs$en_git), mb(docs$bytes[!docs$en_git])))
cat(sprintf("source documents cited by the transcriptions and not downloaded: %d\n",
            sum(catalog$uso == "no descargado" & !catalog$en_disco)))
print(catalog |> summarise(entradas = n(), archivos = sum(n_archivos), MB = round(sum(bytes, na.rm = TRUE) / 1e6, 1),
                           .by = c(tipo, uso)) |> arrange(tipo, uso), n = 40)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# backup (only with COL_BACKUP_DIR) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (nzchar(backup_dir)) {
  to_copy <- if (backup_all) files |> filter(!en_git) else docs |> filter(!en_git)
  dest <- file.path(backup_dir, to_copy$ruta)
  need <- !file.exists(dest) | file.size(dest) != to_copy$bytes
  cat(sprintf("\nbackup to %s: %d files, %d to copy (%s)\n", backup_dir, nrow(to_copy), sum(need), mb(to_copy$bytes[need])))
  walk(unique(dirname(dest[need])), \(d) dir.create(d, recursive = TRUE, showWarnings = FALSE))
  ok <- file.copy(file.path(root, to_copy$ruta[need]), dest[need], overwrite = TRUE, copy.date = TRUE)
  same <- sha256(dest) == to_copy$sha256
  cat(sprintf("copied %d; %d of %d files in the backup match their sha256\n", sum(ok), sum(same), length(same)))
  stopifnot(all(ok), all(same))
}
