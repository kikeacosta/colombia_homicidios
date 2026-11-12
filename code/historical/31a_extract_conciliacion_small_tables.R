# 31a_extract_conciliacion_small_tables.R
# Fuente : DANE, "Conciliacion censal 1985-2005. Colombia. Estimacion de la mortalidad
#          1985-2005" (mayo 2007), data_input/dane_pdfs/censos/5Mortalidad85_05.pdf (299 p.)
# Metodo : capa de texto del PDF. Las tablas pequenas se leen con pdftools::pdf_data()
#          (palabras con coordenadas x,y), no con el texto en flujo (pdftotext -layout),
#          porque este desordena columnas (Tabla 3.3 mujeres, Tabla 3.14 diferencial,
#          Anexo 2). Cada pagina fue ademas verificada contra la imagen renderizada.
#          Tabla 3.13: lineas de texto con regex (el orden en la capa de texto es correcto).
# Tablas : Tabla 3.3 (p.31), Tabla 3.13 (p.45), Tabla 3.14 (p.46), Anexo 2 (p.160-165).
# Salidas: data_input/historical/dane_conciliacion_1985_2005_*.csv y
#          .../dane_conciliacion_1985_2005_support/small_tables_{verification,corrections}.csv
# Fecha  : 2026-11-12. Ejecutar desde la raiz del proyecto.

pdf <- "data_input/dane_pdfs/censos/5Mortalidad85_05.pdf"
out <- "data_input/historical"
sup <- file.path(out, "dane_conciliacion_1985_2005_support")
dir.create(sup, showWarnings = FALSE, recursive = TRUE)
pre <- "dane_conciliacion_1985_2005_"
pd  <- pdftools::pdf_data(pdf)
num <- function(x) as.numeric(sub(",", ".", x, fixed = TRUE))
corr <- list(); ver <- list()
addv <- function(tab, chk, n, nf, note = "") ver[[length(ver) + 1]] <<- data.frame(table = tab, check = chk, n = n, n_failing = nf, note = note)
addc <- function(tab, cell, tl, fin, why) corr[[length(corr) + 1]] <<- data.frame(table = tab, cell = cell, text_layer_value = tl, final_value = fin, reason = why)

# ---- Tabla 3.3 (p.31) ------------------------------------------------------
d <- pd[[31]]; d <- d[d$y > 310 & d$y < 560, ]
ages <- c("Total","0","1-4","5-9","10-14","15-19","20-24","25-29","30-34","35-39","40-44",
          "45-49","50-54","55-59","60-64","65-69","70-74","75-79","80-84","85 y +")
fy <- sort(unique(d$y[grepl("^1,\\d{3}$", d$text)]))
stopifnot(length(fy) == 20)
getcol <- function(x0) sapply(fy, function(y) {
  z <- d[abs(d$y - y) < 3 & abs(d$x - x0) < 6 & grepl("^1,\\d{3}$", d$text), ]
  stopifnot(nrow(z) == 1); num(z$text) })
t33 <- rbind(data.frame(edad = ages, sexo = "ambos",   factor = getcol(181)),
             data.frame(edad = ages, sexo = "hombres", factor = getcol(244)),
             data.frame(edad = ages, sexo = "mujeres", factor = getcol(307)))
write.csv(t33, file.path(out, paste0(pre, "cuadro3_03_factor_ajuste_defunciones.csv")), row.names = FALSE, fileEncoding = "UTF-8")
f <- t33[t33$sexo == "mujeres", ]
for (i in seq_len(nrow(f))) addc("3.3", paste0("mujeres/", f$edad[i]), "intercalado sobre otras filas", sprintf("%.3f", f$factor[i]),
  "pdftotext -layout desordena la columna Mujeres; valor por coordenadas y confirmado en imagen p.31")
addv("3.3", "20 grupos x 3 sexos completos", 60, sum(is.na(t33$factor)))
addv("3.3", "factores entre 1.0 y 1.5", 60, sum(t33$factor < 1 | t33$factor > 1.5))
w <- reshape(t33, idvar = "edad", timevar = "sexo", direction = "wide")
addv("3.3", "ambos entre hombres y mujeres (tol 0.002)", 20,
     sum(w$factor.ambos < pmin(w$factor.hombres, w$factor.mujeres) - 0.0021 | w$factor.ambos > pmax(w$factor.hombres, w$factor.mujeres) + 0.0021))

# ---- Tabla 3.13 (p.45) -----------------------------------------------------
tx <- strsplit(pdftools::pdf_text(pdf)[45], "\n")[[1]]
src <- c("1"="Censo 1973","2"="WFS 1976","3"="ENH 1978","4"="Censo 1985","5"="ENDS 90","6"="Censo 1993",
         "7"="ENDS 95","8"="ENDS 95 Historia de Embarazos","9"="ENH 80","10"="ENH 81")
rx <- "(\\d{4}[.,]\\d)\\s+(\\d+)/\\s+(\\d+,\\d)"
rows <- list()
for (l in tx) {
  m <- gregexpr(rx, l, perl = TRUE)[[1]]
  if (m[1] > 0) for (s in regmatches(l, list(m))[[1]]) {
    g <- regmatches(s, regexec(rx, s))[[1]]
    rows[[length(rows) + 1]] <- data.frame(anio = num(g[2]), tasa_por_mil = num(g[4]),
                                           fuente_codigo = as.integer(g[3]), raw_anio = g[2]) } }
t313 <- do.call(rbind, rows)
t313$fuente <- src[as.character(t313$fuente_codigo)]
t313 <- t313[order(t313$anio, t313$fuente_codigo), ]
nd <- t313[grepl(".", t313$raw_anio, fixed = TRUE), ]
for (i in seq_len(nrow(nd))) addc("3.13", paste0("anio/", nd$raw_anio[i], " fuente", nd$fuente_codigo[i]), nd$raw_anio[i], sprintf("%.1f", nd$anio[i]),
  "separador decimal punto en el OCR (mezclado con coma); normalizado a punto")
t313$raw_anio <- NULL
write.csv(t313, file.path(out, paste0(pre, "cuadro3_13_mortalidad_infantil_fuentes.csv")), row.names = FALSE, fileEncoding = "UTF-8")
addv("3.13", "n observaciones = 40 (20 filas x 2 bloques)", nrow(t313), as.integer(nrow(t313) != 40))
addv("3.13", "codigos de fuente 1-10 presentes", length(unique(t313$fuente_codigo)), as.integer(length(unique(t313$fuente_codigo)) != 10))
addv("3.13", "anio 1962-1992.1 y tasa 20-90", nrow(t313), sum(t313$anio < 1962 | t313$anio > 1992.1 | t313$tasa_por_mil < 20 | t313$tasa_por_mil > 90))
addv("3.13", "texto vs imagen p.45 (revision visual fila a fila)", 40, 0)

# ---- Tabla 3.14 (p.46) -----------------------------------------------------
d <- pd[[46]]; d <- d[d$y > 355 & d$y < 430, ]
yy <- d[d$x < 120 & grepl("^(19|20)\\d\\d$", d$text), ]
cl <- function(x0, y) { z <- d$text[abs(d$x - x0) < 8 & abs(d$y - y) < 3]; if (length(z)) num(z) else NA_real_ }
t314 <- data.frame(censo = as.integer(yy$text),
  e0_hombres = sapply(yy$y, cl, x0 = 143), ganancia_media_anual_hombres = sapply(yy$y, cl, x0 = 204),
  e0_mujeres = sapply(yy$y, cl, x0 = 256), ganancia_media_anual_mujeres = sapply(yy$y, cl, x0 = 324),
  diferencial_sexo = sapply(yy$y, cl, x0 = 397))
t314 <- t314[order(t314$censo), ]
write.csv(t314, file.path(out, paste0(pre, "cuadro3_14_e0_censos.csv")), row.names = FALSE, fileEncoding = "UTF-8")
tl <- c("3.45","4.15","6.35","8.33","6.91","(vacio)")
for (i in 1:6) addc("3.14", paste0("diferencial_sexo/", t314$censo[i]), tl[i], sprintf("%.2f", t314$diferencial_sexo[i]),
  "columna Diferencial desplazada una fila en la capa de texto en flujo; confirmado en imagen p.46")
dd <- round(t314$e0_mujeres - t314$e0_hombres, 2)
addv("3.14", "diferencial = e0 mujeres - e0 hombres (tol 0.011)", 6, sum(abs(dd - t314$diferencial_sexo) > 0.011),
     paste0("FUENTE INCONSISTENTE: 1985 impreso ", t314$diferencial_sexo[4], " vs calculado ", dd[4], "; imagen coincide con texto, no se corrige"))
gh <- round(diff(t314$e0_hombres) / diff(t314$censo), 2); gm <- round(diff(t314$e0_mujeres) / diff(t314$censo), 2)
addv("3.14", "ganancia anual hombres = delta e0 / delta anos (tol 0.011)", 5, sum(abs(gh - t314$ganancia_media_anual_hombres[-1]) > 0.011))
addv("3.14", "ganancia anual mujeres = delta e0 / delta anos (tol 0.011)", 5, sum(abs(gm - t314$ganancia_media_anual_mujeres[-1]) > 0.011))
addv("3.14", "6 censos 1951-2005 y e0 mujeres > hombres", 6, sum(nrow(t314) != 6) + sum(t314$e0_mujeres <= t314$e0_hombres))

# ---- Anexo 2 (p.160-165) ---------------------------------------------------
units <- data.frame(unidad = c("Colombia","Antioquia","Atlántico","Bogotá","Bolívar","Boyacá","Caldas","Cauca","Cesar","Chocó","Córdoba",
  "Cundinamarca","Huila","Magdalena","La Guajira","Meta","Nariño","Norte de Santander","Quindío","Risaralda","San Andrés","Santander",
  "Sucre","Tolima","Valle del Cauca","Caquetá","Putumayo","Arauca","Casanare","Grupo Amazonia"),
  codigo = c("00","05","08","11","13","15","17","19","20","27","23","25","41","47","44","50","52","54","63","66","88","68","70","73","76","18","86","81","85","GA"),
  stringsAsFactors = FALSE)
colx <- c(mi_hombres = 210, mi_mujeres = 269, mi_total = 309, e0_hombres = 376, e0_mujeres = 435, e0_total = 475)
qq <- c("1985-1990","1990-1995","1995-2000","2000-2005")
res <- list()
for (p in 160:165) {
  d <- pd[[p]]; q <- d[d$text == "Quinquenio", ]; q <- q[order(q$y), ]
  for (i in seq_len(nrow(q))) {
    tt <- d[d$y > q$y[i] - 26 & d$y < q$y[i] - 5 & d$x > 150, ]; tt <- tt[order(tt$x), ]
    nm <- paste(tt$text, collapse = " ")
    ylim <- if (i < nrow(q)) q$y[i + 1] - 26 else Inf
    b <- d[d$y > q$y[i] + 12 & d$y < ylim & grepl("^\\d+\\.\\d\\d$", d$text), ]
    r <- data.frame(unidad = nm, quinquenio = qq)
    for (k in names(colx)) {
      z <- b[abs(b$x - colx[k]) < 22, ]; z <- z[order(z$y), ]
      r[[k]] <- if (nrow(z) == 4) num(z$text) else rep(NA_real_, 4)
      if (nrow(z) != 4) addv("Anexo 2", paste("4 valores en", nm, k), nrow(z), 1) }
    r$pagina <- p; res[[length(res) + 1]] <- r } }
a2 <- do.call(rbind, res)
a2$unidad_codigo <- units$codigo[match(a2$unidad, units$unidad)]
a2 <- a2[, c("unidad_codigo","unidad","quinquenio","mi_hombres","mi_mujeres","mi_total","e0_hombres","e0_mujeres","e0_total","pagina")]
write.csv(a2, file.path(out, paste0(pre, "anexo2_e0_infantil_quinquenios.csv")), row.names = FALSE, fileEncoding = "UTF-8", na = "")
nu <- length(unique(a2$unidad))
addv("Anexo 2", "unidades = Colombia + 28 unidades + Grupo Amazonia (30)", nu, as.integer(nu != 30))
addv("Anexo 2", "nombres con codigo asignado", nu, sum(is.na(a2$unidad_codigo[!duplicated(a2$unidad)])))
addv("Anexo 2", "4 quinquenios x 6 valores sin vacios", nrow(a2) * 6, sum(is.na(a2[, 4:9])), paste("filas:", nrow(a2), "(esperado 120)"))
btw <- function(t, a, b) t < pmin(a, b) - 1e-9 | t > pmax(a, b) + 1e-9
fe <- btw(a2$e0_total, a2$e0_hombres, a2$e0_mujeres); fm <- btw(a2$mi_total, a2$mi_hombres, a2$mi_mujeres)
addv("Anexo 2", "e0 total entre hombres y mujeres", nrow(a2), sum(fe, na.rm = TRUE), paste(unique(paste(a2$unidad, a2$quinquenio)[which(fe)]), collapse = "; "))
addv("Anexo 2", "mortalidad infantil total entre hombres y mujeres", nrow(a2), sum(fm, na.rm = TRUE), paste(unique(paste(a2$unidad, a2$quinquenio)[which(fm)]), collapse = "; "))
addv("Anexo 2", "mi hombres > mi mujeres y e0 mujeres > e0 hombres", nrow(a2), sum(a2$mi_hombres <= a2$mi_mujeres | a2$e0_mujeres <= a2$e0_hombres, na.rm = TRUE))
addv("Anexo 2", "rangos plausibles (mi 10-120, e0 50-85)", nrow(a2), sum(a2$mi_total < 10 | a2$mi_total > 120 | a2$e0_total < 50 | a2$e0_total > 85, na.rm = TRUE))
dn <- do.call(rbind, lapply(split(a2, a2$unidad), function(z) data.frame(u = z$unidad[1], dn = min(diff(z$e0_total)))))
addv("Anexo 2", "e0 total no decrece entre quinquenios (consistencia interna de la fuente)", nrow(dn), sum(dn$dn < 0), paste(dn$u[dn$dn < 0], collapse = "; "))
addc("Anexo 2", "todas las celdas", "numeros en orden de lectura desordenado", "ver CSV",
     "la capa de texto en flujo mezcla filas y columnas; se leyo por coordenadas (x,y) y se verifico contra imagenes p.160-165; ningun digito corregido")

write.csv(do.call(rbind, ver),  file.path(sup, "small_tables_verification.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(do.call(rbind, corr), file.path(sup, "small_tables_corrections.csv"),  row.names = FALSE, fileEncoding = "UTF-8")
cat("OK:", nrow(t33), nrow(t313), nrow(t314), nrow(a2), "\n")
