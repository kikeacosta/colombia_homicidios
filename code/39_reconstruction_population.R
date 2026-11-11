# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 39. National reconstruction 1950-2023: population given our mortality
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 38 showed that the census age structures do not identify adult mortality,
# but do inform census coverage and migration. Here mortality is fixed at a
# series built from the deaths, and the cohort-component model estimates the
# population that is consistent with it and with the censuses.
#
# mortality (fixed), by variant
#   Propia         ages 5+: non-violent registered deaths / empirical
#                  completeness (Adair-Lopez model 1, 36) + violent deaths
#                  (with the MSE correction in 1985-2018, / completeness in
#                  other years); under five: WPP 2024 rates (placeholder
#                  until UN IGME is added). The adjusted deaths are counts,
#                  so their rates are recomputed on the estimated population
#                  (two rounds: fit, update exposures, refit)
#   WPP + MSE      WPP 2024 with its conflict replaced by the MSE (27)
#   Registradas    registered deaths, no adjustment (a lower bound of
#                  mortality, to see how far the population can move)
#
# estimated, with the priors of 38
#   g(period, sex)      multiplier of WPP's net migrants, N(1, 0.5)
#   kappa(census, sex)  census coverage, log-normal around DANE-based values
#   f(period)           multiplier of WPP's fertility rates, N(1, 0.05): the
#                       cohorts born after 1950 are most of the population
#   sigma               sd of the log census counts around the fit
# fixed: the WPP population of 1 January 1950 and WPP's age patterns of
#   fertility and migration.
# data: census counts by sex and age group 5-9 to 65-69, 1951-2018.
# estimation: posterior mode (BFGS) + Laplace approximation, 400 draws.
#
# output: output/tables/reconstruction_population_1jan_1950-2024.csv
#         output/tables/reconstruction_population_totals.csv
#         output/tables/reconstruction_population_parameters.csv
#         output/tables/reconstruction_mortality_summary.csv
#         figures/05_reconstruction/population_estimate.png
#         figures/05_reconstruction/population_parameters.png
#         figures/05_reconstruction/population_vs_wpp_age.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
set.seed(2026)

years <- 1950:2023; ny <- length(years)
ages <- 0:100; na <- length(ages)
sexes <- c("m", "f")
grp_lo <- c(0, 1, seq(5, 80, 5))
grp <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), 80))
gi <- match(grp(ages), grp_lo)
periods <- c(seq(1950, 2000, 10), 2010); np <- length(periods)
per_i <- findInterval(years, periods)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# inputs (as in 38) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
mat <- \(d, v, rows = "age") d |> select(year, all_of(c(rows, v))) |> pivot_wider(names_from = year, values_from = all_of(v)) |>
  arrange(.data[[rows]]) |> select(-all_of(rows)) |> as.matrix()
by_sex <- \(d, v) map(set_names(sexes), \(s) mat(filter(d, sex == s), v))

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

cen <- read_rds("data_inter/census_pop_age.rds") |> filter(census >= 1951) |> select(census, dec, sex, age, enumerated = pop)
censuses <- cen |> distinct(census, dec) |> arrange(census)
nc <- nrow(censuses)
fit_groups <- which(grp_lo >= 5 & grp_lo <= 65)
O <- map(set_names(sexes), \(s) cen |> filter(sex == s) |> select(census, age, enumerated) |>
           pivot_wider(names_from = census, values_from = enumerated) |> arrange(age) |> select(-age) |> as.matrix())

# mortality variants: ratio of each series' deaths to WPP's, by age group, year and sex
exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
c_al <- read_csv("output/tables/completeness_compared_annual.csv", show_col_types = FALSE) |>
  filter(method == "Adair-Lopez, modelo 1") |> select(year, sex, c_al = completeness)
violent <- read_csv("output/tables/deaths_by_cause_sex_age_1953-2023.csv", show_col_types = FALSE) |> select(year, sex, age, violent_reg)
ratios <-
  exp |>
  left_join(c_al, by = c("year", "sex")) |> left_join(violent, by = c("year", "sex", "age")) |>
  mutate(v = replace_na(violent_reg, 0), v_adj = if_else(year %in% 1985:2018, v + hom_excess + dsp, v / c_al),
         Propia = if_else(age < 5, 1, ((registered - v) / c_al + v_adj) / wpp_total),
         `WPP + MSE` = expected / wpp_total,
         Registradas = registered / wpp_total)
variants <- c("Propia", "WPP + MSE", "Registradas")
mult0 <- map(set_names(variants), \(v) map(by_sex(ratios, v), \(r) r[gi, ]))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# engine ====
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
# L: list(m, f) of Lx matrices; g: list(m, f) annual migration multipliers; fm: annual fertility multiplier
project <- function(L, g, fm) {
  G <- map(set_names(sexes), \(s) { m <- sweep(M_w[[s]], 2, g[[s]], "*"); m[1, ] <- M_w[[s]][1, ]; m })
  Pm <- Pf <- matrix(0, na, ny + 1)
  Pm[, 1] <- pop0$m; Pf[, 1] <- pop0$f
  for (j in seq_len(ny)) {
    m2 <- survive(Pm[, j], L$m[, j]); f2 <- survive(Pf[, j], L$f[, j])
    b <- fm[j] * sum(F_w[, j] * (Pf[, j] + f2) / 2)
    f2[1] <- b / (1 + srb[j]) * L$f[1, j]; m2[1] <- b * srb[j] / (1 + srb[j]) * L$m[1, j]
    Pm[, j + 1] <- pmax(m2 + G$m[, j], 1); Pf[, j + 1] <- pmax(f2 + G$f[, j], 1)
  }
  list(m = Pm, f = Pf)
}
cj <- floor(censuses$dec) - years[1] + 1; cw <- censuses$dec - floor(censuses$dec)
at_census <- function(P) map(P, \(p) rowsum(sweep(p[, cj], 2, 1 - cw, "*") + sweep(p[, cj + 1], 2, cw, "*"), gi))
life_tables <- \(mult) map(set_names(sexes), \(s) Lx_mat(mx_w[[s]] * mult[[s]], ax_w[[s]]))
mid <- \(p) (p[, 1:ny] + p[, 2:(ny + 1)]) / 2   # mid-year population = person-years

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# parameters, priors, posterior ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ix <- list(g_m = 1:np, g_f = np + 1:np, lk_m = 2 * np + 1:nc, lk_f = 2 * np + nc + 1:nc, f = 2 * np + 2 * nc + 1:np, ls = 3 * np + 2 * nc + 1)
npar <- ix$ls
par_names <- c(paste0("g ", rep(sexes, each = np), " ", periods), paste0("log kappa ", rep(sexes, each = nc), " ", censuses$census),
               paste0("f t ", periods), "log sigma")
k0 <- c(0.95, 0.97, 1.00, 0.91, 0.94, 0.985, 0.915)
sd_k <- c(0.05, 0.05, 0.03, 0.03, 0.03, 0.03, 0.03)
prior_mean <- c(rep(1, 2 * np), rep(log(k0), 2), rep(1, np), log(0.04))
prior_sd <- c(rep(0.5, 2 * np), rep(sd_k, 2), rep(0.05, np), 0.5)

unpack <- \(th) list(g = list(m = th[ix$g_m][per_i], f = th[ix$g_f][per_i]), lk = list(m = th[ix$lk_m], f = th[ix$lk_f]),
                     fm = th[ix$f][per_i], sigma = exp(th[ix$ls]))
neg_post <- function(th, L) {
  u <- unpack(th)
  E <- at_census(project(L, u$g, u$fm))
  ll <- sum(map_dbl(sexes, \(s) sum(dnorm(log(O[[s]][fit_groups, ]), sweep(log(E[[s]][fit_groups, ]), 2, u$lk[[s]], "+"), u$sigma, log = TRUE))))
  -(ll + sum(dnorm(th, prior_mean, prior_sd, log = TRUE)))
}
fit_model <- function(label, mult, start = prior_mean) {
  t1 <- Sys.time()
  L <- life_tables(mult)
  o <- optim(start, neg_post, L = L, method = "BFGS", control = list(maxit = 400, reltol = 1e-10))
  H <- optimHess(o$par, neg_post, L = L)
  ev <- min(eigen((H + t(H)) / 2, symmetric = TRUE, only.values = TRUE)$values)
  cat(sprintf("%-22s convergence %d, -log posterior %.1f, smallest Hessian eigenvalue %.3g, sigma %.3f, %.0f s\n",
              label, o$convergence, o$value, ev, exp(o$par[ix$ls]), as.numeric(difftime(Sys.time(), t1, units = "secs"))))
  u <- unpack(o$par)
  list(label = label, par = o$par, cov = solve((H + t(H)) / 2), L = L, mult = mult, P = project(L, u$g, u$fm))
}

# own mortality: rates recomputed on the estimated exposures, two rounds
exposure_ratio <- \(P) map(set_names(sexes), \(s) { r <- (rowsum(mid(P_w[[s]]), gi) / rowsum(mid(P[[s]]), gi))[gi, ]; r[1:5, ] <- 1; r })
old_age <- \(P, lo) sum(map_dbl(sexes, \(s) sum(P[[s]][ages >= lo, "2018" == c(years, 2024)]))) / sum(map_dbl(sexes, \(s) sum(P_w[[s]][ages >= lo, "2018" == c(years, 2024)])))
fit_own <- fit_model("Propia, ronda 1", mult0$Propia)
cat(sprintf("   2018, relative to WPP: population 60+ %.3f, 80+ %.3f\n", old_age(fit_own$P, 60), old_age(fit_own$P, 80)))
# rates consistent with the death counts for given parameters: iterate the
# projection until the exposures stop moving (the open group 80+ is the slow
# one: its stock keeps growing while the deaths are fixed)
fixed_point <- function(par, mult) {
  u <- unpack(par)
  for (i in 1:300) {
    P <- project(life_tables(mult), u$g, u$fm)
    er <- exposure_ratio(P)
    new <- map(set_names(sexes), \(s) mult0$Propia[[s]] * er[[s]])
    d <- max(map_dbl(sexes, \(s) max(abs(new[[s]] / mult[[s]] - 1))))
    mult <- new
    if (d < 1e-5) break
  }
  cat("   exposure fixed point reached in", i, "projections\n")
  mult
}
for (k in 2:5) {
  prev <- fit_own$P
  fit_own <- fit_model(paste("Propia, ronda", k), fixed_point(fit_own$par, fit_own$mult), start = fit_own$par)
  # convergence on the 18 age groups (single very old ages hold a handful of people)
  chg <- map_dbl(sexes, \(s) max(abs(rowsum(fit_own$P[[s]], gi) / rowsum(prev[[s]], gi) - 1)))
  chg79 <- map_dbl(sexes, \(s) max(abs(rowsum(fit_own$P[[s]], gi)[-18, ] / rowsum(prev[[s]], gi)[-18, ] - 1)))
  cat(sprintf("   largest change from the previous round by age group and year: %.4f (below 80: %.4f); 2018 relative to WPP: 60+ %.3f, 80+ %.3f\n",
              max(chg), max(chg79), old_age(fit_own$P, 60), old_age(fit_own$P, 80)))
  if (max(chg) < 0.002) break
}
fits <- list(Propia = fit_own, `WPP + MSE` = fit_model("WPP + MSE", mult0$`WPP + MSE`), Registradas = fit_model("Registradas", mult0$Registradas))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# summaries ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
yy <- c(years, 2024)
long <- \(m, v) as_tibble(m, .name_repair = ~ as.character(yy[seq_len(ncol(m))])) |> mutate(age = ages) |>
  pivot_longer(-age, names_to = "year", values_to = v, names_transform = as.integer)
pop_own <- map_dfr(sexes, \(s) long(fits$Propia$P[[s]], "pop") |> mutate(sex = s)) |>
  left_join(pop_wpp |> rename(pop_wpp = pop), by = c("year", "sex", "age")) |> select(year, sex, age, pop, pop_wpp)
write_csv(pop_own |> mutate(pop = round(pop, 1)), "output/tables/reconstruction_population_1jan_1950-2024.csv")

# draws: totals by sex and broad age
nd <- 400
draws <- sweep(matrix(rnorm(nd * npar), nd) %*% chol(fits$Propia$cov), 2, fits$Propia$par, "+")
band3 <- cut(ages, c(-1, 14, 59, Inf), c("0-14", "15-59", "60+"))
tot_draw <- map(seq_len(nd), \(i) { u <- unpack(draws[i, ]); P <- project(fits$Propia$L, u$g, u$fm); map(P, \(p) rowsum(p, band3)) })
qtot <- function(sel) {   # sel: function(draw) -> vector over years
  a <- sapply(tot_draw, sel)
  tibble(lo = apply(a, 1, quantile, 0.025), hi = apply(a, 1, quantile, 0.975))
}
tot_of <- \(P) colSums(P$m) + colSums(P$f)
totals <- bind_rows(
  imap_dfr(fits, \(f, v) tibble(variant = v, year = yy, pop = tot_of(f$P))),
  tibble(variant = "WPP 2024", year = yy, pop = tot_of(P_w))) |>
  left_join(bind_cols(tibble(variant = "Propia", year = yy), qtot(\(d) colSums(d$m) + colSums(d$f))), by = c("variant", "year"))
write_csv(totals, "output/tables/reconstruction_population_totals.csv")

cat("\npopulation at 1 January, millions:\n")
print(totals |> filter(year %in% c(1951, 1964, 1973, 1985, 1993, 2005, 2018, 2024)) |>
        mutate(pop = if_else(is.na(lo), sprintf("%.2f", pop / 1e6), sprintf("%.2f [%.2f-%.2f]", pop / 1e6, lo / 1e6, hi / 1e6))) |>
        select(variant, year, pop) |> pivot_wider(names_from = year, values_from = pop) |> as.data.frame())

sdr <- sqrt(diag(fits$Propia$cov)) / prior_sd
nat <- \(name, v) if (str_starts(name, "log")) exp(v) else v
pars <- map_dfr(seq_len(npar), \(i) tibble(
  parameter = par_names[i],
  prior = nat(par_names[i], prior_mean[i]), prior_lo = nat(par_names[i], prior_mean[i] - 1.96 * prior_sd[i]), prior_hi = nat(par_names[i], prior_mean[i] + 1.96 * prior_sd[i]),
  post = nat(par_names[i], fits$Propia$par[i]), post_lo = nat(par_names[i], quantile(draws[, i], 0.025)), post_hi = nat(par_names[i], quantile(draws[, i], 0.975)),
  sd_ratio = sdr[i], post_wpp_mse = nat(par_names[i], fits$`WPP + MSE`$par[i]), post_registradas = nat(par_names[i], fits$Registradas$par[i])))
write_csv(pars, "output/tables/reconstruction_population_parameters.csv")
cat("\nparameters, own mortality (prior -> posterior mode [95 %]; sd ratio; mode under the other mortality variants):\n")
print(pars |> transmute(parameter, prior = round(prior, 3), post = sprintf("%.3f [%.3f-%.3f]", post, post_lo, post_hi), sd_ratio = round(sd_ratio, 2),
                        wpp_mse = round(post_wpp_mse, 3), registradas = round(post_registradas, 3)) |> as.data.frame())

# net migration and births implied, by decade
u <- unpack(fits$Propia$par)
net <- map_dfr(sexes, \(s) { m <- sweep(M_w[[s]], 2, u$g[[s]], "*"); m[1, ] <- M_w[[s]][1, ]
  tibble(year = years, sex = s, own = colSums(m), wpp = colSums(M_w[[s]])) })
cat("\nnet migration, thousands per year, both sexes, by decade:\n")
print(net |> mutate(decade = 10 * (year %/% 10)) |> summarise(own = round(sum(own) / n_distinct(year) / 1e3, 1), wpp = round(sum(wpp) / n_distinct(year) / 1e3, 1), .by = decade) |> as.data.frame())

# mortality summary on the estimated population: e0 and deaths
e0 <- \(L) map(L, colSums)
mort <- map_dfr(sexes, \(s) {
  Dw <- mx_w[[s]] * mid(P_w[[s]]); Do <- mx_w[[s]] * fits$Propia$mult[[s]] * mid(fits$Propia$P[[s]])
  tibble(year = years, sex = s, e0_own = e0(fits$Propia$L)[[s]], e0_wpp = e0(L_w)[[s]], deaths_own = colSums(Do), deaths_wpp = colSums(Dw),
         pop_mid_own = colSums(mid(fits$Propia$P[[s]])), pop_mid_wpp = colSums(mid(P_w[[s]])))
})
write_csv(mort, "output/tables/reconstruction_mortality_summary.csv")
cat("\nlife expectancy at birth and deaths (thousands), own estimate against WPP:\n")
print(mort |> filter(year %in% c(1950, 1960, 1970, 1980, 1990, 2000, 2010, 2018)) |>
        transmute(year, sex, e0_own = round(e0_own, 1), e0_wpp = round(e0_wpp, 1), deaths_own = round(deaths_own / 1e3, 1), deaths_wpp = round(deaths_wpp / 1e3, 1)) |>
        arrange(sex, year) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#52514e"
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))
var_cols <- c("Propia" = "#2a78d6", "WPP + MSE" = "#eb6834", "Registradas" = "#8a8983", "WPP 2024" = "#0b0b0b")

kap <- (exp(fits$Propia$par[ix$lk_m]) * colSums(O$m) + exp(fits$Propia$par[ix$lk_f]) * colSums(O$f)) / (colSums(O$m) + colSums(O$f))
cen_pts <- tibble(year = censuses$dec, Enumerada = (colSums(O$m) + colSums(O$f)) / 1e6,
                  `Enumerada / cobertura estimada` = (colSums(O$m) / exp(fits$Propia$par[ix$lk_m]) + colSums(O$f) / exp(fits$Propia$par[ix$lk_f])) / 1e6) |>
  pivot_longer(-year, names_to = "kind", values_to = "pop")
pa <-
  ggplot(totals |> mutate(variant = factor(variant, names(var_cols))), aes(year, pop / 1e6)) +
  geom_ribbon(data = \(d) filter(d, variant == "Propia"), aes(ymin = lo / 1e6, ymax = hi / 1e6), fill = "#2a78d6", alpha = 0.2) +
  geom_line(aes(col = variant, linewidth = variant %in% c("Propia", "WPP 2024"))) +
  geom_point(data = cen_pts, aes(year, pop, shape = kind), size = 2.2, colour = "#0b0b0b") +
  scale_color_manual(values = var_cols) +
  scale_linewidth_manual(values = c(`TRUE` = 0.9, `FALSE` = 0.5), guide = "none") +
  scale_shape_manual(values = c(Enumerada = 16, `Enumerada / cobertura estimada` = 1)) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "a. Población total al 1 de enero, millones",
       subtitle = "Líneas: reconstrucción con cada serie de mortalidad y WPP 2024. Banda: intervalo de 95 % (mortalidad propia). Puntos: censos",
       x = NULL, y = "Millones", col = NULL, shape = NULL) +
  base + guides(col = guide_legend(nrow = 2), shape = guide_legend(nrow = 2))
rel <- map_dfr(sexes, \(s) {
  o <- rowsum(fits$Propia$P[[s]], band3); w <- rowsum(P_w[[s]], band3)
  a <- sapply(tot_draw, \(d) as.vector(t(d[[s]] / w)))   # rows: band x year
  expand_grid(band = levels(band3), year = yy) |>
    mutate(sex = s, rel = as.vector(t(o / w)), lo = apply(a, 1, quantile, 0.025), hi = apply(a, 1, quantile, 0.975))
})
pb <-
  rel |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, 100 * (rel - 1), col = band, fill = band)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_ribbon(aes(ymin = 100 * (lo - 1), ymax = 100 * (hi - 1)), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("0-14" = "#1baf7a", "15-59" = "#2a78d6", "60+" = "#eb6834"), aesthetics = c("colour", "fill")) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "b. Diferencia de la población estimada (mortalidad propia) frente a WPP 2024, por grupo de edad",
       subtitle = "Porcentaje; banda: intervalo de 95 %", x = NULL, y = "%", col = "Edad", fill = "Edad") +
  base
ggsave("figures/05_reconstruction/population_estimate.png", ggpubr::ggarrange(pa, pb, ncol = 1, heights = c(1.1, 1)), w = 13, h = 11, bg = "white")

pp <- pars |> filter(parameter != "log sigma") |>
  mutate(panel = case_when(str_detect(parameter, "kappa m") ~ "Cobertura censal, hombres", str_detect(parameter, "kappa f") ~ "Cobertura censal, mujeres",
                           str_detect(parameter, "^g m") ~ "Multiplicador de la migración WPP, hombres", str_detect(parameter, "^g f") ~ "Multiplicador de la migración WPP, mujeres",
                           TRUE ~ "Multiplicador de la fecundidad WPP"),
         x = str_extract(parameter, "[0-9]{4}"))
bind_rows(pp |> transmute(panel, x, kind = "Previa", mid = prior, lo = prior_lo, hi = prior_hi),
          pp |> transmute(panel, x, kind = "Posterior", mid = post, lo = post_lo, hi = post_hi)) |>
  mutate(kind = factor(kind, c("Previa", "Posterior")), panel = factor(panel, unique(pp$panel)[c(3, 4, 1, 2, 5)])) |>
  ggplot(aes(x, mid, ymin = lo, ymax = hi, col = kind)) +
  geom_hline(yintercept = 1, colour = "grey55", linewidth = 0.3) +
  geom_pointrange(position = position_dodge(width = 0.5), linewidth = 0.6, size = 0.3) +
  facet_wrap(~panel, scales = "free", nrow = 3) +
  scale_color_manual(values = c(Previa = "#8a8983", Posterior = "#2a78d6")) +
  labs(title = "Cobertura censal, migración y fecundidad: distribución previa y posterior (mortalidad propia)",
       subtitle = "Punto: media previa o moda posterior; barra: intervalo de 95 %", x = NULL, y = NULL, col = NULL) +
  base
ggsave("figures/05_reconstruction/population_parameters.png", w = 13, h = 10, bg = "white")

pop_own |>
  filter(age < 100, year <= 2023) |>
  mutate(pct = 100 * (pop / pop_wpp - 1), sex = lab_sex(sex)) |>
  ggplot(aes(year, age, fill = pct)) +
  geom_raster() +
  facet_wrap(~sex) +
  scale_fill_gradient2(low = "#2a78d6", mid = "#f0efec", high = "#eb6834", midpoint = 0, limits = c(-15, 15), oob = scales::squish,
                       labels = \(x) paste0(ifelse(x > 0, "+", ""), x, " %")) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, 100, 20), expand = c(0, 0)) +
  labs(title = "Población estimada (mortalidad propia) frente a WPP 2024, por edad simple y año",
       subtitle = "Naranja: más población que WPP; azul: menos (escala cortada en ±15 %)", x = NULL, y = "Edad", fill = NULL) +
  base + theme(legend.key.width = unit(1.6, "cm"), panel.grid = element_blank())
ggsave("figures/05_reconstruction/population_vs_wpp_age.png", w = 13, h = 6.5, bg = "white")
