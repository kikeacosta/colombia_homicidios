# 20_model_improvements.R ----------------------------------------------------
# evaluation of ways to improve the municipal model of violent deaths, v2
# (redesigned after a design review; v1 re-entered the outcome through the
# department rate, mixed the pandemic into the covariates and evaluated only
# in-sample).
#
# design
#   sample A  1985-2019, the main comparison (pandemic excluded)
#   sample B  1985-2023, appendix: pandemic regime
#   covariates
#     - department violent-death rate LEAVE-ONE-OUT (excluding the
#       municipality itself) instead of the rate including it
#     - log crude death rate centred within municipality (no look-ahead)
#     - excess deaths: baseline fitted on years <= 2019 only
#     - sex ratios shrunk toward the department-year, sex-specific rate with a
#       pseudo-population of 1,000 persons (proportional, not a constant
#       number of deaths)
#     - completeness: the DDM window value as a step function (not an
#       interpolated trend)
#     - Mundlak split of the sex ratio into municipality mean (between) and
#       deviation (within)
#   two kinds of variants
#     descriptive (in-sample): regimes, Caribbean x regime, department x era
#       random effects, spline in time. These cannot be transferred across
#       eras and answer "does the relationship change?"
#     predictive (out-of-sample): null, all-ages sex ratio, age-specific
#       ratios, + completeness. Evaluated by (a) fitting 1998-2019 and
#       predicting 1985-97, and (b) 3-fold CV by blocks of years.
#   metric: within-department-year correlation of log municipal rates after
#       rescaling to the observed department total, departments with >= 5
#       municipalities, as gain over the null model
#
# outputs: output/tables/model_improvements_*.csv, figures/02_model/*

rm(list = ls())
gc()
source("code/00_setup.R")
library(arrow)
library(splines)

dir.create("data_inter/model_variants", showWarnings = FALSE)
t0 <- Sys.time()
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n", flush = TRUE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. data ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sh <- read_csv("output/deaths_pop_munic_1985_2023.csv.gz", show_col_types = FALSE) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)), cod_munic = sprintf("%05d", as.integer(cod_munic)),
         dx_v = dx_homicide + dx_undetermined + dx_legal) |>
  filter(!is.na(pop), pop > 0)

mu <- sh |> summarise(dts = sum(dx_all), dts_v = sum(dx_v), pop = sum(pop), .by = c(year, cod_dpto, dpto, cod_munic, munic))

# shrunk sex ratio: department-year, sex-specific rate as the prior, 1,000 persons of weight
K <- 1000
dep_sx <- sh |> summarise(r_dep = sum(dx_all) / sum(pop), .by = c(year, cod_dpto, sex))
sr <-
  sh |>
  left_join(dep_sx, by = c("year", "cod_dpto", "sex")) |>
  mutate(rate = (dx_all + K * r_dep) / (pop + K)) |>
  select(year, cod_munic, sex, rate) |>
  pivot_wider(names_from = sex, values_from = rate) |>
  transmute(year, cod_munic, sex_r_log = log(m / f))

ag <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |>
  as_tibble() |>
  filter(!is.na(age), !is.na(pop), pop > 0) |>
  mutate(band = case_when(age >= 15 & age <= 40 ~ "young", age >= 50 & age <= 75 ~ "old", TRUE ~ NA_character_),
         cod_dpto = sprintf("%02d", as.integer(cod_dpto)), cod_munic = sprintf("%05d", as.integer(cod_munic))) |>
  filter(!is.na(band)) |>
  summarise(dx = sum(dx_all), pop = sum(pop), .by = c(year, cod_dpto, cod_munic, sex, band))
dep_ag <- ag |> summarise(r_dep = sum(dx) / sum(pop), .by = c(year, cod_dpto, sex, band))
ag <-
  ag |>
  left_join(dep_ag, by = c("year", "cod_dpto", "sex", "band")) |>
  mutate(rate = (dx + K * r_dep) / (pop + K)) |>
  select(year, cod_munic, sex, band, rate) |>
  pivot_wider(names_from = c(sex, band), values_from = rate) |>
  transmute(year, cod_munic, sr_young = log(m_young / f_young), sr_old = log(m_old / f_old))

# leave-one-out department rate; single-municipality departments get the
# national leave-one-out rate
loo <-
  mu |>
  mutate(Vd = sum(dts_v), Pd = sum(pop), .by = c(year, cod_dpto)) |>
  mutate(Vn = sum(dts_v), Pn = sum(pop), .by = year) |>
  mutate(h_loo = ifelse(Pd - pop > 0, (Vd - dts_v) / (Pd - pop), (Vn - dts_v) / (Pn - pop))) |>
  select(year, cod_munic, h_loo)

# excess all-cause deaths, baseline fitted on <= 2019, projected to all years
est_exc <- function(chunk) {
  fit_y <- chunk$year <= 2019
  w <- rep(1, nrow(chunk)); w[!fit_y] <- 0
  for (i in 1:3) {
    m <- gam(dts ~ t, data = chunk, weights = w, family = "quasipoisson")
    pr <- predict(m, newdata = chunk, type = "response", se.fit = TRUE)
    u <- pr$fit + 1.96 * pr$se.fit
    w <- ifelse(chunk$dts > u | !fit_y, 0, 1)
  }
  chunk |> mutate(excess = ifelse(dts > u, dts - u, 0))
}
say("excess deaths")
exc <-
  mu |>
  arrange(cod_munic, year) |>
  mutate(t = row_number(), n = n(), .by = cod_munic) |>
  filter(n == max(n)) |>
  group_by(cod_munic) |>
  group_modify(~ est_exc(.x)) |>
  ungroup() |>
  select(year, cod_munic, excess)

# completeness: DDM hybrid, mean of the sexes, as a step function of the window
ddm <- read_csv("output/tables/completeness_ddm.csv", show_col_types = FALSE) |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod))) |>
  summarise(c = mean(ggbseg), .by = c(window, cod_dpto)) |>
  mutate(c = pmin(c, 1))
step <- function(y) case_when(y <= 1993 ~ "1985-1993", y <= 2005 ~ "1993-2005", TRUE ~ "2005-2017")
comp <- expand_grid(year = 1985:2023, cod_dpto = unique(ddm$cod_dpto)) |>
  mutate(window = step(year)) |>
  left_join(ddm, by = c("window", "cod_dpto")) |>
  select(year, cod_dpto, comp = c)
comp <- bind_rows(comp, comp |> filter(cod_dpto == "91") |> select(year, comp) |> cross_join(tibble(cod_dpto = c("94", "95", "97", "99"))))

dat_all <-
  mu |>
  left_join(sr, by = c("year", "cod_munic")) |>
  left_join(ag, by = c("year", "cod_munic")) |>
  left_join(exc, by = c("year", "cod_munic")) |>
  left_join(loo, by = c("year", "cod_munic")) |>
  left_join(comp, by = c("year", "cod_dpto")) |>
  drop_na(sex_r_log, sr_young, sr_old, excess, h_loo, comp) |>
  filter(is.finite(sex_r_log), is.finite(sr_young), is.finite(sr_old), is.finite(excess), is.finite(h_loo)) |>
  mutate(w_pop = pop / sum(pop), n_munic = n(), .by = c(cod_dpto, year)) |>
  mutate(
    exc_mx_log = log((excess + 1) / pop),
    log_cdr = log(dts / pop + 1e-5),
    log_cdr_c = log_cdr - mean(log_cdr[year <= 2019]),
    sr_mean = mean(sex_r_log[year <= 2019]),
    yng_mean = mean(sr_young[year <= 2019]),
    old_mean = mean(sr_old[year <= 2019]), .by = cod_munic
  ) |>
  mutate(
    sr_within = sex_r_log - sr_mean,
    yng_within = sr_young - yng_mean,
    old_c = sr_old - old_mean,
    h_loo_log = log(h_loo + 1e-5),
    comp_c = comp - 0.75,
    era = factor(ifelse(year < 1998, "pre1998", "post1998"), levels = c("post1998", "pre1998")),
    caribe = cod_dpto %in% cod_caribe,
    dpto_era = interaction(cod_dpto, era, drop = TRUE),
    yr = (year - 2002) / 10
  ) |>
  drop_na(sex_r_log, sr_young, sr_old, exc_mx_log, h_loo, comp) |>
  filter(is.finite(sex_r_log), is.finite(sr_young), is.finite(sr_old), is.finite(exc_mx_log))

A <- dat_all |> filter(year <= 2019)
say("sample A rows:", nrow(A), " municipalities:", n_distinct(A$cod_munic), " | all years rows:", nrow(dat_all))

ctl <- glmmTMBControl(optCtrl = list(iter.max = 1000, eval.max = 1000))
ff <- function(rhs) as.formula(paste("dts_v ~", rhs, "+ offset(log(pop))"))
re <- "(1 | cod_dpto) + (1 | cod_munic)"
core <- "h_loo_log + log_cdr_c + exc_mx_log + w_pop"

fit_one <- function(f, zi, d, nm = "") {
  fit <- tryCatch(glmmTMB(f, ziformula = zi, data = d, family = nbinom2, control = ctl),
                  error = function(e) { say("   failed", nm, conditionMessage(e)); NULL })
  fit
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. descriptive variants (in-sample, sample A) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

desc <- list(
  D0_null  = list(ff(paste(core, "+", re)), ~ w_pop),
  D1_sr    = list(ff(paste("sr_within + sr_mean +", core, "+", re)), ~ sr_within + w_pop),
  D2_era   = list(ff(paste("sr_within * era + sr_mean +", core, "+", re)), ~ sr_within + w_pop),
  D3_carib = list(ff(paste("sr_within * era * caribe + sr_mean +", core, "+", re)), ~ sr_within + w_pop),
  D4_dera  = list(ff(paste("sr_within * era + sr_mean +", core, "+ (1 | cod_dpto) + (1 | dpto_era) + (1 | cod_munic)")), ~ sr_within + w_pop),
  D5_slope = list(ff(paste("sr_within * era + sr_mean +", core, "+ (1 + sr_within || cod_dpto) + (1 | cod_munic)")), ~ sr_within + w_pop),
  D6_comp  = list(ff(paste("sr_within * era + sr_within:comp_c + comp_c + sr_mean +", core, "+", re)), ~ sr_within + w_pop),
  D7_spl   = list(ff(paste("sr_within * ns(year, df = 4) + sr_mean +", core, "+", re)), ~ sr_within + w_pop)
)
dfits <- list()
for (nm in names(desc)) {
  say("descriptive:", nm)
  fit <- fit_one(desc[[nm]][[1]], desc[[nm]][[2]], A, nm)
  if (is.null(fit)) next
  dfits[[nm]] <- fit
  say("   logLik", round(as.numeric(logLik(fit)), 1), " pdHess", fit$sdr$pdHess, " elapsed", round(difftime(Sys.time(), t0, units = "mins"), 1), "min")
}
dev <- imap_dfr(dfits, \(fit, nm) tibble(model = nm, df = attr(logLik(fit), "df"), logLik = as.numeric(logLik(fit)),
                                         aic = AIC(fit), bic = BIC(fit), pdHess = isTRUE(fit$sdr$pdHess)))
dev$daic_vs_D1 <- dev$aic - dev$aic[dev$model == "D1_sr"]
write_csv(dev, "output/tables/model_improvements_descriptive.csv")
print(dev |> mutate(across(where(is.numeric), ~ round(.x, 1))) |> as.data.frame())

dco <- imap_dfr(dfits, \(fit, nm) {
  x <- summary(fit)$coefficients$cond
  tibble(model = nm, term = rownames(x), estimate = x[, 1], se = x[, 2], z = x[, 3], p = x[, 4])
})
write_csv(dco, "output/tables/model_improvements_coefficients.csv")
print(dco |> filter(model %in% c("D2_era", "D3_carib", "D6_comp"), grepl("sr_within|comp|sr_mean", term)) |>
        mutate(across(where(is.numeric), ~ round(.x, 3))) |> as.data.frame())

# time-varying slope from D7
if (!is.null(dfits$D7_spl)) {
  fe <- fixef(dfits$D7_spl)$cond; vc <- vcov(dfits$D7_spl)$cond
  B <- ns(A$year, df = 4); yrs <- 1985:2019
  X <- cbind(1, predict(B, yrs))
  idx <- c("sr_within", grep("^sr_within:ns", names(fe), value = TRUE))
  sl <- as.numeric(X %*% fe[idx]); se <- sqrt(rowSums((X %*% vc[idx, idx]) * X))
  tv <- tibble(year = yrs, slope = sl, lo = sl - 1.96 * se, hi = sl + 1.96 * se)
  write_csv(tv, "output/tables/model_improvements_time_varying_slope.csv")
  ggplot(tv, aes(year, slope)) +
    geom_hline(yintercept = 0, lty = "dashed", col = "grey60") +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.2) + geom_line(linewidth = 1) +
    geom_vline(xintercept = 1997.5, lty = "dashed", alpha = 0.5) +
    labs(x = NULL, y = "within-municipality coefficient of the log sex ratio",
         title = "Time-varying coefficient of the sex ratio (natural spline, 4 df)") +
    theme_minimal()
  ggsave("figures/02_model/model_improvements_time_varying_slope.png", w = 8, h = 4.5)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. predictive variants, out-of-sample ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

pred <- list(
  P0_null = list(ff(paste(core, "+", re)), ~ w_pop),
  P1_all  = list(ff(paste("sex_r_log +", core, "+", re)), ~ sex_r_log + w_pop),
  P2_age  = list(ff(paste("sr_young + sr_old +", core, "+", re)), ~ sr_young + w_pop),
  P3_comp = list(ff(paste("sr_young + sr_old + sr_young:comp_c + comp_c +", core, "+", re)), ~ sr_young + w_pop)
)

score <- function(fit, test, tag) {
  out <- map_dfr(c("conditional", "population"), \(kind) {
    p <- tryCatch(
      predict(fit, newdata = test, type = "response", allow.new.levels = TRUE, re.form = if (kind == "population") NA else NULL),
      error = function(e) rep(NA_real_, nrow(test)))
    test |>
      mutate(p = p) |>
      filter(!is.na(p)) |>
      mutate(pr = sum(dts_v) * p / sum(p), .by = c(cod_dpto, year)) |>
      filter(n_munic >= 5) |>
      mutate(lo = log((pr + 0.5) / pop), ly = log((dts_v + 0.5) / pop)) |>
      summarise(r = suppressWarnings(cor(lo, ly)), rmse = sqrt(mean((lo - ly)^2)), caribe = first(caribe), era = first(era), n = n(),
                .by = c(cod_dpto, year)) |>
      mutate(kind = kind, scheme = tag)
  })
  out
}

res <- list()
# (a) transfer: fit 1998-2019, predict 1985-97
train <- A |> filter(era == "post1998"); test <- A |> filter(era == "pre1998")
for (nm in names(pred)) {
  say("transfer fit:", nm)
  fit <- fit_one(pred[[nm]][[1]], pred[[nm]][[2]], train, nm)
  if (!is.null(fit)) res[[paste("transfer", nm)]] <- score(fit, test, "transfer 1998-2019 to 1985-97") |> mutate(model = nm, pdHess = isTRUE(fit$sdr$pdHess))
}
# (b) 3-fold CV by blocks of years
folds <- list(1985:1995, 1996:2007, 2008:2019)
for (k in seq_along(folds)) {
  tr <- A |> filter(!year %in% folds[[k]]); te <- A |> filter(year %in% folds[[k]])
  for (nm in names(pred)) {
    say("cv fold", k, nm)
    fit <- fit_one(pred[[nm]][[1]], pred[[nm]][[2]], tr, nm)
    if (!is.null(fit)) res[[paste("cv", k, nm)]] <- score(fit, te, "block CV") |> mutate(model = nm, fold = k, pdHess = isTRUE(fit$sdr$pdHess))
  }
  saveRDS(bind_rows(res), "data_inter/model_variants/oos_scores_partial.rds")
}
oos <- bind_rows(res)
saveRDS(oos, "data_inter/model_variants/oos_scores.rds")

sumry <-
  oos |>
  mutate(group = case_when(caribe & era == "pre1998" ~ "Caribbean 1985-97", !caribe & era == "pre1998" ~ "other 1985-97", TRUE ~ "post-1998")) |>
  summarise(r = mean(r, na.rm = TRUE), rmse = mean(rmse, na.rm = TRUE), n = n(), .by = c(scheme, kind, model, group)) |>
  group_by(scheme, kind, group) |>
  mutate(r_gain_vs_null = r - r[model == "P0_null"], rmse_gain_vs_null = rmse[model == "P0_null"] - rmse) |>
  ungroup() |>
  arrange(scheme, kind, group, model)
write_csv(sumry, "output/tables/model_improvements_out_of_sample.csv")
print(sumry |> filter(kind == "conditional") |> mutate(across(where(is.numeric), ~ round(.x, 3))) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 4. appendix: pandemic regime (sample 1985-2023) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

B <- dat_all |> mutate(pandemic = factor(ifelse(year >= 2020 & year <= 2022, "pandemic", "other"), levels = c("other", "pandemic")))
say("pandemic appendix, rows", nrow(B))
b1 <- fit_one(ff(paste("sr_within * era + sr_mean +", core, "+", re)), ~ sr_within + w_pop, B, "B1")
b2 <- fit_one(ff(paste("sr_within * era + sr_within:pandemic + pandemic + sr_mean +", core, "+", re)), ~ sr_within + w_pop, B, "B2")
bco <- bind_rows(
  if (!is.null(b1)) { x <- summary(b1)$coefficients$cond; tibble(model = "B1_no_pandemic_term", term = rownames(x), estimate = x[, 1], se = x[, 2], p = x[, 4]) },
  if (!is.null(b2)) { x <- summary(b2)$coefficients$cond; tibble(model = "B2_pandemic_regime", term = rownames(x), estimate = x[, 1], se = x[, 2], p = x[, 4]) }
)
write_csv(bco, "output/tables/model_improvements_pandemic.csv")
if (!is.null(b1) && !is.null(b2)) cat("AIC B1", AIC(b1), " B2", AIC(b2), "\n")
print(bco |> filter(grepl("sr_within|pandemic", term)) |> mutate(across(where(is.numeric), ~ round(.x, 3))) |> as.data.frame())
say("done")
