# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 32. Data availability by year, geographic level and disaggregation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# One tile per series and year, for the inventory documents. Rows are the
# sources of population, all-cause deaths, homicides / violent deaths and life
# tables held in the project, grouped by geographic level (national,
# departmental, municipal). The fill is the finest disaggregation available
# that year (total only, by sex, age and sex, age, sex and cause); faded tiles
# mark years with partial coverage (fewer than 80 % of the units reporting, a
# short year such as EEVV 1979, or a different concept such as the 1943-1945
# "muertes violentas accidentales").
#
# Where a transcription csv is in the repository the years and the share of
# units with data are computed from it; the other series (microdata, WPP, DANE
# projections, MSE, UCDP, Policía, UN IGME, NRC 1982) are declared with their
# known ranges, and so are the sources still being extracted from their PDF
# (DANE "Registro de defunciones 1970-1978"), which carry "en extracción" in
# the row label.
# Series projected beyond 2023 (WPP to 2100, DANE to 2042) are cut at 2023.
#
# Two figures: the information available whatever the source (one row per level
# and domain, colour = finest disaggregation, with the data that come from adding
# up a finer level marked) and the sources (one row per source, with overlaps).
#
# output: figures/inventory/data_availability_information.png
#         output/tables/data_availability_information.csv  (nivel, dominio, year,
#                                               detalle, parcial, agregado, ...)
#         figures/inventory/data_availability.png  (sources)
#         output/tables/data_availability.csv  (nivel, dominio, serie, year,
#                                               detalle, parcial, archivo)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))
dir.create("figures/inventory", showWarnings = FALSE, recursive = TRUE)

hist <- "data_input/historical/"
ref <- "data_input/reference/"
gap <- \(f) paste0(hist, "col_gap_analysis_1920_1985_", f)

detalles <- c("Solo total", "Por sexo", "Edad y sexo")   # the cause of death is not a stratum here: homicides are their own domain
niveles <- c("Nacional", "Departamental", "Municipal")
dominios <- c("Población", "Defunciones", "Homicidios y violencia", "Tablas de vida")

# a series declared by year range -------------------------------------------
serie <- function(nivel, dominio, serie, years, detalle, archivo, parcial = NULL) {
  tibble(nivel = nivel, dominio = dominio, serie = serie, year = years, detalle = detalle,
         parcial = if (is.null(parcial)) FALSE else year %in% parcial, archivo = archivo)
}

# a series computed from a transcription csv: years with data, share of units
# reporting and whether the sex split exists for at least half of them -------
serie_csv <- function(nivel, dominio, serie, file, delim = ",", unit = "department",
                      detalle_sexo = "Por sexo", min_share = 0.8, extra_parcial = NULL) {
  d <- read_delim(gap(file), delim = delim, show_col_types = FALSE, guess_max = 1e5,
                  name_repair = "minimal")
  d <- d[, names(d) != ""]
  s <- d |>
    summarise(n = n(), with_data = sum(data_available == 1, na.rm = TRUE),
              with_sex = sum(sex_disagg_available == 1, na.rm = TRUE), .by = year) |>
    filter(with_data > 0) |>
    mutate(share = with_data / n,
           detalle = if_else(with_sex / with_data >= 0.5, detalle_sexo, "Solo total"),
           parcial = share < min_share | year %in% extra_parcial)
  tibble(nivel = nivel, dominio = dominio, serie = serie, year = s$year, detalle = s$detalle,
         parcial = s$parcial, archivo = gap(file), share = s$share)
}

# DANE "Estadística vital 1958-1960" (OCR of the municipal tables, script
# historical/24): deaths by sex and municipality, verified against the
# departmental totals; the departmental series is the same file summed by
# department (16 departments plus the intendencias and comisarías)
serie_vitales <- function(nivel) {
  d <- read_csv(paste0(hist, "dane_vitales_1958_1960_municipal.csv"), show_col_types = FALSE)
  s <- d |> summarise(share = mean(!is.na(deaths_t)), .by = year)
  archivo <- paste0(hist, "dane_vitales_1958_1960_municipal.csv",
                    if (nivel == "Departamental") " (suma por departamento); dane_vitales_1958_1960_departamental.csv" else "")
  tibble(nivel = nivel, dominio = "Defunciones", serie = "DANE Estadística vital 1958-1960 (OCR), total y sexo",
         year = s$year, detalle = "Por sexo", parcial = s$share < 0.8, archivo = archivo, share = s$share)
}

# years in the LAMBdA text extracts
lambda_years <- \(f) unique(read_table(paste0(hist, f), show_col_types = FALSE)[[grep("year", names(read_table(paste0(hist, f), show_col_types = FALSE, n_max = 1)), ignore.case = TRUE)[1]]])

undata_years <- read_csv(paste0(ref, "undata_census_colombia.csv"), show_col_types = FALSE) |>
  filter(age != "Total") |> distinct(year) |> pull(year)
who_hom_years <- read_csv(paste0(ref, "who/who_homicide_colombia.csv"), show_col_types = FALSE) |> distinct(year) |> pull(year)
who_cause_years <- setdiff(1953:1977, c(1970, 1971, 1973))

# ---------------------------------------------------------------------------
# national ====
# ---------------------------------------------------------------------------
nat <- bind_rows(
  # population
  serie("Nacional", "Población", "Censos por edad y sexo (LAMBdA, UNdata; 1905 solo total)",
        sort(c(1905, union(lambda_years("lambda_Col_Popm.txt"), undata_years))), "Edad y sexo",
        "historical/lambda_Col_Pop{m,f}.txt; reference/undata_census_colombia.csv") |>
    mutate(detalle = if_else(year == 1905, "Solo total", detalle)),
  serie("Nacional", "Población", "Censos 1938, 1964 y 1973 por edad simple (OCR cuadros censales)", c(1938, 1964, 1973),
        "Edad y sexo", "historical/census_tables/census{1938,1973}_single_age_sex.csv; census1964_single_age_sex_zone.csv"),
  serie_csv("Nacional", "Población", "Anuarios DANE, población total", "national_population_clean_v02.csv",
            delim = ";", min_share = 0) |> mutate(detalle = "Solo total"),
  serie("Nacional", "Población", "WPP 2024, edad simple (hasta 2023; proyecta a 2100)", 1950:2023, "Edad y sexo",
        "reference/wpp2024_colombia_pop_single_age_1950-2023.csv"),
  serie("Nacional", "Población", "DANE proyecciones, suma municipal (hasta 2023; a 2042)", 1985:2023, "Edad y sexo",
        "DANEpop/*.xlsx"),
  # all-cause deaths
  serie_csv("Nacional", "Defunciones", "Anuarios DANE, total y sexo", "national_deaths_clean_v03.csv",
            delim = ";", min_share = 0) |>
    mutate(detalle = if_else(share > 0 & year %in% c(1934, 1939, 1950), "Solo total", detalle)),
  serie("Nacional", "Defunciones", "LAMBdA, edad y sexo", lambda_years("lambda_Col_Deathsm.txt"), "Edad y sexo",
        "historical/lambda_Col_Deaths{m,f}.txt"),
  serie("Nacional", "Defunciones", "OMS Mortality Database (CIE-7, CIE-8)", 1953:1977,
        "Edad, sexo y causa", "who_mdb/morticd07.zip, morticd08.zip") |>
    mutate(detalle = if_else(year %in% who_cause_years, detalle, "Edad y sexo")),
  serie("Nacional", "Defunciones", "DANE Registro de defunciones 1970-1978, cuadro 1: total nacional 1915-1984", 1915:1984,
        "Solo total", "historical/dane_defunciones_1970_1978_cuadro01_nacional_1915_1984.csv"),
  serie("Nacional", "Defunciones", "DANE Registro de defunciones 1970-1978, cuadros 3 y 6: edad y sexo", 1970:1978,
        "Edad y sexo", "historical/dane_defunciones_1970_1978_cuadro03_*.csv, cuadro06_*.csv"),
  serie("Nacional", "Defunciones", "EEVV microdatos DANE", 1979:2023, "Edad, sexo y causa",
        "micro/Defun*.txt, nofetal*.csv", parcial = 1979),
  serie("Nacional", "Defunciones", "WPP 2024, mx y componentes de crisis (hasta 2023)", 1950:2023, "Edad y sexo",
        "reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds; wpp2024_crises_colombia_*.csv"),
  # homicides and violent deaths
  serie_csv("Nacional", "Homicidios y violencia", "Anuarios DANE, suma de departamentos",
            "department_homicides_clean_v02.csv", min_share = 0, extra_parcial = 1943:1945),
  serie("Nacional", "Homicidios y violencia", "OMS, homicidio e intención no determinada por edad", who_cause_years,
        "Edad y sexo", "reference/who_violent_age_colombia_1953-1977.csv"),
  serie("Nacional", "Homicidios y violencia", "OMS, totales de homicidio (extracto)", who_hom_years, "Por sexo",
        "reference/who/who_homicide_colombia.csv"),
  serie("Nacional", "Homicidios y violencia", "Policía Nacional, suma de jurisdicciones", 1962:2002, "Solo total",
        "historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx"),
  serie("Nacional", "Homicidios y violencia", "EEVV, muertes violentas", 1979:2023, "Edad y sexo",
        "data_inter/deaths_munic_age_1979-2023.rds (dx_v)", parcial = 1979),
  serie("Nacional", "Homicidios y violencia", "MSE JEP-CEV-HRDAG, homicidios y desapariciones del conflicto",
        1985:2018, "Edad y sexo", "conflict/mse_national_age5_1985-2018.rds"),
  serie("Nacional", "Homicidios y violencia", "UCDP GED, muertes en eventos de conflicto", 1989:2024, "Solo total",
        "ucdp/GEDEvent_v25_1.csv"),
  # life tables
  serie("Nacional", "Tablas de vida", "NRC 1982, tablas de vida quinquenales (l(x) transcrito)", seq(1950, 1975, 5),
        "Edad y sexo", "reference/nrc1982_colombia_lifetables.csv"),
  serie("Nacional", "Tablas de vida", "LAMBdA 1x1", lambda_years("lambda_Col_mltper_1x1.txt"), "Edad y sexo",
        "historical/lambda_Col_{m,f}ltper_1x1.txt"),
  serie("Nacional", "Tablas de vida", "LAMBdA abreviadas pivotales (Drive)",
        c(1905, 1908, 1912, 1915, 1918, 1923, 1928, 1933, 1938, 1944, 1957, 1968, 1979, 1989, 1999, 2008),
        "Edad y sexo", "I:/My Drive/gits_drive/colombia_bereavement_pdr/data_input/life_tables_lambda.csv"),
  serie("Nacional", "Tablas de vida", "DANE abreviadas por quinquenio", 1985:2020, "Edad y sexo",
        "reference/dane_lifetables_nmx_1985_2020.csv"),
  serie("Nacional", "Tablas de vida", "WPP 2024 completas (hasta 2023; a 2100)", 1950:2023, "Edad y sexo",
        "reference/wpp2024_colombia_lt_complete_1950-2100.csv")
)

# ---------------------------------------------------------------------------
# departmental ====
# ---------------------------------------------------------------------------
dep <- bind_rows(
  serie_csv("Departamental", "Población", "Censos (anuarios), total y sexo", "department_population_clean_v03.csv",
            delim = ";"),
  serie("Departamental", "Población", "Censos 1938, 1951 y 1964 por edad quinquenal (OCR; 1964 también por zona)",
        c(1938, 1951, 1964), "Edad y sexo",
        "historical/census_tables/census1951_dept_age5_sex_1938_1951.csv; census1964_dept_age5_sex_zone.csv"),
  serie("Departamental", "Población", "Censo 1973 ajustado por cobertura, cabecera y resto (OCR cap. VIII)", 1973,
        "Solo total", "historical/census_tables/census1973_adjusted_population_units.csv"),
  serie("Departamental", "Población", "DANE proyecciones (hasta 2023; a 2042)", 1985:2023, "Edad y sexo",
        "DANEpop/*.xlsx"),
  serie_vitales("Departamental"),
  serie_csv("Departamental", "Defunciones", "Anuarios y boletines DANE, total y sexo",
            "department_deaths_clean_v06_territories_aggregated.csv", delim = ";"),
  serie("Departamental", "Defunciones", "DANE Registro de defunciones 1970-1978, por sección: sexo 1970-1984, edad 1970-1978",
        1970:1984, "Por sexo", "historical/dane_defunciones_1970_1978_cuadro02_*.csv, cuadro10_*.csv, cuadro11_*.csv") |>
    mutate(detalle = if_else(year <= 1978, "Edad y sexo", detalle)),
  serie("Departamental", "Defunciones", "EEVV (suma municipal)", 1979:2023, "Edad, sexo y causa",
        "data_inter/deaths_munic_age_1979-2023.rds", parcial = 1979),
  serie_csv("Departamental", "Homicidios y violencia", "Anuarios DANE, total y sexo",
            "department_homicides_clean_v02.csv", extra_parcial = 1943:1945),
  serie("Departamental", "Homicidios y violencia", "Policía Nacional, 40 jurisdicciones", 1962:2002, "Solo total",
        "historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx"),
  serie("Departamental", "Homicidios y violencia", "EEVV, muertes violentas", 1979:2023, "Edad y sexo",
        "data_inter/deaths_munic_age_1979-2023.rds (dx_v)", parcial = 1979),
  serie("Departamental", "Tablas de vida", "DANE abreviadas por quinquenio", 1985:2020, "Edad y sexo",
        "lifetables/tablas_utf8.txt; reference/dane_lifetables_nmx_1985_2020.csv")
)

# ---------------------------------------------------------------------------
# municipal ====
# ---------------------------------------------------------------------------
mun <- bind_rows(
  serie_csv("Municipal", "Población", "Censos (transcripción), total y sexo", "municipal_population_clean_v03.csv",
            unit = "municipality"),
  serie("Municipal", "Población", "DANE proyecciones (hasta 2023; a 2042)", 1985:2023, "Edad y sexo",
        "DANEpop/*.xlsx"),
  serie_csv("Municipal", "Defunciones", "Estadística vital y anuarios DANE, total y sexo",
            "municipal_deaths_clean_v03.csv", unit = "municipality"),
  serie_vitales("Municipal"),
  serie("Municipal", "Defunciones", "EEVV microdatos DANE", 1979:2023, "Edad, sexo y causa",
        "micro/Defun*.txt, nofetal*.csv", parcial = 1979),
  serie("Municipal", "Homicidios y violencia", "EEVV, muertes violentas", 1979:2023, "Edad y sexo",
        "data_inter/deaths_munic_age_1979-2023.rds (dx_v)", parcial = 1979),
  serie("Municipal", "Homicidios y violencia", "UCDP GED, eventos georreferenciados", 1989:2024, "Solo total",
        "ucdp/GEDEvent_v25_1.csv")
)

avail <- bind_rows(nat, dep, mun) |>
  mutate(detalle = if_else(detalle == "Edad, sexo y causa", "Edad y sexo", detalle),
         nivel = factor(nivel, niveles), dominio = factor(dominio, dominios),
         detalle = factor(detalle, detalles),
         estado = if_else(str_detect(serie, "en extracción"), "en extracción", "disponible")) |>
  arrange(nivel, dominio, serie, year)

# ---------------------------------------------------------------------------
# what was already held before the baseline ====
# ---------------------------------------------------------------------------
# For the figure of what is new. Held before Monday 2026-11-09: the EEVV microdata 1979-2023, the DANE
# projections, UCDP, the DANE abridged life tables, the WHO Mortality Database (deaths and homicides by age and sex, 1953-1977), WPP 2024 (Drive, August 2024), the anuario transcriptions
# (the col_gap_analysis_* files: total and sex only, no age) and the Policía homicide series 1962-2002
# (a single sheet of totals by jurisdiction). Everything else arrived on Monday or later: LAMBdA, UNdata
# censuses, the WHO Mortality Database by age, WPP 2024, MSE, the census and vital statistics tables
# extracted from PDF, the Registro de defunciones 1970-1978. The first two groups were checked against
# the files themselves: the col_gap files carry only total, male and female, and the EEVV start in 1979.
baseline <- as.Date("2026-11-09")
avail <- avail |>
  mutate(anterior = str_detect(serie, "^EEVV|^DANE proyecciones|^UCDP|^DANE abreviadas|^Anuarios|^Censos \\(|^Estadística vital y anuarios|^Policía") |
           startsWith(serie, "OMS") | startsWith(serie, "WPP"))

# ---------------------------------------------------------------------------
# figure 1: the information available, whatever the source ====
# ---------------------------------------------------------------------------
# One row per level and domain. The fill is the finest disaggregation that any
# source gives that year, so it changes with the stratification of the data and
# not with the source. A source at a finer geographic level counts for the
# coarser ones (municipal data add up to departmental and national, departmental
# data to national), life tables excepted because they do not add up; where the
# finest data of a year come only from such an addition a dot is drawn. Sources
# still being extracted from their PDF do not count; where they would raise the
# level a hollow outline is drawn. Years after 2023 are not drawn.
compute_info <- function(av) {
  contrib <- map_dfr(seq_along(niveles), \(i) {
    av |> filter(as.integer(nivel) >= i, year <= 2023,
                 as.integer(nivel) == i | dominio != "Tablas de vida") |>
      mutate(destino = niveles[i], via = if_else(as.integer(nivel) == i, "directa", "agregada"))
  })
  # the finest disaggregation, then complete before partial, then direct before added
  pick <- function(d) {
    d |> arrange(destino, dominio, year, desc(as.integer(detalle)), parcial, desc(via == "directa")) |>
      slice(1, .by = c(destino, dominio, year)) |>
      transmute(destino, dominio = as.character(dominio), year, detalle, parcial, via, serie)
  }
  have <- pick(filter(contrib, estado == "disponible"))
  soon <- pick(contrib) |> select(destino, dominio, year, detalle_soon = detalle, serie_soon = serie)
  # the finest disaggregation that a finer geographic level gives, to tell whether what is shown
  # can also be added up from there
  finer <- contrib |> filter(estado == "disponible", via == "agregada") |>
    summarise(finer_rank = max(as.integer(detalle)), .by = c(destino, dominio, year)) |>
    mutate(dominio = as.character(dominio))
  expand_grid(destino = niveles, dominio = as.character(dominios), year = 1902:2023) |>
    left_join(have, by = c("destino", "dominio", "year")) |>
    left_join(soon, by = c("destino", "dominio", "year")) |>
    left_join(finer, by = c("destino", "dominio", "year")) |>
    mutate(agregado = !is.na(via) & via == "agregada",   # the finest data exist only as a sum of a finer level
           # the same information also exists at a finer geographic level (whether or not what is shown comes from it)
           agregable = !is.na(detalle) & !is.na(finer_rank) & finer_rank >= as.integer(detalle),
           extraccion = !is.na(detalle_soon) & (is.na(detalle) | as.integer(detalle_soon) > as.integer(detalle)))
}
info <- compute_info(avail)
# the same, with what the project held before the baseline
info_before <- compute_info(filter(avail, anterior))

# ---------------------------------------------------------------------------
# figure 2: the sources ====
# ---------------------------------------------------------------------------
# row order: within each level and domain, series by first year
ord <- avail |> summarise(y0 = min(year), .by = c(nivel, dominio, serie)) |>
  arrange(nivel, dominio, y0, serie) |>
  mutate(key = paste(nivel, dominio, serie, sep = " | "), serie_f = factor(key, levels = rev(key)))
plot_df <- avail |> left_join(ord |> select(nivel, dominio, serie, serie_f), by = c("nivel", "dominio", "serie"))
strip_key <- \(x) sub("^.* \\| ", "", x)

fill_cols <- c("Solo total" = "#c6dbef", "Por sexo" = "#6baed6", "Edad y sexo" = "#2171b5")

theme_avail <- theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank(),
        panel.grid.major.x = element_line(colour = "grey85", linewidth = 0.3),
        panel.grid.minor.x = element_line(colour = "grey93", linewidth = 0.2),
        panel.spacing.y = unit(4, "pt"),
        strip.placement = "outside", strip.text.y.left = element_text(angle = 0, hjust = 1, face = "bold", size = 9),
        strip.background = element_rect(fill = "grey95", colour = NA),
        axis.text.y = element_text(size = 8.5), axis.text.x = element_text(size = 9),
        legend.position = "bottom", legend.box = "vertical", legend.box.just = "left",
        legend.justification = "left", legend.margin = margin(0, 0, 0, 0),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.subtitle = element_text(size = 9, colour = "grey30"), plot.caption = element_text(size = 8, colour = "grey40"))
x_axis <- scale_x_continuous(breaks = seq(1900, 2020, 10), minor_breaks = seq(1905, 2025, 10),
                             limits = c(1902, 2026), expand = c(0, 0))

# figure 1: one row per level and domain; empty rows stay visible as grey
lab_agregable <- "Franja inferior: el mismo detalle existe a un nivel geográfico más fino y se puede agregar"
lab_extraccion <- "Contorno: mejora posible, documento ya en el proyecto y en extracción"
lab_parcial <- "Punto: cobertura parcial del año (menos del 80 % de las unidades, año corto o concepto distinto)"
# a dot on the tiles of the years with partial coverage; white with a black rim so that it reads on every blue
dot_parcial <- \(d) geom_point(data = filter(d, parcial), aes(shape = lab_parcial), fill = "white", colour = "black",
                               size = 0.9, stroke = 0.3)
info_p <- info |> mutate(destino = factor(destino, niveles), dominio_f = factor(dominio, rev(dominios)))
# sources still being extracted from their PDF (label contains "en extracción") are drawn as an outline;
# the layer exists only while there are any
has_ext <- any(info_p$extraccion)
layer_ext <- if (has_ext) geom_tile(data = filter(info_p, extraccion), aes(colour = lab_extraccion),
                                    fill = NA, width = 1, height = 0.8, linewidth = 0.5)
p1 <- ggplot(info_p, aes(x = year, y = dominio_f)) +
  geom_tile(fill = "grey95", width = 1, height = 0.8) +
  geom_tile(data = filter(info_p, !is.na(detalle)), aes(fill = detalle), width = 1, height = 0.8) +
  geom_tile(data = filter(info_p, agregable), aes(y = as.numeric(dominio_f) - 0.36, colour = lab_agregable),
            fill = "black", width = 1, height = 0.09, linewidth = 0) +
  layer_ext +
  dot_parcial(info_p) +
  scale_fill_manual(values = fill_cols, name = "Mayor desagregación disponible", drop = FALSE, na.translate = FALSE) +
  scale_colour_manual(values = c(setNames("black", lab_agregable), if (has_ext) setNames("#d95f02", lab_extraccion)),
                      breaks = c(lab_agregable, if (has_ext) lab_extraccion), name = NULL) +
  scale_shape_manual(values = setNames(21, lab_parcial), name = NULL) +
  scale_y_discrete(drop = FALSE) +
  guides(fill = guide_legend(order = 1, nrow = 1),
         colour = guide_legend(order = 2, override.aes = list(fill = c("black", if (has_ext) NA),
                                                              linewidth = c(0, if (has_ext) 0.5))),
         shape = guide_legend(order = 3)) +
  x_axis +
  facet_grid(rows = vars(destino), switch = "y") +
  labs(x = NULL, y = NULL,
       title = "Información disponible por año, nivel geográfico y dominio, sin importar la fuente",
       subtitle = "El color marca la mayor desagregación que existe ese año (total, por sexo, o por edad y sexo), sea cual sea la fuente",
       caption = paste0("Los datos municipales se agregan a departamento y nación, y los departamentales a nación; las tablas de vida no se agregan.\n",
                        "Hasta 2023. Las fuentes, en la segunda figura. Script: code/32_data_availability.R")) +
  theme_avail
ggsave("figures/inventory/data_availability_information.png", p1, width = 14, height = 8.6, dpi = 200, bg = "white")

# ---------------------------------------------------------------------------
# two variants of figure 1 ====
# ---------------------------------------------------------------------------
# (a) what is new since the baseline: a year of a level and domain is new when it had no information
#     before or the finest disaggregation is now finer; the rest keeps its grey
# (b) the years in which the homicides can be estimated: no homicide data at that level, but deaths
#     by sex (or by age and sex) at that level, which is what the sex ratio of mortality needs
info_full <- info |>
  left_join(info_before |> select(destino, dominio, year, detalle_antes = detalle), by = c("destino", "dominio", "year")) |>
  left_join(info |> filter(dominio == "Defunciones") |> transmute(destino, year, defunciones = detalle), by = c("destino", "year")) |>
  mutate(nuevo = !is.na(detalle) & (is.na(detalle_antes) | as.integer(detalle) > as.integer(detalle_antes)),
         homicidios_estimables = dominio == "Homicidios y violencia" & is.na(detalle) & !is.na(defunciones) &
           as.integer(defunciones) >= as.integer(factor("Por sexo", detalles)))
info_p <- info_full |> mutate(destino = factor(destino, niveles), dominio_f = factor(dominio, rev(dominios)))

new_lev <- c(paste0("Antes: ", detalles), paste0("Nuevo: ", detalles))
new_cols <- c(setNames(c("#e3e3e3", "#b4b4b4", "#7d7d7d"), new_lev[1:3]), setNames(unname(fill_cols), new_lev[4:6]))
info_new <- info_p |> filter(!is.na(detalle)) |>
  mutate(cat = factor(paste0(if_else(nuevo, "Nuevo: ", "Antes: "), detalle), new_lev))
p_new <- ggplot(info_p, aes(x = year, y = dominio_f)) +
  geom_tile(fill = "grey95", width = 1, height = 0.8) +
  geom_tile(data = info_new, aes(fill = cat), width = 1, height = 0.8) +
  geom_tile(data = filter(info_p, agregable), aes(y = as.numeric(dominio_f) - 0.36, colour = lab_agregable),
            fill = "black", width = 1, height = 0.09, linewidth = 0) +
  dot_parcial(info_p) +
  scale_fill_manual(values = new_cols, name = NULL) +
  scale_colour_manual(values = setNames("black", lab_agregable), name = NULL) +
  scale_shape_manual(values = setNames(21, lab_parcial), name = NULL) +
  scale_y_discrete(drop = FALSE) +
  guides(fill = guide_legend(order = 1, ncol = 3, byrow = TRUE),
         colour = guide_legend(order = 2, override.aes = list(fill = "black", linewidth = 0)),
         shape = guide_legend(order = 3)) +
  x_axis +
  facet_grid(rows = vars(destino), switch = "y") +
  labs(x = NULL, y = NULL,
       title = paste0("Qué información es nueva desde el lunes ", format(baseline, "%Y-%m-%d")),
       subtitle = "Gris: ya se tenía antes del lunes. Azul: información nueva, porque ese año no había nada a ese nivel o ahora hay más desagregación. El tono marca la desagregación",
       caption = paste0("Antes del lunes: microdatos EEVV 1979-2023, proyecciones DANE, UCDP, tablas de vida DANE, OMS, WPP 2024, anuarios transcritos (total y sexo) y serie policial (total).\n",
                        "Los datos municipales se agregan a departamento y nación, y los departamentales a nación; las tablas de vida no se agregan. Hasta 2023. Script: code/32_data_availability.R")) +
  theme_avail
ggsave("figures/inventory/data_availability_information_new.png", p_new, width = 14, height = 8.9, dpi = 200, bg = "white")

lab_est <- "Naranja: homicidios sin dato directo a ese nivel, estimables a partir de la mortalidad total por sexo"
est_cols <- c(fill_cols, setNames("#e8801a", lab_est))
info_est <- info_p |> mutate(cat = case_when(homicidios_estimables ~ lab_est, !is.na(detalle) ~ as.character(detalle))) |>
  filter(!is.na(cat)) |> mutate(cat = factor(cat, names(est_cols)))
p_est <- ggplot(info_p, aes(x = year, y = dominio_f)) +
  geom_tile(fill = "grey95", width = 1, height = 0.8) +
  geom_tile(data = info_est, aes(fill = cat), width = 1, height = 0.8) +
  geom_tile(data = filter(info_p, agregable), aes(y = as.numeric(dominio_f) - 0.36, colour = lab_agregable),
            fill = "black", width = 1, height = 0.09, linewidth = 0) +
  dot_parcial(info_p) +
  scale_fill_manual(values = est_cols, name = NULL, drop = FALSE) +
  scale_colour_manual(values = setNames("black", lab_agregable), name = NULL) +
  scale_shape_manual(values = setNames(21, lab_parcial), name = NULL) +
  scale_y_discrete(drop = FALSE) +
  guides(fill = guide_legend(order = 1, ncol = 2, byrow = TRUE),
         colour = guide_legend(order = 2, override.aes = list(fill = "black", linewidth = 0)),
         shape = guide_legend(order = 3)) +
  x_axis +
  facet_grid(rows = vars(destino), switch = "y") +
  labs(x = NULL, y = NULL,
       title = "Dónde se pueden estimar los homicidios a partir de la mortalidad por sexo",
       subtitle = "En la fila de homicidios, el naranja marca los años sin dato directo en los que sí hay defunciones por sexo (o por edad y sexo) al mismo nivel geográfico",
       caption = paste0("Es una posibilidad, no un resultado: que la razón de sexo de la mortalidad total permita estimar los homicidios en cada periodo depende del modelo y de la calidad del registro. Hasta 2023.\n",
                        "Los datos municipales se agregan a departamento y nación, y los departamentales a nación. Script: code/32_data_availability.R")) +
  theme_avail
ggsave("figures/inventory/data_availability_information_homicides.png", p_est, width = 14, height = 8.9, dpi = 200, bg = "white")

cat("\nNew since the baseline (level, domain: years):\n")
print(info_full |> filter(nuevo) |> summarise(anios = n(), desde = min(year), hasta = max(year), .by = c(destino, dominio)), n = 20)
cat("\nHomicides that can be estimated (years):\n")
print(info_full |> filter(homicidios_estimables) |> summarise(anios = n(), .by = destino))

p <- ggplot(plot_df, aes(x = year, y = serie_f)) +
  geom_tile(aes(fill = detalle), width = 1, height = 0.72) +
  dot_parcial(plot_df) +
  scale_fill_manual(values = fill_cols, name = "Desagregación disponible", drop = FALSE) +
  scale_shape_manual(values = setNames(21, lab_parcial), name = NULL) +
  scale_y_discrete(labels = strip_key) +
  guides(fill = guide_legend(order = 1, nrow = 1), shape = guide_legend(order = 2)) +
  x_axis +
  facet_grid(rows = vars(nivel, dominio), scales = "free_y", space = "free_y", switch = "y") +
  labs(x = NULL, y = NULL,
       title = "Fuentes de información por año, nivel geográfico y desagregación",
       subtitle = "Una fila por fuente, con sus traslapes; el color marca el detalle de esa fuente ese año",
       caption = "WPP 2024 y proyecciones DANE recortadas en 2023. Las filas con «OCR» salen de los cuadros censales 1938, 1951, 1964 y 1973 extraídos de los PDF; «en extracción» = documento fuente ya en el proyecto, cuadros aún no extraídos. Script: code/32_data_availability.R") +
  theme_avail

n_rows <- n_distinct(plot_df$serie_f)
ggsave("figures/inventory/data_availability.png", p, width = 14, height = 2.6 + 0.3 * n_rows, dpi = 200, bg = "white")

# ---------------------------------------------------------------------------
# table ====
# ---------------------------------------------------------------------------
write_csv(avail |> select(nivel, dominio, serie, year, detalle, parcial, share, estado, archivo),
          "output/tables/data_availability.csv")
# the information available, one row per level, domain and year with something
write_csv(info_full |> filter(!is.na(detalle) | extraccion | homicidios_estimables) |>
            transmute(nivel = destino, dominio, year, detalle, parcial, agregado, agregable, fuente_del_detalle = serie,
                      detalle_antes_del_lunes = detalle_antes, nuevo_desde_el_lunes = nuevo, homicidios_estimables,
                      en_extraccion = extraccion, detalle_en_extraccion = if_else(extraccion, as.character(detalle_soon), NA_character_),
                      fuente_en_extraccion = if_else(extraccion, serie_soon, NA_character_)),
          "output/tables/data_availability_information.csv", na = "")

# compact summary per series (printed, and reused in the inventory document)
resumen <- avail |>
  summarise(años = {
    y <- sort(unique(year)); r <- split(y, cumsum(c(1, diff(y) != 1)))
    paste(map_chr(r, \(v) if (length(v) == 1) as.character(v) else paste0(v[1], "-", v[length(v)])), collapse = ", ")
  }, n = n_distinct(year), detalle = paste(levels(droplevels(detalle)), collapse = " / "),
  parcial = sum(parcial), .by = c(nivel, dominio, serie))
print(resumen, n = 60, width = 200)
