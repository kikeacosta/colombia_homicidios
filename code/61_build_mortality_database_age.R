# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 61. Colombia mortality database, phase 2: REGISTERED deaths BY AGE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Same database as phase 1 (code/60_build_mortality_database.R) with age:
# registered deaths (all causes, homicide) by sex (total, men, women) x age
# group, national / departmental / municipal. Nothing is adjusted, imputed or
# split: coarse age groups are kept as published. Same cod / unit / quality /
# coverage conventions as phase 1 (output/mortalidad_colombia/).
#
# Run from the project root:  Rscript code/61_build_mortality_database_age.R
#
# input : data_inter/deaths_munic_age_1979-2023.rds                    (EEVV)
#         data_input/historical/dane_defunciones_1970_1978_cuadro{02,03,06,10,11}_*.csv
#         data_input/historical/dane_defunciones_196{5_1967,8_1969}_secciones_sexo_edad.csv
#         data_input/reference/who_deaths_age_colombia_1953-1977.csv     (OMS, all causes)
#         data_input/reference/who_violent_age_colombia_1953-1977.csv    (OMS, homicide)
#         data_input/historical/lambda_Col_Deaths{m,f}.txt, lambda_Col_Cause19_Deaths{m,f}.txt
#         output/mortalidad_colombia/mortalidad_colombia{,_fuentes}.csv.gz   (phase 1: check 2)
#         output/tables/data_availability_information.csv                   (check 6)
# output: output/mortalidad_colombia/
#           mortalidad_colombia_edad.csv.gz            best source per cell (age rows)
#           mortalidad_colombia_edad_municipal.csv.gz  municipal rows (if the single file is too large)
#           mortalidad_colombia_edad_fuentes.csv.gz    every source, `elegida`
#           verification_edad.csv (+ _detalle, _cobertura, _cobertura_inventario, _filas_por_decada)
#           diccionario_edad.md
#
# Selection: per (nivel, cod, anio, causa) ONE source for all sexes and ages:
# (1) the 1979 EEVV short year is demoted as in phase 1, (2) finest age detail
# (number of age groups after harmonisation), (3) priority EEVV > Registro de
# defunciones 1970-1978 > anuarios 1965-1969 > OMS > LAMBdA.
# Age convention: edad_inicio = first completed year of the group, edad_fin =
# last completed year INCLUDED (NA = open group). Infant detail (<1 day ... 11
# months) -> "0"; 12-23 months + 2-4 years -> "1-4".
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(tidyverse); library(stringi)})
options(width = 200)
od <- "output/mortalidad_colombia"
H <- "data_input/historical/"
R <- "data_input/reference/"
stopifnot(file.exists("code/60_build_mortality_database.R"), file.exists(paste0(od, "/mortalidad_colombia.csv.gz")))
MUN_FULL <- TRUE    # TRUE = explicit zero rows at municipal level (about 5 million rows); FALSE = only cells with deaths
MAX_MB <- 40

# ---------------------------------------------------------------------------
# helpers (same logic as phase 1) ====
# ---------------------------------------------------------------------------
norm <- function(x) x |> stri_trans_general("Latin-ASCII") |> tolower() |>
  str_replace_all("[^a-z0-9]+", " ") |> str_squish()
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
dv <- read_csv(paste0(R, "DIVIPOLA-_Códigos_municipios_20260307.csv"), show_col_types = FALSE) |>
  transmute(cod = `Código Municipio`, nombre = str_to_title(`Nombre Municipio`))
muni_name <- function(cod, fallback) { n <- dv$nombre[match(cod, dv$cod)]; ifelse(is.na(n), fallback, n) }
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
cat_note <- function(...) {
  x <- list(...); x <- lapply(x, \(v) ifelse(is.na(v) | v == "", NA_character_, v))
  r <- do.call(paste, c(lapply(x, \(v) replace_na(v, "")), sep = "|"))
  r <- str_replace_all(r, "\\|+", "; ") |> str_remove("^; ") |> str_remove("; $")
  ifelse(r == "", NA_character_, r)
}
rngs <- function(y) {   # compact year ranges "1953-1969, 1972, 1974-1977"
  y <- sort(unique(y)); if (!length(y)) return("")
  g <- cumsum(c(1, diff(y) != 1))
  paste(tapply(y, g, \(v) if (length(v) == 1) as.character(v) else paste0(min(v), "-", max(v))), collapse = ", ")
}
lvl_ord <- c("nacional", "departamental", "municipal")

# standard age groups; edad_fin = last completed year INCLUDED (NA = open)
std_ages <- tibble(edad = c("0", "1-4", paste0(seq(5, 80, 5), "-", seq(9, 84, 5)), "85+"),
                   edad_inicio = c(0, 1, seq(5, 85, 5)), edad_fin = c(0, 4, seq(9, 84, 5), NA))
stopifnot(nrow(std_ages) == 19)
# text age labels of the DANE tables -> standard group (infant detail collapsed)
age_map <- bind_rows(
  tibble(raw = c("under 1 day", "1-6 days", "7-29 days", "1-5 months", "6-11 months", "under 1 year"),
         edad = "0", edad_inicio = 0, edad_fin = 0),
  tibble(raw = c("12-23 months", "2-4", "1-4"), edad = "1-4", edad_inicio = 1, edad_fin = 4),
  std_ages |> filter(!edad %in% c("0", "1-4")) |> mutate(raw = edad),
  tibble(raw = "not stated", edad = "desconocida", edad_inicio = NA_real_, edad_fin = NA_real_))
age_note_dane <- "edad: 0 = menores de 1 día a 11 meses; 1-4 = 12-23 meses + 2-4 años; 'not stated' = desconocida"
age_note_1965 <- "edad: 0 = menores de 1 año; 'not stated' = desconocida"

# raw DANE rows -> long rows
age_long <- function(d) {
  d |> inner_join(age_map, by = c("age" = "raw")) |>
    summarise(hombres = sum(male), mujeres = sum(female), total = sum(total),
              .by = c(src, nivel, cod, anio, causa, edad, edad_inicio, edad_fin)) |>
    pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "def") |> filter(!is.na(def))
}
all_pub <- function(d) d |> filter(age == "all") |>
  transmute(src, nivel, cod, anio, causa, hombres = male, mujeres = female, total) |>
  pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "publicado")

CORE <- list(); META <- list(); ALLP <- list()

# ---------------------------------------------------------------------------
# 1. EEVV 1979-2023 (place of occurrence) ====
# ---------------------------------------------------------------------------
cat("EEVV...\n")
f_ev <- "data_inter/deaths_munic_age_1979-2023.rds"
ev <- readRDS(f_ev) |> as_tibble() |>
  mutate(cod = sprintf("%02d%03d", cod_dpto, cod_munic), dcod = sprintf("%02d", cod_dpto),
         edad = case_when(is.na(age) ~ "desconocida", age == 0 ~ "0", age == 1 ~ "1-4", age >= 85 ~ "85+",
                          TRUE ~ paste0(age, "-", age + 4)),
         sx = case_when(sex == "m" ~ "hombres", sex == "f" ~ "mujeres", TRUE ~ "sin_sexo"))
stopifnot(all(ev$edad %in% c(std_ages$edad, "desconocida")), !anyNA(ev$dx_tot))
ev_long <- bind_rows(ev |> transmute(anio = year, cod, dcod, nacional = "00", edad, sx, causa = "todas", v = dx_tot),
                     ev |> transmute(anio = year, cod, dcod, nacional = "00", edad, sx, causa = "homicidio", v = dx_h))
rm(ev)
ev_level <- function(nivel, key) {
  d <- ev_long |> mutate(ccod = .data[[key]]) |>
    summarise(v = sum(v), .by = c(ccod, anio, causa, edad, sx)) |>
    pivot_wider(names_from = sx, values_from = v, values_fill = 0)
  for (v in c("hombres", "mujeres", "sin_sexo")) if (!v %in% names(d)) d[[v]] <- 0
  d <- d |> mutate(total = hombres + mujeres + sin_sexo)
  sin <- d |> summarise(sin_sexo = sum(sin_sexo), .by = c(ccod, anio, causa))
  if (nivel == "municipal" && !MUN_FULL) {
    core <- d
  } else {
    uy <- d |> distinct(ccod, anio)
    g <- uy |> cross_join(tibble(causa = c("todas", "homicidio"))) |> cross_join(std_ages |> select(edad)) |>
      left_join(d |> filter(edad != "desconocida"), by = c("ccod", "anio", "causa", "edad")) |>
      mutate(across(c(hombres, mujeres, sin_sexo, total), \(v) replace_na(v, 0)))
    unk <- d |> filter(edad == "desconocida", total > 0)
    core <- bind_rows(g, unk)
  }
  core <- core |> left_join(std_ages, by = "edad") |>
    pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "def")
  if (nivel == "municipal" && !MUN_FULL) core <- core |> filter(def > 0)
  core <- core |> transmute(src = "eevv", nivel = nivel, cod = ccod, anio, causa, sexo, edad, edad_inicio, edad_fin, def)
  m <- sin |> transmute(src = "eevv", nivel = nivel, cod = ccod, anio, causa, sin_sexo,
                        unidad = case_when(
                          nivel == "nacional" ~ "Colombia",
                          nivel == "departamental" ~ coalesce(dep_name(ccod), paste0("Código de departamento ", ccod, " (no existe en DIVIPOLA)")),
                          TRUE ~ muni_name(ccod, paste0("Código ", ccod, " no está en DIVIPOLA 2026"))),
                        calidad = "observada",
                        cobertura = if_else(anio == 1979, "parcial", "completa"),
                        nota = cat_note(
                          ifelse(anio == 1979, "1979 es un año corto en las EEVV; no comparable con los demás años", NA),
                          ifelse(sin_sexo > 0, paste0("incluye ", sin_sexo, " defunciones de sexo no registrado"), NA),
                          "lugar de ocurrencia",
                          ifelse(causa == "homicidio", "homicidio = Lista 105 código 101", NA),
                          ifelse(anio >= 2008, "microdatos con 85-89, 90-94, 95-99 y 100+ unidos en 85+", NA))) |>
    select(-sin_sexo)
  list(core = core, meta = m)
}
for (lv in list(c("nacional", "nacional"), c("departamental", "dcod"), c("municipal", "cod"))) {
  r <- ev_level(lv[1], lv[2]); CORE[[paste0("eevv_", lv[1])]] <- r$core; META[[paste0("eevv_", lv[1])]] <- r$meta
  cat("  ", lv[1], nrow(r$core), "rows\n")
}
rm(ev_long)

# ---------------------------------------------------------------------------
# 2. Registro de defunciones 1970-1978 ====
# ---------------------------------------------------------------------------
cat("Registro...\n")
f_c11 <- paste0(H, "dane_defunciones_1970_1978_cuadro11_secciones_edad.csv")
f_c3 <- paste0(H, "dane_defunciones_1970_1978_cuadro03_nacional_zona_edad.csv")
f_c6 <- paste0(H, "dane_defunciones_1970_1978_cuadro06_causas_edad_1973_1978.csv")
f_c10 <- paste0(H, "dane_defunciones_1970_1978_cuadro10_menores5_secciones.csv")
f_c2 <- paste0(H, "dane_defunciones_1970_1978_cuadro02_secciones_sexo_1970_1984.csv")
num3 <- function(d) d |> mutate(across(c(year, male, female, total), as.numeric), anio = as.integer(year))
c11 <- read_csv(f_c11, show_col_types = FALSE, col_types = cols(.default = "c")) |> num3() |>
  mutate(cod = case_when(unit == "Total nacional" ~ "00", unit == "Intendencias y comisarías" ~ "TN", TRUE ~ cod_dpto),
         nivel = if_else(cod == "00", "nacional", "departamental"), src = "reg_c11", causa = "todas")
stopifnot(!anyNA(c11$cod))
c2 <- read_csv(f_c2, show_col_types = FALSE, col_types = cols(.default = "c")) |>
  mutate(anio = as.integer(year), cod = case_when(unit == "Total nacional" ~ "00", unit == "Intendencias y comisarías" ~ "TN", TRUE ~ cod_dpto)) |>
  transmute(cod, anio, cobertura = if_else(!is.na(mark), "parcial", "completa"),
            nota = cat_note(mark_note, note, if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA), hist_nota(cod, anio)))
CORE$reg_c11 <- age_long(c11); ALLP$reg_c11 <- all_pub(c11)
META$reg_c11 <- c11 |> distinct(src, nivel, cod, anio, causa) |> left_join(c2, by = c("cod", "anio")) |>
  mutate(unidad = if_else(cod == "00", "Colombia", dep_name(cod)), calidad = "observada",
         nota = cat_note(nota, "cuadro 11 (sección x sexo x edad); cobertura y notas heredadas del cuadro 2 de la misma unidad-año", age_note_dane),
         cobertura = replace_na(cobertura, "completa"))
c3 <- read_csv(f_c3, show_col_types = FALSE, col_types = cols(.default = "c")) |> num3() |> filter(zone == "total") |>
  mutate(cod = "00", nivel = "nacional", src = "reg_c3", causa = "todas")
CORE$reg_c3 <- age_long(c3); ALLP$reg_c3 <- all_pub(c3)
META$reg_c3 <- c3 |> distinct(src, nivel, cod, anio, causa) |> mutate(unidad = "Colombia", calidad = "observada", cobertura = "completa",
  nota = cat_note("cuadro 3 (nacional, zona total, sexo x edad)", age_note_dane))
c6 <- read_csv(f_c6, show_col_types = FALSE, col_types = cols(.default = "c")) |> num3() |>
  filter(cause_code %in% c("148", "TOTAL")) |>
  mutate(cod = "00", nivel = "nacional", src = if_else(cause_code == "148", "reg_c6", "reg_c6t"),
         causa = if_else(cause_code == "148", "homicidio", "todas"))
CORE$reg_c6 <- age_long(c6); ALLP$reg_c6 <- all_pub(c6)
META$reg_c6 <- c6 |> distinct(src, nivel, cod, anio, causa) |> mutate(unidad = "Colombia", calidad = "observada", cobertura = "completa",
  nota = cat_note(if_else(causa == "homicidio",
                          "cuadro 6, CIE-8 lista A 148: homicidio y lesiones provocadas intencionalmente por otras personas, incluye intervención legal (no solo código 101 de la Lista 105)",
                          "cuadro 6, fila TOTAL NACIONAL"), age_note_dane))
c10 <- read_csv(f_c10, show_col_types = FALSE, col_types = cols(.default = "c")) |> num3() |> filter(age %in% c("under 5", "under 1", "1-4"))

# ---------------------------------------------------------------------------
# 3. Anuarios 1965-1969 (sección x sexo x edad) ====
# ---------------------------------------------------------------------------
cat("Anuarios 1965-69...\n")
f_b <- paste0(H, "dane_defunciones_1965_1967_secciones_sexo_edad.csv")
f_a <- paste0(H, "dane_defunciones_1968_1969_secciones_sexo_edad.csv")
for (ff in list(c(f_b, "ane_6567", age_note_1965), c(f_a, "ane_6869", age_note_dane))) {
  d <- read_csv(ff[1], show_col_types = FALSE, col_types = cols(.default = "c")) |> num3() |>
    mutate(cod = ifelse(norm(unit) == "total nacional", "00", dep_cod(unit)), nivel = if_else(cod == "00", "nacional", "departamental"),
           src = ff[2], causa = "todas")
  stopifnot(!anyNA(d$cod))
  CORE[[ff[2]]] <- age_long(d); ALLP[[ff[2]]] <- all_pub(d)
  META[[ff[2]]] <- d |> distinct(src, nivel, cod, anio, causa) |>
    mutate(unidad = if_else(cod == "00", "Colombia", dep_name(cod)), calidad = "observada", cobertura = "completa",
           nota = cat_note(if_else(cod == "TN", "unidad agrupada tal como se publica; no se divide", NA), hist_nota(cod, anio), ff[3]))
}

# ---------------------------------------------------------------------------
# 4. OMS 1953-1977 ====
# ---------------------------------------------------------------------------
cat("OMS...\n")
f_wd <- paste0(R, "who_deaths_age_colombia_1953-1977.csv")
f_wv <- paste0(R, "who_violent_age_colombia_1953-1977.csv")
who_age <- function(f, causa, src, keep) {
  d <- read_csv(f, show_col_types = FALSE)
  d <- d[keep(d), ]
  stopifnot(!any(duplicated(d[, c("Year", "Sex")])))
  # Deaths1 total; Deaths2 age 0; Deaths3 1-4 (Frmat 02) or age 1 (Frmat 01, with 2, 3, 4 in Deaths4-6);
  # Deaths7.. 5-year groups 5-9 ... 80-84 (Deaths22); Deaths23 = 85+; Deaths26 = unknown age
  stopifnot(all(is.na(unlist(d[, c("Deaths24", "Deaths25")]))))
  chk <- d |> rowwise() |> mutate(s = sum(c_across(Deaths2:Deaths26), na.rm = TRUE)) |> ungroup()
  stopifnot(all(chk$s == chk$Deaths1))
  l <- d |> select(Year, Sex, Frmat, List, Cause, starts_with("Deaths")) |> select(-Deaths1) |>
    pivot_longer(starts_with("Deaths"), names_to = "k", values_to = "v") |> mutate(k = as.integer(sub("Deaths", "", k))) |>
    filter(!is.na(v)) |>
    mutate(edad = case_when(k == 2 ~ "0", k %in% 3:6 ~ "1-4", k %in% 7:22 ~ std_ages$edad[match(5 + 5 * (k - 7), std_ages$edad_inicio)],
                            k == 23 ~ "85+", k == 26 ~ "desconocida"),
           sexo = if_else(Sex == 1, "hombres", "mujeres"))
  stopifnot(!anyNA(l$edad))
  l <- l |> summarise(def = sum(v), .by = c(Year, sexo, edad)) |> left_join(std_ages, by = "edad")
  w <- l |> select(Year, sexo, edad, edad_inicio, edad_fin, def) |> pivot_wider(names_from = sexo, values_from = def) |>
    mutate(total = hombres + mujeres) |>
    pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "def") |> filter(!is.na(def))
  nota_h <- if (causa == "homicidio") d |> distinct(Year, List) |>
    mutate(nh = if_else(List == "07A", "CIE-7 lista A 149: homicidio y operaciones de guerra",
                        "CIE-8 lista A 148: homicidio y lesiones provocadas intencionalmente por otras personas, incluye intervención legal")) |> select(Year, nh) else
    tibble(Year = unique(d$Year), nh = NA_character_)
  list(core = w |> transmute(src = src, nivel = "nacional", cod = "00", anio = Year, causa = causa, sexo, edad, edad_inicio, edad_fin, def),
       meta = d |> distinct(Year, Frmat, List, Cause) |> left_join(nota_h, by = "Year") |>
         transmute(src = src, nivel = "nacional", cod = "00", anio = Year, causa = causa,
                   unidad = "Colombia", calidad = "observada", cobertura = "completa",
                   nota = cat_note("total = hombres + mujeres (la OMS publica por sexo)", paste0("OMS lista ", List, " causa ", Cause),
                                   if_else(Frmat == "01", "formato OMS 01: 1, 2, 3 y 4 años sumados en 1-4", NA), nh)))
}
r <- who_age(f_wd, "todas", "who_todas", \(x) rep(TRUE, nrow(x))); CORE$who_todas <- r$core; META$who_todas <- r$meta
wv <- read_csv(f_wv, show_col_types = FALSE)
cat("OMS violentas: grupos por año\n"); print(wv |> distinct(Year, group, List, Cause) |> summarise(g = paste(paste0(group, ":", List, "/", Cause), collapse = " "), .by = Year) |> as.data.frame())
r <- who_age(f_wv, "homicidio", "who_hom", \(x) x$group %in% c("violent", "homicide")); CORE$who_hom <- r$core; META$who_hom <- r$meta

# ---------------------------------------------------------------------------
# 5. LAMBdA (all causes) ====
# ---------------------------------------------------------------------------
cat("LAMBdA...\n")
lm <- read_tsv(paste0(H, "lambda_Col_Deathsm.txt"), show_col_types = FALSE); lf <- read_tsv(paste0(H, "lambda_Col_Deathsf.txt"), show_col_types = FALSE)
lam <- bind_rows(hombres = lm, mujeres = lf, .id = "sexo") |> mutate(a = if_else(Age == 999, NA_real_, pmin(Age, 85))) |>
  summarise(def = sum(Deaths), .by = c(Year, sexo, a))
sch <- lam |> filter(!is.na(a)) |> distinct(Year, a) |> arrange(Year, a) |> mutate(nxt = lead(a), .by = Year) |>
  mutate(edad_inicio = a, edad_fin = if_else(is.na(nxt), NA_real_, nxt - 1),
         edad = case_when(is.na(edad_fin) ~ paste0(edad_inicio, "+"), edad_inicio == edad_fin ~ as.character(edad_inicio),
                          TRUE ~ paste0(edad_inicio, "-", edad_fin)))
lam <- lam |> left_join(sch |> select(Year, a, edad, edad_inicio, edad_fin), by = c("Year", "a")) |>
  mutate(edad = if_else(is.na(a), "desconocida", edad))
lw <- lam |> select(Year, sexo, edad, edad_inicio, edad_fin, def) |> pivot_wider(names_from = sexo, values_from = def) |>
  mutate(total = if_else(!is.na(hombres) & !is.na(mujeres), hombres + mujeres, NA_real_)) |>
  pivot_longer(c(total, hombres, mujeres), names_to = "sexo", values_to = "def") |> filter(!is.na(def))
CORE$lambda <- lw |> transmute(src = "lambda", nivel = "nacional", cod = "00", anio = Year, causa = "todas", sexo, edad, edad_inicio, edad_fin, def)
lam_scheme <- sch |> summarise(grupos = paste(edad, collapse = " "), .by = Year) |> summarise(anios = rngs(Year), n = n(), .by = grupos)
cat("LAMBdA age schemes:\n"); print(as.data.frame(lam_scheme))
META$lambda <- lw |> distinct(Year) |> transmute(src = "lambda", nivel = "nacional", cod = "00", anio = Year, causa = "todas", unidad = "Colombia",
  calidad = "observada", cobertura = "completa",
  nota = "grupos de edad tal como los publica LAMBdA (85, 90, 95+ unidos en 85+; 999 = desconocida); no se verificó si LAMBdA corrige subregistro; total = hombres + mujeres")
# LAMBdA cause file: is homicide separable? (report only)
lc <- bind_rows(m = read_tsv(paste0(H, "lambda_Col_Cause19_Deathsm.txt"), show_col_types = FALSE),
                f = read_tsv(paste0(H, "lambda_Col_Cause19_Deathsf.txt"), show_col_types = FALSE), .id = "sx")
wc <- read_csv(paste0(R, "who_causes_age_colombia_1953-1977.csv"), show_col_types = FALSE)
lam_ext <- lc |> filter(Year == 1977, sx == "m", age %in% c(0, 1, seq(5, 80, 5))) |> arrange(age)
who_ext <- wc |> filter(Year == 1977, Sex == 1, List == "08A", Cause %in% sprintf("A%d", 138:149)) |>
  summarise(across(c(Deaths2, Deaths3, Deaths7:Deaths22), \(v) sum(v, na.rm = TRUE)))
lam_cols <- grep("^Cause_", names(lc), value = TRUE)
lam_ext_eq <- lam_cols[map_lgl(lam_cols, \(k) isTRUE(all(lam_ext[[k]] == unlist(who_ext))))]
cat("LAMBdA cause groups equal to WHO external causes (A138-A149), 1977 men:", paste(lam_ext_eq, collapse = ", "), "\n")

# ---------------------------------------------------------------------------
# assemble, flag sex inconsistencies ====
# ---------------------------------------------------------------------------
cat("assemble...\n")
SRC <- tribble(
  ~src, ~rank, ~fuente_id, ~archivo,
  "eevv", 1, "dane_eevv", f_ev,
  "reg_c11", 2.0, "dane_registro_def_1970_1978", f_c11,
  "reg_c3", 2.05, "dane_registro_def_1970_1978", f_c3,
  "reg_c6", 2.1, "dane_registro_def_1970_1978", f_c6,
  "reg_c6t", 2.2, "dane_registro_def_1970_1978", f_c6,
  "ane_6567", 3.1, "dane_anuarios", f_b,
  "ane_6869", 3.2, "dane_anuarios", f_a,
  "who_todas", 5, "who_mdb", f_wd,
  "who_hom", 5, "who_mdb", f_wv,
  "lambda", 6, "lambda", paste0(H, "lambda_Col_Deaths{m,f}.txt"))
K <- c("src", "nivel", "cod", "anio", "causa")
CORE <- bind_rows(CORE) |> mutate(anio = as.integer(anio))
META <- bind_rows(META) |> mutate(anio = as.integer(anio))
ALLP <- bind_rows(ALLP) |> mutate(anio = as.integer(anio))
stopifnot(!anyDuplicated(META[, K]), !anyNA(META$cobertura))
dk <- CORE |> count(across(all_of(c(K, "sexo", "edad")))) |> filter(n > 1)
if (nrow(dk)) { print(head(dk, 20)); cat("WARNING: duplicate age cells inside sources:", nrow(dk), "\n") }
# total = hombres + mujeres per source group (as phase 1): sex rows are 'parcial' when the sexes do not add to the total
sexdif <- CORE |> summarise(dif = sum(def[sexo == "total"]) - sum(def[sexo == "hombres"]) - sum(def[sexo == "mujeres"]),
                            has = all(c("total", "hombres", "mujeres") %in% sexo), .by = all_of(K)) |> filter(has, dif != 0) |> select(-has)
cat("source groups with sexes not adding to the total:", nrow(sexdif), "\n")

# ---------------------------------------------------------------------------
# selection ====
# ---------------------------------------------------------------------------
Cd <- CORE |> filter(sexo == "total") |>
  summarise(ng = n_distinct(edad[edad != "desconocida"]), tot = sum(def), .by = all_of(K)) |>
  left_join(SRC |> select(src, rank), by = "src") |>
  mutate(demote = src == "eevv" & anio == 1979L & !(causa == "homicidio" & nivel == "departamental"))
win <- Cd |> arrange(demote, -ng, rank) |> slice(1, .by = c(nivel, cod, anio, causa)) |> select(nivel, cod, anio, causa, src_sel = src)
CORE <- CORE |> left_join(win, by = c("nivel", "cod", "anio", "causa")) |> mutate(elegida = src == src_sel) |> select(-src_sel)
cat("rows:", nrow(CORE), " chosen:", sum(CORE$elegida), "\n")

cols <- c("nivel", "cod", "unidad", "anio", "causa", "sexo", "edad", "edad_inicio", "edad_fin", "def_registradas", "fuente_id", "archivo",
          "calidad", "cobertura", "nota")
finish <- function(d) {
  d |> left_join(META, by = K) |> left_join(SRC |> select(src, fuente_id, archivo), by = "src") |>
    left_join(sexdif, by = K) |>
    mutate(sx = sexo %in% c("hombres", "mujeres") & !is.na(dif),
           cobertura = if_else(sx, "parcial", cobertura),
           nota = if_else(sx, cat_note(nota, paste0("hombres + mujeres difiere del total en ", dif, " (total publicado conservado)")), nota)) |>
    rename(def_registradas = def) |> select(all_of(cols), elegida, src)
}
ord <- function(d) d |> arrange(match(nivel, lvl_ord), cod, anio, causa, sexo, edad_inicio, edad)
T1 <- finish(CORE |> filter(elegida)) |> ord()
stopifnot(!anyNA(T1$cobertura), !anyNA(T1$unidad))
cat("table 1:", nrow(T1), "rows\n")
wr <- function(d, f) { write_csv(d, gzfile(paste0(od, "/", f)), na = ""); round(file.size(paste0(od, "/", f)) / 1e6, 2) }
out_files <- list()
sz_all <- wr(T1 |> select(all_of(cols)), "mortalidad_colombia_edad.csv.gz")
split_mun <- sz_all > MAX_MB
if (split_mun) {
  cat("single file", sz_all, "MB >", MAX_MB, ": municipal rows to a separate file\n")
  out_files$t1 <- wr(T1 |> filter(nivel != "municipal") |> select(all_of(cols)), "mortalidad_colombia_edad.csv.gz")
  out_files$t1m <- wr(T1 |> filter(nivel == "municipal") |> select(all_of(cols)), "mortalidad_colombia_edad_municipal.csv.gz")
} else {
  out_files$t1 <- sz_all
  if (file.exists(paste0(od, "/mortalidad_colombia_edad_municipal.csv.gz"))) file.remove(paste0(od, "/mortalidad_colombia_edad_municipal.csv.gz"))
}
TF <- finish(CORE) |> ord() |> relocate(elegida, .after = nota)
# municipal has a single source (EEVV): its source rows equal table 1; kept in the sources file only if the file fits
sz_f <- wr(TF |> select(-src), "mortalidad_colombia_edad_fuentes.csv.gz")
fuentes_con_mun <- sz_f <= MAX_MB
if (!fuentes_con_mun) { cat("sources file with municipal", sz_f, "MB: municipal left out (single source, equal to table 1)\n")
  sz_f <- wr(TF |> filter(nivel != "municipal") |> select(-src), "mortalidad_colombia_edad_fuentes.csv.gz") }
out_files$tf <- sz_f
cat("sources table:", nrow(TF), "rows\n")

# ---------------------------------------------------------------------------
# verification ====
# ---------------------------------------------------------------------------
cat("verification...\n")
V <- list(); DET <- list()
addv <- function(check, n, n_failing, note) { V[[length(V) + 1]] <<- tibble(check = check, n = n, n_failing = n_failing, note = note)
  cat(sprintf("%-75s n=%-8s fail=%-6s %s\n", check, n, n_failing, str_trunc(note, 220))) }
# (1)
dk <- T1 |> count(nivel, cod, unidad, anio, causa, sexo, edad, edad_inicio, edad_fin) |> filter(n > 1)
addv("1 clave única (nivel,cod,unidad,anio,causa,sexo,edad,edad_inicio,edad_fin)", nrow(T1), nrow(dk), "")
dk2 <- T1 |> count(nivel, cod, anio, causa, sexo, edad) |> filter(n > 1)
addv("1b clave única (nivel,cod,anio,causa,sexo,edad)", nrow(T1), nrow(dk2), "")
# (2) sum over ages vs phase 1
P1 <- read_csv(paste0(od, "/mortalidad_colombia_fuentes.csv.gz"), show_col_types = FALSE, col_types = cols(.default = "c")) |>
  filter(sexo == "total") |>
  transmute(nivel, cod, anio = as.integer(anio), causa, def1 = as.numeric(def_registradas), fuente_id1 = fuente_id, archivo1 = archivo, elegida1 = elegida == "TRUE")
sumages <- CORE |> filter(sexo == "total") |> summarise(suma = sum(def), .by = all_of(c(K, "elegida"))) |>
  left_join(SRC |> select(src, fuente_id, archivo), by = "src")
pm <- sumages |> inner_join(P1, by = c("nivel", "cod", "anio", "causa"), relationship = "many-to-many") |>
  filter(fuente_id == fuente_id1,
         case_when(fuente_id == "dane_anuarios" ~ archivo == archivo1,
                   fuente_id == "dane_registro_def_1970_1978" ~ str_detect(archivo1, "cuadro02"),
                   TRUE ~ TRUE)) |>
  mutate(rel = (suma - def1) / def1, igual = suma == def1)
DET$sumas <- pm |> transmute(src, nivel, cod, anio, causa, suma_edades = suma, total_fase1 = def1, rel_dif = rel, igual,
                             elegida_edad = elegida, elegida_fase1 = elegida1)
pm_same <- pm |> filter(elegida1)
addv("2 suma de edades = total fase 1 (misma fuente elegida en fase 1)", nrow(pm_same), sum(!pm_same$igual),
     paste0("la suma incluye edad desconocida y sexo no registrado. Fallan: ",
            paste(head(paste(pm_same$src[!pm_same$igual], pm_same$nivel[!pm_same$igual], pm_same$cod[!pm_same$igual], pm_same$anio[!pm_same$igual], pm_same$causa[!pm_same$igual], round(pm_same$rel[!pm_same$igual], 4)), 12), collapse = "; ")))
pm_oth <- pm |> filter(!elegida1)
for (s in unique(pm_oth$src)) { x <- pm_oth |> filter(src == s)
  addv(paste0("2 suma de edades vs total fase 1 (fuente no elegida en fase 1), ", s), nrow(x), sum(!x$igual),
       paste0("máx |dif rel| ", round(max(abs(x$rel)), 4), "; media ", round(mean(abs(x$rel)), 4), "; años con dif: ", rngs(x$anio[!x$igual]))) }
miss1 <- sumages |> anti_join(P1, by = c("nivel", "cod", "anio", "causa"))
addv("2 celdas con edad sin contraparte alguna en fase 1 (nivel,cod,año,causa)", nrow(sumages), nrow(miss1),
     paste(count(miss1, src, causa) |> mutate(x = paste0(src, "/", causa, ":", n)) |> pull(x), collapse = " "))
p1ev <- P1 |> filter(fuente_id1 == "dane_eevv", def1 > 0) |> anti_join(sumages |> filter(src == "eevv"), by = c("nivel", "cod", "anio", "causa"))
addv("2 celdas EEVV con defunciones en fase 1 y sin filas de edad", sum(P1$fuente_id1 == "dane_eevv" & P1$def1 > 0), nrow(p1ev), "")
# 2b sum of ages vs 'all' row published in the same source
ap <- ALLP |> inner_join(CORE |> summarise(suma = sum(def), .by = all_of(c(K, "sexo"))), by = c(K, "sexo")) |> mutate(dif = suma - publicado)
for (s in unique(ap$src)) { x <- ap |> filter(src == s)
  addv(paste0("2b suma de edades = fila 'all' publicada por la misma fuente, ", s), nrow(x), sum(x$dif != 0),
       if (any(x$dif != 0)) paste0("máx |dif| ", max(abs(x$dif)), "; ", paste(head(paste(x$nivel, x$cod, x$anio, x$causa, x$sexo, x$dif)[x$dif != 0], 6), collapse = "; ")) else "") }
DET$all_publicada <- ap |> filter(dif != 0)
# 2c cuadro 10 (menores de 5) vs cuadro 11
c10l <- c10 |> mutate(cod = case_when(unit == "Total nacional" ~ "00", unit == "Intendencias y comisarías" ~ "TN", TRUE ~ cod_dpto)) |>
  transmute(cod, anio, age, total)
c11b <- CORE |> filter(src == "reg_c11", sexo == "total", edad %in% c("0", "1-4")) |> select(cod, anio, edad, def)
x10 <- c10l |> filter(age %in% c("under 1", "1-4")) |> mutate(edad = if_else(age == "under 1", "0", "1-4")) |> inner_join(c11b, by = c("cod", "anio", "edad")) |> mutate(dif = def - total)
addv("2c cuadro 11 (0 y 1-4) = cuadro 10 (menores de 5)", nrow(x10), sum(x10$dif != 0), paste(head(paste(x10$cod, x10$anio, x10$edad, x10$dif)[x10$dif != 0], 6), collapse = "; "))
x3 <- CORE |> filter(src %in% c("reg_c3", "reg_c11"), nivel == "nacional") |> select(src, anio, sexo, edad, def) |> pivot_wider(names_from = src, values_from = def) |> filter(!is.na(reg_c3), !is.na(reg_c11))
addv("2d cuadro 3 = cuadro 11 (nacional, por edad y sexo)", nrow(x3), sum(x3$reg_c3 != x3$reg_c11), "")
x6 <- CORE |> filter(src %in% c("reg_c6t", "reg_c11"), nivel == "nacional") |> select(src, anio, sexo, edad, def) |> pivot_wider(names_from = src, values_from = def) |> filter(!is.na(reg_c6t), !is.na(reg_c11))
addv("2e cuadro 6 (fila TOTAL) = cuadro 11 (nacional, por edad y sexo)", nrow(x6), sum(x6$reg_c6t != x6$reg_c11), paste(head(paste(x6$anio, x6$sexo, x6$edad)[x6$reg_c6t != x6$reg_c11], 6), collapse = "; "))
# (3) male + female = total (cells in the table; implicit zeros at municipal level)
w3 <- T1 |> select(nivel, cod, anio, causa, edad, edad_inicio, sexo, v = def_registradas, cobertura) |>
  pivot_wider(names_from = sexo, values_from = c(v, cobertura)) |>
  mutate(across(c(v_hombres, v_mujeres), \(x) replace_na(x, 0))) |> filter(!is.na(v_total))
f3 <- w3 |> filter(v_total != v_hombres + v_mujeres)
addv("3 total = hombres + mujeres (por celda de edad; sexo ausente = 0 en municipal)", nrow(w3), nrow(f3),
     paste0("fallan: ", sum(f3$nivel == "nacional"), " nacional, ", sum(f3$nivel == "departamental"), " departamental, ", sum(f3$nivel == "municipal"),
            " municipal (sexo no registrado en EEVV, desde ", min(f3$anio), "); filas de sexo marcadas parcial en ",
            sum(f3$cobertura_hombres == "parcial", na.rm = TRUE), " de ellas"))
DET$sexos_no_suman <- f3 |> select(nivel, cod, anio, causa, edad, v_total, v_hombres, v_mujeres)
# (4) homicidio <= todas by age group
w4 <- T1 |> select(nivel, cod, anio, sexo, edad, causa, v = def_registradas) |> pivot_wider(names_from = causa, values_from = v) |>
  filter(!is.na(todas), !is.na(homicidio))
f4 <- w4 |> filter(homicidio > todas)
nh <- T1 |> filter(causa == "homicidio") |> distinct(nivel, cod, anio, edad); nt <- T1 |> filter(causa == "todas") |> distinct(nivel, cod, anio, edad)
sincomp <- nrow(anti_join(nh, nt, by = c("nivel", "cod", "anio", "edad")))
addv("4 homicidio <= todas por grupo de edad", nrow(w4), nrow(f4),
     paste0(sincomp, " celdas de homicidio sin grupo de edad igual en 'todas' (fuentes con distinto detalle); fallan: ",
            paste(head(paste(f4$nivel, f4$cod, f4$anio, f4$sexo, f4$edad), 8), collapse = "; ")))
DET$homicidio_mayor <- f4
# (5) overlaps by broad group
broad <- function(ini, fin) case_when(is.na(ini) ~ NA_character_, ini >= 65 ~ "65+", ini >= 45 & !is.na(fin) & fin <= 64 ~ "45-64",
                                      ini >= 15 & !is.na(fin) & fin <= 44 ~ "15-44", ini >= 5 & !is.na(fin) & fin <= 14 ~ "5-14",
                                      !is.na(fin) & fin <= 4 ~ "0-4", TRUE ~ NA_character_)
cmp_broad <- function(sa, sb, causa_, label) {
  g <- \(s) CORE |> filter(src == s, causa == causa_, nivel == "nacional", edad != "desconocida") |>
    mutate(b = broad(edad_inicio, edad_fin)) |> mutate(ok = !anyNA(b), .by = c(anio)) |> filter(ok) |>
    summarise(v = sum(def), .by = c(anio, sexo, b))
  j <- inner_join(g(sa), g(sb), by = c("anio", "sexo", "b"), suffix = c("_a", "_b")) |>
    mutate(rel = (v_a - v_b) / pmax(v_b, 1), absd = v_a - v_b)
  DET[[label]] <<- j |> mutate(comparacion = label)
  if (!nrow(j)) { addv(paste0("5 ", label), 0, 0, "sin años en común"); return(invisible()) }
  jj <- j |> filter(sexo == "total", v_b >= 100)
  addv(paste0("5 ", label), nrow(j), sum(abs(j$rel) > 0.05 & pmax(j$v_a, j$v_b) >= 100),
       paste0("n_failing = celdas con |dif rel| > 5% y >= 100 def.; máx |dif rel| (sexo total, >= 100 def.) ", round(max(abs(jj$rel)), 4),
              " (", jj$anio[which.max(abs(jj$rel))], " ", jj$b[which.max(abs(jj$rel))], "); máx |dif| absoluta ", max(abs(j$absd)),
              "; años ", rngs(j$anio)))
}
addv("5 OMS vs EEVV, años en común", length(intersect(CORE$anio[CORE$src == "who_todas"], CORE$anio[CORE$src == "eevv"])), 0,
     "la OMS termina en 1977 y las EEVV con edad empiezan en 1979: no hay años en común")
cmp_broad("who_todas", "reg_c11", "todas", "OMS vs Registro 1970-1977, todas, por grupo amplio")
cmp_broad("who_hom", "reg_c6", "homicidio", "OMS vs Registro cuadro 6, homicidio, por grupo amplio")
cmp_broad("lambda", "eevv", "todas", "LAMBdA vs EEVV nacional 1979-2015, todas, por grupo amplio")
cmp_broad("lambda", "who_todas", "todas", "LAMBdA vs OMS 1953-1977, todas, por grupo amplio")
cmp_broad("lambda", "reg_c11", "todas", "LAMBdA vs Registro 1970-1978, todas, por grupo amplio")
cmp_broad("who_todas", "ane_6567", "todas", "OMS vs anuarios 1965-1967, todas, por grupo amplio")
cmp_broad("who_todas", "ane_6869", "todas", "OMS vs anuarios 1968-1969, todas, por grupo amplio")
cmp_broad("reg_c6", "eevv", "homicidio", "Registro 1973-1978 vs EEVV, homicidio (sin años comunes)")
# (5b) national = sum of departments, by age
nd <- T1 |> filter(sexo == "total", edad != "desconocida", nivel != "municipal") |>
  summarise(v = sum(def_registradas), .by = c(nivel, anio, causa, edad)) |>
  pivot_wider(names_from = nivel, values_from = v) |> filter(!is.na(nacional), !is.na(departamental)) |>
  mutate(rel = (departamental - nacional) / pmax(nacional, 1))
nd_y <- nd |> summarise(nac = sum(nacional), dep = sum(departamental), .by = c(anio, causa)) |> mutate(rel_total = (dep - nac) / nac)
DET$nac_vs_dep <- nd_y
addv("5b nacional = suma de departamentos, por edad (sexo total)", nrow(nd), sum(abs(nd$rel) > 0.01 & nd$nacional >= 100),
     paste0("n_failing = celdas (año, causa, edad) con |dif| > 1% y >= 100 def.; años con |dif| > 0,5% en el total de edades: ",
            rngs(nd_y$anio[abs(nd_y$rel_total) > 0.005]), "; máx |dif| ", round(max(abs(nd_y$rel_total)), 4)))
# (6) coverage by nivel x causa; compare with the inventory
cy <- T1 |> summarise(filas = n(), grupos = n_distinct(edad[sexo == "total" & edad != "desconocida"]), .by = c(nivel, causa, anio, src))
cov <- cy |> summarise(anios = rngs(anio), n_anios = n(), filas = sum(filas), grupos_min = min(grupos), grupos_max = max(grupos), .by = c(nivel, causa, src)) |>
  arrange(match(nivel, lvl_ord), causa, anios)
write_csv(cov, paste0(od, "/verification_edad_cobertura.csv"), na = "")
av <- read_csv("output/tables/data_availability_information.csv", show_col_types = FALSE) |>
  filter(dominio %in% c("Defunciones", "Homicidios y violencia"), detalle == "Edad y sexo") |>
  transmute(nivel = tolower(nivel), causa = if_else(dominio == "Defunciones", "todas", "homicidio"), anio = year, agregado, agregable)
have <- T1 |> distinct(nivel, causa, anio) |> mutate(en_tabla = TRUE)
j6 <- full_join(av |> mutate(en_inventario = TRUE), have, by = c("nivel", "causa", "anio"))
m1 <- j6 |> filter(!is.na(en_inventario), is.na(en_tabla)); m2 <- j6 |> filter(is.na(en_inventario), !is.na(en_tabla))
write_csv(bind_rows(m1 |> mutate(sentido = "en inventario (Edad y sexo), falta en tabla de edad"), m2 |> mutate(sentido = "en tabla de edad, no en inventario como Edad y sexo")) |>
            select(sentido, nivel, causa, anio, agregado, agregable), paste0(od, "/verification_edad_cobertura_inventario.csv"), na = "")
fmt <- \(d) if (nrow(d)) paste(d |> summarise(a = paste0(nivel[1], "/", causa[1], ": ", rngs(anio)), .by = c(nivel, causa)) |> pull(a), collapse = " | ") else "ninguno"
addv("6 inventario 'Edad y sexo' sin filas de edad en la tabla", nrow(av), nrow(m1), fmt(m1))
addv("6 filas de edad en la tabla que el inventario no lista como 'Edad y sexo'", nrow(have), nrow(m2), fmt(m2))
# (7) row counts
rc <- T1 |> mutate(decada = paste0(anio %/% 10 * 10, "s")) |> count(nivel, causa, decada) |> arrange(match(nivel, lvl_ord), causa, decada)
write_csv(rc, paste0(od, "/verification_edad_filas_por_decada.csv"), na = "")
addv("7 filas por nivel y causa (por década: verification_edad_filas_por_decada.csv)", nrow(T1), 0,
     paste(rc |> summarise(a = paste0(nivel[1], "/", causa[1], ":", sum(n)), .by = c(nivel, causa)) |> pull(a), collapse = " | "))
addv("7b filas en fuentes (todas las fuentes)", nrow(TF), 0, paste(count(TF, nivel) |> mutate(x = paste0(nivel, ":", n)) |> pull(x), collapse = " | "))
VV <- bind_rows(V)
write_csv(VV, paste0(od, "/verification_edad.csv"), na = "")
write_csv(bind_rows(lapply(names(DET), \(n) DET[[n]] |> mutate(across(everything(), as.character)) |> mutate(detalle = n, .before = 1))),
          paste0(od, "/verification_edad_detalle.csv"), na = "")
cat("verification done\n")

# ---------------------------------------------------------------------------
# dictionary ====
# ---------------------------------------------------------------------------
cat("dictionary...\n")
src_lab <- c(eevv = "EEVV microdatos (`dane_eevv`)", reg_c11 = "Registro 1970-1978, cuadro 11 (`dane_registro_def_1970_1978`)",
             reg_c3 = "Registro 1970-1978, cuadro 3", reg_c6 = "Registro 1970-1978, cuadro 6 (causa 148)", reg_c6t = "Registro 1970-1978, cuadro 6 (fila TOTAL)",
             ane_6567 = "Anuarios DANE 1965-1967 (`dane_anuarios`)", ane_6869 = "Anuarios DANE 1968-1969 (`dane_anuarios`)",
             who_todas = "OMS, todas las causas (`who_mdb`)", who_hom = "OMS, homicidio (`who_mdb`)", lambda = "LAMBdA (`lambda`)")
mdt <- function(d) c(paste0("| ", paste(names(d), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
                     apply(d, 1, \(r) paste0("| ", paste(replace_na(as.character(r), ""), collapse = " | "), " |")))
f1 <- function(x) format(x, big.mark = " ", scientific = FALSE, trim = TRUE)
cov_md <- cov |> transmute(nivel, causa, fuente = unname(src_lab[src]), años = anios, `n años` = n_anios, filas = f1(filas),
                           `grupos de edad (mín-máx)` = if_else(grupos_min == grupos_max, as.character(grupos_max), paste0(grupos_min, "-", grupos_max)))
fu_md <- TF |> summarise(años = rngs(anio), filas = n(), `filas elegidas` = sum(elegida), .by = src) |>
  transmute(variante = src, fuente = unname(src_lab[src]), años, filas = f1(filas), `filas elegidas` = f1(`filas elegidas`))
vv_md <- VV |> transmute(check, n = f1(n), n_failing = f1(n_failing))
ev_unk <- T1 |> filter(fuente_id == "dane_eevv", nivel == "nacional", sexo == "total", causa == "todas") |>
  summarise(desc = sum(def_registradas[edad == "desconocida"]), tot = sum(def_registradas), .by = anio) |> mutate(p = desc / tot)
fmt_mb <- \(x) paste0(x, " MB")
md <- c(
  "# Mortalidad registrada en Colombia por edad, 1926-2023 (fase 2)",
  "",
  paste0("Defunciones **registradas** (no ajustadas, no imputadas, sin repartir los grupos de edad gruesos) por causa (todas, homicidio), sexo (total, ",
         "hombres, mujeres), grupo de edad y nivel geográfico (nacional, departamental, municipal). Extiende la fase 1 (`diccionario.md`) con edad; ",
         "mismas convenciones de `cod`, unidades, `calidad`, `cobertura`, causas y orden de prioridad de fuentes. Generado por ",
         "`code/61_build_mortality_database_age.R` a partir de los archivos ya extraídos del proyecto. No duplica la fase 1: solo contiene filas de edad ",
         "(la fila de edad `total` está en `mortalidad_colombia.csv.gz`)."),
  "",
  "## Archivos",
  "",
  "| archivo | contenido | filas | tamaño |",
  "|---|---|---|---|",
  paste0("| `mortalidad_colombia_edad.csv.gz` | una fuente por (nivel, cod, año, causa), la mejor según la regla de abajo",
         if (split_mun) " (nacional y departamental; el municipal está en el archivo siguiente por tamaño)" else " (nacional, departamental y municipal)",
         " | ", f1(sum(T1$nivel != "municipal" | !split_mun)), " | ", fmt_mb(out_files$t1), " |"),
  if (split_mun) paste0("| `mortalidad_colombia_edad_municipal.csv.gz` | filas municipales de la tabla anterior | ", f1(sum(T1$nivel == "municipal")), " | ", fmt_mb(out_files$t1m), " |"),
  paste0("| `mortalidad_colombia_edad_fuentes.csv.gz` | todas las fuentes sin armonizar entre sí, mismas columnas más `elegida` (TRUE = la fila pasó a la tabla de edad)",
         if (!fuentes_con_mun) "; **no incluye el nivel municipal**: la única fuente municipal con edad son las EEVV, de modo que sus filas son idénticas a las de la tabla de edad" else "",
         " | ", f1(if (fuentes_con_mun) nrow(TF) else sum(TF$nivel != "municipal")), " | ", fmt_mb(out_files$tf), " |"),
  "| `verification_edad.csv` | controles (check, n, n_failing, note); detalle en `verification_edad_detalle.csv`, `verification_edad_cobertura.csv`, `verification_edad_cobertura_inventario.csv`, `verification_edad_filas_por_decada.csv` | | |",
  "",
  "## Columnas",
  "",
  "Las de la fase 1 (`nivel`, `cod`, `unidad`, `anio`, `causa`, `sexo`, `def_registradas`, `fuente_id`, `archivo`, `calidad`, `cobertura`, `nota`; `cod` y `unidad` como en `unidades_colombia.csv`) más:",
  "",
  "| columna | definición |",
  "|---|---|",
  "| edad | etiqueta del grupo: `0`, `1-4`, `5-9`, ..., `80-84`, `85+`; grupos más gruesos tal como los publica la fuente (p. ej. `40-49`, `70+`, `80+`); `desconocida` = edad no declarada |",
  "| edad_inicio | primera edad cumplida del grupo (0 = menores de 1 año). NA solo en `desconocida` |",
  "| edad_fin | **última edad cumplida incluida** en el grupo (`5-9` -> 5 y 9; `1-4` -> 1 y 4; `0` -> 0 y 0). NA para el grupo abierto (`85+`, `80+`, `70+`) y para `desconocida` |",
  "",
  "## Convenciones de edad",
  "",
  "- Grupos estándar (19): `0`, `1-4`, `5-9`, `10-14`, ..., `80-84`, `85+`. Es el detalle de las EEVV 1979-2023, el Registro 1970-1978, los anuarios 1965-1969 y la OMS 1953-1977.",
  "- **El grupo `0` es de menores de 1 año.** Las fuentes con detalle de la infancia (menores de 1 día, 1-6 días, 7-29 días, 1-5 meses, 6-11 meses) se suman en `0`; `12-23 meses` + `2-4 años` se suman en `1-4` (Registro 1970-1978 y anuarios 1968-1969). El anuario 1965-1967 publica `menores de 1 año` y `1-4`. La OMS formato 02 publica `0` y `1-4`; el formato 01 (1967, 1968) publica 1, 2, 3 y 4 años por separado y se suman en `1-4`. Cada fila lo documenta en `nota`.",
  "- Las EEVV agrupan 85 y más en `85+` (los microdatos desde 2008 traen 85-89, 90-94, 95-99 y 100+ y se unen en `85+`). LAMBdA publica 85, 90 y 95+ en los años recientes; se unen en `85+`.",
  "- **No se divide ningún grupo grueso.** LAMBdA usa grupos más gruesos en algunos años (ver abajo); se conservan tal como se publican, con su `edad_inicio`/`edad_fin`.",
  "- `desconocida`: 'not stated' de los cuadros DANE, edad vacía de las EEVV (cerca del 1% de las defunciones, sobre todo antes de 1998), 999 de LAMBdA, 'unspecified' de la OMS. Aparece solo si la fuente trae defunciones con edad desconocida (nacional y departamental: en las EEVV solo cuando hay alguna). La suma de todas las edades, incluida `desconocida`, es el total de la fase 1 de la misma fuente.",
  paste0("- Porcentaje nacional de edad desconocida en las EEVV (todas las causas): ", sprintf("%.1f%%", 100 * max(ev_unk$p[ev_unk$anio <= 1990])), " como máximo hasta 1990, ",
         sprintf("%.2f%%", 100 * max(ev_unk$p[ev_unk$anio >= 2010])), " como máximo desde 2010."),
  "",
  "## Regla de selección",
  "",
  "Por (nivel, cod, año, causa) se elige **una** fuente para todos los sexos y todas las edades (nunca se mezclan fuentes dentro de un grupo). Orden:",
  "1. el año corto EEVV 1979 se degrada por debajo de cualquier otra fuente con edad, como en la fase 1 (en la práctica no hay otra fuente con edad en 1979, de modo que se usa y queda `cobertura = parcial`);",
  "2. mayor detalle de edad (número de grupos de edad tras armonizar: 5 años sobre grueso);",
  "3. prioridad de la fase 1: EEVV > Registro de defunciones 1970-1978 (cuadro 11, luego cuadro 3, luego cuadro 6) > anuarios 1965-1969 > OMS > LAMBdA.",
  "",
  "Los municipios solo tienen una fuente con edad (EEVV). Los departamentos tienen EEVV (1979-2023), Registro (1970-1978), anuarios (1965-1969). Las intendencias y comisarías se conservan agrupadas (`TN`) cuando la fuente las publica así (anuarios 1965-1967 y Registro 1970-1978), como en la fase 1; en 1968-1969 los anuarios las publican por separado.",
  "",
  "## Cobertura (años y detalle de edad por nivel, causa y fuente elegida)",
  "",
  mdt(cov_md),
  "",
  paste0("Detalle de edad de LAMBdA (única fuente nacional de todas las causas antes de 1953): ",
         paste(paste0("`", lam_scheme$grupos, "` en ", lam_scheme$anios), collapse = "; "),
         ". LAMBdA no tiene datos en 1929-1935, 1972 ni 1976-1981; en 1950-1971, 1973-1975 y 1982-2015 existe pero no se elige porque hay OMS, Registro o EEVV (solo se elige en 1926-1928 y 1936-1952)."),
  "",
  "Años con edad en el inventario (`output/tables/data_availability_information.csv`, detalle 'Edad y sexo'): todos los años listados tienen filas en la tabla (`verification_edad.csv`, control 6). La tabla tiene dos años que el inventario no lista como 'Edad y sexo': homicidio nacional 1973 y 1978 (Registro cuadro 6).",
  "",
  "## Fuentes cargadas (`_fuentes`)",
  "",
  mdt(fu_md),
  "",
  "## Definición de homicidio por fuente",
  "",
  "- EEVV 1979-2023: código 101 de la Lista 105 de DANE (agresiones; CIE-9 E960-E969, CIE-10 X85-Y09); no incluye intención indeterminada ni intervención legal. Igual que la fase 1.",
  "- Registro 1970-1978, cuadro 6 (1973-1978): categoría 148 de la CIE-8 lista A, 'homicidio y lesiones provocadas intencionalmente por otras personas; intervención legal'. **Incluye intervención legal** (no coincide con el código 101).",
  "- OMS 1968-1977: CIE-8 lista A categoría 148 (la misma definición del Registro; en los años comunes 1974-1977 las cifras son idénticas). OMS 1953-1967: CIE-7 lista A categoría 149, 'homicidio y operaciones de guerra' (grupo `violent` del archivo `who_violent_age_colombia_1953-1977.csv`). La categoría 149 de la CIE-8 (intención indeterminada) **no** se usa.",
  "- Los años 1970, 1971 no tienen homicidio por edad en ninguna fuente (la OMS no los publica y el cuadro 6 empieza en 1973). 1973 y 1978 vienen solo del cuadro 6 del Registro.",
  "- LAMBdA por causas (`lambda_Col_Cause19_Deaths{m,f}.txt`): el homicidio **no es separable**. El grupo de causas externas (`Cause_18` en los archivos; coincide por edad con la suma de las categorías A138-A149 de la OMS en 1977, hombres) junta accidentes, suicidio, homicidio e intención indeterminada. No se usa.",
  "- Muertes violentas por departamento 1951-1964 (`dane_causas_violentas_dept_1951_1964.csv`): traen sexo pero no edad; no entran en esta fase.",
  "",
  "## Vacíos conocidos y decisiones",
  "",
  "- **Homicidio por edad**: nacional 1953-1969, 1972-1978 y 1979-2023 (faltan 1970 y 1971); departamental y municipal solo 1979-2023. No hay homicidio por edad departamental antes de 1979.",
  "- **Todas las causas por edad**: nacional 1926-1928, 1936-2023 (faltan 1929-1935; LAMBdA, con grupos de edad gruesos en 1926-1949); departamental 1965-2023 (anuarios 1965-1969, Registro 1970-1978, EEVV 1979-2023); municipal 1979-2023. Para 1958-1960 hay municipios y departamentos (fase 1) pero **sin edad**.",
  "- **1979**: año corto de las EEVV. La fase 1 usa para el total 1979 la cifra del Registro (cuadro 1/2); el único origen con edad es la EEVV, de modo que la suma de edades 1979 es la de las EEVV (110 400 defunciones) y no coincide con el total 1979 de la fase 1. Las filas llevan `cobertura = parcial`. En 1980-2023 la suma de edades sí es el total de la fase 1.",
  "- **1978**: no existe en las EEVV; el Registro 1978 trae edad nacional y por sección, con los mismos totales que el cuadro 2 de la fase 1 (el total nacional de 1978, 124 613, es menor que el de 1977).",
  "- Registro por sección (cuadro 11): `cobertura` y `nota` heredan las marcas de subregistro (`*`, `**`) del cuadro 2 de la misma unidad-año.",
  "- Anuario 1968-1969: la fila `all` publicada difiere de la suma de las edades en el sexo (no en el total) de tres unidades-año: Bolívar 1968 (20), La Guajira 1968 (10) y Guainía 1969 (1), con hombres y mujeres transpuestos; se conservan las edades tal como están transcritas y el total publicado coincide. Cuadro 10 vs cuadro 11: difieren en `TN` 1976 (menores de 1 año -4, 1-4 +2); ver `verification_edad.csv`.",
  "- **Sexo no registrado** (EEVV desde 1998): el total incluye esas defunciones; hombres + mujeres es menor que el total en esas celdas; las filas de hombres y mujeres del grupo (unidad, año, causa) quedan `parcial` con nota, como en la fase 1.",
  if (MUN_FULL) "- **Municipal**: tabla completa con ceros explícitos para cada municipio-año presente en la fase 1 (19 grupos x 3 sexos x 2 causas)."
  else "- **Municipal**: solo se escriben las celdas con al menos una defunción (la ausencia de fila en un municipio-año que existe en la fase 1 equivale a 0); en nacional y departamental todas las celdas se escriben, con ceros explícitos.",
  "- **LAMBdA** no es un conteo de registro bruto: difiere de las cifras registradas de la OMS y del Registro en 1950-1975 (hasta 55% en 15-44 años en 1970) y de las EEVV en 1982-2015 (hasta 27% en 5-14 años en 1991); solo se usa donde no hay otra fuente nacional con edad. No se verificó si corrige subregistro.",
  "- **Unidades**: igual que la fase 1: 'Bogotá D.E.' del Registro y los anuarios es `11` Bogotá D.C.; 'Intendencias y comisarías' son `TN`; Quindío, Risaralda y Sucre aparecen como unidades separadas desde 1967 (anuarios) y en el Registro 1970-1978; en 1965-1966 están dentro de Caldas y Bolívar (nota).",
  "- Los años de las EEVV son años de registro y el lugar es de ocurrencia; el Registro y los anuarios, la sección donde se registró.",
  "",
  "## Controles (`verification_edad.csv`)",
  "",
  mdt(vv_md),
  "",
  "## Cómo reconstruir",
  "",
  "Desde la raíz del proyecto: `Rscript code/61_build_mortality_database_age.R` (requiere la salida de la fase 1; usa solo archivos ya extraídos; tarda unos minutos).")
md <- unlist(md[!vapply(md, is.null, logical(1))])
writeLines(md, paste0(od, "/diccionario_edad.md"), useBytes = TRUE)
cat("done\n")
