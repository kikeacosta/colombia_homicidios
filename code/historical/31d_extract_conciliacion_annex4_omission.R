# 31d_extract_conciliacion_annex4_omission.R
# Anexo 4 "Metodos explorados para la estimacion de la omision de las defunciones" de
#   DANE, Conciliacion censal 1985-2005. Colombia. Estimacion de la mortalidad 1985-2005 (mayo de 2007),
#   data_input/dane_pdfs/censos/5Mortalidad85_05.pdf, paginas 288 a 299.
# El anexo es texto y tablas de hallazgos en rangos, sin series numericas: se transcribe a mano
# (cada valor leido del texto del PDF y las tablas 6 y 7 comprobadas en la imagen de la pagina 296)
# y el script comprueba la coherencia (min <= max, omision y cobertura consistentes).
# Produce, en data_input/historical/:
#   dane_conciliacion_1985_2005_anexo4_metodos_omision.csv      (5 metodos: supuestos, decision y motivo)
#   dane_conciliacion_1985_2005_anexo4_resultados_omision.csv   (tablas 1 a 12: hallazgos por alternativa)
# y la verificacion en dane_conciliacion_1985_2005_support/anexo4_verification.csv.
# Ejecutar desde la raiz del proyecto: Rscript code/historical/31d_extract_conciliacion_annex4_omission.R
# Fecha de la extraccion: 2026-11-12.

out <- "data_input/historical"
sup <- file.path(out, "dane_conciliacion_1985_2005_support")
dir.create(sup, showWarnings = FALSE, recursive = TRUE)

metodos <- data.frame(
  metodo = c("Brass", "Preston y Coale", "Ecuación de equilibrio de Brass",
             "General de equilibrio de crecimiento", "Bennet-Hoiruchi"),
  orden = letters[1:5],
  referencia = c("Primante y García, XX Curso Regional Intensivo de Análisis Demográfico 1997, vol. 4, p. 117",
                 "Naciones Unidas, Estudios de Población n.º 81, Manual X, 1986, p. 139",
                 "Naciones Unidas, Manual X, 1986, p. 149",
                 "Hill, Stanton y Gupta, MEASURE Evaluation Manual Series n.º 4, 2001",
                 "Pujol, Notas de Población n.º 39, CELADE, 1985, p. 57"),
  poblacion_de_edad_desde = c("5 años", "toda la población", "x años y más", "segmentos abiertos de edad", "grupos de edad"),
  supuestos = c("población cerrada y estable; dos variantes",
                "población cerrada y estable; tasa de crecimiento r por grupo de edad; tablas modelo para el intervalo abierto",
                "población cerrada y estable; misma cobertura de defunciones por encima de 5 o 10 años; edades bien declaradas",
                "población cerrada a la migración, no necesariamente estable; dos recuentos de población y defunciones del período",
                "sin migración internacional; esperanza de vida a los 60 años de tablas anteriores; mismo patrón de omisión censal por edad en ambos censos"),
  decision = c("no usado", "usado para corregir 2004 y 2005 (sección 3.1.1)", "no usado", "no usado", "no usado"),
  motivo = c("la población colombiana no es cerrada ni estable; las tasas parciales no se ajustan a una recta y daría tasas de mortalidad demasiado altas",
             "más resistente que Brass a desviaciones de la estabilidad; se aplicó a las defunciones de 2005 con la población del censo de 2005 por grupos de edad",
             "arroja sobreregistro de defunciones, que no se espera en el país",
             "arroja sobreregistro de defunciones, que no se espera en el país",
             "arroja sobreregistro de defunciones, que no se espera en el país"),
  pagina = c("288", "289-290", "290", "290-291", "292"),
  stringsAsFactors = FALSE)

r <- function(tabla, metodo, alternativa, insumos, defunciones, sexo = "ambos",
              om = c(NA, NA), cr = c(NA, NA), cob = c(NA, NA), pagina) {
  data.frame(tabla = tabla, metodo = metodo, alternativa = alternativa, insumos = insumos,
             defunciones_evaluadas = defunciones, sexo = sexo,
             omision_min_pct = om[1], omision_max_pct = om[2],
             crecimiento_min_pct = cr[1], crecimiento_max_pct = cr[2],
             cobertura_min = cob[1], cobertura_max = cob[2], pagina = pagina,
             stringsAsFactors = FALSE)
}
B <- "Brass"
ev05 <- "Estadísticas Vitales 2005, por grupos de edad"
ev0105 <- "Estadísticas Vitales, promedio 2001-2005, por grupos de edad"
ev05a <- "Estadísticas Vitales 2005 ajustadas con la pregunta de defunciones del censo (% de no certificación)"
ev0105a <- "Estadísticas Vitales, promedio 2001-2005, ajustadas con la pregunta de defunciones del censo (% de no certificación)"
c05 <- "Defunciones del censo 2005"
c05c <- "Defunciones del censo 2005 con certificado"
res <- rbind(
  r(1, B, "primera: población censada 2005", "población censada 2005", ev05, om = c(16.7, 47), cr = c(1.78, 2.42), pagina = "293"),
  r(1, B, "primera: población censada 2005", "población censada 2005", ev0105, om = c(22.7, 50.5), cr = c(1.69, 2.32), pagina = "293"),
  r(1, B, "primera: población censada 2005", "población censada 2005", ev05a, om = c(11.3, 43.6), cr = c(1.28, 1.77), pagina = "293"),
  r(1, B, "primera: población censada 2005", "población censada 2005", ev0105a, om = c(17.8, 47.4), cr = c(1.68, 2.32), pagina = "293"),
  r(1, B, "primera: población censada 2005", "población censada 2005", c05, om = c(28.3, 54.3), cr = c(1.67, 2.24), pagina = "293"),
  r(1, B, "primera: población censada 2005", "población censada 2005", c05c, om = c(32.9, 57.2), cr = c(1.69, 2.25), pagina = "293"),
  r(2, B, "segunda: población 2005 compensada", "población 2005 compensada", ev05, om = c(17.9, 47.8), cr = c(1.78, 2.42), pagina = "294"),
  r(2, B, "segunda: población 2005 compensada", "población 2005 compensada", ev0105, om = c(23.9, 51.2), cr = c(1.69, 2.32), pagina = "294"),
  r(2, B, "segunda: población 2005 compensada", "población 2005 compensada", ev05a, om = c(12.6, 44.5), cr = c(1.77, 2.34), pagina = "294"),
  r(2, B, "segunda: población 2005 compensada", "población 2005 compensada", ev0105a, om = c(19.0, 48.1), cr = c(1.68, 2.32), pagina = "294"),
  r(2, B, "segunda: población 2005 compensada", "población 2005 compensada", c05, om = c(29.4, 55.0), cr = c(1.68, 2.24), pagina = "294"),
  r(2, B, "segunda: población 2005 compensada", "población 2005 compensada", c05c, om = c(33.9, 57.8), cr = c(1.69, 2.25), pagina = "294"),
  r(3, B, "tercera: población censada 2005 ajustada por la estructura de edad del censo 1993", "población 2005 ajustada con la estructura de 1993", ev05, om = c(2.4, 31.9), cr = c(2.83, 3.24), pagina = "294-295"),
  r(3, B, "tercera: población censada 2005 ajustada por la estructura de edad del censo 1993", "población 2005 ajustada con la estructura de 1993", ev0105, om = c(4.8, 30.3), cr = c(2.88, 3.24), pagina = "294-295"),
  r(4, B, "cuarta: población del censo 1993 sin ajuste", "población censada 1993", "Estadísticas Vitales 1991-1995, por grupos de edad", om = c(2.64, 3.00), cr = c(0.5, 32.6), pagina = "295"),
  r(4, B, "cuarta: población del censo 1993 sin ajuste", "población censada 1993", "Estadísticas Vitales 1993, por grupos de edad", om = c(2.65, 3.01), cr = c(10.2, 39.4), pagina = "295"),
  r(5, B, "cuarta: población del censo 1993 ajustada", "población censada 1993 ajustada", "Estadísticas Vitales 1991-1995, por grupos de edad", om = c(2.58, 3.15), cr = c(6.2, 28.6), pagina = "295"),
  r(6, "Preston y Coale", "población censada 2005", "censos 1951, 1964, 1973, 1985, 1993 y 2005; r por grupos de edad; tablas modelo", "Estadísticas Vitales 2005", cob = c(0.750, 0.842), pagina = "296"),
  r(6, "Preston y Coale", "población censada 2005", "censos 1951, 1964, 1973, 1985, 1993 y 2005; r por grupos de edad; tablas modelo", "Estadísticas Vitales, promedio 2001-2005", cob = c(0.703, 0.795), pagina = "296"),
  r(6, "Preston y Coale", "población censada 2005", "censos 1951, 1964, 1973, 1985, 1993 y 2005; r por grupos de edad; tablas modelo", "Estadísticas Vitales 2005 ajustadas con la pregunta del censo (no tuvo certificado)", cob = c(0.798, 0.969), pagina = "296"),
  r(6, "Preston y Coale", "población censada 2005", "censos 1951, 1964, 1973, 1985, 1993 y 2005; r por grupos de edad; tablas modelo", "Estadísticas Vitales, promedio 2001-2005, ajustadas con la pregunta del censo (no tuvo certificado)", cob = c(0.748, 0.922), pagina = "296"),
  r(7, "Ecuación de equilibrio de Brass", "única", "censos 1993 y 2005 sin ajuste; Estadísticas Vitales 1993 y 2005; por sexo y grupos quinquenales", "Estadísticas Vitales 1993 y 2005", "hombres", cob = c(1.1906, 1.1906), pagina = "296"),
  r(7, "Ecuación de equilibrio de Brass", "única", "censos 1993 y 2005 sin ajuste; Estadísticas Vitales 1993 y 2005; por sexo y grupos quinquenales", "Estadísticas Vitales 1993 y 2005", "mujeres", cob = c(1.2553, 1.2553), pagina = "296"),
  r(7, "Ecuación de equilibrio de Brass", "única", "censos 1993 y 2005 sin ajuste; Estadísticas Vitales 1993 y 2005; por sexo y grupos quinquenales", "Estadísticas Vitales 1993 y 2005", "ambos", cob = c(1.224, 1.224), pagina = "296"),
  r(8, "General de equilibrio de crecimiento", "primera: población censada frente a Estadísticas Vitales", "censos 1993 y 2005", "Estadísticas Vitales 2005", "ambos", cob = c(1.2241, 1.2241), pagina = "297"),
  r(8, "General de equilibrio de crecimiento", "primera: población censada frente a Estadísticas Vitales", "censos 1993 y 2005", "Estadísticas Vitales 2005", "hombres", cob = c(1.1906, 1.1906), pagina = "297"),
  r(8, "General de equilibrio de crecimiento", "primera: población censada frente a Estadísticas Vitales", "censos 1993 y 2005", "Estadísticas Vitales 2005", "mujeres", cob = c(1.2553, 1.2553), pagina = "297"),
  r(9, "General de equilibrio de crecimiento", "segunda: población censada 2005 frente a defunciones de los últimos doce meses del censo", "censos 1993 y 2005", "Defunciones de los últimos doce meses del censo 2005", "ambos", cob = c(1.163, 1.163), pagina = "297"),
  r(9, "General de equilibrio de crecimiento", "segunda: población censada 2005 frente a defunciones de los últimos doce meses del censo", "censos 1993 y 2005", "Defunciones de los últimos doce meses del censo 2005", "hombres", cob = c(1.1211, 1.1211), pagina = "297"),
  r(9, "General de equilibrio de crecimiento", "segunda: población censada 2005 frente a defunciones de los últimos doce meses del censo", "censos 1993 y 2005", "Defunciones de los últimos doce meses del censo 2005", "mujeres", cob = c(1.145, 1.145), pagina = "297"),
  r(10, "General de equilibrio de crecimiento", "tercera: población censada 2005 frente a defunciones con certificado de la pregunta del censo", "censos 1993 y 2005", "Defunciones de los últimos doce meses del censo 2005 con certificado", "ambos", cob = c(1.088, 1.088), pagina = "298"),
  r(10, "General de equilibrio de crecimiento", "tercera: población censada 2005 frente a defunciones con certificado de la pregunta del censo", "censos 1993 y 2005", "Defunciones de los últimos doce meses del censo 2005 con certificado", "hombres", cob = c(1.046, 1.046), pagina = "298"),
  r(10, "General de equilibrio de crecimiento", "tercera: población censada 2005 frente a defunciones con certificado de la pregunta del censo", "censos 1993 y 2005", "Defunciones de los últimos doce meses del censo 2005 con certificado", "mujeres", cob = c(1.132, 1.132), pagina = "298"),
  r(11, "General de equilibrio de crecimiento", "cuarta: población 2005 ajustada frente a Estadísticas Vitales ajustadas por % de no certificación", "censo 1993; censo 2005 ajustado", "Estadísticas Vitales 2005 ajustadas por % de no certificación de la pregunta censal", "ambos", cob = c(1.544, 1.544), pagina = "298"),
  r(11, "General de equilibrio de crecimiento", "cuarta: población 2005 ajustada frente a Estadísticas Vitales ajustadas por % de no certificación", "censo 1993; censo 2005 ajustado", "Estadísticas Vitales 2001-2005 ajustadas por % de no certificación de la pregunta censal", "ambos", cob = c(1.443, 1.443), pagina = "298"),
  r(12, "Bennet-Hoiruchi", "única: población 2005 censada", "censos 1993 y 2005 censados; Estadísticas Vitales 2005 por sexo y grupos de edad", "Estadísticas Vitales 2005, por grupos de edad", "hombres", cob = c(1.050, 1.228), pagina = "299"),
  r(12, "Bennet-Hoiruchi", "única: población 2005 censada", "censos 1993 y 2005 censados; Estadísticas Vitales 2005 por sexo y grupos de edad", "Estadísticas Vitales 2005, por grupos de edad", "mujeres", cob = c(1.251, 1.460), pagina = "299"))

# Comprobaciones
chk <- function(nombre, ok, n) data.frame(check = nombre, n = n, n_failing = sum(!ok), stringsAsFactors = FALSE)
v <- rbind(
  chk("minimo <= maximo en omision, crecimiento y cobertura",
      with(res, (is.na(omision_min_pct) | omision_min_pct <= omision_max_pct) &
                (is.na(crecimiento_min_pct) | crecimiento_min_pct <= crecimiento_max_pct) &
                (is.na(cobertura_min) | cobertura_min <= cobertura_max)), nrow(res)),
  chk("cada fila tiene omision o cobertura", !is.na(res$omision_min_pct) | !is.na(res$cobertura_min), nrow(res)),
  chk("12 tablas presentes", 1:12 %in% res$tabla, 12),
  chk("5 metodos, uno por letra a-e", letters[1:5] %in% metodos$orden, 5),
  chk("tablas 8 y 7 coinciden (misma cobertura por sexo)",
      abs(res$cobertura_min[res$tabla == 7] - res$cobertura_min[res$tabla == 8][c(2, 3, 1)]) < 0.001, 3))

write.csv(metodos, file.path(out, "dane_conciliacion_1985_2005_anexo4_metodos_omision.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
write.csv(res, file.path(out, "dane_conciliacion_1985_2005_anexo4_resultados_omision.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
write.csv(v, file.path(sup, "anexo4_verification.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(v); cat(nrow(metodos), "metodos;", nrow(res), "filas de resultados\n")
