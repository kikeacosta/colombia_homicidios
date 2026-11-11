# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 38. National reconstruction 1950-2023: formal estimation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The cohort-component engine of 37 inside a Bayesian model. The census
# counts by age and sex are the data; the completeness of death registration,
# the scale of net migration and the coverage of each census are parameters
# with explicit priors. The point is to see what the censuses can say about
# mortality once their own errors and migration are allowed to vary.
#
# model
#   population   1 January, single ages 0-100+, both sexes, 1950-2024; the
#                base population of 1 January 1950 and the fertility rates
#                are WPP 2024's and are held fixed
#   mortality    under five: WPP 2024 (placeholder until UN IGME is added)
#                ages 5+: deaths = registered / c(t, sex) + MSE conflict
#                deaths missing from the registry (27). c is the completeness
#                of the registered deaths; logit c is piecewise linear in
#                time with knots every ten years (1950, ..., 2020), by sex
#   migration    WPP's net migrants by age and sex (37) times a multiplier
#                g(period, sex), seven periods (1950s, ..., 2000s, 2010-23).
#                The age profile is WPP's; age 0, a residual of the engine's
#                convention, is not scaled
#   censuses     log enumerated(census, sex, age group) ~ Normal(log(kappa x
#                projected), sigma), age groups 5-9 to 65-69. kappa(census,
#                sex) is the coverage. Ages 0-4 (under-enumeration) and 70+
#                (age exaggeration) are left out of the likelihood: with a
#                free age pattern of census error at those ages, mortality
#                would not be identified from them anyway
#
# priors (ASSUMPTIONS)
#   logit c at each knot ~ N(logit 0.90, 1), and successive knots differ by
#     N(0, 0.7) (first-order random walk): vague on the level, smooth in time
#   g ~ N(1, 0.5)
#   log kappa ~ N(log k0, s): k0 = enumerated / DANE retroprojection for
#     1985, 1993, 2005 (0.91, 0.94, 0.985), 1 - DANE's published omission
#     for 2018 (0.915), 1.00 for 1973 (UNdata carries DANE's adjusted
#     counts), all with s = 0.03; 0.95 and 0.97 for 1951 and 1964, s = 0.05
#   log sigma ~ N(log 0.04, 0.5)
#
# estimation: posterior mode (BFGS) and Laplace approximation (inverse
#   Hessian), 2,000 draws for the intervals. For every parameter the ratio
#   posterior sd / prior sd says how much the censuses add to the prior:
#   near 1, nothing.
#
# sensitivity: migration fixed at WPP (g = 1); wide coverage priors (s =
#   0.15); completeness prior centred on the empirical method (Adair-Lopez
#   model 1 of 36, logit sd 0.5).
#
# output: output/tables/reconstruction_parameters.csv
#         output/tables/reconstruction_completeness_annual.csv
#         output/tables/reconstruction_census_fit.csv
#         figures/05_reconstruction/estimation_completeness.png
#         figures/05_reconstruction/estimation_parameters.png
#         figures/05_reconstruction/estimation_census_fit.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
set.seed(2026)
dir.create("figures/05_reconstruction", showWarnings = FALSE)

years <- 1950:2023; ny <- length(years)
ages <- 0:100; na <- length(ages)
sexes <- c("m", "f")
grp_lo <- c(0, 1, seq(5, 80, 5))
grp <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), 80))
gi <- match(grp(ages), grp_lo)
knots <- seq(1950, 2020, 10); nk <- length(knots)
periods <- c(seq(1950, 2000, 10), 2010); np <- length(periods)
per_i <- findInterval(years, periods)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# inputs ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
mat <- \(d, v, rows = "age") d |> select(year, all_of(c(rows, v))) |> pivot_wider(names_from = year, values_from = all_of(v)) |>
  arrange(.data[[rows]]) |> select(-all_of(rows)) |> as.matrix()
by_sex <- \(d, v, rows = "age") map(set_names(sexes), \(s) mat(filter(d, sex == s), v, rows))

pop_wpp <- read_csv("data_input/reference/wpp2024_colombia_pop_1jan_single_age_1950-2024.csv", show_col_types = FALSE) |>
  transmute(year = Time, age = AgeGrpStart, m = PopMale * 1000, f = PopFemale * 1000) |>
  pivot_longer(c(m, f), names_to = "sex", values_to = "pop")
P_w <- by_sex(pop_wpp, "pop")
pop0 <- map(P_w, \(p) p[, 1])

lt_wpp <- read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Time %in% years, Sex != "Total") |>
  transmute(year = Time, sex = unname(c(Female = "f", Male = "m")[Sex]), age = AgeGrpStart, mx, ax)
mx_w <- by_sex(lt_wpp, "mx"); ax_w <- by_sex(lt_wpp, "ax")

F_w <- read_csv("data_input/reference/wpp2024_colombia_fertility_age1.csv", show_col_types = FALSE) |>
  filter(Variant == "Medium", Time %in% years) |>
  transmute(year = Time, age = AgeGrpStart, fx = ASFR / 1000) |>
  complete(year = years, age = ages, fill = list(fx = 0)) |> mat("fx")

M_w <- read_csv("output/tables/wpp_net_migration_age_sex_1950-2023.csv", show_col_types = FALSE) |> by_sex("net_mig")

exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |>
  mutate(r_reg = registered / wpp_total, r_add = (hom_excess + dsp) / wpp_total)
R_reg <- map(by_sex(exp, "r_reg"), \(r) r[gi, ])   # single ages x years
R_add <- map(by_sex(exp, "r_add"), \(r) r[gi, ])

cen <- read_rds("data_inter/census_pop_age.rds") |> filter(census >= 1951) |> select(census, dec, sex, age, enumerated = pop)
censuses <- cen |> distinct(census, dec) |> arrange(census)
nc <- nrow(censuses)
fit_groups <- which(grp_lo >= 5 & grp_lo <= 65)
O <- map(set_names(sexes), \(s) cen |> filter(sex == s) |> select(census, age, enumerated) |>
           pivot_wider(names_from = census, values_from = enumerated) |> arrange(age) |> select(-age) |> as.matrix())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# engine (37), on matrices ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Lx_mat <- function(mx, ax) {
  k <- nrow(mx)
  ax[k, ] <- 1 / mx[k, ]
  qx <- pmin(mx / (1 + (1 - ax) * mx), 0.999999); qx[k, ] <- 1
  lx <- rbind(1, exp(apply(log(1 - qx[-k, , drop = FALSE]), 2, cumsum)))
  Lx <- rbind(lx[-1, , drop = FALSE], 0) + ax * lx * qx
  Lx[k, ] <- lx[k, ] / mx[k, ]
  Lx
}
L_w <- map(set_names(sexes), \(s) Lx_mat(mx_w[[s]], ax_w[[s]]))
srb <- (P_w$m[1, 2:(ny + 1)] / L_w$m[1, ]) / (P_w$f[1, 2:(ny + 1)] / L_w$f[1, ])

survive <- function(p, L) {
  out <- numeric(na)
  out[2:(na - 1)] <- p[1:(na - 2)] * L[2:(na - 1)] / L[1:(na - 2)]
  out[na] <- (p[na - 1] + p[na]) * L[na] / (L[na - 1] + L[na])
  out
}
# c: list(m, f) of annual completeness; g: list(m, f) of annual migration multipliers
project <- function(c, g) {
  L <- map(set_names(sexes), \(s) {
    mult <- sweep(R_reg[[s]], 2, c[[s]], "/") + R_add[[s]]
    mult[1:5, ] <- 1
    Lx_mat(mx_w[[s]] * mult, ax_w[[s]])
  })
  G <- map(set_names(sexes), \(s) { m <- sweep(M_w[[s]], 2, g[[s]], "*"); m[1, ] <- M_w[[s]][1, ]; m })
  Pm <- Pf <- matrix(0, na, ny + 1)
  Pm[, 1] <- pop0$m; Pf[, 1] <- pop0$f
  for (j in seq_len(ny)) {
    m2 <- survive(Pm[, j], L$m[, j]); f2 <- survive(Pf[, j], L$f[, j])
    b <- sum(F_w[, j] * (Pf[, j] + f2) / 2)
    f2[1] <- b / (1 + srb[j]) * L$f[1, j]; m2[1] <- b * srb[j] / (1 + srb[j]) * L$m[1, j]
    Pm[, j + 1] <- pmax(m2 + G$m[, j], 1); Pf[, j + 1] <- pmax(f2 + G$f[, j], 1)
  }
  list(m = Pm, f = Pf)
}
# projected population at the census dates, by census age group: list(m, f) of 18 x nc matrices
cj <- floor(censuses$dec) - years[1] + 1; cw <- censuses$dec - floor(censuses$dec)
at_census <- function(P) map(P, \(p) rowsum(sweep(p[, cj], 2, 1 - cw, "*") + sweep(p[, cj + 1], 2, cw, "*"), gi))

chk <- project(list(m = rep(1, ny), f = rep(1, ny)), list(m = rep(1, ny), f = rep(1, ny)))
t0 <- system.time(for (i in 1:20) project(list(m = rep(0.9, ny), f = rep(0.9, ny)), list(m = rep(1, ny), f = rep(1, ny))))[["elapsed"]] / 20
cat("one projection:", round(1000 * t0, 1), "ms\n")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# parameters, priors, posterior ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ix <- list(lc_m = 1:nk, lc_f = nk + 1:nk, g_m = 2 * nk + 1:np, g_f = 2 * nk + np + 1:np,
           lk_m = 2 * nk + 2 * np + 1:nc, lk_f = 2 * nk + 2 * np + nc + 1:nc, ls = 2 * nk + 2 * np + 2 * nc + 1)
npar <- ix$ls
par_names <- c(paste0("logit c ", rep(sexes, each = nk), " ", knots), paste0("g ", rep(sexes, each = np), " ", periods),
               paste0("log kappa ", rep(sexes, each = nc), " ", censuses$census), "log sigma")
k0 <- c(`1951` = 0.95, `1964` = 0.97, `1973` = 1.00, `1985` = 0.91, `1993` = 0.94, `2005` = 0.985, `2018` = 0.915)
sd_k0 <- c(0.05, 0.05, 0.03, 0.03, 0.03, 0.03, 0.03)

annual_c <- \(lc) plogis(approx(knots, lc, xout = years, rule = 2)$y)
unpack <- function(th) list(c = list(m = annual_c(th[ix$lc_m]), f = annual_c(th[ix$lc_f])),
                            g = list(m = th[ix$g_m][per_i], f = th[ix$g_f][per_i]),
                            lk = list(m = th[ix$lk_m], f = th[ix$lk_f]), sigma = exp(th[ix$ls]))

cfg0 <- list(c_mean = list(m = rep(qlogis(0.9), nk), f = rep(qlogis(0.9), nk)), sd_c = 1, sd_rw = 0.7, sd_g = 0.5, sd_k = sd_k0)
neg_prior <- function(th, cfg) {
  -(sum(dnorm(th[ix$lc_m], cfg$c_mean$m, cfg$sd_c, log = TRUE)) + sum(dnorm(th[ix$lc_f], cfg$c_mean$f, cfg$sd_c, log = TRUE)) +
      sum(dnorm(diff(th[ix$lc_m]), 0, cfg$sd_rw, log = TRUE)) + sum(dnorm(diff(th[ix$lc_f]), 0, cfg$sd_rw, log = TRUE)) +
      sum(dnorm(th[c(ix$g_m, ix$g_f)], 1, cfg$sd_g, log = TRUE)) +
      sum(dnorm(th[ix$lk_m], log(k0), cfg$sd_k, log = TRUE)) + sum(dnorm(th[ix$lk_f], log(k0), cfg$sd_k, log = TRUE)) +
      dnorm(th[ix$ls], log(0.04), 0.5, log = TRUE))
}
neg_lik <- function(th) {
  u <- unpack(th)
  E <- at_census(project(u$c, u$g))
  -sum(map_dbl(sexes, \(s) sum(dnorm(log(O[[s]][fit_groups, ]), sweep(log(E[[s]][fit_groups, ]), 2, u$lk[[s]], "+"), u$sigma, log = TRUE))))
}
neg_post <- \(th, cfg) neg_prior(th, cfg) + neg_lik(th)

fit_model <- function(label, cfg) {
  t1 <- Sys.time()
  start <- c(cfg$c_mean$m, cfg$c_mean$f, rep(1, 2 * np), rep(log(k0), 2), log(0.04))
  o <- optim(start, neg_post, cfg = cfg, method = "BFGS", control = list(maxit = 400, reltol = 1e-10))
  H <- optimHess(o$par, neg_post, cfg = cfg)
  H0 <- optimHess(o$par, neg_prior, cfg = cfg)
  ev <- eigen((H + t(H)) / 2, symmetric = TRUE, only.values = TRUE)$values
  cat(sprintf("%-28s convergence %d, -log posterior %.1f, smallest Hessian eigenvalue %.3g, %.0f s\n",
              label, o$convergence, o$value, min(ev), as.numeric(difftime(Sys.time(), t1, units = "secs"))))
  list(label = label, cfg = cfg, par = o$par, cov = solve((H + t(H)) / 2), cov0 = solve((H0 + t(H0)) / 2), conv = o$convergence)
}

c_al <- read_csv("output/tables/completeness_compared_annual.csv", show_col_types = FALSE) |>
  filter(method == "Adair-Lopez, modelo 1")
al_knots <- \(s) qlogis(pmin(approx(c_al$year[c_al$sex == s], c_al$completeness[c_al$sex == s], xout = knots, rule = 2)$y, 0.99))

fits <- list(
  fit_model("principal", cfg0),
  fit_model("migración fija en WPP", modifyList(cfg0, list(sd_g = 0.01))),
  fit_model("cobertura censal amplia", modifyList(cfg0, list(sd_k = rep(0.15, nc)))),
  fit_model("previa Adair-Lopez", modifyList(cfg0, list(c_mean = list(m = al_knots("m"), f = al_knots("f")), sd_c = 0.5))))
names(fits) <- map_chr(fits, "label")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# summaries ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
draw <- \(mean, cov, n = 2000) sweep(matrix(rnorm(n * length(mean)), n) %*% chol(cov), 2, mean, "+")
nat <- function(name, v) if (str_starts(name, "logit")) plogis(v) else if (str_starts(name, "log")) exp(v) else v

pars <- imap_dfr(fits, \(f, label) {
  d <- draw(f$par, f$cov); d0 <- draw(c(f$cfg$c_mean$m, f$cfg$c_mean$f, rep(1, 2 * np), rep(log(k0), 2), log(0.04)), f$cov0)
  map_dfr(seq_len(npar), \(i) tibble(
    fit = label, parameter = par_names[i],
    prior = nat(par_names[i], median(d0[, i])), prior_lo = nat(par_names[i], quantile(d0[, i], 0.025)), prior_hi = nat(par_names[i], quantile(d0[, i], 0.975)),
    post = nat(par_names[i], f$par[i]), post_lo = nat(par_names[i], quantile(d[, i], 0.025)), post_hi = nat(par_names[i], quantile(d[, i], 0.975)),
    sd_ratio = sqrt(f$cov[i, i] / f$cov0[i, i])))
})
write_csv(pars, "output/tables/reconstruction_parameters.csv")

cat("\nposterior sd / prior sd by block (1 = the censuses add nothing to the prior), principal fit:\n")
print(pars |> filter(fit == "principal") |> mutate(block = str_extract(parameter, "^[a-z ]+[a-z]")) |>
        summarise(min = round(min(sd_ratio), 2), median = round(median(sd_ratio), 2), max = round(max(sd_ratio), 2), .by = block) |> as.data.frame())

comp <- imap_dfr(fits, \(f, label) {
  d <- draw(f$par, f$cov)
  map_dfr(sexes, \(s) {
    cc <- apply(d[, ix[[paste0("lc_", s)]]], 1, annual_c)
    tibble(fit = label, sex = s, year = years, completeness = annual_c(f$par[ix[[paste0("lc_", s)]]]),
           lo = apply(cc, 1, quantile, 0.025), hi = apply(cc, 1, quantile, 0.975))
  })
})
prior_c <- { d0 <- draw(c(cfg0$c_mean$m, cfg0$c_mean$f, rep(1, 2 * np), rep(log(k0), 2), log(0.04)), fits$principal$cov0)
  cc <- apply(d0[, ix$lc_m], 1, annual_c); tibble(year = years, lo = apply(cc, 1, quantile, 0.025), hi = apply(cc, 1, quantile, 0.975)) }
write_csv(comp, "output/tables/reconstruction_completeness_annual.csv")

cat("\ncompleteness of the registered deaths at ages 5+, posterior mode [95 % interval], principal fit:\n")
print(comp |> filter(fit == "principal", year %in% knots) |>
        transmute(year, sex, c = sprintf("%.2f [%.2f-%.2f]", completeness, lo, hi)) |> pivot_wider(names_from = sex, values_from = c) |> as.data.frame())
cat("\nposterior mode by fit, men:\n")
print(comp |> filter(sex == "m", year %in% knots) |> transmute(year, fit, c = round(completeness, 2)) |> pivot_wider(names_from = fit, values_from = c) |> as.data.frame())
cat("\ncoverage and migration multipliers, principal fit (prior -> posterior [95 %]):\n")
print(pars |> filter(fit == "principal", str_detect(parameter, "kappa|^g ")) |>
        transmute(parameter, prior = round(prior, 3), post = sprintf("%.3f [%.3f-%.3f]", post, post_lo, post_hi), sd_ratio = round(sd_ratio, 2)) |> as.data.frame())
cat("\nsigma (sd of the log census counts around the fit), by fit:\n")
print(pars |> filter(parameter == "log sigma") |> transmute(fit, sigma = round(post, 4)) |> as.data.frame())

# fit to the censuses at the posterior mode
u <- unpack(fits$principal$par)
E <- at_census(project(u$c, u$g))
fitc <- map_dfr(sexes, \(s) as_tibble(sweep(E[[s]], 2, exp(u$lk[[s]]), "*"), .name_repair = ~ as.character(censuses$census)) |>
                  mutate(age = grp_lo, sex = s) |> pivot_longer(-c(age, sex), names_to = "census", values_to = "fitted", names_transform = as.integer)) |>
  inner_join(cen |> select(census, sex, age, enumerated), by = c("census", "sex", "age")) |>
  mutate(ratio = enumerated / fitted, in_likelihood = age >= 5 & age <= 65)
write_csv(fitc, "output/tables/reconstruction_census_fit.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#52514e"
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))

ref <- read_csv("output/tables/completeness_compared_annual.csv", show_col_types = FALSE) |>
  filter(method %in% c("Implícita en WPP 2024", "Adair-Lopez, modelo 1"), scope == "todas las edades" | method == "Adair-Lopez, modelo 1") |>
  transmute(year, sex, series = if_else(method == "Implícita en WPP 2024", "Implícita en WPP 2024 (todas las edades)", "Adair-Lopez, modelo 1"), completeness)
fit_cols <- c("principal" = "#2a78d6", "migración fija en WPP" = "#1baf7a", "cobertura censal amplia" = "#eda100", "previa Adair-Lopez" = "#e87ba4")
ggplot() +
  geom_ribbon(data = crossing(prior_c, sex = lab_sex(sexes)), aes(year, ymin = lo, ymax = hi), fill = "grey50", alpha = 0.10) +
  geom_ribbon(data = comp |> filter(fit == "principal") |> mutate(sex = lab_sex(sex)), aes(year, ymin = lo, ymax = hi), fill = "#2a78d6", alpha = 0.22) +
  geom_line(data = ref |> mutate(sex = lab_sex(sex)), aes(year, completeness, linetype = series), colour = "#0b0b0b", linewidth = 0.5) +
  geom_line(data = comp |> mutate(sex = lab_sex(sex), fit = factor(fit, names(fit_cols))), aes(year, completeness, col = fit), linewidth = 0.9) +
  facet_wrap(~sex) +
  scale_color_manual(values = fit_cols) +
  scale_linetype_manual(values = c("Implícita en WPP 2024 (todas las edades)" = "solid", "Adair-Lopez, modelo 1" = "22")) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), breaks = seq(0, 1, 0.1)) +
  coord_cartesian(ylim = c(0.3, 1)) +
  labs(title = "Completitud del registro de defunciones (5 años y más) estimada por la reconstrucción",
       subtitle = "Líneas de color: moda posterior de cada ajuste. Banda azul: intervalo de 95 % del ajuste principal. Banda gris: intervalo de 95 % de la distribución previa",
       x = NULL, y = "Completitud", col = "Ajuste", linetype = "Referencia") +
  base + guides(col = guide_legend(nrow = 2), linetype = guide_legend(nrow = 2))
ggsave("figures/05_reconstruction/estimation_completeness.png", w = 13, h = 7, bg = "white")

pp <- pars |> filter(fit == "principal", str_detect(parameter, "kappa|^g ")) |>
  mutate(block = if_else(str_detect(parameter, "kappa"), "Cobertura de cada censo", "Multiplicador de la migración neta de WPP, por periodo"),
         sex = lab_sex(str_extract(parameter, "(?<= )[mf](?= )")), x = str_extract(parameter, "[0-9]{4}"))
bind_rows(pp |> transmute(block, sex, x, kind = "Previa", mid = prior, lo = prior_lo, hi = prior_hi),
          pp |> transmute(block, sex, x, kind = "Posterior", mid = post, lo = post_lo, hi = post_hi)) |>
  mutate(kind = factor(kind, c("Previa", "Posterior"))) |>
  ggplot(aes(x, mid, ymin = lo, ymax = hi, col = kind)) +
  geom_hline(yintercept = 1, colour = "grey55", linewidth = 0.3) +
  geom_pointrange(position = position_dodge(width = 0.5), linewidth = 0.6, size = 0.3) +
  facet_grid(block ~ sex, scales = "free") +
  scale_color_manual(values = c(Previa = "#8a8983", Posterior = "#2a78d6")) +
  labs(title = "Cobertura censal y migración: distribución previa y posterior (ajuste principal)",
       subtitle = "Punto: mediana previa o moda posterior; barra: intervalo de 95 %. Si la posterior no se estrecha frente a la previa, los censos no informan ese parámetro",
       x = NULL, y = NULL, col = NULL) +
  base
ggsave("figures/05_reconstruction/estimation_parameters.png", w = 13, h = 7.5, bg = "white")

age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, TRUE ~ a + 2.5)
fitc |>
  mutate(sex = lab_sex(sex), x = age_mid(age)) |>
  ggplot(aes(x, ratio, col = sex)) +
  annotate("rect", xmin = 5, xmax = 70, ymin = -Inf, ymax = Inf, fill = "grey50", alpha = 0.07) +
  geom_hline(yintercept = 1, colour = "grey55", linewidth = 0.3) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~census, nrow = 2) +
  scale_color_manual(values = c(Hombres = "#2a78d6", Mujeres = "#eb6834")) +
  coord_cartesian(ylim = c(0.6, 1.6)) +
  labs(title = "Ajuste a los censos: población enumerada / población ajustada (ajuste principal, moda posterior)",
       subtitle = "Franja gris: edades que entran en la verosimilitud (5-69). Fuera de ella se ve el error censal no modelado: subenumeración de niños y exageración de la edad",
       x = "Edad", y = "Enumerada / ajustada", col = NULL) +
  base
ggsave("figures/05_reconstruction/estimation_census_fit.png", w = 13, h = 7, bg = "white")
