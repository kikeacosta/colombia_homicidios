# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 90. Observed and estimated violent deaths by state in the most dynamic
#     year of each country, hidden in a block centred on that year
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 88 used 2015 for every country, a quiet year for most of them. Here each
# country gets the year of its largest change, hidden in a block of 11 years
# centred on it (5 years each side), so that the year is as far from the
# known years on both sides. A first version took the year from the blocks
# of 72, where it could sit next to a known year (Mexico 2011 at the end of
# 2004-2011, with 2012 known), which flatters interpolation.
#   Colombia 1991   peak of the late 1980s and early 1990s, hidden 1986-1996
#   Mexico   2011   peak of the war on drugs (x2.7 since 2007), hidden 2006-2016
#   US       1991   peak of the early 1990s, hidden 1986-1996
#   Brazil   2014   the data end in 2020, so the block cannot be centred on
#                   the 2017 maximum; 2009-2019 covers the whole rise to 2017
#                   and the fall after it
#   Ecuador  2023   violent deaths x5 since 2020; forward test, 2018-2024
#                   hidden (5 years before, as elsewhere) with data only up
#                   to 2017 (cannot be centred: no data after 2024)
# methods, refitted on each block with the parameters of 72: N
# interpolation (or carrying the last level forward), S state-space with
# the sex ratio, B1 simple regression with the national total, D direct
# estimator (the unit's own non-violent ratio from the 5 years on each
# side). All ages.
#
# input    data_inter/intl_datasets.rds (72)
#          output/tables/intl_validation_parameters.csv (72)
# output   output/tables/intl_dynamic_years_predictions.csv
#          output/tables/intl_dynamic_years_scores.csv
#          figures/09_international/intl_dynamic_years.png
#          figures/09_international/intl_dynamic_years_over_time.png
#          figures/09_international/intl_dynamic_years_top_unit.png
#          output/tables/intl_dynamic_years_block_predictions.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(glmmTMB)
options(width = 200)
k_side <- 5
pick <- tribble(~country, ~year, ~from, ~to,
                "colombia", 1991, 1986, 1996,
                "mexico", 2011, 2006, 2016,
                "brazil", 2014, 2009, 2019,
                "us", 1991, 1986, 1996,
                "ecuador", 2023, 2018, 2024)
dd <- readRDS("data_inter/intl_datasets.rds"); datasets <- dd$datasets
pars <- read_csv("output/tables/intl_validation_parameters.csv", show_col_types = FALSE)

direct_block <- function(md, pi_m, yrs_b, b) {
  md <- md |> mutate(lnv = log(pmax(dm - pi_m * h, 1) / pmax(df - (1 - pi_m) * h, 1)))
  lo <- min(yrs_b); hi <- max(yrs_b)
  L <- md |> filter(year < lo) |> slice_max(year, n = k_side, by = unit) |> summarise(l = mean(lnv), yl = mean(year), .by = unit)
  R <- md |> filter(year > hi) |> slice_min(year, n = k_side, by = unit) |> summarise(r = mean(lnv), yr = mean(year), .by = unit)
  out <- md |> filter(year %in% yrs_b) |> left_join(L, by = "unit")
  out <- if (nrow(R)) left_join(out, R, by = "unit") else mutate(out, r = NA_real_, yr = NA_real_)
  out |> mutate(w = ifelse(is.na(yr), 0, (year - yl) / (yr - yl)), lr = (1 - w) * l + w * coalesce(r, l),
                hom_pred = pmax((dm - exp(lr) * df) / (pi_m - exp(lr) * (1 - pi_m)), 1)) |>
    transmute(block = b, model = "D: direct", unit, unit_label, year, d, hom_obs = h, hom_pred)
}

pred <- list()
for (i in seq_len(nrow(pick))) {
  cc <- pick$country[i]; ds <- datasets[[paste(cc, "all")]]; md <- ds$md$md; pi_m <- ds$md$pi_m
  b <- paste0(pick$from[i], "-", pick$to[i]); blk <- setNames(list(pick$from[i]:pick$to[i]), b)
  pr <- pars |> filter(country == cc, ages == "all")
  cat(cc, b, "\n")
  pred[[cc]] <- bind_rows(intl_validate(md, c(pr$s_eta, pr$s_u, pr$s_0), pi_m, blk), intl_simple(md, blk), direct_block(md, pi_m, blk[[1]], b)) |>
    mutate(country = cc, unit = as.character(unit), m = sub(":.*", "", model), .before = 1) |>
    filter(m %in% c("N", "S", "B1", "D")) |>
    select(country, block, year, m, unit, unit_label, d, hom_obs, hom_pred)
}
pred_all <- bind_rows(pred)
write_csv(pred_all, "output/tables/intl_dynamic_years_block_predictions.csv")
pred <- pred_all |> semi_join(pick, by = c("country", "year"))
write_csv(pred, "output/tables/intl_dynamic_years_predictions.csv")


# national change since the year before the block, to say how big the jump was
sc <- pred |> filter(hom_obs > 0) |>
  summarise(err = 100 * median(abs(hom_pred / hom_obs - 1)), nat = 100 * (sum(hom_pred) / sum(hom_obs) - 1),
            r_log = cor(log(pmax(hom_pred, 1)), log(hom_obs)), share = 100 * sum(hom_obs) / sum(d), units = n(), .by = c(country, year, m))
write_csv(sc, "output/tables/intl_dynamic_years_scores.csv")
cat("== median absolute error by unit (%), national total error (%), in the most dynamic year ==\n")
print(as.data.frame(sc |> mutate(across(c(err, nat, share), ~ round(.x, 1)), r_log = round(r_log, 2)) |>
                      arrange(match(country, pick$country), match(m, c("N", "S", "B1", "D")))), row.names = FALSE)

pais <- c(colombia = "Colombia, 1991\n(ocultos 1986-1996)", mexico = "México, 2011\n(ocultos 2006-2016)", brazil = "Brasil, 2014\n(ocultos 2009-2019)",
          us = "EE. UU., 1991\n(ocultos 1986-1996)", ecuador = "Ecuador, 2023\n(pronóstico: ocultos\n2018-2024)")
met <- c(N = "Sin pistas\n(interpolación)", S = "1. Estados ocultos\n(razón de sexos)", B1 = "2. Regresión simple\n(+ total nacional)", D = "3. Directo\n(estimador de España)")
fd <- pred |> filter(hom_obs > 0) |> left_join(sc |> select(country, m, err, nat, share), by = c("country", "m")) |>
  mutate(fila = factor(paste0(pais[country], "\n", format(round(share, 1), decimal.mark = ","), " % violentas"),
                       paste0(pais[pick$country], "\n", format(round(sc$share[match(paste(pick$country, "S"), paste(sc$country, sc$m))], 1), decimal.mark = ","), " % violentas")),
         metodo = factor(met[m], met), hom_pred = pmax(hom_pred, 1))
lab <- fd |> distinct(fila, metodo, err, nat) |>
  mutate(txt = paste0("error mediano ", round(err), " %\ntotal nacional ", ifelse(nat >= 0, "+", ""), round(nat), " %"))
fig <- ggplot(fd, aes(hom_obs, hom_pred)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey55", linetype = "22") +
  geom_point(aes(colour = metodo), size = 1.7, alpha = 0.8, show.legend = FALSE) +
  geom_text(data = lab, aes(x = 0, y = Inf, label = txt), hjust = -0.05, vjust = 1.25, size = 2.9, colour = "grey20", lineheight = 0.9, inherit.aes = FALSE) +
  scale_x_log10(labels = scales::label_number(big.mark = ".")) + scale_y_log10(labels = scales::label_number(big.mark = ".")) +
  scale_colour_manual(values = c("grey50", "#2a78d6", "#1baf7a", "#eb6834")) +
  facet_grid(fila ~ metodo, scales = "free") +
  labs(title = "¿Capta cada método el año de mayor cambio de cada país sin haberlo visto?",
       subtitle = paste0("Cada punto es un estado, departamento o provincia. Eje x: muertes violentas registradas. Eje y: estimadas sin ver ese año\n",
                         "ni los 5 anteriores ni los 5 posteriores (Ecuador: pronóstico, sin datos después de 2017). Sobre la línea punteada, la estimación es exacta.\n",
                         "Todas las edades. Escalas logarítmicas; las estimaciones negativas o nulas se dibujan en 1."),
       x = "muertes violentas registradas", y = "muertes violentas estimadas") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 13), strip.text = element_text(face = "bold"),
        strip.text.y = element_text(angle = 0, hjust = 0))
ggsave("figures/09_international/intl_dynamic_years.png", fig, w = 13, h = 12.5, bg = "white", dpi = 160)

# over time: the national sum of each method across the hidden block, against
# the registered series, and the median error by unit in each year.
# the simple regression is rescaled to the registered national total, so its
# national sum is the registered one: it is drawn wide, under the black line,
# so that it shows where it coincides.
obs <- bind_rows(lapply(pick$country, function(cc) datasets[[paste(cc, "all")]]$md$md |>
  summarise(h = sum(h), .by = year) |> mutate(country = cc))) |>
  left_join(pick |> select(country, from, to), by = "country") |>
  filter(year >= from - 8, year <= to + 6)
nat_m <- pred_all |> filter(m %in% c("N", "S", "D")) |> summarise(h = sum(hom_pred), .by = c(country, year, m))
nat_b <- pred_all |> filter(m == "B1") |> summarise(h = sum(hom_pred), .by = c(country, year, m))
err_y <- pred_all |> filter(hom_obs > 0) |> summarise(err = 100 * median(abs(hom_pred / hom_obs - 1)), .by = c(country, year, m))
pais2 <- c(colombia = "Colombia (ocultos 1986-1996)", mexico = "México (ocultos 2006-2016)", brazil = "Brasil (ocultos 2009-2019)",
           us = "EE. UU. (ocultos 1986-1996)", ecuador = "Ecuador (pronóstico desde 2017)")
mcol <- c(Registradas = "black", N = "grey55", S = "#2a78d6", B1 = "#1baf7a", D = "#eb6834")
mlab <- c(Registradas = "Registradas", N = "Sin pistas", S = "1. Estados ocultos", B1 = "2. Regresión simple (+ total nacional)", D = "3. Directo")
lay <- function(x) mutate(x, pais = factor(pais2[country], pais2[pick$country]))
rect <- pick |> transmute(country, x0 = from - 0.5, x1 = to + 0.5) |> lay()
p_top <- ggplot() +
  geom_rect(data = rect, aes(xmin = x0, xmax = x1, ymin = -Inf, ymax = Inf), fill = "grey93") +
  geom_line(data = lay(nat_b), aes(year, h / 1000, colour = m), linewidth = 3, alpha = 0.45) +
  geom_line(data = lay(obs), aes(year, h / 1000, colour = "Registradas"), linewidth = 0.9) +
  geom_point(data = lay(obs), aes(year, h / 1000, colour = "Registradas"), size = 1.2) +
  geom_line(data = lay(nat_m), aes(year, h / 1000, colour = m, linetype = m), linewidth = 0.8) +
  geom_vline(data = lay(pick), aes(xintercept = year), colour = "grey40", linetype = "13", linewidth = 0.3) +
  scale_colour_manual(values = mcol, labels = mlab, breaks = names(mlab), limits = names(mlab), name = NULL) +
  scale_linetype_manual(values = c(N = "22", S = "solid", D = "solid"), guide = "none") +
  facet_wrap(~pais, nrow = 1, scales = "free") + expand_limits(y = 0) +
  labs(title = "Muertes violentas por año: registradas y estimadas sin ver los años sombreados",
       subtitle = paste0("Arriba: total nacional (miles). Abajo: error mediano por estado o departamento en cada año (%). Franja gris: años ocultos; ",
                         "línea vertical: año de mayor cambio.\nLa regresión simple (franja verde) recibe el total nacional registrado y solo lo reparte entre las unidades: ",
                         "arriba coincide con lo registrado por construcción, y su error está abajo. Todas las edades."),
       x = NULL, y = "miles de muertes violentas") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 13),
                                        strip.text = element_text(face = "bold"))
p_bot <- ggplot(lay(err_y), aes(year, pmin(err, 100), colour = m)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1) +
  scale_colour_manual(values = mcol, labels = mlab, breaks = names(mlab), limits = names(mlab), name = NULL) +
  facet_wrap(~pais, nrow = 1, scales = "free_x") + scale_x_continuous(breaks = function(x) seq(ceiling(x[1] / 2) * 2, floor(x[2]), by = 2)) +
  labs(x = NULL, y = "error mediano por unidad (%)", caption = "Errores mayores de 100 % se dibujan en 100.") +
  theme_minimal(base_size = 10) + theme(legend.position = "none", panel.grid.minor = element_blank(), strip.text = element_blank())
fig2 <- ggpubr::ggarrange(p_top, p_bot, ncol = 1, heights = c(1.25, 1), common.legend = TRUE, legend = "bottom")
ggsave("figures/09_international/intl_dynamic_years_over_time.png", fig2, w = 16, h = 8.5, bg = "white", dpi = 160)

# the same over time for one unit per country: the most violent in the hidden
# block (highest share of violent deaths among the units with at least the
# median number of deaths), where the simple regression is a real estimate
top_u <- pred_all |> filter(m == "S") |> summarise(h = sum(hom_obs), d = sum(d), lab = first(unit_label), .by = c(country, unit)) |>
  filter(d >= median(d), .by = country) |> slice_max(h / d, n = 1, by = country) |> mutate(share = 100 * h / d)
print(as.data.frame(top_u |> mutate(share = round(share, 1))))
obs_u <- bind_rows(lapply(pick$country, function(cc) datasets[[paste(cc, "all")]]$md$md |> mutate(unit = as.character(unit), country = cc))) |>
  semi_join(top_u, by = c("country", "unit")) |>
  left_join(pick |> select(country, from, to), by = "country") |>
  filter(year >= from - 8, year <= to + 6) |> select(country, unit, year, h)
est_u <- pred_all |> semi_join(top_u, by = c("country", "unit")) |> select(country, unit, year, m, h = hom_pred)
err_u <- pred_all |> semi_join(top_u, by = c("country", "unit")) |> semi_join(pick, by = c("country", "year")) |>
  transmute(country, m, e = 100 * (hom_pred / hom_obs - 1))
lab_u <- top_u |> left_join(pick, by = "country") |>
  transmute(country, pais = paste0(lab, " (", c(colombia = "Colombia", mexico = "México", brazil = "Brasil", us = "EE. UU.", ecuador = "Ecuador")[country],
                                   ")\n", ifelse(country == "ecuador", "pronóstico desde 2017", paste0("ocultos ", from, "-", to)), "; ",
                                   format(round(share, 1), decimal.mark = ","), " % violentas"))
lay_u <- function(x) left_join(x, lab_u, by = "country") |> mutate(pais = factor(pais, lab_u$pais[match(pick$country, lab_u$country)]))
txt_u <- err_u |> mutate(lbl = paste0(c(N = "Sin pistas", S = "1", B1 = "2", D = "3")[m], ": ", ifelse(e >= 0, "+", ""), round(e), " %")) |>
  summarise(lbl = paste0("Error en el año de mayor cambio\n", paste(lbl[order(match(m, c("N", "S", "B1", "D")))], collapse = "\n")), .by = country)
fig3 <- ggplot() +
  geom_rect(data = lay_u(rect |> select(-pais)), aes(xmin = x0, xmax = x1, ymin = -Inf, ymax = Inf), fill = "grey93") +
  geom_line(data = lay_u(obs_u), aes(year, h, colour = "Registradas"), linewidth = 0.9) +
  geom_point(data = lay_u(obs_u), aes(year, h, colour = "Registradas"), size = 1.2) +
  geom_line(data = lay_u(est_u), aes(year, h, colour = m, linetype = m), linewidth = 0.8) +
  geom_vline(data = lay_u(pick |> select(country, year)), aes(xintercept = year), colour = "grey40", linetype = "13", linewidth = 0.3) +
  geom_text(data = lay_u(txt_u), aes(x = -Inf, y = Inf, label = lbl), hjust = -0.05, vjust = 1.1, size = 2.7, colour = "grey20", lineheight = 0.95) +
  scale_colour_manual(values = mcol, labels = mlab, breaks = names(mlab), limits = names(mlab), name = NULL) +
  scale_linetype_manual(values = c(N = "22", S = "solid", B1 = "solid", D = "solid"), guide = "none") +
  facet_wrap(~pais, nrow = 1, scales = "free") + expand_limits(y = 0) +
  labs(title = "La unidad más violenta de cada país: muertes violentas registradas y estimadas sin ver los años sombreados",
       subtitle = paste0("La unidad con mayor proporción de muertes violentas en los años ocultos, entre las de tamaño mediano o mayor. ",
                         "Aquí la regresión simple sí estima: reparte el total nacional según la razón de sexos de cada unidad.\n",
                         "Franja gris: años ocultos; línea vertical: año de mayor cambio, con el error de cada método en ese año. Todas las edades."),
       x = NULL, y = "muertes violentas") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 13),
                                        strip.text = element_text(face = "bold"))
ggsave("figures/09_international/intl_dynamic_years_top_unit.png", fig3, w = 16, h = 5.8, bg = "white", dpi = 160)
