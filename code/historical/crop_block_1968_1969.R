# helper: 300-dpi crop of a block: Rscript crop_block_1968_1969.R <year> "<unit>" [row_from row_to]
suppressMessages(library(tidyverse))
a <- commandArgs(TRUE); yr <- as.integer(a[1]); un <- a[2]
s <- read_rds("data_inter/dane_defunciones_1968_1969_state.rds"); b <- s$blocks |> filter(year == yr, unit == un)
stopifnot(nrow(b) == 1)
dpi <- 300; sc <- dpi / 72
img <- magick::image_read_pdf("data_input/dane_pdfs/anuarios/LD_70106_1968_1969_EJ_3.pdf", pages = b$page, density = dpi)
r0 <- if (length(a) >= 4) as.integer(a[3]) else 0L; r1 <- if (length(a) >= 4) as.integer(a[4]) else 25L
ytop <- if (r0 == 0) b$y0 - 24 else b$y0 + b$gap1 + (r0 - 1) * b$pitch - b$pitch * 0.7
ybot <- if (r1 == 0) b$y0 + 6 else b$y0 + b$gap1 + (r1 - 1) * b$pitch + b$pitch * 0.7
g <- sprintf("%dx%d+%d+%d", round((250 + 6) * sc), round((ybot - ytop) * sc), round((b$x0 - 6) * sc), round(ytop * sc))
f <- sprintf("data_inter/crops/%d_%s_%d_%d.png", yr, gsub("[^A-Za-z]", "", iconv(un, to = "ASCII//TRANSLIT")), r0, r1)
magick::image_write(magick::image_crop(img, g), f); cat(f, "\n")
