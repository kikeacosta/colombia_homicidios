# ¿El cociente de sexo de la mortalidad registrada ve las muertes del conflicto que faltan en el registro?

Calibración del modelo de cociente de sexo contra el MSE departamental, 1985-2018. Script `code/52_sexratio_mse_calibration.R`, 2026-11-12.

## Pregunta

El modelo municipal (07, 20) distribuye las muertes violentas registradas de un departamento entre sus municipios con el cociente de sexo de la mortalidad por todas las causas. Para estimar homicidios donde el registro falla, el cociente tendría que llevar información sobre las muertes que el registro no clasificó como violentas. El MSE departamental (51) dice cuántas muertes del conflicto faltan en la componente violenta de cada departamento y año: 117 mil a las edades 15-49, un 18 % de las violentas registradas a esas edades. Si esas muertes entraron al registro bajo otra causa (natural, mal definida, accidente), el cociente de sexo de las muertes **no violentas** registradas sube con ellas. Si nunca entraron, no.

## Panel

Departamento × año, 1985-2018, 986 observaciones, edades 15-49, 29 unidades (la Amazonía agrupada). Variables por 1.000 personas de 15-49: `v_rate` violentas registradas, `m_rate` faltantes del MSE (exceso de homicidios más desapariciones, calibrados a la serie nacional). Cocientes de sexo estandarizados por edad con la población nacional de 2000. Control por el diferencial de completitud por sexo (`log(c_m / c_f)`, del script 50). Efectos aleatorios de departamento y efectos fijos de año.

## Resultados

| modelo | variable | coeficiente | t |
|---|---|---|---|
| A: log cociente no violento | faltantes MSE | −0,022 | −1,1 |
| A | violentas registradas | 0,000 | 0,0 |
| B: log cociente todas las causas | faltantes MSE | −0,017 | −0,8 |
| B | violentas registradas | **0,246** | **17,1** |
| C: muertes masculinas ocultas implícitas | faltantes MSE | −0,019 | −1,4 |

Lectura. Una muerte violenta registrada por 1.000 sube el cociente de todas las causas un 25 %, como corresponde a una muerte que es masculina en el 93 % de los casos. Una muerte del conflicto que falta en la componente violenta no mueve ni el cociente de todas las causas ni el de las no violentas: su coeficiente es cero con un intervalo que excluye cualquier valor por encima de 0,02, es decir, a lo sumo un 10 % de las faltantes podría estar dentro del registro bajo otra causa. La medida directa de muertes masculinas ocultas (modelo C) recupera cero de ellas donde debería recuperar una por una.

Robustez. Sin efectos de año: igual. Antes y después de 1998: igual. Con el total de homicidios del MSE en lugar de las violentas registradas, el cociente sigue al registro (logLik 402 frente a 313) y el MSE no añade nada una vez que el registro está en el modelo. A nivel de las cinco regiones naturales, donde el MSE se estima directamente y el reparto documentado no mete ruido: igual. Las correlaciones dentro de departamento y año entre el cociente no violento y las faltantes son −0,03.

## Conclusión

Las muertes del conflicto que faltan en la componente violenta no están en el registro bajo otra causa: **no están en el registro**. El cociente de sexo de la mortalidad registrada solo ve la violencia registrada. Por tanto, el modelo de cociente de sexo no puede calibrarse para estimar el subregistro de homicidios: no hay señal que calibrar.

Lo que el cociente sí puede hacer, y es lo que ya hace, es distribuir dentro de un departamento un nivel que viene de otra parte, y llenar los huecos de **causa** donde las muertes sí están registradas por sexo pero sin clasificación de causa, como los departamentos-año de los anuarios de 1915-1965 que traen muertes por sexo pero no homicidios. El **nivel** del subregistro tiene que venir de fuentes externas: el MSE donde existe, la completitud por sexo y los pisos de la Policía y de Romero-Meisel en el resto.

Esto cambia el diseño de la serie departamental de homicidios: no es "modelo calibrado con el MSE", sino "registro + MSE o pisos externos" para el nivel, y cociente de sexo solo para repartir y para los huecos de causa.
