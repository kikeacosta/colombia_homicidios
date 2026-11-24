# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 87. Spain 1926-1946: the state-space model of 60/70, with the violent
#     causes registered in 1936-1940 as observations
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 86 found the state-space model best or tied with the other two methods,
# and the direct estimator of 80 unreliable where violence weighs little.
# Here the state-space model runs on Spain.
#
# states, by province k and year t (random walks):
#   eta   logit of the share of violent deaths in registered deaths
#   u     deviation of the province's non-violent log sex ratio from the
#         national one
# the national non-violent log sex ratio rho_t is the pre-war (1926-1935)
# national mean, carried through the war (its linear trend as a
# sensitivity, SPAIN_TREND=1): the same assumption as 80, but each province
# can drift away from it through u, as slowly as it did before the war.
# observations:
#   log(Dm / Df)        = g(rho_t + u, eta) + e      every year, pi = 0.95
#   logit(V_reg / D)    = eta + beta_p + e           1936-1939 and 1940
#                         (registered homicide + war + executions, 83).
#                         beta_p < 0 is how much of the violence the registry
#                         holds, one value for 1936-1939 and one for 1940,
#                         estimated: the registry is a floor, not the truth.
#   logit(0.003)        = eta + e, sd 1               1926-1935: a weak anchor
#                         at the pre-war level of homicide in Spain (about
#                         1,000-1,200 a year among 400,000 deaths); the
#                         causes of those years are not transcribed
# 1941-1942 have homicide only (abridged list) and are not used as
# observations: violence there comes from the sex ratio alone, as in 80.
# eta moves with sd s_eta_war from 1936 on and with a fixed 0.1 before.
# s_u and s_0 by maximum likelihood on 1926-1935 (see below why), then
# s_eta_war, s_reg, beta_3639 and beta_40 on all years; extended Kalman
# filter and smoother by province.
#
# input    data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv
#          output/tables/intl_spain_causes_check.csv (83)
#          output/tables/intl_spain_excess_male_1936-1946.csv (80)
# output   output/tables/intl_spain_state_space.csv
#          output/tables/intl_spain_state_space_national.csv
#          output/tables/intl_spain_state_space_parameters.csv
#          figures/09_international/spain_state_space.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 220)
pi_m <- 0.95
v_pre <- 0.003
war <- 1936:1946   # years where eta moves with s_eta_war (from 1936 on)
s_eta_pre <- 0.1   # 1927-1935: fixed; the anchor there is a constant, so it cannot be estimated
z90 <- qnorm(0.95)
# national non-violent ratio: the pre-war mean (main, the assumption of 80)
# or the pre-war mean and its linear trend (sensitivity: SPAIN_TREND=1)
trend <- Sys.getenv("SPAIN_TREND", "0") == "1"
sfx <- if (trend) "_trend" else ""

sp <- read_csv("data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character()))
w <- sp |> filter(!is.na(province_code), !grepl("+", province_code, fixed = TRUE)) |>
  select(year, province_code, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths)
lab <- sp |> filter(!is.na(province_code), year == max(year)) |> distinct(province_code, province)
pv <- sort(unique(w$province_code)); yrs <- 1926:1946
reg <- read_csv("output/tables/intl_spain_causes_check.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(year <= 1940) |> select(year, province_code, violent_reg)

# national non-violent log sex ratio: pre-war level and trend
nat <- w |> filter(year <= 1935) |> summarise(m = sum(male), f = sum(female), .by = year) |>
  mutate(rho = log((m - pi_m * v_pre * (m + f)) / (f - (1 - pi_m) * v_pre * (m + f))))
fr <- lm(rho ~ I(year - 1930.5), data = nat)
cat("national pre-war non-violent log sex ratio:", round(coef(fr)[1], 4), "| trend per year", round(coef(fr)[2], 5), "\n")

md <- expand_grid(province_code = pv, year = yrs) |>
  left_join(w, by = c("province_code", "year")) |>
  left_join(reg, by = c("year", "province_code")) |>
  mutate(rho = if (trend) predict(fr, newdata = tibble(year = year)) else mean(nat$rho),
         y_sr = ifelse(!is.na(male) & male > 0 & female > 0, log(male / female), NA), q_sr = 1 / male + 1 / female,
         y_reg = ifelse(!is.na(violent_reg) & violent_reg > 0, qlogis(violent_reg / total), NA),
         q_reg = 1 / violent_reg + 1 / (total - violent_reg),
         per = case_when(year %in% 1936:1939 ~ 1L, year == 1940 ~ 2L, TRUE ~ NA_integer_),
         y_pre = ifelse(year <= 1935 & !is.na(total), qlogis(v_pre), NA)) |>
  arrange(province_code, year)

g_sr <- function(delta, eta) {
  h <- plogis(eta); ed <- exp(delta)
  log((1 - h) * ed + h * pi_m * (1 + ed)) - log((1 - h) + h * (1 - pi_m) * (1 + ed))
}

kf <- function(z, par, smooth = FALSE) {
  s_ep <- par[1]; s_ew <- par[2]; s_u <- par[3]; s_0 <- par[4]; s_r <- par[5]; beta <- par[6:7]
  n <- nrow(z); x <- c(qlogis(v_pre), 0); P <- diag(c(1, 0.3)^2); ll <- 0
  if (smooth) { xp <- xf <- matrix(NA, n, 2); Pp <- Pf <- array(NA, c(2, 2, n)) }
  upd <- function(H, innov, R) {
    S <- drop(H %*% P %*% H) + R; K <- drop(P %*% H) / S
    x <<- x + K * innov; P <<- P - tcrossprod(K, drop(H %*% P)); ll <<- ll - 0.5 * (log(2 * pi * S) + innov^2 / S)
  }
  for (t in seq_len(n)) {
    if (t > 1) P <- P + diag(c(ifelse(z$year[t] %in% war, s_ew, s_ep)^2, s_u^2))
    if (smooth) { xp[t, ] <- x; Pp[, , t] <- P }
    if (!is.na(z$y_pre[t])) upd(c(1, 0), z$y_pre[t] - x[1], 1)
    if (!is.na(z$y_reg[t])) upd(c(1, 0), z$y_reg[t] - x[1] - beta[z$per[t]], s_r^2 + z$q_reg[t])
    if (!is.na(z$y_sr[t])) {
      # iterated extended Kalman update: the identity is relinearised at the
      # updated state until it settles. with one linearisation at the prior,
      # a large jump of the sex ratio (Cadiz 1941, typhus) overshot: the
      # slope of g in eta is small where violence is low, so the filter
      # moved eta far past what the identity allows
      R <- s_0^2 + z$q_sr[t]; xi <- x
      for (it in 1:20) {
        d0 <- z$rho[t] + xi[2]; g0 <- g_sr(d0, xi[1])
        H <- c((g_sr(d0, xi[1] + 1e-5) - g0) / 1e-5, (g_sr(d0 + 1e-5, xi[1]) - g0) / 1e-5)
        innov <- z$y_sr[t] - g0 - sum(H * (x - xi))
        S <- drop(H %*% P %*% H) + R; K <- drop(P %*% H) / S
        xn <- x + K * innov
        if (any(!is.finite(xn))) { if (smooth) stop("filter diverged") else return(-1e10) }
        done <- max(abs(xn - xi)) < 1e-6; xi <- xn
        if (done) break
      }
      x <- xi; P <- P - tcrossprod(K, drop(H %*% P)); ll <- ll - 0.5 * (log(2 * pi * S) + innov^2 / S)
    }
    if (smooth) { xf[t, ] <- x; Pf[, , t] <- P }
  }
  if (!smooth) return(ll)
  xs <- xf; Ps <- Pf
  for (t in rev(seq_len(n - 1))) {
    C <- Pf[, , t] %*% solve(Pp[, , t + 1])
    xs[t, ] <- xf[t, ] + drop(C %*% (xs[t + 1, ] - xp[t + 1, ]))
    Ps[, , t] <- Pf[, , t] + C %*% (Ps[, , t + 1] - Pp[, , t + 1]) %*% t(C)
  }
  data.frame(eta = xs[, 1], sd_eta = sqrt(pmax(Ps[1, 1, ], 0)), u = xs[, 2], sd_u = sqrt(pmax(Ps[2, 2, ], 0)))
}
parts <- split(md, md$province_code)
# two stages. a first fit with every parameter free let u (the non-violent
# ratio of each province) move fast in the war and absorb the male excess,
# so that eta followed the registry (correlation 0.999) and the registry
# came out as holding 94 % of the violence. the speed of u is therefore
# learned where violence is known to be small, 1926-1935, and then held:
# the assumption of 80, that the non-violent ratio moves in the war no
# faster than in peace.
# stage 1: s_u and s_0 from 1926-1935
parts_pre <- split(filter(md, year <= 1935), filter(md, year <= 1935)$province_code)
nll_pre <- function(lp) -sum(vapply(parts_pre, kf, numeric(1), par = c(s_eta_pre, 1, exp(lp), 1, 0, 0)))
o1 <- optim(log(c(0.01, 0.02)), nll_pre, method = "BFGS")
s_u <- exp(o1$par[1]); s_0 <- exp(o1$par[2])
cat("stage 1 (1926-1935): s_u", round(s_u, 4), "| s_0", round(s_0, 4), "\n")
# stage 2: the rest, from all years
expand <- function(lp) c(s_eta_pre, exp(lp[1]), s_u, s_0, exp(lp[2]), lp[3:4])
nll <- function(lp) -sum(vapply(parts, kf, numeric(1), par = expand(lp)))
best <- NULL
for (s in list(c(log(1), log(0.3), -0.3, -0.5), c(log(0.6), log(0.15), -0.1, -0.1))) {
  o <- optim(s, nll, method = "BFGS", control = list(maxit = 500))
  if (is.null(best) || o$value < best$value) best <- o
}
par <- setNames(expand(best$par), c("s_eta_pre", "s_eta_war", "s_u", "s_0", "s_reg", "beta_1936_1939", "beta_1940"))
cat("loglik", round(-best$value, 1), "| convergence", best$convergence, "\n"); print(round(par, 4))
cat("share of violence the registry holds (exp(beta), on the odds scale): 1936-1939", round(exp(par[6]), 2), "| 1940", round(exp(par[7]), 2), "\n")
write_csv(tibble(term = names(par), estimate = par, loglik = -best$value, convergence = best$convergence),
          paste0("output/tables/intl_spain_state_space_parameters", sfx, ".csv"))

sm <- bind_rows(lapply(parts, function(z) cbind(z, kf(z, par, smooth = TRUE)))) |>
  mutate(H_ss = plogis(eta) * total, H_lo = plogis(eta - z90 * sd_eta) * total, H_hi = plogis(eta + z90 * sd_eta) * total,
         sd_H = total * plogis(eta) * (1 - plogis(eta)) * sd_eta) |>
  left_join(lab, by = "province_code")
dr <- read_csv("output/tables/intl_spain_excess_male_1936-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(scenario == "pi = 0.95") |> select(year, province_code, H_direct = H)
out <- sm |> left_join(dr, by = c("year", "province_code")) |>
  transmute(year, province_code, province, male, female, total, violent_reg, rho_nat = rho, u, sd_u, eta, sd_eta,
            H_ss, H_lo90 = H_lo, H_hi90 = H_hi, H_direct)
write_csv(out, paste0("output/tables/intl_spain_state_space", sfx, ".csv"))

# national, by period and year (interval: provinces independent given the parameters)
pers <- function(y) case_when(y <= 1935 ~ "1926-1935", y <= 1939 ~ "1936-1939", y <= 1942 ~ "1940-1942", TRUE ~ "1943-1946")
na <- bind_rows(sm |> mutate(period = pers(year)), sm |> mutate(period = as.character(year))) |>
  left_join(dr, by = c("year", "province_code")) |>
  summarise(H_ss = sum(H_ss), sd = sqrt(sum(sd_H^2)), H_direct = sum(H_direct), registered = sum(violent_reg), .by = period) |>
  mutate(lo90 = H_ss - z90 * sd, hi90 = H_ss + z90 * sd)
write_csv(na, paste0("output/tables/intl_spain_state_space_national", sfx, ".csv"))
cat("\n== Spain: violent deaths, state-space model against the direct estimator (80) and the registry ==\n")
print(as.data.frame(na |> mutate(across(where(is.numeric), round)) |> select(period, H_ss, lo90, hi90, H_direct, registered)), row.names = FALSE)

# provinces, 1936-1939: where the two estimators differ most
pp <- out |> filter(year %in% 1936:1939) |>
  summarise(H_ss = sum(H_ss), H_direct = sum(H_direct), reg = sum(violent_reg), d = sum(total), .by = c(province_code, province)) |>
  mutate(share_ss = 100 * H_ss / d, ratio = H_ss / H_direct)
cat("\n== provinces 1936-1939: correlation of log H with the registry: state-space",
    round(cor(log(pp$H_ss), log(pp$reg)), 3), "| direct", round(cor(log(pmax(pp$H_direct, 1)), log(pp$reg)), 3), "==\n")
print(as.data.frame(pp |> arrange(share_ss) |> head(10) |> mutate(across(c(H_ss, H_direct, reg), round), share_ss = round(share_ss, 1), ratio = round(ratio, 2))), row.names = FALSE)
cat("provinces with a negative direct estimate in some year 1936-1946:", n_distinct(out$province_code[out$year >= 1936 & out$H_direct < 0]),
    "| province-years:", sum(out$year >= 1936 & out$H_direct < 0, na.rm = TRUE), "\n")

# figure: national by year; provinces 1936-1939
fy <- na |> filter(!grepl("-", period)) |> mutate(year = as.integer(period)) |> filter(year >= 1930)
p1 <- ggplot(fy, aes(year)) +
  geom_ribbon(aes(ymin = lo90 / 1000, ymax = hi90 / 1000), fill = "#2a78d6", alpha = 0.18) +
  geom_line(aes(y = H_ss / 1000, colour = "estados ocultos (87)"), linewidth = 0.8) +
  geom_point(aes(y = H_direct / 1000, colour = "directo (80)"), size = 2) +
  geom_col(aes(y = registered / 1000, fill = "violencia registrada (83)"), width = 0.5, alpha = 0.5) +
  scale_colour_manual(values = c(`estados ocultos (87)` = "#2a78d6", `directo (80)` = "#eb6834"), name = NULL) +
  scale_fill_manual(values = c(`violencia registrada (83)` = "grey60"), name = NULL) +
  scale_x_continuous(breaks = 1930:1946) +
  labs(title = "España: muertes violentas por año", subtitle = "Banda: intervalo de 90 % del modelo de estados ocultos.", x = NULL, y = "miles") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
p2 <- ggplot(pp, aes(pmax(H_direct, 10), H_ss)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = "22") +
  geom_point(colour = "#2a78d6", size = 1.6) +
  ggrepel::geom_text_repel(aes(label = province), size = 2.4, colour = "grey30", max.overlaps = 15) +
  scale_x_log10(labels = scales::comma) + scale_y_log10(labels = scales::comma) +
  labs(title = "Por provincia, 1936-1939", subtitle = "Estados ocultos frente al estimador directo. Línea: iguales.\nLos valores directos negativos (Canarias) se dibujan en 10.", x = "directo (80)", y = "estados ocultos (87)") +
  theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
fig <- ggpubr::ggarrange(p1, p2, ncol = 2, widths = c(1.2, 1))
if (!trend) ggsave("figures/09_international/spain_state_space.png", fig, w = 14, h = 6, bg = "white", dpi = 160)
