# helper for the manual check: contact sheets (300 dpi) of the rows of the cells that the identities corrected.
# Rscript code/historical/crop_cells_1968_1969.R   ->  data_inter/crops/sheet_N.png (one strip per cell, with what the script took)
suppressMessages({library(tidyverse); library(magick)})
s <- read_rds("data_inter/dane_defunciones_1968_1969_state.rds"); bl <- s$blocks
cc <- read_csv("data_input/historical/dane_defunciones_1968_1969_support/cells_corrected.csv", show_col_types = FALSE) |> filter(grepl("^identities", method))
ages <- c("all", "under 1 day", "1-6 days", "7-29 days", "1-5 months", "6-11 months", "12-23 months", "2-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80-84", "85+", "not stated")
sc <- 300 / 72; pdf <- "data_input/dane_pdfs/anuarios/LD_70106_1968_1969_EJ_3.pdf"
pgs <- unique(cc$page |> sort()); imgs <- map(set_names(pgs), \(p) image_read_pdf(pdf, pages = p, density = 300))
cc <- cc |> arrange(year, match(unit, unique(bl$unit)), match(age, ages), sex)
cc <- cc |> distinct(year, unit, age, .keep_all = TRUE) |> select(year, unit, age) |> left_join(cc |> group_by(year, unit, age) |> summarise(what = paste(sex, text_layer_value, "->", value, collapse = "; "), .groups = "drop"), by = c("year", "unit", "age"))
strips <- pmap(cc, function(year, unit, age, what) {
  b <- bl |> filter(year == !!year, unit == !!unit); k <- match(age, ages) - 1L
  yc <- b$y0 + if (k == 0) 0 else b$gap1 + (k - 1) * b$pitch
  x <- image_crop(imgs[[as.character(b$page)]], sprintf("%dx%d+%d+%d", round(254 * sc), round(b$pitch * sc * 1.05), round((b$x0 - 6) * sc), round((yc - b$pitch * 0.52) * sc)))
  lab <- image_blank(900, image_info(x)$height, "white") |> image_annotate(sprintf("%d %s | %s | %s", year, unit, age, what), size = 24, location = "+5+4", color = "black")
  image_append(c(x, lab))
})
for (i in seq(1, length(strips), by = 16)) image_write(image_append(do.call(c, strips[i:min(i + 15, length(strips))]), stack = TRUE), sprintf("data_inter/crops/sheet_%d.png", (i - 1) %/% 16 + 1))
cat(length(strips), "strips\n")
