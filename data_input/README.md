# Input data

## Mapa de fuentes: de dónde sale cada cosa (resumen en español)

Registro completo: `documents/inventory/fuentes.csv` (fuentes) y `documents/inventory/archivos.csv` (archivos, con uso y script);
`output/tables/data_catalog_files.csv` trae el sha256 y el estado en git. Los PDF están en `dane_pdfs/`, no se versionan y se bajan de
`https://biblioteca.dane.gov.co/media/libros/<nombre>.PDF`. Desde el 2026-11-24 `dane_pdfs/` guarda solo los PDF de los que salen
datos extraídos (19); la colección completa (952 PDF, entre ellos los anuarios 1915-1931 de las series `col_gap_analysis_*`) está en
el proyecto `dane_biblioteca`, en `D:\data\colombia\dane_pdfs` y en las releases de su repositorio en GitHub.

| Carpeta o archivo | Qué es | Fuente y PDF de origen |
|---|---|---|
| `micro/` | defunciones no fetales 1979-2023, un archivo por año | DANE, Estadísticas Vitales (microdatos.dane.gov.co); diccionarios en `documents/metadata/` |
| `DANEpop/` | población municipal por área, sexo y edad simple 1985-2042 | DANE, proyecciones (xlsx) |
| `lifetables/tablas_utf8.txt`, `reference/dane_lifetables_nmx_1985_2020.csv` | tablas abreviadas nacionales y departamentales 1985-2020 | `dane_pdfs/estudios/estudios_postcensales_08.pdf` |
| `historical/col_gap_analysis_1920_1985_*.csv` | muertes, homicidios y población 1905-1985 (nacional, departamental, municipal) | transcripciones de los anuarios `LD_70104_*` (1915-1931, en la colección `dane_biblioteca`, no aquí) y `LD_70106_1968_1969` y de boletines `BOL_*` |
| `historical/dane_vitales_1958_1960_*.csv` | población y estadística vital departamental y municipal 1958-1960 | `dane_pdfs/vitales/LD_558_1958_1960_EJ_2.pdf` |
| `historical/dane_defunciones_1968_1969_*.csv` | defunciones por sexo y edad, 31 secciones | `dane_pdfs/anuarios/LD_70106_1968_1969_EJ_3.pdf` |
| `historical/dane_defunciones_1970_1978_*.csv` | cuadros 1, 2, 3, 6, 10 y 11 | `dane_pdfs/vitales/LD_8789_1970_1978_EJ_3.pdf` |
| `historical/dane_defunciones_1965_1967_*` | defunciones por sección del país, sexo y edad 1965-1967 | `dane_pdfs/anuarios/LD_70104_1965_EJ_3.pdf` y `LD_70104_1966_1967_EJ_3.pdf`; script `code/historical/33` |
| `historical/dane_causas_violentas_*` | defunciones por causas violentas, sexo y sección 1951-1957 | `dane_pdfs/anuarios/LD_70104_1951_1952_EJ_2.pdf` a `LD_70104_1957_EJ_2.pdf`; script `code/historical/32` |
| `historical/census_tables/` | tablas de los censos 1938, 1951, 1964 y 1973 | `dane_pdfs/censos/1938/LD_771_1938_V_1.pdf`, `1951/LD_771_1951.pdf`, `1964/LD_771_1964.pdf`, `1973/LB_771_1973.pdf`; muestra de 1973: `1973/LD_1007_1973_EJ_4.pdf` |
| `historical/dane_conciliacion_1985_2005_*.csv` | tablas de vida 1985, 1993, 2005 y quinquenales, e0, mortalidad infantil, factores de ajuste y omisión de defunciones | `dane_pdfs/censos/5Mortalidad85_05.pdf` (cuadros 3.3, 3.13, 3.14 y anexos 1 a 4; scripts `code/historical/31a-d`) |
| `historical/lambda_Col_*.txt` | defunciones, población y tablas de vida | LAMBdA (documentación en `reference/LAMBdA_documentation.pdf`) |
| `historical/Homicidio 1962-2002 por depto de Policía_v1.xlsx` | homicidios por departamento de Policía | Policía Nacional |
| `dane_pdfs/censos/*.xlsx` | proyecciones DANE nacionales 1950-2070 y departamentales 1985-2050 | DANE, proyecciones; catalogadas, sin extraer |
| `reference/who*`, `who_mdb/` | homicidios y causas por edad y sexo 1953-1977 | OMS, Mortality Database |
| `reference/wpp2024_*`, `251208_MortalityCrises.zip` | población, fecundidad, tablas de vida y mortalidad por crisis | Naciones Unidas, WPP 2024 |
| `reference/unigme2024_*`, `nrc1982_*`, `trussell_*`, `coale_demeny_*`, `romero_meisel_2019_*` | mortalidad en la niñez, tablas de vida de 1982, modelos y muertes violentas 1945-1969 | UN IGME 2024; National Research Council 1982; Manual X (paquete `u5mr`); Romero-Prieto y Meisel-Roca 2019 |
| `census_raw/`, `reference/undata_*` | censos 1951-2018 por edad y sexo; nacidos en el extranjero | UNdata |
| `migration/*.xlsx` | stock de migrantes por edad y sexo | UN DESA, International Migrant Stock 2020 y 2024 |
| `migration/dane_internal/bol314_*.csv` | migración interdepartamental 1964-1973 (cuadros 6, 10-15) | `dane_pdfs/boletines/BOL_314_1977-141.pdf`; script `code/historical/29` |
| `migration/dane_internal/epc07_*.csv` | saldo neto migratorio y migración a 5 años, censo 2005 | `dane_pdfs/estudios/estudios_postcensales_07.pdf`; script `code/historical/28` |
| `conflict/`, `ucdp/` | homicidios del conflicto 1985-2018; eventos georreferenciados | JEP-CEV-HRDAG; UCDP GED 25.1 |
| `reference/DIVIPOLA-*.csv` | códigos de municipios | DANE, DIVIPOLA |

### PDF de `dane_pdfs/` y qué se sacó de cada uno

Solo están los PDF de los que salen datos del proyecto. Los demás (sin extraer, o fuente de las series
`col_gap_analysis_*`) se sacaron el 2026-11-24 y siguen en la colección `dane_biblioteca`.

| PDF | Contenido | Extraído a |
|---|---|---|
| `censos/1938/LD_771_1938_V_1.pdf`, `1951/LD_771_1951.pdf`, `1964/LD_771_1964.pdf`, `1973/LB_771_1973.pdf` | resúmenes de los censos | `historical/census_tables/` |
| `censos/1973/LD_1007_1973_EJ_4.pdf` | muestra de avance del censo de 1973 | `historical/census_tables/census_1973_muestra_*.csv` |
| `censos/5Mortalidad85_05.pdf` | conciliación censal, mortalidad 1985-2005 | `historical/dane_conciliacion_1985_2005_*.csv` |
| `vitales/LD_558_1958_1960_EJ_2.pdf` | estadística vital 1958-1960 | `historical/dane_vitales_1958_1960_*.csv` |
| `vitales/LD_8789_1970_1978_EJ_3.pdf` | registro de defunciones 1970-1978 | `historical/dane_defunciones_1970_1978_*.csv` |
| `anuarios/LD_70104_1951_1952_EJ_2.pdf`, `1953_EJ_2`, `1954_EJ_2`, `1955_EJ_2`, `1957_EJ_2` | anuarios generales de estadística | `historical/dane_causas_violentas_dept_1951_1964.csv` |
| `anuarios/LD_70104_1965_EJ_3.pdf`, `LD_70104_1966_1967_EJ_3.pdf` | anuarios generales de estadística | `historical/dane_defunciones_1965_1967_secciones_sexo_edad.csv` |
| `anuarios/LD_70106_1968_1969_EJ_3.pdf` | anuario demográfico 1968-1969 | `historical/dane_defunciones_1968_1969_*.csv` |
| `boletines/BOL_314_1977-141.pdf` | boletín 314, migración interdepartamental | `migration/dane_internal/bol314_*.csv` |
| `estudios/estudios_postcensales_07.pdf` | estudios postcensales n.º 7 | `migration/dane_internal/epc07_*.csv` |
| `estudios/estudios_postcensales_08.pdf` | tablas de mortalidad 1985-2020 | `lifetables/tablas_utf8.txt` |

## Detalle (inglés)


None of these files are versioned. Place them as below; script 01 expects
exactly the 45 files listed in `micro/`.

## micro/ (DANE EEVV, defunciones no fetales, 1979-2023)

Download from DANE's microdata catalogue, https://microdatos.dane.gov.co
(Estadísticas Vitales, Defunciones no fetales, one file per year).
Dictionaries are in `documents/metadata/`.

| file | bytes |
|---|---|
| Defun1979.txt | 4968113 |
| Defun1980.txt | 5650898 |
| Defun1981.txt | 6277838 |
| Defun1982.txt | 6195623 |
| Defun1983.txt | 6313253 |
| Defun1984.txt | 6173618 |
| Defun1985.txt | 6927728 |
| Defun1986.txt | 6585683 |
| Defun1987.txt | 6838178 |
| Defun1988.txt | 6888128 |
| Defun1989.txt | 6961343 |
| Defun1990.txt | 6960938 |
| Defun1991.txt | 7366253 |
| Defun1992.txt | 8890434 |
| Defun1993.txt | 8938368 |
| Defun1994.txt | 8934168 |
| Defun1995.txt | 9004415 |
| Defun1996.txt | 9195865 |
| Defun1997.txt | 9332447 |
| Defunciones 1998.txt | 19472282 |
| Defunciones_1999.txt | 20608162 |
| Defunciones_2000.txt | 23324715 |
| Defunciones_2001.txt | 24244415 |
| Defunciones_2002.txt | 24335638 |
| Defunciones_2003.txt | 24319617 |
| Defunciones_2004.txt | 23972210 |
| Defunciones_2005.txt | 24121859 |
| Defunciones_2006.txt | 24870190 |
| Defunciones_2007.txt | 25247079 |
| Defun_2008.txt | 36981185 |
| Defun_2009.txt | 38350992 |
| Defun_2010.txt | 42477168 |
| Defun_2011.txt | 45990164 |
| Defun_2012.txt | 47415969 |
| Defun_2013.txt | 48908425 |
| Defun_2014.txt | 49403024 |
| Defun_2015.txt | 51669592 |
| Nofetal_2016.txt | 53650053 |
| nofetal2017.csv | 36235677 |
| nofetal2018.csv | 37540563 |
| nofetal2019.csv | 35605603 |
| nofetal2020.csv | 72718654 |
| nofetal2021.csv | 89063048 |
| nofetal2022.csv | 69771386 |
| nofetal2023.csv | 65288762 |

## DANEpop/ (municipal population projections 1985-2017)

DANE, Proyecciones de población, municipal by area, sex and age:
`DCD-area-sexo-edad-proypoblacion-Mun-1985-1994.xlsx`,
`DCD-area-sexo-edad-proypoblacion-Mun-1995-2004.xlsx`,
`DCD-area-sexo-edad-proypoblacion-Mun-2005-2017_VP.xlsx`.

## ucdp/ (historical module only)

`GEDEvent_v25_1.csv` and `GEDEvent_v25_01_25_12.csv`, from
https://ucdp.uu.se/downloads/ (UCDP GED global version 25.1 and the
January-December 2025 monthly release).

## conflict/ (versioned)

`mse_national_age5_1985-2018.rds`: the JEP-CEV-HRDAG multiple-systems
estimates of conflict homicides and enforced disappearances, national, by
year, sex and 5-year age group (mean and 95 % interval over 10 replicates x
1,000 draws), summarised by `code/21_census_who_inputs.R` from the draws of
the `colombia_bereavement_pdr` repository on the Drive.
`mse_documented_dept_1985-2018.csv` and `mse_regional_age5_1985-2018.csv`:
the caches of `code/51_mse_departments.R`, the documented conflict victims by
department and year (mean of the 10 verdata replicates, version 2) and the
mean of the MSE draws by natural region, year, sex and age; the replicates
(1.5 GB) and the draws stay in that repository.

## reference/ and historical/ (versioned)

`reference/`: DIVIPOLA municipality codes (DANE, March 2026); UNdata census
tables; the WPP 2024 Colombia extracts written by `code/31_wpp_lifetables_inputs.R`
from the full WPP downloads kept outside the repository
(`wpp2024_colombia_lt_complete_1950-2100.csv`, complete life tables by sex,
estimates and medium-variant projections; `wpp2024_colombia_pop_single_age_1950-2023.csv`;
`wpp2024_colombia_pop_1jan_single_age_1950-2024.csv`, population at 1 January by
single age and sex extracted by `code/37_reconstruction_ccmpp.R`;
`wpp2024_colombia_fertility_age1.csv`, age-specific fertility 1950-2100) and the
crisis-mortality extracts of `code/26_wpp_crises_inputs.R`.
`trussell_child_mortality_coefficients.csv` (coefficients of the child
mortality multipliers k(i) and of the time reference t(i), UN 1983 Manual X,
tables 47 and 48) and `coale_demeny_child_q_by_level.csv` (q(1) … q(20) by
level of the Coale-Demeny model life tables, four families, by sex), both
taken from the R package `u5mr` 0.1.1 (archived on CRAN) and read by
`code/43_child_mortality_census1973.R`.
`romero_meisel_2019_violent_deaths_1945_1969.csv`: violent deaths by sex
1945-1969 estimated from censuses, vital records and life tables by
Romero-Prieto and Meisel-Roca (2019, *Análisis demográfico de la Violencia
en Colombia*, Cuadernos de Historia Económica 50, Banco de la República,
Cuadro 1), transcribed by hand: all violent deaths and the variant net of
the 1945-1947 level, with rates per 100,000; read by
`code/47_crisis_deaths.R` as a floor of the registered violent deaths.
`historical/census_tables/`: population tables extracted from the 1938, 1951,
1964 and 1973 census summary PDFs by `code/historical/23_census_tables_ocr.R`
(national single ages by sex 1938, 1964 and 1973; 5-year ages by sex and
department for 1938, 1951 and 1964, the last also by zone; coverage-adjusted
population by department and zone 1973; place of birth by place of
residence, sex and broad age group in 1964, the lifetime migration matrix
between departments (Cuadro 14);
women aged 15+ by children ever born and surviving in 1973, by age group and
by department), with the OCR grids, corrections and transcriptions in `ocr_support/`; see its
`README.md`. The PDFs themselves are kept in `dane_pdfs/censos/` (see the section on `dane_pdfs/` below); not versioned.
The same folder holds the **1973 muestra de avance** (`LD_1007_1973_EJ_4.pdf` in
`data_input/dane_pdfs/`, not versioned), read by
`code/historical/27_censo_1973_muestra_avance.R`:
`census_1973_muestra_single_age_sex_dept.csv` (population by sex and single age,
0-84 and 85+, for 22 departments and Bogotá D.E., plus the 23 sections added as
`cod_dpto` `00`; long format: `cod_dpto`, `department`, `sex`, `age`, `age_start`,
`population`) and `census_1973_muestra_age5_sex_dept.csv` (the same by 5-year age
group, same layout as the 1964 file plus `cod_dpto`; the national block also by
zone). **They are sample-expanded figures, not the final census count**: one
private household in 25 (28 in Bogotá) expanded, without collective households,
armed forces, indigenous population or any intendencia or comisaría (19.7 million
persons against 20.67 million censused and 22.49 million adjusted for the same 23
sections), so every cell is a multiple of 25 (28 in Bogotá) and small cells carry
a sampling error of 10-25 % or more. This is the only 1973 population by age and
department. The 1973 national single-age table of the resumen
(`census1973_single_age_sex.csv`) is compared with it by age in
`ocr_support/compare_1973_census_vs_muestra_single_age.csv`.
`historical/dane_vitales_1958_1960_*.csv`: DANE "Estadística vital 1958 a
1960" (1962) read from the library scan `LD_558_1958_1960_EJ_2.pdf` (not
versioned) by `code/historical/24_dane_vitales_1958_1960.R`: the departmental
table (population, marriages, baptisms, deaths, infant deaths, 16 departments
by year) and the municipal tables (marriages; baptisms, infant deaths and
deaths by sex; 828-872 municipalities, intendencias and comisarías per year,
with DIVIPOLA codes). Every municipal column was checked against its unit
TOTAL and the departmental table; `vitales_1958_1960_support/` holds the
manual corrections, the rows read by eye and the verification reports
(`verification_unit_columns.csv`, `differences_vs_col_gap_analysis.csv`). The
column `flag` marks the few units whose printed figures do not add up and
`nodata_in_source` the cells printed as "..." (no information).
`historical/dane_defunciones_1970_1978_*.csv`: six tables of DANE/UNICEF
"Registro de defunciones en Colombia, 1970-1978" read from the library scan
`LD_8789_1970_1978_EJ_3.pdf` (not versioned) by
`code/historical/25_dane_defunciones_1970_1978.R`: `cuadro01` registered
deaths, national, 1915-1984; `cuadro02` deaths by sex and sección, 1970-1984
(with the printed under-registration marks); `cuadro03` national deaths by
zone, sex and age group, 1970-1978; `cuadro06` national deaths by age group,
sex and cause (ICD-8 list A, 134-139 causes per year), 1973-1978; `cuadro10`
deaths under five by detailed age and sex, by sección, 1970-1978; `cuadro11`
deaths by sex and age group, national and by sección, 1970-1978. Secciones
are 22 departments, Bogotá D.E. and "Intendencias y comisarías" pooled; ages
are under 1 day, 1-6 and 7-29 days, 1-5 and 6-11 months, 12-23 months, 2-4,
5-9 ... 80-84, 85+ and not stated. All cells are tied by 47,874 accounting
identities, within and between tables; `dane_defunciones_1970_1978_support/`
holds the manual readings, the cells corrected (`cells_corrected.csv`), the
misprints of the print (`misprints_in_source.csv`) and the 112 identities
the printed source itself does not satisfy (`source_inconsistencies.csv`,
left as printed).
`historical/dane_defunciones_1968_1969_secciones_sexo_edad.csv`: deaths by sex
and age group for the 31 secciones and the national total (`Total nacional`,
cod_dpto 00), 1968 (Cuadro 30) and 1969 (Cuadro 76), from the DANE Anuario de
Estadísticas Vitales 1968-1969 (library scan `LD_70106_1968_1969_EJ_3.pdf`,
not versioned), built by `code/historical/26_dane_defunciones_1968_1969.R`.
Columns `year, unit, cod_dpto, age, male, female, total`, with the same age
labels as `dane_defunciones_1970_1978_cuadro11_secciones_edad.csv` (`all`,
under 1 day, 1-6 and 7-29 days, 1-5 and 6-11 months, 12-23 months, 2-4, 5-9
... 80-84, 85+, not stated: the printed groups are the same), so the two files
stack. Unlike the 1970-1978 volume, the intendencias and comisarías are
printed one by one (Arauca, Caquetá, Putumayo, San Andrés y Providencia,
Amazonas, Guainía, Vaupés, Vichada; Putumayo is a comisaría in 1968 and an
intendencia in 1969) and are kept apart; to stack with 1970-1978 add them into
"Intendencias y comisarías". Putumayo 1968 prints no "Edad desconocida" row
(its 24 age rows add up to the total); it is 0. The national total equals
Cuadro 1 of the 1970-1978 volume (169.007 and 153.882) and the department rows
equal `col_gap_analysis_..._territories_split.csv` except Vaupés 1969 (here 7:
5 + 2, there 8: 5 + 3). Every cell is tied by total = men + women, age rows =
TOTAL row and secciones = TOTAL NACIONAL (2,012 identities);
`dane_defunciones_1968_1969_support/` holds the manual readings from 300-dpi
crops (`corrections.csv`), every cell not taken from the text layer
(`cells_corrected.csv`: 103 text-layer misreadings, 3 misprints of the print
listed in `misprints_in_source.csv`, 24 read by eye), the verification report
and the 12 identities the printed source itself fails
(`source_inconsistencies.csv`: Bolívar 1968 1-6 days and La Guajira 1968 85+,
men and women swapped in print; Guainía 1969, total row against its only age
row), left as printed. The cause tables (Cuadros 29 and 75) are not extracted.
`historical/`: series transcribed from DANE anuarios estadísticos and boletines
(`col_gap_analysis_1920_1985_*.csv`): deaths by department 1915-1984 (three
territorial variants), by municipality 1924-1960 and national 1923-1984;
homicides by department 1923-1965; census population by department
(1905-1973), municipality (1938-1964) and national (1905-1985). The files
whose name ends in `department_deaths_*`, `department_population_*`,
`national_deaths_*` and `national_population_*` are `;`-separated, the others
`,`-separated. `archive_v01_v02/` holds the previous transcription, read by no
script. Also LAMBdA extracts for Colombia (`lambda_Col_*.txt`) and the
Policía Nacional homicide series 1962-2002 (xlsx). See
`code/historical/README.md`.

## dane_pdfs/ (DANE library scans, not versioned)

`data_input/dane_pdfs/` holds only the DANE PDFs that project data are extracted from (19 PDFs, plus 6
projection xlsx in `censos/`), grouped by series. The other PDFs were removed on 2026-11-24; the full
collection (952 PDFs) is kept by the `dane_biblioteca` project (`D:/data/colombia/dane_pdfs` and the
GitHub releases of that repository). Catalogues: `documents/catalogo_dane_pdfs.md` (mortality) and
`documents/catalogo_migracion_interdepartamental.md` (migration) describe the earlier, larger set.

| folder | contents |
|---|---|
| `censos/1938/`, `1951/`, `1964/`, `1973/` | census summaries (`LD_771_*`, `LB_771_1973`) and the 1973 muestra de avance (`LD_1007_1973_EJ_4`); `5Mortalidad85_05` (1985-2005 reconciliation) |
| `anuarios/` | *Anuario General de Estadística* 1951-1957 and 1965-1967 (`LD_70104_*`), *Anuario demográfico* 1968-1969 (`LD_70106`) |
| `vitales/` | vital statistics: deaths 1958-1960 and 1970-1978 |
| `boletines/` | *Boletín Mensual de Estadística* 314 (interdepartmental migration) |
| `estudios/` | postcensal studies 7 (migration) and 8 (life tables) |

`reference/LAMBdA_documentation.pdf` is not a DANE publication and was moved to `reference/`.
Scripts read PDFs from these paths (`code/historical/23`-`30`); the three PDFs that used to be
duplicated in `historical/` (`LD_771_1964`, `LD_558_1958_1960_EJ_2`, `LD_8789_1970_1978_EJ_3`) exist only here.
