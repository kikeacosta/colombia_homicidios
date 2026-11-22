# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 75. Figure: observed and predicted violent deaths in the four most violent
#     states of Brazil (hidden interior blocks of 72, deaths of all ages)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# "Most violent" = highest share of violent deaths (homicide, legal
# intervention, undetermined intent) in all deaths of 1990-2020; there is no
# population in the project to rank by rate. Draws only: run 71 and 72 first.
#
# inputs   output/tables/intl_brazil_deaths_state_year.csv   (71)
#          output/tables/intl_validation_predictions.csv     (72)
# output   figures/09_international/brazil_top4_observed_predicted.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressPackageStartupMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2)})
viol <- c("homicide", "legal", "undetermined")
panel <- read_csv("output/tables/intl_brazil_deaths_state_year.csv", show_col_types = FALSE, col_types = cols(unit = col_character()))
obs <- panel |> summarise(d = sum(deaths), h = sum(deaths[cause %in% viol]), .by = c(unit, unit_label, year))
rank <- obs |> summarise(share = 100 * sum(h) / sum(d), h_year = mean(h), .by = c(unit, unit_label)) |> arrange(-share)
print(as.data.frame(head(rank, 8)), row.names = FALSE)
top <- head(rank, 4)
pred <- read_csv("output/tables/intl_validation_predictions.csv", show_col_types = FALSE, col_types = cols(unit = col_character())) |>
  filter(country == "brazil", ages == "all", test == "interior", unit %in% top$unit,
         model %in% c("N: nothing in the block", "S: sex ratio"))
lab <- c("N: nothing in the block" = "Predicted without clues (interpolation)", "S: sex ratio" = "Predicted with the sex ratio of deaths")
lev <- paste0(top$unit_label, " (", sprintf("%.1f", top$share), " % of deaths)")
names(lev) <- top$unit
pred <- pred |> mutate(line = factor(lab[model], lab), panel = factor(lev[unit], lev))
obs4 <- obs |> filter(unit %in% top$unit) |> mutate(panel = factor(lev[unit], lev))
rect <- pred |> distinct(block) |> mutate(x0 = as.numeric(substr(block, 1, 4)) - 0.4, x1 = as.numeric(substr(block, 6, 9)) + 0.4)
ink <- "#1f1f1e"
fig <- ggplot() +
  geom_rect(data = rect, aes(xmin = x0, xmax = x1, ymin = -Inf, ymax = Inf), fill = "grey94") +
  geom_ribbon(data = filter(pred, model == "S: sex ratio"), aes(year, ymin = hom_lo90, ymax = hom_hi90, group = block), fill = "#2a78d6", alpha = 0.15) +
  geom_line(data = obs4, aes(year, h, colour = "Observed"), linewidth = 0.4) +
  geom_point(data = obs4, aes(year, h, colour = "Observed"), size = 1.3) +
  geom_line(data = pred, aes(year, hom_pred, colour = line, linetype = line, group = interaction(block, line)), linewidth = 0.7) +
  scale_colour_manual(values = c("Observed" = ink, setNames(c("grey45", "#2a78d6"), lab)), breaks = c("Observed", unname(lab)), name = NULL) +
  scale_linetype_manual(values = setNames(c("22", "solid"), lab), guide = "none") +
  scale_y_continuous(labels = scales::label_comma(), limits = c(0, NA), expand = expansion(mult = c(0, 0.06))) +
  facet_wrap(~panel, ncol = 2, scales = "free_y") +
  labs(title = "Brazil: observed and predicted violent deaths in the four most violent states",
       subtitle = paste0("Violent deaths per year (homicide, legal intervention and undetermined intent). States ranked by violent deaths as a share of all deaths, 1979-2020.\n",
                         "Grey bands: years hidden from the model. Blue band: 90 % interval of the prediction with the sex ratio."),
       x = NULL, y = NULL,
       caption = "Each grey band was hidden in turn; the model kept the years outside it. Deaths of all ages. Source: SIM microdata, state of residence.") +
  theme_minimal(base_size = 10) +
  theme(legend.position = "top", legend.margin = margin(0, 0, 0, 0), panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        strip.text = element_text(face = "bold", hjust = 0), plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey45", hjust = 0))
ggsave("figures/09_international/brazil_top4_observed_predicted.png", fig, w = 11, h = 7, bg = "white", dpi = 160)
err <- pred |> summarise(median_abs_error_pct = round(100 * median(abs(hom_pred / hom_obs - 1))), .by = c(unit_label, model))
print(as.data.frame(pivot_wider(err, names_from = model, values_from = median_abs_error_pct)), row.names = FALSE)
