# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 41. Municipal allocation of homicides in 1958-1960 from the sex ratio of
#     deaths: prototype
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# PROTOTYPE. There are no municipal homicide counts before 1979. This script
# splits the homicides of each unit of 40 among its municipalities in
# 1958-1960 (three years pooled) using deaths by sex, and measures on EEVV
# how much the sex ratio improves on a plain split.
#
# estimator  per municipality i of unit u, with A_m, A_f deaths by sex:
#              raw_i = (A_m - rho_i A_f) / (pi - rho_i (1 - pi))
#            the excess of male deaths over the non-violent sex ratio rho_i,
#            scaled by the male share of homicides pi. rho_i is the unit's
#            non-violent sex ratio (from the unit's homicides) times a
#            municipal deviation:
#              common  none
#              popcov  the sex ratio of the municipality's population
#                      relative to the unit's, with an estimated slope
#              did     the municipality's own sex ratio of deaths in an
#                      earlier period with little violence, shrunk by its
#                      reliability (1924-1936 for 1958-1960)
#            raw_i is noisy, so it is shrunk toward a plain split of the
#            unit's homicides (by deaths or by population) with weight
#              w_i = (cv prior_i)^2 / ((cv prior_i)^2 + var(raw_i))
#            truncated at zero and rescaled to the unit total. cv is the
#            assumed CV of the municipal homicide share within a unit. its
#            maximum-likelihood estimate is too large (it trusts raw_i too
#            much), so cv is calibrated on EEVV instead.
#
# validation EEVV 1985-2019, 3-year windows, departments as units, observed
#            municipal violent deaths as truth.
#            (a) every estimator and prior with the ML cv, at the modern
#                level of violence and thinned to 30 % of the violent deaths
#            (b) error as a function of cv under the conditions of 1958-60:
#                violent deaths thinned to 50, 30 and 15 % (7, 4 and 2 % of
#                deaths) and the non-violent sex ratio perturbed so that its
#                municipal heterogeneity matches the one measured in 1958-60.
#                the cv with the lowest error there is used for 1958-60.
#            `did` uses non-violent deaths of 1985-1991 as the earlier period
#            for 2011-13 and 2016-18 (a gap like 1924-36 to 1958-60) and of
#            2003-2009 (short gap).
#
# 1958-1960  deaths over one year of age (infant deaths by sex are in the
#            source and carry no homicide signal). unit totals: anuario
#            homicides 1958-1960, which every unit reports.
#
# caveats    - homicides among registered deaths, by place of registration:
#              towns with a hospital get deaths from their neighbours
#            - the 16 rows without DIVIPOLA code (municipalities annexed to
#              Bogota, suppressed municipalities) are left out
#            - cv and the size of the gain are transferred from EEVV; they
#              cannot be checked in 1958-60, where no municipal homicide
#              count exists
#
# inputs   data_input/historical/dane_vitales_1958_1960_municipal.csv
#          data_input/historical/col_gap_analysis_1920_1985_municipal_*_v03.csv
#          output/deaths_pop_munic_1985_2023.csv.gz
#          output/tables/homicide_backcast_dept_1915-2019.csv   (40)
# outputs  output/tables/homicide_munic_validation.csv
#          output/tables/homicide_munic_validation_cv_grid.csv
#          output/tables/homicide_munic_1958-1960.csv
#          output/tables/homicide_munic_1958-1960_parameters.csv
#          figures/06_backcast/munic_validation.png
#          figures/06_backcast/munic_1958_1960_map.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls())
gc()
source("code/00_setup.R")

dir.create("figures/06_backcast", showWarnings = FALSE, recursive = TRUE)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
h_dir <- "data_input/historical/"
pi_m <- 0.90
lgt <- function(m, f) log((m + 0.5) / (f + 0.5))

cod_unit <- c(
  "05" = "antioquia", "08" = "atlantico", "13" = "bolivar", "23" = "bolivar", "70" = "bolivar",
  "15" = "boyaca", "17" = "caldas", "63" = "caldas", "66" = "caldas", "19" = "cauca",
  "11" = "cundinamarca", "25" = "cundinamarca", "41" = "huila", "47" = "magdalena", "20" = "magdalena",
  "52" = "narino", "54" = "norte_de_santander", "68" = "santander", "73" = "tolima", "76" = "valle_del_cauca"
) # every other code is "territorios" (same units as 40)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. estimator ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# heterogeneity of a municipal log sex ratio around its unit, net of sampling
# noise: sd of dev (weighted by precision) with the mean sampling variance
# removed
tau_of <- function(dev, sv) {
  ok <- is.finite(dev) & is.finite(sv)
  sqrt(max(0, weighted.mean(dev[ok]^2, 1 / sv[ok]) - weighted.mean(sv[ok], 1 / sv[ok])))
}
# slope of dev on a covariate, through the origin, weighted by precision
slope_of <- function(dev, x, sv) {
  ok <- is.finite(dev) & is.finite(x) & is.finite(sv)
  sum(dev[ok] * x[ok] / sv[ok]) / sum(x[ok]^2 / sv[ok])
}

# z: one row per municipality with unit, am, af (deaths by sex), pop, H_u
# (unit homicides), dev (municipal deviation of the non-violent log sex
# ratio, 0 for `common`) and s2 (variance of what is left unexplained of it).
# prior: the homicides of the unit split by deaths or by population.
# the prior CV is the maximum-likelihood value of a normal random effect on
# the relative scale, (raw - prior) / prior ~ N(0, cv^2 + v_raw / prior^2).
allocate <- function(z, prior = c("deaths", "pop"), cv = NULL) {
  prior <- match.arg(prior)
  z <- z |>
    mutate(
      A = am + af,
      th_u = H_u / sum(A),
      lam_u = log((sum(am) - pi_m * H_u) / (sum(af) - (1 - pi_m) * H_u)),
      prior = if (prior == "deaths") H_u * A / sum(A) else H_u * pop / sum(pop),
      .by = unit
    ) |>
    mutate(
      rho = exp(lam_u + dev),
      den = pi_m - rho * (1 - pi_m),
      raw = (am - rho * af) / den,
      v_raw = (am + rho^2 * af + (rho * af)^2 * s2) / den^2
    )
  k <- z |> filter(prior >= 1)
  zz <- (k$raw - k$prior) / k$prior
  ss <- k$v_raw / k$prior^2
  if (is.null(cv)) cv <- optimize(function(cv) sum(log(cv^2 + ss) + zz^2 / (cv^2 + ss)), c(0.01, 3))$minimum
  z |>
    mutate(
      w = (cv * prior)^2 / ((cv * prior)^2 + v_raw),
      post = pmax(prior + w * (raw - prior), 0),
      cv = cv
    ) |>
    mutate(hom = H_u * post / sum(post), .by = unit)
}

# scores of an allocation against observed counts
score <- function(z, hom, obs) {
  z |>
    transmute(unit, hom = {{ hom }}, obs = {{ obs }}, pop) |>
    filter(pop > 0) |>
    mutate(lr = log((hom + 0.5) / pop), lo = log((obs + 0.5) / pop)) |>
    mutate(lr_w = lr - mean(lr), lo_w = lo - mean(lo), .by = unit) |>
    summarise(n = n(), r_within = suppressWarnings(cor(lr_w, lo_w)), rmse_within = sqrt(mean((lr_w - lo_w)^2)),
              misallocated = sum(abs(hom - obs)) / (2 * sum(obs)))
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. validation on EEVV ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sh <- read_csv("output/deaths_pop_munic_1985_2023.csv.gz", show_col_types = FALSE) |>
  filter(year <= 2019) |>
  mutate(unit = sprintf("%02d", as.integer(cod_dpto)), cod_munic = sprintf("%05d", as.integer(cod_munic)),
         dx_v = dx_homicide + dx_undetermined + dx_legal, pop = replace_na(pop, 0))

# municipality totals of a set of years, wide by sex. q < 1 keeps each
# violent death with probability q (binomial thinning), to bring the share
# of violent deaths down to the level of 1958-1960.
win <- function(years, q = 1) {
  w <- sh |>
    filter(year %in% years) |>
    summarise(d = sum(dx_all), v = sum(dx_v), p = sum(pop), .by = c(unit, cod_munic, sex))
  if (q < 1) w <- w |> mutate(vq = rbinom(n(), v, q), d = d - v + vq, v = vq) |> select(-vq)
  w |>
    pivot_wider(names_from = sex, values_from = c(d, v, p), values_fill = 0) |>
    mutate(nm = d_m - v_m, nf = d_f - v_f) # non-violent deaths
}

# deviations of the non-violent log sex ratio in a baseline period
base_dev <- function(b) {
  b |>
    filter(nm + nf >= 10) |>
    mutate(dev_b = lgt(nm, nf) - log(sum(nm) / sum(nf)),
           devp_b = log((p_m + 0.5) / (p_f + 0.5)) - log(sum(p_m) / sum(p_f)),
           sv_b = 1 / (nm + 0.5) + 1 / (nf + 0.5), .by = unit) |>
    select(unit, cod_munic, dev_b, devp_b, sv_b)
}
b_long <- base_dev(win(1985:1991))
b_short <- base_dev(win(2003:2009))
tau_common <- tau_of(b_long$dev_b, b_long$sv_b)
b_pop <- slope_of(b_long$dev_b, b_long$devp_b, b_long$sv_b)
tau_pop <- tau_of(b_long$dev_b - b_pop * b_long$devp_b, b_long$sv_b)
say("EEVV, non-violent log sex ratio around the department: tau", round(tau_common, 3),
    "| slope on the population sex ratio:", round(b_pop, 2), "| tau after it:", round(tau_pop, 3))

set.seed(1958)
val <- list()
kap <- list()
for (q in c(1, 0.3)) {
  for (y0 in c(1986, 1991, 1996, 2001, 2006, 2011, 2016)) {
    tg <- win(y0:(y0 + 2), q) |>
      filter(d_m + d_f > 0, p_m + p_f > 0) |>
      mutate(H_u = sum(v_m + v_f), k = n(), .by = unit) |>
      filter(k >= 5, H_u > 0) |>
      mutate(devp = log((p_m + 0.5) / (p_f + 0.5)) - log(sum(p_m) / sum(p_f)), .by = unit) |>
      transmute(unit, cod_munic, am = d_m, af = d_f, nm, nf, H_u, obs = v_m + v_f, pop = p_m + p_f, devp)
    runs <- list(
      common = tg |> mutate(dev = 0, s2 = tau_common^2),
      popcov = tg |> mutate(dev = b_pop * devp, s2 = tau_pop^2)
    )
    for (g in c("long", "short")) {
      if (!(y0 %in% c(2011, 2016))) next
      bb <- tg |> left_join(if (g == "long") b_long else b_short, by = c("unit", "cod_munic")) |>
        mutate(r = tau_common^2 / (tau_common^2 + sv_b), r = replace_na(r, 0), dev_b = replace_na(dev_b, 0))
      # drift of the municipal deviation between baseline and target, net of
      # sampling noise (uses the non-violent deaths of the target: one scalar)
      dv <- bb |> filter(nm + nf >= 10, r > 0) |>
        mutate(dev_t = lgt(nm, nf) - log(sum(nm) / sum(nf)), sv_t = 1 / (nm + 0.5) + 1 / (nf + 0.5), .by = unit)
      kappa <- tau_of(dv$dev_t - dv$dev_b, dv$sv_t + dv$sv_b)
      if (q == 1) kap[[length(kap) + 1]] <- tibble(window = y0, gap = g, kappa = kappa)
      runs[[paste0("did_", g)]] <- bb |> mutate(dev = r * dev_b, s2 = tau_common^2 * (1 - r) + kappa^2)
    }
    res <- list()
    for (nmr in names(runs)) for (pr in c("deaths", "pop")) {
      a <- allocate(runs[[nmr]], pr)
      for (s in c("all", "big")) {
        aa <- if (s == "all") a else a |> filter(A >= 200)
        res[[length(res) + 1]] <- score(aa, hom, obs) |>
          mutate(estimator = nmr, prior = pr, subset = s, cv = a$cv[1], w_mean = mean(aa$w))
        if (nmr == "common") res[[length(res) + 1]] <- score(aa, prior, obs) |>
          mutate(estimator = "none", prior = pr, subset = s)
      }
    }
    val[[length(val) + 1]] <- bind_rows(res) |>
      mutate(window = paste0(y0, "-", y0 + 2), thinning = q, share_violent = sum(tg$obs) / sum(tg$am + tg$af))
  }
}
val <- bind_rows(val) |> relocate(thinning, window, subset, estimator, prior)
kap <- bind_rows(kap)
write_csv(val, "output/tables/homicide_munic_validation.csv")
cat("\n== validation on EEVV: mean over windows (r within department; misallocated share) ==\n")
print(as.data.frame(val |> summarise(share_violent = round(mean(share_violent), 3), r_within = round(mean(r_within), 2),
                                     misallocated = round(mean(misallocated), 3), w_mean = round(mean(w_mean), 2), windows = n(),
                                     .by = c(thinning, subset, estimator, prior)) |> arrange(thinning, subset, estimator, prior)), row.names = FALSE)
print(as.data.frame(kap))
kappa_long <- mean(kap$kappa[kap$gap == "long"])

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. 1958-1960: data ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vit <- read_csv(paste0(h_dir, "dane_vitales_1958_1960_municipal.csv"), show_col_types = FALSE,
                col_types = cols(cod_dpto = "c", cod_munic = "c"))
say("1958-60: rows without code left out:", sum(is.na(vit$cod_munic)), "with", sum(vit$deaths_t[is.na(vit$cod_munic)], na.rm = TRUE), "deaths")
m58 <- vit |>
  filter(!is.na(cod_munic), !is.na(deaths_m), !is.na(deaths_f)) |>
  mutate(im = replace_na(infant_deaths_m, 0), i_f = replace_na(infant_deaths_f, 0)) |>
  summarise(municipio = first(municipio), years = n(), dm = sum(deaths_m), df = sum(deaths_f),
            am = sum(pmax(deaths_m - im, 0)), af = sum(pmax(deaths_f - i_f, 0)), .by = cod_munic) |>
  mutate(unit = coalesce(unname(cod_unit[substr(cod_munic, 1, 2)]), "territorios")) |>
  filter(am + af > 0)

# population by sex in mid-1959: censuses of 1951 and 1964, log-linear
popc <- read_csv(paste0(h_dir, "col_gap_analysis_1920_1985_municipal_population_clean_v03.csv"), show_col_types = FALSE) |>
  filter(!is.na(dane_code), !is.na(total), year %in% c(1951, 1964)) |>
  transmute(cod_munic = sprintf("%05d", as.integer(dane_code)), year, total, male, female) |>
  summarise(across(c(total, male, female), sum), .by = c(cod_munic, year))
ip <- function(y, v, at) {
  ok <- !is.na(v) & v > 0
  if (!any(ok)) NA_real_ else if (sum(ok) == 1) v[ok] else exp(approx(y[ok], log(v[ok]), at, rule = 2)$y)
}
pop59 <- popc |>
  summarise(pop_census = ip(year, total, 1959.5), p_m = ip(year, male, 1959.5), p_f = ip(year, female, 1959.5), .by = cod_munic)

# earlier period with little violence: deaths by sex, 1924-1936, all ages
early <- read_csv(paste0(h_dir, "col_gap_analysis_1920_1985_municipal_deaths_clean_v03.csv"), show_col_types = FALSE) |>
  filter(year <= 1936, !is.na(dane_code), !is.na(male), !is.na(female)) |>
  transmute(cod_munic = sprintf("%05d", as.integer(dane_code)), male, female) |>
  summarise(bm = sum(male), bf = sum(female), .by = cod_munic)

# unit totals: anuario homicides 1958-60 (all units report) and model 40
tot <- read_csv("output/tables/homicide_backcast_dept_1915-2019.csv", show_col_types = FALSE) |>
  filter(year %in% 1958:1960) |>
  summarise(H_anuario = sum(hom_anuario), H_model = sum(hom_est), deaths_unit = sum(deaths_reg), .by = unit)
stopifnot(!anyNA(tot$H_anuario))

m58 <- m58 |>
  left_join(pop59, by = "cod_munic") |>
  left_join(early, by = "cod_munic") |>
  left_join(tot, by = "unit") |>
  mutate(
    # the municipal file has the deaths of the unit except the rows without
    # code: homicides are scaled to the deaths that are in the file
    H_u = H_anuario * sum(dm + df) / deaths_unit,
    th_u = H_u / sum(am + af),
    # the few municipalities without census get the unit's persons per death
    pop = coalesce(pop_census, (am + af) * sum(pop_census, na.rm = TRUE) / sum((am + af)[!is.na(pop_census)])),
    devp = ifelse(is.na(p_m) | is.na(p_f), 0, log(p_m / p_f) - log(sum(p_m, na.rm = TRUE) / sum(p_f, na.rm = TRUE))),
    dev_1p = lgt(am, af) - log(sum(am) / sum(af)), sv_1p = 1 / (am + 0.5) + 1 / (af + 0.5),
    dev_b = lgt(bm, bf) - log(sum(bm, na.rm = TRUE) / sum(bf, na.rm = TRUE)), sv_b = 1 / (bm + 0.5) + 1 / (bf + 0.5),
    .by = unit
  )
say("1958-60: municipalities", nrow(m58), "| with census population", sum(!is.na(m58$pop_census)), "| with 1924-36 deaths", sum(!is.na(m58$bm)))
print(as.data.frame(m58 |> summarise(munic = n(), deaths = sum(dm + df), deaths_1plus = sum(am + af), H_u = round(first(H_u)),
                                     share_1plus_pct = round(100 * first(th_u), 1), H_model = round(first(H_model)), .by = unit) |>
                      arrange(-share_1plus_pct)), row.names = FALSE)

# heterogeneity of the non-violent sex ratio, measured in 1958-60 (ages 1+)
# where homicides are under 3 % of those deaths, and in 1924-36 (all ages)
calm <- m58 |> filter(th_u < 0.03, am + af >= 10)
tau1_common <- tau_of(calm$dev_1p, calm$sv_1p)
b1_pop <- slope_of(calm$dev_1p, calm$devp, calm$sv_1p)
tau1_pop <- tau_of(calm$dev_1p - b1_pop * calm$devp, calm$sv_1p)
eb <- m58 |> filter(!is.na(bm), bm + bf >= 10)
tau_early <- tau_of(eb$dev_b, eb$sv_b)
say("1958-60, calm units (", n_distinct(calm$unit), "), ages 1+: tau", round(tau1_common, 3), "| slope on the population sex ratio",
    round(b1_pop, 2), "| tau after it", round(tau1_pop, 3), "| 1924-36, all ages: tau", round(tau_early, 3),
    "| drift over a long gap, EEVV:", round(kappa_long, 3))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 4. validation under the conditions of 1958-1960: choice of cv ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EEVV windows with the violent deaths thinned and, in the "1958-60" setting,
# the non-violent deaths moved between the sexes by a municipal random shift
# of the log sex ratio, so that the heterogeneity left after the population
# covariate goes from the modern tau to the one measured in 1958-60.
tau_add <- sqrt(max(0, tau1_pop^2 - tau_pop^2))
target <- function(y0, q, add) {
  w <- win(y0:(y0 + 2), q) |> filter(d_m + d_f > 0, p_m + p_f > 0)
  if (add > 0) {
    w <- w |>
      mutate(nn = nm + nf, p0 = pmin(pmax(nm / pmax(nn, 1), 0.01), 0.99),
             nm = round(nn * plogis(qlogis(p0) + rnorm(n(), 0, add))), nf = nn - nm,
             d_m = nm + v_m, d_f = nf + v_f)
  }
  w |>
    mutate(H_u = sum(v_m + v_f), k = n(), .by = unit) |>
    filter(k >= 5, H_u > 0) |>
    mutate(devp = log((p_m + 0.5) / (p_f + 0.5)) - log(sum(p_m) / sum(p_f)), .by = unit) |>
    transmute(unit, cod_munic, am = d_m, af = d_f, H_u, obs = v_m + v_f, pop = p_m + p_f,
              dev = b_pop * devp, s2 = tau_pop^2 + add^2)
}
set.seed(1960)
cvs <- c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.75, 1, 1.5)
grid <- list()
for (add in c(0, tau_add)) for (q in c(1, 0.5, 0.3, 0.15)) for (y0 in c(1986, 1991, 1996, 2001, 2006, 2011, 2016)) {
  tg <- target(y0, q, add)
  for (pr in c("deaths", "pop")) for (cv in cvs) {
    a <- allocate(tg, pr, cv = cv)
    grid[[length(grid) + 1]] <- bind_rows(score(a, hom, obs) |> mutate(subset = "all"),
                                          score(a |> filter(A >= 200), hom, obs) |> mutate(subset = "big")) |>
      mutate(setting = ifelse(add > 0, "1958-60", "EEVV"), thinning = q, window = y0, prior = pr, cv = cv,
             share_violent = sum(tg$obs) / sum(tg$am + tg$af), w_mean = mean(a$w))
  }
}
grid <- bind_rows(grid) |>
  summarise(share_violent = mean(share_violent), r_within = mean(r_within), misallocated = mean(misallocated),
            w_mean = mean(w_mean), .by = c(setting, thinning, subset, prior, cv))
write_csv(grid, "output/tables/homicide_munic_validation_cv_grid.csv")
cat("\n== misallocated share by cv (0 = plain split), all municipalities ==\n")
print(as.data.frame(grid |> filter(subset == "all") |> mutate(share = round(100 * share_violent, 1), misallocated = round(misallocated, 3)) |>
                      select(setting, share, prior, cv, misallocated) |> pivot_wider(names_from = cv, values_from = misallocated)), row.names = FALSE)
cat("\n== within-department correlation of log rates by cv, all municipalities ==\n")
print(as.data.frame(grid |> filter(subset == "all") |> mutate(share = round(100 * share_violent, 1), r_within = round(r_within, 2)) |>
                      select(setting, share, prior, cv, r_within) |> pivot_wider(names_from = cv, values_from = r_within)), row.names = FALSE)

# cv and prior for 1958-60: lowest mean error in the 1958-60 setting over
# the three thinned levels
pick <- grid |>
  filter(setting == "1958-60", subset == "all", thinning < 1) |>
  summarise(misallocated = mean(misallocated), .by = c(prior, cv)) |>
  mutate(plain = misallocated[cv == 0], .by = prior) |>
  arrange(misallocated)
cat("\n== choice for 1958-60 (mean over 7, 4 and 2 % of violent deaths) ==\n")
print(as.data.frame(head(pick |> mutate(across(c(misallocated, plain), ~ round(.x, 3))), 6)), row.names = FALSE)
cv_star <- pick$cv[1]
prior_star <- pick$prior[1]
say("1958-60 uses prior by", prior_star, "and cv", cv_star, "| error", round(pick$misallocated[1], 3),
    "against", round(pick$plain[1], 3), "for the plain split by", prior_star,
    "and", round(min(pick$plain), 3), "for the best plain split")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 5. 1958-1960: allocation ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
a_main <- allocate(m58 |> mutate(dev = b1_pop * devp, s2 = tau1_pop^2), prior_star, cv = cv_star)
a_common <- allocate(m58 |> mutate(dev = 0, s2 = tau1_common^2), prior_star, cv = cv_star)
# `did` on all ages (1924-36 has no infant deaths); the unit homicide share
# is recomputed on those deaths inside allocate()
a_did <- allocate(m58 |>
  mutate(am = dm, af = df, r = replace_na(tau_early^2 / (tau_early^2 + sv_b), 0),
         dev = r * replace_na(dev_b, 0), s2 = tau_early^2 * (1 - r) + kappa_long^2), prior_star, cv = cv_star)

write_csv(tibble(term = c("pi_male", "cv", "prior", "tau_1plus_common", "slope_pop_sex_ratio", "tau_1plus_popcov",
                          "tau_early_all_ages", "kappa_drift_eevv", "tau_add_validation", "eevv_tau_common",
                          "eevv_slope_pop_sex_ratio", "eevv_tau_popcov", "mean_weight_main", "mean_weight_did"),
                 value = as.character(c(pi_m, cv_star, prior_star, round(c(tau1_common, b1_pop, tau1_pop, tau_early, kappa_long, tau_add,
                                        tau_common, b_pop, tau_pop, mean(a_main$w), mean(a_did$w)), 4)))),
          "output/tables/homicide_munic_1958-1960_parameters.csv")

out <- a_main |>
  transmute(unit, cod_munic, municipio, years, deaths = dm + df, deaths_1plus = A, pop_1959 = pop,
            pop_imputed = is.na(pop_census), sex_ratio_1plus = am / af, sr_nonviolent_expected = rho,
            share_unit_pct = 100 * th_u, hom_unit_3y = H_u, hom_plain_3y = prior, hom_raw_3y = raw, weight = w, hom_3y = hom) |>
  left_join(a_common |> select(cod_munic, hom_common_3y = hom), by = "cod_munic") |>
  left_join(a_did |> select(cod_munic, hom_did_3y = hom, weight_did = w), by = "cod_munic") |>
  mutate(hom_by_pop_3y = hom_unit_3y * pop_1959 / sum(pop_1959), hom_by_deaths_3y = hom_unit_3y * deaths_1plus / sum(deaths_1plus), .by = unit) |>
  mutate(rate = 1e5 * hom_3y / years / pop_1959, rate_plain = 1e5 * hom_plain_3y / years / pop_1959,
         rate_did = 1e5 * hom_did_3y / years / pop_1959)
write_csv(out, "output/tables/homicide_munic_1958-1960.csv")

# agreement between estimators that use different baselines
agree <- function(a, b) {
  out |>
    mutate(x = log(({{ a }} + 0.5) / pop_1959), y = log(({{ b }} + 0.5) / pop_1959)) |>
    mutate(x = x - mean(x), y = y - mean(y), .by = unit) |>
    summarise(r = cor(x, y)) |> pull(r)
}
cat("\n== 1958-60: within-unit correlation of log rates between allocations ==\n")
cat("main vs plain:", round(agree(hom_3y, hom_plain_3y), 2), "| main vs common:", round(agree(hom_3y, hom_common_3y), 2),
    "| main vs did:", round(agree(hom_3y, hom_did_3y), 2), "| did vs plain:", round(agree(hom_did_3y, hom_plain_3y), 2), "\n")
cat("mean weight of the municipality's own sex ratio: main", round(mean(a_main$w), 2), "| did", round(mean(a_did$w), 2), "\n")
print(as.data.frame(out |> summarise(munic = n(), weight = round(mean(weight), 2), moved_pct = round(100 * sum(abs(hom_3y - hom_plain_3y)) / (2 * sum(hom_3y)), 1),
                                     .by = unit) |> arrange(-weight)), row.names = FALSE)
cat("\n== 1958-60: highest rates among municipalities with 300+ deaths ==\n")
print(as.data.frame(out |> filter(deaths_1plus >= 300) |> slice_max(rate, n = 25) |>
  transmute(unit, municipio, deaths_1plus, sr = round(sex_ratio_1plus, 2), sr0 = round(sr_nonviolent_expected, 2), w = round(weight, 2),
            hom_year = round(hom_3y / years), rate = round(rate), rate_plain = round(rate_plain), rate_did = round(rate_did))), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 6. figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
base <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
        legend.position = "top", strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey40", hjust = 0))

# error against the weight given to the sex ratio, by level of violence
gfig <- grid |>
  filter(subset == "all", prior == prior_star) |>
  mutate(nivel = factor(thinning, c(1, 0.5, 0.3, 0.15),
                        paste0(round(100 * tapply(share_violent, thinning, mean)[c("1", "0.5", "0.3", "0.15")]), " %")),
         setting = factor(setting, c("EEVV", "1958-60"),
                          c("Heterogeneidad entre municipios de EEVV", "Heterogeneidad medida en 1958-60")))
fig1 <- ggplot(gfig, aes(cv, misallocated, colour = nivel, shape = nivel)) +
  geom_vline(xintercept = cv_star, colour = "grey60", linewidth = 0.3, linetype = 3) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 1.8) +
  scale_colour_manual(values = c("#0d366b", "#1c5cab", "#3987e5", "#86b6ef")) +
  scale_shape_manual(values = c(16, 17, 15, 18)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05)), labels = scales::label_percent(accuracy = 1)) +
  facet_wrap(~setting) +
  labs(title = "Validación con EEVV: error del reparto municipal según el peso dado a la razón de sexos",
       subtitle = paste0("Proporción de los homicidios asignada al municipio equivocado. En cv = 0 el reparto es solo por ",
                         ifelse(prior_star == "deaths", "defunciones", "población"),
                         "; la línea punteada es el cv usado en 1958-60.\nPromedio de siete trienios, 1986-2018, con las muertes violentas reducidas al nivel indicado."),
       x = "cv: variación supuesta de la proporción de homicidios entre municipios de un departamento", y = NULL,
       colour = "Muertes violentas como % de las defunciones", shape = "Muertes violentas como % de las defunciones") +
  base
ggsave("figures/06_backcast/munic_validation.png", fig1, w = 11, h = 5.5, bg = "white", dpi = 160)

# map of the rates, on today's municipal boundaries (municipalities created
# after 1960 have no data of their own and stay blank)
mapa <- st_as_sf(municipios) |>
  left_join(out |> select(cod_munic, rate), by = c("id" = "cod_munic")) |>
  mutate(cls = cut(rate, c(-Inf, 10, 25, 50, 100, Inf), c("< 10", "10-25", "25-50", "50-100", "100 o más")))
fig2 <- ggplot(mapa) +
  geom_sf(aes(fill = cls), colour = "white", linewidth = 0.03) +
  scale_fill_manual(values = c("< 10" = "#cde2fb", "10-25" = "#86b6ef", "25-50" = "#3987e5", "50-100" = "#1c5cab", "100 o más" = "#0d366b"),
                    na.value = "grey93", labels = function(x) ifelse(is.na(x), "Sin dato", x), drop = FALSE) +
  labs(title = "Homicidios por 100.000 habitantes al año, 1958-1960: reparto municipal",
       subtitle = "Total de cada unidad (anuarios) repartido con la razón de sexos de las defunciones de 1 año y más.\nLímites municipales actuales; en gris, municipios sin dato propio.",
       caption = "Prototipo. Homicidios entre las defunciones registradas, por lugar de registro.") +
  theme_void(base_size = 10) +
  theme(legend.position = "right", legend.title = element_blank(), plot.title = element_text(face = "bold"),
        plot.caption = element_text(colour = "grey40", hjust = 0), plot.margin = margin(8, 8, 8, 8))
ggsave("figures/06_backcast/munic_1958_1960_map.png", fig2, w = 8, h = 9.5, bg = "white", dpi = 170)

say("done")
