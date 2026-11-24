# Mortalidad registrada en Colombia, 1915-2023 (fase 1)

Defunciones **registradas** (no ajustadas, no imputadas) por causa (todas, homicidio), sexo (total, hombres, mujeres) y
nivel geográfico (nacional, departamental, municipal), sin edad todavía. Generado por `code/60_build_mortality_database.R`
a partir de los archivos ya extraídos del proyecto.

## Archivos

| archivo | contenido |
|---|---|
| `mortalidad_colombia.csv.gz` | una fuente por celda (la mejor, según la prioridad de abajo) |
| `mortalidad_colombia_fuentes.csv.gz` | todas las fuentes sin armonizar, mismas columnas más `elegida` (TRUE = la fila pasó a la tabla 1) |
| `poblacion_colombia.csv.gz` | denominadores: proyecciones y retroproyecciones DANE, y totales censales |
| `unidades_colombia.csv` | cada nombre de unidad encontrado en cada fuente, su cod y la convención territorial |
| `verification.csv`, `verificacion_nacional_vs_departamentos.csv`, `verificacion_cobertura_inventario.csv` | controles |

## Columnas de `mortalidad_colombia.csv.gz` y `_fuentes`

| columna | definición |
|---|---|
| nivel | `nacional`, `departamental`, `municipal` |
| cod | DIVIPOLA: `00` nacional, 2 dígitos departamento, 5 dígitos municipio. `TN` = intendencias y comisarías agrupadas; `TN_I` / `TN_C` = solo intendencias / solo comisarías (así publicadas en 1938-39 en los homicidios de col_gap). Vacío (NA) solo para jurisdicciones de Policía que no son un departamento y para municipios de col_gap sin emparejamiento único; `unidad` siempre está llena |
| unidad | nombre de la unidad (departamentos y municipios con el nombre actual de DIVIPOLA) |
| anio | año de registro (EEVV: año de registro; las demás fuentes, el año que publican) |
| causa | `todas` = todas las causas; `homicidio` (definición abajo) |
| sexo | `total`, `hombres`, `mujeres` |
| edad | `total` en esta fase |
| def_registradas | defunciones registradas tal como las publica la fuente |
| fuente_id | clave en `documents/inventory/fuentes.csv` |
| archivo | archivo de origen, relativo a la raíz del proyecto |
| calidad | `observada`; `imputada_por_la_fuente` (la transcripción marca cifras copiadas del año anterior, estimadas o completadas por la fuente); `corregida` no se usa en esta fase |
| cobertura | `completa` o `parcial`: la fuente marca subregistro (cuadro 2 del Registro 1970-1978: `*`, `**`; notas DANE de col_gap), cubre solo parte de las unidades, el año es corto (EEVV 1979), el concepto difiere, o la fila de sexo no suma el total de su fuente |
| nota | avisos: marcas de la fuente, límites territoriales históricos, sexo no registrado, etc. |
| elegida | (solo en `_fuentes`) TRUE si la fila está en la tabla 1 |

## Prioridad de fuentes

Por (nivel, unidad, año, causa) se elige **una** fuente para todo el grupo total/hombres/mujeres, en este orden:
1. EEVV microdatos 1979-2023 (`dane_eevv`). El año 1979 (año corto: 110 400 defunciones frente a 135 925 del Registro) se degrada por debajo de cualquier otra fuente, salvo en homicidio departamental (la única alternativa es la Policía, parcial).
2. Registro de defunciones 1970-1978: cuadro 2 (por sección y sexo, 1970-1984) y cuadro 1 (total nacional 1915-1984).
3. Estadística vital 1958-1960 (cuadros departamental y municipal) y anuarios 1965-1967 y 1968-1969 (fila `all` = todas las edades).
4. col_gap (transcripciones de los anuarios): defunciones nacionales, departamentales (archivo `_split` cuando la unidad aparece por separado, `_aggregated` para los años con intendencias y comisarías agrupadas), municipales; homicidios departamentales 1923-1965.
5. OMS (totales nacionales por sexo, 1953-2023). 6. LAMBdA (suma de edades, 1926-2015, solo todas las causas). 7. Policía Nacional (homicidios, 1962-2002). 8. Suma nacional de los homicidios departamentales de col_gap (parcial; solo cuando no hay nada mejor).

Reglas: (a) una celda tiene una sola fuente: nunca se combinan fuentes dentro de un grupo; (b) si la ganadora solo trae total y una fuente inferior trae sexos con **exactamente el mismo total**, se usa esa (es la misma cifra publicada; la nota lo dice); (c) si los sexos de una fuente no suman su total se conserva el total y las filas de sexo quedan `parcial` con nota; (d) en años con unidades agrupadas, ver convención territorial.

## Convención territorial

Departamentos de la Constitución de 1991 más Bogotá D.C. Las fuentes que publican las intendencias y comisarías agrupadas (Registro 1970-1978 cuadro 2, anuarios 1965-1967, Estadística vital 1958-1960, col_gap en años agrupados) conservan una unidad `Intendencias y comisarías (agrupadas)` con cod `TN`; no se reparten. Para col_gap se usa el archivo `_split` cuando la unidad existe por separado y el `_aggregated` para los años agrupados, nunca los dos para la misma unidad-año: en un año, las unidades separadas pasan a la tabla 1 solo si su suma coincide con el agregado `TN`; si no coincide, se usa `TN` y las unidades separadas quedan solo en `_fuentes` (`elegida` FALSE). En 1958-1960 las sumas municipales por departamento se usan solo para las unidades que el cuadro departamental publica por separado.
Los límites son los de la época: Caldas incluye Quindío y Risaralda hasta 1966, Bolívar incluye Córdoba y Sucre antes de 1952 y Sucre hasta 1966, Magdalena incluye Cesar (y La Guajira hasta 1963), Cundinamarca incluye Bogotá hasta 1955, etc. Ver `nota` y `unidades_colombia.csv`. No se reconstruyen los límites actuales.

## Definición de las causas

- `todas`: todas las defunciones no fetales registradas por la fuente.
- `homicidio` en las EEVV: código 101 de la Lista 105 Colombia de DANE (agresiones; CIE-9 E960-E969 hasta 1997, CIE-10 X85-Y09 desde 1998), igual que `dx_h` en `code/02_summarise_deaths.R` y `dx_homicide` en `code/11_shared_dataset.R`. No incluye intención indeterminada (102) ni intervención legal (103).
- Homicidio en otras fuentes: el que publica cada una (OMS: agresiones; col_gap 1923-1965: homicidios de los anuarios, con las excepciones de 1943-1945, años en que la fuente es `muertes violentas accidentales`, marcados parcial; Policía: homicidios registrados por la Policía, no del registro civil).
- Las EEVV son por **lugar de ocurrencia** de la defunción; el Registro y los anuarios, por la sección donde se registró; no es residencia.
- Las EEVV incluyen defunciones de sexo no registrado en el total (nota); el subregistro del Caribe antes de 1998 no se corrige.

## Cobertura de la tabla 1 (años presentes por nivel y causa)

| nivel | causa | años | n años | filas | años sin ninguna fila dentro del rango |
|---|---|---|---|---|---|
| nacional | homicidio | 1923-2023 | 91 | 259 | 1925, 1926, 1932, 1933, 1934, 1935, 1937, 1941, 1942, 1950 |
| nacional | todas | 1915-2023 | 109 | 297 | ninguno |
| departamental | homicidio | 1923-2023 | 91 | 6396 | 1925, 1926, 1932, 1933, 1934, 1935, 1937, 1941, 1942, 1950 |
| departamental | todas | 1915-2023 | 109 | 7925 | ninguno |
| municipal | homicidio | 1979-2023 | 45 | 142908 | ninguno |
| municipal | todas | 1924-2023 | 59 | 175914 | 1933, 1934, 1937, 1938, 1939, 1940, 1941, 1942, 1943, 1944, 1945, 1946, 1947, 1948, 1949, 1950, 1951, 1952, 1953, 1954, 1955, 1956, 1957, 1961, 1962, 1963, 1964, 1965, 1966, 1967, 1968, 1969, 1970, 1971, 1972, 1973, 1974, 1975, 1976, 1977, 1978 |

## Fuentes cargadas (tabla `_fuentes`)

| variante | fuente_id | años | filas | filas elegidas |
|---|---|---|---|---|
| ane_6567 | dane_anuarios | 1965-1967 | 198 | 198 |
| ane_6869 | dane_anuarios | 1968-1969 | 192 | 192 |
| eevv | dane_eevv | 1979-2023 | 294960 | 294870 |
| gap_dep | dane_anuarios | 1915-1984 | 4252 | 2357 |
| gap_hom | dane_anuarios | 1923-1965 | 1476 | 1476 |
| gap_homsum | dane_anuarios | 1923-1965 | 91 | 52 |
| gap_mun | dane_anuarios | 1924-1960 | 32949 | 25524 |
| gap_nat | dane_anuarios | 1923-1984 | 180 | 93 |
| lambda | lambda | 1926-2015 | 228 | 12 |
| policia | policia_homicidios | 1962-2002 | 1314 | 486 |
| reg_c1 | dane_registro_def_1970_1978 | 1915-1984 | 70 | 15 |
| reg_c2 | dane_registro_def_1970_1978 | 1970-1984 | 1134 | 750 |
| vit_dep | dane_vitales_1958_1960 | 1958-1960 | 55 | 0 |
| vit_dsum | dane_vitales_1958_1960 | 1958-1960 | 165 | 120 |
| vit_mun | dane_vitales_1958_1960 | 1958-1960 | 7482 | 7482 |
| who_homicidio | who_mdb | 1953-2023 | 195 | 72 |
| who_todas | who_mdb | 1953-2023 | 147 | 0 |

## Población (`poblacion_colombia.csv.gz`)

Columnas: nivel, cod, unidad, anio, sexo (`total`, `hombres`, `mujeres`), poblacion, fuente_id, archivo, tipo (`censo`, `proyeccion`, `retroproyeccion`). Nacional 1950-2070 (suma de edades, área total) y departamental 1985-2050 de las proyecciones DANE; municipal 1985-2023 de `output/deaths_pop_munic_1985_2023.csv.gz` (DANE, retroproyecciones hasta 2017 y proyecciones desde 2018); totales censales (1905, 1912, 1918, 1928, 1938, 1951, 1964, 1973) de las transcripciones col_gap. Las proyecciones son por lugar de residencia.

## Vacíos conocidos

- Antes de 1979 no hay datos municipales salvo 1924-1936 (col_gap, con vacíos) y 1958-1960.
- 1978 no existe en las EEVV; 1979 es un año corto.
- Homicidio departamental 1966-1978 solo en la Policía (jurisdicciones, no departamentos; Antioquia, Cundinamarca y Valle sin su área metropolitana).
- Homicidio nacional 1923-1952 solo como suma de los departamentos de col_gap (parcial); 1943-1945 es otro concepto.
- LAMBdA y OMS se incluyen para comparar; no se verificó si LAMBdA corrige subregistro.
- Subregistro: el Registro 1970-1978 marca `*` y `**` en varios departamentos; el subregistro del Caribe en las EEVV antes de 1998 no está marcado en las fuentes y no se corrige aquí.
- Lo que no reconcilia está en `verification.csv`.

## Cómo reconstruir

Desde la raíz del proyecto: `Rscript code/60_build_mortality_database.R` (usa solo archivos ya extraídos; tarda unos minutos).
