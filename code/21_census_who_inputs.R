# 21_census_who_inputs.R -----------------------------------------------------
# inputs for the national DDM on unadjusted census counts (22):
#   1. census population by single age and sex, censuses 1951-2018, as
#      enumerated (no DANE omission correction), from the UN Demographic
#      Statistics Database (UNdata, table 22 "Population by age, sex and
#      urban/rural residence"), plus the 2005 and 2018 foreign-born population
#      by age and sex (table 44), used in 22 to remove the 2005-2018
#      immigration (Venezuela) from the closed-population assumption.
#   2. registered deaths by age and sex, 1953-1977, from the WHO Mortality
#      Database raw files (ICD-7 and ICD-8), to cover the intercensal windows
#      before the DANE microdata (1979+).
#   3. stock of Colombian-born emigrants abroad by sex and age, 1990-2024,
#      from UN DESA International Migrant Stock 2024 (by destination, origin
#      and sex), distributed by age with the 2020 revision's age profile of
#      all migrants in each destination (Colombians are assumed to share it;
#      destinations without a profile take the world one). Used in 22 to add
#      the intercensal net emigration back to the second census.
#
# UNdata's download handler is broken (404), so the record view is scraped page
# by page (50 records each) and cached in data_input/census_raw/; the parsed
# tables are versioned in data_input/reference/.
#
# WHO raw files (place in data_input/who_mdb/, from
# https://www.who.int/data/data-collection-tools/who-mortality-database):
#   morticd07.zip, morticd08.zip, mort_documentation.zip
# UN DESA files (place in data_input/migration/, from
# https://www.un.org/development/desa/pd/content/international-migrant-stock):
#   undesa_pd_2024_ims_stock_by_sex_destination_and_origin.xlsx
#   undesa_pd_2020_ims_stock_by_age_sex_and_destination.xlsx
# Colombia is country 2130; years 1971, 1973 and 1978 are missing.
# Age formats 01 and 02 both give 0, 1-4 (01: 1, 2, 3, 4), 5-9, ..., 80-84,
# 85+ and unknown (Deaths2 to Deaths23, Deaths26).
#
# outputs:
#   data_input/reference/undata_census_colombia.csv
#   data_input/reference/undata_foreign_born_colombia.csv
#   data_input/reference/who_deaths_age_colombia_1953-1977.csv
#   data_inter/census_pop_age.rds   (census, date, sex, age 0,1,5,...,80, pop, fb)
#   data_inter/who_deaths_age_1953-1977.rds  (year, sex, age, dx)
#   data_inter/emigrant_stock_age_1990-2024.rds  (year, sex, age 0,1,5,...,80, stock)

rm(list = ls())
gc()
source("code/00_setup.R")
library(rvest)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# UNdata scrape ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
undata_table <- function(table_code, cache) {
  url <- paste0("https://data.un.org/Data.aspx?d=POP&f=tableCode:", table_code, ";countryCode:170")
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  first <- file.path(cache, "p1.html")
  if (!file.exists(first)) download.file(paste0(url, "&v=1"), first, quiet = TRUE)
  n_pages <- as.integer(html_text(html_element(read_html(first), "#spanPageCountB")))
  map_dfr(seq_len(n_pages), \(i) {
    f <- file.path(cache, paste0("p", i, ".html"))
    if (!file.exists(f)) download.file(paste0(url, "&v=", i), f, quiet = TRUE)
    # the last column (footnote marks) has no header
    t <- suppressMessages(read_html(f) |> html_element(".DataContainer table") |> html_table(convert = FALSE))
    t[nzchar(names(t)) & !startsWith(names(t), "...")]
  }) |>
    rename_with(\(x) str_to_lower(str_replace_all(x, " ", "_"))) |>
    mutate(across(everything(), str_squish), value = as.numeric(str_remove_all(value, ",")))
}

f_cen <- "data_input/reference/undata_census_colombia.csv"
f_fb <- "data_input/reference/undata_foreign_born_colombia.csv"
if (!file.exists(f_cen)) write_csv(undata_table(22, "data_input/census_raw/undata_t22"), f_cen)
if (!file.exists(f_fb)) {
  undata_table(44, "data_input/census_raw/undata_t44") |>
    filter(country_of_birth == "Total Foreign-born") |>
    write_csv(f_fb)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# census population, 0, 1-4, 5-9, ..., 80+ ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# census reference dates (DANE): 2005 is the 30 June 2005 reference date of
# the 2005-06 operation; 2018 ran April-October, taken at mid-year
census_dates <- tribble(
  ~year, ~date,
  1938, "1938-07-05", 1951, "1951-05-09", 1964, "1964-07-15", 1973, "1973-10-24", 1985, "1985-10-15",
  1993, "1993-10-24", 2005, "2005-06-30", 2018, "2018-06-30"
) |>
  mutate(date = as.Date(date), dec = year(date) + (yday(date) - 1) / 365.25)

# open age 80+: the 1973 tabulation stops at "80 +"
age_top <- 80

# one tabulation per census: national total, de jure when there is one (2005,
# 2018), else de facto; then the source year with the most records, completed
# with ages it lacks from other source years (1993 women aged 31 come only in
# the 2008 release)
prep_age <- function(x) {
  x |>
    filter(area == "Total", sex %in% c("Male", "Female")) |>
    mutate(jure = str_detect(record_type, "de jure")) |>
    filter(jure == max(jure), .by = year) |>
    mutate(n = n(), .by = c(year, source_year)) |>
    mutate(main = n == max(n), .by = year) |>
    filter(main | !any(main), .by = c(year, sex, age)) |>
    filter(source_year == max(source_year), .by = c(year, sex, age)) |>
    select(-main) |>
    mutate(
      sex = if_else(sex == "Male", "m", "f"),
      lo = suppressWarnings(as.integer(str_extract(age, "^\\d+"))),
      single = str_detect(age, "^\\d+$"),
      open = str_detect(age, "\\+$")
    ) |>
    select(-n)
}

# per census and sex, ages 0, 1-4, 5-9, ..., 80+: from single ages when the
# tabulation has them, else from 0, 1-4 and the 5-year groups; above 80, the
# "80 +" group when there is one, else the single (or 5-year) ages plus the
# highest open group. "Unknown" is spread pro rata.
agg_age <- function(x) {
  x |>
    filter(age != "Total") |>
    group_by(year, sex) |>
    group_modify(\(d, k) {
      unk <- sum(d$value[d$age == "Unknown"])
      d <- d |> filter(!is.na(lo))
      has_single <- any(d$single & d$lo >= 5 & d$lo < age_top)
      low <-
        if (has_single) {
          d |> filter(single, lo < age_top)
        } else {
          d |> filter(age %in% c("0", "1 - 4") | (str_detect(age, " - ") & lo >= 5 & lo < age_top))
        }
      top <- d |> filter(lo >= age_top)
      top <-
        if (any(top$open & top$lo == age_top)) {
          top |> filter(open, lo == age_top)
        } else {
          fine <- if (has_single && any(top$single)) top |> filter(single) else top |> filter(str_detect(age, " - "))
          bind_rows(fine, top |> filter(open, lo == max(lo[open])))
        }
      bind_rows(low, top) |>
        mutate(a = case_when(lo == 0 ~ 0, lo < 5 ~ 1, lo >= age_top ~ age_top, TRUE ~ 5 * (lo %/% 5))) |>
        summarise(pop = sum(value), .by = a) |>
        mutate(pop = pop * (1 + unk / sum(pop)))
    }) |>
    ungroup() |>
    rename(age = a)
}

cen <- read_csv(f_cen, col_types = cols(.default = "c", value = "d", year = "i")) |> prep_age()
pop <- agg_age(cen)

# check: aggregated totals against the census totals
tot <- cen |> filter(age == "Total") |> select(year, sex, total = value)
chk <- pop |> summarise(pop = sum(pop), .by = c(year, sex)) |> left_join(tot, by = c("year", "sex"))
print(chk |> mutate(ratio = round(pop / total, 4)) |> as.data.frame())
stopifnot(all(abs(chk$pop / chk$total - 1) < 0.005))

fb <-
  read_csv(f_fb, col_types = cols(.default = "c", value = "d", year = "i")) |>
  prep_age() |>
  agg_age() |>
  rename(fb = pop)
cat("foreign-born totals by census:\n")
print(fb |> summarise(fb = sum(fb), .by = c(year, sex)))

# 1938 census from LAMBdA (ages 0, 1, 5, ..., 85, 999 = unknown); its 1951-2005
# counts are identical to UNdata's. The earlier LAMBdA censuses are not used:
# 1912 and 1918 tabulated mainly men of voting and military age, with many
# unknown ages, and the 1928 results were inflated and never approved
# (Estrada Orrego 2017, Historia Critica 64, doi 10.7440/histcrit64.2017.08).
lambda <-
  map_dfr(c(m = "m", f = "f"), \(s) read_tsv(paste0("data_input/historical/lambda_Col_Pop", s, ".txt"),
                                               show_col_types = FALSE), .id = "sex") |>
  rename(year = Year, age = Age, value = Population) |>
  filter(year == 1938) |>
  mutate(unk = sum(value[age == 999]), .by = sex) |>
  filter(age != 999) |>
  mutate(age = pmin(age, age_top)) |>
  summarise(pop = sum(value), unk = first(unk), .by = c(year, sex, age)) |>
  mutate(pop = pop * (1 + unk / sum(pop)), .by = sex) |>
  select(-unk)

census_pop_age <-
  bind_rows(lambda, pop) |>
  left_join(fb, by = c("year", "sex", "age")) |>
  left_join(census_dates, by = "year") |>
  rename(census = year) |>
  select(census, date, dec, sex, age, pop, fb) |>
  arrange(census, sex, age)
write_rds(census_pop_age, "data_inter/census_pop_age.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# WHO deaths by age, 1953-1977 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
f_who <- "data_input/reference/who_deaths_age_colombia_1953-1977.csv"
if (!file.exists(f_who)) {
  read_who <- function(zipf, member) {
    con <- unz(zipf, member)
    x <- fread(text = readLines(con), colClasses = list(character = c("Admin1", "SubDiv", "List", "Cause", "Frmat", "IM_Frmat")))
    x[Country == 2130 & Cause %in% c("A000", "B000")]
  }
  bind_rows(
    read_who("data_input/who_mdb/morticd07.zip", "MortIcd7"),
    read_who("data_input/who_mdb/morticd08.zip", "Morticd8")
  ) |>
    as_tibble() |>
    write_csv(f_who)
}

who_cols <- c(setNames(2, 0), setNames(3:6, rep(1, 4)), setNames(7:22, seq(5, 80, 5)), setNames(23, 85), setNames(26, NA))
who <-
  read_csv(f_who, show_col_types = FALSE) |>
  filter(Sex %in% 1:2) |>
  select(year = Year, Sex, num_range("Deaths", 1:26)) |>
  pivot_longer(starts_with("Deaths"), names_to = "col", values_to = "dx", names_prefix = "Deaths",
               names_transform = as.integer) |>
  mutate(sex = if_else(Sex == 1, "m", "f"), age = as.numeric(names(who_cols)[match(col, who_cols)])) |>
  filter(col %in% who_cols) |>
  replace_na(list(dx = 0))

# check: age groups add up to the all-ages column
all_ages <- read_csv(f_who, show_col_types = FALSE) |> filter(Sex %in% 1:2) |> select(year = Year, Sex, all = Deaths1)
stopifnot(all(who |> summarise(dx = sum(dx), .by = c(year, Sex)) |> left_join(all_ages, by = c("year", "Sex")) |>
                with(dx == all)))

who_deaths_age <-
  who |>
  summarise(dx = sum(dx), .by = c(year, sex, age)) |>
  mutate(unk = sum(dx[is.na(age)]), tot = sum(dx[!is.na(age)]), .by = c(year, sex)) |>
  filter(!is.na(age)) |>
  mutate(dx = dx * (1 + unk / tot)) |>
  select(year, sex, age, dx) |>
  arrange(year, sex, age)
write_rds(who_deaths_age, "data_inter/who_deaths_age_1953-1977.rds")

cat("\nWHO deaths by year (both sexes):\n")
print(who_deaths_age |> summarise(dx = round(sum(dx)), .by = year) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# WHO violent deaths by age, 1953-1977 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# same files, abbreviated lists: ICD-7 A149 "homicide and operations of war"
# (E964, E980-E985, i.e. homicide plus injuries of undetermined intent, the
# counterpart of this project's dx_v); ICD-8 A148 homicide (E960-E969) and
# A149 undetermined intent (E980-E989). The totals by sex of A149/A148 match
# data_input/reference/who/who_homicide_colombia.csv (3,772 in 1953).
# Colombia reported no causes for 1970, 1971 and 1973 under ICD-8.
f_whov <- "data_input/reference/who_violent_age_colombia_1953-1977.csv"
if (!file.exists(f_whov)) {
  read_who_causes <- function(zipf, member, causes) {
    x <- fread(text = readLines(unz(zipf, member)), colClasses = list(character = c("Admin1", "SubDiv", "List", "Cause", "Frmat", "IM_Frmat")))
    x[Country == 2130 & Cause %in% causes]
  }
  bind_rows(
    read_who_causes("data_input/who_mdb/morticd07.zip", "MortIcd7", "A149") |> mutate(group = "violent"),
    read_who_causes("data_input/who_mdb/morticd08.zip", "Morticd8", c("A148", "A149")) |>
      mutate(group = if_else(Cause == "A148", "homicide", "undetermined"))
  ) |>
    as_tibble() |>
    write_csv(f_whov)
}
who_violent_age <-
  read_csv(f_whov, show_col_types = FALSE) |>
  filter(Sex %in% 1:2) |>
  select(year = Year, Sex, group, num_range("Deaths", 1:26)) |>
  pivot_longer(starts_with("Deaths"), names_to = "col", values_to = "dx", names_prefix = "Deaths",
               names_transform = as.integer) |>
  mutate(sex = if_else(Sex == 1, "m", "f"), age = as.numeric(names(who_cols)[match(col, who_cols)])) |>
  filter(col %in% who_cols) |>
  replace_na(list(dx = 0)) |>
  summarise(dx = sum(dx), .by = c(year, sex, group, age)) |>
  mutate(unk = sum(dx[is.na(age)]), tot = sum(dx[!is.na(age)]), .by = c(year, sex, group)) |>
  filter(!is.na(age)) |>
  mutate(dx = if_else(tot > 0, dx * (1 + unk / tot), dx)) |>
  select(year, sex, group, age, dx) |>
  arrange(year, sex, group, age)
write_rds(who_violent_age, "data_inter/who_violent_age_1953-1977.rds")

cat("\nWHO violent deaths by year and group (both sexes):\n")
print(who_violent_age |> summarise(dx = round(sum(dx)), .by = c(year, group)) |>
        pivot_wider(names_from = group, values_from = dx) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Colombian emigrant stock by sex and age, 1990-2024 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
f_od <- "data_input/migration/undesa_pd_2024_ims_stock_by_sex_destination_and_origin.xlsx"
f_age <- "data_input/migration/undesa_pd_2020_ims_stock_by_age_sex_and_destination.xlsx"
yrs_ims <- c(1990, 1995, 2000, 2005, 2010, 2015, 2020, 2024)
ages_ims <- c(seq(0, 70, 5), 75)

# stock of Colombian-born (origin 170) by destination country and sex
od <- read_excel(f_od, sheet = "Table 1", skip = 11, col_names = FALSE, .name_repair = "minimal")
names(od) <- c("idx", "dest", "cov", "type", "dest_code", "origin", "origin_code",
               paste0("b_", yrs_ims), paste0("m_", yrs_ims), paste0("f_", yrs_ims))
emig_dest <-
  od |>
  filter(origin_code == 170, dest_code < 900) |>
  select(dest_code, starts_with("m_"), starts_with("f_")) |>
  pivot_longer(-dest_code, names_to = c("sex", "year"), names_sep = "_", values_to = "stock",
               names_transform = list(year = as.integer)) |>
  mutate(stock = as.numeric(stock)) |>
  filter(!is.na(stock), stock > 0)

# age profile of all migrants by destination and sex, 1990-2020 (2024 takes
# 2020)
ag <- read_excel(f_age, sheet = "Table 1", skip = 10, col_names = FALSE, .name_repair = "minimal")
names(ag) <- c("idx", "year", "area", "notes", "code", "type",
               paste0("b_", ages_ims), "b_tot", paste0("m_", ages_ims), "m_tot", paste0("f_", ages_ims), "f_tot")
profile <-
  ag |>
  select(year, code, matches("^[mf]_\\d+$")) |>
  mutate(across(-c(year, code), as.numeric), year = as.integer(year), code = as.integer(code)) |>
  pivot_longer(-c(year, code), names_to = c("sex", "age"), names_sep = "_", values_to = "n",
               names_transform = list(age = as.integer)) |>
  filter(!is.na(n)) |>
  mutate(share = n / sum(n), .by = c(year, code, sex)) |>
  filter(is.finite(share)) |>
  select(year, code, sex, age, share)
profile <- bind_rows(profile, profile |> filter(year == 2020) |> mutate(year = 2024L))
world <- profile |> filter(code == 900) |> select(-code, share_w = share)

emigrant_stock <-
  emig_dest |>
  cross_join(tibble(age = ages_ims)) |>
  left_join(profile, by = c("dest_code" = "code", "year", "sex", "age")) |>
  left_join(world, by = c("year", "sex", "age")) |>
  mutate(has = any(!is.na(share)), .by = c(dest_code, year, sex)) |>
  mutate(share = if_else(has, replace_na(share, 0), share_w)) |>
  summarise(stock = sum(stock * share), .by = c(year, sex, age)) |>
  # 0-4 split 1:4 into 0 and 1-4; 75+ split 60:40 into 75-79 and 80+
  reframe(s = c(stock[age == 0] * c(0.2, 0.8), stock[age >= 5 & age < 75], stock[age == 75] * c(0.6, 0.4)),
          a = c(0, 1, age[age >= 5 & age < 75], 75, 80),
          .by = c(year, sex)) |>
  rename(age = a, stock = s) |>
  arrange(year, sex, age)

cat("\nColombian-born emigrant stock (UN DESA), by sex:\n")
print(emigrant_stock |> summarise(stock = round(sum(stock)), .by = c(year, sex)) |>
        pivot_wider(names_from = sex, values_from = stock) |> as.data.frame())
write_rds(emigrant_stock, "data_inter/emigrant_stock_age_1990-2024.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAMBdA registered deaths by age, 1926-2015 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Latin American Mortality Database (Palloni, Pinto-Aguirre, Beltran-Sanchez),
# files lambda_Col_Deaths{m,f}.txt: registered deaths as published in the UN
# Demographic Yearbooks and WHO (verified: identical to the WHO and DANE
# counts where they overlap), ages 0, 1, 5, ..., 85 (coarser groups 40-49,
# 50-59, 60-69, 70+ before 1947), 999 = unknown age. Used in 22 for the
# years without WHO or DANE age detail (1938-1952, 1971, 1973). Known flaws:
# 1970 is 48% above the registered total (not used), 2012 is 11% below.
lambda_deaths_age <-
  map_dfr(c(m = "m", f = "f"), \(s) read_tsv(paste0("data_input/historical/lambda_Col_Deaths", s, ".txt"),
                                               show_col_types = FALSE), .id = "sex") |>
  rename(year = Year, age = Age, dx = Deaths) |>
  mutate(unk = sum(dx[age == 999]), .by = c(year, sex)) |>
  filter(age != 999) |>
  mutate(dx = dx * (1 + unk / sum(dx)), .by = c(year, sex)) |>
  select(year, sex, age, dx) |>
  arrange(year, sex, age)
write_rds(lambda_deaths_age, "data_inter/lambda_deaths_age_1926-2015.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# conflict homicides and enforced disappearances, MSE 1985-2018 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# JEP-CEV-HRDAG multiple-systems estimates (version 2), national draws by
# year, sex and 5-year age group (1,000 draws x 10 replicates), as prepared
# for Acosta et al., "Weaponizing kinship" (PDR 2025), repository
# colombia_bereavement_pdr (data_inter/mse_draws/region-year-age-sex). The
# 660 parquet files are read once and summarised here (mean, 2.5% and 97.5%
# quantiles over the 10,000 draws); the summary is cached in
# data_input/conflict/. Disappearances are only estimated up to 2016.
#
# victims without a recorded age were not removed in the source pipeline:
# they sit in 0-4 and in one of the top groups (85-89, 90-94 or 95+,
# depending on the year), about 30,000 male homicides at 0-4 and 40,000 at
# 85+ over 1985-2018; 23 and 27 treat those groups as unknown age and
# redistribute them over 5-84.
f_mse <- "data_input/conflict/mse_national_age5_1985-2018.rds"
if (!file.exists(f_mse)) {
  library(arrow)
  pq <- list.files("I:/My Drive/gits_drive/colombia_bereavement_pdr/data_inter/mse_draws/region-year-age-sex",
                   pattern = "parquet$", recursive = TRUE, full.names = TRUE)
  mse <-
    open_dataset(pq, format = "parquet") |>
    filter(region == "National") |>
    summarise(N = sum(N), .by = c(violation, year, sex, age5y, replica, sample_num)) |>
    collect() |>
    summarise(mean = mean(N), q025 = quantile(N, 0.025), q975 = quantile(N, 0.975), .by = c(violation, year, sex, age5y)) |>
    mutate(violation = recode(violation, DESAPARICION = "dsp", HOMICIDIO = "hom"),
           sex = recode(sex, HOMBRE = "m", MUJER = "f"),
           age = as.integer(str_extract(age5y, "^\\d+"))) |>
    select(violation, year, sex, age, mean, q025, q975) |>
    arrange(violation, year, sex, age)
  dir.create("data_input/conflict", showWarnings = FALSE)
  write_rds(mse, f_mse)
}
mse <- read_rds(f_mse)
cat("\nMSE conflict victims (mean), by violation:\n")
print(mse |> summarise(n = round(sum(mean)), .by = violation))
write_rds(mse, "data_inter/conflict_mse_age5_1985-2018.rds")
