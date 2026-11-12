# =============================================================================
# 31b_extract_conciliacion_annex1_lifetables.R
#
# Fuente : DANE (mayo 2007), "Conciliacion censal 1985-2005. Colombia.
#          Estimacion de la mortalidad 1985-2005", ANEXO 1 "Tablas de mortalidad
#          1985, 1993 y 2005. Nacional y departamental" (paginas PDF 71-158; la
#          etiqueta impresa "N de 299" coincide con el numero de pagina PDF).
#          PDF: data_input/dane_pdfs/censos/5Mortalidad85_05.pdf
#
# Metodo : 1. pdftools::pdf_data() entrega cada palabra con sus coordenadas.
#             Las filas (18 grupos de edad x 2 sexos por pagina) se asignan por la
#             coordenada y de la etiqueta de edad; las columnas (nmx, nqx, lx, ndx,
#             nLx, Tx, ex, 5P) por la coordenada x del borde derecho (agrupamiento
#             por huecos), no por el orden del texto de pdftotext -layout, que
#             mezcla filas contiguas.
#          2. Normalizacion de numeros: separadores de miles/decimales mixtos
#             (coma o punto): nmx, nqx, 5P y ex llevan decimales (coma -> punto);
#             lx, ndx, nLx y Tx son enteros (se eliminan todos los separadores;
#             lx en base 100.000).
#          3. Validacion con identidades de la tabla de vida (ver violations()):
#             l0 = 100000; ndx = lx[x]-lx[x+n] = lx*nqx; ndx(80+) = lx(80+); nqx(80+) = 1;
#             Tx = Tx[x+n] + nLx, T80 = L80; ex = Tx/lx; nLx entre n*lx[x+n] y n*lx[x];
#             5P = L[x+5]/L[x] (0: (L0+L1-4)/(5 l0); 1-4: L5/(L0+L1-4); 75-79: T80/T75);
#             nmx ~ ndx/nLx y nqx ~ 5mx/(1+2.5mx) (solo coherencia, tolerancia 2-3%).
#             Las tolerancias salen de las tablas limpias (154 de 176 bloques sin
#             ninguna violacion): lx/ndx/Tx/nLx a +-1 (enteros), ex a +-0.0055,
#             5P a +-3e-5 + redondeo, ndx vs lx*nqx a 1 + 0.5*10^-decimales(nqx)*lx.
#          4. Reparaciones (solo si hay solucion unica, bloque sin fallas en la
#             cadena lx/ndx/Tx/nLx):
#               - ex que no cuadra con Tx/lx  -> round(Tx/lx, 2)       [corregido]
#               - 5P que no cuadra con L o T  -> cociente esperado     [corregido]
#               - 5P de 75-79 impreso en la fila 80+ (desplazado)      [corregido]
#               - nmx de 0 con razon nmx/nqx > 3 (decimal desplazado)  -> nmx/10
#               - nmx (>=5 anios) con |nmx/qm - 1| > 8% en bloques con <= 2 casos
#                 -> nqx/(5-2.5 nqx) (aprox. +-0.5%)                   [corregido]
#             Sin ningun caso de celda ausente: el texto impreso esta completo
#             (origen 'recalculado' queda previsto pero no se usa).  Las celdas
#             leidas de la imagen (origen 'imagen') se toman de
#             anexo1_corrections.csv (filas con origen == 'imagen'); no hizo falta
#             ninguna porque la capa de texto coincide con lo impreso (se
#             verificaron visualmente p. 71, 72, 73, 108, 117, 128, 133, 153).
#             Las inconsistencias que son del propio impreso y no tienen solucion
#             unica (cadena Tx de Santander 2005 y Putumayo 1985, mx de Colombia
#             1985, San Andres, mx infantiles) NO se corrigen: se documentan en
#             anexo1_source_inconsistencies.csv.
#
# Salidas: data_input/historical/dane_conciliacion_1985_2005_anexo1_tablas_vida_censales.csv
#          data_input/historical/dane_conciliacion_1985_2005_support/anexo1_verification.csv
#          .../anexo1_corrections.csv  .../anexo1_source_inconsistencies.csv
#          .../anexo1_colombia_e0_vs_cuadro314.csv
# Ejecutar desde la raiz del proyecto:  Rscript code/historical/31b_extract_conciliacion_annex1_lifetables.R
# Fecha  : 2026-11-12
# =============================================================================

suppressPackageStartupMessages(library(pdftools))

PDF <- "data_input/dane_pdfs/censos/5Mortalidad85_05.pdf"
OUT <- "data_input/historical/dane_conciliacion_1985_2005_anexo1_tablas_vida_censales.csv"
SUP <- "data_input/historical/dane_conciliacion_1985_2005_support"
PAGES <- 71:158
stopifnot(file.exists(PDF))
dir.create(SUP, showWarnings = FALSE, recursive = TRUE)

AGES <- c(0, 1, seq(5, 80, 5))
COLS <- c("nmx", "nqx", "lx", "ndx", "nLx", "Tx", "ex", "p_sobrev")
N_AGE <- c(1, 4, rep(5, 16))
UNIT_CODE <- c("Colombia" = "00", "Antioquia" = "05", "Atlántico" = "08", "Bogotá" = "11",
  "Bolívar" = "13", "Boyacá" = "15", "Caldas" = "17", "Caquetá" = "18", "Cauca" = "19",
  "Cesar" = "20", "Córdoba" = "23", "Cundinamarca" = "25", "Chocó" = "27", "Huila" = "41",
  "La Guajira" = "44", "Magdalena" = "47", "Meta" = "50", "Nariño" = "52",
  "Norte de Santander" = "54", "Quindío" = "63", "Risaralda" = "66", "Santander" = "68",
  "Sucre" = "70", "Tolima" = "73", "Valle del Cauca" = "76", "Arauca" = "81",
  "Casanare" = "85", "Putumayo" = "86", "San Andrés" = "88",
  "Grupo Amazonia" = "AMZ")   # Amazonas 91, Guainia 94, Guaviare 95, Vaupes 97, Vichada 99 agrupados

D <- pdf_data(PDF)

# ------------------------------------------------------------------ parsing --
parse_page <- function(p, gap = 12) {
  d <- D[[p]]
  lab <- d[d$x < 120 & d$y > 195 & grepl("^[0-9]+$", d$text), ]
  lab <- lab[order(lab$y, lab$x), ]
  grp <- cumsum(c(1, diff(lab$y) > 3))
  rows <- do.call(rbind, lapply(split(lab, grp), function(g)
    data.frame(y = mean(g$y), age = as.integer(g$text[1]))))
  out <- data.frame(y = numeric(), age = integer(), block = integer())
  b <- 1; expected <- 1
  for (i in seq_len(nrow(rows))) {
    a <- rows$age[i]
    if (a == AGES[expected]) {
      out <- rbind(out, data.frame(y = rows$y[i], age = a, block = b)); expected <- expected + 1
      if (expected > 18) { expected <- 1; b <- b + 1 }
    } else if (expected == 1 && a == AGES[2]) {   # etiqueta '0' ausente en la capa de texto
      out <- rbind(out, data.frame(y = NA, age = 0, block = b),
                   data.frame(y = rows$y[i], age = a, block = b)); expected <- 3
    }
  }
  for (i in which(is.na(out$y)))
    out$y[i] <- out$y[i + 1] - median(diff(out$y[out$block == out$block[i]]), na.rm = TRUE)
  stopifnot(nrow(out) == 36)
  num <- d[d$x >= 120 & d$y > 160 & nchar(d$text) >= 2 & grepl("^[0-9.,]*[0-9][0-9.,]*$", d$text), ]
  num$r <- num$x + num$width
  num$ri <- NA_integer_
  for (i in seq_len(nrow(num))) {   # fila = etiqueta mas cercana por debajo (la y del dato puede ir hasta 6 pt mas arriba)
    dd <- out$y - num$y[i]; ok <- which(dd >= -1.5 & dd <= 14)
    if (length(ok)) num$ri[i] <- ok[which.min(dd[ok])]
  }
  cells <- num[!is.na(num$ri), ]
  foot <- num[is.na(num$ri), ]
  re <- sort(cells$r)
  centers <- tapply(re, cumsum(c(1, diff(re) > gap)), median)
  stopifnot(length(centers) == 8)
  cells$col <- sapply(cells$r, function(r) which.min(abs(centers - r)))
  stopifnot(!any(duplicated(cells[, c("ri", "col")])))
  list(rows = out, cells = cells, foot = foot)
}

page_title <- function(p) {
  d <- D[[p]]; t <- d[grepl("^Tablas?$", d$text), ][1, ]
  ln <- d[abs(d$y - t$y) < 3 & d$y < 170, ]; ln <- ln[order(ln$x), ]
  txt <- paste(ln$text, collapse = " ")
  list(unit = sub("[.]? Tablas? de mortalidad.*$", "", txt),
       anio = as.integer(regmatches(txt, regexpr("(1985|1993|2005)", txt))))
}

dec_of <- function(tok) if (is.na(tok)) NA_integer_ else nchar(sub("^[^.,]*[.,]?", "", tok))
to_num <- function(tok, col) {
  if (col %in% c("nmx", "nqx", "p_sobrev", "ex")) as.numeric(sub(",", ".", tok))
  else as.numeric(gsub("[.,]", "", tok))
}

# --------------------------------------------------------------- identities --
violations <- function(M, DEC) {
  v <- list()
  add <- function(id, bad, cells, age) v[[length(v) + 1]] <<- data.frame(id = id, bad = bad, cells = cells, edad = age, stringsAsFactors = FALSE)
  m <- M[, "nmx"]; q <- M[, "nqx"]; l <- M[, "lx"]; d <- M[, "ndx"]; L <- M[, "nLx"]
  T <- M[, "Tx"]; e <- M[, "ex"]; P <- M[, "p_sobrev"]
  chk <- function(x, tol) ifelse(is.na(x), NA, abs(x) > tol)
  add("l0", chk(l[1] - 100000, 0.5), "lx@1", 0)
  for (i in 1:17) {
    add(paste0("A1_", i), chk(d[i] - (l[i] - l[i + 1]), 1), paste0("ndx@", i, ",lx@", i, ",lx@", i + 1), AGES[i])
    dq <- if (is.na(DEC[i, 2])) 6 else DEC[i, 2]
    add(paste0("A2_", i), chk(d[i] - l[i] * q[i], 1 + 0.5 * 10^(-dq) * l[i]), paste0("ndx@", i, ",lx@", i, ",nqx@", i), AGES[i])
  }
  add("A3d", chk(d[18] - l[18], 1), "ndx@18,lx@18", 80)
  add("A3q", chk(q[18] - 1, 1e-6), "nqx@18", 80)
  for (i in 1:17) add(paste0("B1_", i), chk(T[i] - (T[i + 1] + L[i]), 1), paste0("Tx@", i, ",Tx@", i + 1, ",nLx@", i), AGES[i])
  add("B1_18", chk(T[18] - L[18], 1), "Tx@18,nLx@18", 80)
  for (i in 1:18) add(paste0("B2_", i), chk(e[i] - T[i] / l[i], 0.0055), paste0("ex@", i, ",Tx@", i, ",lx@", i), AGES[i])
  for (i in 1:17) {
    lo <- N_AGE[i] * l[i + 1]; hi <- N_AGE[i] * l[i]
    bad <- if (is.na(L[i]) || is.na(lo) || is.na(hi)) NA else (L[i] < lo - 1 || L[i] > hi + 1)
    add(paste0("B3_", i), bad, paste0("nLx@", i, ",lx@", i, ",lx@", i + 1), AGES[i])
  }
  Pexp <- Pexp_of(M)
  for (i in 1:17) {
    dp <- if (is.na(DEC[i, 3])) 5 else DEC[i, 3]
    add(paste0("C1_", i), chk(P[i] - Pexp[i], 3e-5 + 0.5 * 10^(-dp)), paste0("p_sobrev@", i), AGES[i])
  }
  for (i in 3:17) {   # coherencia (no identidad exacta): mx ~ ndx/nLx y nqx ~ 5mx/(1+2.5mx)
    dm <- if (is.na(DEC[i, 1])) 5 else DEC[i, 1]
    tol <- 0.5 * 10^(-dm) + abs(m[i]) * (0.5 / max(d[i], 1) + 0.02) + 2e-6
    add(paste0("C2_", i), chk(m[i] - d[i] / L[i], tol), paste0("nmx@", i, ",ndx@", i, ",nLx@", i), AGES[i])
    qm <- 5 * m[i] / (1 + 2.5 * m[i])
    add(paste0("C3_", i), ifelse(is.na(q[i] - qm), NA, abs(q[i] - qm) > 0.03 * qm + 3e-5), paste0("nmx@", i, ",nqx@", i), AGES[i])
  }
  do.call(rbind, v)
}
Pexp_of <- function(M) {
  L <- M[, "nLx"]; T <- M[, "Tx"]; l <- M[, "lx"]
  Pe <- rep(NA_real_, 18)
  Pe[1] <- (L[1] + L[2]) / (5 * l[1]); Pe[2] <- L[3] / (L[1] + L[2])
  for (i in 3:16) Pe[i] <- L[i + 1] / L[i]
  Pe[17] <- T[18] / T[17]; Pe
}

# ------------------------------------------------------------------- repairs --
fix_block <- function(M, DEC, TOK) {
  ch <- list()
  rec <- function(i, col, new, reason, origen = "corregido") {
    ch[[length(ch) + 1]] <<- data.frame(i = i, col = col, tok = TOK[i, col], new = new, origen = origen, reason = reason, stringsAsFactors = FALSE)
    M[i, col] <<- new
  }
  vv <- violations(M, DEC); fail <- vv$id[vv$bad %in% TRUE]
  chain_ok <- !any(grepl("^(l0|A|B1|B3)", fail))
  if (chain_ok) {
    for (i in 1:18) if (paste0("B2_", i) %in% fail) {
      new <- round(M[i, "Tx"] / M[i, "lx"], 2)
      rec(i, "ex", new, if (dec_of(TOK[i, "ex"]) < 2)
        "ex impreso con 1 decimal; recalculado Tx/lx a 2 decimales"
        else sprintf("ex impreso (%s) no cuadra con Tx/lx = %.2f", TOK[i, "ex"], new))
    }
    Pe <- Pexp_of(M)
    if (!is.na(M[18, "p_sobrev"]) && "C1_17" %in% fail) {   # 5P75+ impreso una fila abajo (80+)
      dp <- if (is.na(DEC[17, 3])) 5 else DEC[17, 3]
      if (abs(M[18, "p_sobrev"] - Pe[17]) < 3e-5 + 0.5 * 10^(-dp)) {
        rec(17, "p_sobrev", M[18, "p_sobrev"], sprintf("5P75+ (c/) impreso en la fila 80+ (%s); en la fila 75-79 aparece %s, que no cuadra con T80/T75 = %.5f", TOK[18, "p_sobrev"], TOK[17, "p_sobrev"], Pe[17]))
        rec(18, "p_sobrev", NA_real_, "celda desplazada: el valor 5P75+ pertenece a la fila 75-79; la fila 80+ no tiene 5P")
        fail <- setdiff(fail, "C1_17")
      }
    }
    for (i in 1:17) if (paste0("C1_", i) %in% fail && !is.na(Pe[i])) {
      dp <- if (is.na(DEC[i, 3])) 5 else DEC[i, 3]
      rec(i, "p_sobrev", round(Pe[i], dp), sprintf("5P impreso (%s) no cuadra con el cociente de nLx/Tx = %.5f", TOK[i, "p_sobrev"], Pe[i]))
    }
  }
  # nmx infantil con decimal desplazado
  if (!is.na(M[1, "nmx"]) && M[1, "nmx"] / M[1, "nqx"] > 3)
    rec(1, "nmx", round(M[1, "nmx"] / 10, 5), sprintf("nmx0 impreso (%s) es ~10x nqx0 (decimal/digitos desplazados, p.ej. 0,39890 por 0,03989); se divide por 10 (razon nmx/nqx pasa a %.2f); no derivable de identidades exactas", TOK[1, "nmx"], M[1, "nmx"] / 10 / M[1, "nqx"]))
  # nmx (>=5) groseramente incoherente con nqx en bloques cuyo resto es coherente
  q <- M[, "nqx"]; m <- M[, "nmx"]; idx <- 3:17
  qm_inv <- q[idx] / (5 - 2.5 * q[idx])
  r3 <- m[idx] / qm_inv
  flag <- idx[!is.na(r3) & abs(log(r3)) > log(1.08)]
  if (length(flag) >= 1 && length(flag) <= 2 && chain_ok) for (i in flag) {
    dm <- if (is.na(DEC[i, 1])) 5 else DEC[i, 1]
    rec(i, "nmx", round(q[i] / (5 - 2.5 * q[i]), dm), sprintf("nmx impreso (%s) incoherente con nqx y ndx/nLx (razon %.2f); se reemplaza por nqx/(5-2.5nqx) con precision aprox. +-0.5%% (el resto de la tabla cumple esa relacion)", TOK[i, "nmx"], r3[i - 2]))
  }
  list(M = M, ch = if (length(ch)) do.call(rbind, ch) else NULL)
}

# ------------------------------------------------------------------- driver --
sex_lab <- c("hombres", "mujeres")
blocks <- list(); chg <- list(); ver <- list(); inc <- list()
img_file <- file.path(SUP, "anexo1_corrections.csv")
img <- if (file.exists(img_file)) { x <- read.csv(img_file, stringsAsFactors = FALSE, encoding = "UTF-8"); x[x$origen == "imagen", ] } else NULL
if (!is.null(img) && nrow(img) == 0) img <- NULL

for (p in PAGES) {
  r <- parse_page(p); ti <- page_title(p)
  stopifnot(ti$unit %in% names(UNIT_CODE), ti$anio %in% c(1985, 1993, 2005))
  y2 <- r$rows$y[r$rows$block == 2 & r$rows$age == 0]
  f <- r$foot[grepl("^[0-9][.,][0-9]+$", r$foot$text), ]; f$block <- ifelse(f$y < y2, 1, 2)
  for (b in 1:2) {
    s <- r$cells[r$rows$block[r$cells$ri] == b, ]
    ri <- match(r$rows$age[s$ri], AGES)
    M <- matrix(NA_real_, 18, 8, dimnames = list(NULL, COLS))
    TOK <- matrix(NA_character_, 18, 8, dimnames = list(NULL, COLS))
    DEC <- matrix(NA_integer_, 18, 3)
    for (j in seq_len(nrow(s))) {
      col <- COLS[s$col[j]]
      M[ri[j], col] <- to_num(s$text[j], col); TOK[ri[j], col] <- s$text[j]
      if (col == "nmx") DEC[ri[j], 1] <- dec_of(s$text[j])
      if (col == "nqx") DEC[ri[j], 2] <- dec_of(s$text[j])
      if (col == "p_sobrev") DEC[ri[j], 3] <- dec_of(s$text[j])
    }
    stopifnot(!anyNA(M[, 1:7]))
    g <- f[f$block == b, ]; g <- g[order(g$x), ]
    F0 <- if (nrow(g) >= 1) as.numeric(sub(",", ".", g$text[1])) else NA
    K1 <- if (nrow(g) >= 2) as.numeric(sub(",", ".", g$text[2])) else NA
    v0 <- violations(M, DEC)
    fx <- fix_block(M, DEC, TOK)
    M2 <- fx$M
    ORI <- matrix("texto", 18, 8, dimnames = list(NULL, COLS))
    ch <- fx$ch
    if (!is.null(ch)) for (k in seq_len(nrow(ch))) ORI[ch$i[k], ch$col[k]] <- ch$origen[k]
    imgb <- if (!is.null(img)) img[img$page == p & img$sex == sex_lab[b], ] else NULL   # celdas leidas de la imagen
    if (!is.null(imgb) && nrow(imgb)) for (k in seq_len(nrow(imgb))) {
      i <- match(imgb$age[k], AGES); M2[i, imgb$column[k]] <- imgb$final_value[k]; ORI[i, imgb$column[k]] <- "imagen"
      ch <- rbind(ch, data.frame(i = i, col = imgb$column[k], tok = TOK[i, imgb$column[k]], new = imgb$final_value[k], origen = "imagen", reason = imgb$reason[k], stringsAsFactors = FALSE))
    }
    v1 <- violations(M2, DEC)
    blocks[[length(blocks) + 1]] <- data.frame(
      unidad_codigo = UNIT_CODE[[ti$unit]], unidad = ti$unit, anio = ti$anio, sexo = sex_lab[b],
      edad_inicio = AGES, edad_fin = c(AGES[-1], NA), M2,
      pagina = p, setNames(as.data.frame(ORI), paste0("origen_", COLS)),
      F0 = F0, K1_4 = K1, stringsAsFactors = FALSE, row.names = NULL)
    if (!is.null(ch)) chg[[length(chg) + 1]] <- data.frame(
      page = p, unit = ti$unit, year = ti$anio, sex = sex_lab[b], age = AGES[ch$i], column = ch$col,
      text_layer_value = ch$tok, final_value = ch$new, origen = ch$origen, reason = ch$reason, stringsAsFactors = FALSE)
    ncor <- if (is.null(ch)) 0 else sum(ch$origen == "corregido")
    nrec <- if (is.null(ch)) 0 else sum(ch$origen == "recalculado")
    nimg <- if (is.null(ch)) 0 else sum(ch$origen == "imagen")
    ver[[length(ver) + 1]] <- data.frame(
      pagina = p, unidad_codigo = UNIT_CODE[[ti$unit]], unidad = ti$unit, anio = ti$anio, sexo = sex_lab[b],
      celdas_texto = sum(!is.na(M)),
      identidades_verificadas = sum(!is.na(v1$bad[!grepl("^C[23]", v1$id)])),
      fallan_texto = sum(v0$bad[!grepl("^C[23]", v0$id)], na.rm = TRUE),
      fallan_final = sum(v1$bad[!grepl("^C[23]", v1$id)], na.rm = TRUE),
      coherencia_mx_verificadas = sum(!is.na(v1$bad[grepl("^C[23]", v1$id)])),
      coherencia_mx_fallan_texto = sum(v0$bad[grepl("^C[23]", v0$id)], na.rm = TRUE),
      coherencia_mx_fallan_final = sum(v1$bad[grepl("^C[23]", v1$id)], na.rm = TRUE),
      celdas_corregidas = ncor, celdas_recalculadas = nrec, celdas_imagen = nimg,
      identidades_fallan_final = paste(v1$id[v1$bad %in% TRUE], collapse = " "), stringsAsFactors = FALSE)
    # inconsistencias residuales del impreso
    bad <- v1[v1$bad %in% TRUE, ]
    descr <- c(l0 = "lx(0) distinto de 100000", A1 = "ndx distinto de lx[x]-lx[x+n]", A2 = "ndx distinto de lx*nqx", A3d = "ndx(80+) distinto de lx(80+)",
               A3q = "nqx(80+) distinto de 1", B1 = "Tx distinto de Tx[x+n]+nLx", B2 = "ex distinto de Tx/lx", B3 = "nLx fuera de [n*lx[x+n], n*lx[x]]",
               C1 = "5P distinto del cociente esperado de nLx/Tx", C2 = "nmx incoherente con ndx/nLx (>2%)", C3 = "nmx incoherente con nqx (>3%)")
    if (nrow(bad)) {
      fam <- sub("_.*$", "", bad$id)
      vals <- sapply(seq_len(nrow(bad)), function(k) {
        cs <- strsplit(bad$cells[k], ",")[[1]]
        paste(sapply(cs, function(cc) { cl <- sub("@.*", "", cc); ii <- as.integer(sub(".*@", "", cc)); sprintf("%s[%s]=%s", cl, AGES[ii], TOK[ii, cl]) }), collapse = "; ")
      })
      inc[[length(inc) + 1]] <- data.frame(pagina = p, unidad = ti$unit, anio = ti$anio, sexo = sex_lab[b], edad = bad$edad,
        tipo = ifelse(fam %in% c("C2", "C3"), "coherencia_mx_falla_en_el_impreso", "identidad_falla_en_el_impreso"), identidad = bad$id, descripcion = descr[fam], valores_impresos = vals, stringsAsFactors = FALSE)
    }
    r0 <- M2[1, "nmx"] / M2[1, "nqx"]; r1 <- 4 * M2[2, "nmx"] / M2[2, "nqx"]   # mx infantiles incoherentes con nqx (no corregibles)
    if (r0 < 0.15 || r0 > 1.6 || r1 < 0.15 || r1 > 1.6)
      inc[[length(inc) + 1]] <- data.frame(pagina = p, unidad = ti$unit, anio = ti$anio, sexo = sex_lab[b], edad = "0 y 1-4",
        tipo = "mx_infantil_incoherente", identidad = "nmx0/nqx0, 4*nmx1/nqx1", descripcion = "nmx de 0 y/o 1-4 muy distinto de nqx (razones tipicas 0.4-1.1); posible escala/digito perdido; sin solucion unica, no corregido",
        valores_impresos = sprintf("nmx0=%s nqx0=%s (razon %.2f); nmx1-4=%s nqx1-4=%s (razon 4m/q %.2f)", TOK[1, "nmx"], TOK[1, "nqx"], r0, TOK[2, "nmx"], TOK[2, "nqx"], r1), stringsAsFactors = FALSE)
  }
}

TL <- do.call(rbind, blocks)
CH <- do.call(rbind, chg); VER <- do.call(rbind, ver); INC <- do.call(rbind, inc)

# valores impresos erroneos que se corrigieron: tambien son inconsistencias de la fuente
INC <- rbind(INC, data.frame(pagina = CH$page, unidad = CH$unit, anio = CH$year, sexo = CH$sex, edad = CH$age,
  tipo = "impreso_erroneo_corregido", identidad = CH$column, descripcion = CH$reason,
  valores_impresos = paste0(CH$column, "=", CH$text_layer_value), stringsAsFactors = FALSE))
units <- unique(TL$unidad)   # tablas ausentes
miss <- expand.grid(unidad = units, anio = c(1985, 1993, 2005), stringsAsFactors = FALSE)
miss <- miss[!paste(miss$unidad, miss$anio) %in% paste(TL$unidad, TL$anio), ]
if (nrow(miss)) INC <- rbind(INC, data.frame(pagina = NA, unidad = miss$unidad, anio = miss$anio, sexo = "ambos", edad = NA,
  tipo = "tabla_ausente_en_el_anexo", identidad = NA, descripcion = "el Anexo 1 no contiene esta tabla (ni en las paginas 71-158 ni con otro titulo)", valores_impresos = NA, stringsAsFactors = FALSE))
INC <- INC[order(INC$tipo, INC$pagina, INC$sexo, suppressWarnings(as.numeric(INC$edad))), ]

TL <- TL[order(TL$unidad_codigo, TL$anio, TL$sexo, TL$edad_inicio), ]
rownames(TL) <- NULL
for (cc in c("lx", "ndx", "nLx", "Tx")) TL[[cc]] <- as.integer(TL[[cc]])   # evita notacion cientifica (1e+05)
w <-function(x, f) write.csv(x, f, row.names = FALSE, fileEncoding = "UTF-8")
w(TL, OUT)
w(VER, file.path(SUP, "anexo1_verification.csv"))
w(CH, file.path(SUP, "anexo1_corrections.csv"))   # todas las celdas no 'texto' (incluye las 'imagen' leidas a mano)
w(INC, file.path(SUP, "anexo1_source_inconsistencies.csv"))

# ----------------------------------------- comparacion e0 Colombia vs Tabla 3.14
tab314 <- data.frame(anio = c(1985, 1993, 2005), e0_hombres_cuadro314 = c(64.39, 65.41, 70.20), e0_mujeres_cuadro314 = c(70.65, 73.74, 77.11))
col <- TL[TL$unidad_codigo == "00" & TL$edad_inicio == 0, ]
cmp <- merge(tab314, data.frame(anio = col$anio[col$sexo == "hombres"], e0_hombres_anexo1 = col$ex[col$sexo == "hombres"]), by = "anio")
cmp <- merge(cmp, data.frame(anio = col$anio[col$sexo == "mujeres"], e0_mujeres_anexo1 = col$ex[col$sexo == "mujeres"]), by = "anio")
cmp$dif_hombres <- round(cmp$e0_hombres_anexo1 - cmp$e0_hombres_cuadro314, 2)
cmp$dif_mujeres <- round(cmp$e0_mujeres_anexo1 - cmp$e0_mujeres_cuadro314, 2)
w(cmp, file.path(SUP, "anexo1_colombia_e0_vs_cuadro314.csv"))

cat("Filas:", nrow(TL), " tablas (unidad x anio):", nrow(unique(TL[, c("unidad", "anio")])), "\n")
cat("Celdas corregidas:", sum(CH$origen == "corregido"), " recalculadas:", sum(CH$origen == "recalculado"), " imagen:", sum(CH$origen == "imagen"), "\n")
cat("Bloques (tabla x sexo):", nrow(VER), " sin fallas de identidades:", sum(VER$fallan_final == 0), "\n")
print(cmp)
if (nrow(miss)) print(miss)
