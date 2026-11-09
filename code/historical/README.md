# Historical module (1923-1984 series, WHO and UCDP comparisons)

Scripts, run from the project root, independent of `run_all.R`:

- `20_historic_data_coverage.R`: coverage of the transcribed DANE anuario series (homicides, deaths, population) by year, department and municipality, compared with WHO Mortality Database homicides.
- `21_historic_data_quality_tests.R`: internal consistency tests (total vs male + female, NAs coded as zeros, missing sex splits).
- `22_testing_ucdp.R`: UCDP GED v25.1 conflict deaths for Colombia against WHO homicides.
- `23_census_tables_ocr.R`: builds `data_input/historical/census_tables/` from the 1938, 1951 and 1973 census summary PDFs: tesseract grid OCR of the 1951 Cuadro 10 (department × 5-year age × sex, 1938 and 1951) reconciled by accounting identities plus manual corrections, and visual transcriptions of the 1938 and 1973 national single-age tables and of the 1973 coverage-adjusted population by department and zone. Runs from the versioned `ocr_support/` files; `run_ocr <- TRUE` repeats the OCR from the PDF. Stops if any identity fails. See `data_input/historical/census_tables/README.md`.

Inputs:

- `data_input/historical/census_tables/`: the four census csvs above and `ocr_support/` (OCR grids of both passes, `corrections_1951.csv`, `transcription_*.csv`). The PDFs `LD_771_1938_V_1.pdf`, `LD_771_1951.pdf` and `LB_771_1973.pdf` are not versioned (29 MB).
- `data_input/historical/col_gap_analysis_1920_1985_*.csv`: series transcribed from DANE anuarios estadísticos and boletines (versioned, CC-BY 4.0). Common columns `department`/`municipality`, `year`, `total`, `male`, `female`, `data_available`, `sex_disagg_available`, plus quality notes (`known_data_problem`, or `data_flag_dane_*` / `data_flag_collaborator_*` and `source_new` in the departmental deaths file).
  - `department_deaths_clean_v06.csv` (`;`-separated), 1915-1984, with two territorial variants: `_territories_aggregated` (25 units, intendencias and comisarías summed into their department of origin; the default in 20 and 21) and `_territories_split` (33 units). The aggregated sum matches the national file except in 1926, 1931, 1932, 1934 and 1956-1961 (Bogotá counted as its own row and inside Cundinamarca); 21 prints those years.
  - `department_homicides_clean_v02.csv` (`,`), 1923-1965. There is no national homicide file: 20 and 21 sum the departments with data in each year.
  - `department_population_clean_v03.csv` (`;`), censuses 1905-1973.
  - `municipal_deaths_clean_v03.csv` and `municipal_population_clean_v03.csv` (`,`), 1924-1960 and censuses 1938-1964.
  - `national_deaths_clean_v03.csv` and `national_population_clean_v02.csv` (`;`), 1923-1984 and 1905-1985. The national deaths file is also the anuario total used by `code/22_ddm_census_national.R`.
- `data_input/historical/archive_v01_v02/`: the previous transcription (October 2026), kept for reference and read by no script. Against it, the new files add 1915-1922, sex splits for 1923-1949, source and quality notes per cell, and fix transcription errors (e.g. Valle del Cauca 1979, 4,818 → 14,818; Santander 1947, 6,091 → 11,499).
- `data_inter/who_homicide_colombia.rds`, `data_inter/who_all_cause_colombia.rds`: extracts of the WHO Mortality Database. **No script in this repository produces them.** Convert them to CSV under `data_input/reference/who/` with a source note before publishing.
- `data_input/ucdp/GEDEvent_v25_1.csv`, `GEDEvent_v25_01_25_12.csv`: UCDP GED, not versioned (270 MB). Download from https://ucdp.uu.se/downloads/ and cite UCDP GED v25.1.

The source inventory of variables, years and known gaps is `documents/datos_mortalidad_colombia_03_2026.xlsx`.
