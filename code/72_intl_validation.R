# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 72. Validation of the sex-ratio model of homicides by state in other
#     countries, where the homicides are known in every year
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# For each country with a panel of deaths by unit, year, sex, age band and
# cause group: fit the generic state-space model of 70, hide the violent
# deaths in blocks of years and predict them back, with nothing in the block
# (N), with the sex ratio (S) and with the sex ratio rescaled to the national
# total (ST); and the simple regression of 64 (B0, B1), refitted without each
# block. Twice: with deaths of all ages (the situation of the historical
# Colombian data) and with deaths at ages 15-44 (what microdata allow).
#
# Colombia 1979-2019 goes through the same code as a reference: 15 units,
# deaths by sex and violent deaths of the EEVV from the table of 60, all ages
# only, share of men among the violent deaths fixed at 0.90 as in 60.
#
# inputs   output/tables/intl_<country>_deaths_state_year.csv
#          (71 Brazil, 73 Mexico)
#          output/tables/intl_us_unit_year_1979-2020.csv, intl_us_male_share.csv (76)
#          output/tables/homicide_backcast_dept_1915-2019.csv   (60, Colombia)
# outputs  output/tables/intl_validation_parameters.csv
#          output/tables/intl_validation_predictions.csv
#          output/tables/intl_validation_scores.csv
#          output/tables/intl_validation_scores_units.csv
#          figures/09_international/<country>_predictive_check.png
#          figures/09_international/intl_error_by_violent_share.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(glmmTMB)

dir.create("figures/09_international", showWarnings = FALSE, recursive = TRUE)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
options(width = 200)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. countries ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# blocks: about eight years with data on both sides (interpolation).
# back: the first fifteen years, with data only afterwards. it is the test
# closest to the use of the model in Colombia, a backcast
cfg <- list(
  brazil = list(label = "Brasil", blocks = list("1985-1992" = 1985:1992, "1995-2002" = 1995:2002, "2003-2010" = 2003:2010, "2011-2018" = 2011:2018),
                back = list("1979-1993" = 1979:1993),
                fig_units = c("33", "35", "26", "29", "15", "43")),
  # Mexico: 2025 is incomplete; 2020-2021 are inflated by COVID-19 but stay
  # outside the hidden blocks. 2004-2011 holds the
  # rise of violence of 2008-2011, the hardest test of the method
  mexico = list(label = "México", years = 1990:2024, blocks = list("1996-2003" = 1996:2003, "2004-2011" = 2004:2011, "2012-2018" = 2012:2018),
                back = list("1990-2004" = 1990:2004),
                fig_units = c("08", "12", "11", "06", "15", "09")),
  # United States: the public-use files carry the state only in 1979-2004
  # United States: microdata 1979-2004 and CDC WONDER 2005-2020 (76), with
  # the narrow definition of violent deaths (no undetermined intent). 2020
  # is left out (COVID-19)
  us = list(label = "Estados Unidos", years = 1979:2019, unit_year = "output/tables/intl_us_unit_year_1979-2020.csv",
            male_share = "output/tables/intl_us_male_share.csv",
            blocks = list("1984-1991" = 1984:1991, "1992-1999" = 1992:1999, "2006-2013" = 2006:2013), back = list("1979-1993" = 1979:1993),
            fig_units = c("CA", "NY", "TX", "LA", "DC", "MN")),
  colombia = list(label = "Colombia", blocks = list("1985-1997" = 1985:1997, "1998-2010" = 1998:2010),
                  back = list("1979-1993" = 1979:1993),
                  fig_units = c("antioquia", "valle_del_cauca", "tolima", "bolivar", "cundinamarca", "santander"))
)

datasets <- list()
for (cc in setdiff(names(cfg), "colombia")) {
  if (!is.null(cfg[[cc]]$unit_year)) { # already one row per unit and year (76)
    if (!file.exists(cfg[[cc]]$unit_year)) next
    uy <- read_csv(cfg[[cc]]$unit_year, show_col_types = FALSE, col_types = cols(unit = col_character()))
    ms <- read_csv(cfg[[cc]]$male_share, show_col_types = FALSE)
    for (a in c("all", "15-44")) {
      dat <- uy |> filter(ages == a, year %in% cfg[[cc]]$years) |> select(country, unit, unit_label, year, d, dm, df, h, hm, hf) |> arrange(unit, year)
      datasets[[paste(cc, a)]] <- list(country = cc, ages = a, md = intl_model_data(dat, pi_m = ms$pi[ms$ages == a]))
    }
    next
  }
  f <- paste0("output/tables/intl_", cc, "_deaths_state_year.csv")
  if (!file.exists(f)) next
  panel <- read_csv(f, show_col_types = FALSE, col_types = cols(unit = col_character()))
  if (!is.null(cfg[[cc]]$years)) panel <- filter(panel, year %in% cfg[[cc]]$years)
  datasets[[paste(cc, "all")]] <- list(country = cc, ages = "all", md = intl_model_data(intl_data(panel, "all")))
  datasets[[paste(cc, "15-44")]] <- list(country = cc, ages = "15-44", md = intl_model_data(intl_data(panel, "15-44")))
}
# Colombia, EEVV 1979-2019 by the 15 units of 60. partial years are left out
col <- read_csv("output/tables/homicide_backcast_dept_1915-2019.csv", show_col_types = FALSE) |>
  filter(year >= 1979, !is.na(hom_eevv), hom_eevv > 0, !partial_year, !is.na(sex_ratio_deaths)) |>
  transmute(country = "colombia", unit, unit_label, year, d = deaths_reg, dm = d * sex_ratio_deaths / (1 + sex_ratio_deaths),
            df = d / (1 + sex_ratio_deaths), h = hom_eevv, hm = 0.9 * h, hf = 0.1 * h) |>
  arrange(unit, year)
datasets[["colombia all"]] <- list(country = "colombia", ages = "all", md = intl_model_data(col, pi_m = 0.90))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. fit and hidden blocks ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pars <- list(); pred <- list(); fitted <- list()
for (nm in names(datasets)) {
  ds <- datasets[[nm]]; md <- ds$md$md; pi_m <- ds$md$pi_m
  say(nm, "| units", n_distinct(md$unit), "| years", paste(range(md$year), collapse = "-"), "| share of men among violent deaths", round(pi_m, 3),
      "| violent deaths as % of deaths", round(100 * sum(md$h) / sum(md$d), 2))
  ft <- intl_fit(md, pi_m)
  say("  s_eta", round(ft$par[1], 3), "| s_u", round(ft$par[2], 4), "| s_0", round(ft$par[3], 4), "| loglik", round(ft$loglik, 1), "| convergence", ft$convergence)
  pars[[nm]] <- tibble(country = ds$country, ages = ds$ages, units = n_distinct(md$unit), years = paste(range(md$year), collapse = "-"),
                       pi_m = pi_m, violent_share_pct = 100 * sum(md$h) / sum(md$d),
                       s_eta = ft$par[1], s_u = ft$par[2], s_0 = ft$par[3], loglik = ft$loglik, convergence = ft$convergence)
  bl <- c(cfg[[ds$country]]$blocks, cfg[[ds$country]]$back)
  pred[[nm]] <- bind_rows(intl_validate(md, ft$par, pi_m, bl), intl_simple(md, bl)) |>
    mutate(country = ds$country, ages = ds$ages, test = ifelse(block %in% names(cfg[[ds$country]]$back), "backcast", "interior"), .before = 1)
  fitted[[nm]] <- intl_run(md, ft$par, pi_m, smooth = TRUE) |> mutate(country = ds$country, ages = ds$ages)
}
pars <- bind_rows(pars); pred <- bind_rows(pred)
write_csv(pars, "output/tables/intl_validation_parameters.csv")
write_csv(pred, "output/tables/intl_validation_predictions.csv")

scores <- intl_scores(pred, by = c("country", "ages", "test", "block", "family", "model"))
write_csv(scores, "output/tables/intl_validation_scores.csv")
scores_all <- intl_scores(filter(pred, test == "interior"), by = c("country", "ages", "family", "model")) |> mutate(block = "all interior blocks", test = "interior")
cat("\n== median absolute error (%), by block ==\n")
print(as.data.frame(bind_rows(scores, scores_all) |> mutate(m = sub(":.*", "", model), v = round(median_abs_error_pct)) |>
                      select(country, ages, test, block, n, m, v) |> pivot_wider(names_from = m, values_from = v) |> arrange(test, country, ages)), row.names = FALSE)
cat("\n== coverage of the 90 % interval (state-space) and violent deaths as % of deaths in the block ==\n")
print(as.data.frame(scores |> filter(model %in% c("N: nothing in the block", "S: sex ratio")) |>
                      transmute(country, ages, test, block, m = sub(":.*", "", model), cov = round(100 * coverage90), share = round(violent_share_pct, 1)) |>
                      pivot_wider(names_from = m, values_from = cov, names_prefix = "coverage_")), row.names = FALSE)

# by unit, the interior blocks together
scores_u <- pred |> filter(test == "interior") |> mutate(lr = log(hom_pred / hom_obs)) |>
  summarise(n = n(), median_abs_error_pct = 100 * median(abs(exp(lr) - 1)), violent_share_pct = 100 * sum(hom_obs) / sum(d),
            deaths_per_year = mean(d), .by = c(country, ages, unit, unit_label, family, model))
write_csv(scores_u, "output/tables/intl_validation_scores_units.csv")
cat("\n== by unit, deaths of all ages: median absolute error (%) ==\n")
print(as.data.frame(scores_u |> filter(ages == "all") |> mutate(m = sub(":.*", "", model), v = round(median_abs_error_pct)) |>
                      select(country, unit_label, share = violent_share_pct, m, v) |> mutate(share = round(share, 1)) |>
                      pivot_wider(names_from = m, values_from = v) |> arrange(country, -share)), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#1f1f1e"
base <- theme_minimal(base_size = 10) +
  theme(legend.position = "top", legend.margin = margin(0, 0, 0, 0), panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold", hjust = 0), plot.title = element_text(face = "bold"),
        plot.caption = element_text(colour = "grey45", hjust = 0))
lines_lab <- c("N: nothing in the block" = "Sin pistas del bloque", "S: sex ratio" = "Modelo de espacio de estados, razón de sexos",
               "B1: sex ratio + national total" = "Modelo simple, razón de sexos + total nacional")
lines_col <- setNames(c("grey45", "#2a78d6", "#1baf7a"), lines_lab)

# observed and predicted, all ages, six units of each country
for (cc in unique(pars$country)) {
  u <- cfg[[cc]]$fig_units
  md <- datasets[[paste(cc, "all")]]$md$md |> filter(unit %in% u)
  labs_u <- md |> distinct(unit, unit_label)
  lev <- labs_u$unit_label[match(u, labs_u$unit)]
  p <- pred |> filter(country == cc, ages == "all", test == "interior", unit %in% u, model %in% names(lines_lab)) |>
    mutate(line = factor(lines_lab[model], lines_lab), unit_label = factor(unit_label, lev), share = 100 * hom_pred / d)
  band <- p |> filter(model == "S: sex ratio")
  rect <- tibble(block = names(cfg[[cc]]$blocks)) |> mutate(x0 = as.numeric(substr(block, 1, 4)) - 0.4, x1 = as.numeric(substr(block, 6, 9)) + 0.4)
  fig <- ggplot() +
    geom_rect(data = rect, aes(xmin = x0, xmax = x1, ymin = 0, ymax = Inf), fill = "grey94") +
    geom_ribbon(data = band, aes(year, ymin = 100 * hom_lo90 / d, ymax = 100 * hom_hi90 / d, group = block), fill = "#2a78d6", alpha = 0.15) +
    geom_line(data = md |> mutate(unit_label = factor(unit_label, lev)), aes(year, 100 * h / d), colour = ink, linewidth = 0.35) +
    geom_point(data = md |> mutate(unit_label = factor(unit_label, lev)), aes(year, 100 * h / d), colour = ink, size = 1.1) +
    geom_line(data = p, aes(year, share, colour = line, linetype = line, group = interaction(block, line)), linewidth = 0.65) +
    scale_colour_manual(values = lines_col, name = NULL) +
    scale_linetype_manual(values = setNames(c("22", "solid", "solid"), lines_lab), name = NULL) +
    scale_y_log10(labels = scales::label_number(drop0trailing = TRUE)) +
    facet_wrap(~unit_label, ncol = 3, scales = "free_y") +
    labs(title = paste0(cfg[[cc]]$label, ": muertes violentas observadas y predichas en años ocultos al modelo"),
         subtitle = paste0("Muertes violentas como % de las defunciones de todas las edades, escala logarítmica. Negro: observado. ",
                           "Franjas grises: años ocultos.\nBanda azul: intervalo de 90 % del modelo de espacio de estados con razón de sexos."),
         x = NULL, y = NULL,
         caption = "Muertes violentas: homicidio, intervención legal e intención no determinada. El modelo simple recibe además el total nacional del año.") +
    base
  ggsave(paste0("figures/09_international/", cc, "_predictive_check.png"), fig, w = 12, h = 7.5, bg = "white", dpi = 160)
}

# error against the weight of violent deaths, one point per unit
eu <- scores_u |> filter(model %in% c("N: nothing in the block", "S: sex ratio")) |>
  mutate(modelo = ifelse(grepl("^N", model), "Sin pistas del bloque", "Con razón de sexos"),
         pais = sapply(country, function(x) cfg[[x]]$label),
         panel = ifelse(ages == "all", "Defunciones de todas las edades", "Defunciones de 15 a 44 años"),
         panel = factor(panel, c("Defunciones de todas las edades", "Defunciones de 15 a 44 años")))
fig2 <- ggplot(eu, aes(violent_share_pct, median_abs_error_pct, colour = pais, shape = modelo)) +
  geom_point(size = 2, alpha = 0.85) +
  scale_x_log10(labels = scales::label_number(drop0trailing = TRUE)) +
  scale_shape_manual(values = c("Sin pistas del bloque" = 1, "Con razón de sexos" = 16), name = NULL) +
  scale_colour_manual(values = c("Brasil" = "#1baf7a", "Colombia" = "#eb6834", "México" = "#2a78d6", "Estados Unidos" = "#8a5cc2"), name = NULL) +
  facet_wrap(~panel, scales = "free_x") +
  labs(title = "El error de predicción según el peso de las muertes violentas",
       subtitle = "Un punto por unidad territorial: error absoluto mediano en los años ocultos. Círculo hueco: sin usar la razón de sexos; lleno: usándola.",
       x = "Muertes violentas como % de las defunciones (escala logarítmica)", y = "Error absoluto mediano (%)") +
  base
ggsave("figures/09_international/intl_error_by_violent_share.png", fig2, w = 11, h = 5.5, bg = "white", dpi = 160)
say("done")
