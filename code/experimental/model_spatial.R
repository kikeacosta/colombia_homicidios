# model_spatial.R (EXPERIMENTAL) ---------------------------------------------
# variant of the model in 07 with a spatial exponential-covariance random
# effect on municipality centroids (glmmTMB: exp(pos + 0 | group)) instead of
# the department/municipality random intercepts. it did not feed any result
# and no uncertainty intervals are computed; kept for reference.
# run from the project root, after 07. (formerly 10_model_spatial.R)

rm(list = ls())
gc()
source("code/00_setup.R")

tst <- read_rds("data_inter/homicide_estimates_1985-2017_excs.rds")

mapa_col <- municipios
# 1. Convertir el objeto Spatial a objeto sf
mapa_sf <- st_as_sf(mapa_col)

municipios_puntos <- st_centroid(mapa_sf)

# 2. Extraer coordenadas X e Y (en metros, no grados, para que la distancia sea real)
# Asegúrate de usar una proyección plana como Magna-Sirgas (EPSG: 3116)
coords <- st_coordinates(st_transform(municipios_puntos, 3116))
tst$x <- coords[match(tst$cod_munic, municipios_puntos$id), 1]
tst$y <- coords[match(tst$cod_munic, municipios_puntos$id), 2]

# Definimos las coordenadas como un factor interactuando con el espacio
# numFactor crea un índice numérico para las coordenadas
tst$pos <- numFactor(tst$x, tst$y)
tst$group <- factor(1) # Un solo grupo para todo el país

length(levels(tst$pos))

mod_espacial <- glmmTMB(
  dts_v ~ sex_r_log + exc_mx_log +
    cdr_h_dpto * w_pop +
    cdr_std +
    offset(log(pop)) +
    exp(pos + 0 | group), # ESTO INFORMA LA VECINDAD ESPACIAL
  ziformula = ~ sex_r_log + w_pop,
  data = tst,
  family = nbinom2
)

# pred <- predict(mod_base4, newdata = tst, type = "response", se.fit = TRUE)
pred <- predict(mod_espacial, newdata = tst, type = "response", se.fit = FALSE)

# pred$fit
# pred$se.fit

# 2. Calcular la tasa observada y la tasa predicha
tst2 <-
  tst %>%
  mutate(
    # pred_dts_v = predict(mod, newdata = tst, type = "response"),
    pred_dts_v = pred,
    # pred_dts_v = pred$fit,
    # pred_dts_v_l = pred_dts_v - 1.96 * pred$se.fit,
    # pred_dts_v_u = pred_dts_v + 1.96 * pred$se.fit,
    cdr_pred = (pred_dts_v / pop)
  ) |>
  group_by(year, dpto) %>%
  # re-escalando suma de homicidios municipales al total del nivel departamental
  mutate(
    pred_dts_v2 = sum(dts_v) * pred_dts_v / sum(pred_dts_v),
    # pred_dts_v_l2 = pred_dts_v_l * pred_dts_v2 / pred_dts_v,
    # pred_dts_v_u2 = pred_dts_v_u * pred_dts_v2 / pred_dts_v,
    cdr_pred2 = pred_dts_v2 / pop,
    # cdr_pred_l2 = (pred_dts_v_l2 / pop),
    # cdr_pred_u2 = (pred_dts_v_u2 / pop)
  ) %>%
  ungroup()

write_rds(tst2, "data_inter/homicide_estimates_1985-2017_spatial.rds")

# plot de tasas observadas vs. predichas
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tst2 %>%
  mutate(
    cdr_h = cdr_h * 1e5,
    cdr_pred = cdr_pred * 1e5,
    cdr_pred2 = cdr_pred2 * 1e5,
    munic2 = paste0(dpto, "-", munic)
  ) |>
  ggplot(aes(x = year)) +
  geom_line(aes(y = cdr_h, color = "Observed", group = 1), size = 0.7) +
  geom_line(
    aes(y = cdr_pred2, color = "Predicted_adj", group = 1),
    size = 0.7,
    alpha = 1
  ) +
  labs(
    title = "Tasa de Homicidios en Medellín: Observada vs. Predicha",
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

ggsave("figures/experimental/predict_spatial.pdf", w = 20, h = 120, limitsize = FALSE)


dt_1m <- read_rds("data_inter/homicide_estimates_1985-2017_excs.rds")

tst3 <-
  dt_1m |>
  select(year, cod_dpto, dpto, cod_munic, munic, cdr_h, cdr_pred = cdr_pred2) |>
  left_join(
    tst2 |>
      select(
        year,
        cod_dpto,
        dpto,
        cod_munic,
        munic,
        cdr_pred_spa = cdr_pred2
      )
  ) |>
  pivot_longer(
    cols = c(cdr_h, cdr_pred, cdr_pred_spa),
    names_to = "metric",
    values_to = "cdr"
  ) |>
  mutate(
    metric = case_when(
      metric == "cdr_h" ~ "Tasa Observada",
      metric == "cdr_pred" ~ "Tasa Predicha (Modelo)",
      metric == "cdr_pred_spa" ~ "Tasa Predicha (Modelo Espacial)"
    ),
    metric = factor(
      metric,
      levels = c(
        "Tasa Observada",
        "Tasa Predicha (Modelo)",
        "Tasa Predicha (Modelo Espacial)"
      )
    )
  )
tst3 %>%
  # filter(munic %in% c("Medellín", "Bello", "Envigado")) |>
  mutate(
    cdr = cdr * 1e5,
    munic2 = paste0(dpto, "-", munic)
  ) |>
  ggplot(aes(x = year)) +
  geom_line(aes(y = cdr, color = metric, group = metric), size = 0.7) +
  labs(
    title = "Tasa de Homicidios en Medellín: Observada vs. Predicha",
    subtitle = "Modelo ZINB con Efectos Mixtos y Ratio de Masculinidad",
    y = "Tasa por 100.000 habitantes",
    x = "Año",
    color = "Referencia"
  ) +
  facet_wrap(~munic2, ncol = 8, scales = "free_y") +
  theme_minimal() +
  scale_color_manual(values = c("black", "firebrick", "grey")) +
  theme(legend.position = "bottom", legend.direction = "horizontal")

ggsave("figures/experimental/predict_spatial_cmp.pdf", w = 20, h = 120, limitsize = FALSE)
