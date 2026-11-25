# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 89. Maps: observed and estimated violent deaths by state, province or
#     department
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Five countries, 2015, with 2011-2018 hidden (88): violent deaths as % of
# all deaths, registered (vital statistics) and estimated by the state-space
# model with the sex ratio, and the ratio of the two. The measure is the
# share of deaths, not a rate, because the models use no population and
# there is none for the other countries.
# Spain, 1936-1939: violent deaths as % of deaths, registered as violent
# (83), estimated by the state-space model (87) and by the direct
# estimator (80).
# boundaries: Natural Earth admin-1, 1:10m (public domain), downloaded
# 2026-11-25 from https://naciscdn.org/naturalearth/10m/cultural/
# ne_10m_admin_1_states_provinces.zip to data_input/geo/natural_earth/ of
# the main project folder (not versioned). Units grouped as in the data
# (Colombia's 15 stable units, Goias + Tocantins, three pairs in Ecuador).
# Alaska and Hawaii are left out of the US map; the Canary Islands are moved
# next to the peninsula.
#
# input    output/tables/intl_holdout_2015_predictions.csv (88)
#          output/tables/intl_spain_state_space.csv (87)
#          data_input/geo/natural_earth/admin1_10m/ne_10m_admin_1_states_provinces.shp
# output   figures/09_international/maps/map_<country>_2015.png
#          figures/09_international/maps/map_spain_1936-1939.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
library(sf)
sf_use_s2(FALSE)
dir.create("figures/09_international/maps", showWarnings = FALSE, recursive = TRUE)
ne_file <- "data_input/geo/natural_earth/admin1_10m/ne_10m_admin_1_states_provinces.shp"
if (!file.exists(ne_file)) ne_file <- file.path("C:/Users/kikep/gits/colombia_homicidios", ne_file)
ne <- st_read(ne_file, quiet = TRUE)
key <- function(s) gsub("[^a-z]", "", tolower(stringi::stri_trans_general(s, "Latin-ASCII")))

# map name -> unit label of the data, where they differ
grp <- list(
  brazil = c("Goiás" = "Goiás + Tocantins", "Tocantins" = "Goiás + Tocantins"),
  mexico = c("Distrito Federal" = "Ciudad de México"),
  ecuador = c("Guayas" = "Guayas + Santa Elena", "Santa Elena" = "Guayas + Santa Elena", "Napo" = "Napo + Orellana", "Orellana" = "Napo + Orellana",
              "Pichincha" = "Pichincha + Santo Domingo", "Santo Domingo de los Tsáchilas" = "Pichincha + Santo Domingo"),
  colombia = c("Bolívar" = "Bolívar + Córdoba + Sucre", "Córdoba" = "Bolívar + Córdoba + Sucre", "Sucre" = "Bolívar + Córdoba + Sucre",
               "Caldas" = "Caldas + Quindío + Risaralda", "Quindío" = "Caldas + Quindío + Risaralda", "Risaralda" = "Caldas + Quindío + Risaralda",
               "Cundinamarca" = "Cundinamarca + Bogotá", "Bogota" = "Cundinamarca + Bogotá", "Magdalena" = "Magdalena + Cesar", "Cesar" = "Magdalena + Cesar",
               setNames(rep("Territorios", 13), c("Chocó", "Meta", "Caquetá", "La Guajira", "Arauca", "Casanare", "Putumayo", "San Andrés y Providencia",
                                                   "Amazonas", "Guainía", "Guaviare", "Vaupés", "Vichada"))),
  spain = c("Castellón" = "Castellón de la Plana", "La Coruña" = "Coruña (La)", "Gipuzkoa" = "Guipúzcoa", "La Rioja" = "Logroño",
            "Asturias" = "Oviedo", "Las Palmas" = "Palmas (Las)", "Cantabria" = "Santander", "Bizkaia" = "Vizcaya"))
iso <- c(brazil = "BRA", mexico = "MEX", ecuador = "ECU", us = "USA", colombia = "COL", spain = "ESP")
shapes <- function(cc) {
  g <- grp[[cc]]; if (is.null(g)) g <- character(0)
  s <- ne |> filter(adm0_a3 == iso[[cc]]) |> select(name) |>
    mutate(label = ifelse(name %in% names(g), g[name], name))
  if (cc == "us") s <- filter(s, !name %in% c("Alaska", "Hawaii"))
  if (cc == "spain") {
    s <- filter(s, !name %in% c("Ceuta", "Melilla"))
    can <- s$name %in% c("Las Palmas", "Santa Cruz de Tenerife")
    st_geometry(s)[can] <- st_geometry(s)[can] + c(5.5, 7)
    s <- st_set_crs(s, 4326)
  }
  s |> group_by(label) |> summarise(.groups = "drop") |> mutate(k = key(label))
}

pais <- c(colombia = "Colombia", brazil = "Brasil", mexico = "México", ecuador = "Ecuador", us = "Estados Unidos")
base <- theme_void(base_size = 10) +
  theme(plot.title = element_text(face = "bold", size = 13), plot.subtitle = element_text(size = 9.5, colour = "grey25"),
        strip.text = element_text(face = "bold", size = 10.5), legend.position = "bottom", legend.key.width = unit(1.6, "cm"),
        plot.background = element_rect(fill = "white", colour = NA))

three_maps <- function(s, d, tit, sub, lab_a, lab_b, lab_ratio, file, w, h) {
  m <- s |> left_join(d, by = "k")
  long <- bind_rows(m |> transmute(panel = lab_a, v = a), m |> transmute(panel = lab_b, v = b)) |> mutate(panel = factor(panel, c(lab_a, lab_b)))
  brk <- signif(quantile(c(m$a, m$b), c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE), 2)
  p1 <- ggplot(long) + geom_sf(aes(fill = v), colour = "white", linewidth = 0.15) +
    scale_fill_distiller(palette = "YlOrRd", direction = 1, trans = "log10", na.value = "grey85", name = "% de las muertes que son violentas",
                         breaks = c(0.2, 0.5, 1, 2, 5, 10, 20, 50), labels = function(x) format(x, decimal.mark = ",", drop0trailing = TRUE)) +
    facet_wrap(~panel) + base
  p2 <- ggplot(m) + geom_sf(aes(fill = 100 * (b / a - 1)), colour = "white", linewidth = 0.15) +
    scale_fill_gradient2(low = "#2a78d6", mid = "grey95", high = "#c0392b", midpoint = 0, limits = c(-60, 60), oob = scales::squish,
                         na.value = "grey85", name = "diferencia, %") +
    labs(subtitle = lab_ratio) + base + theme(plot.subtitle = element_text(face = "bold", size = 10.5, hjust = 0.5))
  fig <- ggpubr::ggarrange(p1, p2, ncol = 2, widths = c(2, 1.05)) |>
    ggpubr::annotate_figure(top = ggpubr::text_grob(paste0(tit, "\n", sub), x = 0.01, hjust = 0, size = 11))
  ggsave(file, fig, w = w, h = h, bg = "white", dpi = 160)
}

p <- read_csv("output/tables/intl_holdout_2015_predictions.csv", show_col_types = FALSE, col_types = cols(unit = col_character())) |>
  filter(ages == "all", year == 2015, m == "S")
dims <- list(colombia = c(13, 6.5), brazil = c(14, 6.2), mexico = c(14, 5.6), ecuador = c(13, 6), us = c(15, 5.4))
for (cc in names(pais)) {
  d <- p |> filter(country == cc) |> transmute(k = key(unit_label), a = 100 * hom_obs / d, b = 100 * hom_pred / d)
  s <- shapes(cc)
  miss <- setdiff(d$k, s$k); if (length(miss)) cat(cc, "units without a shape:", paste(miss, collapse = ", "), "\n")
  three_maps(s, d, paste0(pais[[cc]], ", 2015: muertes violentas registradas y estimadas"),
             "Se ocultaron 2011-2018 y el modelo de estados ocultos estimó cada unidad con la razón de sexos de sus muertes. En gris, unidades sin datos.",
             "Registradas (estadísticas vitales)", "Estimadas (modelo de estados ocultos)", "Estimado frente a registrado\n(rojo: sobreestima; azul: subestima)",
             sprintf("figures/09_international/maps/map_%s_2015.png", cc), dims[[cc]][1], dims[[cc]][2])
}

# Spain 1936-1939
sp <- read_csv("output/tables/intl_spain_state_space.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(year %in% 1936:1939) |>
  summarise(reg = sum(violent_reg), ss = sum(H_ss), dir = sum(H_direct), d = sum(total), .by = province) |>
  transmute(k = key(province), a = 100 * reg / d, b = 100 * ss / d, c = 100 * pmax(dir, 1) / d)
s <- shapes("spain")
miss <- setdiff(sp$k, s$k); if (length(miss)) cat("spain without a shape:", paste(miss, collapse = ", "), "\n")
m <- s |> left_join(sp, by = "k")
long <- bind_rows(m |> transmute(panel = "Registradas como violentas", v = a), m |> transmute(panel = "Estimadas: estados ocultos", v = b),
                  m |> transmute(panel = "Estimadas: estimador directo", v = c)) |>
  mutate(panel = factor(panel, c("Registradas como violentas", "Estimadas: estados ocultos", "Estimadas: estimador directo")))
fig <- ggplot(long) + geom_sf(aes(fill = v), colour = "white", linewidth = 0.15) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1, trans = "log10", na.value = "grey85", name = "% de las muertes que son violentas",
                       limits = c(0.3, 30), oob = scales::squish,
                       breaks = c(0.5, 1, 2, 5, 10, 20), labels = function(x) format(x, decimal.mark = ",", drop0trailing = TRUE)) +
  facet_wrap(~panel) +
  labs(title = "España, 1936-1939: muertes violentas como % de todas las muertes, por provincia",
       subtitle = paste0("Registradas: homicidio, heridas de guerra y ejecuciones (INE). Estimadas: a partir de las muertes por sexo. ",
                         "Canarias, desplazada junto a la península.\nEl estimador directo da valores negativos en Canarias (dibujados en el mínimo).")) +
  base + theme(strip.text = element_text(face = "bold", size = 10.5, margin = margin(t = 10, b = 4)))
ggsave("figures/09_international/maps/map_spain_1936-1939.png", fig, w = 15, h = 5.4, bg = "white", dpi = 160)
