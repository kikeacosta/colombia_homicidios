# Historical module (1923-1984 series, WHO and UCDP comparisons)

Scripts, run from the project root, independent of `run_all.R`:

- `20_historic_data_coverage.R`: coverage of the transcribed DANE anuario series (homicides, deaths, population) by year, department and municipality, compared with WHO Mortality Database homicides.
- `21_historic_data_quality_tests.R`: internal consistency tests (total vs male + female, NAs coded as zeros, missing sex splits).
- `22_testing_ucdp.R`: UCDP GED v25.1 conflict deaths for Colombia against WHO homicides.

Inputs:

- `data_input/historical/*.csv`: series transcribed from DANE anuarios estadisticos (versioned, CC-BY 4.0).
- `data_inter/who_homicide_colombia.rds`, `data_inter/who_all_cause_colombia.rds`: extracts of the WHO Mortality Database. **No script in this repository produces them.** Convert them to CSV under `data_input/reference/who/` with a source note before publishing.
- `data_input/ucdp/GEDEvent_v25_1.csv`, `GEDEvent_v25_01_25_12.csv`: UCDP GED, not versioned (270 MB). Download from https://ucdp.uu.se/downloads/ and cite UCDP GED v25.1.

The source inventory of variables, years and known gaps is `documents/datos_mortalidad_colombia_03_2026.xlsx`.
