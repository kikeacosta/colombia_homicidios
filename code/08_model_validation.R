# 08_model_validation.R ------------------------------------------------------
# validates the model of 07: reads data_inter/homicide_estimates_1985-2017_excs.rds,
# draws observed-vs-predicted rates for the most violent municipalities, maps
# (colmaps::municipios) of observed and estimated rates by year, the discrete
# violence-level match statistics (baja/media/alta/extrema) with and without
# prediction intervals, and summary maps of cumulative accuracy.
# (formerly 09_model_validation.R)

rm(list = ls())
gc()
source("code/00_setup.R")

tst <- read_rds("data_inter/homicide_estimates_1985-2017_excs.rds")


# plot detallado de tasas a nivel municipal

# municipios con mas de 500K habitantes en 2017
munic_lrg <-
  tst |>
  filter(year == 2017 & pop >= 5e5) |>
  pull(cod_munic)

munic_viol <-
  tst |>
  summarise(cdr_h = mean(cdr_h), .by = c(cod_munic, munic)) |>
  arrange(-cdr_h) |>
  slice_head(n = 12) |>
  pull(cod_munic)

# plot de tasas observadas vs. predichas
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tst %>%
  # tasa por 100.000 hab para mejor lectura
  mutate(
    cdr_h = cdr_h * 1e5,
    cdr_pred = cdr_pred * 1e5,
    cdr_pred2 = cdr_pred2 * 1e5,
    cdr_pred_l2 = cdr_pred_l2 * 1e5,
    cdr_pred_u2 = cdr_pred_u2 * 1e5,
    munic2 = paste0(dpto, "-", munic)
  ) |>
  # filter(cod_munic %in% munic_lrg) |>
  filter(cod_munic %in% munic_viol) |>
  ggplot(aes(x = year)) +
  geom_line(aes(y = cdr_h, color = "Observed", group = 1), size = 0.7) +
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
  facet_wrap(~munic2, ncol = 4, scales = "free_y") +
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
    ),
    guide = "none"
  ) +
  labs(
    title = "Tasa de homicidios municipales: Observada vs. Estimada",
    y = "Tasa por 100.000 habitantes",
    x = "Año",
    color = "Referencia",
    fill = "Referencia"
  ) +
  theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    strip.text = element_text(size = 7),
    axis.text = element_text(size = 7)
  )

ggsave("figures/predict_munic_viols_exc.png", w = 7, h = 4, limitsize = FALSE)


mapa_col <- municipios
# 1. Convertir el objeto Spatial a objeto sf
mapa_sf <- st_as_sf(mapa_col)

plot_map <- function(yr = 2000) {
  tst_mapa <-
    tst %>%
    filter(year == yr) |>
    select(year, cod_dpto, dpto, cod_munic, munic, cdr_h, cdr_pred2) |>
    pivot_longer(
      cols = c(cdr_h, cdr_pred2),
      names_to = "metric",
      values_to = "cdr"
    ) %>%
    # Renombramos para que el título del facet sea elegante
    mutate(
      metric = ifelse(
        metric == "cdr_h",
        "Tasa observada",
        "Tasa estimada"
      ),
      metric = factor(
        metric,
        levels = c("Tasa observada", "Tasa estimada")
      )
    )

  # 2. Ahora el left_join funcionará perfectamente
  mapa_final <- left_join(mapa_sf, tst_mapa, by = c("id" = "cod_munic")) |>
    drop_na(metric)

  # 4. Crear el mapa de calor (Choropleth)
  ggplot(mapa_final) +
    geom_sf(aes(fill = cdr), color = NA) +
    facet_wrap(~metric) +
    scale_fill_viridis_c(option = "inferno", name = "Tasa por 100k") +
    labs(
      title = paste0(
        "Tasas de homicidios observadas y estimadas, año ",
        yr
      ),
      subtitle = "Basado en estructura de mortalidad masculina",
      caption = "Fuente: Estimaciones propias con glmmTMB"
    ) +
    theme_void() # Quita coordenadas y fon
  ggsave(paste0("figures/mapa_comp_", yr, "_exc.png"), dpi = 300, w = 8, h = 4)
}
for (yr in seq(1985, 2015, 5)) {
  plot_map(yr)
}


tst_mapa <-
  tst %>%
  filter(year %in% seq(1985, 2015, 5)) |>
  select(year, cod_dpto, dpto, cod_munic, munic, cdr_h, cdr_pred2) |>
  pivot_longer(
    cols = c(cdr_h, cdr_pred2),
    names_to = "metric",
    values_to = "cdr"
  ) %>%
  # Renombramos para que el título del facet sea elegante
  mutate(
    metric = ifelse(
      metric == "cdr_h",
      "Tasa observada",
      "Tasa estimada"
    ),
    metric = factor(
      metric,
      levels = c("Tasa observada", "Tasa estimada")
    )
  )

# 2. Ahora el left_join funcionará perfectamente
mapa_final <- left_join(mapa_sf, tst_mapa, by = c("id" = "cod_munic")) |>
  drop_na(metric)

# 4. Crear el mapa de calor (Choropleth)
ggplot(mapa_final) +
  geom_sf(aes(fill = cdr), color = NA) +
  facet_grid(year ~ metric) +
  scale_fill_viridis_c(option = "inferno", name = "Tasa por 100k") +
  labs(
    title = "Tasas de homicidios observadas y estimadas",
    subtitle = "Basado en estructura de mortalidad masculina",
    caption = "Fuente: Estimaciones propias con glmmTMB"
  ) +
  theme_void() +
  theme(legend.position = "bottom", legend.direction = "horizontal")

ggsave(paste0("figures/mapa_comp_yrs_exc.pdf"), w = 8, h = 20)


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# evaluacion de capacidad de prediccion de "niveles" de violencia =====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Crear cortes específicos para los datos positivos
# definimos los cortes de los datos con violencia (Cuartiles: 0, 25, 50, 75, 100)
# Esto genera 4 intervalos de intensidad

min_val <- quantile(log(tst$cdr_pred2), 0.25, na.rm = TRUE)

pos_val <-
  tst |>
  filter(log(cdr_h) > min_val) |>
  mutate(cdr_h_log = log(cdr_h)) |>
  pull(cdr_h_log) |>
  quantile(probs = c(0, 0.33, 0.66, 1), na.rm = TRUE)

# 2. Aplicamos el cut
violence_lvs <- c("Baja", "Media", "Alta", "Extrema")

tst2 <-
  tst %>%
  mutate(
    cdr_pred_l2 = ifelse(cdr_pred_l2 < 0, 0, cdr_pred_l2),
    cdr_h_lev = cut(
      log(cdr_h),
      # Breas: -Inf a casi 0 (para los "Sin"), y luego los cuartiles
      breaks = c(-Inf, min_val, pos_val[2:4]),
      labels = violence_lvs,
      include.lowest = TRUE
    ),
    cdr_h_pred_lev = cut(
      log(cdr_pred2),
      # Breas: -Inf a casi 0 (para los "Sin"), y luego los cuartiles
      breaks = c(-Inf, min_val, pos_val[2:4]),
      labels = violence_lvs,
      include.lowest = TRUE
    ),
    cdr_h_pred_l_lev = cut(
      log(cdr_pred_l2),
      # Breas: -Inf a casi 0 (para los "Sin"), y luego los cuartiles
      breaks = c(-Inf, min_val, pos_val[2:4]),
      labels = violence_lvs,
      include.lowest = TRUE
    ),
    cdr_h_pred_u_lev = cut(
      log(cdr_pred_u2),
      # Breas: -Inf a casi 0 (para los "Sin"), y luego los cuartiles
      breaks = c(-Inf, min_val, pos_val[2:4]),
      labels = violence_lvs,
      include.lowest = TRUE
    ),
    cdr_h_lev = factor(cdr_h_lev, levels = violence_lvs),
    cdr_h_pred_lev = factor(cdr_h_pred_lev, levels = violence_lvs),
    cdr_h_pred_l_lev = factor(cdr_h_pred_l_lev, levels = violence_lvs),
    cdr_h_pred_u_lev = factor(cdr_h_pred_u_lev, levels = violence_lvs),
    tst = ifelse(cdr_h_lev == cdr_h_pred_lev, 1, 0),
    tst2 = ifelse(
      cdr_h_lev == cdr_h_pred_lev |
        cdr_h_lev == cdr_h_pred_l_lev |
        cdr_h_lev == cdr_h_pred_u_lev,
      1,
      0
    ),
  )

tst3 <-
  tst2 |>
  select(
    year,
    cod_dpto,
    dpto,
    cod_munic,
    munic,
    dts_v,
    cdr_h,
    cdr_pred2,
    cdr_h_lev,
    cdr_h_pred_lev,
    tst,
    tst2
  )

# correspondencia total en municipios-años
tst3 |>
  summarise(
    n = n(),
    tst = sum(tst),
    tst2 = sum(tst2),
  ) |>
  mutate(per = tst / n, per2 = tst2 / n)

# correspondencia total en volumen de homicidios
tst3 |>
  select(year, cod_dpto, dpto, cod_munic, munic, dts_v, tst, tst2) |>
  pivot_longer(
    cols = c(tst, tst2),
    names_to = "type",
    values_to = "match"
  ) %>%
  mutate(
    type = ifelse(type == "tst", "Valor central", "Con incertidumbre"),
    type = factor(type, levels = c("Valor central", "Con incertidumbre"))
  ) |>
  summarise(
    dts_ok = sum(dts_v * match),
    dts_tot = sum(dts_v),
    .by = c(type)
  ) |>
  mutate(per = dts_ok / dts_tot)


yrs <-
  tst3 |>
  summarise(
    n = n(),
    tst = sum(tst),
    tst2 = sum(tst2),
    .by = c(year)
  ) |>
  mutate(per = tst / n, per2 = tst2 / n)

yrs |>
  ggplot() +
  geom_point(aes(year, per)) +
  geom_point(aes(year, per2), col = "red") +
  theme_bw()

ggsave("figures/pred_years_exc.png", w = 5, h = 2)

dpts <-
  tst3 |>
  summarise(
    tst = sum(tst),
    tst2 = sum(tst2),
    n = n(),
    .by = c(dpto)
  ) |>
  mutate(per = tst / n, per2 = tst2 / n)

dpts |>
  ggplot() +
  geom_point(aes(per, dpto)) +
  geom_point(aes(per2, dpto), col = "red") +
  theme_bw()

ggsave("figures/pred_dptos_exc.png")

tst3 |>
  summarise(
    tst = sum(tst),
    tst2 = sum(tst2),
    n = n(),
    .by = c(cdr_h_lev)
  ) |>
  mutate(per = tst / n, per2 = tst2 / n)

tst3 |>
  ggplot() +
  geom_point(aes(log(cdr_h), log(cdr_pred2))) +
  labs(y = "Tasa estimada (log)", x = "Tasa observada (log)") +
  theme_bw()

tst3 |>
  ggplot(aes(x = log(cdr_h), y = log(cdr_pred2))) + # Move aes here to share across layers
  geom_point(alpha = 0.5) +
  geom_smooth(method = "lm", color = "blue", se = TRUE) + # Adds the regression line
  stat_cor(aes(label = ..rr.label..), label.x = -10) + # Adds R-squared or correlation
  stat_regline_equation(label.x = -10, label.y = -3) + # Adds the equation
  labs(
    y = "Tasa estimada (log)",
    x = "Tasa observada (log)",
    title = "Validation of CDR Estimates"
  ) +
  theme_bw()
ggsave("figures/cdr_homicides_observed_vs_estimated_exc.png")

tst |>
  summarise(
    pred_dts_v = sum(pred_dts_v2),
    pred_dts_v_l = sum(pred_dts_v_l2),
    pred_dts_v_u = sum(pred_dts_v_u2),
    dts_v = sum(dts_v),
  )

yrs <-
  tst |>
  summarise(
    pred_dts_v = sum(pred_dts_v),
    pred_dts_v_l = sum(pred_dts_v_l),
    pred_dts_v_u = sum(pred_dts_v_u),
    pred_dts_v2 = sum(pred_dts_v2),
    pred_dts_v_l2 = sum(pred_dts_v_l2),
    pred_dts_v_u2 = sum(pred_dts_v_u2),
    dts_v = sum(dts_v),
    pop = sum(pop),
    .by = c(year)
  ) |>
  mutate(
    cdr = dts_v / pop,
    cdr_pred = pred_dts_v / pop,
    cdr_pred_l = pred_dts_v_l / pop,
    cdr_pred_u = pred_dts_v_u / pop,
    cdr_pred2 = pred_dts_v2 / pop,
    cdr_pred_l2 = pred_dts_v_l2 / pop,
    cdr_pred_u2 = pred_dts_v_u2 / pop
  )

yrs |>
  ggplot() +
  geom_line(aes(year, cdr), size = 2, alpha = 0.5) +
  geom_line(aes(year, cdr_pred), col = "red", lty = "dashed") +
  geom_ribbon(
    aes(year, ymin = cdr_pred_l, ymax = cdr_pred_u),
    alpha = 0.2,
    fill = "red"
  ) +
  geom_line(aes(year, cdr_pred2), col = "blue", lty = "dashed") +
  geom_ribbon(
    aes(year, ymin = cdr_pred_l2, ymax = cdr_pred_u2),
    alpha = 0.2,
    fill = "blue"
  ) +
  theme_bw()

ggsave(
  "figures/cdr_homicides_observed_vs_estimated_years_exc.png",
  w = 5,
  h = 2
)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# mapa de municipios con grados de violencia discretos ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

cols4 <- c("#fcbf49", "#f77f00", "#d62828", "#003049")
cols4 <- c("#f6aa1c", "#bc3908", "#941b0c", "#621708")
plot_discret <- function(yr = 2000) {
  tst_mapa <-
    tst3 %>%
    filter(year %in% yr) |>
    select(year, cod_dpto, dpto, cod_munic, munic, cdr_h_lev, cdr_h_pred_lev) |>
    pivot_longer(
      cols = c(cdr_h_lev, cdr_h_pred_lev),
      names_to = "metric",
      values_to = "cdr"
    ) %>%
    # Renombramos para que el título del facet sea elegante
    mutate(
      metric = ifelse(
        metric == "cdr_h_lev",
        "Tasa observada",
        "Tasa estimada"
      ),
      metric = factor(
        metric,
        levels = c("Tasa observada", "Tasa estimada")
      )
    )

  # 2. Ahora el left_join funcionará perfectamente
  mapa_final <- left_join(mapa_sf, tst_mapa, by = c("id" = "cod_munic")) |>
    drop_na(metric)

  # 4. Crear el mapa de calor (Choropleth)
  ggplot(mapa_final) +
    geom_sf(aes(fill = cdr), color = NA) +
    facet_grid(year ~ metric) +
    # scale_fill_viridis_c(option = "inferno", name = "Tasa por 100k") +
    labs(
      title = "Tasas de homicidios observadas y estimadas",
      subtitle = "Basado en estructura de mortalidad masculina",
      caption = "Fuente: Estimaciones propias con glmmTMB"
    ) +
    scale_fill_manual(values = cols4) +
    theme_void() +
    theme(legend.position = "bottom", legend.direction = "horizontal")

  ggsave(paste0("figures/mapa_comp_disc_", yr, "_exc.png"), w = 8, h = 4)
}

for (yr in seq(1985, 2015, 5)) {
  plot_discret(yr)
}

tst_mapa <-
  tst3 %>%
  filter(year %in% seq(1985, 2015, 5)) |>
  select(year, cod_dpto, dpto, cod_munic, munic, cdr_h_lev, cdr_h_pred_lev) |>
  pivot_longer(
    cols = c(cdr_h_lev, cdr_h_pred_lev),
    names_to = "metric",
    values_to = "cdr"
  ) %>%
  # Renombramos para que el título del facet sea elegante
  mutate(
    metric = ifelse(
      metric == "cdr_h_lev",
      "Tasa observada",
      "Tasa estimada"
    ),
    metric = factor(
      metric,
      levels = c("Tasa observada", "Tasa estimada")
    )
  )

# 2. Ahora el left_join funcionará perfectamente
mapa_final <- left_join(mapa_sf, tst_mapa, by = c("id" = "cod_munic")) |>
  drop_na(metric)

# mapa
ggplot(mapa_final) +
  geom_sf(aes(fill = cdr), color = NA) +
  facet_grid(year ~ metric) +
  # scale_fill_viridis_c(option = "inferno", name = "Tasa por 100k") +
  scale_fill_manual(values = cols4) +
  labs(
    title = "Tasas de homicidios observadas y estimadas",
    subtitle = "Basado en estructura de mortalidad masculina",
    caption = "Fuente: Estimaciones propias con glmmTMB"
  ) +
  theme_void() +
  theme(legend.position = "bottom", legend.direction = "horizontal")

ggsave(paste0("figures/mapa_comp_yrs_disc_exc.pdf"), w = 8, h = 20)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# mapa de municipios con el mismo grado de violencia ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

tst_mapa <-
  tst3 %>%
  filter(year %in% seq(1985, 2015, 5)) |>
  select(year, cod_dpto, dpto, cod_munic, munic, tst, tst2) |>
  pivot_longer(
    cols = c(tst, tst2),
    names_to = "type",
    values_to = "match"
  ) %>%
  mutate(
    match = ifelse(match == 1, "si", "no"),
    match = factor(
      match,
      levels = c("si", "no")
    ),
    type = ifelse(type == "tst", "Valor central", "Con incertidumbre"),
    type = factor(type, levels = c("Valor central", "Con incertidumbre"))
  )


# 2. Ahora el left_join funcionará perfectamente
mapa_final <- left_join(mapa_sf, tst_mapa, by = c("id" = "cod_munic")) |>
  drop_na(match)

cols2 <- c("#6a994e", "#bc4749")

# 4. Crear el mapa de calor (Choropleth)
ggplot(mapa_final) +
  geom_sf(aes(fill = match), color = NA) +
  facet_grid(year ~ type) +
  # scale_fill_viridis_c(option = "inferno", name = "Tasa por 100k") +
  scale_fill_manual(values = cols2) +
  labs(
    title = "Misma intensidad homicidios observadas y estimadas",
  ) +
  theme_void() +
  theme(legend.position = "bottom", legend.direction = "horizontal")

# ggsave("figures/mapa_comp_2005_match.png", w = 8, h = 4)

ggsave("figures/mapa_comp_yrs_match_exc.pdf", w = 8, h = 20)


tst_all <-
  tst3 %>%
  select(year, cod_dpto, dpto, cod_munic, munic, tst, tst2) |>
  pivot_longer(
    cols = c(tst, tst2),
    names_to = "type",
    values_to = "match_num"
  ) %>%
  mutate(
    match = ifelse(match_num == 1, "si", "no"),
    match = factor(match, levels = c("si", "no")),
    munic2 = paste0(dpto, "-", munic),
    type = ifelse(type == "tst", "Valor central", "Con incertidumbre"),
    type = factor(type, levels = c("Valor central", "Con incertidumbre"))
  )

tst_all |>
  filter(type == "Con incertidumbre") |>
  ggplot() +
  geom_tile(aes(x = year, y = munic2, fill = match)) +
  scale_fill_manual(values = cols2) +
  # facet_grid(dpto ~ .) +
  coord_cartesian(expand = FALSE) +
  theme_bw() +
  theme(
    axis.text.y = element_text(size = 3),
    axis.text.x = element_text(size = 7),
    legend.position = "bottom",
    legend.direction = "horizontal",
    axis.title.y = element_blank()
  )

ggsave("figures/munics_yrs_match_exc.pdf", w = 5, h = 40)

tst_all |>
  filter(type == "Con incertidumbre") |>
  filter(cod_munic %in% munic_lrg) |>
  ggplot() +
  geom_tile(aes(x = year, y = munic2, fill = match)) +
  scale_fill_manual(values = cols2) +
  # facet_grid(dpto ~ .) +
  coord_cartesian(expand = FALSE) +
  scale_x_continuous(breaks = seq(1985, 2015, 5)) +
  theme_bw() +
  theme(
    # axis.text.y = element_text(size = 3),
    # axis.text.x = element_text(size = 7),
    legend.position = "bottom",
    legend.direction = "horizontal",
    axis.title.y = element_blank()
  )

ggsave("figures/munics_yrs_match_few_exc.png", w = 7, h = 5)


munic_per <-
  tst_all |>
  summarise(n = n(), si = sum(match_num), .by = c(cod_munic, munic2, type)) |>
  mutate(per = 100 * si / n)

#
# 2. Ahora el left_join funcionará perfectamente
mapa_final <- left_join(mapa_sf, munic_per, by = c("id" = "cod_munic")) |>
  drop_na(type)

# 4. Crear el mapa de calor (Choropleth)
ggplot(mapa_final) +
  geom_sf(aes(fill = per), color = NA) +
  facet_wrap(~type) +
  scale_fill_viridis_c(option = "inferno", name = "% de match") +
  labs(
    title = "Porcentaje de años con predicción correcta"
  ) +
  theme_void() # Quita coordenadas y fon
# ggsave(paste0("figures/mapa_comp_", yr, ".png"), dpi = 300, w = 8, h = 4)

# diferencias de total de homicidios en todo el tiempo
munic_sum <-
  tst2 |>
  mutate(
    munic2 = paste0(dpto, "-", munic)
  ) |>
  summarise(
    dts = sum(dts_v),
    pred = sum(pred_dts_v2),
    pred_l = sum(pred_dts_v_l2),
    pred_u = sum(pred_dts_v_u2),
    .by = c(cod_munic, munic2)
  ) |>
  mutate(
    diff = ((pred / dts) - 1) * 100,
    within = ifelse(dts >= pred_l & dts <= pred_u, "Dentro", "Fuera")
  ) |>
  mutate(
    diff_disc = cut(
      diff,
      breaks = c(-100, -50, -20, -10, -5, 0, 5, 10, 20, 50, 100),
      include.lowest = TRUE
    )
  )

munic_sum |>
  summarise(n = n(), .by = c(diff_disc)) |>
  mutate(per = n / sum(n)) |>
  arrange(-per)


mapa_munic_sum <- left_join(mapa_sf, munic_sum, by = c("id" = "cod_munic"))
# 4. Crear el mapa de calor (Choropleth)

cols9 <- c(
  "#B2182B",
  "#D6604D",
  "#F4A582",
  "#FDDBC7",
  "#F7F7F7",
  "#D1E5F0",
  "#92C5DE",
  "#4393C3",
  "#2166AC"
)

cols9 <- c(
  "#D6604D",
  "#F4A582",
  "#FDDBC7",
  "#F7F7F7",
  "#F7F7F7",
  "#D1E5F0",
  "#92C5DE",
  "#4393C3",
  "#2166AC"
)

ggplot(mapa_munic_sum) +
  geom_sf(aes(fill = diff_disc), color = NA) +
  scale_fill_manual(values = cols9, na.translate = FALSE) +
  labs(
    title = "Precisión de predicción de homicidios totales",
    fill = "Diferencia porcentual"
  ) +
  theme_void() # Quita coordenadas y fon

ggsave("figures/map_perc_precisssion_exc.png")

ggplot(mapa_munic_sum) +
  geom_sf(aes(fill = within), color = NA) +
  scale_fill_manual(values = cols2, na.translate = FALSE) +
  labs(
    title = "Suma total de homicidios 1985-2017 dentro y fuera de las estimaciones"
  ) +
  theme_void() # Quita coordenadas y fon
ggsave("figures/map_years_within_pred_exc.png")
