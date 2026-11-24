# Spain INE volumes: digit reader for the tables of deaths

These are prototype scripts. They read the scanned yearly volumes of the INE (*Movimiento natural de la población de España*, 1933-1946) in `D:/data/spain_mortality/`. Their working copies, with the intermediate `.rds` files and logs, are in `D:/data/spain_mortality/work/`.

| File | What it does |
|---|---|
| `ocr2.R` | Core of the reader. It renders a page, finds the grid of columns and rows, splits cells into digits (connected components), and classifies digits with kNN on 12×16 block features. It also does adaptive binarisation and the ditto sign. `OLDSTYLE=1` switches to old-style figures (1941 on). |
| `glyphs.R` | Feature extraction for the digit glyphs. |
| `step1.R` | Reads the cells of a year: `Rscript step1.R <year> <pages,comma,separated> tess`. Writes `cells_<year>_<page>_<side>.rds`. |
| `step2.R` | Trains the classifier on the year's glyphs: `Rscript step2.R <year>`. Writes `train_<year>.rds`. |
| `step4.R` | Self-training against the printed column totals and one-digit repairs: `Rscript step4.R <year>`. Writes `read_<year>.rds` and reports the columns that add up, are open or were repaired. |
| `assemble.R`, `review.R` | Assemble the cells into a table and list the cells to review. |
| `run_all.sh` | Runs steps 1, 2 and 4 for the 15-44 pages of every year (page numbers per year inside). |
| `find_age2.R` | Finds the pages of the table "Defunciones clasificadas por edades y provincias" in each volume, from the PDF text layer. |
| `merge_causes.R`, `causes_agent_brief.md` | Merge and check the violent causes by province and sex for 1936-1942, which agents transcribed from the page images. This is the source of `data_input/reference/spain_ine_deaths_province_cause_sex_1936-1942.csv`. |

## State

- The age table gives deaths by province, sex and single year of age (0 to 110, plus age not stated). There are about 9 double pages per year in 1933-1940, and more in 1941-1946.
- The reader checks every column against its printed total. On the 15-44 pages, 58-92 % of the columns add up without help, depending on the year.
- The rows can also be checked: each province and sex must add up to the totals already transcribed in `data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv`.
- The scripts use relative paths, so run them from a working folder that holds a copy of them.
