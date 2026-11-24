# merge the per-year transcriptions of violent causes, add province codes by
# printed row (1-50, alphabetical order as in the deaths file), check, write
suppressPackageStartupMessages(library(data.table))
s <- "C:/Users/kikep/AppData/Local/Temp/claude/26bb97bca44464b8/d65f9a45-e428-4f13-9fc0-de9e3574b4f1/scratchpad/spain_causes"
proj <- "C:/Users/kikep/gits/colombia_homicidios/.claude/worktrees/homicide-mortality-modeling-c3a2c6"
ref <- fread(file.path(proj, "data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv"), encoding = "UTF-8", colClasses = list(character = "province_code"))
ord <- ref[year == 1940 & sex == "total" & !is.na(province_code) & province_code != "", .(province_code)][, row := .I]
fs <- list.files(s, "^causes_19[34][0-9]\\.csv$", full.names = TRUE)
cat("files:", basename(fs), "\n")
x <- rbindlist(lapply(fs, fread, encoding = "UTF-8", colClasses = list(character = "item")), fill = TRUE)
x[, row := as.integer(row)]
x <- merge(x, ord, by = "row", all.x = TRUE)
x[province == "TOTALES" | row == 51, province_code := NA_character_]
# checks: provinces add up to the printed totals, for every item and sex
chk <- merge(x[row <= 50, .(sum_prov = sum(deaths)), by = .(year, item, sex)],
             x[row == 51, .(printed = deaths), by = .(year, item, sex)], by = c("year", "item", "sex"), all = TRUE)
bad <- chk[is.na(printed) | sum_prov != printed]
cat("columns:", nrow(chk), "| not adding up:", nrow(bad), "\n"); if (nrow(bad)) print(bad)
print(x[, .(items = uniqueN(item), rows = .N, provinces = uniqueN(row[row <= 50])), by = year])
setorder(x, year, item, sex, row)
fwrite(x[, .(year, item, item_label, province, province_code, row, sex, deaths, pdf_page, note)],
       file.path(proj, "data_input/reference/spain_ine_deaths_province_cause_sex_1936-1942.csv"))
cat("written\n")
