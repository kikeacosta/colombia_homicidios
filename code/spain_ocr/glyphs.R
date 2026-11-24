
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
cell_glyphs <- function(b, dw = 15, hmin = 17) {
  b[, colSums(b) > 0.85 * nrow(b)] <- FALSE
  if (sum(b) < 20) return(list())
  L <- cc_label(b)
  ids <- setdiff(unique(as.vector(L)), 0)
  cm <- rbindlist(lapply(ids, function(k) { w <- which(L == k, arr.ind = TRUE)
    data.table(id = k, y0 = min(w[, 1]), y1 = max(w[, 1]), x0 = min(w[, 2]), x1 = max(w[, 2]), area = nrow(w)) }))
  cm[, `:=`(hh = y1 - y0 + 1, ww = x1 - x0 + 1)]
  cm <- cm[!(ww <= 3 & hh > 0.6 * nrow(b))] # rule remnants
  big <- cm[hh >= hmin & area >= 25 & ww >= 4]
  if (!nrow(big)) return(list())
  top <- median(big$y0); bot <- median(big$y1); bh <- bot - top + 1
  ov <- pmin(cm$y1, bot) - pmax(cm$y0, top) + 1
  cm <- cm[ov >= 0.4 * pmin(cm$hh, bh) & area >= 10 & (ww >= 3 | hh >= hmin)]
  cm <- cm[hh >= 0.45 * bh | (area >= 18)] # keep broken pieces, drop dots
  cm <- cm[hh >= 0.45 * bh] # thousands dots and specks are short
  if (!nrow(cm)) return(list())
  setorder(cm, x0); cm[, grp := cumsum(c(1, head(cummax(x1), -1) < x0[-1] - 0))]
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
right_group <- function(gs, max_gap = 14) {
  if (length(gs) < 2) return(gs)
  x <- t(sapply(gs, attr, "x"))
  keep <- length(gs)
  for (k in rev(seq_len(length(gs) - 1))) { if (x[k + 1, 1] - x[k, 2] - 1 > max_gap) break; keep <- c(k, keep) }
  gs[keep]
}
