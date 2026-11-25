# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 88. One test that reads at a glance: violent deaths of 2011-2018 hidden in
#     every country, and the estimates of each method for 2015 by state
#     against the vital statistics
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 72 and 86 use blocks that differ by country. Here every country gets the
# same hidden years, 2011-2018 (data on both sides: 2019 for Colombia and
# the United States, later years for the rest), and the figure shows one
# year inside the block, 2015.
# methods, as in 72 and 86, with the parameters estimated in 72:
#   N    state-space model, nothing in the block (interpolation)
#   S    state-space model with the sex ratio (method 1)
#   ST   S rescaled to the national total of each year
#   B1   simple regression with the sex ratio and the national total (method 2)
#   D    direct estimator, the unit's own non-violent ratio from the 5 years
#        on each side, interpolated (method 3, the Spain estimator)
# ages: all (the situation of historical Colombia and of Spain) and 15-44
#
# input    data_inter/intl_datasets.rds (72)
#          output/tables/intl_validation_parameters.csv (72)
# output   output/tables/intl_holdout_2015_predictions.csv
#          output/tables/intl_holdout_2015_scores.csv
#          figures/09_international/intl_holdout_2015.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
library(glmmTMB)
options(width = 220)
blk <- list("2011-2018" = 2011:2018)
yr_fig <- 2015
k_side <- 5

dd <- readRDS("data_inter/intl_datasets.rds"); datasets <- dd$datasets
pars <- read_csv("output/tables/intl_validation_parameters.csv", show_col_types = FALSE)

direct_block <- function(md, pi_m, yrs_b) {
  md <- md |> mutate(lnv = log(pmax(dm - pi_m * h, 1) / pmax(df - (1 - pi_m) * h, 1)))
  lo <- min(yrs_b); hi <- max(yrs_b)
  L <- md |> filter(year < lo) |> slice_max(year, n = k_side, by = unit) |> summarise(l = mean(lnv), yl = mean(year), .by = unit)
  R <- md |> filter(year > hi) |> slice_min(year, n = k_side, by = unit) |> summarise(r = mean(lnv), yr = mean(year), .by = unit)
  md |> filter(year %in% yrs_b) |> left_join(L, by = "unit") |> left_join(R, by = "unit") |>
    mutate(w = ifelse(is.na(yr), 0, (year - yl) / (yr - yl)), lr = (1 - w) * l + w * coalesce(r, l),
           hom_pred = pmax((dm - exp(lr) * df) / (pi_m - exp(lr) * (1 - pi_m)), 1)) |>
    transmute(block = names(blk), model = "D: direct", unit, unit_label, year, d, hom_obs = h, hom_pred)
}

pred <- list()
for (nm in names(datasets)) {
  ds <- datasets[[nm]]; md <- ds$md$md; pi_m <- ds$md$pi_m
  if (!all(c(2010, 2019) %in% md$year)) next
  pr <- pars |> filter(country == ds$country, ages == ds$ages)
  par <- c(pr$s_eta, pr$s_u, pr$s_0)
  cat(nm, "\n")
  pred[[nm]] <- bind_rows(intl_validate(md, par, pi_m, blk), intl_simple(md, blk), direct_block(md, pi_m, blk[[1]])) |>
    mutate(country = ds$country, ages = ds$ages, unit = as.character(unit), .before = 1)
}
pred <- bind_rows(pred) |> mutate(m = sub(":.*", "", model)) |> filter(m %in% c("N", "S", "ST", "B1", "D"))
write_csv(pred, "output/tables/intl_holdout_2015_predictions.csv")

sc <- pred |> filter(!is.na(hom_obs), hom_obs > 0) |>
  summarise(err_block = 100 * median(abs(hom_pred / hom_obs - 1)),
            err_2015 = 100 * median(abs(hom_pred / hom_obs - 1)[year == yr_fig]),
            nat_2015 = 100 * (sum(hom_pred[year == yr_fig]) / sum(hom_obs[year == yr_fig]) - 1),
            r_log_2015 = cor(log(hom_pred[year == yr_fig]), log(hom_obs[year == yr_fig])),
            share = 100 * sum(hom_obs) / sum(d), units = n_distinct(unit), .by = c(country, ages, m))
write_csv(sc, "output/tables/intl_holdout_2015_scores.csv")
cat("\n== hidden 2011-2018: median absolute error by state in 2015 (%), national total error in 2015 (%), log correlation across states ==\n")
print(as.data.frame(sc |> mutate(across(c(err_block, err_2015, nat_2015, share), ~ round(.x, 1)), r_log_2015 = round(r_log_2015, 2)) |>
                      arrange(ages, country, match(m, c("N", "S", "ST", "B1", "D")))), row.names = FALSE)

# figure: all ages, 2015, observed (vital statistics) against estimated
pais <- c(colombia = "Colombia", brazil = "Brasil", mexico = "México", ecuador = "Ecuador", us = "EE. UU.")
met <- c(N = "Sin pistas\n(interpolación)", S = "1. Estados ocultos\n(razón de sexos)", B1 = "2. Regresión simple\n(+ total nacional)", D = "3. Directo\n(estimador de España)")
fd <- pred |> filter(ages == "all", year == yr_fig, m %in% names(met), hom_obs > 0) |>
  left_join(sc |> filter(ages == "all") |> select(country, m, err_2015, share), by = c("country", "m")) |>
  mutate(pais = factor(paste0(pais[country], "\n(", format(round(share, 1), decimal.mark = ","), " % violentas)"),
                       unique(paste0(pais[country], "\n(", format(round(share, 1), decimal.mark = ","), " % violentas)"))[order(match(unique(country), names(pais)))]),
         metodo = factor(met[m], met))
lab <- fd |> distinct(pais, metodo, err_2015) |> mutate(txt = paste0("error mediano ", round(err_2015), " %"))
fig <- ggplot(fd, aes(hom_obs, hom_pred)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey55", linetype = "22") +
  geom_point(aes(colour = metodo), size = 1.5, alpha = 0.8, show.legend = FALSE) +
  geom_text(data = lab, aes(x = 0, y = Inf, label = txt), hjust = -0.05, vjust = 1.4, size = 2.8, colour = "grey20", inherit.aes = FALSE) +
  scale_x_log10(labels = scales::label_number(big.mark = ".")) + scale_y_log10(labels = scales::label_number(big.mark = ".")) +
  scale_colour_manual(values = c("grey50", "#2a78d6", "#1baf7a", "#eb6834")) +
  facet_grid(pais ~ metodo, scales = "free") +
  labs(title = "¿Qué tan bien estima cada método las muertes violentas de un año que no vio? Estados o departamentos, 2015",
       subtitle = paste0("Se ocultaron las muertes violentas de 2011-2018 en cada país; el punto es una unidad en 2015. Eje x: registradas (estadísticas vitales). ",
                         "Eje y: estimadas.\nSobre la línea punteada, la estimación es exacta. Todas las edades. Escalas logarítmicas."),
       x = "muertes violentas registradas en 2015", y = "muertes violentas estimadas") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"), strip.text = element_text(face = "bold"),
        strip.text.y = element_text(angle = 0, hjust = 0))
ggsave("figures/09_international/intl_holdout_2015.png", fig, w = 13, h = 12, bg = "white", dpi = 160)
