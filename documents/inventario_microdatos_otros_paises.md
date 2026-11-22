---
title: "Microdatos de mortalidad de Brasil, México y Estados Unidos: qué hay y qué falta"
date: 2026-11-14
lang: es
maxwidth: 62em
header-includes: |
  <style>
  table { font-size: 0.9em; margin: 1em 0; }
  th, td { padding: 0.3em 0.6em; vertical-align: top; }
  </style>
---

Inventario de `D:\data` al 14 de noviembre de 2026, hecho para replicar por estado la validación del modelo de
homicidios con la razón de sexos. Lo que el análisis necesita de cada país es un panel de defunciones por
estado, año, sexo, edad y causa (homicidio o no).

El inventario se hizo en modo de solo lectura: se abrieron encabezados y primeras filas, no archivos completos.
La última sección dice qué quedó sin verificar.

**Actualización del 22 de noviembre de 2026.** Las secciones siguientes describen lo que había el 14 de
noviembre. Desde entonces:

| País | Qué cambió | Panel por estado que se usa ahora |
|---|---|---|
| Brasil | se bajaron de DATASUS los archivos nacionales de 1979-1989 (CIE-9, `.dbc`) a `brazil_mortality\sim_cid9_1979_1989`; Tocantins se mantiene dentro de Goiás para que las unidades sean estables | 1979-2020, 26 unidades (`code/71`) |
| México | llegaron los dbf de INEGI de todos los años de registro, 1990-2025; el de 2020 reemplaza al CSV, que INEGI corrigió en 2022 | 1990-2025 por año de ocurrencia, 32 entidades (`code/73`); la validación usa 1990-2024 |
| Estados Unidos | se leyeron los microdatos de 1979-2004 (posiciones comprobadas contra los totales publicados) y llegaron tablas de CDC WONDER 1999-2020 por estado | 1979-2020, 48 estados en todas las edades y 44 en 15-44 (`code/74`, `code/76`); definición estrecha de muerte violenta, sin intención no determinada |

Todo se respalda en el disco externo (`H:\data`, con un README que describe cada carpeta). La sección 5 queda
superada en lo que respecta a México 1990-2011 y a EE. UU. después de 2004. Lo que sigue faltando de EE. UU.:
las defunciones de todas las causas de 1968-1978 por estado y sexo (el archivo con ese nombre es en realidad la
consulta de homicidios) y, si se quiere la misma definición que en los otros países, la intención no
determinada desde 2005.

# 1. Resumen

| | Brasil | México | Estados Unidos |
|---|---|---|---|
| Carpeta | `brazil_mortality` | `mexico_mortality` | `us_mortality` |
| Fuente | SIM, Ministerio de Salud | INEGI, defunciones registradas | NCHS, archivos de uso público |
| Años en la carpeta | 1990-2020 | 2012-2020 (año de registro) | 1979-2021 |
| Archivos y tamaño | 31 CSV, 7,2 GB | 9 CSV, 0,4 GB (8 dentro de un zip) | 43 zip, 3,5 GB (unos 45 GB al descomprimir) |
| Formato | CSV con encabezado | CSV con encabezado | texto de ancho fijo, sin encabezado |
| Estado de residencia | sí, todos los años | sí, todos los años | **solo 1979-2004** |
| Sexo, edad y causa | sí | sí | sí, pero falta el diccionario para ubicarlos antes de 2003 |
| Clasificación de causas | CIE-9 hasta 1995, CIE-10 desde 1996 | CIE-10 | CIE-9 hasta 1998, CIE-10 desde 1999 |
| Diccionario en la carpeta | sí (PDF) | no | no |
| **Panel por estado que se puede armar hoy** | **1990-2020, 27 unidades** | **2012-2020, 32 entidades** | **1979-2004, 51 unidades** |

Ninguna carpeta trae tablas ya agregadas ni población.

# 2. Brasil

**Lo que hay**

- Un CSV por año, de 1990 a 2020, sin huecos.
- El estado sale de los dos primeros dígitos del código de municipio, tanto de residencia como de ocurrencia.
  No hay una columna de estado aparte.
- Sexo, edad (código de tres dígitos: unidad y valor), fecha de defunción y causa básica en todos los años.
- El diccionario oficial del SIM, con la definición de cada variable y el año en que empezó.

**Lo que falta o complica**

- **Los nombres de las columnas cambian tres veces** (1990-1995, 1996-2005, 2006 en adelante). Hay que
  armonizarlos.
- **Cambio de clasificación en 1996.** La serie de homicidios cruza de CIE-9 a CIE-10; hay que comprobar que no
  deje un escalón.
- **En 1990-1995 algunas defunciones traen residencia solo a nivel de estado.** No afecta un análisis por
  estado.
- **1979-1989 no está en la carpeta.** El SIM existe desde 1979; esos años alargarían la serie, pero no son
  indispensables.
- **Calidad del registro.** Es conocido que en el norte y el nordeste hubo subregistro y muchas causas mal
  definidas o de intención no determinada, sobre todo en los años noventa. No se midió aquí.

# 3. México

**Lo que hay**

- Un CSV por año de registro, de 2012 a 2020, con la misma estructura de 59 columnas.
- Entidad de residencia, de ocurrencia y de registro; sexo; edad; año de ocurrencia; causa en CIE-10.
- Una variable propia de muerte violenta (`presunto`), además del código de causa.

**Lo que falta o complica**

- **Solo nueve años.** Es poco para la prueba de bloques ocultos, que necesita una serie larga a cada lado del
  bloque.
- **Falta 1990-2011.** INEGI publica estos microdatos desde 1990. Sin esos años no se ve la subida de la
  violencia de 2007 a 2011, que es el tramo más informativo para el método.
- **Los archivos van por año de registro, no de ocurrencia.** Cada archivo trae defunciones de años
  anteriores. Hay que reclasificar por año de ocurrencia, y el último año queda incompleto.
- **No hay diccionario en la carpeta.** Los códigos de sexo y edad se leyeron según la convención de INEGI, sin
  comprobarlos.
- **Detalles de formato:** los códigos de entidad de 2012-2019 traen un tabulador pegado, y el archivo de 2020
  está fuera del zip, con los nombres en mayúsculas y una columna de más.

# 4. Estados Unidos

**Lo que hay**

- Un zip por año, de 1979 a 2021, sin huecos. Cada uno contiene un archivo de texto de ancho fijo.
- Estado de ocurrencia en 1979-2004, y estado de residencia confirmado en 2003-2004.
- Causa básica en todos los años; sexo y edad ubicados desde 2003.

**Lo que falta o complica**

- **De 2005 a 2021 no hay estado ni condado.** Son los archivos de uso público, a los que NCHS les quita la
  geografía desde 2005. Para esos años haría falta otra fuente: los archivos restringidos de NCHS o los
  conteos por estado de CDC WONDER.
- **No hay diccionario.** Las posiciones de 1979-2002 se dedujeron mirando los registros. El estado de
  residencia parece estar en las columnas 31-32, pero no está confirmado; el sexo y la edad de esos años no se
  ubicaron. Los diccionarios son públicos y hay que bajarlos de NCHS.
- **Dos sistemas de códigos de estado:** numéricos hasta 2002 y de dos letras en 2003-2004. Hace falta una
  tabla de equivalencias.
- **Cambio de clasificación en 1999** (CIE-9 a CIE-10).
- **Los zip de 2020 y 2021 usan una compresión que R no lee.** Se pueden leer con 7-Zip, que está instalado.
- **El archivo suelto `Vs81mort` (0,8 GB) duplica** el contenido de `mort1981us.zip`.

# 5. Qué falta para el análisis en conjunto

| Qué falta | Para qué | Qué tan necesario |
|---|---|---|
| Diccionarios de NCHS de 1979-2002 | ubicar sexo, edad y estado de residencia en Estados Unidos | indispensable para usar ese país |
| Estado en Estados Unidos desde 2005 | alargar la serie de 26 a 43 años | opcional: 1979-2004 ya alcanza para validar |
| México 1990-2011 | tener una serie larga y el periodo de mayor cambio | casi indispensable: con nueve años la prueba es débil |
| Definición común de homicidio | comparar países y cruzar los cambios de clasificación | indispensable; se propone la de Colombia: homicidio, intención no determinada e intervención legal |
| Tablas de equivalencia de códigos de estado | armar las unidades | indispensable, trabajo menor |
| Población por estado y año | tasas por habitante y el modelo simple de comparación | opcional: el modelo principal usa defunciones, no población |
| Brasil 1979-1989 | alargar la serie | opcional |

# 6. Disco

- **No hace falta copiar nada al proyecto.** Los scripts pueden leer los microdatos desde `D:\data` y guardar
  solo el panel agregado por país, que pesa unos pocos megabytes.
- **Estados Unidos no se debe descomprimir entero:** son unos 45 GB. Se lee cada año directamente del zip.
- Espacio libre al hacer el inventario: 17 GB en C:, donde está el proyecto, y 129 GB en D:.

# 7. Qué no se verificó

- No se contaron filas ni se revisó la distribución de años dentro de cada archivo.
- No se comprobó la integridad de los zip completos; solo su índice y el comienzo de los archivos abiertos.
- En Estados Unidos se abrieron 14 de los 43 años; los demás se suponen iguales a sus vecinos.
- No se probó la definición de homicidio en ningún país, ni los códigos de estado fuera de los valores
  esperados (extranjero, desconocido).
- Lo que se dice sobre lo que existe fuera de la carpeta (INEGI desde 1990, SIM desde 1979, archivos
  restringidos de NCHS, CDC WONDER) es conocimiento general, no algo comprobado en este inventario.
