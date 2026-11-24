# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 84. Spain 1936-1946: one interval for the violent deaths (H), the excess and
#     its non-violent part, combining the sources of error by simulation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Same estimator as 80. Each draw takes:
#   - rho of each province: its 1926-1935 mean log sex ratio, with the error of
#     that mean, and a drift common to all provinces between none (main) and
#     the pre-war national drift (about -0.1 % a year), drawn uniformly
#   - the non-violent sex ratio of each province and year: rho times a
#     deviation with the size seen in peace years, split into a shock common
#     to all provinces in the year and a provincial part (binomial noise of
#     that province's deaths plus extra variation), no autocorrelation (the
#     pre-war deviations have none)
#   - pi: uniform between 0.92 and 0.98, common to the draw (the registered
#     share of men among violent deaths is 0.93-0.97 in 1936-1940, 83)
#   - expected deaths: province levels and the national trend, or each
#     province's own trend (half the draws each), with the error of the
#     coefficients, and the year-to-year noise of deaths around them (a shock
#     common to the year and a provincial part)
# Left out: what the test of 82 and the causes of 83 show for 1940-1942, that
# a famine killing more men than the pre-war pattern is read as violence.
# That is a bias, not noise; the report gives the registered violence as the
# floor for those years.
#
# input    data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv
# output   output/tables/intl_spain_uncertainty_national.csv
#          output/tables/intl_spain_uncertainty_provinces.csv
#          figures/09_international/spain_uncertainty.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)
set.seed(1936)
B <- 2000

sp <- read_csv("data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character()))
w <- sp |> filter(!is.na(province_code), !grepl("+", province_code, fixed = TRUE)) |>
  select(year, province_code, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths) |> arrange(province_code, year)
lab <- sp |> filter(!is.na(province_code), year == max(year)) |> distinct(province_code, province)
pv <- sort(unique(w$province_code)); P <- length(pv)
yrs <- 1936:1946; Y <- length(yrs)

# ---- pre-war noise ----
base <- w |> filter(year <= 1935) |> mutate(lsr = log(male / female), pois = 1 / male + 1 / female) |>
  mutate(dev = lsr - mean(lsr), n = n(), .by = province_code)
yr_shock <- base |> summarise(c = mean(dev), .by = year)
sd_common <- sd(yr_shock$c)
resid_prov <- base |> left_join(yr_shock, by = "year") |> mutate(e = dev - c)
tau2 <- max(0, var(resid_prov$e) - mean(resid_prov$pois))
rho <- base |> summarise(lrho = mean(lsr), se_lrho = sqrt((tau2 + mean(pois)) / n()), .by = province_code)
nat_drift <- coef(lm(lsr ~ year, data = base |> summarise(lsr = log(sum(male) / sum(female)), .by = year)))[["year"]]
cat("sex ratio: common year shock sd", round(sd_common, 4), "| provincial extra sd", round(sqrt(tau2), 4),
    "| national pre-war drift per year", round(nat_drift, 5), "\n")

fit_c <- lm(log(total) ~ factor(province_code) + I(year - 1935), data = base)
fit_p <- lm(log(total) ~ factor(province_code) / I(year - 1935), data = base)
rb <- tibble(province_code = base$province_code, year = base$year, e = resid(fit_c))
sd_d_common <- sd(summarise(rb, m = mean(e), .by = year)$m)
sd_d_prov <- sqrt(max(0, sigma(fit_c)^2 - sd_d_common^2))
cat("deaths: common year shock sd", round(sd_d_common, 4), "| provincial sd", round(sd_d_prov, 4), "\n")

# ---- war years as matrices [province x year] ----
wy <- w |> filter(year %in% yrs) |> complete(province_code = pv, year = yrs)
M <- matrix(wy$male, P, Y, byrow = TRUE); Fm <- matrix(wy$female, P, Y, byrow = TRUE); D <- matrix(wy$total, P, Y, byrow = TRUE)
lrho_hat <- rho$lrho[match(pv, rho$province_code)]; se_lrho <- rho$se_lrho[match(pv, rho$province_code)]
grid <- expand_grid(province_code = pv, year = yrs)
Xc <- model.matrix(~ factor(province_code, levels = pv) + I(year - 1935), data = grid)
Xp <- model.matrix(~ factor(province_code, levels = pv) / I(year - 1935), data = grid)
bc <- MASS::mvrnorm(B, coef(fit_c), vcov(fit_c)); bp <- MASS::mvrnorm(B, coef(fit_p), vcov(fit_p))
pois_wy <- 1 / M + 1 / Fm

Hs <- Es <- array(NA_real_, c(B, P, Y))
for (b in seq_len(B)) {
  pi_b <- runif(1, 0.92, 0.98)
  drift <- runif(1, min(nat_drift, 0), 0)
  lr <- lrho_hat + rnorm(P, 0, se_lrho)
  dev <- matrix(rnorm(Y, 0, sd_common), P, Y, byrow = TRUE) + matrix(rnorm(P * Y, 0, sqrt(tau2 + pois_wy)), P, Y)
  r <- exp(lr + outer(rep(1, P), drift * (yrs - 1930.5)) + dev)
  Hs[b, , ] <- (M - r * Fm) / (pi_b - r * (1 - pi_b))
  le <- if (b %% 2) Xc %*% bc[b, ] else Xp %*% bp[b, ]
  E <- matrix(exp(le), P, Y, byrow = TRUE) *
    exp(matrix(rnorm(Y, 0, sd_d_common), P, Y, byrow = TRUE) + matrix(rnorm(P * Y, 0, sd_d_prov), P, Y))
  Es[b, , ] <- E
}
Xs <- sweep(-Es, c(2, 3), D, "+")          # excess = D - E
NVs <- Xs - Hs

q <- function(x) c(est = median(x), lo = unname(quantile(x, 0.05)), hi = unname(quantile(x, 0.95)))
per <- list("1936-1939" = 1:4, "1940-1942" = 5:7, "1943-1946" = 8:11)
summ <- function(A, idx_p = seq_len(P)) {
  bind_rows(lapply(names(per), function(nm) as_tibble(as.list(q(apply(A[, idx_p, per[[nm]], drop = FALSE], 1, sum)))) |> mutate(period = nm)),
            lapply(seq_len(Y), function(k) as_tibble(as.list(q(apply(A[, idx_p, k, drop = FALSE], 1, sum)))) |> mutate(period = as.character(yrs[k]))))
}
nat <- bind_rows(summ(Hs) |> mutate(quantity = "violent (H)"), summ(Xs) |> mutate(quantity = "excess"),
                 summ(NVs) |> mutate(quantity = "non-violent excess")) |> relocate(quantity, period)
write_csv(nat, "output/tables/intl_spain_uncertainty_national.csv")
cat("\n== Spain: median and 90 % interval (thousands) ==\n")
print(as.data.frame(nat |> filter(grepl("-", period)) |> mutate(across(c(est, lo, hi), ~ round(.x / 1000, 1)))), row.names = FALSE)
cat("\n== by year, violent (H) ==\n")
print(as.data.frame(nat |> filter(quantity == "violent (H)", !grepl("-", period)) |> mutate(across(c(est, lo, hi), ~ round(.x / 1000, 1)))), row.names = FALSE)

# provinces, by period
pr <- bind_rows(lapply(seq_len(P), function(i) bind_rows(
  lapply(names(per), function(nm) bind_rows(
    as_tibble(as.list(q(apply(Hs[, i, per[[nm]], drop = FALSE], 1, sum)))) |> mutate(quantity = "violent (H)"),
    as_tibble(as.list(q(apply(NVs[, i, per[[nm]], drop = FALSE], 1, sum)))) |> mutate(quantity = "non-violent excess")) |>
      mutate(period = nm))) |> mutate(province_code = pv[i]))) |>
  left_join(lab, by = "province_code") |> relocate(province_code, province, period, quantity)
write_csv(pr, "output/tables/intl_spain_uncertainty_provinces.csv")
cat("\n== provinces, violent deaths 1936-1939: median and 90 % interval, the 12 largest ==\n")
print(as.data.frame(pr |> filter(period == "1936-1939", quantity == "violent (H)") |> arrange(-est) |> head(12) |>
                      mutate(across(c(est, lo, hi), round), width_pct = round(100 * (hi - lo) / 2 / est))), row.names = FALSE)

# figure: by year, H and the non-violent excess with their intervals
fy <- nat |> filter(!grepl("-", period), quantity != "excess") |> mutate(year = as.integer(period))
fig <- ggplot(fy, aes(year, est / 1000, colour = quantity, fill = quantity)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lo / 1000, ymax = hi / 1000), alpha = 0.2, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  scale_colour_manual(values = c(`violent (H)` = "#2a78d6", `non-violent excess` = "#f2a541"), name = NULL) +
  scale_fill_manual(values = c(`violent (H)` = "#2a78d6", `non-violent excess` = "#f2a541"), name = NULL) +
  scale_x_continuous(breaks = yrs) +
  labs(title = "Spain: violent and non-violent excess deaths by year of registration, with 90 % intervals",
       subtitle = paste0("Intervals combine the error of each province's pre-war sex ratio, its year-to-year variation, a possible drift, ",
                         "the share of men among victims (0.92-0.98)\nand the expected deaths (trend, coefficients and noise). ",
                         "Not included: a famine killing more men than usual would be read as violence (1940-1942)."),
       x = NULL, y = "thousand deaths") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
ggsave("figures/09_international/spain_uncertainty.png", fig, w = 11, h = 6, bg = "white", dpi = 160)
