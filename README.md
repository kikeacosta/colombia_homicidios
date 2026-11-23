# Colombia mortality: homicides from the sex ratio of all-cause mortality

Can the male/female ratio of all-cause mortality predict municipal homicide
rates in Colombia, and why does it work well only after about 1998?

The idea: where violence is high, male mortality rises disproportionately, so
the all-cause sex ratio carries a signal of violent deaths even where cause
coding is poor. This repository builds a municipal model of violent deaths
1985-2017 on that signal, decomposes the sex ratio by cause of death, and
studies why the relationship breaks down in some departments before ~1998.

## Findings so far

The pre-1998 failure is a registration-completeness problem concentrated in
the Caribbean departments, not a cause-coding problem. Registered crude death
rates there ran at 1.7-2.8 per 1,000 in the late 1980s against 6.0-6.3 in
Antioquia, Bogotá and Santander, and a generalized growth balance puts adult
completeness at 0.20-0.51 in six Caribbean departments in 1985-95. Ill-defined
causes have a sex ratio near 1.1, not near the ~12 of homicide, so hidden
homicides do not explain the break. Details:
`documents/report_missing_deaths_caribbean_09_2026.html`.
Next steps (testing the under-registration hypothesis with DANE adjusted life
tables and the DDM package): `documents/plan_cleanup_and_underregistration.md`,
Plan B.

## Data

Not versioned (see `data_input/README.md` for the manifest and download links).

| Source | Years | Resolution | Used by |
|---|---|---|---|
| DANE, Estadísticas Vitales, defunciones no fetales (microdata) | 1979-2023 | individual deaths | 01 |
| DANE, municipal population projections by area, sex, age | 1985-2017 | municipality x year x sex x age | 03 |
| DANE, list 105 of causes (CIE-9 / CIE-10), `documents/` | 1979-2023 | code table | 00 |
| UCDP GED v25.1 | 1989-2025 | event | historical module |
| WHO Mortality Database extracts | 1950-- | country | historical module |
| DANE anuarios estadísticos, transcribed | 1923-1984 | department, municipality | historical module |

## Pipeline

Run from the project root with `Rscript run_all.R` (`Rscript` must be on the PATH; needs several GB of RAM for step 01). Packages: see the top of `code/00_setup.R`; `colmaps` comes from GitHub (`remotes::install_github("nebulae-co/colmaps")`). Tested with R 4.5.2.

| Script | What it does |
|---|---|
| `00_setup.R` | packages, age recode, cause crosswalk, municipal panel builder |
| `01_load_microdata.R` | reads the 45 yearly files, harmonises layouts |
| `02_summarise_deaths.R` | municipal death counts by sex (and age) |
| `03_population.R` | DANE projections to 5-year age groups |
| `04_descriptives.R` | national, department and municipal sex ratios vs homicide rates |
| `05_municipal_panel.R` | model inputs: sex ratios, violent-death rates |
| `06_excess_deaths.R` | all-cause excess deaths per municipality |
| `07_model_zinb.R` | zero-inflated negative binomial mixed model |
| `08_model_validation.R` | observed vs predicted, maps, level-match statistics |
| `09_sex_ratio_by_cause.R` | cause-specific decomposition of the sex ratio |
| `10_registration_completeness.R` | GGB completeness by department, sex, period |
| `11_shared_dataset.R` | municipal file of deaths by cause group and population, 1985-2023, for sharing |
| `11b_shared_dataset_age.R` | the same by 5-year age group (parquet) |
| `12_underregistration_test.R` | department-level test: correlation vs completeness |
| `13_extract_dane_lifetables.R`, `14_completeness_dane.R` | DANE conciliated life tables: implied completeness and expected sex ratio |
| `15_model_completeness.R` | municipal model with completeness |
| `16_age_placebo.R` | sex ratio at ages 50-79 (placebo) and 15-44 |
| `17_residence.R` | residence vs occurrence tabulation |
| `18_ddm_completeness.R`, `19_completeness_vs_correlation.R` | DDM completeness (GGB, SEG, hybrid) and its relation to the correlation |
| `60_homicide_backcast_dept.R` | prototype: state-space model of departmental homicides 1915-2019 (15 stable units) combining the sex ratio of deaths, anuario homicides, Policía and EEVV; hidden-block validation |
| `61_homicide_munic_1958_1960.R` | prototype: municipal split of the 1958-1960 unit homicides from the sex ratio of deaths over age one, with the shrinkage weight calibrated on EEVV under 1958-60 conditions |
| `62_homicide_underregistration.R` | prototype: from registered to total homicides by unit, 1950-2019. Tests the two conventions for violent deaths against the Policía, builds a completeness index by unit before 1985 and gives four scenarios |
| `63_backcast_predictive_plots.R` | figure only: redraws the predictive check of 60 (observed against predicted homicides by unit in the hidden blocks, and the readings of 1966-1978) from the tables 60 saves, without fitting the model, for four units and for all 15 units in four pages; units, variants, rate or count and scale are options at the top |
| `64_homicide_benchmark_simple.R` | benchmark: a negative binomial mixed model that distributes the national total of homicides among the units with the sex ratio (the municipal model of 07 one level up), against the state-space model of 60 in the same hidden blocks and with the same information |
| `70_intl_model_functions.R` | functions only (sourced by 72): the core of the state-space model of 60 for any panel of deaths by unit, year, sex and cause, the hidden-block validation and the simple benchmark of 64 |
| `71_intl_brazil_panel.R` | Brazil: deaths by state, year, sex, age band and cause group, 1979-2020, aggregated from the SIM microdata read in place from `D:/data/brazil_mortality` (1979-1989: national DATASUS `.dbc` files, read with `microdatasus`); Tocantins kept within Goiás so that the 26 units are stable (nothing is copied into the project) |
| `72_intl_validation.R` | validation of the sex-ratio model by state outside Colombia: hidden interior blocks and a 15-year backcast, with deaths of all ages and of ages 15-44, state-space model against the simple benchmark; Colombia 1979-2019 through the same code as a reference |
| `73_intl_mexico_panel.R` | Mexico: deaths by state, year of occurrence, sex, age band and cause group, 1990-2025, from the INEGI dbf files of every year of registration in `D:/data/mexico_mortality` (files by year of registration, re-sorted by year of occurrence; state of occurrence where the residence is unknown) |
| `74_intl_us_panel.R` | United States: deaths by state, year, sex, age band and cause group, 1968-2004, streamed from the NCHS public-use zips in `D:/data/us_mortality` (the public files carry no state from 2005); column positions checked against the published national totals |
| `79_intl_spain_deaths_figure.R` | figure only: Spain 1936-1942, sex ratio of registered deaths by province, from the INE volumes transcribed into `data_input/reference/spain_ine_deaths_province_sex_1933-1946.csv` (checked: men + women = total, provinces = printed totals) |
| `80_intl_spain_excess_male.R` | Spain 1936-1946: violent deaths by province and year estimated from the male deaths above the pre-war (1933-1935) sex ratio, with the share of men among the victims at 0.95 (0.90 as sensitivity) and a range from the peace-year variation |
| `81_intl_spain_literature_check.R` | Spain: the estimate of 80 against the published counts by province (Salas 1977, registered war deaths and Nationalist-zone executions; Espinosa 2008, documented repression) and the national excess deaths of men and women of Ortega and Silvestre (2005); sources in `data_input/reference/spain_literature_deaths_province.csv` and its `_notes.md` |
| `76_intl_us_wonder_panel.R` | United States 1968-2020 by state and year for 72: microdata of 74 to 2004 and CDC WONDER tables from 2005 (state totals of violent deaths without sex, so that no suppressed count can be derived); narrow definition of violent deaths (no undetermined intent); states with suppressed counts dropped |
| `77_intl_ecuador_panel.R` | Ecuador: deaths by province, year, sex, age band and cause group, 1990-2024, from the INEC SPSS files in `D:/data/ecuador_mortality`; the provinces created after 1990 stay within their province of origin (21 stable units) |
| `75_intl_brazil_top4_figure.R` | figure only: observed and predicted violent deaths in the four Brazilian states with the highest share of violent deaths |
| `experimental/model_spatial.R` | spatial random-effect variant (not used for results) |
| `historical/` | 1923-1984 series, WHO and UCDP comparisons; see its README |

## Model

The dependent variable is violent deaths (DANE list 105 codes 101 homicide,
102 undetermined intent, 103 legal intervention) per municipality-year. The
model is a negative binomial with zero inflation, with log population as
offset and random intercepts for department and municipality. Covariates:
log all-cause sex ratio, log excess all-cause mortality, the department
violent-death rate interacted with the municipality's population share, and
a standardised all-cause crude death rate. Predictions are rescaled so
municipal totals match department totals each year.

## Completeness analysis

Generalized growth balance (Hill 1987) by department, sex and 10-year window,
plus an annual coverage index (natural-cause age-standardised rate relative to
the national one) anchored to the GGB levels. Caveats: GGB assumes no net
migration; population is DANE's projection, not a census count, so the result
is completeness relative to that projection.

## Outputs

- `output/deaths_pop_munic_1985_2023.csv.gz`: deaths by cause group (all causes, homicide, undetermined intent, legal intervention, suicide, accident, residual) and population by year, municipality and sex. **Start here if you only need the data.** Read `output/deaths_pop_munic_dictionary.md` first.
- `output/homicide_estimates_munic_1985_2017.csv.gz`: observed and model-estimated violent deaths and rates by municipality-year, with prediction intervals.
- `output/tables/completeness_ggb.csv`, `completeness_deptos.csv`: death-registration completeness by department.
- `figures/`: figures produced by the scripts.

## Known limitations

- Deaths are tallied by place of occurrence and population by residence.
- Department-level completeness is a floor on the correction; municipal
  completeness varies within departments.
- The 1998 death certificate and ICD-10 introduction coincide with the
  coverage jump, so the two cannot be separated with these data alone.

## Licence and citation

Code: MIT (`LICENSE`). Derived tables, figures and transcribed historical
series: CC-BY 4.0 (`LICENSE-DATA`). Cite as: Acosta E. Colombia mortality:
homicides from the sex ratio of all-cause mortality. 2026.
