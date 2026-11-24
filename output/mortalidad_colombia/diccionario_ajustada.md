# Mortalidad ajustada de Colombia por componentes, sexo y edad (fase 3)

Defunciones **ajustadas** del proyecto (escenario por defecto, `ajustada_por_componentes`), por componente (todas, natural, otras externas, violenta, crisis), sexo (total, hombres, mujeres) y grupo de edad, con las registradas de la fase 2 al lado cuando son comparables. Nacional 1950-2023 y departamental 1985-2023. **No hay municipal.** Generado por `code/62_build_mortality_database_adjusted.R` a partir de las salidas de `code/42_mortality_components_adjusted.R` (nacional) y `code/50_dept_mortality_adjusted.R` (departamental); no se reestima nada ni se inventa ningún ajuste: la tabla es el resultado de esos scripts en formato largo. Convenciones de `cod`, `unidad`, edad y `fuente_id` como en las fases 1 y 2 (`diccionario.md`, `diccionario_edad.md`).

## Archivos

| archivo | contenido | filas | tamaño |
|---|---|---|---|
| `mortalidad_colombia_ajustada.csv.gz` | tabla larga: nivel x unidad x año x causa x sexo x edad | 325 350 (nacional 19 980; departamental 305 370) | 9.98 MB |
| `unidades_ajustada.csv` | las 30 unidades (Colombia + 29), con los `cod` de la fase 1 que agrupa cada una | 30 | |
| `verification_ajustada.csv` | controles (check, n, n_failing, note) | | |
| `verification_ajustada_cobertura.csv` | filas, años y unidades por nivel x causa x década (control 7) | | |
| `verification_ajustada_razon_anual.csv` | razón def_ajustadas / def_registradas por año, nacional, todas, total (control 6) | | |
| `verification_ajustada_def_menor_registradas.csv` | años con celdas donde la ajustada es menor que la registrada (control 4) | | |
| `verification_ajustada_dep_vs_nacional.csv` | suma de departamentos contra nacional por año x causa x sexo x edad (control 5) | | |
| `verification_ajustada_violenta_vs_causas.csv` | violenta contra `deaths_by_cause` (control 8) | | |
| `verification_ajustada_detalle.csv` | detalle de los controles 2 y 3 que fallan | | |

## Cobertura

| nivel | años | unidades | causas | sexos | edades |
|---|---|---|---|---|---|
| nacional (`00`) | 1950-2023 (74) | 1 | 5 | total, hombres, mujeres | 18 |
| departamental | 1985-2023 (39) | 29 | 5 | total, hombres, mujeres | 18 |
| municipal | no disponible | | | | |

Todas las celdas están presentes con ceros explícitos (p. ej. `crisis` es cero fuera de los años con pisos externos y Armero). Cobertura por década en `verification_ajustada_cobertura.csv`. Antes de 1950 no hay serie ajustada. Los años de las EEVV son años de registro y las muertes son por lugar de ocurrencia; la población nacional es WPP 2024 y la departamental DANE (retroproyección 1985-2017, proyecciones del censo de 2018).

## Unidades

`cod` de 2 dígitos DIVIPOLA como en `unidades_colombia.csv`: `00` Colombia; 24 departamentos más Arauca, Casanare, Putumayo, San Andrés y Providencia (`81`, `85`, `86`, `88`) y Bogotá D.C. (`11`). **Grupo Amazonía: `cod = 9X`**, `unidad = "Amazonía (Amazonas, Guainía, Guaviare, Vaupés, Vichada)"`. Es el código del script 50 y no existe en la fase 1: en las fases 1 y 2 los cinco departamentos (`91`, `94`, `95`, `97`, `99`) aparecen por separado. `9X` no es un código DIVIPOLA; para comparar con la fase 2 se suman los cinco (la columna `cod_fase1` de `unidades_ajustada.csv` los lista). Se agrupan porque la serie ajustada se estima, como las tablas de vida de DANE, para el grupo y no por departamento. Quindío (`63`), Risaralda (`66`) y Sucre (`70`) van como unidades propias.

## Columnas

| columna | definición |
|---|---|
| nivel, cod, unidad, anio | como en la fase 1 |
| causa | `todas`, `natural`, `otras_externas`, `violenta`, `crisis` (definiciones abajo) |
| sexo | `total`, `hombres`, `mujeres` |
| edad, edad_inicio, edad_fin | grupos del ajuste: `0` (menores de 1 año), `1-4`, `5-9`, ..., `75-79` y `80+`. Convención de la fase 2: `edad_inicio` primera edad cumplida, `edad_fin` última edad cumplida incluida; `80+` es abierto: `edad_inicio` 80, `edad_fin` NA |
| poblacion | denominador del ajuste (WPP 2024 nacional; DANE departamental); total = hombres + mujeres |
| tasa_ajustada | tasa central de mortalidad (mx) = `def_ajustadas / poblacion`, por persona-año (no por 100 000) |
| def_ajustadas | `mx x poblacion` por sexo; **el sexo `total` es la suma de las defunciones de hombres y mujeres** (y su `tasa_ajustada` es esa suma sobre la población total, no una suma de tasas) |
| def_registradas | defunciones registradas comparables (ver abajo). NA cuando no hay equivalente |
| def_registradas_proyecto | solo causa `todas`: `mx_registered x poblacion` de los scripts 42/50, la registrada del proyecto con la edad desconocida repartida entre las edades conocidas (no la de la fase 2) |
| fuente_registradas | fuente de `def_registradas` (`fuente_id` de la fase 2, o `deaths_by_cause_sex_age_1953-2023 (30)` en violenta) |
| completitud | completitud aplicada por el ajuste (`completeness_natural`), **solo en `natural` (5 años y más) y `otras_externas` (todas las edades)**; NA en `todas`, `violenta`, `crisis`, en `natural` de menores de 5 años (UN IGME) y en el sexo `total`. 1 = registro completo |
| completitud_modelo | solo departamental: completitud del modelo departamental antes de calibrar a la serie nacional (`completeness_model` del script 50); NA en el resto |
| incluye_mse | TRUE en `todas` y `violenta` de los años 1985-2018, cuando el componente violento incluye el déficit del conflicto de la MSE (la celda puede tener un déficit cero) |
| incluye_crisis | TRUE en `todas` y `crisis` donde la celda tiene muertes de crisis (> 0) |
| anio_registro_colapsado | solo nacional: TRUE en 1969-1971 y 1978-1979, años en que el registro colapsó y el ajuste natural 5+ toma el valor del suavizado; NA en el nivel departamental |
| escenario | `ajustada_por_componentes` (único; la columna queda para alternativas futuras como WPP o WPP+MSE, que están en el archivo de entrada nacional como `mx_wpp` y `mx_wpp_mse` y **no se incluyen**) |
| metodo | texto con `method_natural` y `method_completeness` del script, y el método del componente |
| fuente_id | `proyecto` (el script y el archivo de origen están en `archivo`) |
| archivo | script y archivo de salida del proyecto de donde sale la fila |
| calidad | ver abajo |
| nota | definición del componente y avisos de la celda |

## Qué contiene cada causa

Todas las defunciones son **muertes de todas las edades del grupo, no fetales**, ajustadas por componentes y luego sumadas:

- **`todas`** = `natural + otras_externas + violenta + crisis` (tasa total `mx_total` de los scripts). Para menores de 5 años la tasa total es la de UN IGME (m0 y 4m1) más las muertes de crisis, y la natural se obtiene restando las otras externas y las violentas; por eso en el nivel departamental, en 41 celdas de 1-4 años (18 de ellas `total`), la natural está recortada en cero y la suma de componentes excede a `todas` (control 2; en el nivel nacional no hay ninguna).
- **`natural`**: todo lo que no es causa externa, **incluidas las causas mal definidas** (supuesto: son naturales; 27% de las muertes en 1953, 8-15% en 1979-1985, 2% desde 2000), corregido por completitud. 0-4 años: UN IGME (nacional) o UN IGME por un índice departamental DANE; 5-64: registradas / completitud suavizadas con un spline P tensorial (1950-2019; 2020-2023 usan las tasas corregidas anuales porque el COVID-19 es mortalidad real; los años de registro colapsado quedan fuera del ajuste y toman el valor suavizado); 65+: modelo relacional logit sobre el patrón WPP 2010-2019 con el nivel de las muertes naturales corregidas de 65+, desplazamiento suavizado en el tiempo.
- **`otras_externas`**: accidentes, suicidio y el resto de causas externas, **registradas / la misma completitud de las naturales** (supuesto sin evidencia propia).
- **`violenta`**: **no es la categoría CIE de homicidio.** Contiene (a) las muertes violentas registradas del proyecto (`dx_v`): homicidio + intención no determinada + intervención legal (EEVV 1979-2023: códigos 101-103 de la lista 105 de DANE; CIE-9 E960-E978, CIE-10 X85-Y09, Y10-Y34, Y35-Y36); antes de 1979, el grupo violento de la OMS (CIE-7 A149 `homicidio y operaciones de guerra` en 1953-1967; CIE-8 A148 + A149 en 1968-1977; 1973 y 1978 del Registro de defunciones 1970-1978, cuadro 6; 1950-1952 y 1971 sin detalle de causa: participaciones interpoladas); y (b) en 1985-2018, el **déficit del conflicto armado** de la MSE, es decir los homicidios que la MSE estima y no están registrados como violentos más las desapariciones forzadas (`hom_excess + dsp` del script 27; por departamento, script 51). **Sin factor de completitud** (las violentas las certifica medicina legal). Un número `violenta` es mayor que el homicidio de la fase 2 (que es solo el código 101) por la intención no determinada, la intervención legal, las operaciones de guerra de la CIE-7 y, en 1985-2018, el déficit MSE.
- **`crisis`**: muertes que el registro nunca vio, de conteos externos (script 47), no ajustadas por completitud: (1) pisos de las violentas registradas con el conteo de homicidios de la Policía Nacional (1963-1968 y 1978-1984) y con la estimación demográfica de La Violencia de Romero-Prieto y Meisel-Roca (2019) (1950-1969), tomando el mayor de los conteos (`max(eevv + mse, policía, violencia) - (eevv + mse)`); (2) la tragedia de Armero (13 de noviembre de 1985, 22 654 muertes, mortalidad por desastres de WPP 2024 / EM-DAT) en 1985. Las muertes de los pisos se reparten por sexo y edad con el patrón de las violentas registradas; también entran en los menores de 5 años. En los departamentos solo hay crisis en 1985: Armero, 1 100 muertes a Caldas (17, Chinchiná) y el resto a Tolima (73) (supuesto sobre el reparto); desde 1985 el piso de la Policía es cero en el nacional.

**No existe una serie ajustada solo de homicidio** en los resultados del proyecto (no hay `homicide_*` ajustado ni una versión de `crisis_deaths_1950-2023.csv` o de la MSE separada por causa y edad que permita aislarlo): el ajuste se hace sobre el componente violento (homicidio + intención no determinada + intervención legal) y el déficit MSE mezcla homicidios no registrados y desapariciones forzadas. Armarla con el homicidio de la fase 2 más el `hom_excess` del script 27 sería un ajuste nuevo (el exceso se calcula contra las violentas completas, no contra el código 101), de modo que no se incluye `homicidio_ajustado`.

## `def_registradas`

- Causa `todas`: la registrada de la **fase 2** (`mortalidad_colombia_edad.csv.gz`, la fuente elegida allí para la celda) para el mismo nivel, unidad, año, sexo y grupo de edad. Los grupos de la fase 2 `80-84` y `85+` (o `80+` cuando la fuente así lo publica) se **suman en el grupo abierto `80+`** del ajuste, cuyo `edad_inicio` es 80 y `edad_fin` NA; el resto de grupos coincide exactamente (`0`, `1-4`, `5-9`, ..., `75-79`). Se omite la edad `desconocida` de la fase 2 (hasta 1.7% de las defunciones hasta 1990, 0.45% desde 2010), así que la registrada de la fase 2 por grupo es algo menor que `def_registradas_proyecto`, que reparte esas defunciones. Para el sexo `total` se usa la fila `total` de la fase 2 (incluye sexo no registrado). `9X` suma los cinco departamentos amazónicos de la fase 2. Faltan 54 celdas departamentales sin fila en la fase 2.
- Causa `violenta`, nivel nacional, 1953-2023: `violent_reg` de `deaths_by_cause_sex_age_1953-2023.csv` (script 30), con el grupo abierto 80+ ya como en el ajuste; el sexo `total` es hombres + mujeres. Para 1970 y 1971 es una interpolación del proyecto. Sin cifra para 1950-1952 ni para el nivel departamental.
- Causas `natural`, `otras_externas`, `crisis`: NA (la fase 2 no trae causas, y los archivos de entrada no dan la registrada del componente).

## `calidad`

Valores `observada`, `escalada`, `interpolada`, `MSE` (como en las fases 1-2), más `modelada` (una adición a ese vocabulario):

| causa | calidad |
|---|---|
| `violenta` | `MSE` en 1985-2018 (flag `MSE` de `deaths_by_cause`); `interpolada` en 1950-1952, 1970, 1971 (participaciones o cifras sin detalle de causa; flag `interpolated` de `deaths_by_cause` en 1970-1971); `observada` en el resto (registradas sin escalar, el flag `scaled` de `deaths_by_cause` describe su serie escalada, que no es la usada aquí) |
| `natural` | `escalada` donde es la tasa registrada / completitud anual (5-64 años de 2020-2023); `modelada` donde es suavizada, relacional (65+) o UN IGME (menores de 5) |
| `otras_externas`, `crisis` | `escalada` (registradas / completitud; conteos externos repartidos con el patrón de las violentas registradas) |
| `todas` | `MSE` en 1985-2018 (incluye el déficit MSE); `escalada` en los demás años |

## Metodología (resumen de los scripts 42 y 50)

Se corrige cada componente y luego se suman, en vez de ajustar la mortalidad total de una vez.

- **Completitud de las muertes de 5 años y más (natural y otras externas)**: 1970-2023, método empírico (Adair-Lopez modelo 1 sobre las muertes no violentas), anual. 1950-1969: el método empírico está fuera de su periodo de calibración y da cerca de 0.98 en contra de las demás fuentes; la completitud se ancla en 1951 y 1964 con la media de dos estimaciones independientes (NRC 1982, cuadro 50: hombres 0.774 y 0.817, mujeres 0.727 y 0.800; y registradas / WPP 2024 en 15+), se interpola en la escala logit hasta el valor empírico de 1970, y 1950 toma el valor de 1951. Las tres variantes (central, NRC, WPP) existen en los archivos del proyecto; **aquí solo la central**.
- **Departamental (50)**: la misma construcción por departamento: muertes por municipio de las EEVV sumadas a departamentos (85+ plegado en 80+, edad desconocida repartida dentro de departamento, año, sexo y componente); completitud Adair-Lopez modelo 1 suavizada en el tiempo (1985-2019, fijada en el valor de 2019 desde 2020, tope 1) y **calibrada a la serie nacional**: las omisiones departamentales (1/c - 1) se escalan por k(año, sexo) para que la suma de muertes no violentas corregidas de 5+ iguale la nacional; el modelo departamental da la distribución de la omisión, la serie nacional su nivel. Menores de 5 años: UN IGME nacional por un índice departamental de las tablas de vida DANE, reescalado para que su media ponderada sea la nacional. El déficit MSE se reparte entre departamentos según la MSE regional por la participación de víctimas documentadas (51) calibrado al nacional.
- **Población**: WPP 2024 en la serie nacional; DANE en la departamental, de modo que la suma de departamentos no coincide con la serie nacional (control 5).

## Controles (`verification_ajustada.csv`) y qué no cuadra

| control | resultado |
|---|---|
| 1 clave única | 0 duplicados |
| 2 `todas` = suma de componentes (tol. 1e-6) | 41 celdas fallan, todas departamentales de 1-4 años (natural recortada en cero bajo UN IGME x índice); nacional exacto |
| 2b, 2c total = hombres + mujeres; tasa = def / población | 0 fallas |
| 3 e0 recalculada con la tabla abreviada de 42 = e0 de los resúmenes | máxima diferencia 2.4e-9 años (nacional) y 3.2e-9 (departamental); función idéntica a la de 42 y 50 |
| 4 `def_ajustadas >= def_registradas` (todas) | **falla en 10 080 de 65 016 celdas** (nacional 154; departamental 9 926): son casi todas de 65+ (en el departamental ~60% de las celdas 65-74 años) y de 1-4 años, donde la serie ajustada (modelo relacional, suavizado, UN IGME) queda por debajo de la registrada de una unidad pequeña; en el nacional, 80+ y 60-64 en 1957-1962 y 1973-1974. Con la registrada del proyecto fallan 10 670. No es completitud mayor que 1: es la tasa suavizada. Detalle por nivel y año en `verification_ajustada_def_menor_registradas.csv`. En totales nacionales por año no hay ningún año con razón < 1 |
| 5 suma de departamentos vs nacional | por año x sexo x causa (todas las edades) la razón coincide con `ratio_total` de `dept_vs_national_adjusted_deaths.csv` (dif. máx. 1e-10): 0.982 a 1.04, de los cuales la razón de poblaciones DANE/WPP es 0.975 a 1.05. Por año x sexo x edad la diferencia en defunciones tiene mediana +0.2% y rango de -41% a +82% (celdas con diferencia > 5%: 1 642 de 10 530); en tasas, -50% a +23%. La causa es la población (DANE vs WPP) y la estructura de edades, no un error de la suma |
| 6 razón ajustada / registrada (nacional, todas, total) | mediana por década (fase 2): 1950s 1.21, 1960s 1.10, 1970s 1.12, 1980s 1.26, 1990s 1.26, 2000s 1.15, 2010s 1.12, 2020s 1.06; mín-máx global 1.04-1.49 (pico en 1978-1979: total registrado bajo); se parece al inverso de la completitud natural (mediana 1.26, 1.13, 1.07, 1.18, 1.21, 1.12, 1.12, 1.07) con correlación anual de 0.57; no es idéntica porque incluye violentas (sin factor), crisis, menores de 5 (IGME) y 65+ (relacional) |
| 7 cobertura | completa: 74 años nacionales, 39 departamentales, 5 causas |
| 8 `violenta` vs `deaths_by_cause` | (a) en 1985-2018 la diferencia con `violent_adj` es de +0.005% a +5.2%: el script 30 usa las violentas con edad conocida del EEVV y el 42 las del script 40 (edad desconocida repartida), la causa de la diferencia (control 8e: +0.006% a +6.2%); (b) sin MSE 1953-1984 y 2019-2023 `violenta` vs `violent_reg`: -8.9% a +23.3% (el 42 usa las violentas del script 40, la del 30 usa las cifras de la OMS y las EEVV por edad; 1970-1971 interpoladas); (c) 1953-1984 `violent_adj` de 30 escala las violentas por el factor de completitud de todas las causas (1 a 2) mientras 42 las deja registradas y añade pisos externos como `crisis`: `violenta + crisis` difiere de -31% a +54% (31 de 32 años con diferencia > 5%); (d) `violenta` = violentas del script 40 exacta (1e-10) fuera de la MSE |
| 9 violenta departamental vs nacional (MSE) | la suma de departamentos difiere del nacional entre -0.05% y +0.7% por año y sexo |

## Límites conocidos

- **No es un homicidio ajustado**: `violenta` mezcla homicidio, intención no determinada, intervención legal (y operaciones de guerra de la CIE-7), más el déficit MSE (homicidios no registrados como violentos y desapariciones forzadas). Antes de 1985 y desde 2019 no hay déficit MSE: las muertes violentas no registradas solo entran por `crisis` (pisos de la Policía y de La Violencia, y Armero), y desde 1985 solo la MSE.
- Los supuestos clave: causas mal definidas naturales; otras externas con la misma completitud que las naturales; las violentas sin factor de completitud; el reparto de las muertes de crisis con el patrón de las violentas registradas; el reparto departamental del déficit MSE y de Armero.
- 1950-1969: la completitud sale de dos estimaciones externas con diferencias de unos 13 puntos en 1964 (NRC vs WPP); la variante central es su media y las otras dos no están en esta tabla.
- 1969-1971 y 1978-1979 (registro colapsado): ajuste natural 5+ con el suavizado en lugar del dato anual. 1970-1971: violentas por edad interpoladas.
- Los resultados departamentales no son estrictamente comparables con los nacionales (población DANE frente a WPP); el nivel departamental no incluye `homicidio`. Amazonía agrupada (`9X`).
- 80+ es un grupo abierto: no hay 80-84 ni 85+ en esta tabla; la fase 2 sí los trae.
- La edad desconocida se reparte dentro de la unidad, año, sexo y componente en las series ajustadas; la fase 2 la guarda como `desconocida`.
- `modelada` es un valor de `calidad` nuevo respecto a las fases 1 y 2.
