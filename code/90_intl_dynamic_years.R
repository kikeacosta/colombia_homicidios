# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 90. Observed and estimated violent deaths by state in the most dynamic
#     year of each country
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 88 used 2015 for every country, a quiet year for most of them. Here each
# country gets the year of its largest change, inside a block that was
# already hidden (no model is refitted):
#   Colombia 1991   peak of the late 1980s and early 1990s, block 1985-1997 (72)
#   Mexico   2011   peak of the war on drugs (x2.7 since 2007), block 2004-2011 (72)
#   Brazil   2017   national maximum, block 2011-2018 (88)
#   US       1991   peak of the early 1990s, block 1984-1991 (72)
#   Ecuador  2023   violent deaths x5 since 2020; forward test, 2021-2024
#                   hidden with data only up to 2020 (72)
# methods: N interpolation (or carrying the last level forward), S
# state-space with the sex ratio, B1 simple regression with the national
# total, D direct estimator (86, 88). All ages.
#
# input    output/tables/intl_validation_predictions.csv (72)
#          output/tables/intl_three_methods_predictions.csv (86)
#          output/tables/intl_holdout_2015_predictions.csv (88)
# output   output/tables/intl_dynamic_years_predictions.csv
#          output/tables/intl_dynamic_years_scores.csv
#          figures/09_international/intl_dynamic_years.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)
pick <- tribble(~country, ~block, ~year, ~src,
                "colombia", "1985-1997", 1991, "72",
                "mexico", "2004-2011", 2011, "72",
                "brazil", "2011-2018", 2017, "88",
                "us", "1984-1991", 1991, "72",
                "ecuador", "2021-2024", 2023, "72")
rd <- function(f) read_csv(f, show_col_types = FALSE, col_types = cols(unit = col_character()))
p72 <- bind_rows(rd("output/tables/intl_validation_predictions.csv") |> mutate(m = sub(":.*", "", model)),
                 rd("output/tables/intl_three_methods_predictions.csv") |> mutate(m = sub(":.*", "", model))) |>
  filter(ages == "all", m %in% c("N", "S", "B1", "D")) |> mutate(src = "72")
p88 <- rd("output/tables/intl_holdout_2015_predictions.csv") |> filter(ages == "all", m %in% c("N", "S", "B1", "D")) |> mutate(src = "88")
pred <- bind_rows(p72, p88) |> semi_join(pick, by = c("country", "block", "year", "src")) |>
  select(country, block, year, m, unit, unit_label, d, hom_obs, hom_pred)
write_csv(pred, "output/tables/intl_dynamic_years_predictions.csv")

# national change since the year before the block, to say how big the jump was
sc <- pred |> filter(hom_obs > 0) |>
  summarise(err = 100 * median(abs(hom_pred / hom_obs - 1)), nat = 100 * (sum(hom_pred) / sum(hom_obs) - 1),
            r_log = cor(log(pmax(hom_pred, 1)), log(hom_obs)), share = 100 * sum(hom_obs) / sum(d), units = n(), .by = c(country, year, m))
write_csv(sc, "output/tables/intl_dynamic_years_scores.csv")
cat("== median absolute error by unit (%), national total error (%), in the most dynamic year ==\n")
print(as.data.frame(sc |> mutate(across(c(err, nat, share), ~ round(.x, 1)), r_log = round(r_log, 2)) |>
                      arrange(match(country, pick$country), match(m, c("N", "S", "B1", "D")))), row.names = FALSE)

pais <- c(colombia = "Colombia, 1991", mexico = "México, 2011", brazil = "Brasil, 2017", us = "EE. UU., 1991", ecuador = "Ecuador, 2023\n(pronóstico)")
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
       subtitle = paste0("Cada punto es un estado, departamento o provincia. Eje x: muertes violentas registradas. Eje y: estimadas sin ver ese año ni los vecinos\n",
                         "(bloques ocultos de 8-13 años; Ecuador: 2021-2024, con datos solo hasta 2020). Sobre la línea punteada, la estimación es exacta.\n",
                         "Todas las edades. Escalas logarítmicas; las estimaciones negativas o nulas se dibujan en 1."),
       x = "muertes violentas registradas", y = "muertes violentas estimadas") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 13), strip.text = element_text(face = "bold"),
        strip.text.y = element_text(angle = 0, hjust = 0))
ggsave("figures/09_international/intl_dynamic_years.png", fig, w = 13, h = 12.5, bg = "white", dpi = 160)
