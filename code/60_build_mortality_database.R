# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 60. Colombia mortality database, phase 1: REGISTERED deaths 1915-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Builds one tidy long table of registered deaths (all causes and homicide;
# total, men, women; national, departmental, municipal) from the extracted
# CSV / RDS files already in the project (no PDF extraction here), plus the
# table with every source unharmonised, a population-denominator table, a
# unit crosswalk, a verification table and the data dictionary.
# Nothing is adjusted or imputed here; a source's own imputation is flagged
# in `calidad`.
#
# Run from the project root:  Rscript code/60_build_mortality_database.R
#
# input : data_inter/deaths_munic_1979-2023.rds                     (EEVV)
#         output/deaths_pop_munic_1985_2023.csv.gz                  (municipal pop)
#         data_input/historical/dane_defunciones_1970_1978_cuadro0{1,2}_*.csv
#         data_input/historical/dane_defunciones_196{5_1967,8_1969}_secciones_sexo_edad.csv
#         data_input/historical/dane_vitales_1958_1960_{departamental,municipal}.csv
#         data_input/historical/col_gap_analysis_1920_1985_*  (deaths, homicides, population)
#         data_input/historical/lambda_Col_Deaths{m,f}.txt
#         data_input/historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx
#         data_input/reference/who/*.csv, DIVIPOLA, DANE projections
#         output/tables/data_availability_information.csv           (check 6)
# output: output/mortalidad_colombia/
#           mortalidad_colombia.csv.gz          best source per cell
#           mortalidad_colombia_fuentes.csv.gz  every source, unharmonised, `elegida`
#           poblacion_colombia.csv.gz           denominators
#           unidades_colombia.csv               unit crosswalk
#           verification.csv (+ verificacion_nacional_vs_departamentos.csv)
#           diccionario.md
#
# Selection: per (nivel, unit, year, cause) ONE source is chosen for the whole
# group of sexes (total, men, women); order EEVV > Registro de defunciones
# 1970-1978 > Estadística vital 1958-60 / anuarios 1965-69 > col_gap anuarios >
# OMS > LAMBdA > Policía > (sum of col_gap departmental homicides). The EEVV
# year 1979 (short year) is demoted below any other source. If the winner has
# only a total and a lower source has sexes with the SAME total, that source
# is used instead (same published figure, so total = men + women holds).
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(tidyverse); library(readxl); library(stringi)})
options(width = 200)
od <- "output/mortalidad_colombia"
dir.create(od, showWarnings = FALSE, recursive = TRUE)
H <- "data_input/historical/"
R <- "data_input/reference/"
G <- function(f) paste0(H, "col_gap_analysis_1920_1985_", f)
stopifnot(file.exists("code/60_build_mortality_database.R") || file.exists("data_input"))

# ---------------------------------------------------------------------------
# helpers ====
# ---------------------------------------------------------------------------
read_any <- function(f, delim = ",", ...) {   # utf-8 or latin1
  x <- readBin(f, "raw", file.size(f))
  enc <- if (stri_enc_isutf8(x)) "UTF-8" else "latin1"
  read_delim(f, delim = delim, locale = locale(encoding = enc), show_col_types = FALSE,
             guess_max = 1e5, name_repair = "minimal", ...)
}
norm <- function(x) x |> stri_trans_general("Latin-ASCII") |> tolower() |>
  str_replace_all("[^a-z0-9]+", " ") |> str_squish()
cod5 <- function(x) ifelse(is.na(x), NA_character_, sprintf("%05d", as.integer(x)))

# departments, 1991 constitution plus Bogotá; TN = pooled intendencias and comisarías
dep <- tribble(
  ~cod, ~unidad,
  "05", "Antioquia", "08", "Atlántico", "11", "Bogotá D.C.", "13", "Bolívar", "15", "Boyacá",
  "17", "Caldas", "18", "Caquetá", "19", "Cauca", "20", "Cesar", "23", "Córdoba",
  "25", "Cundinamarca", "27", "Chocó", "41", "Huila", "44", "La Guajira", "47", "Magdalena",
  "50", "Meta", "52", "Nariño", "54", "Norte de Santander", "63", "Quindío", "66", "Risaralda",
  "68", "Santander", "70", "Sucre", "73", "Tolima", "76", "Valle del Cauca", "81", "Arauca",
  "85", "Casanare", "86", "Putumayo", "88", "San Andrés y Providencia", "91", "Amazonas",
  "94", "Guainía", "95", "Guaviare", "97", "Vaupés", "99", "Vichada",
  "TN", "Intendencias y comisarías (agrupadas)",
  "TN_I", "Intendencias (agrupadas, sin comisarías)", "TN_C", "Comisarías (agrupadas, sin intendencias)")
alias <- c(dep$unidad, "bogota", "bogota d e", "bogota d c", "bogota distrito especial", "guajira", "san andres",
           "archipielago de san andres", "archipielago de san andres providencia y santa catalina",
           "valle", "norte de santander", "cundinamarca sin bogota", "intendencias y comisarias",
           "intendencias", "comisarias", "quindio", "narino", "boyaca", "choco", "cordoba", "atlantico",
           "bolivar", "caqueta", "guainia", "vaupes", "total nacional")
alias_cod <- c(dep$cod, "11", "11", "11", "11", "44", "88", "88", "88", "76", "54", "25", "TN", "TN_I", "TN_C",
               "63", "52", "15", "27", "23", "08", "13", "18", "94", "97", "00")
dep_key <- tibble(k = norm(alias), cod = alias_cod) |> distinct(k, .keep_all = TRUE)
dep_cod <- function(x) {
  k <- norm(x); k <- str_replace(k, "^(intendencias|comisarias) y (intendencias|comisarias)$", "intendencias y comisarias")
  dep_key$cod[match(k, dep_key$k)]
}
dep_name <- function(cod) unname(c(setNames(dep$unidad, dep$cod), "00" = "Colombia")[cod])

# DIVIPOLA
dv <- read_csv(paste0(R, "DIVIPOLA-_Códigos_municipios_20260307.csv"), show_col_types = FALSE) |>
  transmute(cod = `Código Municipio`, dcod = `Código Departamento`, nombre = str_to_title(`Nombre Municipio`),
            nombre_up = `Nombre Municipio`)
dv_key <- dv |> mutate(k = paste(dcod, norm(nombre_up))) |> filter(!duplicated(k) & !duplicated(k, fromLast = TRUE))
muni_cod <- function(dane_code, department, municipality) {   # given code, else unambiguous name match
  dc <- dep_cod(str_replace_all(department, "_", " "))
  m <- dv_key$cod[match(paste(dc, norm(municipality)), dv_key$k)]
  ifelse(!is.na(dane_code), cod5(dane_code), m)
}
muni_name <- function(cod, fallback) {
  n <- dv$nombre[match(cod, dv$cod)]
  ifelse(is.na(n), fallback, n)
}

# historical territorial note by department code and year
hist_nota <- function(cod, anio) {
  case_when(
    cod == "17" & anio <= 1966 ~ "Caldas incluye Quindío y Risaralda (creados en 1966-67)",
    cod == "13" & anio <= 1951 ~ "Bolívar incluye Córdoba y Sucre",
    cod == "13" & anio <= 1966 ~ "Bolívar incluye Sucre (Córdoba existe desde 1952)",
    cod == "47" & anio <= 1963 ~ "Magdalena incluye La Guajira y Cesar",
    cod == "47" & anio <= 1967 ~ "Magdalena incluye Cesar (departamento desde 1967)",
    cod == "25" & anio <= 1961 ~ "Cundinamarca incluye Bogotá (en los anuarios Bogotá aparece también aparte 1956-1961: sumar ambas duplica)",
    cod == "44" & anio <= 1963 ~ "La Guajira era intendencia",
    cod == "50" & anio <= 1958 ~ "Meta era intendencia/comisaría",
    cod == "18" & anio <= 1981 ~ "Caquetá era intendencia/comisaría",
    cod == "27" & anio <= 1947 ~ "Chocó era intendencia",
    cod %in% c("81", "85", "86", "88", "91", "94", "95", "97", "99") & anio <= 1990 ~ "intendencia o comisaría en ese año",
    TRUE ~ NA_character_)
}
hist_dep_note <- tibble(cod = dep$cod) |> rowwise() |>
  mutate(nota = paste(na.omit(unique(hist_nota(cod, 1915:1990))), collapse = "; ")) |> ungroup()

sexo_lab <- c(total = "total", hombres = "hombres", mujeres = "mujeres")

# one source -> long rows. df: nivel, cod, unidad, anio, total/hombres/mujeres (+ optional columns)
as_long <- function(df, causa, src, rank, fuente_id, archivo, demote = FALSE) {
  for (v in c("hombres", "mujeres")) if (!v %in% names(df)) df[[v]] <- NA_real_
  df <- df |> mutate(causa = causa, src = src, rank = rank, fuente_id = fuente_id, archivo = archivo,
                     demote = if (is.function(demote)) demote(anio) else demote)
  if (!"calidad" %in% names(df)) df$calidad <- "observada"
  if (!"cobertura" %in% names(df)) df$cobertura <- "completa"
  if (!"nota" %in% names(df)) df$nota <- NA_character_
  if (!"nombre_fuente" %in% names(df)) df$nombre_fuente <- df$unidad
  if (!"bloqueada" %in% names(df)) df$bloqueada <- FALSE
  df |>
    pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "def_registradas") |>
    filter(!is.na(def_registradas)) |>
    mutate(edad = "total", def_registradas = as.numeric(def_registradas))
}
cat_note <- function(...) {
  x <- list(...); x <- lapply(x, \(v) ifelse(is.na(v) | v == "", NA_character_, v))
  r <- do.call(paste, c(lapply(x, \(v) replace_na(v, "")), sep = "|"))
  r <- str_replace_all(r, "\\|+", "; ") |> str_remove("^; ") |> str_remove("; $")
  ifelse(r == "", NA_character_, r)
}

# ---------------------------------------------------------------------------
# sources ====
# ---------------------------------------------------------------------------
S <- list()

## 1. EEVV microdata aggregates, 1979-2023 (place of occurrence) -------------
cat("EEVV...\n")
ev <- readRDS("data_inter/deaths_munic_1979-2023.rds") |> as_tibble() |>
  mutate(cod = sprintf("%02d%03d", cod_dpto, cod_munic), dcod = sprintf("%02d", cod_dpto))
f_ev <- "data_inter/deaths_munic_1979-2023.rds"
agg_ev <- function(d, by) {
  bind_rows(
    d |> summarise(total = sum(dx_tot), hombres = sum(dx_tot[sex %in% "m"]), mujeres = sum(dx_tot[sex %in% "f"]),
                   sin_sexo = sum(dx_tot[is.na(sex)]), causa = "todas", .by = all_of(by)),
    d |> summarise(total = sum(dx_h), hombres = sum(dx_h[sex %in% "m"]), mujeres = sum(dx_h[sex %in% "f"]),
                   sin_sexo = sum(dx_h[is.na(sex)]), causa = "homicidio", .by = all_of(by)))
}
nota_ev <- \(anio, sin_sexo) cat_note(
  ifelse(anio == 1979, "1979 es un año corto en las EEVV; no comparable con los demás años", NA),
  ifelse(sin_sexo > 0, paste0("incluye ", sin_sexo, " defunciones de sexo no registrado"), NA),
  "lugar de ocurrencia")
ev_nat <- agg_ev(ev |> rename(anio = year), "anio") |> mutate(nivel = "nacional", cod = "00", unidad = "Colombia")
ev_dep <- agg_ev(ev |> rename(anio = year), c("anio", "dcod")) |> mutate(nivel = "departamental", cod = dcod, unidad = coalesce(dep_name(dcod), paste0("Código de departamento ", dcod, " (no existe en DIVIPOLA)")))
ev_mun <- agg_ev(ev |> rename(anio = year), c("anio", "cod")) |> mutate(nivel = "municipal", dcod = substr(cod, 1, 2))
ev_mun$unidad <- muni_name(ev_mun$cod, paste0("Código ", ev_mun$cod, " no está en DIVIPOLA 2026"))
ev_all <- bind_rows(ev_nat, ev_dep, ev_mun) |>
  mutate(nota = nota_ev(anio, sin_sexo),
         cobertura = if_else(anio == 1979 | sin_sexo > 0 & FALSE, "parcial", "completa"),
         nombre_fuente = if_else(nivel == "municipal", cod, unidad), bloqueada = FALSE)
for (cz in c("todas", "homicidio"))
  S[[paste0("eevv_", cz)]] <- as_long(ev_all |> filter(causa == cz), cz, "eevv", 1, "dane_eevv", f_ev,
                                      demote = \(a) a == 1979 & !(cz == "homicidio"))
# demotion rule: 1979 (short year) never wins at national / departmental level for "todas",
# nor at national level for "homicidio"; departmental homicide 1979 has only the Policía as alternative
S$eevv_homicidio <- S$eevv_homicidio |> mutate(demote = anio == 1979 & nivel != "departamental")

## 2. Registro de defunciones 1970-1978 ---------------------------------------
cat("Registro...\n")
f_c1 <- paste0(H, "dane_defunciones_1970_1978_cuadro01_nacional_1915_1984.csv")
f_c2 <- paste0(H, "dane_defunciones_1970_1978_cuadro02_secciones_sexo_1970_1984.csv")
c1 <- read_csv(f_c1, show_col_types = FALSE)
S$reg_c1 <- as_long(tibble(nivel = "nacional", cod = "00", unidad = "Colombia", anio = c1$year, total = c1$deaths,
                           nota = "Registro de defunciones 1970-1978, cuadro 1 (total nacional 1915-1984)"),
                    "todas", "reg_c1", 2.1, "dane_registro_def_1970_1978", f_c1)
c2 <- read_csv(f_c2, show_col_types = FALSE, col_types = cols(.default = "c")) |>
  mutate(across(c(year, total, male, female), as.numeric),
         cod = case_when(unit == "Total nacional" ~ "00", unit == "Intendencias y comisarías" ~ "TN", TRUE ~ cod_dpto),
         nivel = if_else(cod == "00", "nacional", "departamental"))
c2d <- c2 |> transmute(nivel, cod, unidad = if_else(cod == "00", "Colombia", dep_name(cod)), anio = year,
                       total, hombres = male, mujeres = female, nombre_fuente = unit,
                       cobertura = if_else(!is.na(mark), "parcial", "completa"),
                       nota = cat_note(mark_note, note, if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA),
                                       hist_nota(cod, year)))
S$reg_c2 <- as_long(c2d, "todas", "reg_c2", 2.0, "dane_registro_def_1970_1978", f_c2)

## 3. Estadística vital 1958-1960, anuarios 1965-1969 -------------------------
cat("Vitales 1958-60 / 1965-69...\n")
unit_cod <- function(u) ifelse(norm(u) == "total nacional", "00", dep_cod(u))
f_a <- paste0(H, "dane_defunciones_1968_1969_secciones_sexo_edad.csv")
f_b <- paste0(H, "dane_defunciones_1965_1967_secciones_sexo_edad.csv")
for (ff in list(c(f_b, "ane_6567", 3.1), c(f_a, "ane_6869", 3.2))) {
  d <- read_csv(ff[1], show_col_types = FALSE, col_types = cols(.default = "c")) |> filter(age == "all") |>
    mutate(across(c(year, male, female, total), as.numeric), cod = unit_cod(unit),
           nivel = if_else(cod == "00", "nacional", "departamental"))
  stopifnot(!any(is.na(d$cod)))
  S[[ff[2]]] <- as_long(d |> transmute(nivel, cod, unidad = if_else(cod == "00", "Colombia", dep_name(cod)), anio = year,
                                       total, hombres = male, mujeres = female, nombre_fuente = unit,
                                       nota = cat_note(if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA),
                                                       hist_nota(cod, year), "fila 'all' (todas las edades)")),
                        "todas", ff[2], as.numeric(ff[3]), "dane_anuarios", ff[1])
}
f_vd <- paste0(H, "dane_vitales_1958_1960_departamental.csv")
f_vm <- paste0(H, "dane_vitales_1958_1960_municipal.csv")
vd <- read_csv(f_vd, show_col_types = FALSE) |> mutate(cod = unit_cod(unit), nivel = if_else(cod == "00", "nacional", "departamental"))
stopifnot(!any(is.na(vd$cod)))
vd_l <- vd |> transmute(nivel, cod, unidad = if_else(cod == "00", "Colombia", dep_name(cod)), anio = year, total = deaths,
                        nombre_fuente = unit,
                        nota = cat_note(if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA), hist_nota(cod, year)))
S$vit_dep <- as_long(vd_l, "todas", "vit_dep", 3.3, "dane_vitales_1958_1960", f_vd)
vm <- read_csv(f_vm, show_col_types = FALSE, col_types = cols(.default = "c")) |>
  mutate(across(c(year, deaths_m, deaths_f, deaths_t), as.numeric))
vm_l <- vm |> transmute(nivel = "municipal", cod = cod_munic, unidad = muni_name(cod_munic, municipio), anio = year,
                        total = deaths_t, hombres = deaths_m, mujeres = deaths_f, nombre_fuente = paste0(name_in_source, " / ", municipio),
                        nota = cat_note(if_else(!is.na(flag), paste0("OCR: ", str_trunc(flag, 100)), NA),
                                        if_else(!cod_munic %in% dv$cod, "código no vigente en DIVIPOLA 2026", NA)))
S$vit_mun <- as_long(vm_l, "todas", "vit_mun", 3.3, "dane_vitales_1958_1960", f_vm)
# department sums of the municipal table (sex split); used only for units published in the departmental table
vms <- vm |> summarise(total = if (any(is.na(deaths_t))) NA_real_ else sum(deaths_t),
                       hombres = if (any(is.na(deaths_m))) NA_real_ else sum(deaths_m),
                       mujeres = if (any(is.na(deaths_f))) NA_real_ else sum(deaths_f), .by = c(year, cod_dpto)) |>
  transmute(nivel = "departamental", cod = cod_dpto, unidad = dep_name(cod_dpto), anio = year, total, hombres, mujeres,
            nombre_fuente = paste0("suma de municipios, ", cod_dpto),
            bloqueada = !paste(cod, anio) %in% paste(vd$cod, vd$year),
            nota = cat_note("suma de los municipios del cuadro municipal; hombres y mujeres solo aquí",
                            if_else(!paste(cod_dpto, year) %in% paste(vd$cod, vd$year),
                                    "no seleccionable: la unidad se publica agrupada en el cuadro departamental", NA)))
S$vit_dsum <- as_long(vms, "todas", "vit_dsum", 3.4, "dane_vitales_1958_1960", f_vm)

## 4. col_gap anuarios -----------------------------------------------------------
cat("col_gap...\n")
bad_dane <- "ubregistro|deficiente|ncompleta|semestre|trimestre|Datos de|No fue posible|cobertura"
bad_coll <- "copied|estimate|Estimate|No genuine"
# national deaths
f_nd <- G("national_deaths_clean_v03.csv")
nd <- read_delim(f_nd, delim = ";", show_col_types = FALSE, name_repair = "minimal")[, 1:7] |> filter(data_available == 1)
S$gap_nat <- as_long(nd |> transmute(nivel = "nacional", cod = "00", unidad = "Colombia", anio = year, total, hombres = male, mujeres = female),
                     "todas", "gap_nat", 4, "dane_anuarios", f_nd)
# departmental deaths: split file where the unit appears separately, aggregated file for pooled years
f_ag <- G("department_deaths_clean_v06_territories_aggregated.csv")
f_sp <- G("department_deaths_clean_v06_territories_split.csv")
ag <- read_any(f_ag, ";") |> mutate(cod = dep_cod(str_replace_all(department, "_", " ")))
sp <- read_any(f_sp, ";") |> mutate(cod = dep_cod(str_replace_all(department, "_", " ")))
stopifnot(!any(is.na(ag$cod)), !any(is.na(sp$cod)))
pool <- ag |> filter(cod == "TN", data_available == 1, !is.na(total)) |>
  select(anio = year, ptot = total, M = existent_intendencias_and_comisarias_per_year)
pool$members <- lapply(pool$M, \(m) if (is.na(m)) character() else dep_cod(str_split(m, ", ")[[1]]))
split_decomposes <- pool |> rowwise() |> mutate(
  ssum = sum(sp$total[sp$year == anio & sp$cod %in% members & sp$data_available == 1], na.rm = TRUE),
  use_split = ssum > 0 & ssum == ptot) |> ungroup()
mem_long <- split_decomposes |> select(anio, members, use_split) |> unnest(members) |> rename(cod = members)
flag_note <- function(dn, cn) {
  cat_note(ifelse(!is.na(dn), str_trunc(dn, 150), NA), ifelse(!is.na(cn), str_trunc(cn, 150), NA))
}
mk_dep <- function(d, file) {
  d |> filter(data_available == 1) |>
    mutate(par = !is.na(data_flag_dane_note) & str_detect(data_flag_dane_note, bad_dane) | !is.na(data_flag_collaborator_note) & str_detect(data_flag_collaborator_note, "Drop in death|undercount|lower"),
           imp = !is.na(data_flag_collaborator_note) & str_detect(data_flag_collaborator_note, bad_coll)) |>
    transmute(nivel = "departamental", cod, unidad = dep_name(cod), anio = year, total, hombres = male, mujeres = female,
              nombre_fuente = department,
              calidad = if_else(imp, "imputada_por_la_fuente", "observada"),
              cobertura = if_else(par, "parcial", "completa"),
              nota = cat_note(flag_note(data_flag_dane_note, data_flag_collaborator_note),
                              if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA), hist_nota(cod, year)))
}
sp_l <- mk_dep(sp, f_sp) |> left_join(mem_long, by = c("cod", "anio")) |>
  mutate(bloqueada = !is.na(use_split) & !use_split,
         nota = if_else(bloqueada, cat_note(nota, "no seleccionado: el agregado de intendencias y comisarías cubre estas unidades este año"), nota)) |>
  select(-use_split)
ag_l <- mk_dep(ag |> filter(cod == "TN"), f_ag) |> left_join(split_decomposes |> select(anio, use_split), by = "anio") |>
  mutate(bloqueada = !is.na(use_split) & use_split,
         nota = if_else(bloqueada, cat_note(nota, "no seleccionado: las unidades se publican por separado este año (archivo split)"), nota)) |>
  select(-use_split)
S$gap_dep <- as_long(bind_rows(sp_l, ag_l), "todas", "gap_dep", 4, "dane_anuarios", paste0(f_sp, "; ", f_ag))
S$gap_dep <- S$gap_dep |> mutate(archivo = if_else(cod == "TN", f_ag, f_sp))
# municipal deaths
f_md <- G("municipal_deaths_clean_v03.csv")
md <- read_csv(f_md, show_col_types = FALSE, col_types = cols(dane_code = "d", year = "d", total = "d", male = "d", female = "d",
                                                              known_data_problem = "c", .default = "c")) |>
  filter(data_available == "1") |>
  mutate(cod = muni_cod(dane_code, department, municipality))
md_l <- md |> transmute(nivel = "municipal", cod, unidad = coalesce(muni_name(cod, NA_character_), str_to_title(municipality)),
                        anio = year, total, hombres = male, mujeres = female,
                        nombre_fuente = paste0(department, " / ", municipality),
                        calidad = if_else(str_detect(replace_na(known_data_problem, ""), "copied|Identical|filled"), "imputada_por_la_fuente", "observada"),
                        cobertura = if_else(str_detect(replace_na(known_data_problem, ""), "Partial|missing|Did not send|only|copied"), "parcial", "completa"),
                        nota = cat_note(known_data_problem, if_else(is.na(cod), "sin cod: nombre no emparejado de forma única con DIVIPOLA", NA)))
S$gap_mun <- as_long(md_l, "todas", "gap_mun", 4, "dane_anuarios", f_md)
# departmental homicides
f_hm <- G("department_homicides_clean_v02.csv")
hm <- read_csv(f_hm, show_col_types = FALSE) |> filter(data_available == 1) |>
  mutate(cod = dep_cod(department)) |> mutate(cod = if_else(is.na(cod) & norm(department) == "cundinamarca sin bogota", "25", cod))
stopifnot(!any(is.na(hm$cod)))
hm_l <- hm |> transmute(nivel = "departamental", cod, unidad = dep_name(cod), anio = year, total, hombres = male, mujeres = female,
                        nombre_fuente = department,
                        cobertura = if_else(str_detect(replace_na(known_data_problem, ""), "NOT_pure|did not send|missing"), "parcial", "completa"),
                        nota = cat_note(known_data_problem,
                                        if_else(norm(department) == "cundinamarca sin bogota", "Cundinamarca sin Bogotá (Bogotá aparece aparte)", NA),
                                        if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA),
                                        if_else(cod %in% c("TN_I", "TN_C"), "intendencias o comisarías publicadas por separado ese año; no se suman", NA),
                                        hist_nota(cod, year), if_else(year %in% 1943:1945, "concepto distinto: muertes violentas accidentales", NA)))
S$gap_hom <- as_long(hm_l, "homicidio", "gap_hom", 4, "dane_anuarios", f_hm)
# national sum of the departmental homicides: extra source row, partial unless every unit with deaths data is present
units_d <- ag |> filter(data_available == 1) |> mutate(c2 = cod) |> select(anio = year, c2) |> distinct()
hm_nat <- hm |> mutate(c2 = if_else(cod %in% c("TN_I", "TN_C"), "TN", cod), c2 = if_else(cod == "11", "25", c2)) |>
  summarise(total = if (any(is.na(total))) NA_real_ else sum(total),
            hombres = if (any(is.na(male))) NA_real_ else sum(male),
            mujeres = if (any(is.na(female))) NA_real_ else sum(female),
            units = list(unique(c2)), notpure = any(str_detect(replace_na(known_data_problem, ""), "NOT_pure")), n = n(), .by = year)
hm_nat$complete <- map2_lgl(hm_nat$year, hm_nat$units, \(y, u) {
  ud <- units_d$c2[units_d$anio == y]; ud <- ifelse(ud == "11", "25", ud)
  length(ud) > 0 && all(ud %in% u)
})
S$gap_homsum <- as_long(hm_nat |> transmute(nivel = "nacional", cod = "00", unidad = "Colombia", anio = year, total, hombres, mujeres,
                                            nombre_fuente = "suma de unidades",
                                            cobertura = if_else(complete & !notpure, "completa", "parcial"),
                                            nota = cat_note(paste0("suma de ", n, " unidades de col_gap_department_homicides; no es un total publicado"),
                                                            if_else(notpure, "concepto distinto (muertes violentas accidentales)", NA),
                                                            if_else(!complete, "faltan unidades presentes en las defunciones departamentales", NA))),
                        "homicidio", "gap_homsum", 7.5, "dane_anuarios", f_hm)

## 5. WHO, LAMBdA, Policía -------------------------------------------------------
cat("WHO / LAMBdA / Policía...\n")
f_wa <- paste0(R, "who/who_all_cause_colombia.csv"); f_wh <- paste0(R, "who/who_homicide_colombia.csv")
who_l <- function(f, v, causa) {
  d <- read_csv(f, show_col_types = FALSE) |> rename(val = all_of(v)) |>
    pivot_wider(names_from = sex, values_from = val)
  as_long(d |> transmute(nivel = "nacional", cod = "00", unidad = "Colombia", anio = year, hombres = m, mujeres = f,
                         total = if_else(!is.na(m) & !is.na(f), m + f, NA_real_),
                         nota = "total = hombres + mujeres (la OMS publica por sexo)"),
          causa, paste0("who_", causa), 5, "who_mdb", f)
}
S$who_t <- who_l(f_wa, "dts", "todas"); S$who_h <- who_l(f_wh, "hms", "homicidio")
lm <- read_tsv(paste0(H, "lambda_Col_Deathsm.txt"), show_col_types = FALSE) |> summarise(hombres = sum(Deaths), .by = Year)
lf <- read_tsv(paste0(H, "lambda_Col_Deathsf.txt"), show_col_types = FALSE) |> summarise(mujeres = sum(Deaths), .by = Year)
S$lambda <- as_long(inner_join(lm, lf, by = "Year") |>
                      transmute(nivel = "nacional", cod = "00", unidad = "Colombia", anio = Year, hombres, mujeres, total = hombres + mujeres,
                                nota = "suma de todas las edades de LAMBdA; no se verificó si LAMBdA corrige subregistro; total = hombres + mujeres"),
                    "todas", "lambda", 6, "lambda", paste0(H, "lambda_Col_Deaths{m,f}.txt"))
f_po <- paste0(H, "Homicidio 1962-2002 por depto de Policía_v1.xlsx")
po <- read_excel(f_po, sheet = "Tabla_ancha") |> filter(!is.na(Jurisdiccion)) |>
  pivot_longer(-Jurisdiccion, names_to = "anio", values_to = "total") |> mutate(anio = as.integer(anio))
# 0 before the first / after the last non-zero value means no jurisdiction or no report: omitted
po <- po |> arrange(Jurisdiccion, anio) |>
  mutate(nz = cumsum(total > 0), nz_rev = rev(cumsum(rev(total) > 0)), .by = Jurisdiccion) |>
  filter(total > 0 | (nz > 0 & nz_rev > 0))
po_cod <- tibble(Jurisdiccion = unique(po$Jurisdiccion)) |>
  mutate(cod = case_when(Jurisdiccion == "TOTAL" ~ "00",
                         norm(Jurisdiccion) %in% c("magdalena medio", "uraba", "metropolitana bogota", "metropolitana cali",
                                                   "metropolitana medellin", "comisarias", "intendencias") ~ NA_character_,
                         TRUE ~ dep_cod(Jurisdiccion)))
cat("Policía jurisdictions without cod:", paste(po_cod$Jurisdiccion[is.na(po_cod$cod)], collapse = ", "), "
")
po <- po |> left_join(po_cod, by = "Jurisdiccion") |>
  mutate(nivel = if_else(Jurisdiccion == "TOTAL", "nacional", "departamental"),
         unidad = case_when(Jurisdiccion == "TOTAL" ~ "Colombia", !is.na(cod) ~ dep_name(cod),
                            TRUE ~ paste0("Jurisdicción de Policía: ", Jurisdiccion)),
         parc = nivel == "departamental" & (is.na(cod) | cod %in% c("05", "25", "76")))
S$policia <- as_long(po |> transmute(nivel, cod, unidad, anio, total, nombre_fuente = Jurisdiccion,
                                     cobertura = if_else(parc, "parcial", "completa"),
                                     nota = cat_note("conteo de la Policía Nacional por jurisdicción, no del registro civil",
                                                     if_else(nivel == "departamental" & is.na(cod), "jurisdicción que no es un departamento; sin cod", NA),
                                                     if_else(!is.na(cod) & cod %in% c("05", "25", "76"), "jurisdicción departamental sin su área metropolitana (se publica aparte)", NA),
                                                     if_else(Jurisdiccion %in% c("Comisarías", "Intendencias"), "intendencias y comisarías publicadas por separado", NA),
                                                     hist_nota(cod, anio))),
                     "homicidio", "policia", 7, "policia_homicidios", f_po)

# ---------------------------------------------------------------------------
# assemble, flag sex inconsistencies, select ====
# ---------------------------------------------------------------------------
cat("assemble...\n")
cols <- c("nivel", "cod", "unidad", "anio", "causa", "sexo", "edad", "def_registradas", "fuente_id", "archivo",
          "calidad", "cobertura", "nota")
SS <- bind_rows(S) |>
  mutate(ukey = coalesce(cod, paste0("NA:", unidad)),
         nota = cat_note(nota),
         nombre_fuente = coalesce(nombre_fuente, unidad))
# drop exact duplicates inside a source (keep first), report
kk <- paste(SS$src, SS$nivel, SS$ukey, SS$anio, SS$causa, SS$sexo)
nd_ <- sum(duplicated(kk)); if (nd_ > 0) { print(count(SS[duplicated(kk), ], src, nivel, anio, causa, sexo));  cat("WARNING: duplicate cells inside sources:", nd_, "(first kept)\n"); SS <- SS[!duplicated(kk), ] }
# total = hombres + mujeres within a source
chk <- SS |> filter(!bloqueada | TRUE) |> select(src, nivel, ukey, anio, causa, sexo, v = def_registradas) |>
  pivot_wider(names_from = sexo, values_from = v) |>
  filter(!is.na(total), !is.na(hombres), !is.na(mujeres), total != hombres + mujeres) |>
  transmute(src, nivel, ukey, anio, causa, dif = total - hombres - mujeres)
SS <- SS |> left_join(chk, by = c("src", "nivel", "ukey", "anio", "causa")) |>
  mutate(cobertura = if_else(!is.na(dif) & sexo %in% c("hombres", "mujeres"), "parcial", cobertura),
         nota = if_else(!is.na(dif) & sexo %in% c("hombres", "mujeres"),
                        cat_note(nota, paste0("hombres + mujeres difiere del total en ", dif, " (total publicado conservado)")), nota)) |>
  select(-dif)
cat("cells with sexes not adding to the total:", nrow(chk), "\n")

# selection
keys <- c("nivel", "ukey", "anio", "causa")
Cd <- SS |> filter(!bloqueada) |>
  summarise(tot = def_registradas[sexo == "total"][1], has_sex = all(c("hombres", "mujeres") %in% sexo),
            rank = first(rank), demote = first(demote), .by = all_of(c(keys, "src"))) |>
  filter(!is.na(tot)) |> arrange(demote, rank)
win <- Cd |> slice(1, .by = all_of(keys))
alt <- Cd |> filter(has_sex) |> inner_join(win |> select(all_of(keys), wtot = tot, wsrc = src, whas = has_sex), by = keys) |>
  filter(!whas, tot == wtot) |> slice(1, .by = all_of(keys)) |> select(all_of(keys), asrc = src, wsrc)
win <- win |> left_join(alt, by = keys) |> mutate(src_sel = coalesce(asrc, src), swapped = !is.na(asrc)) |>
  select(all_of(keys), src_sel, swapped, wsrc)

# pooled intendencias/comisarías (TN, TN_I, TN_C) must not be selected together with units that belong to them
# in the same year and cause when they come from different sources: the better source (demotion first, then
# rank) keeps its unit, the other is blocked and stays only in the sources table
tset <- c("18", "27", "44", "50", "81", "85", "86", "88", "91", "94", "95", "97", "99")
eff <- Cd |> mutate(eff = rank + 100 * demote) |> select(all_of(keys), src, eff)
selw <- win |> left_join(eff, by = c(keys, "src_sel" = "src")) |>
  filter(nivel == "departamental") |>
  mutate(is_tn = ukey %in% c("TN", "TN_I", "TN_C"),
         is_member = ukey %in% tset | str_detect(ukey, "^NA:Jurisdicción de Policía: (Intendencias|Comisarías)"))
tn_sel <- selw |> filter(is_tn) |> select(anio, causa, tn_ukey = ukey, tn_src = src_sel, tn_eff = eff)
conf <- selw |> filter(is_member) |> inner_join(tn_sel, by = c("anio", "causa"), relationship = "many-to-many") |>
  filter(src_sel != tn_src)
block_tn <- conf |> filter(tn_eff > eff) |> distinct(nivel, ukey = tn_ukey, anio, causa)
block_mem <- conf |> filter(tn_eff <= eff) |> distinct(nivel, ukey, anio, causa)
cat("pooled-vs-separate conflicts resolved: TN blocked in", nrow(block_tn), "unit-years, members blocked in", nrow(block_mem), fill = TRUE)
blocked_keys <- bind_rows(block_tn, block_mem) |> mutate(bk = TRUE)
win <- win |> left_join(blocked_keys, by = keys) |> mutate(src_sel = if_else(!is.na(bk), NA_character_, src_sel)) |> select(-bk)
cat("groups where a lower source with identical total supplied the sexes:", sum(win$swapped), "\n")
SS <- SS |> left_join(win |> select(all_of(keys), src_sel, swapped, wsrc), by = keys) |>
  mutate(nota = if_else(!is.na(src_sel) | bloqueada, nota, if (FALSE) nota else nota),
         elegida = !bloqueada & !is.na(src_sel) & src == src_sel,
         nota = if_else(elegida & swapped, cat_note(nota, paste0("total idéntico al de ", wsrc, ", que no trae sexo")), nota))
T1 <- SS |> filter(elegida) |> arrange(match(nivel, c("nacional", "departamental", "municipal")), cod, anio, causa, sexo) |>
  select(all_of(cols))
TF <- SS |> arrange(match(nivel, c("nacional", "departamental", "municipal")), cod, anio, causa, sexo, rank) |>
  select(all_of(cols), elegida, fuente_src = src)
write_csv(T1, gzfile(paste0(od, "/mortalidad_colombia.csv.gz")), na = "")
write_csv(TF |> select(-fuente_src), gzfile(paste0(od, "/mortalidad_colombia_fuentes.csv.gz")), na = "")
cat("table 1:", nrow(T1), "rows; sources table:", nrow(TF), "rows\n")

# ---------------------------------------------------------------------------
# population ====
# ---------------------------------------------------------------------------
cat("population...\n")
f_pn <- paste0(R, "dane_proyecciones_nacional_1950-2070.csv")
f_pd <- paste0(R, "dane_proyecciones_departamental_1985-2050.csv.gz")
f_pm <- "output/deaths_pop_munic_1985_2023.csv.gz"
pw <- function(d, nivel, cod, unidad, anio, hom, muj, fuente_id, archivo, tipo) {
  tibble(nivel = nivel, cod = cod, unidad = unidad, anio = anio, hombres = hom, mujeres = muj) |>
    mutate(total = hombres + mujeres) |>
    pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "poblacion") |>
    mutate(fuente_id = fuente_id, archivo = archivo, tipo = tipo(anio))
}
tipo_pr <- \(a) if_else(a <= 2017, "retroproyeccion", "proyeccion")
pn <- read_csv(f_pn, show_col_types = FALSE) |> filter(area == "total") |> summarise(p = sum(population), .by = c(year, sex)) |>
  pivot_wider(names_from = sex, values_from = p)
P1 <- pw(pn, "nacional", "00", "Colombia", pn$year, pn$male, pn$female, "dane_proyecciones", f_pn, tipo_pr)
pdp <- read_csv(f_pd, show_col_types = FALSE) |> filter(area == "total") |>
  summarise(p = sum(population), .by = c(unit_code, year, sex)) |> pivot_wider(names_from = sex, values_from = p)
P2 <- pw(pdp, "departamental", pdp$unit_code, dep_name(pdp$unit_code), pdp$year, pdp$male, pdp$female, "dane_proyecciones", f_pd, tipo_pr)
pm <- read_csv(f_pm, show_col_types = FALSE, col_types = cols(cod_munic = "c", cod_dpto = "c")) |> filter(!is.na(pop)) |>
  select(year, cod_munic, munic, sex, pop) |> pivot_wider(names_from = sex, values_from = pop)
P3 <- pw(pm, "municipal", pm$cod_munic, pm$munic, pm$year, pm$m, pm$f, "dane_proyecciones", f_pm, tipo_pr)
cen_years <- c(1905, 1912, 1918, 1928, 1938, 1951, 1964, 1973)
pcen <- function(d, nivel, cod, unidad, fuente_id, archivo) {
  d <- d |> filter(data_available == 1, year %in% cen_years)
  d |> transmute(nivel = nivel, cod = cod, unidad = unidad, anio = year, total, hombres = male, mujeres = female) |>
    pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "poblacion") |> filter(!is.na(poblacion)) |>
    mutate(fuente_id = fuente_id, archivo = archivo, tipo = "censo")
}
f1 <- G("national_population_clean_v02.csv"); f2 <- G("department_population_clean_v03.csv"); f3 <- G("municipal_population_clean_v03.csv")
cn <- read_delim(f1, delim = ";", show_col_types = FALSE, name_repair = "minimal")[, 1:7]
P4 <- pcen(cn, "nacional", "00", "Colombia", "dane_anuarios", f1) |> mutate(cod = "00", unidad = "Colombia")
cd <- read_any(f2, ";") |> mutate(cod = dep_cod(str_replace_all(department, "_", " ")))
stopifnot(!any(is.na(cd$cod[cd$data_available == 1])))
P5 <- cd |> filter(data_available == 1, year %in% cen_years) |>
  transmute(nivel = "departamental", cod, unidad = dep_name(cod), anio = year, total, hombres = male, mujeres = female) |>
  pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "poblacion") |> filter(!is.na(poblacion)) |>
  mutate(fuente_id = "dane_anuarios", archivo = f2, tipo = "censo")
cm <- read_csv(f3, show_col_types = FALSE, col_types = cols(dane_code = "d", known_data_problem = "c", .default = "?")) |>
  mutate(cod = muni_cod(dane_code, department, municipality))
P6 <- cm |> filter(data_available == 1, year %in% cen_years) |>
  transmute(nivel = "municipal", cod, unidad = coalesce(muni_name(cod, NA_character_), str_to_title(municipality)), anio = year,
            total, hombres = male, mujeres = female) |>
  pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "poblacion") |> filter(!is.na(poblacion)) |>
  mutate(fuente_id = "dane_anuarios", archivo = f3, tipo = "censo")
POB <- bind_rows(P1, P2, P3, P4, P5, P6) |> select(nivel, cod, unidad, anio, sexo, poblacion, fuente_id, archivo, tipo) |>
  arrange(match(nivel, c("nacional", "departamental", "municipal")), cod, anio, tipo, sexo)
write_csv(POB, gzfile(paste0(od, "/poblacion_colombia.csv.gz")), na = "")

# ---------------------------------------------------------------------------
# unit crosswalk ====
# ---------------------------------------------------------------------------
cat("crosswalk...\n")
XW <- bind_rows(
  SS |> filter(nivel != "municipal" | src != "eevv_x") |>
    distinct(fuente_id, nombre_fuente, nivel, cod, unidad),
  POB |> mutate(nombre_fuente = unidad) |> distinct(fuente_id, nombre_fuente, nivel, cod, unidad)) |>
  distinct() |>
  mutate(convencion = case_when(
    cod == "00" ~ "nacional",
    cod == "TN" ~ "agrupado: intendencias y comisarías publicadas juntas (no se divide)",
    cod %in% c("TN_I", "TN_C") ~ "agrupado parcial: solo intendencias o solo comisarías, publicadas así ese año",
    is.na(cod) & nivel == "departamental" ~ "jurisdicción de Policía que no es un departamento; sin cod",
    is.na(cod) ~ "municipio sin emparejar con DIVIPOLA de forma única; sin cod",
    nivel == "departamental" ~ "departamento de la Constitución de 1991 más Bogotá D.C. (límites históricos: ver nota)",
    nivel == "municipal" & cod %in% dv$cod ~ "municipio DIVIPOLA 2026",
    TRUE ~ "código municipal que no está en DIVIPOLA 2026 (municipio desaparecido o código antiguo)")) |>
  left_join(hist_dep_note |> rename(nota_historica = nota), by = "cod") |>
  mutate(nota = if_else(nivel == "departamental", na_if(nota_historica, ""), NA_character_)) |> select(-nota_historica) |>
  arrange(match(nivel, c("nacional", "departamental", "municipal")), cod, unidad, fuente_id, nombre_fuente)
write_csv(XW, paste0(od, "/unidades_colombia.csv"), na = "")

# ---------------------------------------------------------------------------
# verification ====
# ---------------------------------------------------------------------------
cat("verification...\n")
V <- list(); addv <- function(check, n, n_failing, note) V[[length(V) + 1]] <<- tibble(check = check, n = n, n_failing = n_failing, note = note)
T1k <- T1 |> mutate(ukey = coalesce(cod, paste0("NA:", unidad)))
# (1)
dk <- T1k |> count(nivel, ukey, anio, causa, sexo) |> filter(n > 1)
addv("1 clave única (nivel,cod,anio,causa,sexo)", nrow(T1k), nrow(dk), "ukey = cod, o el nombre de la unidad cuando cod es NA")
# (2)
w <- T1k |> select(nivel, ukey, anio, causa, sexo, v = def_registradas, cobertura) |>
  pivot_wider(names_from = sexo, values_from = c(v, cobertura)) |>
  filter(!is.na(v_total), !is.na(v_hombres), !is.na(v_mujeres))
f2 <- w |> filter(v_total != v_hombres + v_mujeres)
addv("2 total = hombres + mujeres", nrow(w), nrow(f2),
     paste0("de los que fallan, ", sum(f2$cobertura_hombres == "parcial"), " tienen las filas de sexo marcadas parcial (total conservado)"))
# (3)
wh <- T1k |> filter(causa %in% c("todas", "homicidio")) |> select(nivel, ukey, anio, sexo, causa, v = def_registradas) |>
  pivot_wider(names_from = causa, values_from = v) |> filter(!is.na(todas), !is.na(homicidio))
f3 <- wh |> filter(homicidio > todas)
addv("3 homicidio <= todas", nrow(wh), nrow(f3),
     if (nrow(f3)) paste0("fallan: ", paste(head(paste(f3$nivel, f3$ukey, f3$anio, f3$sexo), 10), collapse = "; ")) else "")
# (4)
for (cz in c("todas", "homicidio")) {
  e <- TF |> filter(nivel == "nacional", sexo == "total", causa == cz, fuente_src == "eevv_x" | str_starts(fuente_src, "eevv")) |> select(anio, ev = def_registradas)
  o <- TF |> filter(nivel == "nacional", sexo == "total", causa == cz, str_starts(fuente_src, "who")) |> select(anio, who = def_registradas)
  j <- inner_join(e, o, by = "anio") |> mutate(rel = abs(ev - who) / who)
  addv(paste0("4 EEVV nacional vs OMS, ", cz), nrow(j), sum(j$rel > 0.05),
       paste0("máx. diferencia relativa ", round(max(j$rel), 4), " (año ", j$anio[which.max(j$rel)], "); n_failing = años con diferencia > 5% (",
              paste(j$anio[j$rel > 0.05], collapse = ","), "); difieren por diseño; media ", round(mean(j$rel), 4)))
}
# (5)
dd <- bind_rows(lapply(c("todas", "homicidio"), \(cz) {
  n <- T1k |> filter(nivel == "nacional", causa == cz, sexo == "total") |> select(anio, nacional = def_registradas, fuente_nac = fuente_id)
  d <- T1k |> filter(nivel == "departamental", causa == cz, sexo == "total", !is.na(cod)) |>
    summarise(suma_deptos = sum(def_registradas), n_unidades = n(), n_parcial = sum(cobertura == "parcial"), .by = anio)
  full_join(n, d, by = "anio") |> mutate(causa = cz, rel = (suma_deptos - nacional) / nacional) |> arrange(anio)
})) |> filter(anio >= 1915, anio <= 2023)
write_csv(dd, paste0(od, "/verificacion_nacional_vs_departamentos.csv"), na = "")
for (cz in c("todas", "homicidio")) {
  x <- dd |> filter(causa == cz); both <- x |> filter(!is.na(nacional), !is.na(suma_deptos))
  bad <- both |> filter(abs(rel) > 0.01)
  addv(paste0("5 nacional vs suma de departamentos, ", cz), nrow(both), nrow(bad),
       paste0("n_failing = años con |dif| > 1%. Años sin nacional: ", paste(x$anio[is.na(x$nacional)], collapse = ","), ". Años sin departamentos: ",
              paste(x$anio[is.na(x$suma_deptos)], collapse = ","), ". Años con |dif| > 1%: ", paste(bad$anio, collapse = ","),
              ". Detalle en verificacion_nacional_vs_departamentos.csv"))
}
# (6)
av <- read_csv("output/tables/data_availability_information.csv", show_col_types = FALSE) |>
  filter(dominio %in% c("Defunciones", "Homicidios y violencia"), !is.na(detalle)) |>
  transmute(nivel = tolower(nivel), causa = if_else(dominio == "Defunciones", "todas", "homicidio"), anio = year, agregado, agregable)
have <- T1 |> distinct(nivel, causa, anio) |> mutate(en_tabla = TRUE)
j6 <- full_join(av |> mutate(en_inventario = TRUE), have, by = c("nivel", "causa", "anio")) |>
  filter(anio >= 1915, anio <= 2023)
miss <- j6 |> filter(!is.na(en_inventario), is.na(en_tabla))
extra <- j6 |> filter(is.na(en_inventario), !is.na(en_tabla))
write_csv(bind_rows(miss |> mutate(sentido = "en inventario, falta en tabla 1"), extra |> mutate(sentido = "en tabla 1, no en inventario")) |>
            select(sentido, nivel, causa, anio, agregado, agregable),
          paste0(od, "/verificacion_cobertura_inventario.csv"), na = "")
fmt <- \(d) if (nrow(d)) paste(d |> summarise(a = paste0(nivel[1], "/", causa[1], ": ", paste(anio, collapse = ",")), .by = c(nivel, causa)) |> pull(a), collapse = " | ") else "ninguno"
addv("6 cobertura vs data_availability_information.csv: en inventario, falta en tabla 1", nrow(av), nrow(miss), fmt(miss))
addv("6 cobertura vs data_availability_information.csv: en tabla 1, no en inventario", nrow(have), nrow(extra), fmt(extra))
# (7)
cnt <- T1 |> mutate(decada = anio %/% 10 * 10) |> count(nivel, causa, decada)
for (i in seq_len(nrow(cnt))) addv(paste0("7 filas nivel=", cnt$nivel[i], " causa=", cnt$causa[i], " decada=", cnt$decada[i]), cnt$n[i], 0, "")
VER <- bind_rows(V)
write_csv(VER, paste0(od, "/verification.csv"), na = "")
print(VER |> filter(!str_starts(check, "7")), n = 50, width = 220)

# ---------------------------------------------------------------------------
# dictionary ====
# ---------------------------------------------------------------------------
rng <- T1 |> summarise(anios = paste(range(anio), collapse = "-"), n_anios = n_distinct(anio), filas = n(),
                       .by = c(nivel, causa)) |> arrange(match(nivel, c("nacional", "departamental", "municipal")), causa)
gaps <- T1 |> distinct(nivel, causa, anio) |> arrange(nivel, causa, anio) |>
  summarise(huecos = { y <- anio; all_y <- min(y):max(y); m <- setdiff(all_y, y)
    if (length(m)) paste(m, collapse = ", ") else "ninguno" }, .by = c(nivel, causa))
tabrng <- rng |> left_join(gaps, by = c("nivel", "causa")) |>
  transmute(l = paste0("| ", nivel, " | ", causa, " | ", anios, " | ", n_anios, " | ", filas, " | ", huecos, " |"))
srcs <- TF |> summarise(filas = n(), elegidas = sum(elegida), anios = paste(range(anio), collapse = "-"), .by = c(fuente_src, fuente_id)) |>
  arrange(fuente_src)
dic <- c(
"# Mortalidad registrada en Colombia, 1915-2023 (fase 1)",
"",
"Defunciones **registradas** (no ajustadas, no imputadas) por causa (todas, homicidio), sexo (total, hombres, mujeres) y",
"nivel geográfico (nacional, departamental, municipal), sin edad todavía. Generado por `code/60_build_mortality_database.R`",
"a partir de los archivos ya extraídos del proyecto.",
"",
"## Archivos",
"",
"| archivo | contenido |",
"|---|---|",
"| `mortalidad_colombia.csv.gz` | una fuente por celda (la mejor, según la prioridad de abajo) |",
"| `mortalidad_colombia_fuentes.csv.gz` | todas las fuentes sin armonizar, mismas columnas más `elegida` (TRUE = la fila pasó a la tabla 1) |",
"| `poblacion_colombia.csv.gz` | denominadores: proyecciones y retroproyecciones DANE, y totales censales |",
"| `unidades_colombia.csv` | cada nombre de unidad encontrado en cada fuente, su cod y la convención territorial |",
"| `verification.csv`, `verificacion_nacional_vs_departamentos.csv`, `verificacion_cobertura_inventario.csv` | controles |",
"",
"## Columnas de `mortalidad_colombia.csv.gz` y `_fuentes`",
"",
"| columna | definición |",
"|---|---|",
"| nivel | `nacional`, `departamental`, `municipal` |",
"| cod | DIVIPOLA: `00` nacional, 2 dígitos departamento, 5 dígitos municipio. `TN` = intendencias y comisarías agrupadas; `TN_I` / `TN_C` = solo intendencias / solo comisarías (así publicadas en 1938-39 en los homicidios de col_gap). Vacío (NA) solo para jurisdicciones de Policía que no son un departamento y para municipios de col_gap sin emparejamiento único; `unidad` siempre está llena |",
"| unidad | nombre de la unidad (departamentos y municipios con el nombre actual de DIVIPOLA) |",
"| anio | año de registro (EEVV: año de registro; las demás fuentes, el año que publican) |",
"| causa | `todas` = todas las causas; `homicidio` (definición abajo) |",
"| sexo | `total`, `hombres`, `mujeres` |",
"| edad | `total` en esta fase |",
"| def_registradas | defunciones registradas tal como las publica la fuente |",
"| fuente_id | clave en `documents/inventory/fuentes.csv` |",
"| archivo | archivo de origen, relativo a la raíz del proyecto |",
"| calidad | `observada`; `imputada_por_la_fuente` (la transcripción marca cifras copiadas del año anterior, estimadas o completadas por la fuente); `corregida` no se usa en esta fase |",
"| cobertura | `completa` o `parcial`: la fuente marca subregistro (cuadro 2 del Registro 1970-1978: `*`, `**`; notas DANE de col_gap), cubre solo parte de las unidades, el año es corto (EEVV 1979), el concepto difiere, o la fila de sexo no suma el total de su fuente |",
"| nota | avisos: marcas de la fuente, límites territoriales históricos, sexo no registrado, etc. |",
"| elegida | (solo en `_fuentes`) TRUE si la fila está en la tabla 1 |",
"",
"## Prioridad de fuentes",
"",
"Por (nivel, unidad, año, causa) se elige **una** fuente para todo el grupo total/hombres/mujeres, en este orden:",
"1. EEVV microdatos 1979-2023 (`dane_eevv`). El año 1979 (año corto: 110 400 defunciones frente a 135 925 del Registro) se degrada por debajo de cualquier otra fuente, salvo en homicidio departamental (la única alternativa es la Policía, parcial).",
"2. Registro de defunciones 1970-1978: cuadro 2 (por sección y sexo, 1970-1984) y cuadro 1 (total nacional 1915-1984).",
"3. Estadística vital 1958-1960 (cuadros departamental y municipal) y anuarios 1965-1967 y 1968-1969 (fila `all` = todas las edades).",
"4. col_gap (transcripciones de los anuarios): defunciones nacionales, departamentales (archivo `_split` cuando la unidad aparece por separado, `_aggregated` para los años con intendencias y comisarías agrupadas), municipales; homicidios departamentales 1923-1965.",
"5. OMS (totales nacionales por sexo, 1953-2023). 6. LAMBdA (suma de edades, 1926-2015, solo todas las causas). 7. Policía Nacional (homicidios, 1962-2002). 8. Suma nacional de los homicidios departamentales de col_gap (parcial; solo cuando no hay nada mejor).",
"",
"Reglas: (a) una celda tiene una sola fuente: nunca se combinan fuentes dentro de un grupo; (b) si la ganadora solo trae total y una fuente inferior trae sexos con **exactamente el mismo total**, se usa esa (es la misma cifra publicada; la nota lo dice); (c) si los sexos de una fuente no suman su total se conserva el total y las filas de sexo quedan `parcial` con nota; (d) en años con unidades agrupadas, ver convención territorial.",
"",
"## Convención territorial",
"",
"Departamentos de la Constitución de 1991 más Bogotá D.C. Las fuentes que publican las intendencias y comisarías agrupadas (Registro 1970-1978 cuadro 2, anuarios 1965-1967, Estadística vital 1958-1960, col_gap en años agrupados) conservan una unidad `Intendencias y comisarías (agrupadas)` con cod `TN`; no se reparten. Para col_gap se usa el archivo `_split` cuando la unidad existe por separado y el `_aggregated` para los años agrupados, nunca los dos para la misma unidad-año: en un año, las unidades separadas pasan a la tabla 1 solo si su suma coincide con el agregado `TN`; si no coincide, se usa `TN` y las unidades separadas quedan solo en `_fuentes` (`elegida` FALSE). En 1958-1960 las sumas municipales por departamento se usan solo para las unidades que el cuadro departamental publica por separado.",
"Los límites son los de la época: Caldas incluye Quindío y Risaralda hasta 1966, Bolívar incluye Córdoba y Sucre antes de 1952 y Sucre hasta 1966, Magdalena incluye Cesar (y La Guajira hasta 1963), Cundinamarca incluye Bogotá hasta 1955, etc. Ver `nota` y `unidades_colombia.csv`. No se reconstruyen los límites actuales.",
"",
"## Definición de las causas",
"",
"- `todas`: todas las defunciones no fetales registradas por la fuente.",
"- `homicidio` en las EEVV: código 101 de la Lista 105 Colombia de DANE (agresiones; CIE-9 E960-E969 hasta 1997, CIE-10 X85-Y09 desde 1998), igual que `dx_h` en `code/02_summarise_deaths.R` y `dx_homicide` en `code/11_shared_dataset.R`. No incluye intención indeterminada (102) ni intervención legal (103).",
"- Homicidio en otras fuentes: el que publica cada una (OMS: agresiones; col_gap 1923-1965: homicidios de los anuarios, con las excepciones de 1943-1945, años en que la fuente es `muertes violentas accidentales`, marcados parcial; Policía: homicidios registrados por la Policía, no del registro civil).",
"- Las EEVV son por **lugar de ocurrencia** de la defunción; el Registro y los anuarios, por la sección donde se registró; no es residencia.",
"- Las EEVV incluyen defunciones de sexo no registrado en el total (nota); el subregistro del Caribe antes de 1998 no se corrige.",
"",
"## Cobertura de la tabla 1 (años presentes por nivel y causa)",
"",
"| nivel | causa | años | n años | filas | años sin ninguna fila dentro del rango |",
"|---|---|---|---|---|---|",
tabrng$l,
"",
"## Fuentes cargadas (tabla `_fuentes`)",
"",
"| variante | fuente_id | años | filas | filas elegidas |",
"|---|---|---|---|---|",
paste0("| ", srcs$fuente_src, " | ", srcs$fuente_id, " | ", srcs$anios, " | ", srcs$filas, " | ", srcs$elegidas, " |"),
"",
"## Población (`poblacion_colombia.csv.gz`)",
"",
"Columnas: nivel, cod, unidad, anio, sexo (`total`, `hombres`, `mujeres`), poblacion, fuente_id, archivo, tipo (`censo`, `proyeccion`, `retroproyeccion`). Nacional 1950-2070 (suma de edades, área total) y departamental 1985-2050 de las proyecciones DANE; municipal 1985-2023 de `output/deaths_pop_munic_1985_2023.csv.gz` (DANE, retroproyecciones hasta 2017 y proyecciones desde 2018); totales censales (1905, 1912, 1918, 1928, 1938, 1951, 1964, 1973) de las transcripciones col_gap. Las proyecciones son por lugar de residencia.",
"",
"## Vacíos conocidos",
"",
"- Antes de 1979 no hay datos municipales salvo 1924-1936 (col_gap, con vacíos) y 1958-1960.",
"- 1978 no existe en las EEVV; 1979 es un año corto.",
"- Homicidio departamental 1966-1978 solo en la Policía (jurisdicciones, no departamentos; Antioquia, Cundinamarca y Valle sin su área metropolitana).",
"- Homicidio nacional 1923-1952 solo como suma de los departamentos de col_gap (parcial); 1943-1945 es otro concepto.",
"- LAMBdA y OMS se incluyen para comparar; no se verificó si LAMBdA corrige subregistro.",
"- Subregistro: el Registro 1970-1978 marca `*` y `**` en varios departamentos; el subregistro del Caribe en las EEVV antes de 1998 no está marcado en las fuentes y no se corrige aquí.",
"- Lo que no reconcilia está en `verification.csv`.",
"",
"## Cómo reconstruir",
"",
"Desde la raíz del proyecto: `Rscript code/60_build_mortality_database.R` (usa solo archivos ya extraídos; tarda unos minutos).")
writeLines(dic, paste0(od, "/diccionario.md"), useBytes = TRUE)
cat("done\n")
