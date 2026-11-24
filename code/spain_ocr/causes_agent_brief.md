# Brief: transcribe violent causes of death by province and sex, Spain, one year

Accuracy matters more than speed. Every number you write must be what is printed.

## Source
Scanned INE yearly volume D:/data/spain_mortality/ine_historia_<YEAR>.pdf (no usable text layer for the numbers; read the page images).
Tables "Defunciones clasificadas por provincias, sexo y causas de muerte, según la Nomenclatura internacional detallada" (1936-1940): each PDF page is a two-page spread; rows are the 50 provinces in alphabetical order (Alava ... Zaragoza) plus a "TOTALES" row; columns are causes (item numbers in the header), each split into "Var." (men) and "Hem." (women). "»" means zero. Thousands separator is a dot or space.
For 1941-1942 the table is "Defunciones por causas (Nomenclatura abreviada)", one page, columns "V." and "M.".

## What to transcribe (both sexes, all 50 provinces and the TOTALES row)
- 1936-1940 (detailed list, item numbers as printed in that year's header; check them, they may shift by a few between years):
  - homicide items: "Homicidio por arma de fuego", "Homicidio por instrumento cortante o punzante", "Otros homicidios" (in 1936 items 173, 174, 175; skip infanticide 172)
  - "Muerte violenta cuya naturaleza (accidente, homicidio, suicidio) es desconocida" (1936: 195)
  - "Heridas de guerra" (1936: 196) and any other war item (e.g. 1937-1939 may add items such as war injuries to civilians, gases, bombing: include every column whose header mentions guerra / bombardeo / gases de guerra)
  - "Ejecución en la población civil por los ejércitos beligerantes" (1936: 197)
  - "Ejecución judicial" (1936: 198)
  - "Muerte repentina" (1936: 199) and "Causas no especificadas o mal definidas" (1936: 200)
  - the "TOTAL GENERAL" column (all causes) as a check against known totals
- 1941-1942 (abridged list): every rubric from "41.—Homicidios" onward on that page (41 Homicidios, 42 Accidentes de automóviles, 43 Otras muertes violentas o accidentales, 44 Causas no expresas o mal definidas) and the TOTALES column.

Candidate PDF pages (spreads) for your year: 1936: 66, 68 · 1937: 68, 69, 70 · 1938: 67, 68, 69 · 1939: 69, 70, 71 · 1940: 67, 68, 69 · 1941: 102 · 1942: 102. Check neighbouring pages if an item is not there; the detailed table runs over several spreads.

## Method
- R: "/c/Program Files/R/R-4.5.2/bin/Rscript.exe" (pdftools, magick). Write R scripts with the Write tool (bash heredocs mangle backslashes); run them with Bash. Work in your own folder: C:/Users/kikep/AppData/Local/Temp/claude/26bb97bca44464b8/d65f9a45-e428-4f13-9fc0-de9e3574b4f1/scratchpad/spain_causes/y<YEAR>/
- Render the page at 250-300 dpi and crop narrow vertical strips (the province names plus 1-3 item columns, split top/bottom halves if needed) so digits are legible. Read by eye.
- Checks for every column: the sum over the 50 provinces equals the printed TOTALES value. If not, re-read the column at higher zoom. Never alter a value to force a check; if a printed total is genuinely inconsistent, keep the printed values and record a note.
- Also check: for the TOTAL GENERAL column (1936-1940) or TOTALES (1941-42), men and women by province must equal the deaths by province and sex in C:/Users/kikep/gits/colombia_homicidios/.claude/worktrees/homicide-mortality-modeling-c3a2c6/data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv (column deaths, sex male/female, same year). Report any province where they differ (it may be a real difference between tables; do not change values).

## Output
- C:/Users/kikep/AppData/Local/Temp/claude/26bb97bca44464b8/d65f9a45-e428-4f13-9fc0-de9e3574b4f1/scratchpad/spain_causes/causes_<YEAR>.csv with columns: year, item (as printed, e.g. "173" or "41"), item_label (Spanish header text, short), province (as printed; "TOTALES" for the totals row), row (1-50, 51 for TOTALES), sex ("male"/"female"), deaths (integer), pdf_page, note.
- The R script you used, in your folder.
- Do not modify anything in the project folder.

## Report back (short)
Items transcribed (number and label), whether every column passed the sum check (which cells you corrected), the national totals by item and sex, and any check against the deaths file that failed.
