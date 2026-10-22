# Corridas Ejercicio 2023 — Resultados Completos

## 1. Aclaración sobre la corrida anterior

La corrida de la sesión pasada fue **ejercicio 2022** (anio=2022, Excel 2022 como LY). La "PG diff" reportada era el **control interno del R** (diferencia s/prueba vs s/revalúo), NO contra el estudio. No se comparó contra la PG del estudio porque `leer_pg_real()` no pudo parsear el formato de la hoja PG del Excel 2022.

## 2. Ejercicio 2023 — Datos cargados

| Fuente | Registros |
|---|---|
| **LY** (Excel KPMG 2022) | 10 rubros, inventario completo |
| **Altas SAP 2023** | 3.339 |
| **Bajas SAP 2023** | 1.373 |
| **Transferencias SAP 2023** | 1.583 |

Inventario tras rollforward:

| Rubro | Activos | Movimientos 2023 |
|---|---|---|
| Cercos | 9 | 0 |
| Edificios | 4.818 | 532 |
| Terrenos | 25 | 0 |
| Eq de Oficina | 18.006 | 858 |
| Maquinas y Equipos | 31.634 | 3.112 |
| Maquinas Mejoras | 429 | 55 |
| MyU | 7.957 | 1.374 |
| Rodados | 7.110 | 219 |
| Terreno Mejoras | 1.048 | 127 |
| Software | 571 | 18 |
| **Total** | **71.607** | **6.295** |

## 3. Tabla por paso — Totales vs estudio 2023

Referencia del estudio: amort $1.179.524.957 | VR $7.585.493.061 | VR_R $29.179.928.610 | AXI $21.594.435.551

| Paso | Amort acum | Dif % | VR | Dif % | VR reexp | Dif % | AXI | PG int |
|---|---|---|---|---|---|---|---|---|
| **0-BASELINE** | 6.058M | +414% | 6.518M | −14% | 33.744M | +16% | 27.197M | 8.546M |
| **1-V03** | 3.753M | +218% | 8.823M | +16% | 40.543M | +39% | 31.691M | **222M** |
| **2-B01** | 3.753M | +218% | 8.823M | +16% | **14.094M** | **−52%** | **5.242M** | 222M |
| **3-V08** | 3.753M | +218% | 8.823M | +16% | 14.111M | −52% | 5.259M | 222M |
| **4-B04** | 3.715M | +215% | 8.862M | +17% | 14.120M | −52% | 5.256M | 222M |
| 5-V05 | = | = | = | = | = | = | = | = |
| 6-B02 | = | = | = | = | = | = | = | = |
| **7-V09** | 3.715M | +215% | 8.862M | +17% | 14.120M | −52% | 5.256M | 222M |

*(M = millones de pesos)*

### Impacto de cada corrección (delta vs paso anterior)

| Corrección | Δ Amort | Δ VR | Δ VR_R | Δ AXI |
|---|---|---|---|---|
| **V-03** (VU sin /4) | −2.305M | +2.305M | +6.799M | +4.494M |
| **B-01** (coef=1 pre-2018) | 0 | 0 | **−26.449M** | **−26.449M** |
| **V-08** (fecha alta bajas) | 0 | 0 | +17M | +17M |
| **B-04** (VUT entero) | −39M | +39M | +10M | −3M |
| V-05, B-02 | 0 | 0 | 0 | 0 |
| **V-09** (trim anterior) | 0 | 0 | −13K | 0 |

## 4. Diferencia residual — diagnóstico

### El R tiene amort +215% vs el estudio. ¿Por qué?

**Causa principal: las tablas IPC del Excel 2022 no cubren diciembre 2023.** El archivo `MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC.xlsx` fue generado en abril 2023 con el IPC hasta ~marzo 2023. Para el ejercicio 2023, los coeficientes deberían usar IPC cierre diciembre 2023 = 3.533,19 (valor del estudio). El R usa coeficientes parciales (IPC ~marzo 2023 / IPC alta), que son ~3× menores.

**Causa secundaria: el R recalcula la amortización acumulada desde cero** como `cuota × VUT`, en vez de heredar la amort_acum del LY y sumarle la del ejercicio. Para activos con VU no estándar (VU=13, VU=21 en Maquinas; VU=20 en Cercos), el recálculo diverge del valor que trae el estudio.

**Causa terciaria (Terrenos −88%):** El Excel 2022 trae 25 terrenos con VO total ~$30M. El estudio 2023 muestra VR de terrenos = $245M. La diferencia ($215M) corresponde a terrenos que no están en la base LY 2022 (posiblemente incorporados vía transferencias o ajustes que el R no procesó).

### Rubros con mayor diferencia y activos ejemplo

**Maquinas y Equipos** (amort +314%): activos con VU no estándar. Ejemplo: activo 267 tiene VU=21 años en el Excel vs el parámetro PARAMETROS_RUBROS que dice 10. El R usa 21 del Excel (correcto post V-03), pero el VUT_LY del Excel puede haber sido calculado con VU=10 en años anteriores.

**Eq de Oficina** (amort +212%): muchos activos con VU=10 (primera docena del LY) cuando el rubro tiene VU=3. Son activos migrados de otro rubro. El R usa la VU del Excel, pero la cuota y amort se recalculan sin considerar la historia.

**Software** (amort +142%): el Excel 2022 trae 571 activos. La amort recalculada ($551M) excede el estudio ($228M) porque el R computa VUT como si todos los activos tuvieran historia uniforme, sin ajuste por la migración trimestre→año.

### Para cerrar la comparación se necesita:
1. **Usar el Excel 2023 como LY** (tiene IPC a dic 2023 y el inventario completo)
2. **Agregar hoja IPIM ficticia** al Excel 2023 (o que el R no la requiera con coef=1)
3. **No recalcular amort_acum del LY** — tomarla como dato y solo sumar la del ejercicio

## 5. Bajas de Edificios 2023

### Bajas con VU activa

Se encontraron **14 sub-líneas** de bajas de Edificios con VU no agotada. Son transferencias históricas de bienes dados de baja en 2023:

| Activo | Alta | VO ($) | VU | VUT_LY | VUT baja | Δ trim | Cuota/trim |
|---|---|---|---|---|---|---|---|
| 405482001247 | 2018 | 12 | 200 | 13 | 4 | −9 | 183 |
| 405482001215 | 2008 | 2 | 200 | 56 | 4 | −52 | 140 |
| 405482001219 | 2008 | 2 | 200 | 56 | 4 | −52 | 140 |
| 405482001245 | 1992 | 1 | 200 | 120 | 4 | −116 | 76 |
| 405482001246 | 1992 | 1 | 200 | 120 | 4 | −116 | 76 |
| 405482001352 | 2021 | 2 | 200 | 4 | 4 | 0 | 192 |

**Nota sobre los VUT negativos:** El VUT de la baja es menor que el VUT_LY. Esto indica que la sección "Bajas" del estudio **congela los valores al momento de la baja** (ej: VUT=4 trimestres devengados hasta el trimestre de baja), no al cierre del año. El estudio expone las bajas con sus saldos de retiro, no con los de cierre.

### Impacto por criterio (total de las 14 sub-líneas)

| Criterio | Amort del ejercicio ($) | Fuente |
|---|---|---|
| Estudio (año completo, 4 trim) | −101.295 | Observado en los datos |
| R actual (trimestre baja inclusive) | −101.295 | Igual al estudio para datos del LY |
| **Art. 87 LIG** (trimestre anterior) | **0** | Todos los delta son ≤ 0, la amort del año queda en 0 |

**La diferencia entre el estudio y la norma es $101.295** en total para estas 14 sub-líneas. Es marginal vs el total de amort de Edificios ($39.7M).

### Doble cómputo (art. 63 LIG)

Para el activo 405482001247 (alta 2018, VO=$12, cuota=$183/trim):
- Amort acum al cierre (estudio): 183 × 4 = $732
- Costo computable: VO actualizado − amort_acum → si la amort del año se deduce como gasto Y se resta del costo computable, no hay doble cómputo (una sola deducción)
- Si la amort del año se deduce como gasto pero NO se resta del costo computable, el contribuyente deduce dos veces

**Con los datos disponibles no se puede confirmar doble cómputo** porque el estudio no expone el cálculo del costo computable de las bajas. Requiere verificar con Impuestos si la fila "Bajas VO" de la PG ya incluye el ajuste.

## 6. Pre-1992 en Edificios

### Resultado

Solo **1 activo** en Edificios tiene `anio_alta < 1992`:

| Activo | Alta original | Año a tomar | VU | VUT_LY | VUT | VR |
|---|---|---|---|---|---|---|
| 405482001243 | 1959 | 1959 | 200 | 200 | 0 | $0 |

Este activo tiene **VU agotada** (200 trimestres). Su VR es $0, así que no tiene impacto.

Sin embargo, **muchos activos de Edificios tienen `anio_alta = 1992`** (observado en los encabezados: "Con respecto a los bienes con fecha de alta menor a 12/1992, ya se encontraban reexpresados a Marzo de 1992. Se tomo como año Base para realizar el calculo de AXI. Se actualizan a partir de Abril 1992").

Esto confirma que **el estudio usa la fecha 01/01/1992 tanto para el coeficiente como para la VUT de Edificios** de bienes pre-1992. El R actual no implementa este corte automático (B-02), pero no tiene efecto porque:
1. Solo hay 1 activo pre-1992 y tiene VU agotada
2. Los demás bienes pre-1992 ya fueron ajustados a `anio_alta=1992` en el propio Excel del estudio

**Para los demás rubros (Cercos):** El encabezado dice "Los bienes del 2 al 8 ya se encontraban actualizados hasta marzo de 1992. Se toma como base ese año". Son 7 activos con `anio_alta=1992` y VU=50 años. VUT_LY=47 o 50 (varios agotados). VR total de Cercos = $5.130.
