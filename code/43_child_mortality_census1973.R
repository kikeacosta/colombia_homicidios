# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 43. Child mortality around 1960-1972 from the 1973 census: Brass method
#     (Trussell variant) on children ever born and surviving
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The 1973 census asked women aged 15+ for their children ever born and
# surviving (Cuadros 21 and 21A, transcribed by code/historical/23). The
# proportion dead among the children of women aged 15-19 ... 45-49 becomes
# q(1), q(2), q(3), q(5), q(10), q(15), q(20) with the Trussell multipliers
#   k(i) = a(i) + b(i) P1/P2 + c(i) P2/P3 ,   q(x) = k(i) D(i)
# and each estimate is dated t(i) = a + b P1/P2 + c P2/P3 years before the
# census (24 October 1973). Coefficients: UN (1983) Manual X, tables 47 and
# 48, Coale-Demeny families; West is the main variant and the other three
# give the range. Each q(x) is turned into the 5q0 of the Coale-Demeny model
# table (both sexes) of the same family that has that q(x).
#
# Parities and non-response. 18.5 % of the women did not state their number
# of children (40 % at 15-19). El-Badry (1961): across age groups the share
# not stated is a linear function of the share reported childless, and the
# intercept is the true non-response; the rest are childless women left
# blank by the enumerator. The intercept is 0.4 % nationally, so nearly all
# the "no informan" are childless and P(i) = children / [women (1 - a)].
# D(i) does not depend on this choice; only P1/P2 and P2/P3 do. The variant
# that drops the not stated from the denominator is kept for comparison.
#
# What the data allow. By age of mother only nationally and by zone
# (cabecera, resto). By department the census table has no age, so only the
# overall proportion dead of the children of women aged 15+ can be computed.
# It is an index of level, not an estimate: it depends on the age of the
# mothers and on the omission of dead children. `q5_index` rescales it with
# the national ratio q(5) / overall proportion dead and is comparable across
# departments only under equal age structure and equal reporting.
#
# Checks: the UN IGME database has its own indirect series from this census
# (series 385) and the fitted UN IGME estimate; WPP 2024 5q0; and, for the
# departments, the DANE abridged tables of 1985-1990.
#
# input:  data_input/historical/census_tables/census1973_children_ever_born_age.csv
#         data_input/historical/census_tables/census1973_children_ever_born_units.csv
#         data_input/reference/trussell_child_mortality_coefficients.csv
#           (Manual X tables 47-48, as distributed in the R package u5mr 0.1.1)
#         data_input/reference/coale_demeny_child_q_by_level.csv
#           (Coale-Demeny q(1) ... q(20) by level, family and sex; same source)
#         data_input/reference/unigme2024_colombia_sdmx.csv (41)
#         data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv (31)
#         data_input/reference/dane_lifetables_nmx_1985_2020.csv (13)
# output: output/tables/child_mortality_brass_census1973.csv
#         output/tables/child_mortality_census1973_departments.csv
#         figures/06_components/child_mortality_census1973.png
#         figures/06_components/child_mortality_census1973_departments.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(tidyverse); library(ggrepel)})
options(width = 160)
dir.create("figures/06_components", showWarnings = FALSE, recursive = TRUE)

census_date <- 1973 + (as.numeric(as.Date("1973-10-24") - as.Date("1973-01-01")) + 0.5) / 365
ages7 <- c("15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49")
x_of  <- c(1, 2, 3, 5, 10, 15, 20)

ceb  <- read_csv("data_input/historical/census_tables/census1973_children_ever_born_age.csv", show_col_types = FALSE)
coef <- read_csv("data_input/reference/trussell_child_mortality_coefficients.csv", show_col_types = FALSE)
cd   <- read_csv("data_input/reference/coale_demeny_child_q_by_level.csv", show_col_types = FALSE) |> filter(sex == "both")

# ---- El-Badry: true non-response by zone -------------------------------------
d7 <- ceb |> filter(age %in% ages7) |> mutate(age = factor(age, ages7)) |> arrange(zone, age)
elbadry <- d7 |> group_by(zone) |>
  group_modify(\(d, g) { m <- lm(I(not_stated / women) ~ I(childless / women), data = d)
    tibble(intercept = unname(coef(m)[1]), slope = unname(coef(m)[2]), r2 = summary(m)$r.squared) }) |>
  ungroup() |> mutate(a = pmax(intercept, 0))
cat("El-Badry, share not stated on share childless (7 age groups):\n"); print(as.data.frame(elbadry), digits = 3)

# ---- Brass, Trussell variant ---------------------------------------------------
# q(x) -> 5q0 of the model table of the same family holding that q(x)
to_q5 <- function(q, x, model) {
  tab <- cd[cd$model == model, ]
  map2_dbl(q, x, \(qi, xi) { col <- tab[[paste0("q", xi)]]
    lev <- approx(rev(col), rev(tab$level), xout = qi)$y
    approx(tab$level, tab$q5, xout = lev)$y })
}
brass <- function(d, model, parity_variant, a) {
  women_p <- if (parity_variant == "El-Badry") d$women * (1 - a) else d$women - d$not_stated
  P <- d$children_ever_born / women_p
  D <- 1 - d$children_surviving / d$children_ever_born
  kc <- coef[coef$model == model & coef$coefficient == "k", ]; tc <- coef[coef$model == model & coef$coefficient == "t", ]
  stopifnot(all(kc$agegrp == ages7), all(tc$agegrp == ages7))
  k <- kc$a + kc$b * P[1] / P[2] + kc$c * P[2] / P[3]
  t <- tc$a + tc$b * P[1] / P[2] + tc$c * P[2] / P[3]
  tibble(age = ages7, x = x_of, women = d$women, parity = P, prop_dead = D, k = k, qx = k * D,
         t = t, ref_date = census_date - t, q5 = to_q5(k * D, x_of, model))
}
grid <- expand_grid(zone = c("total", "cabecera", "resto"), model = c("west", "north", "south", "east"),
                    parity_variant = c("El-Badry", "not stated excluded"))
est <- pmap_dfr(grid, \(zone, model, parity_variant)
  brass(d7[d7$zone == zone, ], model, parity_variant, elbadry$a[elbadry$zone == zone]) |>
    mutate(zone = zone, model = model, parity_variant = parity_variant, .before = 1)) |>
  # 15-19: few births, of very young mothers, at high risk; 20-24 also biased upwards
  mutate(use = case_when(age == "15-19" ~ "no", age == "20-24" ~ "caution", TRUE ~ "yes"))
stopifnot(!anyNA(est$q5))

# ---- references ---------------------------------------------------------------
raw  <- read_csv("data_input/reference/unigme2024_colombia_sdmx.csv", show_col_types = FALSE, guess_max = 5000)
igme <- raw |> filter(SERIES_NAME == "UN_IGME", INDICATOR == "MRY0T4", SEX == "_T") |>
  transmute(date = REF_DATE, q5 = OBS_VALUE / 1000, lo = LOWER_BOUND / 1000, hi = UPPER_BOUND / 1000) |> arrange(date)
igme_c73 <- raw |> filter(SERIES_CATEGORY == "CEN", SERIES_YEAR == "1973", INDICATOR == "MRY0T4", SEX == "_T") |>
  transmute(age = sub("Y([0-9]+)T([0-9]+)", "\\1-\\2", AGE_GROUP_OF_WOMEN), date = REF_DATE, q5 = OBS_VALUE / 1000, status = OBS_STATUS)
wpp  <- read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Sex == "Total", AgeGrpStart %in% c(0, 5)) |> group_by(Time) |>
  summarise(q5 = 1 - lx[AgeGrpStart == 5] / lx[AgeGrpStart == 0], .groups = "drop") |> transmute(date = Time + 0.5, q5)

est <- est |> mutate(q5_igme = approx(igme$date, igme$q5, xout = ref_date)$y,
                     q5_wpp  = approx(wpp$date, wpp$q5, xout = ref_date)$y) |>
  left_join(igme_c73 |> select(age, q5_igme_census1973 = q5, date_igme_census1973 = date), by = "age")
write_csv(est |> mutate(across(c(parity, prop_dead, k, qx, q5, q5_igme, q5_wpp), \(v) round(v, 5)), across(c(t, ref_date), \(v) round(v, 2))),
          "output/tables/child_mortality_brass_census1973.csv")

main <- est |> filter(model == "west", parity_variant == "El-Badry")
cat("\nNational, West, El-Badry parities (5q0 per 1,000):\n")
print(main |> filter(zone == "total") |>
        transmute(age, x, parity = round(parity, 2), prop_dead = round(prop_dead, 4), k = round(k, 3), ref_date = round(ref_date, 1),
                  q5 = round(1000 * q5), igme_c73 = round(1000 * q5_igme_census1973), igme = round(1000 * q5_igme), wpp = round(1000 * q5_wpp)) |> as.data.frame())
cat("\nBy zone, West (5q0 per 1,000) and ratio resto / cabecera:\n")
print(main |> select(age, zone, q5) |> pivot_wider(names_from = zone, values_from = q5) |>
        mutate(ratio = round(resto / cabecera, 2), across(c(total, cabecera, resto), \(v) round(1000 * v))) |> as.data.frame())
cat("\nSensitivity, national 5q0 per 1,000: range over the four families and the two parity variants:\n")
print(est |> filter(zone == "total") |> group_by(age) |> summarise(min = round(1000 * min(q5)), max = round(1000 * max(q5)), .groups = "drop") |> as.data.frame())

# ---- departments: proportion dead as an index of level -------------------------
units <- read_csv("data_input/historical/census_tables/census1973_children_ever_born_units.csv", show_col_types = FALSE)
nat <- ceb |> filter(age == "total") |> transmute(zone, pd_nat = 1 - children_surviving / children_ever_born)
q5_nat <- main |> filter(age == "30-34") |> select(zone, q5_nat = qx)       # q(5), about 1967
caribe <- c("Atlántico", "Bolívar", "Cesar", "Córdoba", "La Guajira", "Magdalena", "Sucre", "San Andrés y Providencia")
dep <- units |> left_join(nat, by = "zone") |> left_join(q5_nat, by = "zone") |>
  mutate(share_not_stated = not_stated / women, parity = children_ever_born / women,
         prop_dead = if_else(children_ever_born > 0, 1 - children_surviving / children_ever_born, NA_real_),
         ratio_to_national = prop_dead / pd_nat, q5_index = ratio_to_national * q5_nat,
         region = if_else(unit %in% caribe, "Caribe", "Resto del país"),
         small = women < 5000)                                        # comisarías: indigenous areas not tabulated
# DANE 1985-1990, both sexes (mean of the sex-specific rates), as in 33
dane <- read_csv("data_input/reference/dane_lifetables_nmx_1985_2020.csv", show_col_types = FALSE) |>
  filter(age_label %in% c("0", "1a4"), period == "1985-1990") |> select(area, sex, age, nmx) |>
  pivot_wider(names_from = age, values_from = nmx, names_prefix = "m") |>
  mutate(q5 = 1 - (1 - m0 / (1 + 0.8 * m0)) * (1 - 4 * m1 / (1 + 2.5 * m1))) |>
  group_by(area) |> summarise(q5_dane_1985_1990 = mean(q5), .groups = "drop") |>
  mutate(unit = recode(area, "Bogotá D.C." = "Bogotá D.E.", "Valle del Cauca" = "Valle", "San Andrés" = "San Andrés y Providencia"))
dep <- dep |> left_join(dane |> select(unit, q5_dane_1985_1990), by = "unit")
write_csv(dep |> transmute(census_year, unit, unit_type, region, zone, women, share_not_stated = round(share_not_stated, 4), parity = round(parity, 3),
                           prop_dead = round(prop_dead, 4), ratio_to_national = round(ratio_to_national, 3), q5_index = round(q5_index, 4),
                           q5_dane_1985_1990 = round(q5_dane_1985_1990, 4), small_population = small),
          "output/tables/child_mortality_census1973_departments.csv", na = "")
dt <- dep |> filter(zone == "total", !small, !is.na(q5_dane_1985_1990))
cat("\nDepartments (zone total), index of level against DANE 1985-1990; Spearman:",
    round(cor(dt$q5_index, dt$q5_dane_1985_1990, method = "spearman"), 2), "all,",
    round(cor(dt$q5_index[dt$region != "Caribe"], dt$q5_dane_1985_1990[dt$region != "Caribe"], method = "spearman"), 2), "without the Caribbean\n")
print(dt |> arrange(desc(q5_index)) |> transmute(unit, region, prop_dead = round(prop_dead, 3), q5_index = round(1000 * q5_index),
                                                 dane_85_90 = round(1000 * q5_dane_1985_1990), not_stated = round(share_not_stated, 2)) |> as.data.frame())

# ---- figures ------------------------------------------------------------------
ink <- "#0b0b0b"; ink2 <- "#52514e"; muted <- "#8a8983"
zone_lab <- c(total = "Total nacional", cabecera = "Cabecera", resto = "Resto (rural)")
zone_col <- c("Total nacional" = "#2a78d6", "Cabecera" = "#eb6834", "Resto (rural)" = "#1baf7a")
pm <- main |> filter(use != "no") |> mutate(serie = factor(zone_lab[zone], zone_lab))
rng <- est |> filter(zone == "total", use != "no") |> group_by(age) |>
  summarise(date = mean(ref_date[model == "west" & parity_variant == "El-Badry"]), lo = min(q5), hi = max(q5), .groups = "drop")
lab_end <- pm |> group_by(serie) |> slice_max(ref_date, n = 1) |> ungroup()
p1 <- ggplot() +
  geom_ribbon(data = filter(igme, date >= 1955, date <= 1976), aes(date, ymin = 1000 * lo, ymax = 1000 * hi), fill = muted, alpha = 0.18) +
  geom_line(data = filter(igme, date >= 1955, date <= 1976), aes(date, 1000 * q5, linetype = "UN IGME 2024 (ajuste, IC 90 %)"), colour = ink2, linewidth = 0.7) +
  geom_line(data = filter(wpp, date >= 1955, date <= 1976), aes(date, 1000 * q5, linetype = "WPP 2024"), colour = ink2, linewidth = 0.7) +
  geom_linerange(data = rng, aes(date, ymin = 1000 * lo, ymax = 1000 * hi), colour = "#2a78d6", linewidth = 0.5, alpha = 0.6) +
  geom_line(data = pm, aes(ref_date, 1000 * q5, colour = serie), linewidth = 0.7) +
  geom_point(data = pm, aes(ref_date, 1000 * q5, colour = serie, alpha = use), size = 2.6) +
  geom_point(data = filter(igme_c73, age %in% ages7[-1]), aes(date, 1000 * q5, shape = "Serie indirecta del censo de 1973 en la base UN IGME"),
             colour = ink, size = 2.6, stroke = 0.7) +
  geom_text(data = filter(pm, zone == "resto"), aes(ref_date, 1000 * q5, label = age), colour = ink2, size = 3, vjust = -1.1) +
  geom_text(data = lab_end, aes(ref_date, 1000 * q5 - if_else(zone == "cabecera", 5, 0), label = serie), colour = ink, size = 3.3, hjust = 0, nudge_x = 0.35) +
  scale_colour_manual(values = zone_col, name = NULL) +
  scale_alpha_manual(values = c(yes = 1, caution = 0.45), guide = "none") +
  scale_linetype_manual(values = c("UN IGME 2024 (ajuste, IC 90 %)" = "solid", "WPP 2024" = "22"), name = NULL) +
  scale_shape_manual(values = c("Serie indirecta del censo de 1973 en la base UN IGME" = 1), name = NULL) +
  scale_x_continuous(breaks = seq(1956, 1976, 4), limits = c(1955, 1977.5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(60, 180, 20)) + coord_cartesian(ylim = c(60, 180)) +
  labs(title = "Mortalidad antes de los cinco años según el censo de 1973",
       subtitle = "5q0 por mil nacidos vivos, método de Brass (variante Trussell, familia Oeste) sobre hijos nacidos vivos y sobrevivientes;\ncada punto es un grupo de edad de las madres (rotulado sobre la serie rural) y la barra el rango entre familias Coale-Demeny y variantes de paridad",
       x = "Fecha de referencia de la estimación", y = "5q0 (por mil)",
       caption = "Punto atenuado: madres de 20-24, sesgado al alza. Fuentes: DANE, censo 1973, Cuadro 21 (census_tables); UN IGME 2024; WPP 2024. Script: code/43_child_mortality_census1973.R") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", legend.box = "vertical", legend.margin = margin(0, 0, 0, 0), plot.title.position = "plot",
        panel.grid.minor = element_blank(), plot.caption = element_text(colour = ink2, hjust = 0), plot.caption.position = "plot")
ggsave("figures/06_components/child_mortality_census1973.png", p1, width = 11, height = 6.8, dpi = 200, bg = "white")

reg_col <- c("Caribe" = "#eb6834", "Resto del país" = "#2a78d6")
p2 <- ggplot(dt, aes(1000 * q5_dane_1985_1990, 1000 * q5_index)) +
  geom_point(aes(colour = region, size = women), alpha = 0.85) +
  geom_text_repel(aes(label = unit), colour = ink, size = 3, seed = 1, box.padding = 0.35, min.segment.length = 0.3, segment.colour = muted) +
  scale_colour_manual(values = reg_col, name = NULL) +
  scale_size_area(max_size = 9, breaks = c(1e5, 5e5), labels = c("100 mil", "500 mil"), name = "Mujeres de 15 y más") +
  labs(title = "Hijos fallecidos declarados en 1973 frente a la mortalidad de 1985-1990, por departamento",
       subtitle = "Eje vertical: índice de nivel hacia 1967 (proporción de hijos fallecidos de las mujeres de 15 y más, reescalada al q(5) nacional);\nsin edad de las madres, no es una estimación. A igual mortalidad posterior, la costa Caribe declara menos hijos fallecidos que el resto",
       x = "5q0 por mil, tablas abreviadas DANE 1985-1990", y = "Índice de 5q0 por mil, censo 1973",
       caption = "Sin las comisarías (áreas indígenas fuera del tabulado). Fuentes: DANE, censo 1973, Cuadro 21A; DANE, tablas abreviadas 1985-2020. Script: code/43_child_mortality_census1973.R") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", plot.title.position = "plot", panel.grid.minor = element_blank(),
        plot.caption = element_text(colour = ink2, hjust = 0), plot.caption.position = "plot")
ggsave("figures/06_components/child_mortality_census1973_departments.png", p2, width = 10.5, height = 7.5, dpi = 200, bg = "white")
