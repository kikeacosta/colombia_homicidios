# 00_setup.R -----------------------------------------------------------------
# Shared setup sourced by every script: packages, the DANE age-group recode,
# the cause-of-death crosswalk (DANE list 105) and the municipal panel builder.
#
# Every script starts with:
#   rm(list = ls()); gc(); source("code/00_setup.R")
# and is run from the project root (paths are relative to it).

options(scipen = 9999)
try(dev.off(), silent = TRUE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# packages ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# install once:
#   install.packages(c("data.table", "tidyverse", "readxl", "mgcv", "glmmTMB",
#                      "sf", "ggpubr", "remotes"))
#   remotes::install_github("nebulae-co/colmaps")
#
# data.table is loaded before tidyverse on purpose, so dplyr's between(),
# first() and last() are the ones found on the search path.
pkgs <- c(
  "data.table", # 01: fread() on the microdata
  "tidyverse", # dplyr, tidyr, ggplot2, readr, stringr, purrr, tibble
  "readxl", # 03: DANE population projections (xlsx)
  "mgcv", # 06, 09: gam() baselines and smoothers
  "glmmTMB", # 07, experimental/model_spatial: zero-inflated NB mixed models
  "sf", # 08, experimental/model_spatial: maps
  "colmaps", # 08, experimental/model_spatial: `municipios` shapes (GitHub only)
  "ggpubr" # 04, 08: stat_cor(), stat_regline_equation()
)

missing_pkgs <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(
    "Missing packages: ",
    paste(missing_pkgs, collapse = ", "),
    "\nSee the install lines at the top of code/00_setup.R"
  )
}
invisible(lapply(pkgs, library, character.only = TRUE))
rm(pkgs, missing_pkgs)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# constants ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# analysis window: years for which both deaths (1979-2023) and the DANE
# municipal projections (1985-2017) are available
yrs_analysis <- 1985:2017

# open age interval of the DANE municipal projections ("85 y más")
age_open <- 85

# Caribbean departments (DIVIPOLA codes): Atlantico, Bolivar, Cesar, Cordoba,
# La Guajira, Magdalena, Sucre
cod_caribe <- c("08", "13", "20", "23", "44", "47", "70")

# figure folders, one per analysis (created if missing so ggsave never fails)
for (d in c("01_descriptives", "02_model", "03_cause_decomposition", "04_completeness",
            "05_underregistration_tests", "historical", "experimental")) {
  dir.create(file.path("figures", d), showWarnings = FALSE, recursive = TRUE)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# small helpers ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# min-max standardisation to [0, 1], used to overlay series with different units
minmax <- function(x) {
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

# five-digit DIVIPOLA municipality code from the two integer codes in the
# microdata (cod_dpto 1-99, cod_munic 1-999 within department)
make_cod_munic <- function(cod_dpto, cod_munic) {
  paste0(sprintf("%02d", as.integer(cod_dpto)), sprintf("%03d", as.integer(cod_munic)))
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# age groups ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# lower bound of the age group coded in DANE's GRU_ED1 / gru_ed1 variable.
# the coding changes twice over the series (see documents/metadata/):
#
#   1979-1997   01-05 = <1 yr | 06 = 1 | 07 = 2-4 | 08 = 5-9 | ... | 24 = 85+ | 25 = unknown
#   1998-2007   01-06 = <1 yr | 07 = 1 | 08 = 2-4 | 09 = 5-9 | ... | 25 = 85+ | 26 = unknown
#   2008-2023   01-06 = <1 yr | 07 = 1 | 08 = 2-4 | 09 = 5-9 | ... | 28 = 100+| 29 = unknown
#
# so the first group of the 5-year series is 8 before 1998 and 9 from 1998 on,
# and both map to age 5. verified against documents/metadata/1979-1991.pdf,
# which lists "08 = de 5 a 9 años 09 = de 10 a 14 años 10 = de 15 a 19 años".
recode_age_group <- function(gr_edad, year) {
  dplyr::case_when(
    year <= 1997 & gr_edad <= 5 ~ 0,
    year <= 1997 & gr_edad %in% 6:7 ~ 1,
    year <= 1997 & gr_edad %in% 8:24 ~ (gr_edad - 7) * 5,
    year >= 1998 & year <= 2007 & gr_edad <= 6 ~ 0,
    year >= 1998 & year <= 2007 & gr_edad %in% 7:8 ~ 1,
    year >= 1998 & year <= 2007 & gr_edad %in% 9:25 ~ (gr_edad - 8) * 5,
    year >= 2008 & gr_edad <= 6 ~ 0,
    year >= 2008 & gr_edad %in% 7:8 ~ 1,
    year >= 2008 & gr_edad %in% 9:28 ~ (gr_edad - 8) * 5,
    TRUE ~ NA_real_ # unknown age (25 / 26 / 29 depending on the period)
  )
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# causes of death: DANE list 105 (cau_homol / CAU_HOMOL) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# one definition for the whole project. see
# documents/Lista_105_Colombia_CIE9-y-CIE10.xls for the code list.
#
# code groups used directly:
codes_natural <- 1:88 # chapters I-XVII, excluding ill-defined
codes_ill_defined <- 89L # signs, symptoms and ill-defined conditions
codes_external <- 90:105 # chapter XX, external causes
codes_homicide <- 101L # assault (homicide)
codes_undetermined <- 102L # event of undetermined intent
codes_legal <- 103L # legal intervention and operations of war
# "violent deaths" as used for the dependent variable of the model (dx_v):
# homicide + undetermined intent + legal intervention
codes_violent <- c(codes_homicide, codes_undetermined, codes_legal)

# fine groups, attached to the microdata in 01
recode_cause_fine <- function(cod_col) {
  dplyr::case_when(
    cod_col %in% c(1:8, 10) ~ "infeccion",
    cod_col == 9 ~ "vih",
    cod_col %in% 11:38 ~ "cancer",
    cod_col %in% c(39:48, 63:89) ~ "otras",
    cod_col %in% 49:58 ~ "circulatoria",
    cod_col %in% 59:62 ~ "respiratoria",
    cod_col == 90 ~ "acc_transito",
    cod_col %in% c(91, 92) ~ "otr_acc_transp",
    cod_col == 93 ~ "caida",
    cod_col == 95 ~ "ahogamiento",
    cod_col == 99 ~ "envenenamiento",
    cod_col == 100 ~ "suicidio",
    cod_col == 101 ~ "homicidio",
    cod_col == 102 ~ "violnt_sin_det",
    cod_col == 103 ~ "legal",
    cod_col %in% c(94, 96:98, 104:105) ~ "resto_externa",
    TRUE ~ "x"
  )
}

# broad groups, used by 09 for the cause-specific decomposition of the sex
# ratio. NB: here "homicidio" = assault + legal intervention (101, 103), while
# undetermined intent (102) is kept apart so its sex ratio can be inspected.
# the model's dx_v is the union of all three (codes_violent).
recode_cause_broad <- function(cod_col) {
  dplyr::case_when(
    cod_col %in% 1:10 ~ "infeccion",
    cod_col %in% 11:38 ~ "cancer",
    cod_col %in% 39:43 ~ "metabolicas",
    cod_col %in% c(44:48, 71:77) ~ "otras",
    cod_col %in% 49:58 ~ "circulatoria",
    cod_col %in% 59:62 ~ "respiratoria",
    cod_col %in% 63:70 ~ "digestiva",
    cod_col %in% 78:88 ~ "peri_congenita",
    cod_col == 89 ~ "mal_definidas",
    cod_col %in% c(90:99, 104:105) ~ "accidente",
    cod_col == 100 ~ "suicidio",
    cod_col %in% c(101, 103) ~ "homicidio",
    cod_col == 102 ~ "violnt_sin_det",
    TRUE ~ "x"
  )
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# municipal panel ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# one row per year x municipality x sex over `years`, for the municipalities
# present in the DANE projection. used by 04, 05 and 06 (it used to be copied
# into each of them).
#
#   dts : output of 02, data_inter/deaths_munic_1979-2023.rds
#         (year, cod_dpto <int>, cod_munic <int>, sex, dx_tot, dx_h, dx_v, dx_e)
#   pop : output of 03, data_inter/pop_munic_1985-2017.rds
#         (cod_dpto <chr>, dpto, cod_munic <chr 5>, munic, year, sex, age, pop)
#
# notes
#   - population is restricted to sex %in% c("m", "f"). the projection also
#     carries a "t" (total) row; summing over all three doubles every total.
#     the previous copies of this code did exactly that for the department and
#     national denominators.
#   - deaths with unknown sex, or in codes absent from the projection (e.g.
#     99999), are dropped here. they are still in `dts` for anyone who needs
#     them.
#   - municipality-years with no registered deaths are filled with zeros.
build_munic_panel <- function(dts, pop, years = yrs_analysis) {
  pop_sx <-
    pop |>
    filter(sex %in% c("m", "f"), year %in% years) |>
    summarise(pop = sum(pop), .by = c(year, cod_dpto, dpto, cod_munic, munic, sex))

  munic_codes <-
    pop_sx |>
    distinct(cod_dpto, dpto, cod_munic, munic)

  dts |>
    filter(year %in% years, !is.na(sex)) |>
    mutate(cod_munic = make_cod_munic(cod_dpto, cod_munic)) |>
    select(year, cod_munic, sex, dx_tot, dx_h, dx_v, dx_e) |>
    semi_join(munic_codes, by = "cod_munic") |>
    complete(
      year = years,
      cod_munic = munic_codes$cod_munic,
      sex = c("m", "f"),
      fill = list(dx_tot = 0, dx_h = 0, dx_v = 0, dx_e = 0)
    ) |>
    left_join(munic_codes, by = "cod_munic") |>
    left_join(
      pop_sx |> select(year, cod_munic, sex, pop),
      by = c("year", "cod_munic", "sex")
    ) |>
    mutate(
      cdr = dx_tot / pop,
      cdr2 = (dx_tot + 5) / pop, # +5 deaths: shrinks sex ratios of tiny municipalities toward 1
      cdr_v = dx_v / pop
    ) |>
    select(
      year, cod_dpto, dpto, cod_munic, munic, sex,
      dx_tot, dx_h, dx_v, dx_e, pop, cdr, cdr2, cdr_v
    ) |>
    arrange(year, cod_munic, sex)
}

# department totals from the panel (both sexes): crude all-cause and violent
# death rates, used as covariates in the model
dept_rates_from_panel <- function(panel) {
  panel |>
    summarise(
      dx_tot = sum(dx_tot),
      dx_v = sum(dx_v),
      pop = sum(pop, na.rm = TRUE),
      .by = c(year, cod_dpto, dpto)
    ) |>
    mutate(cdr_dpto = dx_tot / pop, cdr_h_dpto = dx_v / pop) |>
    select(year, cod_dpto, dpto, cdr_dpto, cdr_h_dpto)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cause groups of the shared dataset (11_shared_dataset.R) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# mutually exclusive and exhaustive, so the groups sum to all-cause deaths.
# residual = natural causes (1-88), ill-defined (89) and any unmapped code.
cause_groups_shared <- function(cod_col) {
  dplyr::case_when(
    cod_col == 101 ~ "homicide",
    cod_col == 102 ~ "undetermined",
    cod_col == 103 ~ "legal",
    cod_col == 100 ~ "suicide",
    cod_col %in% c(90:99, 104:105) ~ "accident",
    TRUE ~ "residual"
  )
}
