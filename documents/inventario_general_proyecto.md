---
title: "Inventario general del proyecto colombia_homicidios"
subtitle: "Insumos, intermedios, salidas, scripts y documentos, con el estado de uso de cada dato"
date: 2026-11-09
lang: es
---

Estado al 2026-11-09. Rutas relativas a la raíz `C:\Users\kikep\gits\colombia_homicidios`.
El inventario detallado de las fuentes de mortalidad por nivel geográfico está en
`documents/inventario_datos_mortalidad.md`; este documento cubre todo el proyecto y señala
qué datos no se están usando todavía (sección 7).

![Disponibilidad de datos por año, nivel geográfico y desagregación (script 32; una fila por serie, el color indica el detalle disponible y los tonos atenuados años con cobertura parcial)](../figures/inventory/data_availability.png)

## 1. Qué es el proyecto y cómo está organizado

Dos líneas de trabajo conviven en el repositorio:

1. **Módulo municipal (scripts 01-20)**: modelo de homicidios municipales 1985-2017 a partir de la
   razón de sexos de la mortalidad por todas las causas, con descomposición por causa, pruebas de
   subregistro (Caribe antes de 1998), completitud GGB/DDM por departamento y conjunto de datos
   compartido 1985-2023. Es el pipeline de `run_all.R`.
2. **Módulo nacional de mortalidad ajustada (scripts 21-30)**: censos, OMS, LAMBdA, WPP 2024 y la
   estimación MSE del conflicto (JEP-CEV-HRDAG) para construir una serie nacional de mortalidad por
   edad, sexo y causa (violenta / no violenta) 1953-2023 y extenderla hacia atrás hasta 1905. No está
   en `run_all.R`; se corre script a script.

Además hay un módulo histórico (`code/historical/`, series transcritas de anuarios 1915-1984) y un
script experimental (`code/experimental/model_spatial.R`).

| Carpeta | Contenido | Versionada en git |
|---|---|---|
| `code/` | 35 scripts R numerados, `historical/` (4), `experimental/` (1) | sí |
| `data_input/` | insumos originales (2,9 GB) | solo `README.md` y los csv pequeños de `historical/` y `reference/` |
| `data_inter/` | productos intermedios `.rds` (130 MB) y pruebas (`q_test/`, `model_variants/`) | no |
| `output/` | tablas finales (`tables/`, 32 csv) y datos compartidos (csv.gz, parquet, diccionario) | sí |
| `figures/` | 82 figuras en 8 subcarpetas | sí |
| `documents/` | planes, informes, inventarios, metadatos DANE | sí |
| raíz | `README.md`, `run_all.R`, `DESCRIPTION`, licencias, `Rplots.pdf` (residuo, borrar) | sí |

## 2. Insumos (`data_input/`)

Columna "Scripts": número del script que lo lee. "hist/" = `code/historical/`. **Sin uso** marca lo que ningún script lee.

### 2.1 Defunciones

| Archivo | Contenido | Años | Tamaño | Scripts |
|---|---|---|---|---|
| `micro/Defun1979.txt` … `Defun2021.txt`, `nofetal2022.csv`, `nofetal2023.csv` (45 archivos) | microdatos DANE EEVV, defunciones no fetales: municipio de ocurrencia y residencia, sexo, edad, causa (lista 105) | 1979-2023 (sin 1978) | 1,2 GB | 01 |
| `who_mdb/morticd07.zip`, `morticd08.zip` | WHO Mortality Database, CIE-7 y CIE-8, todos los países | Colombia 1953-1977 | 10 MB | 21 |
| `who_mdb/mort_pop.zip`, `mort_availability.zip`, `mort_documentation.zip`, `doc/*.pdf` | población OMS, disponibilidad, documentación | | 2 MB | **sin uso** (documentación consultada a mano) |
| `historical/lambda_Col_Deaths{m,f}.txt` | LAMBdA, defunciones registradas por edad y sexo | 1926-2015 (76 años) | 48 KB | 21 → 22, 23 |
| `historical/lambda_Col_Cause19_Deaths{m,f}.txt` | LAMBdA, defunciones por 19 grupos de causa × edad × sexo | 1953-2009 | 168 KB | **sin uso** |
| `historical/col_gap_analysis_1920_1985_national_deaths_clean_v03.csv` | totales nacionales por sexo (anuarios DANE) | 1923-1984 | 3 KB | 22 |
| `historical/col_gap_analysis_1920_1985_department_deaths_clean_v06.csv` (+ `_territories_aggregated`, `_territories_split`) | defunciones por departamento y sexo, con banderas de calidad y fuente por celda | 1915-1984 | 390 KB | hist/20, hist/21 (variante aggregated) |
| `historical/col_gap_analysis_1920_1985_municipal_deaths_clean_v03.csv` | defunciones por municipio y sexo, 850 municipios | 14 años entre 1924 y 1960 | 3 MB | hist/20, hist/21 |
| `historical/archive_v01_v02/*.csv` (6 archivos) | versión anterior de las transcripciones (2026-10-13) | 1923-1984 | 1,2 MB | archivados, **sin uso** |
| `conflict/mse_national_age5_1985-2018.rds` | JEP-CEV-HRDAG, homicidios y desapariciones del conflicto, edad quinquenal × sexo | 1985-2018 | 208 KB | 21 → 23, 27 |
| `ucdp/GEDEvent_v25_1.csv`, `GEDEvent_v25_01_25_12.csv` | UCDP GED, eventos georreferenciados, todos los países | 1989-2025 | 259 MB | hist/22 |
| `251208_MortalityCrises.zip` | UN Population Division, mx por tipo de crisis, todos los países (no público) | 1950-2023 | 766 MB | 26 (extrae Colombia) |
| `reference/wpp2024_crises_colombia_mx1_conflicts.csv`, `lt1_crises_free.csv`, `events.csv`, `country.csv` | extracto Colombia de lo anterior | 1950-2023 | 5 MB | 27 |
| `reference/wpp2024_crises_colombia_mx1_crises.csv`, `mx1_disasters.csv`, `mx1_famine.csv`, `mx1_covid.csv`, `cdr.csv` | extracto Colombia: crisis total, desastres, hambruna, COVID, TBM | 1950-2023 | 1,3 MB | **sin uso** (extraídos, no analizados) |
| `reference/who_deaths_age_colombia_1953-1977.csv`, `who_violent_age_colombia_1953-1977.csv` | extractos OMS por edad: todas las causas; homicidio + intención no determinada | 1953-1977 | 16 KB | producidos por 21; copias csv de los rds |
| `reference/who/who_homicide_colombia.csv`, `who_all_cause_colombia.csv` | totales anuales OMS (origen externo, sin script productor) | 1953-2019 aprox. | 4 KB | hist/20, hist/22 |
| `historical/col_gap_analysis_1920_1985_department_homicides_clean_v02.csv` | homicidios por departamento y sexo (anuarios) | 1923-1965 | 80 KB | hist/20, hist/21 |
| `historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx` | homicidios Policía Nacional, 40 jurisdicciones | 1962-2002 | 20 KB | **sin uso** |

### 2.2 Población

| Archivo | Contenido | Años | Tamaño | Scripts |
|---|---|---|---|---|
| `DANEpop/DCD-area-sexo-edad-proypoblacion-Mun-1985-1994.xlsx`, `…1995-2004.xlsx`, `…2005-2017_VP.xlsx` | retroproyecciones municipales DANE por área, sexo y edad simple | 1985-2017 | 137 MB | 03 |
| `DANEpop/PPED-AreaSexoEdadMun-2018-2042_VP.xlsx` | proyecciones municipales DANE | 2018-2042 | 129 MB | 03, 11, 11b (solo hasta 2023) |
| `reference/wpp2024_colombia_mx_pop_single_age_1950_2100.rds` | WPP 2024, mx y población por edad simple y sexo | 1950-2100 | 1,8 MB | 22, 23, 24, 25, 27, 28, 29, 30 (**sin script productor**) |
| `reference/wpp2024_colombia_pop_single_age_1950-2023.csv` | WPP 2024, población por edad simple y sexo (estimaciones) | 1950-2023 | 1 MB | 31 (produce); **sin uso** aún |
| `reference/wpp2024_colombia_fertility_age1.csv` | WPP 2024, tasas de fecundidad por edad simple (ASFR, PASFR, nacimientos) | 1950-2100 | 3 MB | 31 (produce); **sin uso** aún (insumo para una reconstrucción poblacional) |
| `census_raw/undata_t22/` (126 páginas html), `undata_t44/` (314) | caché de UNdata: censos por edad y sexo (t22) y nacidos en el extranjero (t44) | censos 1951-2018 | 36 MB | 21 (solo si falta el csv parseado) |
| `reference/undata_census_colombia.csv`, `undata_foreign_born_colombia.csv` | tablas UNdata parseadas | censos 1951-2018 | 676 KB | 21 → `census_pop_age.rds` |
| `historical/lambda_Col_Pop{m,f}.txt` | LAMBdA, población censal por edad | censos 1912-2005 | 6 KB | 21 |
| `historical/col_gap_analysis_1920_1985_national_population_clean_v02.csv` | población nacional (anuarios y censos) | 1905-1985 | 3 KB | **sin uso** |
| `historical/col_gap_analysis_1920_1985_department_population_clean_v03.csv` | población censal por departamento y sexo | censos 1905-1973 | 84 KB | hist/20, hist/21 |
| `historical/col_gap_analysis_1920_1985_municipal_population_clean_v03.csv` | población censal por municipio y sexo, 881 municipios | censos 1938, 1951, 1964 | 3 MB | hist/20, hist/21 |
| `migration/undesa_pd_2020_…xlsx`, `undesa_pd_2024_…xlsx` | UN DESA, stock de emigrantes colombianos por edad, sexo y destino | 1990-2024 | 12 MB | 21 → 22, 23 |
| `historical/census_tables/census1938_single_age_sex.csv`, `census1973_single_age_sex.csv` | población nacional por edad simple y sexo, censos 1938 (con fila indígena) y 1973 (censada, sin ajuste) | censos 1938, 1973 | 6 KB | hist/23 (produce); **sin uso** aún |
| `historical/census_tables/census1951_dept_age5_sex_1938_1951.csv` | población por edad quinquenal y sexo, 15 departamentos, 3 intendencias y 7 comisarías, censos 1938 y 1951 (Cuadro 10 de 1951) | censos 1938, 1951 | 64 KB | hist/23 (produce); **sin uso** aún |
| `historical/census_tables/census1973_adjusted_population_units.csv` | población ajustada por cobertura 1973 por departamento, D.E., intendencia y comisaría, zona (total, cabecera, resto) y componente (hogares particulares, colectivos, áreas indígenas) | censo 1973 | 5 KB | hist/23 (produce); **sin uso** aún |
| `historical/LD_771_1938_V_1.pdf`, `LD_771_1951.pdf`, `LB_771_1973.pdf` | resúmenes generales de los censos 1938, 1951 y 1973; fuente de `census_tables/` (OCR + transcripción validada por sumas, hist/23). Sin extraer: cabecera/resto de 1973 por edad y el ajuste de cobertura 1973 a nivel municipal | | 29 MB (no versionados) | hist/23 (solo si `run_ocr`) |
| `historical/LB_771_1951_V_2.pdf`, `LB_771_1964_V_2.pdf` | censos de edificios y viviendas 1951 y 1964 (no población) | | 11 MB | **sin uso** |
| `historical/LB_800_1938.pdf` (Norte de Santander), `LB_811_1951_V_1.pdf` (Huila) | tomos departamentales | | 12 MB | **sin uso** |
| `historical/LAMBdA_documentation.pdf` | documentación LAMBdA | | 17 MB | documentación |

### 2.3 Tablas de vida y referencias

| Archivo | Contenido | Años | Scripts |
|---|---|---|---|
| `lifetables/tablas_utf8.txt` | texto del PDF DANE "Tablas abreviadas de mortalidad nacionales y departamentales 1985-2020" | 1985-2020 | 13 (manual) → `reference/dane_lifetables_nmx_1985_2020.csv` |
| `reference/dane_lifetables_nmx_1985_2020.csv` | nmx abreviadas DANE, nacional y departamental | 1985-2020 | 14, 16, 18, 24, 25, 28 |
| `historical/lambda_Col_{m,f}ltper_1x1.txt` | LAMBdA, tablas de vida 1x1 | 1950-2015 | 25, 28, 29 |
| `reference/wpp2024_colombia_lt_complete_1950-2100.csv` | WPP 2024, tablas de vida completas (edad simple) por sexo y ambos sexos, estimaciones y proyección media | 1950-2100 | 31 (produce); **sin uso** aún |
| `I:/My Drive/gits_drive/colombia_bereavement_pdr/data_input/life_tables_lambda.csv` (fuera del repo) | LAMBdA, tablas abreviadas pivotales | 1905-2008 | 29 |
| `reference/DIVIPOLA-_Códigos_municipios_20260307.csv` | códigos y nombres de municipios | 2026 | 00, 14 |
| `documents/Lista_105_Colombia_CIE9-y-CIE10.xls` | lista DANE de 105 causas | | 00 |

## 3. Intermedios (`data_inter/`)

| Archivo | Lo produce | Lo leen | Contenido |
|---|---|---|---|
| `micro_1979_2023.rds` (40 MB) | 01 | 02, 09, 10, 11, 11b | microdatos limpios, una fila por defunción |
| `deaths_munic_1979-2023.rds` | 02 | 04, 05, 06, 10 | defunciones por municipio × año × sexo × grupo de causa |
| `deaths_munic_age_1979-2023.rds` (45 MB) | 02 | 04, 14, 18, 22, 23, 27, 30 | ídem con edad quinquenal (dx, dx_v) |
| `pop_munic_1985-2017.rds` | 03 | 04, 05, 06, 09, 10, 11, 11b, 14, 18, 23, 24 | población municipal por sexo y edad |
| `asdr_munic_1985-2017.rds` | 04 | **nadie** | tasas por edad municipales |
| `homicide_cdr_munic_1985-2017.rds`, `sex_ratios_munic_1985-2017.rds` | 05 | 07, 15 | panel municipal: tasas de homicidio y razones de sexo |
| `excess_deaths_munic.rds` | 06 | 07, 15 | exceso de mortalidad masculina |
| `homicide_estimates_1985-2017_excs.rds` (16 MB) | 07 | 08, experimental | estimaciones ZINB de homicidios |
| `sex_ratio_contrib_by_cause.rds` | 09 | **nadie** (solo figuras) | contribución de cada causa a la razón de sexos |
| `completeness_deptos.rds`, `completeness_ggb.rds` | 10 | 12, 14, 15, 18 | completitud por departamento (TBM relativa y GGB) |
| `census_pop_age.rds` | 21 | 22, 24 | censos UNdata por edad y sexo |
| `emigrant_stock_age_1990-2024.rds` | 21 | 22 | stock de emigrantes por edad |
| `lambda_deaths_age_1926-2015.rds`, `who_deaths_age_1953-1977.rds`, `who_violent_age_1953-1977.rds`, `conflict_mse_age5_1985-2018.rds` | 21 | 22, 23, 27, 30 | insumos nacionales por edad |
| `deaths_age_annual_1938-2023.rds`, `ddm_census_inputs.rds` | 22 | 23, 25, 27 | serie registrada por edad e insumos del DDM |
| `who_homicide_colombia.rds`, `who_all_cause_colombia.rds` | **sin script productor** | nadie (los csv de `reference/who/` los sustituyen) | totales OMS |
| `model_variants/oos_scores.rds` | 20 | nadie | puntajes fuera de muestra |
| `model_variants/null.rds`, `oos_scores_partial.rds` | **sin script productor** | nadie | residuos de corridas anteriores |
| `q_test/*.csv` (9) | 10, hist/21 | nadie | pruebas de calidad y sensibilidad |

## 4. Salidas

### 4.1 Datos compartidos (`output/`)

| Archivo | Script | Contenido |
|---|---|---|
| `deaths_pop_munic_1985_2023.csv.gz` | 11 | año × municipio × sexo: población y defunciones por 6 grupos de causa (87.594 filas) |
| `deaths_pop_munic_age_1985_2023.parquet` | 11b | ídem con edad quinquenal |
| `deaths_pop_munic_dictionary.md` | 11 | diccionario de variables y fuentes |
| `homicide_estimates_munic_1985_2017.csv.gz` | 07/08 (nombre no aparece en el código actual) | estimaciones municipales de homicidios |

### 4.2 Tablas (`output/tables/`, 35 csv)

| Grupo | Archivos | Scripts |
|---|---|---|
| Completitud departamental | `completeness_deptos`, `completeness_ggb`, `completeness_dane`, `completeness_ddm`, `underreg_dept_correlations`, `sex_ratio_observed_vs_dane_expected` | 10, 12, 14, 18, 19 |
| Modelo municipal | `model_completeness_*` (2), `model_improvements_*` (5), `age_placebo_*` (3), `residence_vs_occurrence_*` (2) | 15, 16, 17, 20 |
| Completitud nacional (DDM) | `completeness_ddm_census` (+ `_annual`), `completeness_ddm_conflict` (+ `_annual`), `completeness_wpp_mse_annual` | 22, 23, 27 |
| Completitud empírica (Adair y Lopez 2018) | `completeness_empirical_national_1979-2023`, `completeness_empirical_dept_1985-2023`, `completeness_empirical_validation_2014` (modelos 1 y 2, con y sin defunciones violentas; 5q0 departamental DANE escalada a WPP o anclada a la ENDS 2015) | 33 |
| Serie nacional ajustada | `deaths_expected_wpp_mse_1950-2023`, `deaths_by_cause_sex_age_1953-2023`, `mx_extended_1905-2023`, `lifetables_extended_summary` | 27, 29, 30 |
| Comparaciones | `pyramids_census_wpp_dane`, `mx_wpp_lambda_ours`, `lifetables_compared` (+ `_summary`) | 24, 25, 28 |
| Inventario | `data_availability` (nivel, dominio, serie, año, detalle, cobertura parcial, archivo; una fila por serie y año) | 32 |

### 4.3 Figuras (`figures/`)

| Carpeta | n | Scripts |
|---|---|---|
| `01_descriptives/` | 15 | 04 |
| `02_model/` | 24 | 07, 08, 15, 20 |
| `03_cause_decomposition/` | 6 | 09 |
| `04_completeness/` | 24 | 10, 14, 18, 22-30, 33 |
| `05_underregistration_tests/` | 6 | 12, 16, 17, 19 |
| `historical/` | 6 | hist/20, hist/22 |
| `inventory/` | 1 (`data_availability.png`, tile de disponibilidad por año, nivel y desagregación) | 32 |
| `experimental/` | 0 | |

## 5. Scripts (`code/`)

| Script | Qué hace | En `run_all.R` |
|---|---|---|
| `00_setup.R` | paquetes, rutas, lista 105, DIVIPOLA | fuente común |
| `01_load_microdata.R` | lee los 45 archivos EEVV, armoniza variables | sí |
| `02_summarise_deaths.R` | agrega por municipio, sexo, edad y grupo de causa | sí |
| `03_population.R` | lee las proyecciones DANE municipales | sí |
| `04_descriptives.R` | descriptivos y tasas por edad | sí |
| `05_municipal_panel.R` | panel municipal: razones de sexo y tasas de homicidio | sí |
| `06_excess_deaths.R` | exceso de mortalidad masculina | sí |
| `07_model_zinb.R`, `08_model_validation.R` | modelo ZINB de homicidios y validación | sí |
| `09_sex_ratio_by_cause.R` | descomposición de la razón de sexos por causa | sí |
| `10_registration_completeness.R` | completitud por departamento (TBM relativa, GGB) | sí |
| `11_shared_dataset.R`, `11b_shared_dataset_age.R` | datos compartidos 1985-2023 | sí |
| `12_underregistration_test.R` | prueba de la hipótesis de subregistro | sí |
| `13_extract_dane_lifetables.R` | parsea las tablas de vida DANE del texto del PDF | manual |
| `14_completeness_dane.R` | completitud frente a las tablas DANE | sí |
| `15_model_completeness.R` | modelo con completitud como covariable | sí |
| `16_age_placebo.R`, `17_residence.R` | placebo por edad; residencia vs ocurrencia | sí |
| `18_ddm_completeness.R`, `19_completeness_vs_correlation.R` | DDM departamental; completitud vs correlación | sí |
| `20_model_improvements.R` | variantes del modelo, fuera de muestra, pandemia | no |
| `21_census_who_inputs.R` | censos UNdata, LAMBdA, OMS por edad y causa, MSE, emigrantes | no |
| `22_ddm_census_national.R` | serie registrada por edad 1938-2023 y DDM nacional | no |
| `23_ddm_conflict_adjusted.R` | DDM con numerador corregido por conflicto; referencias WPP/DANE/LAMBdA | no |
| `24_pyramids_census_wpp_dane.R`, `25_mx_wpp_lambda_ours.R` | pirámides y tasas comparadas | no |
| `26_wpp_crises_inputs.R` | extrae Colombia del zip de crisis de WPP 2024 | no |
| `27_wpp_conflict_replaced.R` | defunciones esperadas: WPP sin su conflicto + MSE (1985-2018) | no |
| `28_lifetables_compared.R`, `29_mx_extended_back_lambda.R` | tablas de vida por fuente; extensión a 1905 | no |
| `30_deaths_by_cause_series.R` | serie nacional violenta / no violenta 1953-2023 | no |
| `31_wpp_lifetables_inputs.R` | extrae Colombia de los csv completos de WPP 2024 (fuera del repo): tablas de vida completas, población y fecundidad por edad simple | no |
| `32_data_availability.R` | tile de disponibilidad de datos por año, nivel geográfico y desagregación → `figures/inventory/data_availability.png`, `output/tables/data_availability.csv` | no |
| `33_completeness_empirical.R` | completitud empírica del registro de defunciones (Adair y Lopez 2018, PLoS ONE): nacional 1979-2023 y departamental 1985-2023, modelos 1 y 2, con todas las defunciones y sin violentas; validación 2014 → `completeness_empirical_*` en `output/tables/` y `figures/04_completeness/` | no |
| `historical/20`, `21`, `22` | cobertura y calidad de las transcripciones; UCDP vs OMS | no |
| `historical/23_census_tables_ocr.R` | tablas censales 1938, 1951 y 1973 desde los PDF (OCR tesseract + transcripción, validadas por identidades) → `historical/census_tables/` | no |
| `experimental/model_spatial.R` | modelo espacial (exploratorio) | no |

## 6. Documentos (`documents/`)

| Archivo | Fecha | Contenido |
|---|---|---|
| `report_missing_deaths_caribbean_09_2026.html` | 2026-09 | informe: subregistro en el Caribe antes de 1998 |
| `executive_report_underregistration_10_2026.html` | 2026-10 | informe ejecutivo de subregistro |
| `plan_cleanup_and_underregistration.md`, `HANDOFF_plan_A_execution.md` | 2026-10-13 | evaluación del repositorio, plan de limpieza (Plan A) y de subregistro (Plan B) |
| `datos_mortalidad_colombia_03_2026.xlsx` | 2026-03 | inventario anterior de variables y lagunas |
| `inventario_datos_mortalidad.md` (+ `.html`) | 2026-11-09 | fuentes de mortalidad por nivel geográfico |
| `inventario_general_proyecto.md` (+ `.html`) | 2026-11-09 | este documento |
| `Lista_105_Colombia_CIE9-y-CIE10.xls` | | lista DANE de causas |
| `metadata/` | | diccionarios EEVV 1979-2016, variables de microdatos, manual de certificación, glosario |

## 7. Datos que no se están usando ni analizando

Ordenados por lo que aportarían.

| Dato | Qué aportaría | Esfuerzo |
|---|---|---|
| **Tablas censales extraídas (`historical/census_tables/`, hist/23)** | ya extraídas y validadas, sin explotar: edades simples nacionales 1938 y 1973 (preferencia de dígitos, DDM con edad simple); edad quinquenal por departamento 1938 y 1951 (completitud departamental intercensal con las defunciones 1915-1984); población ajustada por cobertura 1973 por departamento (omisión 9,8 % nacional, muy desigual por territorio) | bajo: lectura directa |
| **Resúmenes censales 1973: lo que falta** | cabecera/resto por edad simple (Cuadro 2) y ajuste de cobertura por municipio (capítulo VIII, ~1.000 filas) | alto: el escaneo no admite OCR; transcripción manual |
| **Tablas WPP 2024 nuevas (31)**: tablas de vida completas, población y fecundidad por edad simple | insumos para una reconstrucción poblacional 1938-2023 (cohorte-componente bayesiano) y para comparar la mortalidad propia con la tabla completa de WPP | bajo |
| **LAMBdA, 19 grupos de causa 1953-2009** | mortalidad por causa con edad y sexo para 1978 (año sin EEVV) y cotejo independiente de la serie violenta de OMS y EEVV 1953-2009 | bajo: lectura directa |
| **Homicidios Policía Nacional 1962-2002 por departamento** | única fuente departamental de homicidios 1966-1978; calibración del concepto policial frente a anuarios (1962-65) y EEVV (1979-2002) | bajo |
| **Transcripciones nuevas sin explotar analíticamente**: defunciones departamentales 1915-1984, municipales 1924-1960, homicidios departamentales 1923-1965 | solo se usan para figuras de cobertura y pruebas de calidad (hist/20-21) y para el total nacional de 22; permitirían completitud departamental antes de 1979 (con los censos 1938-1973) y tasas municipales de los años 20-50 | medio: requiere población interpolada y armonización territorial |
| **Población nacional anuarios 1905-1985** | contraste con WPP y censos para 1905-1950 | bajo |
| **Componentes de crisis WPP distintos del conflicto** (desastres, hambruna, COVID, TBM) | ya extraídos; la COVID importa para 2020-2023 si se quiere separar exceso pandémico de la serie no violenta | bajo |
| **UCDP GED** | solo comparado con OMS a nivel nacional; tiene geolocalización por evento (municipio) 1989-2024 que no se ha cruzado con el panel municipal | medio |
| **Proyecciones DANE 2024-2042** | fuera del alcance actual | ninguno |
| **Población OMS (`mort_pop.zip`)** | redundante con WPP | ninguno |
| **Tomos departamentales 1938 (Norte de Santander) y 1951 (Huila)** | edad por municipio en dos departamentos; sin interés salvo como prueba de método | bajo |
| **Censos de vivienda 1951 y 1964** | no contienen población por edad | ninguno |

Productos intermedios que nadie lee: `asdr_munic_1985-2017.rds` (tasas por edad municipales, 5 MB),
`sex_ratio_contrib_by_cause.rds`, `model_variants/oos_scores.rds` y todo `q_test/`. No es un
problema, pero `model_variants/null.rds`, `oos_scores_partial.rds` y los rds `who_*_colombia.rds`
no tienen script productor y conviene borrarlos o documentar su origen.

## 8. Lagunas de cobertura que ningún dato disponible cierra

- Defunciones municipales 1961-1978, y por edad a nivel subnacional antes de 1979.
- Resumen de población del censo de 1964 (solo está el de vivienda); la edad quinquenal nacional de 1964 viene de UNdata.
- Población por departamento y edad en 1964 y 1973 (en 1973 solo quedó en los bancos de datos del DANE); para 1938 y 1951 ya está en `historical/census_tables/`.
- Causa de muerte en 1970, 1971, 1973 y 1978 a nivel nacional (interpolada en el script 30; LAMBdA causa-19 cubriría 1978 si se usa).
- Omisión censal por edad y sexo en 1985-2018: solo se conocen los totales de las conciliaciones DANE.
