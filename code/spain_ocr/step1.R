source("ocr2.R")
a <- commandArgs(TRUE); y <- as.integer(a[1]); pages <- as.integer(strsplit(a[2], ",")[[1]]); tess <- a[3] == "tess"
for (p in pages) {
  ims <- table_images(y, p)
  for (s in names(ims)) {
    t0 <- Sys.time(); r <- table_cells(ims[[s]], tess = tess)
    r$cells[, `:=`(year = y, page = p, side = s)]
    saveRDS(r, sprintf("cells_%d_%d_%s.rds", y, p, s))
    cat(y, p, s, "| cols", nrow(r$cols), "| pitch", round(r$pitch, 1), "| sec", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "\n")
  }
}
