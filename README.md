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
