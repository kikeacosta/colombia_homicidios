# deaths_pop_munic_1985_2023.csv.gz

One row per year x municipality x sex (1985-2023, 1,123 municipalities, 87,594 rows).
Built by `code/11_shared_dataset.R`. Licence CC-BY 4.0.

| column | description |
|---|---|
| year | calendar year of registration (`ANO` in the EEVV files) |
| sex | `m` or `f` |
| cod_dpto, dpto | department code (2 digits) and name |
| cod_munic, munic | DIVIPOLA municipality code (5 digits) and name |
| pop | population of that sex, all ages, DANE |
| dx_all | all-cause deaths |
| dx_homicide | list 105 code 101, assault |
| dx_undetermined | code 102, event of undetermined intent |
| dx_legal | code 103, legal intervention and operations of war |
| dx_suicide | code 100 |
| dx_accident | codes 90-99 and 104-105: transport, falls, drowning, poisoning, other external accidents |
| dx_residual | everything else: natural causes (1-88), ill-defined (89) |

`dx_all` equals the sum of the six cause columns in every row. A "violent deaths"
series as used in the model is `dx_homicide + dx_undetermined + dx_legal`.

## Sources

- Deaths: DANE, Estadísticas Vitales, defunciones no fetales, microdata
  1979-2023, cause group from DANE's list of 105 causes (`cau_homol`),
  ICD-9 until 1997 and ICD-10 from 1998.
- Population 1985-2017: DANE retroprojections on the 2018 census base
  (`DCD-area-sexo-edad-proypoblacion-Mun-*`), versions of 8 Aug 2025 for
  2005-2017.
- Population 2018-2023: DANE `PPED-AreaSexoEdadMun-2018-2042_VP`, version of
  8 Aug 2025 (technical note `NotaTecnica-PPED-jul2025.pdf`). National totals
  are continuous across 2017 and 2018 (47.4 and 48.3 million).

## Read this before using the file

1. **Occurrence vs residence.** Deaths are by place of occurrence, population
   by place of residence. Municipalities with hospitals receive deaths of
   residents of neighbouring municipalities, so small-area rates can be
   biased in both directions.
2. **Under-registration before ~1998.** Registered death rates in the
   Caribbean departments are implausibly low until the 1998 certificate
   (completeness of adult deaths about 0.2-0.5). All-cause and cause-specific
   counts there are floors, not levels. See the repository README.
3. **Cause-coding breaks at 1998.** ICD-9 to ICD-10 and a new certificate.
   Suicides roughly double between 1997 and 1998 (1,266 to 2,113), and
   undetermined-intent deaths change level. Do not read these as real trends.
4. **COVID-19.** 2020-2021 excess deaths are in `dx_all` and `dx_residual`.
5. **Dropped deaths.** 1,502 of 7,758,616 deaths (0.02 percent) are not in
   the file: 1,101 with unknown sex and 404 coded to a municipality absent
   from the population files (e.g. 99999), with some overlap.
6. **Municipality 27493** (Nuevo Belén de Bajirá) exists from 2018; its rows
   before 2018 have `pop = NA` and zero deaths.
7. Population by 5-year age group is not in this file.

---

# deaths_pop_munic_age_1985_2023.parquet

Same data with age detail: one row per year x municipality x sex x age group
(1,751,880 rows, 5.3 MB, zstd-compressed parquet). Built by
`code/11b_shared_dataset_age.R`. Read with `arrow::read_parquet()` (R),
`pandas.read_parquet()` (Python) or DuckDB.

Same columns as the file above, plus:

| column | description |
|---|---|
| age | lower bound of the age group (0, 1, 5, 10, ..., 85); missing for unknown age |
| age_group | `0`, `1-4`, `5-9`, ..., `80-84`, `85+`, or `unknown` |

- Population by age is available for every year 1985-2023: 1985-2017 from
  DANE's retroprojections, 2018-2023 from single ages 0-100+ of the PPED
  workbook, grouped here.
- `unknown` rows carry deaths whose age was not recorded (about 1 percent of
  deaths, mostly before 1998) and no population (`pop` missing).
- The 85+ group joins ages 85-100+, because the older microdata stop at 85+.
- Totals by year and sex of deaths and population equal the municipal file
  exactly (checked when the file is built).
- Age-group boundaries are the DANE age groups of the microdata; the 0 and
  1-4 groups are kept apart because infant deaths are the main
  under-registration signal.
