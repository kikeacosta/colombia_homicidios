# Catálogo de fuentes de migración interdepartamental (interna) en los PDF del proyecto

Elaborado el 2026-11-12. Es una **evaluación**: no se escribió ningún script de extracción ni se transcribió ningún cuadro. Cada rango de páginas se verificó leyendo el texto de la hoja con `pdftools::pdf_text` (volcado a una carpeta temporal fuera del repo). Parte del catálogo ya existente, `documents/catalogo_dane_pdfs.md`, que clasificó los boletines y los estudios postcensales como «nula/baja» porque los miró solo por mortalidad; aquí se reevalúan para migración.

## Convenciones

- **Páginas = número de página del PDF** (la 1 es la primera hoja), no el folio impreso. Cuando el folio impreso difiere se indica.
- **Capa de texto**: *limpia* = las cifras salen alineadas y se pueden leer con `pdf_text`/`pdf_data` más identidades de control; *ruidosa* = las cifras están pero con confusiones de dígitos, signos o columnas partidas; *inutilizable* = el cuadro no tiene cifras en el texto (hay que hacer OCR o transcribir).
- **Esfuerzo A/B/C** como en `catalogo_dane_pdfs.md`: **A** = tabla limpia con texto; **B** = texto ruidoso o diseño complejo (re-verificar con totales) o escaneo en que el OCR sí funciona; **C** = escaneo sin texto en que el OCR no funciona (transcripción manual).
- **Migración de toda la vida** = lugar de nacimiento frente a lugar de residencia en el censo (stock). **Migración de período** = lugar de residencia cinco años antes (o diferencia entre stocks intercensales). Ninguna fuente de los PDF trae migración de período *por flujo directo* antes de 2003, salvo lo derivado por DANE en el Boletín 314.
- Unidades: «departamentos» incluye Bogotá D.E. como unidad aparte; las intendencias y comisarías (territorios nacionales) se anotan cuando aparecen.

## Lo que ya está en el proyecto (para no duplicar)

`data_input/historical/census_tables/census1964_birthplace_by_residence.csv`: matriz de 1964 (lugar de nacimiento × lugar de residencia × sexo × 3 grupos de edad: 0-14, 15-59, 60+), 20 unidades, extraída del Cuadro 14 de `LD_771_1964.pdf` (pp. 49-61; el texto de esas hojas no trae cifras, de ahí que se hizo OCR). Es **la única matriz de migración interna por sexo y edad del proyecto**. UN DESA y WPP son solo migración internacional.

---

## 1. Resumen: qué hay y dónde

| # | Fuente (archivo) | Páginas PDF verificadas | Año(s) | Unidades | Qué cruza | Sexo / edad | Capa de texto | Esfuerzo |
|---|---|---|---|---|---|---|---|---|
| 1 | `BOL_314_1977-141` Cuadro 6 | 32-34 | 1973 | 23 deptos + Bogotá y capitales (filas) × lugar de nacimiento (columnas) | **Matriz de toda la vida** residencia × nacimiento | No | ruidosa-limpia | B |
| 2 | `BOL_314_1977-141` Cuadros 7-9 | 36, 37, 38 | 1973 | Departamentos | Inmigrantes, emigrantes, tasas (toda la vida) | No | limpia | A |
| 3 | `BOL_314_1977-141` Cuadros 10-11 | 39 | 1964 y 1973 | 19 unidades (Caldas con Quindío y Risaralda; Bolívar con Sucre; Magdalena con Cesar) | Población nativa y no nativa, inmigrantes y emigrantes por departamento; variación 1964-73 | No | limpia | A |
| 4 | `BOL_314_1977-141` Cuadros 12-13 | 40 | 1951-64, 1964-73 | Ídem | **Saldo neto y «índice migratorio» por período intercensal** | No | limpia | A |
| 5 | `BOL_314_1977-141` Cuadro 14 | 41 | 1973 | 24 unidades (separa Cesar, Quindío, Risaralda, Sucre, La Guajira) | **Saldos netos entre pares de departamentos** (matriz antisimétrica) | No | ruidosa | B |
| 6 | `BOL_314_1977-141` Cuadro 15 | 42 | 1964-73 | 19 unidades | **Migrantes del período 1964-73, origen × destino** (obtenidos por DANE como diferencia de stocks; trae celdas negativas) | No | ruidosa | B |
| 7 | `BOL_314_1977-141` Cuadros 16, 18, 6A, 18A | 43, 44, 35, 45 | 1973 | Regiones (10 subregiones); capitales | Origen × destino regional; capitales por lugar de nacimiento; «opciones» de destino | No | ruidosa | B |
| 8 | `LD_771_1964` Cuadro 14 | 49-61 | 1964 | 20 unidades × 20 | Nacimiento × residencia × sexo × 3 edades | **Sí** | ya extraído | hecho |
| 9 | `LD_771_1964` Cuadro 13 | 45-48 | 1964 | Depto + cabecera/resto | Nacidos en el mismo depto / otros / exterior × sexo | Sexo | p. 45 parcial (47 cifras); pp. 46-48 sin cifras | B (OCR) |
| 10 | `LD_771_1951` Cuadro 15 | 60-63 | 1951 | Deptos e intendencias × departamento de nacimiento | **Matriz de toda la vida 1951** × sexo | Sexo | inutilizable (solo rótulos y una fila) | B/C |
| 11 | `LD_771_1951` Cuadro 17 | 67-75 | 1951 | Departamentos | Nacidos en Colombia / exterior × **grupo de edad** × sexo | Sexo y edad | p. 68: 72 cifras; resto casi sin cifras | B |
| 12 | `LB_771_1973` Cuadro 4A | 326-343 | 1973 | Secciones | Lugar de empadronamiento × lugar de nacimiento | No | inutilizable (basura OCR) | C (y casi redundante con el n.º 1) |
| 13 | `LB_811_1951_V_1` (tomo Huila) Cuadros 14-15 | 70-74 (municipal), 76-77 (depto × edad × sexo) | 1951 | Municipios de Huila; Huila × depto de nacimiento | Lugar de nacimiento × **edad × sexo** para un solo departamento | Sí | limpia-ruidosa (127-266 cifras por página) | A/B |
| 14 | `estudios_postcensales_07` Cuadro 3 | 19 | 2005 | 29 unidades | Inmigrantes, emigrantes y saldo de los **5 años antes** | No | limpia | A |
| 15 | `estudios_postcensales_07` Cuadro 4 | 21 | 1985-2005 (4 quinquenios) | 24 deptos + Arauca, Casanare, Putumayo, San Andrés, Amazonía | **Saldo neto migratorio adoptado por departamento y quinquenio** | No | limpia | A |
| 16 | `estudios_postcensales_07` Cuadro 2 | 16 | 1985-2005 | Nacional | SNM internacional por **sexo y edad quinquenal**, 4 quinquenios | Sí | limpia | A |
| 17 | `estudios_postcensales_07` Cuadros 5-6 | 43 (nacional por sexo y edad), 43-44 (por depto) | 2005-2020 | Nacional / 29 unidades | SNM por quinquenio (nacional por sexo y edad; deptos solo total) | parcial | limpia | A |
| 18 | `estudios_postcensales_07` **Anexo D** | 287-300 | 2005-2020 | **29 unidades** (≈2 por página) | **SNM por departamento × sexo × edad quinquenal × quinquenio** | **Sí** | limpia | A |
| 19 | `BOL_625_2005-448` Cuadros 1-2 | 325, 326 | hasta 2003 | Deptos y 5 regiones | Migración de toda la vida (ECH 2003): inmigrantes, emigrantes, saldo | No | ruidosa | B |
| 20 | `BOL_625_2005-448` Cuadro 6 | 331 | 1998-2003 | Deptos, total/cabecera/resto | Inmigración, emigración y saldo **recientes (5 años)** | No | ruidosa | B |
| 21 | `BOL_625_2005-448` Cuadros 3-5, 7-10 | 328, 329, 330, 332-335 | 1998-2003 | 5 regiones + Bogotá | Flujos intra e interregionales | No | ruidosa | B |
| 22 | `LD_1007_1973_EJ_4` (muestra de avance 1973) | — | 1973 | — | **No trae ningún cuadro de migración** | — | — | — |
| 23 | `LD_773_1971_1974_V_2_EJ_4` (CIMED-ERED) | 144-183 (según catálogo previo; no leído a fondo) | 1971-74 | Muestra en Bolívar y Santander | Migración en áreas de estudio | — | degradada al final | descartar |

Sin migración interna (solo internacional): `BOL_310_1977-137` (pp. 8-40, «éxodo de colombianos 1963-1973», por sexo, edad y país de destino), `BOL_417_1987-244` (pp. ~175-225, migración internacional de colombianos 1978-1985, Cuadro 5 p. 184 «por sexo y región de procedencia» es del exterior), `BOL_308_1977-135` (pp. 25-27, migración internacional como componente de la cobertura censal), `BOL_355_1981-182` (solo dos menciones del saldo migratorio en la metodología, pp. 46-47), `LB_1006_1964` (población municipal 1964 y 1968 sin lugar de nacimiento; el texto no contiene «nacimiento», «migra» ni «residencia»).

---

## 2. Fichas por fuente

### 2.1 `BOL_314_1977-141.pdf` — «La migración interna y el proceso de concentración de la población en los departamentos» (pp. 8-46)

Es **la fuente más rica de migración interdepartamental del proyecto y no estaba catalogada para este fin**. Autor: División de Demografía, DANE, septiembre de 1977. Se apoya en la muestra de avance del censo de 1973, con poblaciones ajustadas por las tasas de cobertura de la encuesta postcensal (p. 8). Texto: pp. 8-26; cuadros: pp. 27-46. Págs. 47-68 son defunciones (ya catalogadas).

- **Qué dice la prosa (pp. 8-9, 14)**: en 1973 el 21 % de los residentes en departamentos nació en otra área (18 % en 1964); el desplazamiento neto interdepartamental anual fue ≈ 79 000 personas en 1951-64 y 113 500 en 1964-73 (+43 %); Bogotá absorbe el 52 % de los inmigrantes del período, el Valle el 12 %. Dato adicional (p. 14): 9 % de las personas vivían un año antes en otro municipio o el extranjero, 3,51 % en otro departamento. **No hay cuadro de residencia un año antes** en el boletín. La p. 8 anuncia que «tiempo de residencia, residencia anterior» saldrán en una publicación posterior (no está en el proyecto).
- **Cuadro 6, pp. 32-34** (continúa en 33 y 34): «Población por lugar de nacimiento, según residencia actual en departamentos y capitales, 1973». Filas = lugar de residencia (departamentos y capitales), columnas = lugar de nacimiento (Bogotá, Antioquia, Atlántico, Bolívar, Boyacá, Caldas…, intendencias, extranjeros). Ejemplo: `TOTAL DEPTOS.  22.066.741  17.403.541  4.663.200  1.610.558  3.181.811 …` (p. 32). Texto: cifras presentes y alineadas, encabezados con letras partidas («n cimiento»); esfuerzo **B** por 3 hojas anchas. **Es la matriz de toda la vida 1973 a nivel departamental, sin sexo ni edad, y sustituye al Cuadro 4A del resumen censal (ficha 2.7).**
- **Cuadros 7, 8, 9, pp. 36, 37, 38**: nativos e inmigrantes por departamento de residencia (7), emigrantes por departamento de origen con destino Bogotá / otras capitales / resto (8), población residente, originaria, inmigrantes, emigrantes y tasas de migración (9). Limpios (**A**). Ejemplo p. 38: `Antioquia  3.133.196  .871.582  261.614  243.523  3.181.811  310.229 - . 66.706 …`.
- **Cuadros 10 y 11, p. 39**: población residente, nativa, no nativa e inmigrante de otros departamentos en **1964 y 1973**, variación 1964-73 y porcentaje del total de inmigrantes del período (10); lo mismo desde el lado de la población originaria: residentes en el propio departamento, emigrantes (11). Ejemplo: `TOTAL 17.096.370 13.974.264 3.122.106 3.018.234 22.066.741 17.403.541 4.663.200 4.070.555 4.970.371 3.429.277 1.541.094 1.052.321 100.00`. **Los 1 052 321 migrantes interdepartamentales de 1964-73 son el total del período.** Unidades agregadas: Bolívar incluye Sucre; Caldas incluye Quindío y Risaralda; Magdalena incluye Cesar (nota al pie). Limpio (**A**).
- **Cuadros 12 y 13, p. 40**: Cuadro 12, índice migratorio y saldo neto (en miles) en 1964, 1973 y en el intervalo 1964-73 por departamento; **Cuadro 13, índices migratorios por períodos: 1951, 1951-64, 1964, 1964-73, 1973**. Es la única serie de saldos netos departamentales para **1951-1964** del proyecto (como índice = saldo / (inmigrantes + emigrantes) × 100, no como número). Limpio (**A**), con columnas pegadas en alguna fila (`- 24 - 29`).
- **Cuadro 14, p. 41**: «Saldos netos migratorios interdepartamentales, 1973»: matriz de 24 × 24 con signo entre pares de departamentos (separa Cesar, Quindío, Risaralda, Sucre y La Guajira). Texto con columnas desplazadas en algunas filas (`Meta … -  7.110 - 20.412`); la antisimetría permite validar cada celda. **B**.
- **Cuadro 15, p. 42**: «Migrantes interdepartamentales del período 1964-1973»: origen (columnas) × destino (filas), total de emigrantes 1 052 321. **Es lo más parecido a una matriz de flujos de período 1964-73**, pero no es una medición directa: aparece como diferencia de matrices de toda la vida (por eso hay celdas negativas, p. ej. `Boyacá  - 580  - 599 - 112 …`, y el total coincide con la columna de los Cuadros 10-11). El texto que leí no explica la derivación; la lectura «diferencia de stocks» es una inferencia mía y hay que comprobarla contra el Cuadro 6 de 1973 y el Cuadro 14 de 1964 ya extraído. Tiene dos bloques de columnas (origen i y j) en la misma página. **B**.
- **Cuadros 16, 18, 6A, 18A, pp. 43, 44, 35, 45**: matriz por 10 subregiones (16), residentes en capitales por lugar de nacimiento (18), primeras cuatro «opciones» de destino por departamento de origen (6A) y por ciudad (18A). Útiles como control, no como insumo.
- **Cuadros 1-5, 20, pp. 27-31 y 46**: población y crecimiento por zona, tamaño de cabeceras, 39 conjuntos urbanos; no son migración.
- **Qué NO tiene**: sexo, edad ni residencia previa en ningún cuadro; solo totales por departamento.

### 2.2 `estudios_postcensales_07.pdf` — Proyecciones nacionales y departamentales 2005-2020 (DANE, 2009)

**Sí publica los supuestos de saldo neto migratorio por departamento, sexo y edad, pero solo para 2005-2020 (Anexo D). Para 1985-2005 publica los saldos por departamento sin edad ni sexo, y la estructura por sexo y edad solo a nivel nacional.** Texto nativo, limpio.

- **Metodología de la migración (pp. 14-21, 38-44)**: la migración interna se aborda desde los flujos de los cuatro censos (1973, 1985, 1993, 2005) con las preguntas de lugar de nacimiento y residencia cinco años antes (pp. 14, 18). Las matrices de migración interdepartamental de cada censo **se construyeron por grupos de edad y sexo (p. 19), pero no se publican**: solo se publican resultados agregados. Los saldos departamentales «adoptados» deben sumar cero entre departamentos y su suma con la migración internacional debe coincidir con el saldo nacional (p. 14, 20); es decir, **el SNM departamental adoptado es la suma de migración interna e internacional**, y su suma nacional es el SNM internacional.
- **Cuadro 1, p. 15**: SNM nacional 1985-2005 (inicial y adoptado: −393 894 → −245 587; −652 851 → −268 264; −876 617 → −703 343; −798 530 → −661 151) y tasa neta por mil.
- **Cuadro 2, p. 16**: SNM nacional por sexo y grupo de edad quinquenal, 4 quinquenios (ejemplo: total 1985-90 `-117.075 -128.512 -245.587`). Limpio, **A**. Es el patrón por sexo y edad de 1985-2005 (nacional).
- **Cuadro 3, p. 19**: «Migración interdepartamental según lugar de residencia cinco años antes, Censo 2005»: 29 unidades con inmigrantes, emigrantes y saldo (nacional: 1 583 919). Ejemplo: `Bogotá D.C.  344.211  285.283  58.928`. **A.** Útil como contraste de 2000-2005, no como serie.
- **Cuadro 4, p. 21**: «Saldos netos migratorios interdepartamentales adoptados en la conciliación censal, 1985-2005»: 29 unidades × 4 quinquenios (1985-90, 1990-95, 1995-2000, 2000-2005). Ejemplo: `Bogotá D.C.  263.931  260.001  117.106  81.258`; el total (−245 587, −268 264, −703 343, −661 151) iguala al Cuadro 1. Nota: «Grupo Amazonía» agrega Amazonas, Guainía, Guaviare, Vaupés y Vichada. Limpio, **A**. (El título dice «interdepartamentales» pero los totales no suman cero, así que son saldos totales.)
- **Cuadros 5-6 y Tabla 11, pp. 40, 43-44**: SNM 2005-2020 nacional (por sexo y edad, p. 43) y por departamento (Cuadro 6, pp. 43-44; Antioquia +38 635, etc.). **A**.
- **Anexo D, pp. 287-300**: «Parámetros de migración utilizados como insumo de las proyecciones», **por departamento, sexo (hombres/mujeres) y 17 grupos de edad (0-4 … 80+), quinquenios 2005-10, 2010-15, 2015-20**. Verificado: el total de Antioquia (18 443 + 20 192 = 38 635) coincide con el Cuadro 6, por lo que es el SNM total (interno + internacional), no solo el internacional. Ejemplo: `Atlántico  Total  -5.915  -8.026 …`. Texto limpio, una a dos unidades por página; unidades como en el Cuadro 4. **A**.
- **Anexos de población (pp. 79-196) y tablas de mortalidad (pp. ~197-286)** traen población y mortalidad por departamento 2005-2020; y cada cuadro de indicadores (A3, A6, …) incluye «Migrantes netos» por quinquenio (p. 76, 80, …).
- **Cuadro 5 y texto de p. 39-42**: criterios y supuestos por departamento (cualitativos).
- **Qué NO tiene**: matrices origen-destino; saldo por departamento y edad para 1985-2005; separación interna / internacional dentro de un departamento; nada anterior a 1985.

### 2.3 `estudios_postcensales_08.pdf`

12 páginas (truncado, como ya dice el catálogo anterior): mortalidad 1985-2020. **Sin migración** (búsqueda de «migra» sin resultados). No sirve para esta evaluación.

### 2.4 `BOL_625_2005-448.pdf` — «Evidencia reciente del comportamiento de la migración interna en Colombia a partir de la ECH» (pp. 323-335, autor Francisco Pérez Torres)

Encuesta Continua de Hogares, primer trimestre de 2003 (residencia 5 años antes: período 1998-2003; lugar de nacimiento: toda la vida). Texto en pp. 323-335, 10 cuadros, **ninguna cifra por sexo ni edad** (la búsqueda de «sexo», «edad», «mujeres», «hombres» en 323-335 no encuentra cuadros por sexo/edad).

- Cuadro 1 (p. 325) y 2 (p. 326): migración de toda la vida por departamento y región de nacimiento: inmigrantes, emigrantes, saldo, porcentajes. Ejemplo: `Total nacional  8 495 565  8 495 565  0`.
- Cuadros 3-4 (pp. 328, 329): migración acumulada intra e interregional por regiones (5: Atlántica, Oriental, Central, Pacífica, Bogotá).
- **Cuadro 6 (p. 331)**: inmigración, emigración y saldo **de 1998-2003** por departamento, total, cabecera y resto. Ejemplo: `Atlántico  08 018  92 272  6 744`.
- Cuadros 5, 7, 8, 9, 10 (pp. 330, 332, 333, 334): flujos entre regiones.
- **Capa de texto ruidosa**: confusiones 9→0 y 8→S («08 018» por «98 018», «•14087», «6 744» frente a «28 072»), y los totales no cuadran entre cuadros (3 001 036 en el Cuadro 6 y 3 681 036 en el Cuadro 8). Requiere validar con totales y con la prosa. **B**.
- Valor: segunda medición independiente de 1998-2003 para contrastar los saldos adoptados por DANE (Cuadro 4 de `estudios_postcensales_07`). **No sustituye** al Anexo D porque no trae edad ni sexo.

### 2.5 `BOL_310_1977-137`, `BOL_417_1987-244`, `BOL_308_1977-135`

Solo **migración internacional** (confirmado leyendo las introducciones y títulos de cuadros):

- `BOL_310` pp. 7-40: «El éxodo de colombianos 1963-1973», emigración legal e ilegal por sexo, edad y país (EE. UU., Venezuela ≈ 85 %). Útil para netear la migración internacional del saldo intercensal 1964-73, no para la interna.
- `BOL_417` pp. 177-225: migración internacional de colombianos 1978-1985 y mercado laboral; el Cuadro 5 (p. 184) es por sexo y región de procedencia pero se refiere a migrantes del exterior (muestra del 10 % del censo de 1985).
- `BOL_308` pp. 25-27: migración internacional 1964-73 (≈ 600 000 emigrantes, estructura por edad de los faltantes del censo); sin migración interna.

### 2.6 `LB_1006_1964.pdf`, `BOL_355_1981-182.pdf`, `BOL_413`, `BOL_469`

- `LB_1006_1964` (37 pp.): población municipal del censo de 1964 y estimada a 1968, sin lugar de nacimiento ni migración. **No sirve.**
- `BOL_355_1981-182`: cobertura del censo de 1973 por departamento y zona (pp. 105-113); menciona el saldo migratorio solo en la metodología (pp. 46-47). Sin cuadros de migración.
- `BOL_413_1987-240`, `BOL_469_1992-296`: sin migración interna (menciones esporádicas en pp. 214-235 y 160-172 son de tendencias o proyecciones nacionales).

### 2.7 Resúmenes censales en `data_input/historical/`

- **Censo de 1938** (`LD_771_1938_V_1`, `LB_800_1938`): **no se encontró ningún cuadro de lugar de nacimiento ni de migración** (las coincidencias con «nacimiento», «nacidos» o «migra» son prosa sobre natalidad e inmigración extranjera; el único cuadro de origen es «Nacionalidad por secciones del país y por sexo», Cuadro 62, p. 144 del folio impreso, que distingue colombianos de extranjeros, no lugar de nacimiento dentro del país). Para 1938 solo hay edad quinquenal por departamento (ya extraída).
- **Censo de 1951, `LD_771_1951` Cuadro 15, pp. 60-63** (folio impreso 64-67): «Población colombiana por departamento de nacimiento y sexo», departamentos e intendencias/comisarías × departamento de nacimiento, hombres y mujeres. **Capa de texto inutilizable**: la p. 60 trae los rótulos de columnas y la fila de totales en departamentos (`TOTAL EN LOS DEPTOS.  …  1.689.215  346.207 …`) y las pp. 61-63 no traen ni una cifra de cuatro dígitos. Esfuerzo **B**: el inventario ya dice que el OCR del Cuadro 10 de 1951 funciona en ese formato; la matriz es de unos 25 × 25 × 2. **Cuadro 17, pp. 67-75** (folio 80 y siguientes): población nacida en Colombia y en el exterior **por grupo de edad y sexo** por departamento (no por departamento de nacimiento; da la proporción de nativos por edad y departamento). Solo la p. 68 trae texto numérico; **B**.
- **Tomo departamental de 1951, `LB_811_1951_V_1` (Huila)**: pp. 70-74 (Cuadro 14: lugar de nacimiento por municipio y sexo, cabecera y resto) y **pp. 76-77 (Cuadro 15: población nacida en el país por departamento de nacimiento, grupo de edad y sexo)**, con texto numérico legible (152 y 127 cifras). **Esto muestra que el censo de 1951 sí publicó lugar de nacimiento × edad × sexo, pero en los 24 tomos departamentales; solo el de Huila está en el proyecto** (`LB_771_1951_V_2` es el censo de edificios/viviendas y no sirve).
- **Censo de 1964, `LD_771_1964`**: **Cuadro 14, pp. 49-61**: nacimiento × residencia × sexo × 3 grupos de edad, ya extraído. **Cuadro 13, pp. 45-48**: nacidos en el mismo departamento / en otros / en el exterior por unidad de residencia, sexo y zona (cabecera/resto); la p. 45 tiene 47 cifras en el texto (`Total en el País  17.484.608  8.614.662  8.869.866  14.241.742 …`) y las pp. 46-48 ninguna; sirve para validar la diagonal del Cuadro 14 y para el desglose cabecera/resto (**B**, OCR). Las pp. 8, 12-13 describen la boleta: **en 1964 se preguntó el tiempo de permanencia en el municipio y el municipio de residencia inmediatamente anterior** (p. 12-13), y se afirma que se cruzó con edad, educación y ocupación, pero **esos cruces no están en el resumen**: solo los Cuadros 16 y 17 (inmigrantes económicamente activos, por ocupación y rama) y 35 (rama por lugar de nacimiento) los usan.
- **Censo de 1973, `LB_771_1973` Cuadro 4A, pp. 326-343** («Población censada por lugar de empadronamiento según lugar de nacimiento»): texto **inutilizable** (p. 326: `CUADRO 4A / POB.UCION CENSADA / POR LUGAR DE MPADRONAHIEHK) / SEGUN LUGAR DE NACIMIENTO`), 18 hojas, y el README de `census_tables` ya descartó el OCR de este volumen (transcripción manual, **C**). La p. 344 empieza el Cuadro 6A. **Casi redundante**: el Cuadro 6 de `BOL_314` (ficha 2.1) da la matriz de 1973 por departamento con texto. El Cuadro 4A sería útil solo si se quisiera el nivel de sección con intendencias y comisarías. Las definiciones (p. 19) confirman que el censo de 1973 investigó **solo lugar de nacimiento y residencia habitual**, no residencia previa.
- **Muestra de avance de 1973, `LD_1007_1973_EJ_4`**: la p. 15 define las variables «lugar de nacimiento» y «residencia habitual», pero **los cuadros por departamento son 1 (edad × sexo × zona), 2 (edades simples), 3 (alfabetismo), 4 (asistencia escolar), 5 (nivel educativo), 6 (actividad)…; no hay ningún cuadro de lugar de nacimiento ni de residencia cinco años antes** (comprobado en las pp. 95-99 y en el índice, pp. 2-3). Ninguna fuente del proyecto da migración de 1973 por sexo y edad.

---

## 3. ¿Qué combinación sirve para cada período intercensal?

Convención: la mejor fuente directa → qué falta → cómo se podría cubrir.

| Período | Fuentes en los PDF | Producto posible | Falta |
|---|---|---|---|
| **1938-1951** | Edad quinquenal por departamento 1938 y 1951 (ya extraída); defunciones departamentales 1915-1984 (ya en el proyecto); **Cuadro 15 de 1951** (stock de toda la vida, pp. 60-63) como contraste. 1938 no tiene lugar de nacimiento. | **Saldo neto por departamento** por residuo cohorte-componente (población 1951 menos supervivientes de 1938 menos nacimientos supervivientes), con el stock de 1951 como control de signo y tamaño. **Sin edad ni sexo medidos**: salen del residuo por cohorte y sexo, con las limitaciones del subregistro. | Matriz de 1938; edad por origen/destino; los 23 tomos departamentales de 1951 (solo Huila). |
| **1951-1964** | **Cuadro 15 de 1951** (pp. 60-63, B) y **Cuadro 14 de 1964** (ya extraído, con sexo y tres grupos de edad); Cuadros 12-13 de `BOL_314` (índice y saldo 1951-64, pp. 40); BOL_314 p. 9 (79 000 anuales). | Saldos por departamento y **por sexo** por diferencia de stocks, calibrados con la serie del Cuadro 13; el residuo cohorte-componente con 1951 y 1964 (edad quinquenal por departamento, ya extraída) da la edad. | Edad × sexo en 1951 por origen y destino; corrección por mortalidad y retorno de los migrantes. |
| **1964-1973** | **`BOL_314` Cuadros 10-12 (saldos netos por departamento) y 14-15 (matriz de pares y de flujos del período)**; matriz 1964 por sexo y 3 edades (ya extraída); Cuadro 6 de 1973; edad quinquenal por departamento 1964 y 1973 muestra de avance (ya extraídas); `BOL_310` y `BOL_308` para la parte internacional. | Saldos netos por departamento y matriz origen-destino de DANE (total). **Sexo y edad**: aplicar el patrón de 1964 (Cuadro 14) y un patrón modelado (Rogers-Castro) escalado al total, o estimar por residuo cohorte-componente usando las dos poblaciones departamentales por edad. | Sexo y edad de 1973 (no están en el proyecto: la muestra de avance no los tabula); residencia anterior y tiempo de residencia (prometidos en BOL_314 p. 8, no incluidos). |
| **1973-1985** | **Nada directo.** Los PDF no traen tablas de migración del censo de 1985. `estudios_postcensales_07` solo trae saldos desde el quinquenio 1985-90. `DANEpop/DCD-…1985-1994.xlsx` (proyecciones municipales por área, sexo y edad 1985-2017) está en el proyecto pero no es una fuente de migración. | Interpolar entre la tasa 1964-73 (Cuadro 12 de BOL_314) y el SNM 1985-90 (Cuadro 4 de EPC07, p. 21), o residuo cohorte-componente entre la muestra de avance de 1973 y el primer año de 1985 de las proyecciones. | Censo de 1985 (población y migración por departamento, sexo y edad), que es **el hueco principal**; el período 1973-85 incluye además la violencia de los ochenta. |
| **1985-2005** | **`estudios_postcensales_07`**: Cuadro 4 (SNM adoptado por departamento y quinquenio, p. 21), Cuadro 2 (estructura nacional por sexo y edad, p. 16), Cuadro 3 (2005, 5 años antes, p. 19), Anexo D como patrón por sexo y edad (pp. 287-300); `BOL_625` Cuadro 6 (ECH 1998-2003, p. 331) como contraste independiente. | **Saldo neto total por departamento y quinquenio (A)**. **Sexo y edad por departamento no se publican**: se puede imputar aplicando a cada total departamental el patrón por sexo y edad del propio departamento de 2005-10 (Anexo D) o el nacional del Cuadro 2 (p. 16), con el supuesto explícito de patrón constante. | Matrices origen-destino de 1985, 1993 y 2005; separación interna/internacional por departamento. |
| **2005-2020** (referencia) | **Anexo D completo**: sexo × edad × departamento × quinquenio. | Directo, sin supuestos adicionales. | Proyecciones de 2009; DANE publicó después otras con base en el censo de 2018 (no están en el proyecto). |

**Respuesta a la pregunta específica**: sí, los estudios postcensales son la ruta más barata para 1985-2020, pero con límites distintos por período:

1. **2005-2020 por departamento × sexo × edad: completo** (Anexo D, pp. 287-300, 29 unidades × 17 edades × 2 sexos × 3 quinquenios, texto limpio).
2. **1985-2005: total por departamento y quinquenio** (Cuadro 4, p. 21) **y estructura por sexo y edad solo nacional** (Cuadro 2, p. 16). DANE construyó las matrices por edad y sexo, pero no las publica en este documento.
3. Los saldos son **netos totales (interno + internacional)**, que es exactamente lo que un cohorte-componente departamental necesita; por construcción suman el saldo internacional nacional. Si el modelo nacional del proyecto usa WPP para la migración internacional (`wpp_net_migration_age_sex`), hay que decidir si se reconcilian los dos totales o si se usa el de DANE para todos los años posteriores a 1985; el de DANE es menor (−245 587 en 1985-90, −703 343 en 1995-2000).

---

## 4. Lo que falta (y de dónde podría salir)

1. **Edad y sexo de los flujos antes de 1985**, salvo la matriz de 1964 de tres grupos de edad. La mejor vía son los microdatos censales (no están en el proyecto; verificar disponibilidad en IPUMS-Internacional o en el catálogo de microdatos de DANE para 1964, 1973, 1985, 1993 y 2005). Las tablas publicadas de los tomos departamentales de 1951 (24 volúmenes, solo está Huila) darían lugar de nacimiento × edad × sexo por departamento de residencia.
2. **Censo de 1985** (migración por departamento): ninguna fuente en los PDF. Cierra 1973-85.
3. **Residencia cinco años antes** de 1973, 1985 y 1993: solo se cita (EPC07 p. 14), pero no está tabulada en ningún PDF. EPC07 Cuadro 3 (p. 19) la trae únicamente para 2005.
4. **Estudio postcensal n.º 2** (DANE, 2000), citado en EPC07 p. 17 como la fuente de los saldos internos hechos con base en el censo de 1993; no está en la carpeta.
5. **Cambios de unidades**: la matriz de BOL_314 (Cuadros 10-13) agrupa Quindío y Risaralda con Caldas, Sucre con Bolívar y Cesar con Magdalena; el Cuadro 14 (p. 41) y EPC07 (p. 21) los separan, salvo Cesar-Magdalena. Antes de 1964 también cambia la división de intendencias y comisarías. Hay que fijar una geografía común antes de combinar períodos.
6. **Mortalidad y retorno de los migrantes** en las diferencias de stocks de toda la vida: los Cuadros 10-15 de BOL_314 no las corrigen.

---

## 5. Recomendación: orden de extracción

Criterio: valor para la reconstrucción departamental desde 1968 o antes, dividido por el esfuerzo.

1. **`estudios_postcensales_07` Anexo D, pp. 287-300, más Cuadros 2, 4 y 6, pp. 16, 21, 43-44 — esfuerzo A, ~17 páginas.** Cubre 1985-2020 completo, con sexo y edad desde 2005 y totales por departamento antes. Sin esto el modelo departamental no tiene migración posterior a 1985.
2. **`BOL_314_1977-141` Cuadros 10-13, pp. 39-40 (A) y Cuadros 6, 14, 15, pp. 32-34, 41, 42 (B)**, ~8 páginas. Es la única cobertura de 1964-1973 y la única serie de 1951-1964 por departamento; la matriz del Cuadro 15 permite saber de dónde viene cada saldo. Comprobar la identidad «suma por filas = saldo del Cuadro 12» y la antisimetría del Cuadro 14.
3. **`LD_771_1951` Cuadro 15, pp. 60-63 (B, OCR)** para cerrar 1951-1964 con la matriz de 1964 ya extraída, y **`LD_771_1964` Cuadro 13, pp. 45-48 (B)** para validar la diagonal. ~7 páginas. Con estas dos matrices por sexo (1951 y 1964) se obtiene el saldo de 1951-64 por diferencia y por sexo.
4. **`BOL_625_2005-448` Cuadros 1, 2, 6, pp. 325, 326, 331 (B)** y **`estudios_postcensales_07` Cuadro 3, p. 19 (A)**: contraste de 1998-2005. Prioridad media-baja: valida el nivel de EPC07 pero no aporta edad ni sexo.
5. **`LB_811_1951_V_1` pp. 76-77 (A/B)**: no es un insumo nacional (solo Huila), pero es el ejemplo para pedir los otros 23 tomos departamentales de 1951 si se quiere edad × sexo en 1951. Solo extraer si se decide conseguirlos.
6. **No extraer**: `LB_771_1973` Cuadro 4A, pp. 326-343 (C, redundante con BOL_314 Cuadro 6); `BOL_310`, `BOL_417`, `BOL_308` (internacionales; usar solo para ajustar el componente internacional de 1964-73 si se necesita); `LB_1006_1964`; `estudios_postcensales_08`; `LD_773` (CIMED-ERED, muestra de dos departamentos).

**Fuentes que conviene conseguir** (fuera de los PDF actuales): tablas de migración del censo de 1985 y 1993, microdatos censales con lugar de nacimiento y residencia previa (1964, 1973, 1985, 1993, 2005) y los tomos departamentales de 1951. Con esos tres, la edad y el sexo dejan de ser un supuesto.

## Dudas abiertas

- La derivación del Cuadro 15 de BOL_314 («migrantes del período 1964-73») no está explicada en el texto que leí (pp. 8-26). Su interpretación como diferencia de matrices de toda la vida es una inferencia que hay que verificar antes de usarlo como flujo.
- No leí en detalle `LD_773_1971_1974_V_2_EJ_4` pp. 144-183; su descripción sale del catálogo anterior.
- Los totales del Cuadro 4 de EPC07 incluyen la migración internacional de cada departamento; no se pudo separar la parte interna con la información publicada.
