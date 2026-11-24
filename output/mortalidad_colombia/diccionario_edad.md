# Mortalidad registrada en Colombia por edad, 1926-2023 (fase 2)

Defunciones **registradas** (no ajustadas, no imputadas, sin repartir los grupos de edad gruesos) por causa (todas, homicidio), sexo (total, hombres, mujeres), grupo de edad y nivel geográfico (nacional, departamental, municipal). Extiende la fase 1 (`diccionario.md`) con edad; mismas convenciones de `cod`, unidades, `calidad`, `cobertura`, causas y orden de prioridad de fuentes. Generado por `code/61_build_mortality_database_age.R` a partir de los archivos ya extraídos del proyecto. No duplica la fase 1: solo contiene filas de edad (la fila de edad `total` está en `mortalidad_colombia.csv.gz`).

## Archivos

| archivo | contenido | filas | tamaño |
|---|---|---|---|
| `mortalidad_colombia_edad.csv.gz` | una fuente por (nivel, cod, año, causa), la mejor según la regla de abajo (nacional, departamental y municipal) | 5 700 504 | 26.88 MB |
| `mortalidad_colombia_edad_fuentes.csv.gz` | todas las fuentes sin armonizar entre sí, mismas columnas más `elegida` (TRUE = la fila pasó a la tabla de edad) | 5 705 664 | 26.97 MB |
| `verification_edad.csv` | controles (check, n, n_failing, note); detalle en `verification_edad_detalle.csv`, `verification_edad_cobertura.csv`, `verification_edad_cobertura_inventario.csv`, `verification_edad_filas_por_decada.csv` | | |

## Columnas

Las de la fase 1 (`nivel`, `cod`, `unidad`, `anio`, `causa`, `sexo`, `def_registradas`, `fuente_id`, `archivo`, `calidad`, `cobertura`, `nota`; `cod` y `unidad` como en `unidades_colombia.csv`) más:

| columna | definición |
|---|---|
| edad | etiqueta del grupo: `0`, `1-4`, `5-9`, ..., `80-84`, `85+`; grupos más gruesos tal como los publica la fuente (p. ej. `40-49`, `70+`, `80+`); `desconocida` = edad no declarada |
| edad_inicio | primera edad cumplida del grupo (0 = menores de 1 año). NA solo en `desconocida` |
| edad_fin | **última edad cumplida incluida** en el grupo (`5-9` -> 5 y 9; `1-4` -> 1 y 4; `0` -> 0 y 0). NA para el grupo abierto (`85+`, `80+`, `70+`) y para `desconocida` |

## Convenciones de edad

- Grupos estándar (19): `0`, `1-4`, `5-9`, `10-14`, ..., `80-84`, `85+`. Es el detalle de las EEVV 1979-2023, el Registro 1970-1978, los anuarios 1965-1969 y la OMS 1953-1977.
- **El grupo `0` es de menores de 1 año.** Las fuentes con detalle de la infancia (menores de 1 día, 1-6 días, 7-29 días, 1-5 meses, 6-11 meses) se suman en `0`; `12-23 meses` + `2-4 años` se suman en `1-4` (Registro 1970-1978 y anuarios 1968-1969). El anuario 1965-1967 publica `menores de 1 año` y `1-4`. La OMS formato 02 publica `0` y `1-4`; el formato 01 (1967, 1968) publica 1, 2, 3 y 4 años por separado y se suman en `1-4`. Cada fila lo documenta en `nota`.
- Las EEVV agrupan 85 y más en `85+` (los microdatos desde 2008 traen 85-89, 90-94, 95-99 y 100+ y se unen en `85+`). LAMBdA publica 85, 90 y 95+ en los años recientes; se unen en `85+`.
- **No se divide ningún grupo grueso.** LAMBdA usa grupos más gruesos en algunos años (ver abajo); se conservan tal como se publican, con su `edad_inicio`/`edad_fin`.
- `desconocida`: 'not stated' de los cuadros DANE, edad vacía de las EEVV (cerca del 1% de las defunciones, sobre todo antes de 1998), 999 de LAMBdA, 'unspecified' de la OMS. Aparece solo si la fuente trae defunciones con edad desconocida (nacional y departamental: en las EEVV solo cuando hay alguna). La suma de todas las edades, incluida `desconocida`, es el total de la fase 1 de la misma fuente.
- Porcentaje nacional de edad desconocida en las EEVV (todas las causas): 1.7% como máximo hasta 1990, 0.45% como máximo desde 2010.

## Regla de selección

Por (nivel, cod, año, causa) se elige **una** fuente para todos los sexos y todas las edades (nunca se mezclan fuentes dentro de un grupo). Orden:
1. el año corto EEVV 1979 se degrada por debajo de cualquier otra fuente con edad, como en la fase 1 (en la práctica no hay otra fuente con edad en 1979, de modo que se usa y queda `cobertura = parcial`);
2. mayor detalle de edad (número de grupos de edad tras armonizar: 5 años sobre grueso);
3. prioridad de la fase 1: EEVV > Registro de defunciones 1970-1978 (cuadro 11, luego cuadro 3, luego cuadro 6) > anuarios 1965-1969 > OMS > LAMBdA.

Los municipios solo tienen una fuente con edad (EEVV). Los departamentos tienen EEVV (1979-2023), Registro (1970-1978), anuarios (1965-1969). Las intendencias y comisarías se conservan agrupadas (`TN`) cuando la fuente las publica así (anuarios 1965-1967 y Registro 1970-1978), como en la fase 1; en 1968-1969 los anuarios las publican por separado.

## Cobertura (años y detalle de edad por nivel, causa y fuente elegida)

| nivel | causa | fuente | años | n años | filas | grupos de edad (mín-máx) |
|---|---|---|---|---|---|---|
| nacional | homicidio | OMS, homicidio (`who_mdb`) | 1953-1969, 1972 | 18 | 1 080 | 19 |
| nacional | homicidio | Registro 1970-1978, cuadro 6 (causa 148) | 1973-1978 |  6 | 360 | 19 |
| nacional | homicidio | EEVV microdatos (`dane_eevv`) | 1979-2023 | 45 | 2 694 | 19 |
| nacional | todas | LAMBdA (`lambda`) | 1926-1928, 1936-1952 | 20 | 957 | 13-19 |
| nacional | todas | OMS, todas las causas (`who_mdb`) | 1953-1964 | 12 | 720 | 19 |
| nacional | todas | Anuarios DANE 1965-1967 (`dane_anuarios`) | 1965-1967 |  3 | 180 | 19 |
| nacional | todas | Anuarios DANE 1968-1969 (`dane_anuarios`) | 1968-1969 |  2 | 120 | 19 |
| nacional | todas | Registro 1970-1978, cuadro 11 (`dane_registro_def_1970_1978`) | 1970-1978 |  9 | 540 | 19 |
| nacional | todas | EEVV microdatos (`dane_eevv`) | 1979-2023 | 45 | 2 700 | 19 |
| departamental | homicidio | EEVV microdatos (`dane_eevv`) | 1979-2023 | 45 | 87 216 | 19 |
| departamental | todas | Anuarios DANE 1965-1967 (`dane_anuarios`) | 1965-1967 |  3 | 3 780 | 19 |
| departamental | todas | Anuarios DANE 1968-1969 (`dane_anuarios`) | 1968-1969 |  2 | 3 720 | 19 |
| departamental | todas | Registro 1970-1978, cuadro 11 (`dane_registro_def_1970_1978`) | 1970-1978 |  9 | 12 960 | 19 |
| departamental | todas | EEVV microdatos (`dane_eevv`) | 1979-2023 | 45 | 87 906 | 19 |
| municipal | homicidio | EEVV microdatos (`dane_eevv`) | 1979-2023 | 45 | 2 735 835 | 19 |
| municipal | todas | EEVV microdatos (`dane_eevv`) | 1979-2023 | 45 | 2 759 736 | 19 |

Detalle de edad de LAMBdA (única fuente nacional de todas las causas antes de 1953): `0 1-4 5-9 10-14 15-19 20-24 25-29 30-34 35-39 40-44 45-49 50-54 55-59 60-64 65-69 70-74 75-79 80+` en 1926-1928; `0 1-4 5-9 10-14 15-19 20-24 25-29 30-34 35-39 40-49 50-59 60-69 70+` en 1936-1946; `0 1-4 5-9 10-14 15-19 20-24 25-29 30-34 35-39 40-44 45-49 50-59 60-69 70-79 80+` en 1947-1949; `0 1-4 5-9 10-14 15-19 20-24 25-29 30-34 35-39 40-44 45-49 50-54 55-59 60-64 65-69 70-74 75-79 80-84 85+` en 1950-1971, 1973-1975, 1982-2015. LAMBdA no tiene datos en 1929-1935, 1972 ni 1976-1981; en 1950-1971, 1973-1975 y 1982-2015 existe pero no se elige porque hay OMS, Registro o EEVV (solo se elige en 1926-1928 y 1936-1952).

Años con edad en el inventario (`output/tables/data_availability_information.csv`, detalle 'Edad y sexo'): todos los años listados tienen filas en la tabla (`verification_edad.csv`, control 6). La tabla tiene dos años que el inventario no lista como 'Edad y sexo': homicidio nacional 1973 y 1978 (Registro cuadro 6).

## Fuentes cargadas (`_fuentes`)

| variante | fuente | años | filas | filas elegidas |
|---|---|---|---|---|
| lambda | LAMBdA (`lambda`) | 1926-1928, 1936-1971, 1973-1975, 1982-2015 | 4 317 | 957 |
| who_hom | OMS, homicidio (`who_mdb`) | 1953-1969, 1972, 1974-1977 | 1 320 | 1 080 |
| who_todas | OMS, todas las causas (`who_mdb`) | 1953-1970, 1972, 1974-1977 | 1 380 | 720 |
| ane_6567 | Anuarios DANE 1965-1967 (`dane_anuarios`) | 1965-1967 | 3 960 | 3 960 |
| ane_6869 | Anuarios DANE 1968-1969 (`dane_anuarios`) | 1968-1969 | 3 840 | 3 840 |
| reg_c11 | Registro 1970-1978, cuadro 11 (`dane_registro_def_1970_1978`) | 1970-1978 | 13 500 | 13 500 |
| reg_c3 | Registro 1970-1978, cuadro 3 | 1970-1978 | 540 | 0 |
| reg_c6 | Registro 1970-1978, cuadro 6 (causa 148) | 1973-1978 | 360 | 360 |
| reg_c6t | Registro 1970-1978, cuadro 6 (fila TOTAL) | 1973-1978 | 360 | 0 |
| eevv | EEVV microdatos (`dane_eevv`) | 1979-2023 | 5 676 087 | 5 676 087 |

## Definición de homicidio por fuente

- EEVV 1979-2023: código 101 de la Lista 105 de DANE (agresiones; CIE-9 E960-E969, CIE-10 X85-Y09); no incluye intención indeterminada ni intervención legal. Igual que la fase 1.
- Registro 1970-1978, cuadro 6 (1973-1978): categoría 148 de la CIE-8 lista A, 'homicidio y lesiones provocadas intencionalmente por otras personas; intervención legal'. **Incluye intervención legal** (no coincide con el código 101).
- OMS 1968-1977: CIE-8 lista A categoría 148 (la misma definición del Registro; en los años comunes 1974-1977 las cifras son idénticas). OMS 1953-1967: CIE-7 lista A categoría 149, 'homicidio y operaciones de guerra' (grupo `violent` del archivo `who_violent_age_colombia_1953-1977.csv`). La categoría 149 de la CIE-8 (intención indeterminada) **no** se usa.
- Los años 1970, 1971 no tienen homicidio por edad en ninguna fuente (la OMS no los publica y el cuadro 6 empieza en 1973). 1973 y 1978 vienen solo del cuadro 6 del Registro.
- LAMBdA por causas (`lambda_Col_Cause19_Deaths{m,f}.txt`): el homicidio **no es separable**. El grupo de causas externas (`Cause_18` en los archivos; coincide por edad con la suma de las categorías A138-A149 de la OMS en 1977, hombres) junta accidentes, suicidio, homicidio e intención indeterminada. No se usa.
- Muertes violentas por departamento 1951-1964 (`dane_causas_violentas_dept_1951_1964.csv`): traen sexo pero no edad; no entran en esta fase.

## Vacíos conocidos y decisiones

- **Homicidio por edad**: nacional 1953-1969, 1972-1978 y 1979-2023 (faltan 1970 y 1971); departamental y municipal solo 1979-2023. No hay homicidio por edad departamental antes de 1979.
- **Todas las causas por edad**: nacional 1926-1928, 1936-2023 (faltan 1929-1935; LAMBdA, con grupos de edad gruesos en 1926-1949); departamental 1965-2023 (anuarios 1965-1969, Registro 1970-1978, EEVV 1979-2023); municipal 1979-2023. Para 1958-1960 hay municipios y departamentos (fase 1) pero **sin edad**.
- **1979**: año corto de las EEVV. La fase 1 usa para el total 1979 la cifra del Registro (cuadro 1/2); el único origen con edad es la EEVV, de modo que la suma de edades 1979 es la de las EEVV (110 400 defunciones) y no coincide con el total 1979 de la fase 1. Las filas llevan `cobertura = parcial`. En 1980-2023 la suma de edades sí es el total de la fase 1.
- **1978**: no existe en las EEVV; el Registro 1978 trae edad nacional y por sección, con los mismos totales que el cuadro 2 de la fase 1 (el total nacional de 1978, 124 613, es menor que el de 1977).
- Registro por sección (cuadro 11): `cobertura` y `nota` heredan las marcas de subregistro (`*`, `**`) del cuadro 2 de la misma unidad-año.
- Anuario 1968-1969: la fila `all` publicada difiere de la suma de las edades en el sexo (no en el total) de tres unidades-año: Bolívar 1968 (20), La Guajira 1968 (10) y Guainía 1969 (1), con hombres y mujeres transpuestos; se conservan las edades tal como están transcritas y el total publicado coincide. Cuadro 10 vs cuadro 11: difieren en `TN` 1976 (menores de 1 año -4, 1-4 +2); ver `verification_edad.csv`.
- **Sexo no registrado** (EEVV desde 1998): el total incluye esas defunciones; hombres + mujeres es menor que el total en esas celdas; las filas de hombres y mujeres del grupo (unidad, año, causa) quedan `parcial` con nota, como en la fase 1.
- **Municipal**: tabla completa con ceros explícitos para cada municipio-año presente en la fase 1 (19 grupos x 3 sexos x 2 causas).
- **LAMBdA** no es un conteo de registro bruto: difiere de las cifras registradas de la OMS y del Registro en 1950-1975 (hasta 55% en 15-44 años en 1970) y de las EEVV en 1982-2015 (hasta 27% en 5-14 años en 1991); solo se usa donde no hay otra fuente nacional con edad. No se verificó si corrige subregistro.
- **Unidades**: igual que la fase 1: 'Bogotá D.E.' del Registro y los anuarios es `11` Bogotá D.C.; 'Intendencias y comisarías' son `TN`; Quindío, Risaralda y Sucre aparecen como unidades separadas desde 1967 (anuarios) y en el Registro 1970-1978; en 1965-1966 están dentro de Caldas y Bolívar (nota).
- Los años de las EEVV son años de registro y el lugar es de ocurrencia; el Registro y los anuarios, la sección donde se registró.

## Controles (`verification_edad.csv`)

| check | n | n_failing |
|---|---|---|
| 1 clave única (nivel,cod,unidad,anio,causa,sexo,edad,edad_inicio,edad_fin) | 5 700 504 | 0 |
| 1b clave única (nivel,cod,anio,causa,sexo,edad) | 5 700 504 | 0 |
| 2 suma de edades = total fase 1 (misma fuente elegida en fase 1) | 98 686 | 0 |
| 2 suma de edades vs total fase 1 (fuente no elegida en fase 1), eevv | 30 | 0 |
| 2 suma de edades vs total fase 1 (fuente no elegida en fase 1), who_todas | 22 | 0 |
| 2 suma de edades vs total fase 1 (fuente no elegida en fase 1), lambda | 72 | 0 |
| 2 celdas con edad sin contraparte alguna en fase 1 (nivel,cod,año,causa) | 98 817 | 0 |
| 2 celdas EEVV con defunciones en fase 1 y sin filas de edad | 87 682 | 0 |
| 2b suma de edades = fila 'all' publicada por la misma fuente, reg_c11 | 675 | 0 |
| 2b suma de edades = fila 'all' publicada por la misma fuente, reg_c3 | 27 | 0 |
| 2b suma de edades = fila 'all' publicada por la misma fuente, reg_c6 | 18 | 0 |
| 2b suma de edades = fila 'all' publicada por la misma fuente, reg_c6t | 18 | 0 |
| 2b suma de edades = fila 'all' publicada por la misma fuente, ane_6567 | 198 | 0 |
| 2b suma de edades = fila 'all' publicada por la misma fuente, ane_6869 | 192 | 6 |
| 2c cuadro 11 (0 y 1-4) = cuadro 10 (menores de 5) | 450 | 2 |
| 2d cuadro 3 = cuadro 11 (nacional, por edad y sexo) | 540 | 0 |
| 2e cuadro 6 (fila TOTAL) = cuadro 11 (nacional, por edad y sexo) | 360 | 0 |
| 3 total = hombres + mujeres (por celda de edad; sexo ausente = 0 en municipal) | 1 900 168 | 2 732 |
| 4 homicidio <= todas por grupo de edad | 2 827 185 | 0 |
| 5 OMS vs EEVV, años en común | 0 | 0 |
| 5 OMS vs Registro 1970-1977, todas, por grupo amplio | 90 | 0 |
| 5 OMS vs Registro cuadro 6, homicidio, por grupo amplio | 60 | 0 |
| 5 LAMBdA vs EEVV nacional 1979-2015, todas, por grupo amplio | 510 | 21 |
| 5 LAMBdA vs OMS 1953-1977, todas, por grupo amplio | 300 | 15 |
| 5 LAMBdA vs Registro 1970-1978, todas, por grupo amplio | 75 | 15 |
| 5 OMS vs anuarios 1965-1967, todas, por grupo amplio | 45 | 0 |
| 5 OMS vs anuarios 1968-1969, todas, por grupo amplio | 30 | 0 |
| 5 Registro 1973-1978 vs EEVV, homicidio (sin años comunes) | 0 | 0 |
| 5b nacional = suma de departamentos, por edad (sexo total) | 1 976 | 0 |
| 6 inventario 'Edad y sexo' sin filas de edad en la tabla | 352 | 0 |
| 6 filas de edad en la tabla que el inventario no lista como 'Edad y sexo' | 354 | 2 |
| 7 filas por nivel y causa (por década: verification_edad_filas_por_decada.csv) | 5 700 504 | 0 |
| 7b filas en fuentes (todas las fuentes) | 5 705 664 | 0 |

## Cómo reconstruir

Desde la raíz del proyecto: `Rscript code/61_build_mortality_database_age.R` (requiere la salida de la fase 1; usa solo archivos ya extraídos; tarda unos minutos).
