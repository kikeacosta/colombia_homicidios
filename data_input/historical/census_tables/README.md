# Census summary tables 1938, 1951 and 1973 (DANE PDFs)

Tables extracted from the three census summary volumes kept in
`data_input/historical/` (PDFs not versioned, 29 MB) by
`code/historical/23_census_tables_ocr.R`, which also re-checks every
accounting identity listed below and stops if one fails. All counts are
persons as printed by DANE; nothing is smoothed or adjusted here.

| File | Content | Rows |
|---|---|---|
| `census1938_single_age_sex.csv` | National population by single age (0-98, `99+`) and sex, plus the `indígena` row (population not classified by age); columns `census_year, age, age_start, male, female, total` | 101 |
| `census1951_dept_age5_sex_1938_1951.csv` | Population by 5-year age group (`<1`, `1-4`, `5-9` … `90-94`, `95+`, plus the printed `total`) and sex for the censuses of **1938 and 1951**, for 15 departamentos, 3 intendencias, 7 comisarías and the four printed totals (`unit_type` = total / departamento / intendencia / comisaría); columns `census_year, unit, unit_type, age, age_start, male, female, total` | 1,276 |
| `census1973_single_age_sex.csv` | National **censused** (unadjusted) population by single age (0-98, `99+`) and sex | 100 |
| `census1973_adjusted_population_units.csv` | **Coverage-adjusted** population of the 1973 census for 23 departamentos, Bogotá D.E., 4 intendencias and 4 comisarías, by zone (`total`, `cabecera`, `resto`) and component (`total = private_households + collective_households + indigenous_areas`) | 93 |
| `census1973_children_ever_born_age.csv` | Women aged 15+ in 1973 by 5-year age group (`15-19` … `45-49`, `50+`, plus the printed `total`) and zone: `women`, `not_stated`, `childless`, `mothers`, `children_ever_born`, `children_surviving` (`women = not_stated + childless + mothers`) | 27 |
| `census1973_children_ever_born_units.csv` | The same six columns, without age, for 23 departamentos, Bogotá D.E., 4 intendencias and 4 comisarías by zone | 93 |

## Sources (pdf page numbers of the files in `data_input/historical/`)

- **1938**: `LD_771_1938_V_1.pdf`, *Censo general de población, 5 de julio de 1938, resumen general del país*, Cuadro 28 "Población clasificada por edades, sexo y estado civil", pp. 105-107. Only the "totales" block is used (the solteros / casados / viudos blocks were not validated). Grand totals 4,312,763 men, 4,389,053 women, 8,701,816.
- **1951**: `LD_771_1951.pdf`, *Censo de población de 1951, resumen*, Cuadro 10 "Población por grupos de edad y sexo, 1938 y 1951, por departamentos, intendencias y comisarías", pp. 22-32. Enumerated population 11,228,509 in 1951 (DANE's later adjusted figure, 11,548,172, is not in this table) and 8,697,041 in 1938. The 1938 column excludes the 4,775 `indígena` persons of Cuadro 28 (2,606 men, 2,169 women), which is exactly the difference with the 1938 grand total. Vichada has no 1951 data (dashes) and is left empty.
- **1973**: `LB_771_1973.pdf`, *XIV Censo nacional de población y III de vivienda, octubre 24 de 1973, resumen nacional*. Cuadro 2 "Población censada por grupos de edad y sexo, total, cabecera y resto", pp. 316-317 (only the national columns are transcribed; censused total 20,666,920). Chapter VIII "Ajuste por cobertura de la población", pp. 115-197 (TOTAL / CABECERA / RESTO rows of each sección; the municipal rows are not transcribed) and Cuadro VIII.20, p. 94 (national summary: adjusted population 22,915,229 = 22,487,118 in departamentos and D.E. + 375,000 in intendencias and comisarías + 53,111 fuerzas armadas; the implied omission is 9.8 %). Cuadro 21 "Población femenina de 15 años y más en hogares particulares y colectivos por número de hijos nacidos vivos y sobrevivientes a la fecha del censo, según grupos de edad", p. 381, and Cuadro 21A, the same by secciones, pp. 382-384. They cover 5,937,170 women against 6,020,982 women aged 15+ in Cuadro 2, because areas with indigenous population are outside this tabulation (hence 86 women in Vichada and 310 in Guainía), and they are censused counts, not adjusted for coverage. 18.5 % of the women did not state their number of children (40 % at 15-19), so parities need an El-Badry type correction before use; the national proportion of children dead rises from 0.088 at 20-24 to 0.165 at 45-49.

## Method

- **1951** (OCR): each page rendered at 500 dpi (grey, thresholded) and at 300 dpi; tesseract 5 (page mode 6) word boxes clustered into rows and into the six rightmost numeric columns; tokens split at a thousands separator merged; low-confidence or malformed cells re-read one by one (page mode 7, digit whitelist). The two passes are reconciled with the identities total = men + women (every row), 21 age rows = section header, and departamentos + intendencias + comisarías = nación. 190 cells that no identity could settle were read visually from page crops and are listed in `ocr_support/corrections_1951.csv`. The grid output of both passes is in `ocr_support/ocr_grid_1951_*.csv`, so the table is rebuilt without the PDF; `run_ocr <- TRUE` in the script repeats the OCR.
- **1938 and 1973** (visual transcription): tesseract could not read the 12-column typeset table of 1938 reliably, nor the chain-printer scan of 1973 in any preprocessing variant (6/E, 0/C, 9/S confusions). Both were transcribed by eye from 500 dpi crops (`ocr_support/transcription_*.csv`) and corrected until every identity held.

## Validation (all asserted by the script)

- 1938: total = men + women in each of the 101 rows; column sums equal the printed grand totals.
- 1951: total = men + women in each of the 29 × 21 × 2 rows; the 21 ages add to every section header in all six columns; departments, intendencias and comisarías add to their group totals and to the national total in all six columns.
- 1973 Cuadro 2: total = men + women in each row; the single ages add to each of the 20 printed 5-year rows and to the printed grand total.
- 1973 chapter VIII: total = particulares + colectivos + indígenas and total = cabecera + resto in every unit; the 24 departamentos + D.E. and the 8 intendencias + comisarías add to Cuadro VIII.20 in all four columns.
- 1973 Cuadros 21 and 21A: women = no informan + sin hijos + con hijos in each of the 27 + 93 rows; the eight age groups add to the TOTAL row of each zone; total = cabecera + resto in every age group and every unit; the 31 units add to the national rows of Cuadro 21 in all six columns and three zones.

## Not extracted

- 1973 Cuadro 2 by zone (cabecera / resto columns). The volume has no age table by department: Cuadro 2 is national only, and Cuadro 3 (marital status by 5-year age and sex, pp. 318-319) is national by zone.
- 1973 chapter VIII at the municipal level (about 1,000 rows; OCR unusable).
- 1973 Cuadros 22, 22A and 23 (pp. 385-389): women by number of children ever born (0, 1, … 7+) by education, sección and marital status. They have no survivors and no age, so they add nothing for mortality.
- Other 1973 and 1951 tables of possible use: population by sex and municipality 1973 (Cuadro 1A, pp. 264-315), place of birth by place of enumeration (1973 Cuadro 4A, pp. 326-349; 1951 Cuadro 15), 5-year age by sex, zone and department 1951 (Cuadro 11, pp. 37-46).
- 1938 Cuadro 28 marital-status blocks and Cuadro 29 (departments by broad age groups), for which only unvalidated OCR drafts were produced.
- The 1964 census has no population summary volume in the repository (only the housing census).
