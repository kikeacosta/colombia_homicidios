# 07_model_zinb.R ------------------------------------------------------------
# zero-inflated negative binomial mixed model of municipal violent deaths
# (dx_v) on the log all-cause sex ratio, log excess all-cause mortality, the
# department violent-death rate weighted by the municipality's population
# share, the municipality's standardised all-cause CDR, log population as
# offset, and random intercepts for department and municipality. predictions
# are rescaled so municipal sums match department totals each year.
# writes data_inter/homicide_estimates_1985-2017_excs.rds (read by 08).
# (formerly 08_model_glmmTMB_exc.R; the earlier model without excess deaths
# lives in _archive/code/08_model_glmmTMB.R)

rm(list = ls())
gc()
source("code/00_setup.R")

sex_r <- read_rds("data_inter/sex_ratios_munic_1985-2017.rds")
cdr_h <- read_rds("data_inter/homicide_cdr_munic_1985-2017.rds") |>
  replace_na(list(cdr_dpto = 0, cdr_h_dpto = 0))
exc <- read_rds("data_inter/excess_deaths_munic.rds")



# preparing data for regression
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tst <-
  cdr_h %>%
  group_by(dpto, year) %>%
  mutate(
    w_pop = pop / sum(pop),
  ) %>%
  ungroup() |>
  left_join(sex_r |> select(cod_munic, year, sex_r)) |>
  left_join(exc |> select(cod_munic, year, excess)) |>
  mutate(
    sex_r_log = log(sex_r),
    excess = ifelse(is.na(excess), 0, excess),
    exc_mx_log = log((excess + 1) / pop),
    # cdr_h_dpto_lag = ifelse(
    #   is.na(cdr_h_dpto_lag) | !is.finite(cdr_h_dpto_lag),
    #   cdr_h_dpto,
    #   cdr_h_dpto_lag
    # )
  ) |>
  group_by(cod_munic) |>
  mutate(
    cdr_std = (cdr - min(cdr)) / (max(cdr) - min(cdr)),
    cdr_std_chg = cdr_std / lag(cdr_std),
    cdr_std_chg = ifelse(
      is.na(cdr_std_chg) | !is.finite(cdr_std_chg),
      1,
      cdr_std_chg
    )
  ) |>
  ungroup() |>
  drop_na() |>
  filter(pop > 0)

# modelo ZINB con efectos mixtos ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# model evaluation and selection
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# model with only department CDR and population. AIC = 204621.0, BIC = 204671.9
# model with sex ratio, department CDR and population. AIC = 195282.36, BIC = 195341.80

# model with excess deaths, department CDR and population. AIC = 203878.2, BIC = 203937.7
# model with sex ratio, excess deaths, department CDR and population. AIC = 194549.45, BIC = 194617.38

# model with sex ratio, department CDR and population, aleatory effects. AIC = 186082.84, BIC = 186150.77
# model with sex ratio, department CDR and population, aleatory effects, and ZINB. AIC = 179055.03, BIC = 179156.92

# model with excess deaths, sex ratio, department and population, aleatory effects, and ZINB. AIC = 178726.36, BIC = 178836.74

mod_base4 <- glmmTMB(
  dts_v ~
    sex_r_log +
    exc_mx_log +
    cdr_h_dpto *
      w_pop +
    cdr_std +
    (1 | cod_dpto) + # Intercepto aleatorio departamental
    (1 | cod_munic) +
    offset(log(pop)),
  ziformula = ~ sex_r_log + w_pop,
  data = tst,
  family = nbinom2
)

# 1. Generar predicciones de conteo (E[y])
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# predict(mod_base4, newdata = tst, type = "response", se.fit = TRUE)$se.fit
pred <- predict(mod_base4, newdata = tst, type = "response", se.fit = TRUE)

pred$fit
pred$se.fit

# 2. Calcular la tasa observada y la tasa predicha
tst2 <-
  tst %>%
  mutate(
    # pred_dts_v = predict(mod, newdata = tst, type = "response"),
    pred_dts_v = pred$fit,
    pred_dts_v_l = pred_dts_v - 1.96 * pred$se.fit,
    pred_dts_v_u = pred_dts_v + 1.96 * pred$se.fit,
    cdr_pred = (pred_dts_v / pop)
  ) |>
  group_by(year, dpto) %>%
  # re-escalando suma de homicidios municipales al total del nivel departamental
  mutate(
    pred_dts_v2 = sum(dts_v) * pred_dts_v / sum(pred_dts_v),
    pred_dts_v_l2 = pred_dts_v_l * pred_dts_v2 / pred_dts_v,
    pred_dts_v_u2 = pred_dts_v_u * pred_dts_v2 / pred_dts_v,
    cdr_pred2 = pred_dts_v2 / pop,
    cdr_pred_l2 = (pred_dts_v_l2 / pop),
    cdr_pred_u2 = (pred_dts_v_u2 / pop)
  ) %>%
  ungroup()

# plot de tasas observadas vs. predichas
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tst2 %>%
  # tasa por 100.000 hab para mejor lectura
  mutate(
    cdr_h = cdr_h * 1e5,
    cdr_pred = cdr_pred * 1e5,
    cdr_pred2 = cdr_pred2 * 1e5,
    cdr_pred_l2 = cdr_pred_l2 * 1e5,
    cdr_pred_u2 = cdr_pred_u2 * 1e5,
    munic2 = paste0(dpto, "-", munic)
  ) |>
  # filter(munic == c("Medellín", "Bello", "Envigado")) |>
  ggplot(aes(x = year)) +
  geom_line(aes(y = cdr_h, color = "Observed", group = 1), size = 0.7) +
  # geom_line(
  #   aes(y = cdr_pred, color = "Predicted", group = 1),
  #   size = 0.7,
  #   alpha = 1
  # ) +
  geom_line(
    aes(y = cdr_pred2, color = "Predicted_adj", group = 1),
    size = 0.7,
    alpha = 1
  ) +
  geom_ribbon(
    aes(
      x = year,
      ymin = cdr_pred_l2,
      ymax = cdr_pred_u2,
      fill = "Predicted_adj"
    ),
    alpha = 0.2
  ) +
  labs(
    title = "Tasa de muertes violentas por municipio: observada vs. predicha",
    subtitle = "Modelo ZINB con Efectos Mixtos y Ratio de Masculinidad",
    y = "Tasa por 100.000 habitantes",
    x = "Año",
    color = "Referencia"
  ) +
  facet_wrap(~munic2, ncol = 8, scales = "free_y") +
  theme_minimal() +
  scale_color_manual(
    values = c(
      "Observed" = "black",
      "Predicted_adj" = "firebrick",
      "Predicted" = "grey"
    )
  ) +
  scale_fill_manual(
    values = c(
      "Observed" = "black",
      "Predicted_adj" = "firebrick",
      "Predicted" = "grey"
    )
  ) +
  theme(legend.position = "bottom", legend.direction = "horizontal")

ggsave("figures/predict_excs.pdf", w = 20, h = 120, limitsize = FALSE)

write_rds(tst2, "data_inter/homicide_estimates_1985-2017_excs.rds")
