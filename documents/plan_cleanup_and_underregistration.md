# colombia_mortalidad: evaluation, cleanup plan, under-registration plan

Date: 2026-10-13. Nothing was executed; this is a read-through of the 18 scripts,
the data folders, the figures and the September 2026 report.

---

## 1. Pipeline as it stands

```
data_input/micro/*.txt|csv (45 files, 1.1 GB, DANE EEVV 1979-2023)
  -> 01_loading_microdata.R -> data_inter/micro_1979_2023.rds           [STALE: predates age fix]
       -> 02_summarizing_microdata.R -> deaths_munic_1979-2023.rds        [no age column]
       -> 11_sex_ratio_decomp_by_cause.R   (reads micro directly)
       -> 12_registration_completeness.R   (reads micro directly, recomputes age)
data_input/DANEpop/*.xlsx (3 of 4 used)
  -> 03_population.R -> pop_munic_1985-2017.rds (190 MB, uncompressed)

deaths + pop ->
   04_rates.R                BROKEN  needs `age`/`dx` that 02 no longer emits; only ASDR code in project
   05_sex_ratios_deptos.R    dept part OK; municipal block BROKEN (`dptos` undefined)
   descriptive_homics.R      older copy of 05 (same figure names)
   06_sex_ratios_munic.R  -> sex_ratios_munic_1985-2017.rds, homicide_cdr_munic_1985-2017.rds
   07_excess_deaths.R     -> excess_deaths_munic.rds

06 + 07 ->
   08_model_glmmTMB.R      -> homicide_estimates_1985-2017.rds            [SUPERSEDED]
   08_model_glmmTMB_exc.R  -> homicide_estimates_1985-2017_excs.rds       [CURRENT model]
08_exc -> 09_model_validation.R -> figures/*_exc.*
08     -> 10_model_spatial.R    -> homicide_estimates_1985-2017_spatial.rds  [plot block BROKEN, built on superseded input]

Side project (1923-1984 anuarios, WHO, UCDP):
   data_input/historical/*.csv + data_inter/who_*.rds (NO producer script) -> 20, 21, 22
   data_input/ucdp/*.csv (270 MB) -> 22
```

Dependent variable throughout: `dx_v` = codes 101 (homicide) + 102 (undetermined intent)
+ 103 (legal intervention), from DANE list 105 (`cau_homol`). Geography is place of
occurrence (`cod_dpto`/`cod_munic`), population is place of residence.

### 1.1 Script-level verdicts

| Script | Verdict | Notes |
|---|---|---|
| 00_setup.R | keep, extend | `recode_age_group()` lives here. Add the cause crosswalk and the municipal-panel builder. Replace the pacman auto-install with renv or a plain documented list; `colmaps` is GitHub-only. |
| 01_loading_microdata.R | keep | Sep 2026 age fix not yet propagated to the .rds. |
| 02_summarizing_microdata.R | keep, fix | Must emit an age-disaggregated table too (04 needs it; .Rhistory shows you hand-ran such a variant on 16 Sep and never saved it). |
| 03_population.R | keep | Write .rds with `compress = "xz"`; 190 MB is just uncompressed strings. |
| 04_rates.R | fix or fold into 05 | Only place with age-standardised rates. Its figures are all in `figures/old`. Needed for the under-registration work (ASDR), so fix. |
| 05_sex_ratios_deptos.R | keep dept part, delete munic block | Munic block duplicates 06 and errors. |
| descriptive_homics.R | **delete** | Verbatim earlier copy of 05 lines 1-250. |
| 06_sex_ratios_munic.R | keep | Shares ~70 lines with 07 (cdr_munic construction). Factor out. |
| 07_excess_deaths.R | keep | Same duplication as above. |
| 08_model_glmmTMB.R | **delete** | Superseded by _exc (AIC 179055 -> 178726 per in-file notes). Keep the AIC comparison comments: move them to the _exc script or a `model_selection.md`. |
| 08_model_glmmTMB_exc.R | keep, trim | Delete the "trying in a different period" block (lines ~190-273): `mod` undefined, `cdr_h_dpto_lag` never built. Dead code. |
| 09_model_validation.R | keep | Works against _excs. |
| 10_model_spatial.R | experimental or delete | Reads superseded input; plot uses commented-out CI columns -> errors. Never fed results. Decide. |
| 11_sex_ratio_decomp_by_cause.R | keep, fix | Line 48 `drop_na(dpto)` on a table with no `dpto` -> error. `cont_pos_per` plotted before `dt5` is redefined to contain it. Interactive `copy_this()` calls. Reorder into: data, decomposition, plots. This is the cause-of-death analysis you want to keep. |
| 12_registration_completeness.R | keep | Sound, documented. Seed for the under-registration work. |
| 20/21/22 | keep as a separate module (or repo) | Different question (coverage of 1923-1984 series). `who_*.rds` have no producer script. |

### 1.2 Cross-cutting defects

1. **Cause crosswalk defined four times, inconsistently.** 01: 103 = "legal" (own class). 02: `dx_v` = 101+102+103. 11: homicidio = 101+103, 102 separate. 12: natural = 1:88. Define once in 00_setup.R.
2. **Stale intermediates.** `micro_1979_2023.rds` (7 Mar) predates the age recode fix in 01 (16 Sep). `deaths_munic_1979-2023.rds` (23 Mar) predates 02 (24 Apr). Anything that used `edad` from the .rds (11 especially) used ages shifted by one 5-year band for 1979-1997. Everything in `data_inter/` must be treated as regenerable, not canonical.
3. **Occurrence vs residence.** Deaths are tallied by place of occurrence; population by residence. The stray `variables-03-04-26-053051.csv` in the root is the DANE metadata entry for exactly this (`cod_dpto`: "Departamento donde ocurrió la defunción"). EEVV files carry residence codes too (check `CODPTORE`/`CODMUNRE` in `documents/metadata/`). This matters for municipal rates and for GGB (see section 3).
4. `.Rproj` has `SaveWorkspace: Default`; set to `No`.

---

## 2. Data and figure disposition

### data_input (keep locally, gitignore; commit only small public reference files)

| Path | Size | Used by | Disposition |
|---|---|---|---|
| micro/ (45 files) | 1.1 GB | 01 | local only. README with DANE microdata URL + file manifest. |
| DANEpop/ 3 xlsx 1985-2017 | 140 MB | 03 | local only; document download. |
| DANEpop/PPED 2018-2042 | 131 MB | nobody (commented out) | delete or archive. |
| gadm41_COL_2.shp + .zip | 88 MB | nobody (maps use `colmaps::municipios`) | **delete**. A lone .shp without .shx/.dbf is unusable anyway. |
| ucdp/ 2 csv | 270 MB | 22 | local only; cite UCDP GED v25.1. |
| DIVIPOLA csv | 82 KB | nobody (only .Rhistory) | commit under `data_input/reference/` if you adopt it for names; else delete. |
| historical/ 6 csv | 1.2 MB | 20, 21 | commit if the side project stays. |

### data_inter (gitignore all; publish a few small finals as CSV)

| File | Size | Disposition |
|---|---|---|
| micro_1979_2023.rds | 40 MB | regenerate; never commit |
| pop_munic_1985-2017.rds | 190 MB | regenerate compressed; never commit |
| deaths_munic_1979-2023.rds | 3.5 MB | regenerate |
| homicide_estimates_1985-2017.rds | 15 MB | **delete** (superseded model) |
| homicide_estimates_1985-2017_spatial.rds | 12 MB | **delete** unless 10 is kept |
| homicide_estimates_1985-2017_excs.rds | 16 MB | key result; publish as `output/homicide_estimates_munic_1985_2017.csv.gz` or a GitHub release asset |
| homicide_cdr_munic, sex_ratios_munic, excess_deaths_munic | 4 + 3 + 11 MB | regenerate |
| completeness_ggb.rds, completeness_deptos.rds | 20 + 174 KB | publish as CSV in `output/tables/` |
| who_homicide_colombia.rds, who_all_cause_colombia.rds | 3 + 3 KB | **orphans, no producer**. Convert to CSV in `data_input/who/` with a source note, or add the extraction script. |
| q_test/*.csv | 0.8 MB | regenerate (outputs of 21 and 12) |

### figures

| Path | Disposition |
|---|---|
| figures/old/ (43 files, 56 MB) | **delete** (04 clouds, descriptive, predict_v1..v7, spatial) |
| figures/res_v1/ (21 files, 121 MB) | **delete** or zip outside the repo (non-exc model results) |
| figures/mapa_comp_yrs*_exc.pdf (3 x 37 MB), predict_excs.pdf, excess_deaths_munic.pdf | gitignore `*.pdf`; regenerate on demand |
| figures/*_exc.png, completeness_*.png, contrib_*.png, ratio_homs_ext.png, homicides_ucdp_vs_who.png | keep as current figures |
| figures/historical/homicides_municipal.pdf | 0 bytes (failed save) -> delete |
| figures/historical/*.png | keep with side project |

### root and documents

| Path | Disposition |
|---|---|
| Rplots.pdf, .Rhistory, .Rproj.user/ | never commit |
| ratio_homs_ext.png (root, Apr 29) | delete; older duplicate of figures/ratio_homs_ext.png |
| variables-03-04-26-053051.csv | delete (or fold its content into a note on occurrence vs residence) |
| documents/metadata/ (DANE dictionaries, 3.7 MB) | commit; public DANE documentation, needed to justify `recode_age_group` |
| documents/Lista_105_Colombia_CIE9-y-CIE10.xls | commit; needed to document the crosswalk |
| datos_mortalidad_colombia_03_2026.xlsx and _ka.xlsx | near-identical source inventory for the historical project; keep one, move next to 20-22 |
| report_missing_deaths_caribbean_09_2026.html | commit under `docs/` |

---

## 3. Plan A: cleanup before GitHub

Work in this order. Step 4 is the one step that runs code; do it last and once.

### A0. Decisions (taken 2026-10-13)
- Historical series module (20-22, `data_input/historical`, WHO, UCDP): **same repo**, under `R/historical/`, with its own README section and the source inventory xlsx next to it.
- Spatial model (10): **kept as `R/experimental/10_model_spatial.R`**, refit on the `_exc` estimates, plot block repaired, documented as not feeding results.
- Model estimates: **published as `output/homicide_estimates_munic_1985_2017.csv.gz`** (expect ~3 MB from the 16 MB rds).
- Licence: **MIT for code** (`LICENSE`), **CC-BY 4.0 for derived tables, figures and the hand-transcribed historical series** (`LICENSE-DATA`). README states the split and carries attribution notes for DANE (EEVV microdata, population projections, list 105), UCDP GED v25.1 and the WHO Mortality Database.

### A1. Consolidate code (edit in place in the Drive copy)

**Status 2026-10-13:** the judgment-heavy part is done and untested: `00_setup.R`
(packages, `recode_age_group`, cause crosswalk, `build_munic_panel`,
`dept_rates_from_panel`, `minmax`, `make_cod_munic`), `01_load_microdata.R`,
`02_summarise_deaths.R` (now also writes an age-disaggregated table),
`04_descriptives.R` (merged old 04 + 05), `05_municipal_panel.R` (old 06),
`06_excess_deaths.R` (old 07), `09_sex_ratio_by_cause.R` (old 11, repaired),
`run_all.R`, `.gitignore`, `.Rproj`. Two bugs fixed on the way: population
totals summed over the `t` sex row (doubled denominators in old 05/06/07) and
death ages capped at 80 against a population open interval of 85 (old 04).
Remaining mechanical steps are listed in `documents/HANDOFF_plan_A_execution.md`.
Superseded files go to `_archive/` (gitignored), not to the bin.
1. Delete `descriptive_homics.R`, `08_model_glmmTMB.R`. Move the AIC comparison comments into the kept model script.
2. Delete the dead "different period" block from `08_model_glmmTMB_exc.R`.
3. Move to `00_setup.R`: the cause crosswalk (one function returning `causa`, plus named groups `violent = c(101,102,103)`, `natural = 1:88`, `ill_defined = 89`), and a `build_munic_panel(dts, pop)` function used by 05/06/07.
4. Fix 02 to also write `deaths_munic_age_1979-2023.rds`; fix 04 to read it; or fold 04's useful plots into 05 and drop the rest.
5. Delete the municipal block from 05.
6. Reorder 11: data -> decomposition -> plots; fix the `drop_na(dpto)` line; remove `copy_this()`.
7. Strip interactive noise (`unique(...)` echoes, `print(n = 40)`, `tst |> ...` previews) or wrap in `if (interactive())`.
8. Replace pacman auto-install with `renv::init()` and commit `renv.lock`, or a `DESCRIPTION`-style list in the README. Note `colmaps` (GitHub: nebulae-co/colmaps).
9. Add `run_all.R` that sources 01-12 in order.
10. Renumber once the set is final (e.g. 01 load, 02 summarise, 03 pop, 04 descriptives, 05 municipal panel, 06 excess, 07 model, 08 validation, 09 cause decomposition, 10 completeness).

### A2. Write the repo scaffolding
- `README.md`: question, one-paragraph method, data sources with URLs (DANE EEVV microdata, DANE population projections 1985-2017, list 105, UCDP GED), how to run, what each output is, citation.
- `.gitignore`: `data_input/**` (except `reference/`), `data_inter/**`, `*.rds`, `*.pdf`, `.Rproj.user/`, `.Rhistory`, `Rplots.pdf`, `*.xlsx` in data folders.
- `data_input/README.md`: manifest of the 45 microdata files (name, year, format, bytes) and download instructions.
- `LICENSE`.

### A2b. Shared dataset: deaths by cause group and population, 1985-2024 (added 2026-10-13)

Purpose: one tidy file for colleagues, linked from the GitHub repo. Built after
A4 (it needs the corrected age recode and the new `02` output) and before the
clean copy, so it ships in the first commit.

**Content.** One row per year x municipality x sex (long format):

| column | meaning |
|---|---|
| year, sex (m/f), cod_dpto, dpto, cod_munic (5 digits), munic | keys and names (DIVIPOLA) |
| pop | DANE population, both for the sex, all ages |
| dx_all | all-cause deaths |
| dx_homicide | list 105 code 101 |
| dx_undetermined | code 102 (undetermined intent) |
| dx_accident | codes 90-99 and 104-105 (transport, falls, drowning, poisoning, other accidents) |
| dx_suicide | code 100 |
| dx_legal | code 103, kept separate so users can recombine |
| dx_residual | everything else: natural causes 1-88 plus ill-defined 89, so the columns sum to dx_all |

Check on build: the six cause columns sum to `dx_all` in every row. A second,
optional file adds 5-year age groups for the same layout (it already exists as
`deaths_munic_age_1979-2023.rds`; population by age exists for 1985-2017 only).
Store as `output/deaths_pop_munic_1985_2023.csv.gz` (~90k rows, under 5 MB),
with a data dictionary `output/deaths_pop_munic_dictionary.md` and a
`LICENSE-DATA` attribution. Deaths are by place of occurrence, population by
residence; say so in the dictionary.

**Decision 2026-10-13: the file stops at 2023 (no 2024 deaths).** Title and
filenames below say 1985-2023 accordingly.

**Extending past 2017 raises four issues.**

1. **Deaths 2018-2023** are already in `data_input/micro` and `01` loads them.
   **2024 is not** in the project (microdata stops at `nofetal2023.csv`).
   Action: check DANE's EEVV page for the 2024 release (preliminary or final)
   and download it; if it is not out or has a different layout, ship 1985-2023
   and add 2024 when available. Do not impute it.
2. **Population 2018-2024: no series break expected (resolved 2026-10-13).**
   The three 1985-2017 workbooks already in `data_input/DANEpop/`
   (`DCD-area-sexo-edad-proypoblacion-Mun-1985-1994`, `-1995-2004`,
   `-2005-2017_VP`) are DANE's retroprojections on the 2018-census base, not
   the old pre-census series. DANE lists them with the 2018-2042 file on the same
   page: https://www.dane.gov.co/index.php/estadisticas-por-tema/demografia-y-poblacion/proyecciones-de-poblacion
   (1985-2004 files dated 22 Mar 2023; 2005-2017_VP and PPED-AreaSexoEdadMun-2018-2042_VP
   both updated 8 Aug 2025, files carry the `_VP` suffix, technical note
   `NotaTecnica-PPED-jul2025.pdf`). Action: confirm our copies are the 2025
   versions (check the 2005-2017_VP file against the page date), read the
   2018-2042 workbook, and compare national and municipal totals at 2017 vs
   2018 as a check. Record the note and download dates in the dictionary.
   Caveat: the 2018-2042 series is DANE's post-COVID, migration-adjusted update,
   so cite the July 2025 technical note.
   **Verified 2026-10-13** (user confirmed the workbooks are the latest versions):
   national total 47,419,200 in 2017 and 48,258,494 in 2018 (the census-adjusted
   count), sex ratio 0.958 in both; municipal 2017 to 2018 growth has median
   +1.2 percent against +0.9 for 2016 to 2017, and only 6 of 1,122 municipalities
   move by more than 10 percent. One new code appears in 2018 (27493, Nuevo
   Belen de Bajira); no code disappears. No break flag is needed.
3. **Municipality changes.** New municipalities created and codes added
   (e.g. Belén de Bajirá, 27086) appear after 2017; the DIVIPOLA file in
   `data_input/reference/` is the March 2026 version. Rows with no population
   match (code 99999, "sin información") are dropped and counted in the
   dictionary.
4. **2020-2021 COVID excess** inflates `dx_residual` and `dx_all`; it is real
   mortality and stays in. Note it in the dictionary.

**New script** `code/11_shared_dataset.R` (not in `run_all.R` until it works):
reads `deaths_munic_1979-2023.rds`, the population series chosen in item 2 and
`recode_cause_broad`-style groups defined once in `00_setup.R`
(`cause_groups_shared()`), runs the sum-to-total check, writes the csv.gz and
the dictionary. The 1985-2017 and 2018+ population loaders go in `03` (second
output `pop_munic_2018-2042.rds`) so the break is visible in one place.

### A3. Create the clean copy OUTSIDE Google Drive
Git and Drive sync do not mix (Drive rewrites `.git/objects`, leaves lock files, duplicates
files as "(1)"). Create e.g. `C:\Users\kikep\gits\colombia_mortalidad`, copy `code/`
(renamed `R/`), `documents/metadata`, the small reference data, current PNGs, the report
and this plan. `git init` there. The Drive folder stays as the private archive with raw data.

### A4. One end-to-end run (the only execution step)
Run `run_all.R` in the clean copy against the raw data. This (a) propagates the Sep 2026
age fix through every intermediate, (b) proves the consolidated scripts work, and (c)
tells you which figures are current: anything in `figures/` not rewritten by the run is dead.
Then check `git count-objects -vH` stays well under 100 MB before pushing.

---

## 4. Plan B: is under-registration the reason the sex ratio fails before ~1998?

### B0. What is already established (from 12 + the Sep 2026 report)
- Registered CDR in six Caribbean departments 1.7-2.8 per 1000 in the late 1980s vs 6.0-6.3 in Antioquia/Bogota/Santander.
- GGB completeness 0.20-0.51 (Caribbean, 1985-95), with male/female completeness ratio swinging 0.5-1.45 across department-years, i.e. the same order of magnitude as the signal.
- Hidden-homicide (ill-defined causes) hypothesis rejected: sex ratio of ill-defined deaths ~1.1-1.3, not ~12.
- Pre/post-1998 correlation improvement is nationwide, not Caribbean-specific; no sharp breakpoint, R2 0.773-0.788 across 1988-2010.

So the hypothesis is motivated but not yet tested. Two things are missing: an external
check on the completeness levels, and the actual correction followed by a re-test.

### B1. Be precise about the mechanism being tested
Raw sex ratio = (H_m + c_m N_m) / (H_f + c_f N_f), with H violent deaths, N natural deaths,
c completeness. Three distinct ways under-registration breaks the ratio as a homicide proxy:
1. **Sex-differential completeness** (c_m != c_f): shifts the level of the ratio independently of homicides.
2. **Trends in completeness** that coincide with trends in violence (1998 jump).
3. **Cause-differential completeness**: violent deaths go through Medicina Legal and are
   probably near-complete even where natural deaths are not. Then the ratio's level depends
   on c itself, and a rise in coverage looks like a fall in violence.
The correction therefore must be cause-specific (inflate natural deaths by 1/c; treat
violent deaths separately), not a blanket 1/c on all deaths.

### B2. Phase 1: quick external test with DANE's adjusted life tables (days, no DDM yet)
DANE's conciliacion censal 1985-2005 produced completeness-adjusted life tables by
department x sex x quinquennium, extended to 2020 for the 2005-2020 projections:
- Tablas abreviadas de mortalidad nacionales y departamentales 1985-2020 (DANE 2007):
  https://www.dane.gov.co/files/investigaciones/poblacion/conciliacenso/8Tablasvida1985_2020.pdf
- Estimacion de la mortalidad 1985-2005 (methods, coverage evaluation of the registry):
  https://www.dane.gov.co/files/investigaciones/poblacion/conciliacenso/5Mortalidad85_05.pdf
- Conciliacion censal 1985-2005 (overall method):
  https://www.dane.gov.co/files/investigaciones/poblacion/conciliacenso/1Conciliacion_censal.pdf
- DANE reported to the UN that registered deaths at ages 5+ were 11% (M) / 5% (F) short of the
  census-implied count in 1985 and 14.5% / 13% in 1993, nationally, using Brass and Preston methods:
  https://unstats.un.org/unsd/demographic/meetings/wshops/2000_Chile_CRVS/Docs/Colombia.pdf
- The departmental tables are also mirrored one PDF per department-period at lifetable.de
  (e.g. https://www.lifetable.de/File/GetDocument/data\COL\COL000019851990AU1.pdf).
- After the 2018 census DANE republished retroprojections 1985-2017 and new departmental
  life tables; check the "Proyecciones de poblacion" download page for an xlsx before
  extracting from PDF.

Steps:
1. Extract nMx (or nqx -> nMx) by department x sex x age x quinquennium (1985-90 ... 2010-15). Prefer xlsx; fall back to `pdftools`/`tabulizer` on the DANE or lifetable.de PDFs. One-off, ~33 x 2 x 6 tables.
2. Expected deaths E = sum_age nMx x DANE population (same projections the project already uses, so denominators are consistent). Implied completeness c_DANE = registered D / E by department x sex x period. Compute it on all causes and, separately, on natural causes only (subtracting registered external deaths from E on the assumption they are complete; see B4).
3. Compare c_DANE with `completeness_ggb.rds` from 12 (scatter by sex and period; flag departments where they disagree by > 0.1 and look at the GGB R2 and the sensitivity CSV).
4. Cheapest test, no correction needed: across the 33 departments, regress the pre-1998 department-level r(log sex ratio, log homicide rate) on (a) completeness and (b) the M/F completeness differential. If pre-1998 r is a function of data quality, that is the hypothesis in one plot.
5. Correct and re-test: N_adj = N_reg / c (natural causes), recompute the sex ratio with H unchanged, rerun the report's three tests (pre/post-1998 r by department; breakpoint scan; first differences). Success criterion: Caribbean pre-1998 r rises toward 0.8, and pre-1998 r no longer correlates with completeness.
6. Caveat to state in the write-up: DANE's tables are themselves registered deaths corrected by Brass/Preston-type methods plus census conciliation, so this is an authoritative external estimate, not an independent one. Independence comes from B4.

### B3. Phase 2: DDM, as a replacement for the hand-rolled GGB, not as an alternative to B2
Yes, move to the `DDM` package (Riffe, Lima, Queiroz; CRAN 1.0-0 from 2017, dev version at
github.com/timriffe/AdultCoverage): https://github.com/cran/DDM
- Gives GGB, SEG and the GGB-SEG hybrid with automatic age-range selection (`ddm()`), and the hybrid corrects for differential census coverage, which the hand-rolled GGB cannot.
- Use real census-anchored windows (1985-1993, 1993-2005, 2005-2018) with DANE's adjusted census counts or the retroprojections at census dates, rather than arbitrary 10-year projection windows.
- Pool the six micro-departments (Amazonas, Guainia, Guaviare, Vaupes, Vichada, San Andres) into one unit; single-digit death counts break every DDM.
- Known failure modes to check per department: net migration (Antioquia 1985-95 displacement; Bogota in-migration), age heaping, and the occurrence/residence mismatch (B4.2).
- Output resolution is still department x sex x intercensal period. DDM adds an independent method, not more resolution. For annual values keep the anchored index from 12 (natural-cause ASDR relative to national), now anchored to the DDM or DANE levels.

### B4. Phase 2 (parallel): the independent evidence
1. **Homicide-registration completeness.** Your source inventory (`datos_mortalidad_colombia_03_2026.xlsx`) lists Policia Nacional homicides 1962-2002 and Medicina Legal 1980-2003 by department. Ratio DANE-registered violent deaths / Policia or Medicina Legal counts, by department-year, is a direct estimate of c for violent deaths and the only way to test the "violent deaths are complete" assumption in B1.3. If c_violent << 1 in the Caribbean pre-1998, the correction in B2.5 changes.
2. **Occurrence vs residence.** Rerun 12 (and the municipal panel) with residence codes. Deaths in Barranquilla hospitals from Magdalena/Sucre residents inflate Atlantico's registration and deflate the neighbours'. GGB compares deaths to a resident population, so occurrence-coded deaths bias it in both directions.
3. **Cause-specific sex ratios over time** (extend 11): if the natural-cause sex ratio alone shows the 1998 step, that is coverage; if only the external-cause ratio moves, that is violence.

### B5. Phase 3: put completeness into the model
Options in increasing cost; do the first two.
1. Offset: add `log(c_dept_sex_year)` to the exposure in `glmmTMB` (completeness enters as a known scaling of expected deaths), using the anchored annual series from 12. One line, keyed to join.
2. Stratified sensitivity: fit the current model only on municipality-years with department completeness > 0.85 and compare the `sex_r_log` coefficient and out-of-sample fit pre vs post 1998. If the sex ratio predicts homicides pre-1998 wherever coverage is high, the hypothesis holds and the model generalises.
3. Corrected sex ratio as the covariate: recompute `sex_r` from completeness-inflated natural deaths plus registered violent deaths, refit, compare AIC and the validation metrics in 09.
4. Municipal completeness (only if 1-3 leave a residual): shrink a municipal natural-cause ASDR index toward the department value (hierarchical), or model completeness as a latent municipal random effect. Department-level c is a floor on the correction, not the whole of it.

### B6. Prerequisite
None of this is valid until `01` is rerun so the age fix reaches `micro_1979_2023.rds`.
That rerun is Plan A step A4. Do A4 before B2.

### B7. Suggested new scripts
- `13_completeness_dane_vs_ggb.R` (B2.1-B2.3, B3)
- `14_sex_ratio_corrected.R` (B2.4-B2.5, B4.3)
- `15_homicide_completeness_external.R` (B4.1)
- changes to `12` for residence codes (B4.2) and to the model script for B5.

### B8. Alternatives to keep alive while testing
- Composition of violence: pre-1998 homicides were more rural and conflict-related; a different age/sex profile of victims would change the ratio's sensitivity without any registration story.
- Code 102 (undetermined intent) practice changed with the 1998 certificate.
- Projection error: DANE's municipal projections 1985-2004 are themselves back-casts; completeness "relative to the projection" absorbs projection error.
