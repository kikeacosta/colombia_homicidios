# Inventario de datos de mortalidad: Colombia, niveles nacional, departamental y municipal

Estado al 2026-11-10. Rutas relativas a la raíz del proyecto (`C:\Users\kikep\gits\colombia_homicidios`).
`data_input/` contiene insumos originales o transcritos; `data_inter/` productos intermedios de los scripts;
`output/tables/` las series finales.

## 0. Vista rápida: disponibilidad por año, nivel geográfico y desagregación

![Disponibilidad de datos por año, nivel geográfico y desagregación](../figures/inventory/data_availability.png)

Una fila por fuente, agrupadas por nivel geográfico (nacional, departamental, municipal) y por
dominio (población, defunciones, homicidios y violencia, tablas de vida). El color marca el mayor
detalle disponible ese año: solo total, por sexo, edad y sexo, o edad, sexo y causa. Los tonos
claros son años de cobertura parcial: menos del 80 % de las unidades reportan (los homicidios
departamentales de los anuarios nunca pasan de 20 de 27 departamentos), año corto (EEVV 1979) o
concepto distinto (1943-1945, "muertes violentas accidentales"). WPP 2024 y las proyecciones DANE
se recortan en 2023 aunque lleguen a 2100 y 2042. Las filas marcadas "OCR" son los cuadros de los
censos 1938, 1951 y 1973 extraídos de los PDF (edad simple nacional 1938 y 1973; edad quinquenal
por departamento 1938 y 1951; población ajustada por cobertura 1973 por departamento), en
incorporación a `data_input/historical/census_tables/`.

La figura la produce `code/32_data_availability.R`; la tabla subyacente, con una fila por serie y
año, el detalle, la bandera de parcialidad, la proporción de unidades con dato y el archivo de
origen, es `output/tables/data_availability.csv`. Para las series transcritas (anuarios) los años
y la cobertura se calculan de los csv; las demás se declaran con su rango conocido.

Lo que la figura muestra de un vistazo:

- **Edad por debajo del nivel nacional solo existe desde 1979** (EEVV) y, para población, en los
  censos 1938 y 1951 recién extraídos y en las proyecciones DANE desde 1985.
- **Causa de muerte** empieza en 1953 (OMS, LAMBdA 19 causas) y es continua desde 1979; a nivel
  departamental y municipal solo con EEVV.
- **Homicidios departamentales 1966-1978** dependen de una sola fuente, la Policía Nacional, que
  es solo total.
- **Municipal antes de 1979**: 14 años de defunciones (1924-1960) y tres censos (1938, 1951,
  1964), todo sin edad. Para 1958-1960 la fila "DANE Estadística vital (OCR)" es la lectura
  verificada de la publicación original (defunciones totales y de menores de un año por sexo,
  bautizos, matrimonios), que sustituye a la transcripción para esos tres años.
- **Antes de 1923** solo hay población: censos 1905-1918, totales anuales de los anuarios y las
  tablas pivotales de LAMBdA.

## 1. Resumen: qué hay, por nivel y tipo

| Nivel | Defunciones todas las causas | Homicidios / muertes violentas | Población | Tablas de vida |
|---|---|---|---|---|
| **Nacional** | Totales por sexo 1923-1984 (anuarios DANE); por edad y sexo 1926-2015 (LAMBdA), 1953-1977 con causa (OMS), 1979-2023 (EEVV microdatos); WPP 2024 1950-2100 por edad simple, con componente de crisis separado | 1923-1965 (anuarios); 1953-1977 por edad (OMS A148/A149); 1962-2002 (Policía, suma de deptos); 1979-2023 por edad (EEVV); MSE JEP-CEV-HRDAG 1985-2018 por edad quinquenal; UCDP GED 1989-2024 | Censos 1905-2018; edad simple × sexo en los censos 1938 y 1973 (`census_tables`); anuarios 1905-1985; WPP 1950-2100 (población y fecundidad por edad simple); DANE 1985-2042 | LAMBdA 1x1 1950-2015 y abreviadas pivotales 1905-2008 (en Drive); WPP 2024 completas 1950-2100; DANE 1985-2020 |
| **Departamental** | Totales (y sexo cuando existe) 1915-1984 en tres particiones territoriales (v06); versión previa v01 1923-1984; 1979-2023 agregables desde EEVV municipal | 1923-1965 (anuarios, v02, 27 deptos); 1962-2002 Policía Nacional (40 jurisdicciones); 1979-2023 EEVV | Censos 1905, 1912, 1918, 1928, 1938, 1951, 1964, 1973 (v03); edad quinquenal × sexo en 1938 y 1951 y población ajustada por cobertura 1973 (`census_tables`); DANE 1985-2042 | DANE abreviadas departamentales 1985-2020 |
| **Municipal** | Totales por sexo en 14 años: 1924-1932, 1935-1936, 1958-1960 (v03, 850 municipios); 1958-1960 verificados contra los totales departamentales, con bautizos y defunciones de menores de un año por sexo (`dane_vitales_1958_1960`, 828-872 unidades); versión previa v01 1925-1960 (13 años); 1979-2023 por edad, sexo y causa (EEVV) | 1979-2023 EEVV (dx_v); estimaciones ajustadas 1985-2017 (`data_inter`) | Censos 1938, 1951, 1964 (v03, 881 municipios); DANE 1985-2042 por sexo y edad | ninguna (tasas por municipio 1985-2017 en `data_inter`) |

Huecos principales:

- **Municipal 1961-1978**: no hay defunciones municipales. Antes de 1979 nunca hay detalle por edad ni causa a nivel municipal.
- **Departamental por edad antes de 1979**: en defunciones la edad solo llega con EEVV; las series 1915-1984 son totales, con sexo parcial. En población, los censos 1938 y 1951 tienen edad quinquenal por departamento (`census_tables`); 1964 y 1973 no.
- **Homicidios departamentales 1966-1978**: solo la fuente policial (1962-2002) cubre ese tramo; los anuarios paran en 1965 y EEVV empieza en 1979.
- **Nacional sin causa en 1970, 1971, 1973 y 1978**: OMS no tiene causas esos años y EEVV no tiene 1978. Interpolados en el script 30.
- **Censos 1985-2018 sin ajuste de omisión por edad**: las conciliaciones DANE dan omisión total (1985 ~11 %, 1993 ~11,7 %, 2005 ~3,7 %, 2018 ~8,5 %) pero no se ha incorporado el perfil por edad y sexo.

## 2. Nivel nacional

### 2.1 Defunciones, todas las causas

| Archivo | Años | Detalle | Fuente | Notas | Scripts |
|---|---|---|---|---|---|
| `data_input/historical/col_gap_analysis_1920_1985_national_deaths_clean_v03.csv` | 1923-1984 (62 años con dato, 59 con sexo) | total, hombres, mujeres | Anuarios estadísticos DANE, suma de departamentos | Separador `;`. 1950 sin sexo. La caída de 1965 (178.372) a 1970 (134.895) es subregistro y cobertura, no mortalidad | hist/21; 22 (total del anuario) |
| `data_input/historical/lambda_Col_Deathsm.txt`, `lambda_Col_Deathsf.txt` | 1926-2015, 76 años (saltos antes de 1936, 1973 y 1982) | grupos de edad LAMBdA × sexo | LAMBdA (Palloni et al.), defunciones registradas | Coinciden con los anuarios año a año. Usadas para 1938-1952, 1971 y 1973 | 21, 22, 23, 25, 28 |
| `data_input/historical/lambda_Col_Cause19_Deathsm.txt`, `…Deathsf.txt` | 1953-2009 (50 años) | 19 grupos de causa × edad × sexo, CIE-7 a CIE-10 | LAMBdA | Incluye causas externas; no explotado todavía | ninguno |
| `data_input/who_mdb/morticd07.zip`, `morticd08.zip` (+ `mort_pop.zip`, `mort_availability.zip`, `mort_documentation.zip`) | Colombia 1953-1977 | lista A (CIE-7/8) × edad × sexo | WHO Mortality Database | Sin causas en 1970, 1971, 1973. Extractos en `data_input/reference/who_deaths_age_colombia_1953-1977.csv` y `data_inter/who_deaths_age_1953-1977.rds` | 21 |
| `data_input/micro/Defun1979.txt` … `Defun2023.txt` (45 archivos) | 1979-2023 | microdatos: municipio, sexo, edad, causa | DANE EEVV | 1978 no existe; 1979 corto (110.400 vs 125.925 del anuario). Diccionarios en `documents/metadata/` | 01, 02 → `data_inter/micro_1979_2023.rds`, `deaths_munic_1979-2023.rds`, `deaths_munic_age_1979-2023.rds` |
| `data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds` | 1950-2100 | mx y población, edad simple × sexo | UN WPP 2024 | Referencia de nivel adoptada (script 27) | 22-30 |
| `data_input/251208_MortalityCrises.zip` (803 MB, no público) → `data_input/reference/wpp2024_crises_colombia_{mx1_conflicts, mx1_crises, mx1_disasters, mx1_famine, mx1_covid, lt1_crises_free, events, country, cdr}.csv` | 1950-2023 | mx por edad simple y sexo, por tipo de crisis | UN Population Division, insumos de WPP 2024 | mx_total = mx_crises_free + mx_crises. Conflicto en Colombia ~53 k muertes 1985-2018 (UCDP/PRIO/PITF) y La Violencia 12 k/año 1950-56 (Valentino 2004) | 26 (extrae), 27 |
| `data_inter/deaths_age_annual_1938-2023.rds` | 1938-2023 | edad quinquenal × sexo | Ensamble LAMBdA (1938-52, 1971, 1973) + OMS + EEVV | Serie registrada de insumo al DDM y a la completitud | 22 → 23, 25, 27, 28 |

### 2.2 Homicidios y muertes violentas

| Archivo | Años | Detalle | Fuente | Notas | Scripts |
|---|---|---|---|---|---|
| `data_input/historical/archive_v01_v02/homicides_national_v02.csv` | 1923-1965 | total, hombres, mujeres, nº de deptos con dato | Anuarios DANE (suma departamental) | 1943-1945 usan el concepto "muertes violentas accidentales", no homicidio puro | ninguno (archivado; sustituido por col_gap_analysis) |
| `data_input/reference/who_violent_age_colombia_1953-1977.csv`, `data_inter/who_violent_age_1953-1977.rds` | 1953-1977 (sin 1970, 1971, 1973) | homicidio e intención no determinada × edad × sexo | WHO MDB (A149 en CIE-7; A148 + A149 en CIE-8) | Edad desconocida redistribuida | 21 → 30 |
| `data_inter/who_homicide_colombia.rds`, `who_all_cause_colombia.rds` | 1953-2023 (65 años con dato) | totales anuales | WHO MDB, extracto sin script productor | Convertir a csv bajo `data_input/reference/who/` antes de publicar | hist/20, hist/22 |
| `data_input/conflict/mse_national_age5_1985-2018.rds`, `data_inter/conflict_mse_age5_1985-2018.rds` | 1985-2018 (desapariciones hasta 2016) | homicidios y desapariciones del conflicto, edad quinquenal 0-4 … 95+, sexo | JEP-CEV-HRDAG, estimación por sistemas múltiples | 617 k homicidios, 127 k desapariciones. La edad desconocida está volcada en 0-4 y en 85-89 (hasta 1988), 90-94 (1989-93) y 95+ (1994-2000); se trata como desconocida y se redistribuye en 5-84 | 21, 23, 27 |
| `data_input/ucdp/GEDEvent_v25_1.csv`, `GEDEvent_v25_01_25_12.csv` (270 MB, no versionado) | 1989-2024 | eventos georreferenciados con muertes estimadas | UCDP GED v25.1 | Solo comparación | hist/22 |
| `data_input/historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx` (hoja `Tabla_ancha`) | 1962-2002 | 40 jurisdicciones policiales × año | Policía Nacional | Suma nacional derivable; concepto policial distinto del médico-legal | ninguno aún |

### 2.3 Población

| Archivo | Años | Detalle | Fuente | Scripts |
|---|---|---|---|---|
| `data_input/historical/col_gap_analysis_1920_1985_national_population_clean_v02.csv` | 1905-1985 (34 años con dato) | total | Anuarios DANE y censos | hist/21 |
| `data_input/historical/lambda_Col_Popm.txt`, `lambda_Col_Popf.txt` | censos 1912, 1918, 1928, 1938, 1951, 1964, 1973, 1985, 1993, 2005 | edad × sexo | LAMBdA | 21, 22 |
| `data_input/census_raw/undata_t22`, `undata_t44`; `data_input/reference/undata_census_colombia.csv`, `undata_foreign_born_colombia.csv` | censos 1951-2018 | edad × sexo, población enumerada | UNdata (Demographic Yearbook) | 21 → `data_inter/census_pop_age.rds` → 22-24 |
| `data_input/reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds` | 1950-2100 | edad simple × sexo | WPP 2024 | 22-30 |
| `data_input/reference/wpp2024_colombia_pop_single_age_1950-2023.csv`, `wpp2024_colombia_fertility_age1.csv`, `wpp2024_colombia_lt_complete_1950-2100.csv` | 1950-2023 (población), 1950-2100 (fecundidad, tablas de vida) | edad simple × sexo; ASFR por edad simple; tablas de vida completas | WPP 2024 (csv completos en Drive) | 31 (produce); sin uso aún |
| `data_input/historical/census_tables/census1938_single_age_sex.csv`, `census1973_single_age_sex.csv` | censos 1938 y 1973 | edad simple (0-98, 99+) × sexo; 1938 con fila indígena; 1973 población censada sin ajuste | DANE, resúmenes censales (OCR / transcripción validada, hist/23) | hist/23 (produce); sin uso aún |
| `data_input/migration/undesa_pd_2020_ims_stock_by_age_sex_and_destination.xlsx`, `undesa_pd_2024_ims_stock_by_sex_destination_and_origin.xlsx` | 1990-2024 | stock de emigrantes colombianos por edad y sexo | UN DESA | 21 → `data_inter/emigrant_stock_age_1990-2024.rds` → 22, 23 |

### 2.4 Tablas de vida y tasas de referencia

| Archivo | Años | Detalle | Fuente | Scripts |
|---|---|---|---|---|
| `data_input/historical/lambda_Col_mltper_1x1.txt`, `lambda_Col_fltper_1x1.txt` | 1950-2015 | 1x1: mx, qx, lx, Lx, Tx, ex | LAMBdA | 25, 28 |
| `I:/My Drive/gits_drive/colombia_bereavement_pdr/data_input/life_tables_lambda.csv` (fuera del repo) | pivotales 1905, 1912, 1918, 1928, 1938, 1944, 1957 … 2008 | abreviadas × sexo | LAMBdA | 29 |
| `data_input/lifetables/tablas_utf8.txt`, `data_input/reference/dane_lifetables_nmx_1985_2020.csv` | 1985-2020 | nmx abreviadas, nacional y departamental | DANE, proyecciones 2005-2020 | 24, 25, 28 |

## 3. Nivel departamental

| Archivo | Años | Unidades | Detalle | Fuente y notas | Scripts |
|---|---|---|---|---|---|
| `data_input/historical/col_gap_analysis_1920_1985_department_deaths_clean_v06.csv` | 1915-1984 | 34 deptos (15-32 con dato por año) | total, hombres, mujeres; banderas `data_flag_dane` (111 celdas) y `data_flag_collaborator` (222) con nota y página; `source_new` (anuarios y boletines BOL_xxx); intendencias y comisarías existentes por año | Separador `;`. Anuarios y boletines DANE; desde 1960 en parte sumado del municipal v03. Nota típica: "Existe subregistro por problemas de cobertura" | ninguno (20 y 21 usan la variante aggregated) |
| `data_input/historical/dane_vitales_1958_1960_departamental.csv` (+ suma por departamento de `…_municipal.csv`) | 1958-1960 | 16 deptos (Meta desde 1960) + intendencias y comisarías agrupadas; sumando el municipal, también cada intendencia y comisaría publicada | población a mitad de año, matrimonios, bautizos, defunciones y defunciones de menores de un año (cuadro departamental, solo totales); por sexo sumando el archivo municipal, que cuadra con el cuadro en todos los deptos salvo Cundinamarca 1960 (38 defunciones) | DANE, "Estadística vital 1958 a 1960"; transcrito del PDF y verificado (cada columna suma el total publicado) | hist/24; 32 |
| `…_v06_territories_aggregated.csv` | 1915-1984 | 25 unidades (intendencias y comisarías sumadas al depto de origen) | ídem | Partición estable en el tiempo; su suma coincide con `national_deaths_v03` salvo en 1926, 1931, 1932, 1934 (nacional menor) y 1956-1961 (Bogotá en fila propia y dentro de Cundinamarca) | hist/20, hist/21 |
| `…_v06_territories_split.csv` | 1915-1984 | 33 unidades (territorios nacionales separados) | ídem | Mismo contenido con otra partición; totales algo menores por territorios sin dato | ninguno |
| `data_input/historical/archive_v01_v02/deaths_department_v01.csv` | 1923-1984 | 34 deptos | total, hombres, mujeres | Versión anterior (2026-10-13) de la misma transcripción; sustituida por v06 | ninguno (archivado; sustituido por col_gap_analysis) |
| `data_input/historical/col_gap_analysis_1920_1985_department_homicides_clean_v02.csv` | 1923-1924, 1927-1931, 1936, 1938-1940, 1943-1949, 1951-1965 (33 años) | 27 deptos (10-20 con dato) | total, hombres, mujeres, `known_data_problem` | Anuarios DANE. 1943-45 "muertes violentas accidentales" (4-7 veces más altas); "Department did not send data" frecuente | hist/20, hist/21 |
| `data_input/historical/archive_v01_v02/homicides_department_v02.csv` | 1923-1965 | 27 deptos | total, hombres, mujeres, `source_column`, `concept_flag` | Versión anterior de la misma serie | ninguno (archivado; sustituido por col_gap_analysis) |
| `data_input/historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx` | 1962-2002 | 40 jurisdicciones (deptos y metropolitanas) | total anual, formato ancho | Policía Nacional | ninguno aún |
| `data_input/historical/col_gap_analysis_1920_1985_department_population_clean_v03.csv` | censos 1905, 1912, 1918, 1928, 1938, 1951, 1964, 1973 | 20-31 deptos según censo | total, hombres, mujeres (sexo desde BOL_194) | Separador `;`. Anuarios DANE | hist/20, hist/21 |
| `data_input/historical/archive_v01_v02/population_department_v01.csv` | censos 1938, 1951, 1964 | 34 deptos | total, sexo, nº de municipios | Versión anterior | ninguno (archivado; sustituido por col_gap_analysis) |
| `data_input/historical/census_tables/census1951_dept_age5_sex_1938_1951.csv` | censos 1938 y 1951 | 15 deptos, 3 intendencias, 7 comisarías (Vichada sin 1951) | edad quinquenal (<1, 1-4, …, 95+) × sexo | Cuadro 10 del resumen censal de 1951 (OCR tesseract reconciliado por identidades, hist/23) | hist/23 (produce); ninguno aún |
| `data_input/historical/census_tables/census1973_adjusted_population_units.csv` | censo 1973 | 23 deptos, Bogotá D.E., 4 intendencias, 4 comisarías | población ajustada por cobertura por zona (total, cabecera, resto) y componente (hogares particulares, colectivos, áreas indígenas) | Capítulo VIII del resumen censal de 1973 (transcripción validada contra el Cuadro VIII.20, hist/23); omisión nacional 9,8 % | hist/23 (produce); ninguno aún |
| `data_input/micro/Defun*.txt` → `data_inter/deaths_munic_1979-2023.rds` | 1979-2023 | 33 deptos (sumando municipios con DIVIPOLA) | sexo, edad, causa violenta / no violenta | DANE EEVV | 02 → 03-19 |
| `data_input/DANEpop/*.xlsx` | 1985-2042 | 33 deptos (suma municipal) | área, sexo, edad simple | DANE: retroproyecciones 1985-2017 y proyecciones 2018-2042 | 01 → `data_inter/pop_munic_1985-2017.rds` |
| `data_input/lifetables/tablas_utf8.txt` | 1985-2020 por quinquenios | 33 deptos | tablas abreviadas por sexo | DANE | 24, 25 |
| `data_inter/completeness_deptos.rds`, `completeness_ggb.rds` | 1985-2017 | deptos | completitud estimada (GGB) | productos propios | 05-12 |
| `output/tables/completeness_empirical_dept_1985-2023.csv` | 1985-2023 | 33 deptos y grupo amazónico | completitud empírica (Adair y Lopez 2018) por sexo, año, modelo, variante y fuente de 5q0 | producto propio; no requiere población cerrada, pero depende del 5q0 departamental (DANE 2007 duplica o triplica el nivel de la ENDS en Chocó, Cauca, Nariño y la Amazonía) | 33 |
| `data_input/historical/LB_800_1938.pdf`, `LB_811_1951_V_1.pdf` (12 MB, no versionados) | censos 1938 y 1951 | deptos | publicaciones censales originales | DANE; no explotadas | ninguno |

## 4. Nivel municipal

| Archivo | Años | Unidades | Detalle | Fuente y notas | Scripts |
|---|---|---|---|---|---|
| `data_input/historical/dane_vitales_1958_1960_municipal.csv` | 1958-1960 | 828-872 municipios, intendencias y comisarías por año (2.534 filas; 2.518 con código DIVIPOLA); 1959 sin comisarías y 1960 sin Putumayo, como en la fuente | matrimonios; bautizos, defunciones de menores de un año y defunciones totales, cada una hombres/mujeres/total; `nodata_in_source` (celdas "..." de la fuente), `flag` (unidades cuyas columnas no cuadran) | DANE, "Estadística vital 1958 a 1960" (1962), leída del PDF `LD_558_1958_1960_EJ_2.pdf` (texto + dos pasadas OCR + transcripción previa, celda a celda; H + M = T y suma = TOTAL de la unidad = cuadro departamental). 674 de 700 columnas-unidad verificadas; las 26 restantes son inconsistencias del impreso o columnas con celdas "...". Corrige cinco municipio-años de la transcripción previa (Risaralda 1958, San Sebastián de Buenavista e Istmina 1959, Pinchote 1959, La Vega 1960). Soporte en `vitales_1958_1960_support/` | hist/24; 32 |
| `data_input/historical/col_gap_analysis_1920_1985_municipal_deaths_clean_v03.csv` | 1924-1932, 1935-1936, 1958-1960 (14 años) | 850 municipios en 31 deptos (552-799 con dato por año) | total, hombres, mujeres, `dane_code` (4,5 % sin código), `known_data_problem` | Estadística vital y anuarios DANE. Cobertura parcial del año frecuente ("only 4 of 12 months reported"). Para 1958-1960 preferir `dane_vitales_1958_1960_municipal.csv` (misma fuente, verificada) | hist/20, hist/21 |
| `data_input/historical/archive_v01_v02/deaths_municipal_v01.csv` | 1925-1960 (13 años) | 1.148 municipios | total, hombres, mujeres, dane_code, año de creación | Versión anterior; problemas de codificación en los nombres | ninguno (archivado; sustituido por col_gap_analysis) |
| `data_input/historical/col_gap_analysis_1920_1985_municipal_population_clean_v03.csv` | censos 1938, 1951, 1964 | 881 municipios (766-847 con dato) | total, hombres, mujeres, dane_code (5,6 % sin código) | Censos DANE | hist/20, hist/21 |
| `data_input/historical/archive_v01_v02/population_municipal_v01.csv` | censos 1938, 1951, 1964 | 904 municipios | total, sexo | Versión anterior | ninguno (archivado; sustituido por col_gap_analysis) |
| `data_input/micro/Defun*.txt` → `data_inter/deaths_munic_1979-2023.rds`, `deaths_munic_age_1979-2023.rds` | 1979-2023 | ~1.120 municipios (DIVIPOLA 2026) | sexo, edad quinquenal, dx total y dx_v (violenta) | DANE EEVV; códigos en `data_input/reference/DIVIPOLA-_Códigos_municipios_20260307.csv` | 02 → 03-19, 30 |
| `data_input/DANEpop/DCD-…-Mun-1985-1994.xlsx`, `…1995-2004.xlsx`, `…2005-2017_VP.xlsx`, `PPED-AreaSexoEdadMun-2018-2042_VP.xlsx` | 1985-2042 | todos los municipios | área, sexo, edad simple | DANE | 01 → `data_inter/pop_munic_1985-2017.rds` |
| `data_inter/asdr_munic_1985-2017.rds`, `homicide_cdr_munic_1985-2017.rds`, `homicide_estimates_1985-2017_excs.rds`, `excess_deaths_munic.rds`, `sex_ratios_munic_1985-2017.rds` | 1985-2017 | municipios | tasas, homicidios ajustados, excesos, razones de sexo | productos propios del módulo municipal | 03-19 |

## 5. Series finales producidas (nacional)

| Archivo | Años | Contenido | Script |
|---|---|---|---|
| `output/tables/completeness_ddm_conflict.csv`, `completeness_ddm_conflict_annual.csv` | ventanas intercensales 1938-2018 | completitud GGB-SEG con migración y corrección por conflicto, por sexo | 23 |
| `output/tables/deaths_expected_wpp_mse_1950-2023.csv` | 1950-2023 | defunciones esperadas: WPP 2024 con su conflicto sustituido por el ajuste MSE en 1985-2018; registradas; completitud; por sexo y edad quinquenal | 27 |
| `output/tables/lifetables_compared.csv`, `lifetables_compared_summary.csv` | 8 periodos entre 1950 y 2019 | tablas abreviadas: registradas, WPP, WPP sin conflicto + MSE, LAMBdA, DANE | 28 |
| `output/tables/mx_extended_1905-2023.csv`, `lifetables_extended_summary.csv` | 1905-2023 | mx abreviadas por sexo: LAMBdA reescalado y suavizado 1905-1949, serie propia 1950-2023 | 29 |
| `output/tables/deaths_by_cause_sex_age_1953-2023.csv` | 1953-2023 | defunciones violentas (registradas y ajustadas) y no violentas, tasas, bandera de calidad (MSE / escalado / interpolado) | 30 |
| `output/tables/completeness_empirical_national_1979-2023.csv` | 1979-2023 | completitud empírica de Adair y Lopez (2018), anual, por sexo y ambos sexos; modelos 1 (con completitud de menores de 5) y 2; con todas las defunciones y sin violentas; defunciones esperadas | 33 |
| `output/tables/completeness_empirical_dept_1985-2023.csv`, `completeness_empirical_validation_2014.csv` | 1985-2023 | lo mismo por departamento (33 más el grupo amazónico), con dos fuentes de 5q0 departamental (DANE escalada a WPP; DANE anclada en 2014 a la ENDS 2015); comparación con la tabla 6 del artículo | 33 |

## 6. Observaciones para usar los archivos nuevos

- Los csv `col_gap_analysis_*` mezclan separadores: `department_deaths_v06` (tres variantes), `department_population_v03`, `national_deaths_v03` y `national_population_v02` usan `;` (leer con `read_csv2` o `delim = ";"`); los demás usan `,`.
- Hay dos generaciones de la misma transcripción: v01/v02 (2026-10-13) y `col_gap_analysis_*` (2026-11-09). Las nuevas añaden 1915-1922 en deptos, sexo para 1923-1949 a nivel nacional, fuente y banderas de calidad por celda con página de origen, y tres particiones territoriales; corrigen además errores de transcripción (Valle del Cauca 1979: 4.818 → 14.818; Santander 1947: 6.091 → 11.499), por lo que el total nacional de 1979 pasa de 125.925 a 135.925. Los scripts `code/historical/20-21` y el bloque de anuario de `code/22` ya leen las nuevas; las v01/v02 están en `data_input/historical/archive_v01_v02/` y no las lee ningún script.
- La serie departamental 1915-1984 tiene entre 15 y 32 departamentos con dato por año; el total nacional de `national_deaths_v03` depende de qué departamentos reportan, así que los cambios de nivel (por ejemplo 1965 a 1970) son en parte cambios de cobertura.
- Ninguna fuente de defunciones anterior a 1979 tiene edad por debajo del nivel nacional. Toda estimación subnacional por edad antes de 1979 tendría que apoyarse en patrones nacionales (LAMBdA, OMS) aplicados a totales departamentales o municipales; como denominadores por edad existen los censos 1938 y 1951 por departamento (`census_tables`).
- La fuente policial (1962-2002) es la única con homicidios departamentales entre 1966 y 1978. Se solapa con los anuarios (1962-65) y con EEVV (1979-2002), lo que permite calibrar la diferencia de concepto.
- La completitud empírica (33) es la tercera estimación nacional junto al DDM (23) y a WPP sin conflicto + MSE (27). Reproduce el 87 % de Adair y Lopez para 2014 (modelo 2, ambos sexos) y da 79-81 % en 1979, 86-88 % en 1985-1995 y 87-91 % desde 2000; sin las defunciones violentas baja 3-5 puntos en 1985-2000, porque el modelo lee la tasa bruta registrada como señal de registro y los homicidios la inflan. El pico de 2021 (96 %) es el exceso de mortalidad por covid leído de la misma manera. A nivel departamental la comparación con la tabla 6 del artículo da una desviación cuadrática media de 6 puntos (modelo 2) con el 5q0 anclado a la ENDS y de 23 con el 5q0 DANE sin anclar; Bogotá sale más alto por ocurrencia frente a residencia. Figuras en `figures/04_completeness/completeness_empirical_*.png`.
- El inventario anterior de variables y lagunas, de marzo de 2026, está en `documents/datos_mortalidad_colombia_03_2026.xlsx`; este documento lo actualiza con los archivos incorporados desde entonces.

## 7. Información adicional que podría complementar lo disponible

Ordenada por el vacío que cierra (sección 0 y "Huecos principales"). "Esfuerzo" se refiere a
incorporarla al proyecto; "por verificar" marca lo que conviene confirmar en la fuente antes de
contar con ello.

| Vacío | Fuente candidata | Qué aportaría | Nivel | Esfuerzo |
|---|---|---|---|---|
| Nacimientos anuales antes de 1950, necesarios para cualquier reconstrucción poblacional 1900-1950 (proyección inversa) y para la fecundidad histórica | Anuarios estadísticos DANE (nacimientos registrados por departamento, desde ~1915) y publicaciones de Estadísticas Vitales; microdatos EEVV de nacimientos 1979-2023 (DANE); WPP 2024 ya aporta nacimientos y tasas por edad desde 1950 (script 31) | serie anual de nacimientos 1915-2023; corrige el hueco de insumos para el modelo de reconstrucción | nacional y departamental | medio: transcripción de los mismos anuarios ya consultados para las defunciones |
| Censo de 1964 sin resumen de población (solo está el de vivienda) | DANE, *XIII Censo Nacional de Población, Resumen General* (biblioteca digital DANE); UNdata ya da la edad quinquenal nacional | población por edad y sexo por departamento en 1964, cerrando la serie censal departamental 1938-1951-1964-1973 | departamental | bajo si el PDF es tipografiado (OCR como el de 1951) |
| Población por departamento y edad en 1964, 1973, 1985, 1993 y 2005 | IPUMS International, muestras censales de Colombia 1964, 1973, 1985, 1993, 2005 (10 %, con departamento y municipios grandes) | pirámides departamentales en todos los censos, estimaciones de mortalidad adulta por orfandad y de fecundidad por hijos propios; alternativa a los cuadros impresos de 1973 | departamental (municipal parcial) | bajo: registro gratuito y extracto |
| Omisión censal por edad y sexo 1985-2018 | DANE, *Conciliación censal 1985-2005* y conciliación del CNPV 2018 (tablas de omisión por edad y sexo); informes de evaluación de cobertura | perfil de omisión por edad para corregir las pirámides censales que alimentan el DDM | nacional y departamental | bajo: lectura de tablas publicadas |
| Defunciones por edad a nivel departamental antes de 1979 | Anuarios Generales de Estadística 1950-1975 (cuadros de defunciones por grupos de edad y departamento, por verificar en los PDF ya usados) | completitud departamental por edad antes de EEVV | departamental | medio-alto: transcripción |
| Defunciones municipales 1961-1978 | DANE, publicaciones anuales de *Estadísticas Vitales* de los años 60 y 70 (defunciones por municipio, por verificar) | cierra el único tramo sin dato municipal | municipal | alto: transcripción |
| Homicidios con concepto médico-legal y policial después de 2002 | Instituto Nacional de Medicina Legal, *Forensis* y datos abiertos (homicidios por municipio, 2000-2023); Policía Nacional, SIEDCO datos abiertos (homicidios por municipio, ~2003-2024) | tres mediciones independientes del homicidio (EEVV, Medicina Legal, Policía) por municipio y año; calibración del concepto policial de la serie 1962-2002 | municipal | bajo: descargas públicas |
| Víctimas del conflicto por debajo del nivel nacional | CNMH, Observatorio de Memoria y Conflicto (casos por municipio 1958-2018); Registro Único de Víctimas (homicidio y desaparición por municipio y año, 1985-2024); estimaciones MSE JEP-CEV-HRDAG publicadas por departamento y periodo | corrección por conflicto departamental y municipal en la completitud 1985-2018, hoy solo nacional | departamental y municipal | bajo-medio: descargas públicas; el MSE departamental hay que extraerlo de los anexos |
| Mortalidad por causa en 1978 y contraste 1953-2009 | LAMBdA, 19 grupos de causa (ya en el repositorio, sin usar) | causa × edad × sexo para 1978 y cotejo de la serie violenta de OMS y EEVV | nacional | bajo |
| Tabulaciones por causa independientes de los microdatos 1979-2023 | WHO Mortality Database, CIE-9 y CIE-10 (`morticd09`, `morticd10`); UN Demographic Yearbook (defunciones por edad y sexo, desde los años 50) | cotejo externo de EEVV y de la edad en 1950-1952 | nacional | bajo |
| Denominadores departamentales 2015-2023 con la inmigración venezolana | Migración Colombia (stock por departamento), CNPV 2018 (nacidos en el extranjero por departamento), DANE GEIH | población departamental corregida por inmigración reciente; la emigración ya está (UN DESA) | departamental | bajo-medio |
| Estructura por edad departamental antes de 1938 | Publicaciones de los censos de 1918 y 1928 (grupos de edad amplios por departamento, por verificar) | pirámides departamentales tempranas para las proyecciones hacia atrás | departamental | medio: OCR de PDF antiguos |

Lo que ninguna de estas fuentes cierra: edad a nivel municipal antes de 1979 y causa de muerte
antes de 1953 (salvo la distinción homicidio / otras de los anuarios).
