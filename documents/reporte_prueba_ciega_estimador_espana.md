# Prueba ciega del estimador de España

*23 de noviembre de 2026 · script `code/82_intl_blind_test_spain_estimator.R`*

## Qué se hizo

Apliqué el estimador de España (script 80) en cinco países donde sí se conoce la causa de muerte. El procedimiento fue el mismo que en España:

1. De un periodo base más tranquilo saqué la razón de sexos de todas las muertes de cada unidad y su tendencia.
2. En los años siguientes estimé las muertes violentas con H = (D_M − ρD_F)/(π − ρ(1−π)), con π = 0,95, y el exceso no violento como exceso − H.
3. Comparé con las muertes violentas observadas por encima de la proporción del periodo base.

## Resultados

Muertes violentas por encima del nivel base (miles), estimadas solo con el sexo de los muertos, frente a lo observado:

| Caso | Periodo | Edades | Estimado | Observado | Error total | Correlación entre unidades |
|---|---|---|---|---|---|---|
| Ecuador (base 2015–19) | 2022–24, salto de violencia | todas | 15,5 | 15,5 | 0 % | 1,00 |
| | | 15–44 | 15,1 | 13,2 | +14 % | 1,00 |
| | 2020–21, COVID | todas | 16,4 | 0,3 | **falla** | 0,65 |
| | | 15–44 | 1,3 | 1,1 | +20 % | 0,96 |
| México (base 2000–06) | 2008–12, guerra contra el narco | todas | 41,4 | 54,9 | −25 % | 0,94 |
| | | 15–44 | 48,6 | 48,5 | 0 % | 0,96 |
| | 2020–21, COVID | todas | 148,1 | 22,9 | **falla** | 0,02 |
| | | 15–44 | 21,9 | 27,0 | −19 % | 0,60 |
| Colombia (base 1979–83) | 1985–93 | todas | 136,2 | 120,8 | +13 % | 1,00 |
| | 1998–2002 | todas | 100,4 | 98,4 | +2 % | 0,99 |
| Brasil (base 1996–2000) | 2010–17 | todas | −523 | −5 | **falla** | 0,95 |
| | | 15–44 | 111,4 | 114,9 | −3 % | 0,97 |
| EE. UU. (base 1999–2004) | 2015–19 | todas / 15–44 | 592 / 16 | −7 / 3 | **falla** | — |

![prueba ciega](../figures/09_international/intl_blind_test_spain_estimator.png)

## Qué aprendimos

1. **Funciona bien cuando la violencia cambia de golpe y el horizonte es corto.** En Ecuador 2022–24 acierta exactamente. En México 2008–12, en las edades 15–44, también. En Colombia el error es de +2 a +13 %, y las unidades quedan bien ordenadas (correlación 0,99–1,00). La división del exceso en violento y no violento también acierta en esos casos.
2. **Falla cuando la mortalidad no violenta cambia su composición por sexo,** porque los hombres de más se leen como violencia:
   - **COVID, 2020–21:** mató más hombres. La razón de sexos de las muertes no violentas subió entre 7 y 18 %, y el estimador atribuye a violencia entre una cuarta y una tercera parte del exceso. En Ecuador 2020, por ejemplo, salen 11.000 "violentas" de un exceso de 39.000.
   - **Horizontes largos:** en Brasil, entre 15 y 20 años, el envejecimiento baja la razón de sexos no violenta entre 7 y 11 %. En EE. UU. la crisis de opioides la cambia, y además la violencia pesa demasiado poco.
3. **Las edades 15–44 son mucho más robustas.** Con COVID, el error baja a +20 % (Ecuador) y −19 % (México), y Brasil 15–44 acierta (−3 %). EE. UU. sigue sin funcionar porque la violencia es muy pequeña frente al resto de la mortalidad.
4. **El π observado es de 0,87–0,93, menor que el 0,95 usado.** En estos países los homicidios incluyen más mujeres que una guerra. Usar 0,95 cuando el valor real es ~0,89 subestima H en ~12 %, lo que explica parte del −25 % de México en todas las edades.

## Qué implica para España

- **El horizonte es favorable:** de 1 a 11 años después de la base 1926–35, como en los casos donde funciona.
- **1936–39** se parece a Ecuador 2022–24 y a México 2008–12, con un salto brusco de violencia. Ahí la cifra es confiable.
- **1940–42** es el punto débil. Si el hambre y el tifus mataron proporcionalmente más hombres, como hizo el COVID, parte de ese exceso se estaría contando como violencia. La comparación con las provincias lejos del frente (Galicia, Canarias) sugiere que el efecto fue menor que el del COVID, pero no es concluyente.
- **La prueba decisiva** es repetir el cálculo en las edades 15–44, que en esta prueba resiste bien un shock no violento como el COVID. Esto refuerza la necesidad de terminar la lectura de las tablas por edad.
