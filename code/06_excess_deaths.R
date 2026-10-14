# 06_excess_deaths.R ---------------------------------------------------------
# all-cause excess deaths by municipality and year: deaths above the upper
# 95% bound of a quasi-Poisson log-linear trend, fitted iteratively with
# years above the bound down-weighted (three passes). writes
# data_inter/excess_deaths_munic.rds, a covariate of the model.
# (formerly 07_excess_deaths.R)

rm(list = ls())
gc()
source("code/00_setup.R")

pop <- read_rds("data_inter/pop_munic_1985-2017.rds")
dts <- read_rds("data_inter/deaths_munic_1979-2023.rds")

panel <- build_munic_panel(dts, pop)

# both sexes, one row per municipality-year, with a time index
dx_munic <-
  panel |>
  summarise(dx_tot = sum(dx_tot), .by = c(cod_munic, munic, year)) |>
  arrange(cod_munic, year) |>
  mutate(t = row_number(), .by = cod_munic)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# baseline estimation ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fit_bsn <- function(chunk, w = NULL) {
  mod <- gam(dx_tot ~ t, data = chunk, weights = w, family = "quasipoisson")
  pr <- predict(mod, newdata = chunk, type = "response", se.fit = TRUE)
  tibble(fit = pr$fit, se = pr$se.fit, u = pr$fit + 1.96 * pr$se.fit, l = pr$fit - 1.96 * pr$se.fit)
}

est_bsn <- function(chunk) {
  b1 <- fit_bsn(chunk)
  w1 <- ifelse(chunk$dx_tot > b1$u, 0, 1)
  b2 <- fit_bsn(chunk, w = w1)
  w2 <- ifelse(chunk$dx_tot > b2$u, 0, 1)
  b3 <- fit_bsn(chunk, w = w2)
  chunk |>
    mutate(
      bsn = b1$fit,
      bsn2 = b2$fit,
      bsn3 = b3$fit,
      bsn3_se = b3$se,
      bsn3_l = b3$l,
      bsn3_u = b3$u
    )
}

bsn <-
  dx_munic |>
  group_by(cod_munic, munic) |>
  group_modify(~ est_bsn(.x)) |>
  ungroup()

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# plots ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

plot_bsn <- function(d) {
  d |>
    ggplot() +
    geom_line(aes(year, dx_tot)) +
    geom_line(aes(year, bsn), color = "blue", alpha = 0.3) +
    geom_line(aes(year, bsn2), color = "blue", alpha = 0.3) +
    geom_line(aes(year, bsn3), color = "blue") +
    geom_ribbon(aes(year, ymin = bsn3_l, ymax = bsn3_u), alpha = 0.2) +
    labs(x = NULL, y = "all-cause deaths") +
    theme_minimal()
}

# Pacho, Medellin, Bogota, Cartagena, Manizales, Cali
mnc <- c("25513", "05001", "11001", "13001", "17001", "76001")

plot_bsn(bsn |> filter(cod_munic %in% mnc)) +
  facet_wrap(~munic, scales = "free_y")
ggsave("figures/excess_deaths_munic_sample.png", width = 10, height = 6)

plot_bsn(bsn |> mutate(munic2 = paste0(str_sub(cod_munic, 1, 2), "-", munic))) +
  facet_wrap(~munic2, ncol = 15, scales = "free_y")
ggsave("figures/excess_deaths_munic.pdf", width = 20, height = 100, limitsize = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# excess ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

excess <-
  bsn |>
  mutate(excess = ifelse(dx_tot > bsn3_u, dx_tot - bsn3_u, 0))

print(excess |> summarise(excess = sum(excess), dx_tot = sum(dx_tot), .by = year), n = 40)

write_rds(excess, "data_inter/excess_deaths_munic.rds")
