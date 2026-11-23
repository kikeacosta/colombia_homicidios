# España 1936–1946: muertes violentas y no violentas estimadas con la razón de sexos, y prueba ciega del método

*24 de noviembre de 2026 · scripts `code/80`, `81` y `82` (`intl_*`)*

## Resumen

- Con solo las muertes registradas por provincia, sexo y año (INE, 1926–1946), el exceso de muertes de 1936–1942 suma **unas 590.000**. De ellas, **unas 290.000 son violentas** (exceso de muertes de hombres) y **unas 300.000 no violentas** (hambre, enfermedad, refugiados).
- Las cifras coinciden con la literatura: el exceso total con Salas, Díez Nicolás y Ortega y Silvestre, y la violencia registrada por provincia con Salas (correlación 0,93–0,94).
- En una prueba ciega en cinco países con causa de muerte conocida, el método acierta cuando la violencia sube de golpe a pocos años de la base. Falla cuando la mortalidad no violenta cambia su composición por sexo, como con el COVID o con el envejecimiento a lo largo de muchos años. Por eso 1936–39 es más confiable que 1940–42.

## 1. España: datos y método

- **Datos:** defunciones registradas por provincia y sexo, 1926–1946. Las transcribí de los anuarios del INE con dos verificaciones: hombres + mujeres = total, y suma de provincias = total impreso. Son defunciones por año de registro.
- **Muertes esperadas:** el nivel de 1926–35 de cada provincia proyectado con la tendencia nacional (−1,16 % anual). El exceso es registradas − esperadas.
- **Muertes violentas (H):** con ρ, la razón de sexos de 1926–35 de cada provincia, y π = 0,95, la proporción de hombres entre las víctimas:
  - H = (hombres − ρ·mujeres) / (π − ρ(1−π))
  - Los hombres que mueren por encima de lo que "corresponde" según las mujeres se atribuyen a la violencia.
- **Exceso no violento:** lo que queda, exceso − H. H no depende de las muertes esperadas; la parte no violenta sí.

## 2. Estimaciones

| Período | Exceso total | Violentas (H), π = 0,95 | Rango de H | H con π = 0,90 | No violentas |
|---|---|---|---|---|---|
| 1936–39 | 360.000 | 193.000 | 147.000–238.000 | 219.000 | 166.000 (151.000*) |
| 1940–42 | 228.000 | 95.000 | 61.000–127.000 | 107.000 | 133.000 (116.000*) |
| 1943–46 | 6.000 | 40.000 | 3.000–76.000 | 45.000 | −35.000 |

*Con la tendencia propia de cada provincia en lugar de la nacional.

- El rango de H refleja cuánto varía la razón de sexos entre años de paz. Es conservador, porque suma las provincias como si sus errores fueran iguales.
- **La línea base pasa la prueba:** estimada solo con años de paz, deja el exceso de 1943–46 prácticamente en cero sin forzarlo.

**Por provincia:**
- **1936–39:**
  - Mayormente violento: Oviedo, Zaragoza, Vizcaya, Málaga y Badajoz (70–92 % del exceso).
  - Mayormente no violento: Jaén, Almería, Murcia y Alicante (10–26 % violento). Coincide con la retaguardia republicana, los refugiados y la escasez.
- **1940–42:** el mayor exceso está en Badajoz, Sevilla, Madrid, Córdoba y Jaén. Es mayormente no violento, salvo en Madrid y Barcelona.

![División del exceso](../figures/09_international/spain_excess_split.png)

## 3. Comparación con otras estimaciones

| Medida | Otra estimación | Método de esa estimación | Nuestra cifra |
|---|---|---|---|
| Exceso total 1936–39 | Ortega y Silvestre (2005): ~346.000; Salas (1977): 343.500; Díez Nicolás (1985): 345.000 | Ortega y Silvestre: tendencia 1926–35 por provincia y sexo; Salas: muertes registradas frente a un nivel de preguerra; Díez Nicolás: citado por Ortega y Silvestre | 360.000 |
| Exceso total 1936–42 | Ortega y Silvestre: ~540.000; Salas: 567.000; Díez Nicolás: 559.000 | ídem | 588.000 |
| Violencia registrada por provincia, 1936–39 | Salas: muertes en operaciones militares + ejecuciones en zona nacional, 194.700 | causa de muerte registrada, con las inscripciones tardías reasignadas a la guerra | 193.500; correlación entre provincias 0,93 (0,94 sumando hasta 1946) |
| Violencia registrada total | Salas: 296.944 (incluye 72.344 ejecuciones en zona republicana, maquis y 25.500 extranjeros) | ídem | 288.500 (registradas hasta 1942); 328.700 (hasta 1946) |
| Represión documentada | Espinosa (2008), 20 provincias con estudio completo; Espinosa y Ledesma (2012): 130.199 franquista + 49.272 republicana | víctimas con nombre, desde archivos | correlación entre provincias 0,81 (H es más amplia: incluye el frente) |
| No violentas 1936–42 | Implícito en Salas: 567.000 − ~271.000 violentas de españoles ≈ 296.000 | resta | 299.000 |
| Hambre 1939–42 | Del Arco Blanco: ~200.000 | citado en entrevista; método no revisado | 133.000 en 1940–42, más parte de 58.000 en 1939 |
| Exceso de hombres y mujeres por año | Ortega y Silvestre, pasado por nuestra fórmula | — | coincide año a año (mismos datos del INE, no es una prueba independiente) |

En las provincias donde quedamos por encima de Salas (Albacete, Cáceres, Cuenca, Lugo, Jaén), probablemente pesan las ejecuciones de la zona republicana, cuya tabla provincial de Salas no se consiguió, y el año de registro.

![Comparación con Salas y Ortega y Silvestre](../figures/09_international/spain_literature_comparison.png)

## 4. Prueba ciega del método donde se conoce la causa

Apliqué el estimador igual que en España: periodo base para ρ y la tendencia, π = 0,95 y solo el sexo de los muertos. Luego lo comparé con las muertes violentas observadas por encima de la proporción del periodo base.

| Caso | Periodo | Edades | Estimado (miles) | Observado (miles) | Error total | Correlación entre unidades |
|---|---|---|---|---|---|---|
| Ecuador (base 2015–19) | 2022–24, salto de violencia | todas | 15,5 | 15,5 | 0 % | 1,00 |
| | | 15–44 | 15,1 | 13,2 | +14 % | 1,00 |
| | 2020–21, COVID | todas | 16,4 | 0,3 | **falla** | 0,65 |
| | | 15–44 | 1,3 | 1,1 | +20 % | 0,96 |
| México (base 2000–06) | 2008–12, guerra contra el narco | todas | 41,4 | 54,9 | −25 % | 0,94 |
| | | 15–44 | 48,6 | 48,5 | 0 % | 0,96 |
| | 2020–21, COVID | todas | 148,1 | 22,9 | **falla** | 0,02 |
| | | 15–44 | 21,9 | 27,0 | −19 % | 0,60 |
| Colombia (base 1979–83) | 1985–93 | todas | 132,1 | 121,0 | +9 % | 1,00 |
| | | 15–44 | 126,4 | 104,0 | +22 % | 1,00 |
| | 1998–2002 | todas | 97,9 | 98,6 | −1 % | 0,99 |
| | | 15–44 | 98,9 | 82,9 | +19 % | 0,99 |
| Brasil (base 1996–2000) | 2010–17 | todas | −523 | −5 | **falla** | 0,95 |
| | | 15–44 | 111,4 | 114,9 | −3 % | 0,97 |
| EE. UU. (base 1999–2004) | 2015–19 | todas / 15–44 | 592 / 16 | −7 / 3 | **falla** | — |

![Prueba ciega](../figures/09_international/intl_blind_test_spain_estimator.png)

**Qué aprendimos:**

1. **Acierta cuando la violencia cambia de golpe y el horizonte es corto.** Ecuador 2022–24, México 2008–12 en 15–44 y Colombia en todas las edades dan errores de 0–9 %, con las unidades bien ordenadas. Donde se pudo evaluar, la división del exceso también acierta.
2. **Falla cuando la mortalidad no violenta cambia su composición por sexo.** Esos hombres de más se leen como violencia:
   - el COVID mató más hombres;
   - en horizontes de 15–20 años pesan el envejecimiento (Brasil) y los opioides (EE. UU.);
   - en EE. UU., además, la violencia pesa demasiado poco.
3. **Las edades 15–44 suelen resistir mejor,** como con el COVID y en Brasil, pero no siempre. En Colombia 15–44 sobreestima un 20 %, porque la razón de sexos de las muertes no violentas de 15–44 subió un 20–30 % entre 1985 y 2019. Mi hipótesis es que se debe a la caída de la mortalidad de mujeres jóvenes (materna) y a los accidentes de hombres, pero no lo he verificado.
4. **El π observado es 0,87–0,93, no 0,95.** Usar 0,95 cuando el valor real es ~0,89 subestima H en ~12 %. En una guerra, con frente y represión, π debería ser más alto que en la violencia criminal, pero no lo hemos medido para España.
5. **En Colombia no se pudo evaluar la parte no violenta,** porque el registro creció muy rápido en 1979–83, el periodo base.

**Qué implica para España:**
- **1936–39** se parece a los casos donde el método funciona: un salto brusco de violencia a 1–4 años de la base. Ahí la estimación es confiable, dentro del rango de π.
- **1940–42** es el punto débil. Si el hambre y el tifus mataron proporcionalmente más hombres, como el COVID, parte de ese exceso se estaría contando como violencia. Las provincias lejos del frente (Galicia, Canarias) sugieren que el efecto fue pequeño, pero no es concluyente.

## 5. Qué faltaría para mejorar

1. **Edades 15–44 por provincia.** El lector de dígitos está en marcha y verifica sin ayuda el 58–92 % de las columnas, según el año. Serviría para poner a prueba el supuesto en 1940–42, porque el hambre mata sobre todo a niños y viejos. Con la cautela que deja Colombia: hay que revisar que la razón de sexos de 15–44 no se mueva por otras causas.
2. **Causas de muerte registradas 1936–42 por provincia y sexo** (la transcripción está pausada). Permitirían:
   - medir π directamente;
   - validar H provincia por provincia;
   - anclar el modelo de espacio de estados en su versión logit (CoDA), que podría estimar la deriva de la razón de sexos no violenta en vez de suponerla fija.
3. **Bombardeos:** cifras publicadas de muertos por provincia y año (por ejemplo, Solé i Sabaté y Villarroya para Cataluña). Matan a ambos sexos, así que hoy quedan en el exceso no violento; con esas cifras se podrían pasar a la parte violenta.
4. **Desplazados y refugiados por provincia, y exilio de 1939.** Hoy inflan el exceso no violento de las provincias que reciben gente (Jaén, Almería, Murcia, Alicante) y lo bajan en las de origen.
5. **Año de defunción frente a año de registro:** estimar las inscripciones tardías (1939–41, 1943–44) para comparar con Salas en la misma base.
6. **π español:** más estudios locales con víctimas por sexo, además de Talavera.
7. **Incertidumbre conjunta** de ρ, π y la tendencia, en lugar de rangos separados.
8. **Búsqueda bibliográfica** sobre si este estimador ya se propuso: demografía de conflictos, demografía histórica y métodos con la razón de sexos.
