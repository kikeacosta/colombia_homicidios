# Cell and glyph extraction for the INE single-age tables by province.
# geometry: columns from a sparse OCR (clusters of right edges of numbers),
# rows from a regular lattice anchored on the totals row (ocr_half4 logic).
# each cell becomes a binary matrix with the rule lines painted white, and is
# split into glyphs by the vertical projection of its ink.
# old-style figures (1941-1946 volumes): 0, 1 and 2 are short, 3-9 rise or descend
OLDSTYLE <- Sys.getenv("OLDSTYLE") == "1"
suppressPackageStartupMessages({library(magick); library(tesseract); library(data.table)})
eng_sparse <- tesseract(options = list(tessedit_char_whitelist = "0123456789.", tessedit_pageseg_mode = "11"))
eng_cell <- tesseract(options = list(tessedit_char_whitelist = "0123456789.", tessedit_pageseg_mode = "7", classify_bln_numeric_mode = "1"))
runs <- function(v) { r <- rle(v); e <- cumsum(r$lengths); s <- e - r$lengths + 1; data.frame(s = s[r$values], e = e[r$values]) }
bbox_df <- function(d) { b <- do.call(rbind, lapply(strsplit(d$bbox, ","), as.numeric)); d$x1 <- b[, 1]; d$y1 <- b[, 2]; d$x2 <- b[, 3]; d$y2 <- b[, 4]; d$yc <- (d$y1 + d$y2) / 2; as.data.table(d) }
smooth <- function(v, k) { z <- as.numeric(stats::filter(v, rep(1 / k, k), sides = 2)); z[is.na(z)] <- 0; z }

# the image(s) of a table: halves of a spread, or the whole page
table_images <- function(year, page, dpi = 300) {
  img <- image_read(pdftools::pdf_render_page(sprintf("D:/data/spain_mortality/ine_historia_%d.pdf", year), page = page, dpi = dpi))
  w <- image_info(img)$width; h <- image_info(img)$height
  prep <- function(x) image_convert(x, colorspace = "gray") |> image_normalize()
  if (w > h) list(left = prep(image_crop(img, geometry_area(round(w / 2) - 10, h, 0, 0))),
                  right = prep(image_crop(img, geometry_area(round(w / 2) - 10, h, round(w / 2) + 10, 0))))
  else list(page = prep(img))
}

table_cells <- function(g, n_rows = 50, min_words = 12, max_lag = 45, tess = FALSE) {
  h <- image_info(g)$height
  a <- as.integer(image_data(g, "gray"))[, , 1]; dark <- a < 120
  hr <- runs(rowMeans(dark) > 0.35); cand <- hr$s[hr$s > h * 0.6 & hr$s < h * 0.97]
  # the bottom rule of the table: the lowest strong rule (a rule may also run
  # between the provinces and the totals row)
  bottom <- if (length(cand)) max(cand) else round(h * 0.9)
  hl <- which(rowMeans(dark) > 0.25); hl <- unique(pmin(nrow(dark), pmax(1, c(hl - 2, hl - 1, hl, hl + 1, hl + 2)))); dark[hl, ] <- FALSE
  d <- bbox_df(ocr_data(g, engine = eng_sparse))
  d <- d[grepl("[0-9]", word) & y2 < bottom]
  d <- d[order(x2)][, cl := cumsum(c(1, diff(x2) > 35))]
  keep <- d[, .N, by = cl][N >= min_words, cl]; d <- d[cl %in% keep]
  cols <- d[, .(xr = median(x2), wq = quantile(x2 - x1, 0.9), n = .N), by = cl][order(xr)][, col := .I]
  dy <- d[order(cl, yc), .(dd = diff(yc)), by = cl]$dd; pitch <- median(dy[dy > 20 & dy < 60])
  top <- max(1, round(bottom - (n_rows + 6) * pitch))
  ys <- top:(bottom - 3)
  prof <- sapply(seq_len(nrow(cols)), function(j) {
    xl <- max(1, round(cols$xr[j] - min(cols$wq[j], 110) - 14)); xr <- min(ncol(dark), round(cols$xr[j] + 8))
    s <- dark[ys, xl:xr, drop = FALSE]; s[, colMeans(s) > 0.4] <- FALSE # vertical rules
    smooth(rowSums(s), 5)
  })
  ref <- which.max(cols$n)
  lag <- sapply(seq_len(nrow(cols)), function(j) {
    cc <- sapply(-max_lag:max_lag, function(L) { i <- seq_along(ys); k <- i + L; ok <- k >= 1 & k <= length(ys); suppressWarnings(cor(prof[i[ok], ref], prof[k[ok], j])) })
    (-max_lag:max_lag)[which.max(cc)]
  })
  al <- sapply(seq_len(nrow(cols)), function(j) { k <- seq_along(ys) + lag[j]; v <- rep(0, length(ys)); ok <- k >= 1 & k <= length(ys); v[ok] <- prof[k[ok], j]; v })
  P <- smooth(rowSums(al), 15)
  zone <- which(ys > bottom - 2.5 * pitch)
  i_tot <- zone[which.max(P[zone])]
  best <- NULL
  for (p in seq(pitch * 0.94, pitch * 1.06, by = 0.05)) for (gap in seq(1.0 * p, 2.6 * p, by = 1)) {
    ii <- round(i_tot - gap - (n_rows - 1):0 * p)
    if (min(ii) < 1) next
    f <- sum(P[ii]); if (is.null(best) || f > best$f) best <- list(f = f, ii = ii, p = p)
  }
  rows_ref <- c(best$ii, i_tot); pitch <- best$p
  out <- list(); mats <- list()
  for (j in seq_len(nrow(cols))) {
    xr <- min(ncol(dark), round(cols$xr[j] + 6))
    xlw <- max(1, round(cols$xr[j] - min(cols$wq[j], 110) - 16 - 70))
    rule_x <- xlw - 1 + which(colMeans((a < 120)[ys, xlw:xr, drop = FALSE]) > 0.35)
    rule_x <- unique(c(rule_x - 2, rule_x - 1, rule_x, rule_x + 1, rule_x + 2))
    for (i in seq_along(rows_ref)) {
      wide <- if (i == length(rows_ref)) 70 else 0
      xl <- max(1, round(cols$xr[j] - min(cols$wq[j], 110) - 16 - wide))
      yc <- ys[rows_ref[i]] + lag[j]
      y0 <- max(1, round(yc - 0.55 * pitch)); y1 <- min(h, y0 + round(1.1 * pitch) - 1)
      xr_c <- if (i == length(rows_ref)) min(ncol(dark), xr + 14) else xr # totals can stick out on the right
      m <- a[y0:y1, xl:xr_c, drop = FALSE]
      rc <- intersect(rule_x, xl:xr_c) - xl + 1; m[, rc] <- 255L
      hrow <- intersect(hl, y0:y1) - y0 + 1; m[hrow, ] <- 255L
      b <- binarize(m)
      key <- sprintf("%d_%d", j, i); mats[[key]] <- m
      t <- NA_character_
      if (tess) {
        cr <- image_read(array(as.raw(t(ifelse(b, 0L, 255L))), dim = c(1, ncol(m), nrow(m)))) |> image_border("white", "12x12")
        t <- if (sum(b) < 25) "" else gsub("[^0-9.]", "", ocr(image_scale(cr, "300%"), engine = eng_cell))
      }
      sp <- d[cl == cols$cl[j] & abs(yc - (y0 + y1) / 2) < 0.45 * pitch]
      out[[length(out) + 1]] <- data.table(col = j, row = i, cid = key, x0 = xl, y0 = y0, ink = sum(b), tess = t,
                                           sparse = if (nrow(sp)) sp$word[1] else NA_character_, sparse_conf = if (nrow(sp)) sp$confidence[1] else NA_real_)
    }
  }
  list(cells = rbindlist(out), mats = mats, cols = cols, pitch = pitch, lag = lag)
}


# connected components (8-neighbours) of a binary matrix: label matrix, 0 = background
cc_label <- function(b) {
  L <- matrix(ifelse(b, seq_along(b), Inf), nrow(b)); nr <- nrow(b); nc <- ncol(b)
  sh <- function(M, dy, dx) { o <- matrix(Inf, nr, nc)
    ys <- max(1, 1 + dy):min(nr, nr + dy); xs <- max(1, 1 + dx):min(nc, nc + dx)
    if (length(ys) && length(xs) && min(ys) <= max(ys) && min(xs) <= max(xs)) o[ys, xs] <- M[ys - dy, xs - dx]; o }
  repeat {
    M <- L
    for (dy in -1:1) for (dx in -1:1) if (dy | dx) M <- pmin(M, sh(L, dy, dx))
    M[!b] <- Inf
    if (identical(M, L)) break
    L <- M
  }
  L[!b] <- 0; L
}

# glyphs of a cell. components that look like digits (tall enough) set the text
# band; pieces inside the band are kept, specks, dots and rule remnants are
# dropped; pieces overlapping in x are one glyph; over-wide glyphs (touching
# digits) are split into equal parts. returns a list of binary matrices with
# attribute x (left, right) in cell coordinates.
cell_glyphs <- function(b, dw = 15, hmin = if (OLDSTYLE) 10 else 17) {
  if (!is.logical(b)) b <- binarize(b)
  b[, colSums(b) > 0.85 * nrow(b)] <- FALSE
  if (sum(b) < 20) return(list())
  # slanted rule pieces: once the text band is known, pixel columns with a run
  # of ink above or below it (digits stay inside the band) are erased
  L <- cc_label(b)
  ids <- setdiff(unique(as.vector(L)), 0)
  cm <- rbindlist(lapply(ids, function(k) { w <- which(L == k, arr.ind = TRUE)
    data.table(y0 = min(w[, 1]), y1 = max(w[, 1]), ww = diff(range(w[, 2])) + 1, area = nrow(w)) }))
  big <- cm[y1 - y0 + 1 >= hmin & area >= 25 & ww >= 4]
  if (nrow(big)) {
    t0 <- max(1, round(median(big$y0)) - 2); t1 <- min(nrow(b), round(median(big$y1)) + 2)
    # a rule crosses the band: ink both above and below it (marks left by the
    # row above sit only on top)
    if (t0 > 1 && t1 < nrow(b)) {
      ab <- colSums(b[1:(t0 - 1), , drop = FALSE]); be <- colSums(b[(t1 + 1):nrow(b), , drop = FALSE])
      rx <- which(ab >= 2 & be >= 2)
      if (FALSE && length(rx)) { b[, rx] <- FALSE; L <- cc_label(b) }
    }
  }
  ids <- setdiff(unique(as.vector(L)), 0)
  cm <- rbindlist(lapply(ids, function(k) { w <- which(L == k, arr.ind = TRUE)
    data.table(id = k, y0 = min(w[, 1]), y1 = max(w[, 1]), x0 = min(w[, 2]), x1 = max(w[, 2]), area = nrow(w)) }))
  cm[, `:=`(hh = y1 - y0 + 1, ww = x1 - x0 + 1)]
  cm <- cm[!(ww <= 3 & hh > 0.6 * nrow(b))] # rule remnants
  big <- cm[hh >= hmin & area >= 25 & ww >= 4]
  if (!nrow(big)) return(list())
  top <- median(big$y0); bot <- median(big$y1); bh <- bot - top + 1
  # pieces must touch the text band; small pieces are kept only when they lie
  # under a digit-like piece (a broken stroke), standalone ones must be tall
  # and not hair-thin (rule remnants, thousands dots, specks)
  # pieces lying wholly outside the band (marks from the row above or below) go;
  # the rest are grouped by overlap in x, and a group is a glyph when, taken
  # together, it is tall enough and not hair-thin (faint digits print broken)
  cm <- cm[y1 >= top - 2 & y0 <= bot + 2 & area >= 4]
  if (!nrow(cm)) return(list())
  setorder(cm, x0); cm[, grp := cumsum(c(1, head(cummax(x1), -1) < x0[-1] - 0))]
  # a faint 0, 6 or 8 can print as two narrow halves almost touching: merge
  # neighbouring narrow groups when the gap is tiny and the pair is digit-wide
  # (two real 1s are ~10 px apart)
  repeat {
    gs <- cm[, .(gx0 = min(x0), gx1 = max(x1)), by = grp][order(gx0)]
    if (nrow(gs) < 2) break
    gap <- gs$gx0[-1] - gs$gx1[-nrow(gs)] - 1; wl <- gs$gx1 - gs$gx0 + 1
    k <- which(gap <= 3 & wl[-nrow(gs)] < 0.75 * dw & wl[-1] < 0.75 * dw & (gs$gx1[-1] - gs$gx0[-nrow(gs)] + 1) <= 1.3 * dw)
    if (!length(k)) break
    cm[grp == gs$grp[k[1] + 1], grp := gs$grp[k[1]]]
  }
  gs <- cm[, .(gy0 = min(y0), gy1 = max(y1), gx0 = min(x0), gx1 = max(x1), ga = sum(area)), by = grp]
  gs <- gs[gy1 - gy0 + 1 >= (if (OLDSTYLE) 0.4 else 0.6) * bh & gx1 - gx0 + 1 >= 4 & ga >= 20]
  cm <- cm[grp %in% gs$grp]
  if (!nrow(cm)) return(list())
  out <- list()
  for (gk in unique(cm$grp)) {
    z <- cm[grp == gk]; x0 <- min(z$x0); x1 <- max(z$x1)
    yy <- max(1, min(z$y0)):min(nrow(b), max(z$y1))
    g <- matrix(L[yy, x0:x1, drop = FALSE] %in% z$id, length(yy))
    wdt <- ncol(g); n <- if (wdt > 1.6 * dw) max(1, round(wdt / dw)) else 1
    cuts <- round(seq(0, wdt, length.out = n + 1))
    for (q in seq_len(n)) {
      gq <- g[, (cuts[q] + 1):cuts[q + 1], drop = FALSE]
      rq <- which(rowSums(gq) > 0); cq <- which(colSums(gq) > 0)
      if (!length(rq)) next
      o <- gq[min(rq):max(rq), min(cq):max(cq), drop = FALSE]
      attr(o, "x") <- x0 - 1 + cuts[q] + range(cq)
      out[[length(out) + 1]] <- o
    }
  }
  out
}

# the totals cell is wide and may catch the end of the neighbouring total:
# keep the glyphs from the right edge leftwards while the gaps stay small
right_group <- function(gs, max_gap = 30) {
  if (length(gs) < 2) return(gs)
  x <- t(sapply(gs, attr, "x"))
  keep <- length(gs)
  for (k in rev(seq_len(length(gs) - 1))) { if (x[k + 1, 1] - x[k, 2] - 1 > max_gap) break; keep <- c(k, keep) }
  gs[keep]
}

# feature vector of a glyph: block averages on a 12 x 16 grid plus shape
glyph_feat <- function(g, nx = 12, ny = 16) {
  h <- nrow(g); w <- ncol(g)
  ry <- pmin(ny, floor((seq_len(h) - 1) / h * ny) + 1); rx <- pmin(nx, floor((seq_len(w) - 1) / w * nx) + 1)
  m <- matrix(0, ny, nx); n <- matrix(0, ny, nx)
  for (i in seq_len(h)) { m[ry[i], ] <- m[ry[i], ] + tapply(g[i, ], factor(rx, 1:nx), sum, default = 0); n[ry[i], ] <- n[ry[i], ] + tabulate(rx, nx) }
  f <- as.vector(m / pmax(n, 1))
  c(f, aspect = 3 * w / h, height = h / 30)
}

# threshold of each cell halfway between its background and its darkest ink,
# so that faint print is not lost; a cell without contrast is blank
binarize <- function(m) {
  bg <- median(m); ink <- quantile(m, 0.02)
  if (bg - ink < 50) return(matrix(FALSE, nrow(m), ncol(m)))
  m < min(190, (bg + ink) / 2)
}
