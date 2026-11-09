# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 26. WPP 2024 mortality-crisis files: Colombia slice
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# data_input/251208_MortalityCrises.zip (803 MB, UN Population Division,
# December 2025) holds the crisis components of the WPP 2024 mortality
# estimates for all countries: single-age mx attributable to conflicts,
# disasters, famine and COVID-19 (WPP2024_mx1_*.csv.gz), the complete life
# tables without crises (WPP2024_LT1_crises_free.csv.gz, 543 MB) and the
# crisis event lists. Only the Colombia rows (LocID 170) are kept; the
# extracts are small and are versioned in data_input/reference/.
#
# output: data_input/reference/wpp2024_crises_colombia_mx1_<type>.csv
#         data_input/reference/wpp2024_crises_colombia_lt1_crises_free.csv
#         data_input/reference/wpp2024_crises_colombia_events.csv
#         data_input/reference/wpp2024_crises_colombia_country.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))

zipf <- "data_input/251208_MortalityCrises.zip"
loc <- 170
out <- \(n) paste0("data_input/reference/wpp2024_crises_colombia_", n, ".csv")

# gz members are read through a gzip connection on the zip entry, in chunks,
# keeping only Colombia
slice <- function(member, chunk = 5e5) {
  # readr closes the connection itself
  read_csv_chunked(gzcon(unz(zipf, member)), DataFrameCallback$new(\(x, pos) filter(x, LocID == loc)),
                   chunk_size = chunk, show_col_types = FALSE, progress = FALSE)
}

for (type in c("conflicts", "crises", "disasters", "famine", "COVID")) {
  f <- out(paste0("mx1_", tolower(type)))
  if (!file.exists(f)) {
    cat("extracting mx1", type, "...\n")
    slice(paste0("WPP2024_mx1_", type, ".csv.gz")) |> write_csv(f)
  }
}
if (!file.exists(out("lt1_crises_free"))) {
  cat("extracting LT1 crises free (543 MB, several minutes) ...\n")
  slice("WPP2024_LT1_crises_free.csv.gz", chunk = 1e6) |> write_csv(out("lt1_crises_free"))
}

# plain csv members: event list and country summary (column names unknown
# beforehand, Colombia identified by LocID or location name)
plain <- function(member) {
  x <- read_csv(unz(zipf, member), show_col_types = FALSE, progress = FALSE)
  key <- intersect(c("LocID", "locid", "Location", "location", "country", "Country", "iso3"), names(x))
  if (length(key) == 0) stop("no location column in ", member, ": ", paste(names(x), collapse = ", "))
  x |> filter(if_any(all_of(key), \(v) v %in% c(loc, "Colombia", "COL")))
}
if (!file.exists(out("events"))) plain("wpp2024_country_event_data_crisis.csv") |> write_csv(out("events"))
if (!file.exists(out("country"))) plain("wpp2024_country_data_crisis.csv") |> write_csv(out("country"))
if (!file.exists(out("cdr"))) plain("wpp2024_cdr_crises.csv") |> write_csv(out("cdr"))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# summary ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pop <- read_rds("data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds") |>
  mutate(Sex = recode(sex, m = "male", f = "female")) |> select(Year = year, Sex, age_start = age, pop, mx_total = mx)

conf <- read_csv(out("mx1_conflicts"), show_col_types = FALSE)
cat("\nmx1_conflicts columns:", paste(names(conf), collapse = ", "), "\n")
cat("conflict deaths implied (mx_conflict x WPP population), by year and sex:\n")
conf_d <- conf |> inner_join(pop, by = c("Year", "Sex", "age_start")) |>
  summarise(deaths = round(sum(value * pop)), .by = c(Year, Sex)) |>
  filter(deaths > 0) |> pivot_wider(names_from = Sex, values_from = deaths)
print(as.data.frame(conf_d))

ev <- read_csv(out("events"), show_col_types = FALSE)
cat("\nevents columns:", paste(names(ev), collapse = ", "), "\n")
print(ev |> as.data.frame() |> head(40))

lt <- read_csv(out("lt1_crises_free"), show_col_types = FALSE)
cat("\nLT1 crises free columns:", paste(names(lt), collapse = ", "), "; years", range(lt$Year), "\n")
cat("check: mx_total - mx_crises_free against mx_crises (all crisis types), men 2002, selected ages:\n")
cri <- read_csv(out("mx1_crises"), show_col_types = FALSE)
print(lt |> filter(Sex == "male", Year == 2002, Age %in% c(20, 25, 30, 40)) |>
        select(Year, Sex, age_start = Age, mx_free = nMx) |>
        inner_join(pop, by = c("Year", "Sex", "age_start")) |>
        inner_join(cri |> select(Year, Sex, age_start, mx_crises = value), by = c("Year", "Sex", "age_start")) |>
        inner_join(conf |> select(Year, Sex, age_start, mx_conflict = value), by = c("Year", "Sex", "age_start")) |>
        mutate(diff = mx_total - mx_free) |> as.data.frame())
