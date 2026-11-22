# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 70. Functions to validate the sex-ratio model of homicides in any country
#     with deaths by unit, year, sex and cause (sourced by 72; nothing runs
#     here)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The core of the Colombian model of 60, without what is specific to the
# Colombian sources (anuarios with gross errors, Policia, WHO constraint, two
# eras). What is left is the question that travels: how well does the sex
# ratio of all deaths recover the homicides of a unit when they are hidden?
#
# data     one row per unit and year: deaths of men and women (dm, df), all
#          deaths (d, with unknown sex) and violent deaths (h), built by
#          intl_data() from a long panel (country, unit, unit_label, year,
#          sex, age_band, cause, deaths). "violent" = homicide + legal
#          intervention + undetermined intent, as in Colombia
# model    state-space, by unit k and year t, two states that follow random
#          walks:
#            eta   log share of violent deaths in all deaths
#            u     deviation of the non-violent log sex ratio of the unit
#                  from the national one (rho_t)
#          observations:
#            y_e  = eta + e,                        var = s_e^2 + 1/h
#            y_sr = g(rho_t + u, eta) + e,          var = s_0^2 + 1/dm + 1/df
#          g is the accounting identity of 60 with pi = share of men among
#          the violent deaths, measured in the data of the country. rho_t
#          comes from the national deaths by sex and the national share of
#          violent deaths, as in 60 (so in the hidden blocks rho_t still
#          knows the national level of violence; a small leak, see 60)
#          the units are independent given rho_t: extended Kalman filter and
#          RTS smoother unit by unit, parameters (s_eta, s_u, s_0) common to
#          all units, by maximum likelihood; s_e fixed at 0.03 as in 60
# validation  blocks of years in which y_e is hidden for every unit:
#            N   nothing in the block (y_sr hidden too): interpolation
#            S   sex ratio in the block
#            ST  S, then rescaled to the national total of the year
#          parameters from the fit with all the data, as in 60
# simple   the benchmark of 64: negative binomial mixed model
#            h ~ national share + log sex ratio (slope by unit) + offset(log d)
#          refitted without each block and rescaled to the national total
#          (B0 the same without the sex ratio). the offset is the deaths, not
#          the population, so that no population file is needed
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

intl_violent <- c("homicide", "legal", "undetermined")
intl_s_e <- 0.03
intl_z90 <- qnorm(0.95)

# cause groups from the underlying cause, shared by the panel scripts (71, 73, ...)
#   homicide        ICD-9 E960-E969            ICD-10 X85-Y09, Y87.1
#   legal           ICD-9 E970-E978            ICD-10 Y35, Y89.0
#   undetermined    ICD-9 E980-E989            ICD-10 Y10-Y34, Y87.2
#   other_external  the rest of E800-E999 / V01-Y98
#   other           everything else
# ICD-9: the external causes come without the letter E (800-999) in the
# underlying-cause field of the mortality files
intl_cause_icd9 <- function(code) {
  n <- suppressWarnings(as.integer(substr(code, 1, 3)))
  data.table::fcase(is.na(n), "other",
                    n >= 960 & n <= 969, "homicide",
                    n >= 970 & n <= 978, "legal",
                    n >= 980 & n <= 989, "undetermined",
                    n >= 800 & n <= 999, "other_external",
                    default = "other")
}
intl_cause_icd10 <- function(code) {
  c3 <- substr(code, 1, 3); c4 <- substr(code, 1, 4)
  l <- substr(c3, 1, 1); n <- suppressWarnings(as.integer(substr(c3, 2, 3)))
  data.table::fcase(c4 == "Y871", "homicide", c4 == "Y890", "legal", c4 == "Y872", "undetermined",
                    (l == "X" & n >= 85) | (l == "Y" & n <= 9), "homicide",
                    c3 == "Y35", "legal",
                    l == "Y" & n >= 10 & n <= 34, "undetermined",
                    l %in% c("V", "W", "X", "Y"), "other_external",
                    default = "other")
}

# unit-year data from the long panel. ages: "all" or one or more age bands
intl_data <- function(panel, ages = "all", violent = intl_violent) {
  p <- if (identical(ages, "all")) panel else dplyr::filter(panel, age_band %in% ages)
  p |>
    dplyr::summarise(
      d = sum(deaths), dm = sum(deaths[sex == "m"]), df = sum(deaths[sex == "f"]),
      h = sum(deaths[cause %in% violent]), hm = sum(deaths[cause %in% violent & sex == "m"]),
      hf = sum(deaths[cause %in% violent & sex == "f"]),
      .by = c(country, unit, unit_label, year)
    ) |>
    dplyr::arrange(unit, year)
}

# log sex ratio of all deaths given the non-violent log sex ratio (delta) and
# the log share of violent deaths (eta)
intl_g <- function(delta, eta, pi_m) {
  h <- pmin(exp(eta), 0.9)
  ed <- exp(delta)
  log((1 - h) * ed + h * pi_m * (1 + ed)) - log((1 - h) + h * (1 - pi_m) * (1 + ed))
}

# national quantities and the observations of the model
# pi_m: share of men among the violent deaths; measured in the data unless given
intl_model_data <- function(dat, pi_m = NULL) {
  if (is.null(pi_m)) pi_m <- sum(dat$hm) / sum(dat$hm + dat$hf)
  nat <- dat |>
    dplyr::summarise(d = sum(d), dm = sum(dm), df = sum(df), h = sum(h), .by = year) |>
    dplyr::mutate(v_share = h / d, male_share = dm / (dm + df),
                  m0 = (male_share - v_share * pi_m) / (1 - v_share), rho = log(m0 / (1 - m0)))
  md <- dat |>
    dplyr::left_join(dplyr::select(nat, year, rho, h_nat = h, d_nat = d), by = "year") |>
    dplyr::mutate(
      y_sr = ifelse(dm > 0 & df > 0, log(dm / df), NA), q_sr = 1 / dm + 1 / df,
      y_e = ifelse(h > 0, log(h / d), NA), q_e = 1 / h
    )
  list(md = md, nat = nat, pi_m = pi_m)
}

# filter and smoother for one unit. z: rows of one unit sorted by year
intl_kf_unit <- function(z, par, pi_m, x0, smooth = FALSE) {
  n <- nrow(z)
  Q <- diag(c(par[1]^2, par[2]^2))
  x <- x0
  P <- diag(c(2, 0.3)^2)
  ll <- 0
  if (smooth) { xp <- xf <- matrix(NA, n, 2); Pp <- Pf <- array(NA, c(2, 2, n)) }
  upd <- function(H, innov, R) {
    S <- drop(H %*% P %*% H) + R
    K <- drop(P %*% H) / S
    x <<- x + K * innov
    P <<- P - tcrossprod(K, drop(H %*% P))
    ll <<- ll - 0.5 * (log(2 * pi * S) + innov^2 / S)
  }
  for (t in seq_len(n)) {
    if (t > 1) P <- P + Q
    if (smooth) { xp[t, ] <- x; Pp[, , t] <- P }
    if (!is.na(z$y_sr[t])) {
      g0 <- intl_g(z$rho[t] + x[2], x[1], pi_m)
      H <- c((intl_g(z$rho[t] + x[2], x[1] + 1e-5, pi_m) - g0) / 1e-5, (intl_g(z$rho[t] + x[2] + 1e-5, x[1], pi_m) - g0) / 1e-5)
      upd(H, z$y_sr[t] - g0, par[3]^2 + z$q_sr[t])
    }
    if (!is.na(z$y_e[t])) upd(c(1, 0), z$y_e[t] - x[1], intl_s_e^2 + z$q_e[t])
    if (smooth) { xf[t, ] <- x; Pf[, , t] <- P }
  }
  if (!smooth) return(ll)
  xs <- xf; Ps <- Pf
  for (t in rev(seq_len(n - 1))) {
    C <- Pf[, , t] %*% solve(Pp[, , t + 1])
    xs[t, ] <- xf[t, ] + drop(C %*% (xs[t + 1, ] - xp[t + 1, ]))
    Ps[, , t] <- Pf[, , t] + C %*% (Ps[, , t + 1] - Pp[, , t + 1]) %*% t(C)
  }
  data.frame(eta = xs[, 1], sd_eta = sqrt(pmax(Ps[1, 1, ], 0)), u = xs[, 2])
}

intl_run <- function(md, par, pi_m, smooth = FALSE) {
  x0 <- c(log(sum(md$h) / sum(md$d)), 0)
  parts <- split(md, md$unit)
  if (!smooth) return(sum(vapply(parts, intl_kf_unit, numeric(1), par = par, pi_m = pi_m, x0 = x0)))
  dplyr::bind_rows(lapply(parts, function(z) cbind(z, intl_kf_unit(z, par, pi_m, x0, smooth = TRUE))))
}

intl_fit <- function(md, pi_m, starts = list(c(0.15, 0.01, 0.02), c(0.08, 0.03, 0.05))) {
  best <- NULL
  for (s in starts) {
    o <- optim(log(s), function(lp) -intl_run(md, exp(lp), pi_m), method = "BFGS", control = list(maxit = 300))
    if (is.null(best) || o$value < best$value) best <- o
  }
  list(par = setNames(exp(best$par), c("s_eta", "s_u", "s_0")), loglik = -best$value, convergence = best$convergence)
}

# hidden blocks, state-space model. returns one row per block, variant and unit-year of the block
intl_validate <- function(md, par, pi_m, blocks) {
  out <- list()
  for (b in names(blocks)) {
    inb <- md$year %in% blocks[[b]]
    for (v in c("N: nothing in the block", "S: sex ratio")) {
      dat <- md
      dat$y_e[inb] <- NA
      if (v == "N: nothing in the block") dat$y_sr[inb] <- NA
      sm <- intl_run(dat, par, pi_m, smooth = TRUE)
      sm$truth <- md$y_e[match(paste(sm$unit, sm$year), paste(md$unit, md$year))]
      out[[length(out) + 1]] <- sm |>
        dplyr::filter(year %in% blocks[[b]], !is.na(truth)) |>
        dplyr::transmute(block = b, model = v, unit, unit_label, year, d, hom_obs = h, hom_pred = exp(eta) * d,
                         hom_lo90 = exp(eta - intl_z90 * sd_eta) * d, hom_hi90 = exp(eta + intl_z90 * sd_eta) * d,
                         covered90 = abs(truth - eta) <= intl_z90 * sqrt(sd_eta^2 + intl_s_e^2 + q_e))
    }
  }
  out <- dplyr::bind_rows(out)
  st <- out |> dplyr::filter(model == "S: sex ratio") |>
    dplyr::mutate(model = "ST: sex ratio + national total", k = sum(hom_obs) / sum(hom_pred), hom_pred = hom_pred * k,
                  hom_lo90 = NA, hom_hi90 = NA, covered90 = NA, .by = c(block, year)) |>
    dplyr::select(-k)
  dplyr::bind_rows(out, st) |> dplyr::mutate(family = "state-space")
}

# hidden blocks, simple benchmark (64)
intl_simple <- function(md, blocks) {
  cells <- md |> dplyr::filter(!is.na(y_e), !is.na(y_sr)) |>
    dplyr::mutate(log_nat = log(h_nat / d_nat), lsr_c = y_sr - mean(y_sr))
  forms <- list(
    "B0: national total" = h ~ log_nat + (1 | unit) + offset(log(d)),
    "B1: sex ratio + national total" = h ~ log_nat + lsr_c + (1 + lsr_c | unit) + offset(log(d))
  )
  fit1 <- function(f, dat) {
    m <- tryCatch(suppressWarnings(glmmTMB::glmmTMB(f, data = dat, family = glmmTMB::nbinom2)), error = function(e) NULL)
    bad <- is.null(m) || !isTRUE(m$sdr$pdHess) || m$fit$convergence != 0
    if (bad && grepl("1 + lsr_c | unit", deparse1(f), fixed = TRUE)) {
      f2 <- as.formula(gsub("(1 + lsr_c | unit)", "(1 | unit) + (0 + lsr_c | unit)", deparse1(f), fixed = TRUE))
      m2 <- tryCatch(suppressWarnings(glmmTMB::glmmTMB(f2, data = dat, family = glmmTMB::nbinom2)), error = function(e) NULL)
      if (!is.null(m2)) return(list(m = m2, note = "uncorrelated"))
    }
    list(m = m, note = if (bad) "not converged" else "ok")
  }
  out <- list()
  for (b in names(blocks)) {
    inb <- cells$year %in% blocks[[b]]
    for (mn in names(forms)) {
      ft <- fit1(forms[[mn]], cells[!inb, ])
      if (is.null(ft$m)) next
      test <- cells[inb, ]
      mu <- predict(ft$m, newdata = test, type = "response")
      out[[length(out) + 1]] <- test |>
        dplyr::transmute(block = b, model = mn, unit, unit_label, year, d, hom_obs = h, hom_raw = mu, covered90 = NA, note = ft$note) |>
        dplyr::mutate(hom_pred = hom_raw * sum(hom_obs) / sum(hom_raw), .by = year) |>
        dplyr::select(-hom_raw)
    }
  }
  dplyr::bind_rows(out) |> dplyr::mutate(family = "simple")
}

intl_scores <- function(pred, by = c("block", "family", "model")) {
  pred |>
    dplyr::mutate(lr = log(hom_pred / hom_obs)) |>
    dplyr::summarise(n = dplyr::n(), units = dplyr::n_distinct(unit),
                     median_abs_error_pct = 100 * median(abs(exp(lr) - 1)),
                     p90_abs_error_pct = 100 * unname(quantile(abs(exp(lr) - 1), 0.9)),
                     rmse_log = sqrt(mean(lr^2)), bias_log = mean(lr),
                     coverage90 = if (all(is.na(covered90))) NA_real_ else mean(covered90, na.rm = TRUE),
                     violent_share_pct = 100 * sum(hom_obs) / sum(d),
                     .by = dplyr::all_of(by))
}
