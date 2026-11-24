# deaths by province, single age (15-44) and sex from the read tables:
# column j of each half page or page is (age, sex), from the page layout
suppressPackageStartupMessages(library(data.table))
ref <- fread("C:/Users/kikep/gits/colombia_homicidios/.claude/worktrees/homicide-mortality-modeling-c3a2c6/data_input/reference/spain_ine_deaths_province_sex_1933-1946.csv", encoding = "UTF-8", colClasses = list(character = "province_code"))
ord <- ref[year == 1940 & sex == "total" & !is.na(province_code) & province_code != "", .(row = .I, province, province_code)]
ord[, row := seq_len(.N)]; stopifnot(nrow(ord) == 50)
out <- list(); bad <- list()
for (y in 1933:1946) {
  fr <- sprintf("read_%d.rds", y); if (!file.exists(fr)) next
  cl <- readRDS(fr)$cl
  fs <- list.files(".", sprintf("^cells_%d_.*rds$", y))
  info <- rbindlist(lapply(seq_along(fs), function(k) { p <- strsplit(sub(".rds", "", fs[k], fixed = TRUE), "_")[[1]]; data.table(f = k, page = as.integer(p[3]), side = p[4]) }))
  info[, pidx := match(page, sort(unique(page))) - 1L]
  info[, `:=`(start = fifelse(side == "page", 15L + 5L * pidx, 13L + 13L * pidx + fifelse(side == "right", 6L, 0L)),
              ncol_exp = fifelse(side == "page", 10L, fifelse(side == "right", 14L, 12L)))]
  nc <- cl[, .(ncol = max(col)), by = f]; info <- merge(info, nc, by = "f")
  if (any(info$ncol != info$ncol_exp)) bad[[length(bad) + 1]] <- info[ncol != ncol_exp, .(year = y, page, side, ncol, ncol_exp)]
  d <- merge(cl[row <= 50, .(f, col, row, deaths = v, status)], info[, .(f, page, side, start)], by = "f")
  d[, `:=`(year = y, age = start + (col - 1L) %/% 2L, sex = fifelse(col %% 2L == 1L, "male", "female"))]
  out[[length(out) + 1]] <- merge(d, ord, by = "row")
}
res <- rbindlist(out)[age %in% 15:44]
if (length(bad)) { cat("half pages with an unexpected number of columns:\n"); print(rbindlist(bad)) }
print(dcast(unique(res[, .(year, age, sex, status)])[, .N, by = .(year, status)], year ~ status, value.var = "N", fill = 0))
print(res[, .(ages = paste(range(age), collapse = "-"), cols = uniqueN(paste(age, sex))), by = year])
fwrite(res[, .(year, province, province_code, age, sex, deaths, status, page, side)], "spain_age_15_44_read.csv")
