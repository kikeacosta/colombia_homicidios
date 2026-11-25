# Homicidios a partir de la razón de sexos de las muertes: resumen y conclusiones

*25 de noviembre de 2026 · resumen para la reunión. El detalle está en los tres informes: [modelo de Colombia](modelo_homicidios_departamental.html), [validación internacional](reporte_validacion_internacional.html) y [España](reporte_prueba_ciega_estimador_espana.html).*

## La idea en una frase

Las víctimas de muertes violentas son casi todas hombres (78–95 %), y las demás muertes se reparten entre hombres y mujeres de forma estable. Si en un lugar y un año mueren más hombres de lo esperable, lo más probable es que haya habido violencia. Con eso se puede estimar la violencia donde no hay causas de muerte, como en la Colombia de antes de 1979 o en España durante la guerra civil, usando solo las muertes por sexo.

## Los tres métodos

| | Qué hace | Qué necesita en los años que estima | Qué necesita en otros años, para aprender |
|---|---|---|---|
| **1. Estados ocultos** (el principal) | Sigue año a año dos cantidades que no se ven: la proporción de muertes violentas y la razón de sexos de las muertes no violentas. Las une con la razón de sexos observada mediante una identidad contable, y combina todas las fuentes disponibles según su ruido. | Muertes por sexo de cada unidad. El total nacional de homicidios es opcional y mejora la estimación. | Homicidios **por unidad** en algunos años (anuarios, Policía, estadísticas vitales), para fijar el nivel y saber cuánto se mueve cada cosa |
| **2. Regresión simple** | Regresión de las muertes violentas de cada unidad sobre la razón de sexos y el total nacional. Sirve de referencia. | Muertes por sexo y totales de cada unidad, y el **total nacional** de homicidios de ese año | Homicidios **por unidad** en otros años, para estimar los coeficientes |
| **3. Estimador directo** | Despeja las muertes violentas de cada año con la misma identidad, fijando la razón de sexos no violenta en la de un periodo de paz. Es el que se usó en España. | Muertes por sexo de cada unidad | **Ningún homicidio**: solo un periodo base de paz y la proporción de hombres entre las víctimas (~0,95) |

**Lo que esto implica:**
- **El estimador directo es el único que funciona donde no hay ningún dato de homicidios por unidad,** como en España en la guerra. Los otros dos necesitan algunos años con homicidios por unidad para aprender.
- **En la Colombia histórica sí hay de dónde aprender:** los anuarios de 1923–65 y las estadísticas vitales desde 1979.
- **En España,** para usar el modelo de estados ocultos hubo que tomar como dato por provincia las causas violentas registradas.

Ninguno usa la población, así que los errores de los censos no entran en la estimación.

## 1. ¿Qué tan bien funciona? El año de mayor cambio de cada país

En cinco países con causas de muerte conocidas, cada método estimó las muertes violentas de años que no vio. Para cada país se evalúa el año de su **mayor cambio**, que es donde se ve si un método capta la dinámica. Ese año se ocultó junto con los **5 años anteriores y los 5 posteriores**, para que quede igual de lejos de los datos conocidos por ambos lados. Si se ocultara solo hasta ese año, el año siguiente conocido le daría al modelo casi el mismo nivel y la interpolación parecería mejor de lo que es.

| País | Año evaluado | Qué pasó | Años ocultos |
|---|---|---|---|
| Colombia | 1991 | Pico de violencia, de 14.500 muertes violentas en 1985 a 30.100 | 1986–1996 |
| México | 2011 | Guerra contra el narco, de 11.300 en 2007 a 33.100 | 2006–2016 |
| Brasil | 2014 | Subida hasta el máximo de 2017 (75.500) y caída posterior. Los datos terminan en 2020, así que el bloque no puede centrarse en 2017 | 2009–2019 |
| EE. UU. | 1991 | Pico de comienzos de los noventa | 1986–1996 |
| Ecuador | 2023 | Explosión, de 1.153 en 2018 a 7.999 | 2018–2024: cinco años antes, como en los demás países, y desde antes de que empezara la subida. No hay datos posteriores, así que es un pronóstico |

La figura compara, unidad por unidad, lo registrado en las estadísticas vitales (eje x) con lo estimado (eje y). Si un punto cae sobre la línea punteada, la estimación es exacta. En cada panel van el error mediano por unidad y el error del total nacional.

![Lo registrado frente a lo estimado en el año de mayor cambio](../figures/09_international/intl_dynamic_years.png)

*Los puntos pegados al borde inferior (valor 1) son estimaciones negativas o nulas, casi todas del estimador directo.*

**Error mediano por departamento o estado (%)** y, entre paréntesis, error del total nacional:

| País y año | Violentas, % de las muertes | Sin pistas (interpolar) | 1. Estados ocultos | 2. Regresión simple | 3. Directo |
|---|---|---|---|---|---|
| Colombia, 1991 | 18,4 | 24 (−33 %) | 11 (−4 %) | **7** (dado) | 9 (+9 %) |
| México, 2011 | 5,6 | 23 (−34 %) | **19** (−14 %) | 40 (dado) | 39 (−22 %) |
| Brasil, 2014 | 5,7 | 21 (−16 %) | **13** (−9 %) | 14 (dado) | 27 (−27 %) |
| EE. UU., 1991 | 1,2 | 21 (−27 %) | 21 (−25 %) | **17** (dado) | 98 (+122 %) |
| Ecuador, 2023 | 9,1 | 54 (−80 %) | 38 (−37 %) | 80 (dado) | **36** (+23 %) |

*Todas las edades. "Sin pistas" es un modelo ingenuo: traza una línea recta entre el último año conocido antes del bloque y el primero después, o, en el pronóstico de Ecuador, repite el nivel de 2017. No extrapola tendencias. La regresión simple conoce además el total nacional de cada año ("dado"), así que solo reparte ese total entre las unidades.*

**Cómo se lee:**
- **La razón de sexos capta los saltos.** En Colombia 1991, interpolar se queda corto un 33 % en el total nacional, y el modelo de estados ocultos, solo un 4 %. Unidad por unidad, el error baja de 24 % a 11 %. En México 2011 el total pasa de −34 % a −14 %, y en Brasil, de −16 % a −9 %.
- **Donde la violencia pesa muy poco (EE. UU., 1,2 %), la razón de sexos no añade nada:** 21 % de error con y sin ella. Ahí solo ayuda conocer el total nacional (17 %).
- **Un pronóstico de un salto como el de Ecuador es más difícil, pero la razón de sexos lo detecta.** Sin pistas, el modelo repite el nivel de 2017 y se queda corto un 80 %. Con la razón de sexos capta buena parte de la subida, aunque sin ningún año posterior que lo corrija: queda corto un 37 %.
- **El estimador directo funciona donde la violencia pesa mucho.** En Colombia 1991 tiene 9 % de error por unidad, y en Ecuador 2023, 36 %: tan bien o mejor que el modelo de estados ocultos, aunque en Ecuador sobreestima el total un 23 %. Donde la violencia pesa poco falla, con muchas estimaciones negativas (México, EE. UU.).

**Lo mismo en mapas.** Para cada país, la proporción de las muertes de ese año que fueron violentas: a la izquierda la registrada, en el centro la estimada por el modelo de estados ocultos sin ver esos años, y a la derecha la diferencia. Rojo quiere decir que sobreestima y azul que subestima. Se usa el porcentaje de las muertes, no la tasa por habitante, porque los modelos no usan población.

![Colombia, 1991](../figures/09_international/maps/map_colombia_1991.png)

![México, 2011](../figures/09_international/maps/map_mexico_2011.png)

![Brasil, 2014](../figures/09_international/maps/map_brazil_2014.png)

![Estados Unidos, 1991](../figures/09_international/maps/map_us_1991.png)

![Ecuador, 2023](../figures/09_international/maps/map_ecuador_2023.png)

*En Colombia, los departamentos se agrupan en las 15 unidades estables del modelo (Territorios reúne los antiguos territorios nacionales). Límites: Natural Earth.*

**Un año común para todos (2015, con 2011–2018 ocultos)** da el mismo orden. El modelo de estados ocultos tiene el menor error mediano en 4 de 5 países: Colombia 8 %, Brasil 9 %, Ecuador 21 % y EE. UU. 7 %. En México gana la regresión simple con el total nacional, 17 % frente a 21 %. El estimador directo solo se acerca en Colombia, con 18 %. La figura está en `figures/09_international/intl_holdout_2015.png`.

**La validación completa** repite esto en 20 combinaciones de país, edad y tipo de prueba (bloques intermedios, 15 años hacia atrás y 4 años hacia adelante), y el patrón es el mismo:
- **Sin el total nacional,** el modelo de estados ocultos es el mejor o empata en 17 de las 20.
- **Hacia atrás, a 15 años,** la razón de sexos puede empeorar el resultado donde la violencia pesa poco (Brasil, Ecuador), porque el envejecimiento también mueve la razón de sexos.
- **Los intervalos del 90 % del modelo** son confiables en años intermedios, pero demasiado estrechos hacia atrás: contienen el valor real solo el 64–88 % de las veces.

## 2. Colombia: homicidios por departamento, 1915–2019

El modelo de estados ocultos combina para 15 unidades (departamentos o grupos de departamentos estables) cuatro fuentes:
- los anuarios (1923–65);
- la Policía (1962–97);
- las estadísticas vitales (desde 1979);
- la serie nacional de la OMS (1966–77).

Además trata las celdas de los anuarios que parecen errores de transcripción.

| Periodo | Homicidios registrados estimados | Por año | Tasa por 100.000 |
|---|---|---|---|
| 1915–45 | 22.500 | 700 | 9 |
| 1946–65 (La Violencia) | 81.400 | 4.100 | 29 |
| 1966–78 | 73.800 | 5.700 | 27 |
| 1979–97 | 373.900 | 19.700 | 60 |
| 1998–2019 | 475.500 | 21.600 | 51 |

![Serie nacional estimada](../figures/08_backcast/backcast_national.png)

**Lo principal:**
- **La razón de sexos ayuda mucho desde 1985,** cuando los homicidios son el 10–15 % de las muertes: el error en años ocultos baja de 20 % a 9 % (1985–97) y de 16 % a 7 % (1998–2010).
- **Antes de 1966 aporta poco,** porque los homicidios eran solo el 2–3 % de las muertes. Ahí la serie se apoya en los anuarios, y el modelo sirve sobre todo para limpiarlos y llenar sus huecos.
- **El hueco de 1966–78 depende de la Policía,** que es inestable, ajustada al total nacional de la OMS: la suma queda a menos del 3 % de la OMS en 1972–77.
- **Subregistro:** corregido por el registro incompleto de defunciones, el total sube 3–12 % antes de 1998 (escenario central), con correcciones mayores en Bolívar–Córdoba–Sucre y Magdalena–Cesar (+38–40 %).
- **Ajuste reciente:** el modelo pasó a escala logit, que es lo composicional. Las estimaciones cambiaron menos de 1 % y los intervalos cubren algo mejor.

## 3. España, 1936–1946

Es una aplicación a un contexto sin causas de muerte confiables. Se usaron las muertes por provincia y sexo de 1926–1946, transcritas de los anuarios del INE, y se contrastaron con las causas violentas registradas en 1936–42, también transcritas.

| | 1936–39 (guerra) | 1940–42 (posguerra) |
|---|---|---|
| Exceso total de muertes | ~350.000 | ~217.000 |
| Muertes violentas, estimador directo | 193.500 | 95.000 |
| Muertes violentas, estados ocultos | 194.000 | 102.700 |
| Registradas como violentas | 158.700 | 28.000–64.000 |
| Incertidumbre estadística | ±7 % (183.000–210.000) | |
| Rango razonable, con los sesgos | **160.000–240.000** | **techo: ~95.000–103.000** |

![España: métodos y violencia registrada](../figures/09_international/spain_state_space.png)

![España por provincia, 1936-1939](../figures/09_international/maps/map_spain_1936-1939.png)

*El mapa muestra lo mismo que la tabla: las dos estimaciones siguen a lo registrado, con más violencia en el frente de Aragón, Madrid y el norte. El estimador directo falla donde hubo poca violencia (Canarias, Galicia).*

**Lo principal:**
- **1936–39 es sólido.** Dos métodos con supuestos distintos dan lo mismo (194.000). Las estimaciones coinciden con la literatura (Salas, Ortega y Silvestre) y con la violencia registrada provincia por provincia (correlación 0,94). Las propias causas registradas confirman que el 93–97 % de las víctimas eran hombres.
- **El registro contiene cerca del 80 % de la violencia en 1936–39 y del 65 % en 1940.** Es la primera estimación con incertidumbre de lo que faltó en el registro.
- **1940–42 queda acotado, pero no resuelto.** El exceso de muertes de hombres (~100.000) es un techo, y lo registrado como violento (28.000–64.000) un piso. La diferencia puede ser hambre y tifus matando más hombres, o represión registrada bajo otras causas. Para separarlas hacen falta las muertes por edad.
- **Los bombardeos casi no cambian el total** (+1,7 %), pero sí algunas provincias: Oviedo +15 %, Barcelona +9 %.
- **En curso:** la digitalización de las muertes por provincia, sexo y edad simple de 1933–46. No existe en formato abierto y sería una contribución publicable. Es lo que permitiría resolver 1940–42.

## Conclusiones

1. **La razón de sexos de las muertes es un indicador útil de violencia letal donde la violencia pesa en el total de muertes** (más de ~5–10 %). Ahí reduce el error a la mitad. Donde pesa poco, no aporta.
2. **El modelo de estados ocultos es el método recomendado.** Gana o empata en casi todas las pruebas y nunca empeora mucho respecto de interpolar. El estimador directo, más simple, solo sirve con violencia alta y sumando varios años, como en la España de la guerra.
3. **Para la Colombia histórica,** la reconstrucción es buena desde 1985 y razonable en 1946–65 gracias a los anuarios. La razón de sexos añade poco antes de 1966.
4. **Los intervalos son demasiado estrechos al reconstruir hacia atrás,** y hay que ampliarlos antes de publicar.
5. **España muestra que el método funciona en una guerra.** Da cifras coherentes con décadas de investigación histórica, y además estima cuánto faltó en el registro.

## Próximos pasos

- Calibrar los intervalos hacia atrás con estas mismas pruebas.
- Terminar la digitalización por edad en España y usar las edades 15–44 para separar hambre y represión en 1940–42.
- Explorar un modelo con más categorías (homicidios, accidentes y resto) donde haya datos de accidentes, porque los accidentes también matan sobre todo hombres.
- Decidir qué se publica primero: el método y su validación, o la aplicación a España junto con el dataset abierto.
