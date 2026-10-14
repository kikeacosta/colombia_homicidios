# 15_model_completeness.R ----------------------------------------------------
# does registration completeness change how well the sex ratio predicts
# municipal violent deaths? (plan B5.2 and B5.3)
#
#   M0  the model of 07
#   M1  M0 + department-year completeness, and its interaction with the
#       log sex ratio (the slope of the sex ratio is allowed to depend on
#       completeness: the hypothesis predicts a steeper, more useful slope
#       where completeness is high)
#   also: M0 fitted separately before and after 1998, to show how much the
#   coefficient of the sex ratio changes.
#
# completeness: annual, both sexes, department level, from 10
# (completeness_deptos.rds), reliable department-years only. all models use
# the same rows, so AICs are comparable.
#
# outputs: output/tables/model_completeness_*.csv

rm(list = ls())
gc()
source("code/00_setup.R")

sex_r <- read_rds("data_inter/sex_ratios_munic_1985-2017.rds")
cdr_h <- read_rds("data_inter/homicide_cdr_munic_1985-2017.rds") |>
  replace_na(list(cdr_dpto = 0, cdr_h_dpto = 0))
exc <- read_rds("data_inter/excess_deaths_munic.rds")
comp <- read_rds("data_inter/completeness_deptos.rds")

comp_dep <-
  comp |>
  filter(reliable) |>
  summarise(comp = mean(completeness), .by = c(cod_dpto, year))

# same data preparation as 07
dat <-
  cdr_h |>
  mutate(w_pop = pop / sum(pop), .by = c(dpto, year)) |>
  left_join(sex_r |> select(cod_munic, year, sex_r), by = c("cod_munic", "year")) |>
  left_join(exc |> select(cod_munic, year, excess), by = c("cod_munic", "year")) |>
  mutate(
    sex_r_log = log(sex_r),
    excess = ifelse(is.na(excess), 0, excess),
    exc_mx_log = log((excess + 1) / pop)
  ) |>
  mutate(
    cdr_std = (cdr - min(cdr)) / (max(cdr) - min(cdr)),
    .by = cod_munic
  ) |>
  drop_na(sex_r_log, exc_mx_log, cdr_std) |>
  filter(pop > 0, is.finite(sex_r_log)) |>
  left_join(comp_dep, by = c("cod_dpto", "year")) |>
  drop_na(comp) |>
  mutate(comp_c = comp - mean(comp), post = year >= 1998)

cat("rows:", nrow(dat), " municipalities:", n_distinct(dat$cod_munic),
    " pre-1998 rows:", sum(!dat$post), "\n")

f0 <- dts_v ~ sex_r_log + exc_mx_log + cdr_h_dpto * w_pop + cdr_std +
  (1 | cod_dpto) + (1 | cod_munic) + offset(log(pop))
f1 <- dts_v ~ sex_r_log * comp_c + exc_mx_log + cdr_h_dpto * w_pop + cdr_std +
  (1 | cod_dpto) + (1 | cod_munic) + offset(log(pop))
zi <- ~ sex_r_log + w_pop

fit <- function(f, d) glmmTMB(f, ziformula = zi, data = d, family = nbinom2)

m0 <- fit(f0, dat)
m1 <- fit(f1, dat)
m0_pre <- fit(f0, dat |> filter(!post))
m0_post <- fit(f0, dat |> filter(post))

cat("\nAIC M0:", AIC(m0), " M1:", AIC(m1), " (delta", AIC(m1) - AIC(m0), ")\n")
print(summary(m1)$coefficients$cond[c("sex_r_log", "comp_c", "sex_r_log:comp_c"), ])

ct <- function(m, name) {
  x <- summary(m)$coefficients$cond
  tibble(model = name, term = rownames(x), estimate = x[, 1], se = x[, 2], z = x[, 3], p = x[, 4])
}
coefs <- bind_rows(
  ct(m0, "M0 all years"), ct(m0_pre, "M0 1985-1997"),
  ct(m0_post, "M0 1998-2017"), ct(m1, "M1 all years")
)
cat("logLik M0:", as.numeric(logLik(m0)), " M1:", as.numeric(logLik(m1)), " pdHess M1:", m1$sdr$pdHess, "
")
write_csv(coefs, "output/tables/model_completeness_coefficients.csv")
print(coefs |> filter(term %in% c("sex_r_log", "comp_c", "sex_r_log:comp_c")) |> mutate(across(where(is.numeric), ~ round(.x, 3))))

# fit by period and completeness: correlation of predicted and observed
# municipal violent-death rates (log scale, deaths + 0.5), pooled
dat$p0 <- predict(m0, type = "response")
dat$p1 <- predict(m1, type = "response")

fitq <-
  dat |>
  mutate(
    comp_bin = cut(comp, c(0, .5, .75, 1.01), labels = c("<0.5", "0.5-0.75", ">0.75")),
    per = ifelse(post, "1998-2017", "1985-1997")
  ) |>
  summarise(
    n = n(),
    deaths = sum(dts_v),
    cor_M0 = cor(log(p0 + .5), log(dts_v + .5)),
    cor_M1 = cor(log(p1 + .5), log(dts_v + .5)),
    ratio_pred_obs_M0 = sum(p0) / sum(dts_v),
    ratio_pred_obs_M1 = sum(p1) / sum(dts_v),
    .by = c(per, comp_bin)
  ) |>
  arrange(per, comp_bin)
print(fitq |> mutate(across(where(is.numeric), ~ round(.x, 3))))
write_csv(fitq, "output/tables/model_completeness_fit_by_period.csv")
