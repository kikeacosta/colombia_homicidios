# Input data

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
`historical/census_tables/`: population tables extracted from the 1938, 1951,
1964 and 1973 census summary PDFs by `code/historical/23_census_tables_ocr.R`
(national single ages by sex 1938, 1964 and 1973; 5-year ages by sex and
department for 1938, 1951 and 1964, the last also by zone; coverage-adjusted
population by department and zone 1973; place of birth by place of
residence, sex and broad age group in 1964, the lifetime migration matrix
between departments (Cuadro 14);
women aged 15+ by children ever born and surviving in 1973, by age group and
by department), with the OCR grids, corrections and transcriptions in `ocr_support/`; see its
`README.md`. The PDFs themselves (`LD_771_*.pdf`, `LB_*.pdf`, 35 MB) are kept
in `historical/` but not versioned.
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
