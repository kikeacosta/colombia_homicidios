# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 74. United States: deaths by state, year, sex, age band and cause group,
#     1968-2004, from the NCHS public-use mortality files
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Input for the validation of the sex-ratio model outside Colombia (70, 72).
# Each year is a zip with one fixed-width text file (0.7-1 GB unzipped). The
# files are read IN PLACE, streamed from the zip in chunks of bytes; nothing
# is extracted or copied, and only the aggregated panel is written.
#
# reading  as bytes, not as text lines, because the files are not uniform:
#          the 1979 file has a null byte in column 10 of many records (a text
#          reader cuts or shortens those lines) and the 1980 file has its
#          lines trimmed on the right (347-372 characters instead of 440).
#          null bytes and the few bytes that are not ASCII become spaces,
#          and a line is kept if it reaches the last field that is read
# one year the environment variable US_YEARS (for example "1979,1980") reads
#          only those years and replaces them in the existing output
#
# The public-use files carry the state only until 2004: from 2005 NCHS
# removes all geography, so those years need another source (CDC WONDER).
#
# 1968-78  layout of the NCHS documentation dt78icd8.pdf (in the folder docs):
#            resident status 12 (4 = foreign resident, from 1970), state of
#            residence 13-14 (01-51 as below; 52-59 abroad), sex 35, age
#            39-41 (unit at 39 as in 1979-2002), underlying cause 60-63 in
#            ICD-8, external causes without the letter E (E960-E969 homicide,
#            E970-E978 legal intervention, E980-E989 undetermined: the same
#            ranges as ICD-9). 1972 is a 50 % sample of the death records:
#            its counts are doubled. 1968-1969 have no foreign residents
#            (NCHS allocated them to the place of occurrence)
# layout   for 1979-2004 there is no layout document in the folder. the positions below are
#          the ones of the NCHS documentation as remembered, and they were
#          CHECKED against the data: the 1990 file gives 2,148,463 deaths of
#          residents, the published total of the year, 51 state codes, and
#          25,020 deaths by homicide and legal intervention (published for
#          residents: 24,932). the log prints the same checks for every year
#            1979-2002 (record of 440)   2003-2004 (record of 488)
#            resident status   20        20       (4 = foreign resident, dropped)
#            state residence   31-32     29-30    (NCHS number / postal letters)
#            sex               59        69       (1, 2 / M, F)
#            age               64-66     70-73    (unit + value, see below)
#            underlying cause  142-145   146-149  (ICD-9 to 1998, ICD-10 from 1999)
# unit     state of residence, as postal abbreviation. the NCHS numbers 01-51
#          are the states in alphabetical order with the District of Columbia
#          in its place; 52 and over (territories, abroad) are dropped
# age      1979-2002: first digit 0 = years, 1 = 100 and over, 2-6 = under one
#          year, 9 unknown. 2003-2004: first digit 1 = years, 2-6 = under one
#          year, 9 unknown. bands 0-14, 15-44, 45+ and unknown
# cause    grouped by intl_cause_icd9 / intl_cause_icd10 (70). in ICD-9 the
#          external causes come without the letter E
#
# input    D:/data/us_mortality/mort<year>us.zip
# output   output/tables/intl_us_deaths_state_year.csv
#            (country, unit, unit_label, year, sex, age_band, cause, deaths)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(data.table)

us_dir <- "D:/data/us_mortality/"
years <- 1968:2004
chunk_bytes <- 1e8
only <- Sys.getenv("US_YEARS")
years_run <- if (nzchar(only)) as.integer(strsplit(only, ",")[[1]]) else years
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

st_name <- sort(c(state.name, "District of Columbia"))
st_abb <- c(setNames(state.abb, state.name), "District of Columbia" = "DC")[st_name]
stopifnot(length(st_name) == 51, st_name[9] == "District of Columbia", st_name[5] == "California", st_name[51] == "Wyoming")
num_to_abb <- setNames(unname(st_abb), sprintf("%02d", 1:51))
abb_to_name <- setNames(st_name, unname(st_abb))

read_year <- function(y) {
  zip <- sprintf("%smort%dus.zip", us_dir, y)
  entry <- unzip(zip, list = TRUE)$Name[1]
  new <- y >= 2003
  icd8 <- y <= 1978
  need <- if (new) 149 else if (icd8) 63 else 145 # last column that is read
  weight <- if (y == 1972) 2L else 1L # 1972: NCHS processed a 50 % sample
  con <- unz(zip, entry, open = "rb"); on.exit(close(con))
  out <- list(); n <- 0; n_bad <- 0; n_foreign <- 0; n_terr <- 0
  carry <- raw(0); n_nul <- 0
  repeat {
    buf <- readBin(con, "raw", n = chunk_bytes)
    done <- !length(buf)
    buf <- c(carry, buf)
    if (!length(buf)) break
    if (!done) { # keep the unfinished last line for the next chunk
      tail_lf <- which(utils::tail(buf, 5000) == as.raw(10))
      last <- length(buf) - min(5000, length(buf)) + max(tail_lf)
      carry <- if (last < length(buf)) buf[(last + 1):length(buf)] else raw(0)
      buf <- buf[seq_len(last)]
    } else carry <- raw(0)
    # null bytes and bytes that are not ASCII become spaces: one of the
    # latter is enough for R to return a whole chunk as NA (1992 and 1996)
    nul <- buf == as.raw(0) | buf >= as.raw(128)
    n_nul <- n_nul + sum(nul); buf[nul] <- as.raw(32); rm(nul)
    l <- strsplit(rawToChar(buf), "\n", fixed = TRUE, useBytes = TRUE)[[1]]
    rm(buf)
    n <- n + length(l)
    stopifnot(!anyNA(l))
    ok <- nchar(l, type = "bytes") >= need
    n_bad <- n_bad + sum(!ok); l <- l[ok]
    foreign <- substr(l, if (icd8) 12 else 20, if (icd8) 12 else 20) == "4"
    n_foreign <- n_foreign + sum(foreign); l <- l[!foreign]
    if (icd8) {
      # 1968-1978 (dt78icd8.pdf): residence 13-14 (52-59 abroad), occurrence
      # 26-27, sex 35, age 39-41 (unit at 39 as in 1979-2002), underlying
      # cause 60-63, ICD-8, external causes without the letter E
      unit <- num_to_abb[substr(l, 13, 14)]
      sx <- substr(l, 35, 35); sex <- fifelse(sx == "1", "m", fifelse(sx == "2", "f", "u"))
      au <- substr(l, 39, 39); av <- suppressWarnings(as.integer(substr(l, 40, 41)))
      age_band <- fcase(au == "1", "45+", au %in% c("2", "3", "4", "5", "6"), "0-14", au != "0" | is.na(av), "unknown",
                        av <= 14, "0-14", av <= 44, "15-44", default = "45+")
      cause <- intl_cause_icd9(trimws(substr(l, 60, 63))) # same ranges in ICD-8: E960-E969, E970-E978, E980-E989
    } else if (new) {
      unit <- substr(l, 29, 30)
      sx <- substr(l, 69, 69); sex <- fifelse(sx == "M", "m", fifelse(sx == "F", "f", "u"))
      au <- substr(l, 70, 70); av <- suppressWarnings(as.integer(substr(l, 71, 73)))
      age_band <- fcase(au %in% c("2", "3", "4", "5", "6"), "0-14", au != "1" | is.na(av) | av > 130, "unknown",
                        av <= 14, "0-14", av <= 44, "15-44", default = "45+")
      cause <- intl_cause_icd10(trimws(substr(l, 146, 149)))
    } else {
      unit <- num_to_abb[substr(l, 31, 32)]
      sx <- substr(l, 59, 59); sex <- fifelse(sx == "1", "m", fifelse(sx == "2", "f", "u"))
      au <- substr(l, 64, 64); av <- suppressWarnings(as.integer(substr(l, 65, 66)))
      age_band <- fcase(au == "1", "45+", au %in% c("2", "3", "4", "5", "6"), "0-14", au != "0" | is.na(av), "unknown",
                        av <= 14, "0-14", av <= 44, "15-44", default = "45+")
      code <- trimws(substr(l, 142, 145))
      cause <- if (y <= 1998) intl_cause_icd9(code) else intl_cause_icd10(code)
    }
    keep <- !is.na(unit) & unit %in% names(abb_to_name)
    n_terr <- n_terr + sum(!keep)
    out[[length(out) + 1]] <- data.table(unit = unit[keep], sex = sex[keep], age_band = age_band[keep], cause = cause[keep])[
      , .(deaths = .N), by = .(unit, sex, age_band, cause)]
    if (done) break
  }
  res <- rbindlist(out)[, .(deaths = sum(deaths) * weight), by = .(unit, sex, age_band, cause)]
  res[, year := y]
  say(y, entry, "| records", n, "| null or non-ASCII bytes", n_nul, "| too short", n_bad, "| foreign residents", n_foreign, "| territories or no state", n_terr,
      "| kept", sum(res$deaths), "| states", uniqueN(res$unit), "| men", sum(res$deaths[res$sex == "m"]), "| unknown sex", sum(res$deaths[res$sex == "u"]),
      "| unknown age", sum(res$deaths[res$age_band == "unknown"]), "| homicide", sum(res$deaths[res$cause == "homicide"]),
      "| legal", sum(res$deaths[res$cause == "legal"]), "| undetermined", sum(res$deaths[res$cause == "undetermined"]))
  res
}

panel <- rbindlist(lapply(years_run, read_year))
panel[, `:=`(country = "us", unit_label = abb_to_name[unit])]
if (nzchar(only)) { # replace only these years in the existing output
  old <- fread("output/tables/intl_us_deaths_state_year.csv")
  panel <- rbind(old[!(year %in% years_run)], panel, use.names = TRUE)
}
setcolorder(panel, c("country", "unit", "unit_label", "year", "sex", "age_band", "cause", "deaths"))
setorder(panel, unit, year, sex, age_band, cause)
fwrite(panel, "output/tables/intl_us_deaths_state_year.csv")

cat("\n== national, by year: deaths and the three violent groups ==\n")
print(as.data.frame(dcast(panel[, .(deaths = sum(deaths)), by = .(year, grp = ifelse(cause %in% intl_violent, cause, "all_other"))],
                          year ~ grp, value.var = "deaths", fill = 0)[, total := all_other + homicide + legal + undetermined][
                            , violent_pct := round(100 * (homicide + legal + undetermined) / total, 2)][]), row.names = FALSE)
cat("\n== states with fewer than 26 years ==\n")
ny <- length(unique(panel$year)); print(panel[, .(n_years = uniqueN(year)), by = unit][n_years < ny])
say("rows written:", nrow(panel))
