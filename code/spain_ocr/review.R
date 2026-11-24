# strips of the columns that do not add up, four per image, with the reading of
# each cell in red and the row number in blue, for a check by eye
source("ocr2.R")
tag <- commandArgs(TRUE)[1]
rd <- readRDS(sprintf("read_%s.rds", tag)); cl <- rd$cl
fs <- list.files(".", sprintf("^cells_%s_.*rds$", tag)); R <- lapply(fs, readRDS)
open <- unique(cl[status == "open", .(f, col)])
cat(tag, "open columns:", nrow(open), "\n")
panel <- function(ff, j) {
  r <- R[[ff]]
  ims <- lapply(1:51, function(i) {
    m <- r$mats[[sprintf("%d_%d", j, i)]]
    im <- image_read(array(as.raw(t(m)), dim = c(1, ncol(m), nrow(m)))) |> image_extent(sprintf("%dx%d", 200, nrow(m)), gravity = "east", color = "white")
    val <- cl[f == ff & col == j & row == i, v]
    image_append(c(image_blank(34, nrow(m), "white") |> image_annotate(as.character(i), size = 16, gravity = "west", color = "blue"),
                   im, image_blank(70, nrow(m), "white") |> image_annotate(as.character(val), size = 22, gravity = "west", color = "red"))) |> image_border("grey80", "0x1")
  })
  hd <- image_blank(304, 30, "white") |> image_annotate(sprintf("f%d c%d  sum %s / total %s", ff, j,
          cl[f == ff & col == j & row <= 50, sum(v)], cl[f == ff & col == j & row == 51, v]), size = 16, gravity = "west")
  image_append(c(hd, do.call(c, ims)), stack = TRUE) |> image_border("white", "8x0")
}
if (nrow(open)) for (k in seq(1, nrow(open), by = 4)) {
  sel <- open[k:min(k + 3, nrow(open))]
  im <- image_append(do.call(c, lapply(seq_len(nrow(sel)), function(q) panel(sel$f[q], sel$col[q]))))
  image_write(im, sprintf("review_%s_%02d.png", tag, (k + 3) %/% 4))
}
fwrite(open, sprintf("open_%s.csv", tag))
