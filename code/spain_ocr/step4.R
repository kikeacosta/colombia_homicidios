# self-training on the columns whose cells add up to the printed total, then
# repair of the columns that miss by one digit
source("ocr2.R")
tag <- commandArgs(TRUE)[1]; tr <- readRDS(sprintf("train_%s.rds", tag)); cl <- tr$cl; gl <- tr$gl
for (i in which(cl$row == 51)) gl[[i]] <- right_group(gl[[i]])
cl[, ng := lengths(gl)]
# the ditto sign (zero) is a short mark: a cell whose glyphs are all well below
# the height of a digit reads 0
hmed <- median(unlist(lapply(gl, function(g) sapply(g, nrow))))
ditto <- sapply(gl, function(g) !OLDSTYLE && length(g) > 0 && all(sapply(g, nrow) < 0.8 * hmed))
for (i in which(ditto)) gl[[i]] <- list()
cl[, ng := lengths(gl)]; cat("ditto cells", sum(ditto), "
")
F_all <- lapply(gl, function(g) if (length(g)) t(sapply(g, glyph_feat)) else NULL)
gidx <- rep(seq_along(gl), lengths(gl)); FM <- do.call(rbind, F_all)

# distance of every glyph to the nearest training glyph of each class
class_dist <- function(X, y) {
  D <- outer(rowSums(FM^2), rowSums(X^2), "+") - 2 * FM %*% t(X)
  sapply(as.character(0:9), function(c) { k <- which(y == c); if (!length(k)) return(rep(Inf, nrow(FM))); sqrt(pmax(0, apply(D[, k, drop = FALSE], 1, min))) })
}
read_all <- function(X, y) {
  CD <- class_dist(X, y)
  best <- max.col(-CD, ties.method = "first") - 1
  srt <- t(apply(CD, 1, sort)); marg <- srt[, 2] - srt[, 1]
  val <- tapply(best, factor(gidx, seq_along(gl)), paste, collapse = "")
  val[is.na(val)] <- "0"
  list(v = as.numeric(val), CD = CD, best = best, marg = marg)
}
X <- tr$X; y <- tr$y
for (it in 1:6) {
  r <- read_all(X, y)
  cl[, v := r$v]
  chk <- cl[, .(sum_body = sum(v[row <= 50]), total = v[row == 51]), by = .(f, col)][, ok := sum_body == total]
  cat("iteration", it, "| training glyphs", nrow(X), "| columns adding up:", sum(chk$ok), "of", nrow(chk), "\n")
  okc <- chk[ok == TRUE, paste(f, col)]
  cells_ok <- which(paste(cl$f, cl$col) %in% okc & cl$ng > 0)
  gsel <- which(gidx %in% cells_ok)
  X2 <- rbind(tr$X, FM[gsel, , drop = FALSE]); y2 <- c(tr$y, as.character(r$best[gsel]))
  if (nrow(X2) == nrow(X)) break
  X <- X2; y <- y2
}
# repair: one glyph changed to another class (cheapest change first) or the
# total misread; accepted when exactly one cheap change closes the gap
r <- read_all(X, y); cl[, v := r$v]
chk <- cl[, .(sum_body = sum(v[row <= 50]), total = v[row == 51]), by = .(f, col)][, ok := sum_body == total]
fix <- list()
for (k in which(!chk$ok)) {
  ci <- which(cl$f == chk$f[k] & cl$col == chk$col[k])
  cands <- list()
  for (i in ci) {
    gk <- which(gidx == i); if (!length(gk)) next
    for (q in seq_along(gk)) for (c in 0:9) {
      if (c == r$best[gk[q]]) next
      dig <- r$best[gk]; dig[q] <- c; nv <- as.numeric(paste(dig, collapse = ""))
      cost <- r$CD[gk[q], c + 1] - r$CD[gk[q], r$best[gk[q]] + 1]
      sb <- chk$sum_body[k] + if (cl$row[i] <= 50) nv - cl$v[i] else 0
      tt <- if (cl$row[i] == 51) nv else chk$total[k]
      if (sb == tt) cands[[length(cands) + 1]] <- data.table(i = i, row = cl$row[i], old = cl$v[i], new = nv, cost = cost)
    }
  }
  cands <- rbindlist(cands)
  if (nrow(cands)) { setorder(cands, cost); fix[[length(fix) + 1]] <- cbind(chk[k, .(f, col, sum_body, total)], cands[1:min(3, .N)]) }
}
fix <- rbindlist(fix)
cat("\n== one-digit repairs (three cheapest per column) ==\n"); print(fix)
cat("\n== columns still open ==\n"); print(chk[ok == FALSE & !paste(f, col) %in% fix[, paste(f, col)]])
saveRDS(list(cl = cl, X = X, y = y, chk = chk, fix = fix), sprintf("read_%s.rds", tag))
# accept a repair when it is the only one or clearly cheaper than the next
acc <- fix[, .(n = .N, c1 = cost[1], c2 = if (.N > 1) cost[2] else Inf, i = i[1], new = new[1], row = row[1]), by = .(f, col)][c1 < 0.5 * c2]
for (k in seq_len(nrow(acc))) cl[acc$i[k], v := acc$new[k]]
chk <- cl[, .(sum_body = sum(v[row <= 50]), total = v[row == 51]), by = .(f, col)][, ok := sum_body == total]
cl[, status := fifelse(paste(f, col) %in% acc[, paste(f, col)], "repaired", fifelse(paste(f, col) %in% chk[ok == TRUE, paste(f, col)], "adds_up", "open"))]
st <- unique(cl[, .(f, col, status)]); cat("\n== columns by status ==\n"); print(table(st$status))
saveRDS(list(cl = cl, X = X, y = y, chk = chk, fix = fix, acc = acc), sprintf("read_%s.rds", tag))
