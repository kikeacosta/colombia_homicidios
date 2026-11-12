# =============================================================================
# 31c_extract_conciliacion_annex3_lifetables.R
#
# Fuente : DANE (mayo 2007), "Conciliacion censal 1985-2005. Colombia.
#          Estimacion de la mortalidad 1985-2005", ANEXO 3 "Tablas de mortalidad
#          quinquenios 1985-2005. Nacional y departamental" (paginas 167-286 del
#          PDF; 30 unidades x 4 quinquenios = 120 cuadros k.4 a k.7).
#          data_input/dane_pdfs/censos/5Mortalidad85_05.pdf
#          (el Anexo 4 empieza en la pagina 287).
# Fecha  : 2026-11-12
#
# Metodo :
#  1. pdftools::pdf_data() da cada palabra con (x, y). Cada cuadro tiene dos
#     bloques (Hombres / Mujeres) de 18 filas de edad. Las filas se identifican
#     por la etiqueta de edad (x <= 90) y cada celda se asigna a la fila de y mas
#     cercana y a la columna por su borde derecho (columnas alineadas a la
#     derecha). NO se usa el orden de pdftotext -layout (que desordena celdas:
#     p.ej. el Tx de una fila aparece en la fila vecina).
#     Orden de columnas de este anexo: nmx, nqx, lx, ndx, nLx, P(5,x..x+4), Tx, ex.
#  2. Normalizacion: nmx, nqx, P en 0-1 (coma decimal); lx, ndx, nLx, Tx enteros
#     (el punto es separador de miles); ex en anios. F0 y 4K1 del pie de bloque.
#  3. Validacion con identidades de la tabla de vida (ver check_block()):
#       l0 = 100000; ndx = lx[x]-lx[x+n]; lx[x+n] = lx[x](1-nqx);
#       nqx = ndx/lx; nmx = ndx/nLx; ultimo intervalo nqx=1, ndx=lx;
#       Tx = suma acumulada de nLx desde la edad mas vieja; ex = Tx/lx;
#       P: fila 0 = (L0+L1)/(5 l0); fila 1a4 = nL5/(L0+L1);
#          filas 5a9..70a74 = nL[x+5]/nL[x]; 75a79 = T80/T75; 80+ en blanco;
#       qx ~ 5mx/(1+2.5mx) para edades >= 5 (solo bandera).
#     Tolerancias aprendidas de las tablas limpias (redondeo de la fuente).
#  4. Correcciones: support/anexo3_corrections.csv (puede estar vacio) permite
#     fijar celdas (corregido / recalculado / imagen) con las columnas
#     pagina, sexo, edad_inicio, columna, valor_final, origen. Se aplican antes
#     de validar. Resultado actual: ninguna celda requirio correccion (la capa
#     de texto, leida por posicion, cumple todas las identidades); lo que
#     falla es de la fuente impresa y se documenta en
#     support/anexo3_source_inconsistencies.csv (no se "arregla").
#  5. Salidas: CSV largo + verification / corrections / source_inconsistencies.
#
# Uso: Rscript code/historical/31c_extract_conciliacion_annex3_lifetables.R
#      (desde la raiz del proyecto)
# =============================================================================
suppressMessages(library(pdftools))
options(scipen = 100)

pdf_path <- "data_input/dane_pdfs/censos/5Mortalidad85_05.pdf"
out_dir  <- "data_input/historical"
sup_dir  <- file.path(out_dir, "dane_conciliacion_1985_2005_support")
out_csv  <- file.path(out_dir, "dane_conciliacion_1985_2005_anexo3_tablas_vida_quinquenales.csv")
corr_csv <- file.path(sup_dir, "anexo3_corrections.csv")
dir.create(sup_dir, showWarnings = FALSE, recursive = TRUE)

pages <- 167:286
cols  <- c("nmx", "nqx", "lx", "ndx", "nLx", "p_sobrev", "Tx", "ex")
col_breaks <- c(0, 210, 260, 300, 350, 400, 460, 510, Inf)   # bordes derechos
ages  <- c(0, 1, seq(5, 80, 5))
ends  <- c(ages[-1], NA)

# codigos DANE de departamento (DP); 00 = Colombia
codes <- c("Nacional" = "00", "Bogot<<e1>> D.C." = "11", "Antioquia" = "05", "Arauca" = "81",
  "Atl<<e1>>ntico" = "08", "Bol<<ed>>var" = "13", "Boyaca" = "15", "Caldas" = "17", "Caquet<<e1>>" = "18",
  "Casanare" = "85", "Cauca" = "19", "Cesar" = "20", "Choc<<f3>>" = "27", "C<<f3>>rdoba" = "23",
  "Cundinamarca" = "25", "Huila" = "41", "La Guajira" = "44", "Magdalena" = "47",
  "Meta" = "50", "Nari<<f1>>o" = "52", "Norte de Santander" = "54", "Putumayo" = "86",
  "Risaralda" = "66", "San Andr<<e9>>s" = "88", "Santander" = "68", "Sucre" = "70",
  "Tolima" = "73", "Valle del Cauca" = "76", "Quind<<ed>>o" = "63",
  # Amazonas 91 + Guainia 94 + Guaviare 95 + Vaupes 97 + Vichada 99
  "Grupo Amazon<<ed>>a" = "91+94+95+97+99")
# los acentos se escriben como <<hex>> (Latin-1) para no depender de la codificacion del script
for (h in c("e1", "e9", "ed", "f3", "f1"))
  names(codes) <- gsub(paste0("<<", h, ">>"), intToUtf8(strtoi(h, 16L)), names(codes), fixed = TRUE)
quin <- c("4" = "1985-1990", "5" = "1990-1995", "6" = "1995-2000", "7" = "2000-2005")

num <- function(t, col) {
  if (col %in% c("nmx", "nqx", "p_sobrev", "ex", "F0", "K41")) as.numeric(sub(",", ".", t))
  else as.numeric(gsub("[.,]", "", t))
}
NL <- intToUtf8(10)

# ---- 1. extraccion por posicion ---------------------------------------------
txt <- pdf_text(pdf_path)
pd  <- pdf_data(pdf_path)
rows <- list()
for (p in pages) {
  l <- trimws(strsplit(txt[p], NL, fixed = TRUE)[[1]]); l <- l[nzchar(l)]
  i <- grep("^Cuadro", l)[1]; j <- grep("^Edades", l)[1]
  cuadro <- sub("^Cuadro ", "", l[i])
  unidad <- sub(" Tabla de mortalidad.*$", "", l[i + 1])
  if (!grepl("D[.]C[.]$", unidad)) unidad <- sub("[.]$", "", unidad)
  qn <- quin[sub("^.*[.]", "", cuadro)]
  stopifnot(identical(trimws(l[j - 1]), unname(qn)), unidad %in% names(codes))
  d <- pd[[p]]; d$r <- d$x + d$width
  hy <- d$y[d$text == "Hombres"]; my <- d$y[d$text == "Mujeres"]
  stopifnot(length(hy) == 1, length(my) == 1)
  for (sx in c("hombres", "mujeres")) {
    y0 <- if (sx == "hombres") hy else my
    y1 <- if (sx == "hombres") my else max(d$y) + 1
    lab <- d[d$x <= 90 & d$y > y0 & d$y < y1 & grepl("^[0-9]+$", d$text), ]
    lab <- lab[order(lab$y), ]
    stopifnot(nrow(lab) == 18, all(as.numeric(lab$text) == ages))
    dd <- d[d$x >= 140 & d$y > y0 & d$y < y1, ]
    b <- data.frame(unidad_codigo = codes[[unidad]], unidad = unidad, cuadro = cuadro,
                    quinquenio = unname(qn), sexo = sx, edad_inicio = ages, edad_fin = ends,
                    matrix(NA_real_, 18, 8, dimnames = list(NULL, cols)), F0 = NA_real_,
                    K41 = NA_real_, pagina = p, celdas_no_texto = "",
                    stringsAsFactors = FALSE)
    for (k in seq_len(nrow(dd))) {
      w <- dd[k, ]; jj <- which.min(abs(lab$y - w$y))
      if (abs(lab$y[jj] - w$y) <= 5) {
        cn <- cols[findInterval(w$r, col_breaks)]
        stopifnot(is.na(b[[cn]][jj]))
        b[[cn]][jj] <- num(w$text, cn)
      } else if (abs(w$x - 159) < 8 && grepl("^[0-9],[0-9]{3}$", w$text)) {
        b$F0 <- num(w$text, "F0")
      } else if (abs(w$x - 258) < 8 && grepl("^[0-9],[0-9]{3}$", w$text)) {
        b$K41 <- num(w$text, "K41")
      }
    }
    rows[[length(rows) + 1]] <- b
  }
}
tab <- do.call(rbind, rows)
rownames(tab) <- NULL

# ---- 2. correcciones documentadas (si las hay) --------------------------------
corr_cols <- c("pagina", "unidad", "cuadro", "quinquenio", "sexo", "edad_inicio", "columna",
               "valor_texto", "valor_final", "origen", "motivo")
if (file.exists(corr_csv) && file.size(corr_csv) > 0) {
  corr <- read.csv(corr_csv, stringsAsFactors = FALSE, colClasses = c(unidad = "character"))
} else {
  corr <- as.data.frame(setNames(replicate(length(corr_cols), character(0), simplify = FALSE), corr_cols))
}
for (k in seq_len(nrow(corr))) {
  ix <- which(tab$pagina == corr$pagina[k] & tab$sexo == corr$sexo[k] &
              tab$edad_inicio == corr$edad_inicio[k])
  stopifnot(length(ix) == 1)
  tab[[corr$columna[k]]][ix] <- as.numeric(corr$valor_final[k])
  tab$celdas_no_texto[ix] <- paste(c(if (nzchar(tab$celdas_no_texto[ix])) tab$celdas_no_texto[ix],
                                     paste0(corr$columna[k], ":", corr$origen[k])), collapse = ";")
}

# ---- 3. validacion ----------------------------------------------------------
check_block <- function(b) {
  n <- 18; i <- 1:17
  L5 <- b$nLx[1] + b$nLx[2]
  Pc <- c(L5 / (5 * b$lx[1]), b$nLx[3] / L5, b$nLx[4:17] / b$nLx[3:16], b$Tx[18] / b$Tx[17])
  tolE <- if (all(abs(b$ex * 10 - round(b$ex * 10)) < 1e-6)) 0.0505 else 0.0055  # ex a 1 o 2 decimales
  list(
    l0      = abs(b$lx[1] - 1e5) <= 0,
    ndx_lx  = abs(b$ndx[i] - (b$lx[i] - b$lx[i + 1])) <= 1.01,
    lx_nqx  = abs(b$lx[i + 1] - b$lx[i] * (1 - b$nqx[i])) <= 1.5,
    nqx_ndx = abs(b$nqx - b$ndx / b$lx) <= 5.5e-6 + 0.7 / b$lx,
    nmx_ndx = abs(b$nmx - b$ndx / b$nLx) <= 5.5e-6 + b$nmx * (0.5 / b$ndx + 0.5 / b$nLx) * 1.2,
    ultimo  = c(b$nqx[n] == 1, b$ndx[n] == b$lx[n]),
    Tx_nLx  = c(abs(b$Tx[i] - b$Tx[i + 1] - b$nLx[i]) <= 1.01, b$Tx[n] == b$nLx[n]),
    ex_Tx   = abs(b$Tx / b$lx - b$ex) <= tolE,
    P_nLx   = abs(b$p_sobrev[i] - Pc[i]) <= 1e-5,
    qx_mx   = abs(b$nqx[3:17] - 5 * b$nmx[3:17] / (1 + 2.5 * b$nmx[3:17])) <= 4e-5)
}
ver <- list(); incons <- list()
for (pg in pages) for (sx in c("hombres", "mujeres")) {
  b <- tab[tab$pagina == pg & tab$sexo == sx, ]
  ck <- check_block(b)
  nchk <- sum(lengths(ck)); bad <- names(ck)[vapply(ck, function(z) any(!z, na.rm = TRUE), TRUE)]
  nfail <- sum(vapply(ck, function(z) sum(!z, na.rm = TRUE), 1))
  ver[[length(ver) + 1]] <- data.frame(
    unidad_codigo = b$unidad_codigo[1], unidad = b$unidad[1], cuadro = b$cuadro[1],
    quinquenio = b$quinquenio[1], sexo = sx, pagina = pg, identidades_verificadas = nchk,
    identidades_fallidas = nfail, detalle_fallos = paste(bad, collapse = ";"),
    celdas_texto = sum(!is.na(unlist(b[cols]))) - sum(nzchar(b$celdas_no_texto)),
    celdas_corregidas = sum(corr$origen == "corregido" & corr$pagina == pg & corr$sexo == sx),
    celdas_recalculadas = sum(corr$origen == "recalculado" & corr$pagina == pg & corr$sexo == sx),
    celdas_imagen = sum(corr$origen == "imagen" & corr$pagina == pg & corr$sexo == sx))
  # fallos que quedan = inconsistencias de la fuente impresa (se documentan, no se corrigen)
  if (!all(ck$ex_Tx)) for (r in which(!ck$ex_Tx)) incons[[length(incons) + 1]] <- data.frame(
    pagina = pg, unidad_codigo = b$unidad_codigo[1], unidad = b$unidad[1], cuadro = b$cuadro[1],
    quinquenio = b$quinquenio[1], sexo = sx, edad_inicio = b$edad_inicio[r], columna = "ex",
    valor_impreso = b$ex[r], valor_implicito = round(b$Tx[r] / b$lx[r], 3),
    descripcion = "ex impreso no coincide con Tx/lx; Tx es coherente con la suma de nLx (identidad Tx cumplida), por lo que la discrepancia esta en el ex impreso")
  for (nm in setdiff(bad, "ex_Tx")) incons[[length(incons) + 1]] <- data.frame(
    pagina = pg, unidad_codigo = b$unidad_codigo[1], unidad = b$unidad[1], cuadro = b$cuadro[1],
    quinquenio = b$quinquenio[1], sexo = sx, edad_inicio = NA, columna = nm, valor_impreso = NA,
    valor_implicito = NA, descripcion = "identidad no cumplida (revisar)")
}
ver <- do.call(rbind, ver)
incons <- if (length(incons)) do.call(rbind, incons) else data.frame()
# nota de precision: ex a 1 decimal en el bloque de mujeres de la pagina 167
incons <- rbind(incons, data.frame(
  pagina = 167, unidad_codigo = "00", unidad = "Nacional", cuadro = "1.4", quinquenio = "1985-1990",
  sexo = "mujeres", edad_inicio = NA, columna = "ex", valor_impreso = NA, valor_implicito = NA,
  descripcion = "ex impreso con 1 decimal (resto de la fuente: 2 decimales); valores conservados tal cual"))

# ---- 4. salidas ---------------------------------------------------------------
write.csv(tab, out_csv, row.names = FALSE, na = "", quote = FALSE, fileEncoding = "UTF-8")
write.csv(ver, file.path(sup_dir, "anexo3_verification.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
write.csv(corr, corr_csv, row.names = FALSE, na = "", fileEncoding = "UTF-8")
write.csv(incons, file.path(sup_dir, "anexo3_source_inconsistencies.csv"), row.names = FALSE, na = "",
          fileEncoding = "UTF-8")

cat("filas:", nrow(tab), " tablas:", nrow(ver), " identidades:", sum(ver$identidades_verificadas),
    " fallidas:", sum(ver$identidades_fallidas), "\n")
# e0 nacional frente al Anexo 2
print(tab[tab$unidad == "Nacional" & tab$edad_inicio == 0, c("quinquenio", "sexo", "ex")])
