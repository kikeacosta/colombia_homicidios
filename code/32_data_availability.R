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
# projections, MSE, UCDP, Policía) are declared with their known ranges.
# Series projected beyond 2023 (WPP to 2100, DANE to 2042) are cut at 2023.
#
# output: figures/inventory/data_availability.png
#         output/tables/data_availability.csv  (nivel, dominio, serie, year,
#                                               detalle, parcial, archivo)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(tidyverse))
dir.create("figures/inventory", showWarnings = FALSE, recursive = TRUE)

hist <- "data_input/historical/"
ref <- "data_input/reference/"
gap <- \(f) paste0(hist, "col_gap_analysis_1920_1985_", f)

detalles <- c("Solo total", "Por sexo", "Edad y sexo", "Edad, sexo y causa")
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
  serie("Nacional", "Población", "Censos 1938 y 1973 por edad simple (OCR cuadros censales)", c(1938, 1973),
        "Edad y sexo", "historical/census_tables/ (en incorporación)"),
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
  serie("Nacional", "Defunciones", "LAMBdA, 19 grupos de causa", lambda_years("lambda_Col_Cause19_Deathsm.txt"),
        "Edad, sexo y causa", "historical/lambda_Col_Cause19_Deaths{m,f}.txt"),
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
  serie("Departamental", "Población", "Censos 1938 y 1951 por edad quinquenal (OCR Cuadro 10, 1951)", c(1938, 1951),
        "Edad y sexo", "historical/census_tables/ (en incorporación)"),
  serie("Departamental", "Población", "Censo 1973 ajustado por cobertura, cabecera y resto (OCR cap. VIII)", 1973,
        "Solo total", "historical/census_tables/ (en incorporación)"),
  serie("Departamental", "Población", "DANE proyecciones (hasta 2023; a 2042)", 1985:2023, "Edad y sexo",
        "DANEpop/*.xlsx"),
  serie_csv("Departamental", "Defunciones", "Anuarios y boletines DANE, total y sexo",
            "department_deaths_clean_v06_territories_aggregated.csv", delim = ";"),
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
  serie("Municipal", "Defunciones", "EEVV microdatos DANE", 1979:2023, "Edad, sexo y causa",
        "micro/Defun*.txt, nofetal*.csv", parcial = 1979),
  serie("Municipal", "Homicidios y violencia", "EEVV, muertes violentas", 1979:2023, "Edad y sexo",
        "data_inter/deaths_munic_age_1979-2023.rds (dx_v)", parcial = 1979),
  serie("Municipal", "Homicidios y violencia", "UCDP GED, eventos georreferenciados", 1989:2024, "Solo total",
        "ucdp/GEDEvent_v25_1.csv")
)

avail <- bind_rows(nat, dep, mun) |>
  mutate(nivel = factor(nivel, niveles), dominio = factor(dominio, dominios),
         detalle = factor(detalle, detalles)) |>
  arrange(nivel, dominio, serie, year)

# ---------------------------------------------------------------------------
# figure ====
# ---------------------------------------------------------------------------
# row order: within each level and domain, series by first year
ord <- avail |> summarise(y0 = min(year), .by = c(nivel, dominio, serie)) |>
  arrange(nivel, dominio, y0, serie) |>
  mutate(key = paste(nivel, dominio, serie, sep = " | "), serie_f = factor(key, levels = rev(key)))
plot_df <- avail |> left_join(ord |> select(nivel, dominio, serie, serie_f), by = c("nivel", "dominio", "serie"))
strip_key <- \(x) sub("^.* \\| ", "", x)

fill_cols <- c("Solo total" = "#c6dbef", "Por sexo" = "#6baed6", "Edad y sexo" = "#2171b5",
               "Edad, sexo y causa" = "#08306b")

p <- ggplot(plot_df, aes(x = year, y = serie_f, fill = detalle, alpha = parcial)) +
  geom_tile(width = 1, height = 0.72) +
  scale_fill_manual(values = fill_cols, name = "Desagregación disponible", drop = FALSE) +
  scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = 0.4), labels = c("completo", "parcial"),
                     name = "Cobertura del año") +
  scale_y_discrete(labels = strip_key) +
  guides(fill = guide_legend(order = 1, nrow = 1),
         alpha = guide_legend(order = 2, nrow = 1, override.aes = list(fill = "#2171b5"))) +
  scale_x_continuous(breaks = seq(1900, 2020, 10), minor_breaks = seq(1905, 2025, 10),
                     limits = c(1902, 2026), expand = c(0, 0)) +
  facet_grid(rows = vars(nivel, dominio), scales = "free_y", space = "free_y", switch = "y") +
  labs(x = NULL, y = NULL,
       title = "Disponibilidad de datos por año, nivel geográfico y desagregación",
       subtitle = "Una fila por fuente; el color marca el mayor detalle disponible ese año; los tonos claros, cobertura parcial (menos del 80 % de las unidades, año corto o concepto distinto)",
       caption = "WPP 2024 y proyecciones DANE recortadas en 2023. Las filas con «OCR» salen de los cuadros censales 1938, 1951 y 1973 extraídos de los PDF. Script: code/32_data_availability.R") +
  theme_minimal(base_size = 11) +
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

n_rows <- n_distinct(plot_df$serie_f)
ggsave("figures/inventory/data_availability.png", p, width = 14, height = 2.6 + 0.3 * n_rows, dpi = 200, bg = "white")

# ---------------------------------------------------------------------------
# table ====
# ---------------------------------------------------------------------------
write_csv(avail |> select(nivel, dominio, serie, year, detalle, parcial, share, archivo),
          "output/tables/data_availability.csv")

# compact summary per series (printed, and reused in the inventory document)
resumen <- avail |>
  summarise(años = {
    y <- sort(unique(year)); r <- split(y, cumsum(c(1, diff(y) != 1)))
    paste(map_chr(r, \(v) if (length(v) == 1) as.character(v) else paste0(v[1], "-", v[length(v)])), collapse = ", ")
  }, n = n_distinct(year), detalle = paste(levels(droplevels(detalle)), collapse = " / "),
  parcial = sum(parcial), .by = c(nivel, dominio, serie))
print(resumen, n = 60, width = 200)
