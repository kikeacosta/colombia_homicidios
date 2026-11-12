# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 63. Predictive check of the departmental homicide backcast: figures only
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Redraws the predictive-check figure of 60 (its section 6.5) from the tables
# that 60 saves, so the plot can be changed in seconds. It does NOT estimate
# anything: 60 takes about five minutes because it fits the model, and has to
# be run again only when the model or its inputs change.
#
# figure   observed against predicted homicides by unit. Black: the original
#          data, i.e. the registered counts as published, with no adjustment
#          for under-registration, one symbol per source: anuarios to 1965
#          (hollow circles; cells that the model reads as gross errors are
#          not drawn), EEVV from 1979 (points) and the Policia in the years
#          the model uses it, 1962-1997 (hollow triangles). Grey strips:
#          blocks of years in which the homicide counts were hidden and
#          predicted back with the inputs of each variant (N nothing, S sex
#          ratio, SP sex ratio + Policia; P Policia alone is also in the
#          table). N is an interpolation: inside the block the model gets
#          only the total of registered deaths of each year. Cream strip,
#          1966-1978: no count from vital statistics exists, so the same
#          readings are shown without a truth; the Policia is the only count.
#
#          the figure is drawn twice: for the units chosen in the options,
#          and for all 15 units in pages of four (2 x 2), in alphabetical
#          order of the label, with the same size and legend on every page.
#
# options  at the top of section 1: units, variants, rate or count, log or
#          linear scale, the variant that gets the 90 % band.
#
# limits   a unit that is not in homicide_backcast_gap_readings.csv is drawn
#          with no readings in the cream strip, and the script says so (the
#          table holds the 15 units since 60 writes all of them).
#
# inputs   output/tables/homicide_backcast_validation_predictions.csv
#          output/tables/homicide_backcast_gap_readings.csv
#          output/tables/homicide_backcast_dept_1915-2019.csv
# outputs  figures/08_backcast/backcast_predictive_check.png
#          figures/08_backcast/backcast_predictive_check_all_1.png ... _4.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. options ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# units of the main figure, in panel order. names as in the column `unit` of
# the tables: antioquia, atlantico, bolivar, boyaca, caldas, cauca,
# cundinamarca, huila, magdalena, narino, norte_de_santander, santander,
# tolima, valle_del_cauca, territorios
units <- c("antioquia", "valle_del_cauca", "tolima", "bolivar")
out_file <- "figures/08_backcast/backcast_predictive_check.png"

# all 15 units in pages: files <out_all>_1.png, _2.png, ...
all_pages <- TRUE
per_page <- 4
out_all <- "figures/08_backcast/backcast_predictive_check_all"

# predictions to draw: any of "N", "S", "P", "SP"
variants <- c("N", "S", "SP")
band_variant <- "S" # variant that gets the 90 % band (NA for none)

measure <- "rate" # "rate" (per 100,000) or "count"
log_scale <- TRUE

pol_years <- 1962:1997 # years of the Policia counts to draw: the ones the model uses (the table goes to 2002)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. tables ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
val <- read_csv("output/tables/homicide_backcast_validation_predictions.csv", show_col_types = FALSE)
gap <- read_csv("output/tables/homicide_backcast_gap_readings.csv", show_col_types = FALSE)
est <- read_csv("output/tables/homicide_backcast_dept_1915-2019.csv", show_col_types = FALSE)

unit_lab <- est |> distinct(unit, unit_label) |> deframe()
stopifnot(all(units %in% names(unit_lab)), all(variants %in% c("N", "S", "P", "SP")),
          measure %in% c("rate", "count"))

blocks <- c("1946-1953", "1954-1965", "1979-1984", "1985-1997", "1998-2010") # the ones that do not overlap
var_code <- c("N: nothing in the block" = "N", "S: sex ratio" = "S", "P: Policia" = "P", "SP: sex ratio + Policia" = "SP")
var_lab <- c(N = "Sin usar datos del bloque (interpolación)", S = "Razón de sexos", P = "Policía", SP = "Razón de sexos + Policía")
var_col <- c(N = "grey50", S = "#2a78d6", P = "#b0471c", SP = "#eb6834")
var_col_name <- c(N = "gris", S = "azul", P = "marrón", SP = "naranja")
var_lty <- c(N = "22", S = "solid", P = "42", SP = "solid")
# original data are all black, one symbol per source
shp_lab <- c(anu = "Anuarios", eevv = "EEVV", pol = "Policía")
shp_val <- c(anu = 21, eevv = 16, pol = 24) # 21 and 24 are filled in white
ink <- "#1f1f1e"

# counts are turned into the measure asked for
as_measure <- function(n, pop) if (measure == "rate") 1e5 * n / pop else n

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. series, all units ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# observed: EEVV where it exists, else the anuario unless it is a gross error
obs <- est |>
  filter(year >= 1938, year <= 2014) |>
  mutate(has_eevv = !is.na(hom_eevv) & hom_eevv > 0,
         n = ifelse(has_eevv, hom_eevv,
                    ifelse(!is.na(anuario_gross_error_prob) & anuario_gross_error_prob > 0.5, NA, hom_anuario)),
         src = ifelse(has_eevv, "EEVV", "anuarios"), # the observed line is not drawn across 1966-78
         y = as_measure(n, pop)) |>
  filter(!is.na(y), y > 0)

# predicted: the hidden blocks and the readings of 1966-1978
pred <- bind_rows(val |> filter(block %in% blocks), gap) |>
  mutate(code = var_code[variant]) |>
  filter(code %in% variants) |>
  mutate(variante = factor(var_lab[code], var_lab[variants]),
         y = as_measure(hom_pred, pop), lo = as_measure(hom_pred_lo90, pop), hi = as_measure(hom_pred_hi90, pop))

# original Policia counts
pol <- est |>
  filter(year %in% pol_years, !is.na(hom_policia), hom_policia > 0) |>
  mutate(y = as_measure(hom_policia, pop))

rect <- tibble(block = c(blocks, "1966-1978")) |>
  mutate(x0 = as.numeric(substr(block, 1, 4)) - 0.5, x1 = as.numeric(substr(block, 6, 9)) + 0.5,
         tipo = ifelse(block == "1966-1978", "gap", "val"))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 4. figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
base <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
        legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey40", hjust = 0))

txt_measure <- paste0(if (measure == "rate") "Homicidios por 100.000 habitantes" else "Número de homicidios",
                      if (log_scale) ", escala logarítmica" else "")
txt_band <- if (is.na(band_variant)) "" else
  paste0(" Banda ", var_col_name[band_variant], ": intervalo de 90 % con ", str_to_lower(var_lab[band_variant]), ".")
txt_readings <- if (length(variants) == 1) "la misma lectura" else paste("las mismas", length(variants), "lecturas")
txt_readings <- sub(" 2 ", " dos ", sub(" 3 ", " tres ", sub(" 4 ", " cuatro ", txt_readings)))

# one figure for the units `u`, in that order, with `n_col` columns. `page`
# is added to the title
draw_check <- function(u, n_col, page = "") {
  on_panel <- function(z) z |> filter(unit %in% u) |> mutate(panel = factor(unit_lab[unit], unit_lab[u]))
  obs_u <- on_panel(obs)
  lab <- tibble(panel = factor(unit_lab[u], unit_lab[u]), x = 1972, label = "sin dato para\ncontrastar")
  ggplot() +
    geom_rect(data = rect, aes(xmin = x0, xmax = x1, ymin = 0, ymax = Inf, fill = tipo)) +
    scale_fill_manual(values = c(val = "grey95", gap = "#fbefe1"), guide = "none") +
    geom_vline(xintercept = c(1953.5, 1965.5, 1978.5, 1984.5, 1997.5), colour = "white", linewidth = 0.9) +
    geom_ribbon(data = on_panel(pred) |> filter(code %in% band_variant), aes(year, ymin = lo, ymax = hi, group = block),
                fill = var_col[band_variant], alpha = 0.15) +
    geom_line(data = on_panel(pred), aes(year, y, colour = variante, linetype = variante, group = interaction(block, variante)), linewidth = 0.6) +
    geom_point(data = on_panel(pol), aes(year, y, shape = shp_lab[["pol"]]), colour = ink, fill = "white", size = 1.3, stroke = 0.5) +
    geom_line(data = obs_u, aes(year, y, group = src), colour = ink, linewidth = 0.35) +
    geom_point(data = obs_u |> filter(src == "anuarios"), aes(year, y, shape = shp_lab[["anu"]]), colour = ink, fill = "white", size = 1.2, stroke = 0.5) +
    geom_point(data = obs_u |> filter(src == "EEVV"), aes(year, y, shape = shp_lab[["eevv"]]), colour = ink, size = 0.9) +
    scale_shape_manual(values = setNames(shp_val, shp_lab), limits = unname(shp_lab),
                       guide = guide_legend(order = 2, override.aes = list(size = 1.7, stroke = 0.5, fill = "white"))) +
    guides(colour = guide_legend(order = 1), linetype = guide_legend(order = 1)) +
    geom_text(data = lab, aes(x, Inf, label = label), vjust = 1.3, size = 2.7, colour = "grey30", lineheight = 0.9) +
    scale_colour_manual(values = setNames(var_col[variants], var_lab[variants]), drop = FALSE) +
    scale_linetype_manual(values = setNames(var_lty[variants], var_lab[variants]), drop = FALSE) +
    (if (log_scale) scale_y_log10(labels = scales::label_number(drop0trailing = TRUE))
     else scale_y_continuous(labels = scales::label_number(drop0trailing = TRUE),
                             expand = expansion(mult = c(0, 0.05)))) +
    facet_wrap(~panel, ncol = n_col, scales = "free_y") +
    labs(title = paste0("Capacidad predictiva: homicidios observados y predichos en años ocultos al modelo", page),
         subtitle = paste0(txt_measure, ". En negro, los datos originales, sin ajuste por subregistro: anuarios hasta 1965, EEVV desde 1979 y Policía en ", min(pol_years), "-", max(pol_years), ".\n",
                           "Franjas grises: el modelo no vio los homicidios de esos años y los predijo con el insumo indicado.", txt_band, "\n",
                           "Franja crema, 1966-1978: no hay homicidios en las estadísticas vitales para contrastar; se muestran ", txt_readings,
                           "; el único conteo es el de la Policía."),
         x = NULL, y = NULL, colour = NULL, linetype = NULL,
         caption = paste0(if ("SP" %in% variants) "El modelo usa la Policía solo en 1962-1997; en 1966-1978 la línea naranja es el modelo completo, que además usa el total nacional de la OMS.\n" else "",
                          "Parámetros estimados con todos los datos; solo se ocultan los homicidios del bloque.")) +
    base
}

# 4.1 the units chosen in the options
n_col <- if (length(units) <= 4) 2 else 3
ggsave(out_file, draw_check(units, n_col), w = if (n_col == 2) 12 else 13,
       h = 1.2 + 3.4 * ceiling(length(units) / n_col), bg = "white", dpi = 160)
cat("figura:", out_file, "\n")

# 4.2 all the units in pages of `per_page`, alphabetical order of the label.
#     every page has the size of a full one, so the last one leaves a blank
all_units <- names(unit_lab)[str_order(unit_lab, locale = "es")]
if (all_pages) {
  pages <- split(all_units, ceiling(seq_along(all_units) / per_page))
  for (i in seq_along(pages)) {
    f <- paste0(out_all, "_", i, ".png")
    ggsave(f, draw_check(pages[[i]], 2, paste0(" (", i, " de ", length(pages), ")")),
           w = 12, h = 1.2 + 3.4 * ceiling(per_page / 2), bg = "white", dpi = 160)
    cat("figura:", f, "\n")
  }
}

no_gap <- setdiff(if (all_pages) all_units else units, gap$unit)
if (length(no_gap) > 0) {
  message("Sin lecturas de 1966-1978 en homicide_backcast_gap_readings.csv para: ", paste(no_gap, collapse = ", "),
          ". Esa tabla sale del script 60.")
}
