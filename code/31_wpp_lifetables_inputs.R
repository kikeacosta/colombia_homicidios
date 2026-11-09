# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 31. WPP 2024 complete life tables, population and fertility: Colombia slice
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The full WPP 2024 csv downloads (UN Population Division, August 2024) are
# kept outside the repository in I:/My Drive/gits_drive/wpp_2024 (about 200 MB
# each, all countries). Only the Colombia rows (LocID 170) are kept here:
#   - complete (single-age) life tables, medium variant, both sexes, female
#     and male, estimates 1950-2023 and projections 2024-2100, stacked
#   - population by single age and sex, estimates 1950-2023
#   - age-specific fertility rates by single age, 1950-2100
# The extracts are small and are versioned in data_input/reference/.
#
# output: data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv
#         data_input/reference/wpp2024_colombia_pop_single_age_1950-2023.csv
#         data_input/reference/wpp2024_colombia_fertility_age1.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))

src <- "I:/My Drive/gits_drive/wpp_2024/"
loc <- 170
out <- \(n) paste0("data_input/reference/wpp2024_colombia_", n, ".csv")

# the gz files are read in chunks, keeping only Colombia
slice <- function(file, chunk = 5e5) {
  cat("  ", file, "\n")
  read_csv_chunked(paste0(src, file), DataFrameCallback$new(\(x, pos) filter(x, LocID == loc)),
                   chunk_size = chunk, show_col_types = FALSE, progress = FALSE,
                   col_types = cols(Notes = col_character(), .default = col_guess()))
}

if (!file.exists(out("lt_complete_1950-2100"))) {
  lt <- expand_grid(sex = c("Both", "Female", "Male"), per = c("1950-2023", "2024-2100")) |>
    pmap(\(sex, per) slice(sprintf("WPP2024_Life_Table_Complete_Medium_%s_%s.csv.gz", sex, per))) |>
    bind_rows() |>
    select(LocID, Location, Variant, Time, Sex, AgeGrp, AgeGrpStart, AgeGrpSpan, mx, qx, px, lx, dx, Lx, Sx, Tx, ex, ax) |>
    arrange(Sex, Time, AgeGrpStart)
  write_csv(lt, out("lt_complete_1950-2100"))
}

if (!file.exists(out("pop_single_age_1950-2023"))) {
  slice("WPP2024_PopulationBySingleAgeSex_Medium_1950-2023.csv.gz") |>
    select(LocID, Location, Variant, Time, AgeGrp, AgeGrpStart, AgeGrpSpan, PopMale, PopFemale, PopTotal) |>
    write_csv(out("pop_single_age_1950-2023"))
}

if (!file.exists(out("fertility_age1"))) {
  slice("WPP2024_Fertility_by_Age1.csv.gz") |>
    select(-any_of(c("SortOrder", "Notes", "ISO3_code", "ISO2_code", "SDMX_code", "LocTypeID", "LocTypeName", "ParentID", "VarID"))) |>
    write_csv(out("fertility_age1"))
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# summary ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lt <- read_csv(out("lt_complete_1950-2100"), show_col_types = FALSE)
cat("\nlife tables:", nrow(lt), "rows;", paste(range(lt$Time), collapse = "-"), "; sexes:", paste(unique(lt$Sex), collapse = ", "), "\n")
lt |> filter(AgeGrpStart == 0, Time %in% c(1950, 1973, 1985, 2000, 2023, 2050)) |>
  select(Time, Sex, ex) |> pivot_wider(names_from = Sex, values_from = ex) |> print()
fx <- read_csv(out("fertility_age1"), show_col_types = FALSE)
cat("\nfertility:", nrow(fx), "rows; columns:", paste(names(fx), collapse = ", "), "\n")
