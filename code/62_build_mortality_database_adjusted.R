# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 62. Colombia mortality database, phase 3: ADJUSTED deaths by component, sex
#     and age (default scenario "ajustada_por_componentes")
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Puts the project's own adjusted mortality into the tidy format of phases 1
# and 2 (output/mortalidad_colombia/). Nothing is re-estimated here: the
# columns are read from the outputs of
#   42_mortality_components_adjusted.R   national 1950-2023 (WPP population)
#   50_dept_mortality_adjusted.R         departmental 1985-2023 (DANE population)
# with the components natural, other external, violent (incl. the MSE conflict
# shortfall 1985-2018, 27/51) and crisis (47), and the registered deaths of
# phase 2 next to them. See output/mortalidad_colombia/diccionario_ajustada.md.
#
# Run from the project root:  Rscript code/62_build_mortality_database_adjusted.R
#
# input : output/tables/mortality_adjusted_components_1950-2023.csv   (42)
#         output/tables/mortality_adjusted_summary.csv                (42, check 3)
#         output/tables/dept_mortality_adjusted_components_1985-2023.csv (50)
#         output/tables/dept_mortality_adjusted_summary.csv           (50, check 3)
#         output/tables/dept_completeness_applied_1985-2023.csv       (50)
#         output/tables/dept_vs_national_adjusted_deaths.csv          (50, check 5)
#         output/tables/mse_departments_1985-2018.csv                 (51, check 9)
#         output/tables/deaths_by_cause_sex_age_1953-2023.csv         (30, check 8)
#         output/tables/deaths_components_registered_1950-2023.csv    (40, check 8)
#         output/mortalidad_colombia/mortalidad_colombia_edad.csv.gz  (phase 2)
#         output/mortalidad_colombia/unidades_colombia.csv            (phase 1)
# output: output/mortalidad_colombia/
#           mortalidad_colombia_ajustada.csv.gz
#           unidades_ajustada.csv
#           verification_ajustada.csv (+ _detalle, _cobertura, _razon_anual)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages(library(data.table))
setDTthreads(0)
stopifnot(file.exists("code/42_mortality_components_adjusted.R"))   # project root
out_dir <- "output/mortalidad_colombia"
tb <- "output/tables"

ages <- c(0, 1, seq(5, 80, 5))
age_lab <- c("0", "1-4", paste0(seq(5, 75, 5), "-", seq(9, 79, 5)), "80+")
age_fin <- c(0, 4, seq(9, 79, 5), NA)
amazon <- c("91", "94", "95", "97", "99")
amazon_name <- "Amazonía (Amazonas, Guainía, Guaviare, Vaupés, Vichada)"
sex_lab <- c(f = "mujeres", m = "hombres")
mse_years <- 1985:2018
bad_years <- c(1969:1971, 1978:1979)   # registration breakdowns of 42
decade <- function(y) paste0(y %/% 10 * 10, "s")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# inputs ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nat <- fread(file.path(tb, "mortality_adjusted_components_1950-2023.csv"))
dep <- fread(file.path(tb, "dept_mortality_adjusted_components_1985-2023.csv"), colClasses = list(character = "cod"))
cc_dep <- fread(file.path(tb, "dept_completeness_applied_1985-2023.csv"), colClasses = list(character = "cod"))
sum_nat <- fread(file.path(tb, "mortality_adjusted_summary.csv"))[series == "Ajustada por componentes"]
sum_dep <- fread(file.path(tb, "dept_mortality_adjusted_summary.csv"), colClasses = list(character = "cod"))[series == "Ajustada por componentes"]
cmp_script <- fread(file.path(tb, "dept_vs_national_adjusted_deaths.csv"))
mse_dep <- fread(file.path(tb, "mse_departments_1985-2018.csv"), colClasses = list(character = "cod"))
cause <- fread(file.path(tb, "deaths_by_cause_sex_age_1953-2023.csv"))
comp_reg <- fread(file.path(tb, "deaths_components_registered_1950-2023.csv"))
p2 <- fread(file.path(out_dir, "mortalidad_colombia_edad.csv.gz"), colClasses = list(character = c("cod", "edad")))
uni <- fread(file.path(out_dir, "unidades_colombia.csv"), colClasses = "character")

# units: names of phase 1 (cod -> unidad); the Amazon group is "9X"
unit_names <- unique(uni[nivel == "departamental" & !is.na(cod) & fuente_id == "dane_eevv", .(cod, unidad)])
stopifnot(!anyDuplicated(unit_names$cod))
unit_names <- rbind(unit_names[!cod %in% amazon], data.table(cod = "9X", unidad = amazon_name))
setkey(unit_names, cod)
stopifnot(all(dep$cod %in% unit_names$cod), uniqueN(dep$cod) == 29)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# long table by component (sex f / m) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rate_cols <- c(todas = "mx_total", natural = "mx_natural", otras_externas = "mx_other_external", violenta = "mx_violent", crisis = "mx_crisis")

nat[, `:=`(nivel = "nacional", cod = "00", unidad = "Colombia", anio_malo = year %in% bad_years,
           completitud_modelo = NA_real_, reg_proy = mx_registered * pop,
           metodo_comp = method_completeness)]
dep <- merge(dep, cc_dep[, .(cod, year, sex, k_cal = k)], by = c("cod", "year", "sex"), all.x = TRUE)
stopifnot(!anyNA(dep$k_cal))
dep[, `:=`(nivel = "departamental", unidad = unit_names[cod, unidad], anio_malo = NA,
           completitud_modelo = completeness_model, reg_proy = registered,
           metodo_comp = "empírica departamental (Adair-Lopez modelo 1, suavizada) calibrada a la completitud nacional")]
base <- rbind(
  nat[, .(nivel, cod, unidad, anio = year, sex, age, pop, mx_total, mx_natural, mx_other_external, mx_violent, mx_crisis,
          completitud = completeness_natural, completitud_modelo, reg_proy, method_natural, metodo_comp, anio_malo)],
  dep[, .(nivel, cod, unidad, anio = year, sex, age, pop, mx_total, mx_natural, mx_other_external, mx_violent, mx_crisis,
          completitud = completeness_natural, completitud_modelo, reg_proy, method_natural, metodo_comp, anio_malo)])
stopifnot(!anyNA(base$age), all(base$age %in% ages))

long <- rbindlist(lapply(names(rate_cols), function(cz)
  base[, .(nivel, cod, unidad, anio, sex, age, pop, causa = cz, tasa = get(rate_cols[cz]), completitud, completitud_modelo, reg_proy,
           method_natural, metodo_comp, anio_malo, crisis_cell = mx_crisis * pop > 0)]))
long[, def := tasa * pop]

# the completeness is the one the adjustment applied to the NATURAL and OTHER EXTERNAL deaths
# (natural: ages 5+ only; under five the natural component comes from UN IGME). It is not applied to violenta or crisis
long[, `:=`(completitud = fifelse(causa == "natural" & age < 5, NA_real_,
                                  fifelse(causa %in% c("natural", "otras_externas"), completitud, NA_real_)),
            completitud_modelo = fifelse(causa == "natural" & age < 5, NA_real_,
                                         fifelse(causa %in% c("natural", "otras_externas"), completitud_modelo, NA_real_)),
            reg_proy = fifelse(causa == "todas", reg_proy, NA_real_))]

# sex total: deaths and population summed over sexes; the rate is deaths / population (not a sum of rates)
key <- c("nivel", "cod", "unidad", "anio", "causa", "age")
tot <- long[, .(sex = "t", pop = sum(pop), def = sum(def), reg_proy = if (all(is.na(reg_proy))) NA_real_ else sum(reg_proy),
                completitud = NA_real_, completitud_modelo = NA_real_, method_natural = method_natural[1], metodo_comp = metodo_comp[1],
                anio_malo = anio_malo[1], crisis_cell = any(crisis_cell)), by = key]
tot[, tasa := def / pop]
long <- rbind(long, tot, fill = TRUE)
long[, sexo := c(f = "mujeres", m = "hombres", t = "total")[sex]]
ia <- match(long$age, ages)
long[, `:=`(edad = age_lab[ia], edad_inicio = as.integer(age), edad_fin = as.integer(age_fin[ia]))]

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# registered deaths of phase 2 (causa todas), summed to the adjusted age groups ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
std_lab <- c(age_lab[-length(age_lab)], "80-84", "85+", "80+")
r2 <- p2[causa == "todas" & edad %in% std_lab & ((nivel == "nacional" & anio >= 1950) | (nivel == "departamental" & anio >= 1985)) &
           (nivel == "nacional" | cod %in% c(unit_names$cod, amazon))]
r2[, age := fifelse(edad %in% c("80-84", "85+", "80+"), 80L, edad_inicio)]
# stage 1: per original unit; the 80+ group needs 80-84 and 85+, or 80+ as published
r2a <- r2[, .(def = sum(def_registradas), n = .N, has80p = any(edad == "80+"), n80 = sum(edad %in% c("80-84", "85+")),
              fuente = paste(sort(unique(fuente_id)), collapse = "+")), by = .(nivel, cod, anio, sexo, age)]
r2a <- r2a[(age < 80 & n == 1) | (age == 80 & (has80p | n80 == 2))]
# stage 2: the Amazon departments are summed into the group "9X" (all five needed)
r2a[, cod := fifelse(cod %in% amazon, "9X", cod)]
r2b <- r2a[, .(def_registradas = as.numeric(sum(def)), n_units = .N, fuente_registradas = paste(sort(unique(fuente)), collapse = "+")), by = .(nivel, cod, anio, sexo, age)]
r2b <- r2b[cod != "9X" | n_units == 5][, n_units := NULL]
long <- merge(long, r2b, by = c("nivel", "cod", "anio", "sexo", "age"), all.x = TRUE, sort = FALSE)
long[causa != "todas", `:=`(def_registradas = NA_real_, fuente_registradas = NA_character_)]

# registered violent deaths (30; national, 1953-2023, 80+ open); sex total = men + women
vr <- cause[, .(anio = year, sex, age, vr = violent_reg)]
vr <- rbind(vr, vr[, .(sex = "t", vr = sum(vr)), by = .(anio, age)])
long <- merge(long, vr[, .(anio, sex, age, vr)], by = c("anio", "sex", "age"), all.x = TRUE, sort = FALSE)
long[causa == "violenta" & nivel == "nacional" & !is.na(vr), `:=`(def_registradas = vr, fuente_registradas = "deaths_by_cause_sex_age_1953-2023 (30)")]
long[, vr := NULL]
long[nivel == "departamental" & causa == "violenta", def_registradas := NA_real_]

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# flags, quality, method, notes ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
q30 <- unique(cause[, .(anio = year, q30 = quality)])
long <- merge(long, q30, by = "anio", all.x = TRUE, sort = FALSE)
long[, incluye_mse := causa %in% c("todas", "violenta") & anio %in% mse_years]
long[, incluye_crisis := causa %in% c("todas", "crisis") & crisis_cell]
long[, anio_registro_colapsado := anio_malo]
long[, escenario := "ajustada_por_componentes"]
long[, fuente_id := "proyecto"]

# quality: observada (registered counts as they are), escalada (registered / completeness, or external counts spread by the
# registered violent age pattern), modelada (smoothed or model-based natural deaths, or UN IGME under five; an addition to the
# phase 1-2 vocabulary), interpolada (violent shares of years without cause detail), MSE (the MSE conflict shortfall is in the cell)
long[, calidad := fcase(
  causa == "violenta" & anio %in% mse_years, "MSE",
  causa == "violenta" & (anio < 1953 | q30 %in% "interpolated"), "interpolada",
  causa == "violenta", "observada",
  causa == "natural" & method_natural == "corregida, anual", "escalada",
  causa == "natural", "modelada",
  causa == "otras_externas", "escalada",
  causa == "crisis", "escalada",
  causa == "todas" & anio %in% mse_years, "MSE",
  causa == "todas", "escalada")]

long[, metodo := fcase(
  causa == "todas", paste0("suma de componentes; natural: ", method_natural, "; completitud: ", metodo_comp, "; menores de 5 años: tasa total UN IGME + crisis"),
  causa == "natural", paste0(method_natural, "; completitud: ", metodo_comp),
  causa == "otras_externas", paste0("registradas / completitud natural (supuesto); completitud: ", metodo_comp),
  causa == "violenta", fifelse(anio %in% mse_years, "registradas (homicidio + intención no determinada + intervención legal) + déficit MSE; sin factor de completitud",
                                "registradas (violentas, dx_v); sin factor de completitud"),
  causa == "crisis", "pisos Policía Nacional / La Violencia (Romero-Prieto y Meisel-Roca 2019) sobre las violentas registradas + Armero 1985; sin factor de completitud")]
long[nivel == "departamental" & causa == "violenta" & anio %in% mse_years,
     metodo := "registradas (homicidio + intención no determinada + intervención legal) + parte departamental del déficit MSE nacional (reparto proporcional a las violentas registradas / MSE regional x participación documentada, 51); sin factor de completitud"]
long[nivel == "departamental" & causa == "crisis", metodo := "Armero 1985 (22 654 muertes: 1 100 a Caldas, el resto a Tolima; supuesto); sin otras muertes de crisis desde 1985"]
long[nivel == "departamental" & causa == "todas" , metodo := sub("menores de 5 años: tasa total UN IGME + crisis", "menores de 5 años: tasa total UN IGME x índice DANE departamental + crisis", metodo, fixed = TRUE)]

def_violenta <- "homicidio + intención no determinada + intervención legal (CIE-9 E960-E978; CIE-10 X85-Y09, Y10-Y34 intención no determinada, Y35-Y36 intervención legal; antes de 1979 las violentas de la OMS: A149 'homicidio y operaciones de guerra' en CIE-7, A148+A149 en CIE-8) registradas, más el déficit del conflicto armado de la MSE en 1985-2018 (homicidios no registrados como violentos + desapariciones forzadas), sin factor de completitud; NO es la categoría CIE de homicidio"
nota_base <- c(
  todas = "todas = natural + otras_externas + violenta + crisis. def_ajustadas = tasa_ajustada x poblacion; total = hombres + mujeres",
  natural = "causas no externas, incluidas las mal definidas (supuesto: son naturales); registradas / completitud, suavizadas (5-79) o modelo relacional (80+); menores de 5 años: UN IGME todas las causas menos otras externas y violentas",
  otras_externas = "accidentes, suicidio y demás causas externas excepto las violentas; registradas / la misma completitud de las naturales (supuesto sin evidencia propia)",
  violenta = paste0("violenta = ", def_violenta),
  crisis = "muertes que el registro nunca vio, de conteos externos (47): piso Policía Nacional 1963-1968 y 1978-1984, La Violencia 1950-1969 (Romero-Prieto y Meisel-Roca 2019) y Armero 1985; repartidas con el patrón de edad de las violentas registradas; sin factor de completitud")
long[, nota := nota_base[causa]]
long[nivel == "nacional", nota := paste0(nota, ". Población WPP 2024")]
long[nivel == "departamental", nota := paste0(nota, ". Población DANE (retroproyección 1985-2017, proyecciones del censo 2018); Amazonía agrupada ('9X')")]
long[causa == "violenta" & is.na(def_registradas) & nivel == "nacional", nota := paste0(nota, ". def_registradas no disponible (antes de 1953)")]
long[causa == "violenta" & nivel == "departamental", nota := paste0(nota, ". def_registradas no disponible por departamento en estos archivos")]
long[causa == "violenta" & q30 %in% "interpolated", nota := paste0(nota, ". Violentas registradas interpoladas por el proyecto (1970, 1971: sin causas por edad)")]
long[causa == "violenta" & anio < 1953, nota := paste0(nota, ". 1950-1952: sin detalle de causa, participaciones interpoladas")]
long[causa %in% c("natural", "otras_externas") & age < 5, nota := paste0(nota, ". Menores de 5 años: completitud no aplicada (UN IGME)")]
long[anio_malo %in% TRUE & causa %in% c("natural", "todas"), nota := paste0(nota, ". Año de colapso del registro (1969-1971, 1978-1979): natural 5+ toma el valor ajustado del suavizado")]
long[nivel == "departamental" & anio == 1985 & cod %in% c("73", "17") & causa %in% c("todas", "crisis"), nota := paste0(nota, ". Incluye Armero (1985)")]
long[nivel == "departamental" & causa %in% c("natural", "otras_externas") & anio >= 2020 & age >= 5, nota := paste0(nota, ". Completitud fijada en el valor de 2019 por el modelo departamental, luego calibrada")]
long[sexo == "total" & causa %in% c("natural", "otras_externas"), nota := paste0(nota, ". completitud no se resume para el total (distinta por sexo)")]
long[!is.na(def_registradas) & causa == "todas", nota := paste0(nota, ". def_registradas: fase 2, grupos 80-84 y 85+ sumados en 80+, sin edad desconocida")]

arch <- c(todas = "code/42_mortality_components_adjusted.R; code/50_dept_mortality_adjusted.R",
          natural = "code/42_mortality_components_adjusted.R; code/50_dept_mortality_adjusted.R",
          otras_externas = "code/42_mortality_components_adjusted.R; code/50_dept_mortality_adjusted.R",
          violenta = "code/42_mortality_components_adjusted.R (+ code/27, code/51 MSE; code/30 para def_registradas)",
          crisis = "code/42_mortality_components_adjusted.R (+ code/47_crisis_deaths.R)")
long[, archivo := fifelse(nivel == "nacional", sub("; code/50_dept_mortality_adjusted.R", "", arch[causa], fixed = TRUE),
                          sub("code/42_mortality_components_adjusted.R; ", "", arch[causa], fixed = TRUE))]
long[nivel == "nacional", archivo := paste0(archivo, " -> output/tables/mortality_adjusted_components_1950-2023.csv")]
long[nivel == "departamental", archivo := paste0(archivo, " -> output/tables/dept_mortality_adjusted_components_1985-2023.csv")]

# final table -------------------------------------------------------------------
setnames(long, c("anio", "pop", "tasa", "def", "reg_proy", "completitud", "completitud_modelo"),
         c("anio", "poblacion", "tasa_ajustada", "def_ajustadas", "def_registradas_proyecto", "completitud", "completitud_modelo"))
cause_ord <- c("todas", "natural", "otras_externas", "violenta", "crisis")
long[, `:=`(causa = factor(causa, cause_ord), sexo = factor(sexo, c("total", "hombres", "mujeres")))]
setorder(long, nivel, cod, anio, causa, sexo, edad_inicio)
long[, `:=`(causa = as.character(causa), sexo = as.character(sexo))]
final <- long[, .(nivel, cod, unidad, anio, causa, sexo, edad, edad_inicio, edad_fin,
                  poblacion = round(poblacion), tasa_ajustada = signif(tasa_ajustada, 10), def_ajustadas = signif(def_ajustadas, 10),
                  def_registradas, def_registradas_proyecto = signif(def_registradas_proyecto, 10), fuente_registradas,
                  completitud = signif(completitud, 8), completitud_modelo = signif(completitud_modelo, 8),
                  incluye_mse, incluye_crisis, anio_registro_colapsado, escenario, metodo, fuente_id, archivo, calidad, nota)]
stopifnot(!anyNA(final$def_ajustadas), !anyNA(final$calidad), !anyNA(final$poblacion))
f_out <- file.path(out_dir, "mortalidad_colombia_ajustada.csv.gz")
fwrite(final, f_out, compress = "gzip", bom = FALSE)
cat(sprintf("%s: %s rows, %.2f MB\n", f_out, format(nrow(final), big.mark = ","), file.size(f_out) / 1e6))

# units table
un <- final[, .(anios = paste(range(anio), collapse = "-")), by = .(nivel, cod, unidad)]
un[, cod_fase1 := fifelse(cod == "9X", paste(amazon, collapse = ";"), cod)]
un[, convencion := fcase(nivel == "nacional", "nacional", cod == "9X", "grupo Amazonía (5 departamentos de 1991 agrupados; sin cod DIVIPOLA propio, como las tablas de vida de DANE)",
                         default = "departamento de la Constitución de 1991 más Bogotá D.C.")]
fwrite(un, file.path(out_dir, "unidades_ajustada.csv"), bom = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# verification ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ver <- list()
add <- function(check, n, n_failing, note = "") ver[[length(ver) + 1]] <<- data.table(check = check, n = n, n_failing = n_failing, note = note)
f3 <- function(x) formatC(x, digits = 3, format = "g")
det <- list()

# 1 unique key
add("1 clave única (nivel,cod,anio,causa,sexo,edad)", nrow(final), nrow(final) - uniqueN(final, by = c("nivel", "cod", "anio", "causa", "sexo", "edad")))
add("1b clave única incluye escenario", nrow(final), nrow(final) - uniqueN(final, by = c("nivel", "cod", "anio", "causa", "sexo", "edad", "escenario")))

# 2 todas = sum of the four components
w <- dcast(final, nivel + cod + anio + sexo + edad ~ causa, value.var = "def_ajustadas")
w[, `:=`(suma = natural + otras_externas + violenta + crisis, reldif = abs(todas - (natural + otras_externas + violenta + crisis)) / pmax(todas, 1e-300))]
bad2 <- w[reldif > 1e-6]
add("2 todas = natural + otras_externas + violenta + crisis (tol 1e-6 rel.)", nrow(w), nrow(bad2),
    sprintf("max dif. relativa %s; fallan: %s", f3(max(w$reldif)), if (nrow(bad2)) paste(head(unique(paste(bad2$nivel, bad2$edad)), 8), collapse = ", ") else "ninguna"))
if (nrow(bad2)) det[["2"]] <- bad2[, .(check = "2", nivel, cod, anio, sexo, edad, valor = reldif)]
# the same check by sex: total = men + women, and rate = deaths / population
tw <- dcast(final[causa == "todas"], nivel + cod + anio + edad ~ sexo, value.var = "def_ajustadas")
add("2b total = hombres + mujeres (def_ajustadas, todas)", nrow(tw), sum(abs(tw$total - tw$hombres - tw$mujeres) > 1e-6 * tw$total))
add("2c tasa_ajustada = def_ajustadas / poblacion", nrow(final), final[, sum(abs(tasa_ajustada * poblacion - def_ajustadas) > 1e-6 * pmax(def_ajustadas, 1e-12) + 1e-9)])

# 3 e0 from tasa_ajustada (todas) with the abridged life table of 42 / 50 (same function)
lifetable_e0 <- function(age, mx, sex) {
  n <- c(diff(age), Inf)
  m0 <- mx[1]
  a0 <- if (sex == "m") { if (m0 < 0.023) 0.14929 - 1.99545 * m0 else if (m0 < 0.08307) 0.02832 + 3.26201 * m0 else 0.29915 } else
                        { if (m0 < 0.01724) 0.14903 - 2.05527 * m0 else if (m0 < 0.06891) 0.04667 + 3.88089 * m0 else 0.31411 }
  a1 <- if (sex == "m") { if (m0 < 0.023) 1.6534 else if (m0 < 0.08307) 1.5806 else 1.3607 } else
                        { if (m0 < 0.01724) 1.6338 else if (m0 < 0.06891) 1.5265 else 1.3062 }
  ax <- c(a0, a1, rep(2.5, length(age) - 3), 1 / mx[length(age)])
  qx <- n * mx / (1 + (n - ax) * mx); qx[length(age)] <- 1
  lx <- c(1, cumprod(1 - qx))[seq_along(age)]
  dx <- lx * qx
  Lx <- n * (lx - dx) + ax * dx; Lx[length(age)] <- lx[length(age)] / mx[length(age)]
  Tx <- rev(cumsum(rev(Lx)))
  Tx[1] / lx[1]
}
e0_ours <- final[causa == "todas" & sexo != "total"][order(nivel, cod, anio, sexo, edad_inicio),
                  .(e0_ours = lifetable_e0(edad_inicio, tasa_ajustada, if (sexo[1] == "hombres") "m" else "f")), by = .(nivel, cod, anio, sexo)]
e0_ref <- rbind(sum_nat[, .(nivel = "nacional", cod = "00", anio = year, sexo = sex_lab[sex], e0_ref = e0)],
                sum_dep[, .(nivel = "departamental", cod, anio = year, sexo = sex_lab[sex], e0_ref = e0)])
e0c <- merge(e0_ours, e0_ref, by = c("nivel", "cod", "anio", "sexo"), all = TRUE)
e0c[, dif := e0_ours - e0_ref]
add("3 e0 recalculada de tasa_ajustada (tabla abreviada de 42) = e0 de los resúmenes (tol 0.05 años)", nrow(e0c), sum(is.na(e0c$dif) | abs(e0c$dif) > 0.05),
    sprintf("dif. máxima absoluta nacional %s, departamental %s años", f3(max(abs(e0c[nivel == "nacional", dif]))), f3(max(abs(e0c[nivel == "departamental", dif])))))
det[["3"]] <- e0c[abs(dif) > 0.05 | is.na(dif), .(check = "3", nivel, cod, anio, sexo, edad = NA_character_, valor = dif)]

# 4 adjusted >= registered, causa todas, by cell
c4 <- final[causa == "todas" & !is.na(def_registradas), .(nivel, cod, anio, sexo, edad, def_ajustadas, def_registradas, def_registradas_proyecto)]
c4[, `:=`(falla = def_ajustadas < def_registradas - 1e-9, falla_proy = def_ajustadas < def_registradas_proyecto - 1e-9)]
add("4 def_ajustadas >= def_registradas (fase 2), todas, por celda", nrow(c4), sum(c4$falla),
    sprintf("fallan por nivel: %s", paste(c4[falla == TRUE, .N, by = nivel][, paste0(nivel, " ", N)], collapse = "; ")))
add("4b def_ajustadas >= def_registradas_proyecto (registradas del proyecto, edad desconocida repartida), todas", sum(!is.na(c4$def_registradas_proyecto)), sum(c4$falla_proy, na.rm = TRUE),
    sprintf("fallan por nivel: %s", paste(c4[falla_proy == TRUE, .N, by = nivel][, paste0(nivel, " ", N)], collapse = "; ")))
f4 <- c4[, .(celdas = .N, fallan_fase2 = sum(falla), fallan_proyecto = sum(falla_proy, na.rm = TRUE),
             max_exceso_reg_rel = max(pmax(def_registradas - def_ajustadas, 0) / pmax(def_registradas, 1))), by = .(nivel, anio)][fallan_fase2 > 0 | fallan_proyecto > 0]
fwrite(f4[order(nivel, anio)], file.path(out_dir, "verification_ajustada_def_menor_registradas.csv"), bom = FALSE)
if (nrow(f4)) {
  s4 <- f4[, .(anios = paste(range(anio), collapse = "-"), n_anios = .N, celdas = sum(fallan_fase2), celdas_proy = sum(fallan_proyecto)), by = nivel]
  add("4c años con fallas (detalle en verification_ajustada_def_menor_registradas.csv)", nrow(f4), nrow(f4), paste(s4[, paste0(nivel, ": ", n_anios, " años (", anios, "), ", celdas, " celdas fase 2, ", celdas_proy, " celdas proyecto")], collapse = " | "))
}

# 5 departments vs national, by year, sex and age group
dn <- merge(final[nivel == "departamental", .(dep = sum(def_ajustadas)), by = .(anio, causa, sexo, edad, edad_inicio)],
            final[nivel == "nacional" & anio >= 1985, .(nac = def_ajustadas, anio, causa, sexo, edad, edad_inicio)], by = c("anio", "causa", "sexo", "edad", "edad_inicio"))
dn[, rel := dep / nac - 1]
add("5 suma de departamentos vs nacional, def_ajustadas por año x sexo x edad x causa", nrow(dn), sum(abs(dn$rel[!is.na(dn$rel)]) > 0.05),
    sprintf("dif. relativa dep/nac-1: mediana %s, p5 %s, p95 %s, min %s, max %s (n_failing = celdas con |dif| > 5%%); solo todas: mediana %s, rango %s a %s",
            f3(median(dn$rel, na.rm = TRUE)), f3(quantile(dn$rel, .05, na.rm = TRUE)), f3(quantile(dn$rel, .95, na.rm = TRUE)), f3(min(dn$rel, na.rm = TRUE)), f3(max(dn$rel, na.rm = TRUE)),
            f3(median(dn[causa == "todas", rel], na.rm = TRUE)), f3(min(dn[causa == "todas", rel], na.rm = TRUE)), f3(max(dn[causa == "todas", rel], na.rm = TRUE))))
fwrite(dn[, .(anio, causa, sexo, edad, dep, nac, rel)][order(causa, sexo, anio, edad)], file.path(out_dir, "verification_ajustada_dep_vs_nacional.csv"), bom = FALSE)
# against the script's own comparison (year x sex, all ages)
cm <- dn[causa == "todas" & sexo != "total", .(dep = sum(dep), nac = sum(nac)), by = .(anio, sexo)][, ratio := dep / nac]
cm <- merge(cm, cmp_script[, .(anio = year, sexo = sex_lab[sex], ratio_script = ratio_total, ratio_pop, dep_total_script = dep_total, nat_total_script = nat_total)], by = c("anio", "sexo"))
add("5b razón dep/nac (año x sexo, todas las edades) = ratio_total de dept_vs_national_adjusted_deaths.csv", nrow(cm), sum(abs(cm$ratio - cm$ratio_script) > 1e-9),
    sprintf("dif. máxima %s; razón de muertes %s a %s; razón de población DANE/WPP %s a %s (la diferencia entre ambas es sobre todo población, no ajuste)",
            f3(max(abs(cm$ratio - cm$ratio_script))), f3(min(cm$ratio)), f3(max(cm$ratio)), f3(min(cm$ratio_pop)), f3(max(cm$ratio_pop))))
# the same with deaths per unit of population (rates), to take the population denominator out
rt <- merge(final[nivel == "departamental" & causa == "todas", .(dep_pop = sum(poblacion)), by = .(anio, sexo, edad)],
            final[nivel == "nacional" & anio >= 1985 & causa == "todas", .(anio, sexo, edad, nac_pop = poblacion)], by = c("anio", "sexo", "edad"))
rt <- merge(dn[causa == "todas"], rt, by = c("anio", "sexo", "edad"))
rt[, rel_tasa := (dep / dep_pop) / (nac / nac_pop) - 1]
add("5c suma de departamentos vs nacional en TASA (def/poblacion), todas, por año x sexo x edad", nrow(rt), sum(abs(rt$rel_tasa) > 0.05),
    sprintf("dif. relativa de tasas: mediana %s, min %s, max %s", f3(median(rt$rel_tasa)), f3(min(rt$rel_tasa)), f3(max(rt$rel_tasa))))

# 6 adjusted / registered by year (national, todas, total)
r6 <- final[nivel == "nacional" & causa == "todas" & sexo == "total", .(adj = sum(def_ajustadas), reg2 = sum(def_registradas), n_reg2 = sum(!is.na(def_registradas)),
                                                                          regp = sum(def_registradas_proyecto)), by = anio]
r6[n_reg2 < 18, reg2 := NA_real_]
r6[, `:=`(razon_fase2 = adj / reg2, razon_proyecto = adj / regp)]
c_inv <- nat[age >= 5, .(inv_c = mean(1 / completeness_natural)), by = .(anio = year)]
r6 <- merge(r6, c_inv, by = "anio")
r6[, decada := decade(anio)]
fwrite(r6[, .(anio, def_ajustadas = adj, def_registradas_fase2 = reg2, def_registradas_proyecto = regp, razon_fase2, razon_proyecto, inverso_completitud_media_5mas = inv_c)],
       file.path(out_dir, "verification_ajustada_razon_anual.csv"), bom = FALSE)
r6d <- r6[, .(n = .N, min2 = min(razon_fase2, na.rm = TRUE), max2 = max(razon_fase2, na.rm = TRUE), med2 = median(razon_fase2, na.rm = TRUE),
              minp = min(razon_proyecto), maxp = max(razon_proyecto), medp = median(razon_proyecto), medc = median(inv_c),
              bajo1 = sum(razon_fase2 < 1, na.rm = TRUE)), by = decada]
for (i in seq_len(nrow(r6d))) with(r6d[i], add(paste("6 razón def_ajustadas / def_registradas nacional, todas, total,", decada), n, bajo1,
    sprintf("fase 2: min %s, max %s, mediana %s; registradas del proyecto: min %s, max %s, mediana %s; mediana 1/completitud natural (5+, ambos sexos) %s; n_failing = años con razón < 1",
            f3(min2), f3(max2), f3(med2), f3(minp), f3(maxp), f3(medp), f3(medc))))
add("6b correlación año a año razón (fase 2) vs 1/completitud natural media", nrow(r6[!is.na(razon_fase2)]), 0,
    sprintf("cor = %s; cor con razón del proyecto = %s", f3(r6[, cor(razon_fase2, inv_c, use = "complete.obs")]), f3(r6[, cor(razon_proyecto, inv_c)])))

# 7 coverage
cov7 <- final[, .(filas = .N, anio_min = min(anio), anio_max = max(anio), n_anios = uniqueN(anio), n_unidades = uniqueN(cod),
                  con_def_registradas = sum(!is.na(def_registradas)), sin_def_registradas = sum(is.na(def_registradas))), by = .(nivel, causa, decada = decade(anio))]
fwrite(cov7[order(nivel, causa, decada)], file.path(out_dir, "verification_ajustada_cobertura.csv"), bom = FALSE)
exp_dec <- function(lvl) { y <- if (lvl == "nacional") 1950:2023 else 1985:2023; table(decade(y)) }
cov_ok <- all(sapply(c("nacional", "departamental"), function(l) {
  ex <- exp_dec(l)
  all(vapply(cause_ord, function(cz) { s <- cov7[nivel == l & causa == cz]; setequal(s$decada, names(ex)) && all(s$n_anios[match(names(ex), s$decada)] == as.integer(ex)) }, TRUE)) }))
add("7 cobertura nivel x causa x década (nacional 1950-2023, departamental 1985-2023; detalle en verification_ajustada_cobertura.csv)", nrow(cov7), !cov_ok,
    sprintf("filas por celda esperadas: nacional 18 edades x 3 sexos; departamental 29 unidades x 18 x 3. Municipal: no disponible. n_failing = 1 si falta algún año"))
add("7b filas por nivel", nrow(final), 0, paste(final[, .N, by = nivel][, paste0(nivel, " ", N)], collapse = "; "))

# 8 national violenta vs deaths_by_cause violent
v8 <- merge(final[nivel == "nacional" & causa == "violenta" & sexo == "total", .(violenta = sum(def_ajustadas), vr_proy = sum(def_registradas, na.rm = TRUE)), by = anio],
            final[nivel == "nacional" & causa == "crisis" & sexo == "total", .(crisis = sum(def_ajustadas)), by = anio], by = "anio")
v8 <- merge(v8, cause[, .(viol_adj30 = sum(violent_adj), viol_reg30 = sum(violent_reg), q30 = quality[1]), by = .(anio = year)], by = "anio", all.x = TRUE)
v8 <- merge(v8, comp_reg[, .(viol_reg40 = sum(violent)), by = .(anio = year)], by = "anio", all.x = TRUE)
v8[, `:=`(rel_mse = violenta / viol_adj30 - 1, rel_reg_viol = violenta / viol_reg30 - 1, rel_reg40 = violenta / viol_reg40 - 1, rel_mas_crisis = (violenta + crisis) / viol_adj30 - 1)]
fwrite(v8, file.path(out_dir, "verification_ajustada_violenta_vs_causas.csv"), bom = FALSE)
m8 <- v8[anio %in% mse_years]
add("8a violenta (42) vs violent_adj de deaths_by_cause (30), años MSE 1985-2018", nrow(m8), sum(abs(m8$rel_mse) > 1e-6),
    sprintf("dif. relativa min %s, max %s", f3(min(m8$rel_mse)), f3(max(m8$rel_mse))))
o8 <- v8[!anio %in% mse_years & anio >= 1953]
add("8b violenta (42, registradas sin escalar) vs violent_reg de deaths_by_cause, años sin MSE 1953-1984 y 2019-2023", nrow(o8), sum(abs(o8$rel_reg_viol) > 0.001),
    sprintf("dif. relativa min %s, max %s (1970-1971 interpoladas en 30)", f3(min(o8$rel_reg_viol)), f3(max(o8$rel_reg_viol))))
add("8c violenta + crisis vs violent_adj de 30 (años sin MSE 1953-1984), donde 30 escala por completitud", nrow(o8[anio <= 1984]), sum(abs(o8[anio <= 1984]$rel_mas_crisis) > 0.05),
    sprintf("dif. relativa min %s, max %s; n_failing = años con |dif| > 5%%. 30 reescala todas las violentas con el factor todas-las-causas (1 a 2); 42 las deja registradas y añade pisos externos (crisis)",
            f3(min(o8[anio <= 1984]$rel_mas_crisis)), f3(max(o8[anio <= 1984]$rel_mas_crisis))))
add("8d violenta (42) vs violent_reg40 (script 40, registradas), todos los años sin MSE", nrow(v8[!anio %in% mse_years]), sum(abs(v8[!anio %in% mse_years]$rel_reg40) > 1e-6, na.rm = TRUE),
    sprintf("dif. relativa min %s, max %s", f3(min(v8[!anio %in% mse_years]$rel_reg40, na.rm = TRUE)), f3(max(v8[!anio %in% mse_years]$rel_reg40, na.rm = TRUE))))

# 9 MSE departments sum to the national MSE added in the violent component
mse_nat <- final[nivel == "nacional" & causa == "violenta" & anio %in% mse_years & sexo != "total", .(nac = sum(def_ajustadas)), by = .(anio, sexo)]
m9 <- merge(final[nivel == "departamental" & causa == "violenta" & anio %in% mse_years & sexo != "total", .(dep = sum(def_ajustadas)), by = .(anio, sexo)], mse_nat, by = c("anio", "sexo"))
m9[, rel := dep / nac - 1]
m8e <- v8[anio %in% mse_years & !is.na(viol_reg40)]
add("8e violentas registradas del script 40 (base de 42) vs violent_reg del script 30, años MSE", nrow(m8e), sum(abs(m8e$viol_reg40 / m8e$viol_reg30 - 1) > 0.001),
    sprintf("dif. relativa min %s, max %s: 30 usa EEVV con edad conocida (dx_v), 40 reparte la edad desconocida y aplica participaciones por causa a las registradas de 22; explica la diferencia de 8a",
            f3(min(m8e$viol_reg40 / m8e$viol_reg30 - 1)), f3(max(m8e$viol_reg40 / m8e$viol_reg30 - 1))))

add("9 violenta departamental (suma) vs nacional, años MSE, por año x sexo", nrow(m9), sum(abs(m9$rel) > 0.05),
    sprintf("dif. relativa min %s, max %s (población y registradas DANE vs WPP; 51 calibra el déficit MSE al nacional)", f3(min(m9$rel)), f3(max(m9$rel))))
add("9b déficit MSE departamental (51) suma al nacional", nrow(mse_dep), 0, sprintf("suma mse_added 1985-2018 = %s muertes", format(round(sum(mse_dep$mse_added)), big.mark = ",")))

ver <- rbindlist(ver)
fwrite(ver, file.path(out_dir, "verification_ajustada.csv"), bom = FALSE)
if (length(det)) fwrite(rbindlist(det, fill = TRUE), file.path(out_dir, "verification_ajustada_detalle.csv"), bom = FALSE)
options(width = 250, datatable.print.nrows = 100)
print(ver[, .(check, n, n_failing)], row.names = FALSE)
for (i in seq_len(nrow(ver))) cat(sprintf("[%s] %s\n", ver$check[i], ver$note[i]))
cat("\nwritten:", f_out, "\n")
