# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 86. The three methods in the same hidden blocks: the state-space model and
#     the simple regression of 72, and the direct estimator of 80 (Spain)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 72 hides the violent deaths of every unit in blocks of years and predicts
# them with the state-space model (N, S, ST) and the simple regression (B0,
# B1). 82 tested the direct estimator in other periods and against another
# truth. Here the direct estimator runs in the blocks of 72, with the same
# information, so the three can be compared cell by cell.
#
# direct estimator, for unit k in a hidden year t:
#     H = (Dm - r Df) / (pi - r (1 - pi))
# with pi the share of men among violent deaths of the country (as in 72)
# and r the non-violent sex ratio, taken from the years around the block
# where violent deaths are known: log r = log((Dm - pi h) / (Df - (1 - pi) h)).
#   D    the unit's own non-violent ratio: the mean of the 5 visible years on
#        each side of the block, interpolated linearly across an interior
#        block, held flat before a backcast block and after a forward one.
#        This is the Spain estimator: nothing from the hidden years but the
#        deaths by sex.
#   DN   the same deviation of the unit from the national non-violent ratio,
#        added to the national ratio of each hidden year (rho_t of 70, which
#        knows the national share of violent deaths: the same small leak as
#        the state-space model)
#   DT   D rescaled each year to the national total of violent deaths, the
#        counterpart of ST and B1
# H is kept at 1 death or more, so that the log error is finite.
#
# input    data_inter/intl_datasets.rds (72)
#          output/tables/intl_validation_predictions.csv (72)
# output   output/tables/intl_three_methods_predictions.csv
#          output/tables/intl_three_methods_scores.csv
#          figures/09_international/intl_three_methods.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
options(width = 220)
k_side <- 5

dd <- readRDS("data_inter/intl_datasets.rds")
cfg <- dd$cfg; datasets <- dd$datasets
p72 <- read_csv("output/tables/intl_validation_predictions.csv", show_col_types = FALSE, col_types = cols(unit = col_character()))

direct_block <- function(md, pi_m, yrs_b) {
  md <- md |> mutate(lnv = log(pmax(dm - pi_m * h, 1) / pmax(df - (1 - pi_m) * h, 1)), dev = lnv - rho)
  vis <- md |> filter(!year %in% yrs_b)
  lo <- min(yrs_b); hi <- max(yrs_b)
  side <- function(z, before) {
    z <- if (before) filter(z, year < lo) |> slice_max(year, n = k_side) else filter(z, year > hi) |> slice_min(year, n = k_side)
    z |> summarise(lnv = mean(lnv), dev = mean(dev), yr = mean(year), n = n(), .by = unit)
  }
  L <- side(vis, TRUE); R <- side(vis, FALSE)
  md |> filter(year %in% yrs_b) |>
    left_join(L |> select(unit, lnv_l = lnv, dev_l = dev, yr_l = yr), by = "unit") |>
    left_join(R |> select(unit, lnv_r = lnv, dev_r = dev, yr_r = yr), by = "unit") |>
    mutate(
      w = case_when(is.na(yr_l) ~ 1, is.na(yr_r) ~ 0, TRUE ~ (year - yr_l) / (yr_r - yr_l)),
      lr_D = coalesce((1 - w) * lnv_l, 0) + coalesce(w * lnv_r, 0),
      lr_DN = rho + coalesce((1 - w) * dev_l, 0) + coalesce(w * dev_r, 0),
      H_D = pmax((dm - exp(lr_D) * df) / (pi_m - exp(lr_D) * (1 - pi_m)), 1),
      H_DN = pmax((dm - exp(lr_DN) * df) / (pi_m - exp(lr_DN) * (1 - pi_m)), 1),
      H_DT = H_D * sum(h) / sum(H_D), .by = year)
}

pred <- list()
for (nm in names(datasets)) {
  ds <- datasets[[nm]]; md <- ds$md$md; pi_m <- ds$md$pi_m; cc <- ds$country
  bl <- c(cfg[[cc]]$blocks, cfg[[cc]]$back, cfg[[cc]]$forward)
  for (b in names(bl)) {
    x <- direct_block(md, pi_m, bl[[b]])
    test <- case_when(b %in% names(cfg[[cc]]$back) ~ "backcast", b %in% names(cfg[[cc]]$forward) ~ "forward", TRUE ~ "interior")
    pred[[length(pred) + 1]] <- x |>
      select(unit, unit_label, year, d, hom_obs = h, H_D, H_DN, H_DT) |>
      pivot_longer(starts_with("H_"), names_to = "model", values_to = "hom_pred") |>
      mutate(model = c(H_D = "D: direct, own ratio", H_DN = "DN: direct, own ratio + national trend",
                       H_DT = "DT: direct + national total")[model],
             country = cc, ages = ds$ages, test = test, block = b, family = "direct", covered90 = NA, .before = 1)
  }
}
pred <- bind_rows(pred) |> mutate(unit = as.character(unit))
write_csv(pred, "output/tables/intl_three_methods_predictions.csv")

# the three families on the same cells (the cells of 72 have h > 0 and a sex ratio)
keys <- c("country", "ages", "test", "block", "unit", "year")
both <- bind_rows(p72 |> select(all_of(keys), unit_label, d, hom_obs, hom_pred, covered90, family, model),
                  pred |> semi_join(p72 |> distinct(across(all_of(keys))), by = keys) |>
                    select(all_of(keys), unit_label, d, hom_obs, hom_pred, covered90, family, model))
scores <- intl_scores(both, by = c("country", "ages", "test", "block", "family", "model"))
agg <- scores |> summarise(err = weighted.mean(median_abs_error_pct, n), p90 = weighted.mean(p90_abs_error_pct, n),
                           bias = weighted.mean(bias_log, n), share = weighted.mean(violent_share_pct, n), n = sum(n),
                           .by = c(country, ages, test, family, model))
write_csv(bind_rows(scores |> mutate(level = "block"), agg |> rename(median_abs_error_pct = err, p90_abs_error_pct = p90, bias_log = bias, violent_share_pct = share) |>
                      mutate(level = "test", block = "all blocks of the test")),
          "output/tables/intl_three_methods_scores.csv")

cat("== median absolute error (%), mean of the block medians weighted by cells ==\n")
m_order <- c("N", "S", "D", "DN", "ST", "B1", "DT", "B0")
tab <- agg |> mutate(m = sub(":.*", "", model)) |> filter(m %in% m_order) |>
  select(country, ages, test, share, m, err) |> mutate(err = round(err), share = round(share, 1)) |>
  pivot_wider(names_from = m, values_from = err) |> select(country, ages, test, share, any_of(m_order)) |> arrange(ages, test, country)
print(as.data.frame(tab), row.names = FALSE)
cat("\n== bias (mean log ratio predicted / observed) ==\n")
print(as.data.frame(agg |> mutate(m = sub(":.*", "", model)) |> filter(m %in% c("S", "D", "DN")) |>
                      select(country, ages, test, m, bias) |> mutate(bias = round(bias, 2)) |> pivot_wider(names_from = m, values_from = bias) |> arrange(ages, test, country)), row.names = FALSE)

# the same on totals of the block by unit (the way 80 is used in Spain:
# period totals by province), where year-to-year noise partly cancels
ub <- both |> summarise(hom_obs = sum(hom_obs), hom_pred = sum(hom_pred), d = sum(d), .by = c(country, ages, test, block, family, model, unit)) |>
  mutate(covered90 = NA, year = NA)
scores_ub <- intl_scores(ub, by = c("country", "ages", "test", "block", "family", "model")) |>
  summarise(err = weighted.mean(median_abs_error_pct, n), .by = c(country, ages, test, family, model))
write_csv(scores_ub |> rename(median_abs_error_pct_unit_total = err), "output/tables/intl_three_methods_scores_unit_totals.csv")
cat("\n== on totals of the block by unit: median absolute error (%) ==\n")
print(as.data.frame(scores_ub |> mutate(m = sub(":.*", "", model)) |> filter(m %in% m_order) |>
                      select(country, ages, test, m, err) |> mutate(err = round(err)) |>
                      pivot_wider(names_from = m, values_from = err) |> select(country, ages, test, any_of(m_order)) |> arrange(ages, test, country)), row.names = FALSE)
cat("\nshare of cells where the direct estimator (D) is negative and kept at 1 death:\n")
print(as.data.frame(pred |> filter(model == "D: direct, own ratio") |> summarise(neg = round(mean(hom_pred <= 1), 2), .by = c(country, ages, test)) |> arrange(ages, test, country)), row.names = FALSE)

# figure: error of each method, by country, test and age band
fl <- agg |> mutate(m = sub(":.*", "", model)) |> filter(m %in% c("N", "S", "D", "DN", "ST", "B1", "DT")) |>
  mutate(info = ifelse(m %in% c("ST", "B1", "DT"), "con el total nacional de cada año", "sin el total nacional"),
         metodo = factor(c(N = "Sin pistas (interpolación)", S = "1. Estados ocultos", D = "3. Directo, razón propia",
                           DN = "3. Directo, razón propia + tendencia nacional", ST = "1. Estados ocultos",
                           B1 = "2. Regresión simple", DT = "3. Directo, razón propia")[m],
                         c("Sin pistas (interpolación)", "1. Estados ocultos", "2. Regresión simple", "3. Directo, razón propia",
                           "3. Directo, razón propia + tendencia nacional")),
         pais = c(brazil = "Brasil", mexico = "México", us = "EE. UU.", ecuador = "Ecuador", colombia = "Colombia")[country],
         prueba = factor(c(interior = "años intermedios", backcast = "hacia atrás", forward = "hacia adelante")[test],
                         c("años intermedios", "hacia atrás", "hacia adelante")),
         fila = paste0(pais, ", ", ifelse(ages == "all", "todas", "15-44")),
         info = factor(info, c("sin el total nacional", "con el total nacional de cada año")))
fig <- ggplot(fl, aes(pmin(err, 150), fila, colour = metodo, shape = metodo)) +
  geom_point(size = 2.2, alpha = 0.9) +
  facet_grid(prueba ~ info, scales = "free_y", space = "free_y") +
  scale_colour_manual(values = c("grey55", "#2a78d6", "#1baf7a", "#eb6834", "#c0392b"), name = NULL) +
  scale_shape_manual(values = c(1, 16, 17, 15, 18), name = NULL) +
  scale_x_continuous(breaks = c(0, 10, 20, 30, 50, 100, 150)) +
  guides(colour = guide_legend(nrow = 2), shape = guide_legend(nrow = 2)) +
  labs(title = "Error de los tres métodos en los mismos años ocultos",
       subtitle = "Error absoluto mediano (%) de las muertes violentas por unidad y año. Más a la izquierda es mejor. Valores mayores de 150 % se dibujan en 150.",
       x = "error absoluto mediano (%)", y = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"),
        strip.text = element_text(face = "bold"))
ggsave("figures/09_international/intl_three_methods.png", fig, w = 12, h = 9, bg = "white", dpi = 160)
