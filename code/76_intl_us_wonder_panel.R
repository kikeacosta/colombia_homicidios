# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 76. United States, 1968-2020: unit-year data for the validation (72),
#     joining the microdata of 1968-2004 (74) and CDC WONDER for 2005-2020
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The public-use microdata carry the state from 1968 until 2004. From 2005 the
# counts come from CDC WONDER (Underlying Cause of Death, 1999-2020), which
# suppresses counts of 0-9 by state. The tables were queried so that the
# model gets what it needs without any suppressed count being derived:
#   all causes by year x state x sex          -> d, dm, df
#   violent deaths by year x state, NO sex    -> h
#   violent deaths by year x sex, national    -> share of men (pi)
# The homicides by state and sex (us_homicides_state_sex_*.xls) are NOT
# read: with the state totals they would allow the suppressed female counts
# to be derived by subtraction.
#
# violent  homicide (X85-Y09) + legal intervention (Y35; WONDER adds Y36,
#          war, about zero). NARROWER than in the other countries: the WONDER
#          tables do not include undetermined intent (Y10-Y34), 20 % of the
#          violent deaths of 1999-2004. the microdata years use the same
#          narrow definition (cause groups homicide + legal of 74). in
#          1979-2004 the validation with and without undetermined intent
#          differs by 0-2 points of median error
# units    states with a suppressed count of violent deaths in any year of
#          2005-2020 are dropped, so that the units are the same in every
#          year: Vermont, Wyoming and North Dakota (all ages); also New
#          Hampshire, South Dakota, Maine and Hawaii (ages 15-44)
# splice   microdata to 2004, WONDER from 2005. the overlap 1999-2004 is
#          printed: all causes match exactly; violent deaths are about 1 %
#          lower in WONDER (it leaves out the sequelae of assault, Y87.1, and
#          of legal intervention, Y89.0, which 74 counts)
# ages     "all" and "15-44" (WONDER ten-year groups 15-24, 25-34, 35-44)
#
# inputs   output/tables/intl_us_deaths_state_year.csv                    (74)
#          D:/data/us_mortality/cdc_wonder/us_all_cause_state_sex_all_ages.xls, _15_44.xls
#          D:/data/us_mortality/cdc_wonder/us_homicides_state.xls, _15_44.xls
#          D:/data/us_mortality/cdc_wonder/us_homicides_sex.xls, _15_44.xls
# output   output/tables/intl_us_unit_year_1968-2020.csv
#            (country, unit, unit_label, ages, year, d, dm, df, h, hm, hf, source)
#          output/tables/intl_us_male_share.csv (ages, pi, years, source)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(data.table)

wonder_dir <- "D:/data/us_mortality/cdc_wonder/"
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
narrow <- c("homicide", "legal")
abb <- setNames(c(state.abb, "DC"), c(state.name, "District of Columbia"))

read_wonder <- function(f) {
  x <- fread(paste0(wonder_dir, f), sep = "\t", colClasses = "character", fill = TRUE)
  x <- x[grepl("^[0-9]{4}$", Year)]
  x[, `:=`(year = as.integer(Year), deaths = suppressWarnings(as.numeric(Deaths)), suppressed = Deaths == "Suppressed")]
  if ("State" %in% names(x)) x[, unit := abb[State]]
  x
}

# ---- microdata, 1979-2004 ----
micro <- fread("output/tables/intl_us_deaths_state_year.csv")
from_micro <- function(ages) {
  p <- if (ages == "all") micro else micro[age_band == "15-44"]
  p[, .(d = sum(deaths), dm = sum(deaths[sex == "m"]), df = sum(deaths[sex == "f"]),
        h = sum(deaths[cause %in% narrow]), hm = sum(deaths[cause %in% narrow & sex == "m"]),
        hf = sum(deaths[cause %in% narrow & sex == "f"])), by = .(unit, unit_label, year)]
}

# ---- WONDER, 1999-2020 ----
from_wonder <- function(ages) {
  sfx <- if (ages == "all") c("_all_ages", "") else c("_15_44", "_15_44")
  ac <- read_wonder(paste0("us_all_cause_state_sex", sfx[1], ".xls"))
  vi <- read_wonder(paste0("us_homicides_state", sfx[2], ".xls"))
  stopifnot(!any(ac$suppressed[ac$Sex %in% c("Male", "Female")]))
  a <- ac[Sex %in% c("Male", "Female"), .(d = sum(deaths), dm = sum(deaths[Sex == "Male"]), df = sum(deaths[Sex == "Female"])), by = .(unit, year)]
  merge(a, vi[, .(unit, year, h = deaths, h_suppressed = suppressed)], by = c("unit", "year"))
}

# ---- national share of men among the violent deaths ----
male_share <- function(ages) {
  m <- from_micro(ages)
  w <- read_wonder(if (ages == "all") "us_homicides_sex.xls" else "us_homicides_sex_15_44.xls")[year >= 2005]
  stopifnot(!any(w$suppressed))
  hm <- sum(m$hm) + sum(w$deaths[w$Sex == "Male"]); hf <- sum(m$hf) + sum(w$deaths[w$Sex == "Female"])
  data.table(ages = ages, pi = hm / (hm + hf), pi_micro_1968_2004 = sum(m$hm) / sum(m$hm + m$hf),
             pi_wonder_2005_2020 = sum(w$deaths[w$Sex == "Male"]) / sum(w$deaths))
}

out <- list(); pis <- list()
for (ages in c("all", "15-44")) {
  m <- from_micro(ages); w <- from_wonder(ages)
  ov <- merge(m[year %in% 1999:2004], w[year %in% 1999:2004], by = c("unit", "year"), suffixes = c("_micro", "_wonder"))
  say(ages, "| overlap 1999-2004, WONDER / microdata: all causes", round(sum(ov$d_wonder) / sum(ov$d_micro), 4),
      "| men", round(sum(ov$dm_wonder) / sum(ov$dm_micro), 4),
      "| violent (cells not suppressed)", round(sum(ov$h_wonder[!ov$h_suppressed]) / sum(ov$h_micro[!ov$h_suppressed]), 4))
  drop <- w[year >= 2005 & h_suppressed == TRUE, sort(unique(unit))]
  say(ages, "| states dropped (suppressed violent deaths in 2005-2020):", paste(drop, collapse = ", "))
  w <- w[year >= 2005 & !(unit %in% drop)]
  lab <- unique(m[, .(unit, unit_label)])
  out[[ages]] <- rbind(
    m[!(unit %in% drop)][, `:=`(source = "microdata (74)")],
    w[, .(unit, year, d, dm, df, h, hm = NA_real_, hf = NA_real_, source = "CDC WONDER")][lab, on = "unit", nomatch = 0],
    use.names = TRUE)[, ages := ages]
  pis[[ages]] <- male_share(ages)
}
res <- rbindlist(out, use.names = TRUE)[, country := "us"]
setcolorder(res, c("country", "unit", "unit_label", "ages", "year", "d", "dm", "df", "h", "hm", "hf", "source"))
setorder(res, ages, unit, year)
stopifnot(res[, uniqueN(year), by = .(ages, unit)][, all(V1 == 53)])
fwrite(res, "output/tables/intl_us_unit_year_1968-2020.csv")
pis <- rbindlist(pis)
fwrite(pis, "output/tables/intl_us_male_share.csv")

cat("\n== share of men among violent deaths (narrow definition) ==\n"); print(pis)
cat("\n== national violent deaths, all ages, units kept ==\n")
print(dcast(res[ages == "all" & year %in% c(1979, 1990, 2000, 2004, 2005, 2006, 2010, 2015, 2019, 2020),
                .(h = sum(h), share_pct = round(100 * sum(h) / sum(d), 2)), by = .(year, source)], year ~ source, value.var = "h"))
say("units: all ages", res[ages == "all", uniqueN(unit)], "| 15-44", res[ages == "15-44", uniqueN(unit)])
