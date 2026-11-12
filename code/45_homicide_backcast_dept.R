# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 45. Departmental homicides from the sex ratio of all-cause deaths,
#     1915-2019: prototype state-space model
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# PROTOTYPE. Question: how much can the sex ratio of registered deaths say
# about departmental homicides before 1979, alone and next to the other
# sources (anuarios 1923-1965, Policia 1962-2002)?
#
# units    15 stable units, so that departments created after 1950 do not
#          break the series: Bolivar + Cordoba + Sucre, Caldas + Quindio +
#          Risaralda, Cundinamarca + Bogota, Magdalena + Cesar, and
#          "territorios" (intendencias and comisarias plus Choco, Meta,
#          Caqueta and La Guajira, which are inside that row of the anuarios
#          before they became departments).
#
# model    per unit, three latent states by year:
#            eta   log share of homicides in registered deaths (random walk)
#            u     log non-violent sex ratio of deaths, as a deviation from
#                  the national one (random walk, slow)
#            beta  log bias of the Policia count against the vital-statistics
#                  concept (slow random walk: the bias against EEVV differs
#                  by department between 1979-84 and 1985-97)
#          and four observations, any of which can be missing:
#            log(Dm / Df)       = g(rho_t + u, eta) + e   accounting identity:
#                                 non-violent deaths with sex ratio
#                                 exp(rho_t + u) plus homicides, 90 % male
#            log(H_anuario / D) = eta + e                 (e with gross errors)
#            log(H_eevv / D)    = eta + e                 (1979-2019, near exact)
#            log(H_policia / D) = eta + beta + e          (1962-1997)
#          plus one national observation that links the units:
#            log(V_who / D_nat) = log(sum_d w_d exp(eta_d)) + e   (1966-1977)
#          the WHO series is the national vital statistics by cause. in
#          1953-65 it is the sum of the anuario counts already in the model,
#          so it is used only in 1966-1977 (nine years with cause detail),
#          where the Policia is the only departmental source and has a break
#          in 1969 that the WHO series does not show.
#          rho_t is the national non-violent log sex ratio, computed from the
#          panel and the national share of violent deaths (anuarios, WHO
#          1953-77, EEVV). Joint extended Kalman filter and RTS smoother, written
#          here in base R; nine standard deviations and two probabilities by
#          maximum likelihood (the sds of eta, of u and of the sex-ratio
#          error differ before and from 1979: the sex ratio is much noisier
#          as a signal in the anuario years).
#          an anuario cell is read as one of three cases: a regular
#          observation, a gross error (e.g. Valle del Cauca 1959, 52
#          homicides between 1,479 and 855) or a jump of the level since the
#          year before (the start of La Violencia). without this, a few bad
#          cells inflate the error of all the others and the peaks are
#          flattened. a transitory white-noise part of eta was tried instead
#          and its variance was estimated at zero.
#
# validation  blocks of years in which the homicide counts are hidden and
#          predicted back: 1946-65 whole, 1946-53 and 1954-65 (anuarios as
#          truth), 1979-84, 1985-97
#          and 1998-2010 (EEVV as truth). Inside the block the model gets
#          nothing (N), the sex ratio (S), the Policia (P) or both (SP).
#          (a variant without the national offset rho_t was dropped: it
#          predicted the same and fitted worse, log-likelihood about 90 lower.)
#          Parameters are the full-data estimates (not re-estimated per block).
#          anuario cells flagged as gross errors in the full fit are left
#          out of the scores.
#
# caveats  - the target is homicides among REGISTERED deaths; deaths that
#            were never registered are outside the model
#          - 1979-2019 "homicide" is dx_v (homicide + undetermined intent +
#            legal intervention), the convention of the municipal model
#          - population is the enumerated census interpolated log-linearly
#            (1928 dropped) up to the DANE projection of 1985, so rates carry
#            the census omission
#          - the EKF linearises the sex-ratio equation on the log scale;
#            where homicides are below ~2 % of deaths the sex ratio only
#            gives an upper bound and the interval is approximate
#          - EEVV 1979-1984 by department comes from data_inter (02); the
#            versioned shared file starts in 1985. 1979 is a short year
#
# inputs   data_input/historical/col_gap_analysis_*  (deaths, homicides, pop)
#          data_input/historical/Homicidio 1962-2002 por depto de Policia_v1.xlsx
#          data_input/reference/who_violent_age_colombia_1953-1977.csv
#          output/deaths_pop_munic_1985_2023.csv.gz
#          data_inter/deaths_munic_1979-2023.rds  (1979-1984; optional)
# outputs  output/tables/homicide_backcast_dept_1915-2019.csv
#          output/tables/homicide_backcast_parameters.csv
#          output/tables/homicide_backcast_validation.csv
#          output/tables/homicide_backcast_police_bias.csv
#          output/tables/homicide_backcast_gap_information.csv
#          output/tables/homicide_backcast_national.csv
#          figures/07_backcast/*.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls())
gc()
source("code/00_setup.R")

dir.create("figures/07_backcast", showWarnings = FALSE, recursive = TRUE)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

h_dir <- "data_input/historical/"
yrs <- 1915:2019
pi_m <- 0.90 # male share of homicides (0.87-0.92 in anuarios and EEVV)
s_e <- 0.03 # sd of the EEVV observation of eta (near exact by construction)
pol_years <- 1962:1997 # the Policia series is used up to the 1998 certificate
who_years <- 1966:1977 # WHO national violent deaths as a constraint (see header)
s_w <- 0.05 # sd of the WHO national observation (log share), fixed
s_out <- 1.5 # extra sd of an anuario cell that is a gross error (log scale), fixed
s_jump <- 1 # extra sd of eta in a year with a jump (log scale), fixed
eta_break <- 1979 # first year of the modern innovation sd of eta (EEVV microdata)
z90 <- qnorm(0.95)

norm_name <- function(x) {
  x |> stringi::stri_trans_general("Latin-ASCII") |> tolower() |> trimws() |>
    gsub(pattern = "[ _]+", replacement = "_")
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. units ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
terr <- c("intendencias_y_comisarias", "intendencias", "comisarias", "choco", "meta", "caqueta",
          "la_guajira", "guajira", "amazonas", "arauca", "casanare", "guainia", "guaviare",
          "putumayo", "san_andres_y_providencia", "san_andres", "vaupes", "vichada")
unit_map <- c(
  antioquia = "antioquia", uraba = "antioquia", metropolitana_medellin = "antioquia",
  atlantico = "atlantico",
  bolivar = "bolivar", cordoba = "bolivar", sucre = "bolivar",
  boyaca = "boyaca",
  caldas = "caldas", quindio = "caldas", risaralda = "caldas",
  cauca = "cauca",
  cundinamarca = "cundinamarca", bogota = "cundinamarca", "bogota_d.e." = "cundinamarca",
  metropolitana_bogota = "cundinamarca",
  huila = "huila",
  magdalena = "magdalena", cesar = "magdalena",
  narino = "narino", norte_de_santander = "norte_de_santander",
  santander = "santander", magdalena_medio = "santander",
  tolima = "tolima",
  valle_del_cauca = "valle_del_cauca", valle = "valle_del_cauca", metropolitana_cali = "valle_del_cauca",
  setNames(rep("territorios", length(terr)), terr)
)
unit_lab <- c(
  antioquia = "Antioquia", atlantico = "Atlántico", bolivar = "Bolívar + Córdoba + Sucre",
  boyaca = "Boyacá", caldas = "Caldas + Quindío + Risaralda", cauca = "Cauca",
  cundinamarca = "Cundinamarca + Bogotá", huila = "Huila", magdalena = "Magdalena + Cesar",
  narino = "Nariño", norte_de_santander = "Norte de Santander", santander = "Santander",
  tolima = "Tolima", valle_del_cauca = "Valle del Cauca", territorios = "Territorios"
)
cod_unit <- c(
  "05" = "antioquia", "08" = "atlantico", "13" = "bolivar", "23" = "bolivar", "70" = "bolivar",
  "15" = "boyaca", "17" = "caldas", "63" = "caldas", "66" = "caldas", "19" = "cauca",
  "11" = "cundinamarca", "25" = "cundinamarca", "41" = "huila", "47" = "magdalena", "20" = "magdalena",
  "52" = "narino", "54" = "norte_de_santander", "68" = "santander", "73" = "tolima", "76" = "valle_del_cauca"
) # every other code is "territorios"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. data ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# deaths 1915-1984, anuarios. Bogota has its own row from 1956 but stays
# inside Cundinamarca until 1961, so its row is dropped up to that year.
dth_c <- read_delim(paste0(h_dir, "col_gap_analysis_1920_1985_department_deaths_clean_v06_territories_aggregated.csv"),
                    delim = ";", show_col_types = FALSE) |>
  transmute(dep = norm_name(department), year, d = total, dm = male, df = female) |>
  filter(!is.na(d), d > 0, !(dep == "bogota" & year <= 1961)) |>
  mutate(unit = unname(unit_map[dep]))
stopifnot(!anyNA(dth_c$unit))

# homicides 1923-1965, anuarios (1943-45 are "violent and accidental deaths").
# a unit-year is kept only if every component with deaths that year reports.
hom_c <- read_csv(paste0(h_dir, "col_gap_analysis_1920_1985_department_homicides_clean_v02.csv"), show_col_types = FALSE) |>
  transmute(dep = norm_name(department), year, hh = total) |>
  filter(!is.na(hh), !(year %in% 1943:1945)) |>
  mutate(dep = case_when(dep == "cundinamarca_sin_bogota" ~ "cundinamarca",
                         dep == "bogota" & year <= 1961 ~ "cundinamarca",
                         TRUE ~ dep)) |>
  summarise(hh = sum(hh), .by = c(dep, year))

anu <- dth_c |>
  left_join(hom_c, by = c("dep", "year")) |>
  summarise(
    d = sum(d),
    dm = if (anyNA(dm) || anyNA(df)) NA_real_ else sum(dm),
    df = if (anyNA(df) || anyNA(dm)) NA_real_ else sum(df),
    h_anu = if (anyNA(hh)) NA_real_ else sum(hh),
    .by = c(unit, year)
  ) |>
  mutate(dm = ifelse(is.na(df), NA, dm), src_d = "anuario")

# EEVV 1985-2019 (pandemic years left out: they move the sex ratio)
sh <- read_csv("output/deaths_pop_munic_1985_2023.csv.gz", show_col_types = FALSE) |>
  filter(year <= max(yrs)) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)),
         unit = coalesce(unname(cod_unit[cod_dpto]), "territorios"),
         dx_v = dx_homicide + dx_undetermined + dx_legal)
eevv <- sh |>
  summarise(d = sum(dx_all), dm = sum(dx_all[sex == "m"]), df = sum(dx_all[sex == "f"]),
            h_eevv = sum(dx_v), pop = sum(pop, na.rm = TRUE), .by = c(unit, year)) |>
  mutate(src_d = "EEVV")

# EEVV 1979-1984 from the municipal file of 02 (data_inter, not versioned):
# deaths by sex and violent deaths replace the anuario rows of those years.
# without the file, 1979-84 stay on the anuario deaths and have no EEVV
# homicides (the Policia is then the only homicide source for those years).
f_7984 <- "data_inter/deaths_munic_1979-2023.rds"
has_7984 <- file.exists(f_7984)
if (has_7984) {
  e79 <- read_rds(f_7984) |>
    filter(year %in% 1979:1984) |>
    mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)))
  # code 83 is Caqueta as an intendencia (1979-81); like every code outside
  # cod_unit it goes to "territorios"
  say("EEVV 1979-84, codes outside the 33 departments:",
      paste(sort(unique(e79$cod_dpto[!e79$cod_dpto %in% unique(sh$cod_dpto)])), collapse = ", "))
  e79 <- e79 |>
    mutate(unit = coalesce(unname(cod_unit[cod_dpto]), "territorios")) |>
    summarise(d = sum(dx_tot), dm = sum(dx_tot[sex %in% "m"]), df = sum(dx_tot[sex %in% "f"]),
              h_eevv = sum(dx_v), .by = c(unit, year)) |>
    mutate(src_d = "EEVV")
  # the 1979 microdata lack whole departments (Caldas 1 death, Santander 3):
  # where EEVV has less than half the deaths of the anuario, the anuario row
  # is kept and the year has no EEVV homicides
  short <- e79 |>
    inner_join(anu |> select(unit, year, d_anu = d), by = c("unit", "year")) |>
    filter(d < 0.5 * d_anu)
  say("EEVV 1979-84 unit-years replaced by the anuario:",
      paste(with(short, paste0(unit, " ", year, " (", d, " vs ", d_anu, ")")), collapse = "; "))
  e79 <- e79 |> anti_join(short, by = c("unit", "year"))
  anu <- anu |> filter(year < 1979 | paste(unit, year) %in% paste(short$unit, short$year))
  eevv_d <- bind_rows(e79, eevv |> select(-pop))
} else {
  say("data_inter/deaths_munic_1979-2023.rds not found: 1979-84 without EEVV (run 01-02 first)")
  eevv_d <- eevv |> select(-pop)
}

# Policia 1962-2002
pol <- read_excel(paste0(h_dir, "Homicidio 1962-2002 por depto de Policía_v1.xlsx"), sheet = "Tabla_ancha") |>
  pivot_longer(-Jurisdiccion, names_to = "year", values_to = "n") |>
  mutate(year = as.integer(year), dep = norm_name(Jurisdiccion)) |>
  filter(dep != "total") |>
  mutate(unit = unname(unit_map[dep]))
stopifnot(!anyNA(pol$unit))
pol_nat <- pol |> summarise(h_pol = sum(n, na.rm = TRUE), .by = year)
pol <- pol |> summarise(h_pol = sum(n, na.rm = TRUE), .by = c(unit, year))

# population: censuses (1928 dropped: never approved, inflated in several
# departments) + DANE from 1985, log-linear in between
pop_c <- read_delim(paste0(h_dir, "col_gap_analysis_1920_1985_department_population_clean_v03.csv"),
                    delim = ";", show_col_types = FALSE) |>
  transmute(dep = norm_name(department), year, p = total) |>
  filter(!is.na(p), year != 1928) |>
  mutate(unit = unname(unit_map[dep])) |>
  summarise(p = sum(p), .by = c(unit, year))
stopifnot(!anyNA(pop_c$unit))
pop_u <- bind_rows(pop_c, eevv |> transmute(unit, year, p = pop)) |>
  group_by(unit) |>
  reframe(pop = exp(approx(year, log(p), yrs, rule = 2)$y), year = yrs)

# panel
pan <- expand_grid(unit = names(unit_lab), year = yrs) |>
  left_join(bind_rows(anu, eevv_d), by = c("unit", "year")) |>
  left_join(pol, by = c("unit", "year")) |>
  left_join(pop_u, by = c("unit", "year")) |>
  arrange(unit, year)

# years with partial reporting of deaths (e.g. Antioquia 1978, Caldas 1980):
# deaths below 80 % of the median of the four neighbouring years. the sex
# ratio and the anuario share are ratios within the year and are kept; the
# denominator of the Policia share and the final counts use the interpolated
# level d_adj.
near_med <- function(d, year) {
  vapply(seq_along(d), function(i) {
    w <- d[abs(year - year[i]) <= 2 & year != year[i]]
    if (sum(!is.na(w)) < 2) NA_real_ else median(w, na.rm = TRUE)
  }, numeric(1))
}
pan <- pan |>
  group_by(unit) |>
  mutate(partial = year <= 1984 & !is.na(d) & !is.na(near_med(d, year)) & d < 0.8 * near_med(d, year),
         d_adj = exp(approx(year[!is.na(d) & !partial], log(d[!is.na(d) & !partial]), year, rule = 2)$y),
         d_adj = ifelse(is.na(d) | partial, d_adj, d)) |>
  ungroup()
say("partial years:", paste(with(filter(pan, partial), paste(unit, year)), collapse = "; "))

# national share of violent deaths and national non-violent sex ratio ------
who_v <- read_csv("data_input/reference/who_violent_age_colombia_1953-1977.csv", show_col_types = FALSE) |>
  summarise(v_who = sum(Deaths1), .by = Year) |> rename(year = Year)
nat <- pan |>
  summarise(d = sum(d, na.rm = TRUE),
            dm = sum(dm[!is.na(dm)]), df = sum(df[!is.na(dm)]),
            d_anu_cov = sum(d[!is.na(h_anu)], na.rm = TRUE), h_anu = sum(h_anu, na.rm = TRUE), n_anu = sum(!is.na(h_anu)),
            h_eevv = sum(h_eevv, na.rm = TRUE), d_adj = sum(d_adj), pop = sum(pop), .by = year) |>
  left_join(who_v, by = "year") |>
  left_join(pol_nat, by = "year") |>
  mutate(
    v_share = case_when(h_eevv > 0 ~ h_eevv / d,
                        !is.na(v_who) ~ v_who / d,
                        n_anu >= 8 ~ h_anu / d_anu_cov,
                        TRUE ~ NA_real_),
    v_share = approx(year[!is.na(v_share)], v_share[!is.na(v_share)], year, rule = 2)$y,
    male_share = ifelse(dm > 0, dm / (dm + df), NA),
    m0 = (male_share - v_share * pi_m) / (1 - v_share),
    rho = log(m0 / (1 - m0)),
    rho = approx(year[!is.na(rho)], rho[!is.na(rho)], year, rule = 2)$y
  )

# model data: one row per unit-year, observations and their sampling variance
md <- pan |>
  left_join(nat |> select(year, rho), by = "year") |>
  mutate(
    y_sr = ifelse(!is.na(dm) & dm > 0 & df > 0, log(dm / df), NA),
    q_sr = 1 / dm + 1 / df,
    y_a = ifelse(!is.na(h_anu) & h_anu > 0, log(h_anu / d), NA),
    q_a = 1 / h_anu,
    y_e = ifelse(!is.na(h_eevv) & h_eevv > 0, log(h_eevv / d), NA),
    q_e = 1 / h_eevv,
    y_p = ifelse(year %in% pol_years & !is.na(h_pol) & h_pol > 0, log(h_pol / d_adj), NA),
    q_p = 1 / h_pol
  ) |>
  # national WHO observation (the same value in every row of the year) and
  # the weight of each unit in the national deaths
  left_join(nat |> transmute(year, y_w = ifelse(year %in% who_years & !is.na(v_who), log(v_who / d_adj), NA)), by = "year") |>
  mutate(w = d_adj / sum(d_adj), .by = year) |>
  arrange(unit, year)
stopifnot(nrow(md) == length(yrs) * n_distinct(md$unit), all(md$year == rep(yrs, n_distinct(md$unit))))
say("unit-years with: sex ratio", sum(!is.na(md$y_sr)), "| anuario homicides", sum(!is.na(md$y_a)),
    "| Policia", sum(!is.na(md$y_p)), "| EEVV", sum(!is.na(md$y_e)), "| years with WHO:", n_distinct(md$year[!is.na(md$y_w)]))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. model ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# log sex ratio of all deaths given the non-violent log sex ratio (delta) and
# the log share of homicides in deaths (eta)
g_sr <- function(delta, eta) {
  h <- pmin(exp(eta), 0.9)
  ed <- exp(delta)
  log((1 - h) * ed + h * pi_m * (1 + ed)) - log((1 - h) + h * (1 - pi_m) * (1 + ed))
}

x0 <- c(log(0.01), 0, 0)
P0 <- c(2, 0.3, 0.5)^2 # prior variances of eta, u, beta in the first year

# model data as year x unit matrices (dat is sorted by unit, then year)
prep <- function(dat) {
  n <- length(yrs)
  mat <- function(v) matrix(v, nrow = n)
  list(n = n, K = n_distinct(dat$unit), year = yrs, rho = dat$rho[seq_len(n)], y_w = dat$y_w[seq_len(n)],
       W = mat(dat$w), y_a = mat(dat$y_a), q_a = mat(dat$q_a), y_e = mat(dat$y_e), q_e = mat(dat$q_e),
       y_p = mat(dat$y_p), q_p = mat(dat$q_p), y_sr = mat(dat$y_sr), q_sr = mat(dat$q_sr))
}

# extended Kalman filter for all units jointly (state: eta, u, beta of each
# unit). observations are processed one at a time; the units are linked only
# by the national WHO observation.
# the anuario observation is a mixture of three cases:
#   regular      error with sd s_a
#   gross error  the cell is wrong: error with sd sqrt(s_a^2 + s_out^2)
#   jump         the cell is right and eta moved by more than a random-walk
#                step since last year: eta gets an extra sd s_jump first
#                (jumps are allowed only before eta_break; in a year without
#                an anuario cell their variance, p_jump s_jump^2, is added to
#                the random-walk step)
# the three updates are collapsed to one Gaussian by moment matching, so an
# ambiguous cell leaves a wide variance and the next years decide.
# returns the log-likelihood and, if asked, the smoothed states and the
# probabilities of gross error and jump of each anuario cell (as seen by the
# filter when the cell arrives).
# par: see par_names. the sds of eta, u and of the sex-ratio error differ
# before and from `eta_break`.
kf_joint <- function(m, par, smooth = FALSE) {
  n <- m$n
  K <- m$K
  ns <- 3 * K
  ie <- seq(1, ns, 3)
  iu <- ie + 1
  ib <- ie + 2
  hist <- m$year < eta_break
  x <- rep(x0, K)
  P <- diag(rep(P0, K))
  s_eta2 <- ifelse(hist, par[1], par[2])^2
  s_u2 <- ifelse(hist, par[3], par[4])^2
  y_a <- m$y_a; y_e <- m$y_e; y_p <- m$y_p; y_sr <- m$y_sr; y_w <- m$y_w; W <- m$W; rho <- m$rho
  V_s <- ifelse(hist, par[5], par[6])^2 + m$q_sr # the vector recycles down the years
  V_a <- par[7]^2 + m$q_a
  V_e <- s_e^2 + m$q_e
  V_p <- par[8]^2 + m$q_p
  p_out <- par[10]
  p_jump <- par[11]
  mix <- p_out + p_jump > 0
  lp_mix <- log(c(1 - p_out - p_jump, p_out, p_jump))
  ll <- 0
  e <- 1e-4
  upd <- function(idx, Hs, v, R) {
    PH <- if (length(idx) == 1) P[, idx] * Hs else drop(P[, idx, drop = FALSE] %*% Hs)
    S <- sum(Hs * PH[idx]) + R
    x <<- x + PH * (v / S)
    P <<- P - tcrossprod(PH) / S
    ll <<- ll - 0.5 * (log(2 * pi * S) + v^2 / S)
  }
  # anuario observation of eta_i: regular, gross error or jump
  upd_mix <- function(i, v, R) {
    PH <- P[, i]
    PH3 <- PH
    PH3[i] <- PH3[i] + s_jump^2
    S <- c(PH[i] + R, PH[i] + R + s_out^2, PH3[i] + R)
    l <- lp_mix + dnorm(v, 0, sqrt(S), log = TRUE)
    lmax <- max(l)
    lsum <- lmax + log(sum(exp(l - lmax)))
    w <- exp(l - lsum)
    d1 <- PH * (v / S[1])
    d2 <- PH * (v / S[2])
    d3 <- PH3 * (v / S[3])
    dm <- w[1] * d1 + w[2] * d2 + w[3] * d3
    Pn <- P - tcrossprod(PH) * (w[1] / S[1] + w[2] / S[2]) - tcrossprod(PH3) * (w[3] / S[3]) +
      w[1] * tcrossprod(d1 - dm) + w[2] * tcrossprod(d2 - dm) + w[3] * tcrossprod(d3 - dm)
    Pn[i, i] <- Pn[i, i] + w[3] * s_jump^2
    P <<- Pn
    x <<- x + dm
    ll <<- ll + lsum
    w
  }
  if (smooth) {
    xp <- xf <- matrix(NA_real_, n, ns)
    Pp <- Pf <- array(NA_real_, c(ns, ns, n))
    pout <- pjmp <- matrix(NA_real_, n, K)
  }
  for (t in seq_len(n)) {
    if (t > 1) {
      d <- diag(P)
      d[ie] <- d[ie] + s_eta2[t]
      d[iu] <- d[iu] + s_u2[t]
      d[ib] <- d[ib] + par[9]^2
      # before eta_break a jump can happen in any year: where the anuario
      # cell is missing its variance goes into the step (with a cell, the
      # mixture below deals with it)
      if (mix && hist[t]) {
        noa <- is.na(y_a[t, ])
        d[ie[noa]] <- d[ie[noa]] + p_jump * s_jump^2
      }
      diag(P) <- d
    }
    if (smooth) { xp[t, ] <- x; Pp[, , t] <- P }
    for (k in seq_len(K)) {
      i <- ie[k]
      # the sources without gross errors go first, so that the anuario cell
      # is judged against everything else known about the year
      if (!is.na(y_e[t, k])) upd(i, 1, y_e[t, k] - x[i], V_e[t, k])
      if (!is.na(y_p[t, k])) upd(c(i, i + 2L), c(1, 1), y_p[t, k] - x[i] - x[i + 2L], V_p[t, k])
      if (!is.na(y_sr[t, k])) {
        dl <- rho[t] + x[i + 1L]
        Hs <- c((g_sr(dl, x[i] + e) - g_sr(dl, x[i] - e)) / (2 * e),
                (g_sr(dl + e, x[i]) - g_sr(dl - e, x[i])) / (2 * e))
        upd(c(i, i + 1L), Hs, y_sr[t, k] - g_sr(dl, x[i]), V_s[t, k])
      }
      if (!is.na(y_a[t, k])) {
        if (mix) {
          w <- upd_mix(i, y_a[t, k] - x[i], V_a[t, k])
          if (smooth) { pout[t, k] <- w[2]; pjmp[t, k] <- w[3] }
        } else {
          upd(i, 1, y_a[t, k] - x[i], V_a[t, k])
        }
      }
    }
    if (!is.na(y_w[t])) {
      # national share of violent deaths = sum of unit shares weighted by deaths
      hw <- W[t, ] * pmin(exp(x[ie]), 0.9)
      upd(ie, hw / sum(hw), y_w[t] - log(sum(hw)), s_w^2)
    }
    if (smooth) { xf[t, ] <- x; Pf[, , t] <- P }
  }
  if (!smooth) return(ll)
  xs <- xf
  Ps <- Pf
  for (t in (n - 1):1) {
    C <- Pf[, , t] %*% solve(Pp[, , t + 1] + diag(1e-12, ns))
    xs[t, ] <- xf[t, ] + drop(C %*% (xs[t + 1, ] - xp[t + 1, ]))
    Ps[, , t] <- Pf[, , t] + C %*% (Ps[, , t + 1] - Pp[, , t + 1]) %*% t(C)
  }
  sds <- sqrt(pmax(apply(Ps, 3, diag), 0)) # ns x n
  list(ll = ll, eta = xs[, ie], u = xs[, iu], beta = xs[, ib],
       sd_eta = t(sds[ie, ]), sd_u = t(sds[iu, ]), sd_beta = t(sds[ib, ]), p_out = pout, p_jump = pjmp)
}

# run the model on a long table (sorted by unit, then year)
run_model <- function(dat, par, smooth = FALSE) {
  o <- kf_joint(prep(dat), par, smooth = smooth)
  if (!smooth) return(o)
  tibble(unit = dat$unit, year = dat$year, eta = c(o$eta), sd_eta = c(o$sd_eta), u = c(o$u), sd_u = c(o$sd_u),
         beta = c(o$beta), sd_beta = c(o$sd_beta), p_outlier = c(o$p_out), p_jump = c(o$p_jump))
}

par_names <- c("s_eta_hist", "s_eta_mod", "s_u_hist", "s_u_mod", "s_0_hist", "s_0_mod", "s_a", "s_p", "s_b", "p_out", "p_jump")
# nine sds on the log scale and, with `mixture`, the two probabilities on
# the logit scale. the likelihood has more than one local maximum, so every
# starting point given is tried and the best is kept.
fit_par <- function(dat, mixture = TRUE, starts) {
  expand <- function(lp) if (mixture) c(exp(lp[1:9]), plogis(lp[10:11])) else c(exp(lp), 0, 0)
  best <- NULL
  for (s in starts) {
    lp0 <- if (mixture) c(log(s), qlogis(c(0.05, 0.03))) else log(s)
    o <- optim(lp0, function(lp) -run_model(dat, expand(lp)), method = "BFGS", control = list(maxit = 300, reltol = 1e-8))
    if (is.null(best) || o$value < best$value) best <- o
  }
  list(par = setNames(expand(best$par), par_names), ll = -best$value, conv = best$convergence, k = length(best$par))
}
aic_of <- function(f) 2 * f$k - 2 * f$ll

say("estimating: regular anuario errors only...")
fit_plain <- fit_par(md, mixture = FALSE, starts = list(c(0.18, 0.14, 0.013, 0.013, 0.02, 0.02, 0.26, 0.06, 0.11)))
say("  loglik", round(fit_plain$ll, 1), "| AIC", round(aic_of(fit_plain), 1))
say("... with gross errors and jumps")
fit1 <- fit_par(md, mixture = TRUE, starts = list(c(0.18, 0.14, 0.013, 0.013, 0.02, 0.02, 0.15, 0.06, 0.11),
                                                  c(0.24, 0.14, 0.02, 0.009, 0.04, 0.009, 0.09, 0.05, 0.11)))
say("  loglik", round(fit1$ll, 1), "| AIC", round(aic_of(fit1), 1))
print(round(rbind(plain = fit_plain$par, mixture = fit1$par), 4))

pars <- bind_rows(
  tibble(model = "gross errors and jumps", term = names(fit1$par), estimate = fit1$par, loglik = fit1$ll,
         aic = aic_of(fit1), convergence = fit1$conv, used = TRUE),
  tibble(model = "regular errors only", term = names(fit_plain$par), estimate = fit_plain$par, loglik = fit_plain$ll,
         aic = aic_of(fit_plain), convergence = fit_plain$conv, used = FALSE)
)
write_csv(pars, "output/tables/homicide_backcast_parameters.csv")

# anuario cells read as gross errors or as jumps with every source in the model
flag <- run_model(md, fit1$par, smooth = TRUE) |> transmute(unit, year, p_outlier, p_jump)
say("anuario cells:", sum(!is.na(flag$p_outlier)), "| probability of gross error over 0.5:", sum(flag$p_outlier > 0.5, na.rm = TRUE),
    "| of jump over 0.5:", sum(flag$p_jump > 0.5, na.rm = TRUE))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 4. validation: hidden blocks ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
blocks <- list("1946-1965" = 1946:1965, "1946-1953" = 1946:1953, "1954-1965" = 1954:1965, "1979-1984" = 1979:1984, "1985-1997" = 1985:1997, "1998-2010" = 1998:2010)
variants <- tribble(
  ~variant, ~use_sr, ~use_pol, ~offset,
  "N: nothing in the block", FALSE, FALSE, TRUE,
  "S: sex ratio", TRUE, FALSE, TRUE,
  "P: Policia", FALSE, TRUE, TRUE,
  "SP: sex ratio + Policia", TRUE, TRUE, TRUE
)

val <- list()
for (b in names(blocks)) {
  for (i in seq_len(nrow(variants))) {
    vv <- variants[i, ]
    inb <- md$year %in% blocks[[b]]
    has_pol <- any(!is.na(md$y_p[inb]))
    if (vv$use_pol && !has_pol) next
    dat <- if (vv$offset) md else md0
    truth <- ifelse(is.na(dat$y_e), dat$y_a, dat$y_e)
    q_truth <- ifelse(is.na(dat$y_e), dat$q_a, dat$q_e)
    dat$y_a[inb] <- NA
    dat$y_e[inb] <- NA
    if (!vv$use_sr) dat$y_sr[inb] <- NA
    if (!vv$use_pol) dat$y_p[inb] <- NA
    p <- if (vv$offset) fit1$par else fit0$par
    sm <- run_model(dat, p, smooth = TRUE)
    val[[length(val) + 1]] <- sm |>
      mutate(block = b, variant = vv$variant, truth = truth, q_truth = q_truth,
             s_obs = ifelse(max(blocks[[b]]) <= 1965, p[["s_a"]], s_e),
             d = dat$d, in_block = inb) |>
      select(-p_outlier, -p_jump) |>
      left_join(flag |> transmute(unit, year, p_flag = p_outlier), by = c("unit", "year")) |>
      filter(in_block, !is.na(truth), is.na(p_flag) | p_flag <= 0.5)
  }
}
val <- bind_rows(val) |>
  group_by(block, unit) |>
  mutate(h_obs_mean = mean(exp(truth[variant == variant[1]]))) |>
  ungroup() |>
  mutate(level = ifelse(h_obs_mean >= 0.03, "homicides >= 3 % of deaths", "homicides < 3 % of deaths"),
         covered = abs(truth - eta) <= z90 * sqrt(sd_eta^2 + s_obs^2 + q_truth))

val_stats <- function(z) {
  z |> mutate(tw = truth - mean(truth), ew = eta - mean(eta), .by = unit) |>
    summarise(n = n(), units = n_distinct(unit),
              r_log = cor(truth, eta), r_log_within = cor(tw, ew),
              rmse_log = sqrt(mean((eta - truth)^2)), bias_log = mean(eta - truth),
              coverage90 = mean(covered), mean_sd_eta = mean(sd_eta),
              ratio_pred_obs = sum(exp(eta) * d) / sum(exp(truth) * d))
}
val_tab <- bind_rows(
  val |> group_by(block, variant) |> group_modify(~ val_stats(.x)) |> mutate(level = "all units"),
  val |> group_by(block, variant, level) |> group_modify(~ val_stats(.x))
) |>
  ungroup() |>
  mutate(variant = factor(variant, variants$variant)) |>
  arrange(block, level, variant)
write_csv(val_tab, "output/tables/homicide_backcast_validation.csv")
cat("\n== validation: hidden blocks ==\n")
print(as.data.frame(val_tab |> mutate(across(where(is.numeric), ~ round(.x, 2)))), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 5. estimates with every source ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sm <- run_model(md, fit1$par, smooth = TRUE)
est <- md |>
  left_join(sm, by = c("unit", "year")) |>
  mutate(
    h_est = exp(eta), h_lo = exp(eta - z90 * sd_eta), h_hi = exp(eta + z90 * sd_eta),
    hom_est = h_est * d_adj, hom_lo = h_lo * d_adj, hom_hi = h_hi * d_adj,
    rate_est = 1e5 * hom_est / pop, rate_lo = 1e5 * hom_lo / pop, rate_hi = 1e5 * hom_hi / pop,
    sr_nonviolent = exp(rho + u),
    sources = paste0(ifelse(!is.na(y_sr), "S", ""), ifelse(!is.na(y_a), "A", ""),
                     ifelse(!is.na(y_p), "P", ""), ifelse(!is.na(y_e), "E", "")),
    sources = ifelse(sources == "", "none", sources)
  )

est |>
  transmute(unit, unit_label = unit_lab[unit], year, deaths_reg = d, deaths_adj = d_adj, partial_year = partial,
            pop, sex_ratio_deaths = exp(y_sr), sr_nonviolent, hom_anuario = h_anu,
            hom_policia = h_pol, hom_eevv = h_eevv, sources, share_est = h_est, share_lo90 = h_lo,
            share_hi90 = h_hi, hom_est, hom_lo90 = hom_lo, hom_hi90 = hom_hi, rate_est,
            rate_lo90 = rate_lo, rate_hi90 = rate_hi, sd_log_share = sd_eta,
            anuario_gross_error_prob = p_outlier, anuario_jump_prob = p_jump) |>
  write_csv("output/tables/homicide_backcast_dept_1915-2019.csv")

# Policia bias: model estimate and the raw overlaps it comes from
bias <- est |>
  summarise(beta_1964 = beta[year == 1964], beta_1972 = beta[year == 1972], sd_beta_1972 = sd_beta[year == 1972],
            beta_1982 = beta[year == 1982], beta_1992 = beta[year == 1992],
            log_ratio_anuario_1962_65 = mean(log(h_pol / h_anu)[year %in% 1962:1965], na.rm = TRUE),
            log_ratio_eevv_1979_84 = mean(log(h_pol / h_eevv)[year %in% 1979:1984 & h_eevv > 0], na.rm = TRUE),
            log_ratio_eevv_1985_97 = mean(log(h_pol / h_eevv)[year %in% 1985:1997], na.rm = TRUE),
            log_ratio_eevv_1998_02 = mean(log(h_pol / h_eevv)[year %in% 1998:2002], na.rm = TRUE), .by = unit)
write_csv(bias, "output/tables/homicide_backcast_police_bias.csv")
cat("\n== Policia against the vital-statistics concept (log ratios) ==\n")
print(as.data.frame(bias |> mutate(across(where(is.numeric), ~ round(.x, 2)))), row.names = FALSE)

# what each source contributes in the real gap, 1966-1978: sd of log share
gap <- md$year %in% 1966:1978
gap_run <- function(label, sr, pl, who) {
  dat <- md
  if (!sr) dat$y_sr[gap] <- NA
  if (!pl) dat$y_p[gap] <- NA
  if (!who) dat$y_w <- NA
  run_model(dat, fit1$par, smooth = TRUE) |> filter(year %in% 1966:1978) |>
    summarise(sd_log_share = mean(sd_eta), share = exp(mean(eta)), .by = unit) |> mutate(inputs = label)
}
gap_info <- bind_rows(gap_run("nothing", FALSE, FALSE, FALSE), gap_run("sex ratio", TRUE, FALSE, FALSE),
                      gap_run("Policia", FALSE, TRUE, FALSE), gap_run("sex ratio + Policia", TRUE, TRUE, FALSE),
                      gap_run("WHO", FALSE, FALSE, TRUE), gap_run("sex ratio + Policia + WHO", TRUE, TRUE, TRUE))
write_csv(gap_info, "output/tables/homicide_backcast_gap_information.csv")
cat("\n== 1966-1978: mean sd of log share by inputs used in the gap ==\n")
print(as.data.frame(gap_info |> select(-share) |> mutate(sd_log_share = round(sd_log_share, 2)) |>
                      pivot_wider(names_from = inputs, values_from = sd_log_share)), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 6. figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#1f1f1e"
col_src <- c("Anuarios" = "#2a78d6", "Policía" = "#eb6834", "EEVV" = "#1baf7a", "OMS (nacional)" = "#6250d6")
shp_src <- c("Anuarios" = 16, "Policía" = 17, "EEVV" = 15, "OMS (nacional)" = 18)
base <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
        legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey40", hjust = 0))

# 6.1 rates by unit
obs_long <- est |>
  transmute(unit, year, pop, Anuarios = h_anu, `Policía` = ifelse(year %in% pol_years, h_pol, NA), EEVV = h_eevv) |>
  pivot_longer(c(Anuarios, `Policía`, EEVV), names_to = "source", values_to = "n") |>
  filter(!is.na(n), n > 0) |>
  left_join(est |> transmute(unit, year, source = "Anuarios", flagged = !is.na(p_outlier) & p_outlier > 0.5), by = c("unit", "year", "source")) |>
  mutate(rate = 1e5 * n / pop, source = factor(source, names(col_src)), flagged = replace_na(flagged, FALSE))
fig1 <- est |>
  filter(year >= 1923) |>
  ggplot(aes(year)) +
  geom_ribbon(aes(ymin = pmax(rate_lo, 0.3), ymax = pmin(rate_hi, 2000)), fill = "grey75", alpha = 0.6) +
  geom_point(data = obs_long |> filter(year >= 1923, !flagged), aes(y = rate, colour = source, shape = source), size = 0.9, alpha = 0.85) +
  geom_point(data = obs_long |> filter(year >= 1923, flagged), aes(y = rate), colour = "grey35", shape = 4, size = 1.4, stroke = 0.5) +
  geom_line(aes(y = rate_est), colour = ink, linewidth = 0.45) +
  annotate("rect", xmin = 1965.5, xmax = 1978.5, ymin = 0.3, ymax = 2000, fill = NA, colour = "grey55", linewidth = 0.25, linetype = 3) +
  scale_y_log10(breaks = c(1, 3, 10, 30, 100, 300), labels = scales::label_number(accuracy = 1)) +
  scale_colour_manual(values = col_src, drop = TRUE) +
  scale_shape_manual(values = shp_src, drop = TRUE) +
  coord_cartesian(ylim = c(1, 400)) +
  facet_wrap(~ unit_lab[unit], ncol = 3) +
  labs(title = "Homicidios por 100.000 habitantes, estimación del modelo e insumos, 1923-2019",
       subtitle = "Línea: estimación; banda: intervalo de 90 %; entre las líneas punteadas, 1966-1978, solo hay Policía. Escala logarítmica.",
       x = NULL, y = NULL,
       caption = "Cruces grises: celdas de los anuarios que el modelo lee como error grosero.
Homicidios entre las defunciones registradas. 1979-2019: homicidio + intención no determinada + intervención legal. Población: censos interpolados.") +
  base
ggsave("figures/07_backcast/backcast_rate_by_unit.png", fig1, w = 11, h = 12.5, bg = "white", dpi = 160)

# 6.2 validation: observed against predicted share
vfig <- val |>
  filter(variant %in% c("N: nothing in the block", "S: sex ratio", "SP: sex ratio + Policia")) |>
  mutate(variant = factor(variant, c("N: nothing in the block", "S: sex ratio", "SP: sex ratio + Policia"),
                          c("Sin insumos en el bloque", "Razón de sexos", "Razón de sexos + Policía")))
fig2 <- ggplot(vfig, aes(100 * exp(truth), 100 * exp(eta))) +
  geom_abline(colour = "grey60", linewidth = 0.3) +
  geom_linerange(aes(ymin = 100 * exp(eta - z90 * sd_eta), ymax = 100 * exp(eta + z90 * sd_eta)), colour = "grey70", linewidth = 0.2) +
  geom_point(colour = "#2a78d6", size = 0.8, alpha = 0.8) +
  scale_x_log10(labels = scales::label_number(drop0trailing = TRUE)) +
  scale_y_log10(labels = scales::label_number(drop0trailing = TRUE)) +
  coord_cartesian(xlim = c(0.1, 40), ylim = c(0.1, 40)) +
  facet_grid(variant ~ block, labeller = label_wrap_gen(18)) +
  labs(title = "Validación: homicidios ocultados por bloques de años y predichos por el modelo",
       subtitle = "Cada punto es una unidad-año; barras: intervalo de 90 %. Homicidios como % de las defunciones registradas, escala logarítmica.",
       x = "Observado (anuarios hasta 1965, EEVV desde 1979)", y = "Predicho") +
  base
ggsave("figures/07_backcast/backcast_validation.png", fig2, w = 10, h = 8, bg = "white", dpi = 160)

# 6.3 national sum against the national sources
nat_est <- est |> summarise(hom_est = sum(hom_est), pop = sum(pop), .by = year) |>
  left_join(nat |> select(year, v_who, h_pol, h_eevv, h_anu, n_anu), by = "year")
nat_est |>
  transmute(year, pop, hom_est, hom_who = v_who, hom_policia = h_pol, hom_eevv = ifelse(h_eevv > 0, h_eevv, NA),
            hom_anuario = ifelse(n_anu > 0, h_anu, NA), units_anuario = n_anu) |>
  write_csv("output/tables/homicide_backcast_national.csv")
nat_obs <- nat_est |>
  transmute(year, pop, Anuarios = ifelse(n_anu == 15, h_anu, NA), `Policía` = h_pol, EEVV = ifelse(h_eevv > 0, h_eevv, NA),
            `OMS (nacional)` = v_who) |>
  pivot_longer(-c(year, pop), names_to = "source", values_to = "n") |>
  filter(!is.na(n)) |>
  mutate(rate = 1e5 * n / pop, source = factor(source, names(col_src)))
fig3 <- ggplot(nat_est |> filter(year >= 1923), aes(year)) +
  geom_point(data = nat_obs |> filter(year >= 1923), aes(y = rate, colour = source, shape = source), size = 1.6) +
  geom_line(aes(y = 1e5 * hom_est / pop), colour = ink, linewidth = 0.6) +
  scale_colour_manual(values = col_src) +
  scale_shape_manual(values = shp_src) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Suma de las 15 unidades frente a las fuentes nacionales",
       subtitle = "Homicidios registrados por 100.000 habitantes. Línea: suma de las estimaciones departamentales.
La OMS entra al modelo solo en 1966-1977; EEVV 1979 es un año incompleto.",
       x = NULL, y = NULL) +
  base
ggsave("figures/07_backcast/backcast_national.png", fig3, w = 9, h = 5, bg = "white", dpi = 160)

# 6.4 information in the real gap
gfig <- gap_info |>
  filter(inputs != "WHO") |>
  mutate(inputs = factor(inputs, c("nothing", "sex ratio", "Policia", "sex ratio + Policia", "sex ratio + Policia + WHO"),
                         c("Nada", "Razón de sexos", "Policía", "Razón de sexos + Policía", "Las tres (con OMS nacional)")),
         unit = fct_reorder(unit_lab[unit], share))
fig4 <- ggplot(gfig, aes(sd_log_share, unit, colour = inputs, shape = inputs)) +
  geom_point(size = 2.2) +
  scale_colour_manual(values = c("Nada" = "grey55", "Razón de sexos" = "#2a78d6", "Policía" = "#eb6834", "Razón de sexos + Policía" = "#1baf7a", "Las tres (con OMS nacional)" = ink)) +
  scale_shape_manual(values = c("Nada" = 4, "Razón de sexos" = 16, "Policía" = 17, "Razón de sexos + Policía" = 18, "Las tres (con OMS nacional)" = 15)) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Incertidumbre en 1966-1978 según el insumo usado en esos años",
       subtitle = "Desviación estándar del logaritmo de la proporción de homicidios (0,1 ≈ ±10 %).\nUnidades ordenadas por nivel de homicidio estimado.",
       x = NULL, y = NULL) +
  base
ggsave("figures/07_backcast/backcast_gap_information.png", fig4, w = 8.5, h = 5.5, bg = "white", dpi = 160)

say("done")
