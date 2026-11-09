# Comparación de criterios vs Excel manual — ejercicios 2022 y 2023

Resultados de 2022 (arriba) y 2023 (sección final). Para 2023 ver [Ejercicio 2023](#ejercicio-2023-marg-2022--movimientos-sap-2023--marg-2023).

## Ejercicio 2022

Entrada: `inputs/parametros/MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC.xlsx` (hojas por rubro + `PG` / `PG AXI` del Excel manual como referencia). Montos en millones de $. Corrida: `options(revaluo.criterio_unidad_vu = "excel" | "ricardo")`.

- **excel**: replica las fórmulas del Excel manual (Edificios en trimestres; resto en años, año de alta completo).
- **ricardo**: todos los rubros en trimestres salvo Rodados (años), con mes de alta y trimestre de baja (regla 4 de `reglas_negocio.md`, SPEC 4.2).

La referencia son los totales "s/revalúo" de la PG manual: valor residual (VR) y VR reexpresado (VR R).

## Resultado por rubro (diferencia % modelo vs Excel manual)

| Rubro | VR excel | VR R excel | VR ricardo | VR R ricardo |
|---|---|---|---|---|
| Cercos | 0 % | 0 % | 0 % | 0 % |
| Edificios | 0 % | 0 % | 0 % | 0 % |
| Terrenos | −94,1 % (*) | 0 % | −94,1 % (*) | 0 % |
| Eq de Oficina | 0 % | 0 % | +8,29 % | +6,79 % |
| Máquinas y Equipos | 0 % | +0,08 % (**) | +1,84 % | +0,69 % |
| Máquinas Mejoras | 0 % | 0 % | 0 % | 0 % |
| MyU | +0,05 % (**) | +1,69 % (**) | +5,29 % | +5,13 % |
| Rodados | 0 % | 0 % | 0 % | 0 % |
| Terreno Mejoras | 0 % | 0 % | +2,27 % | +0,99 % |
| Software | 0 % | 0 % | +15,00 % | +10,95 % |
| **TOTAL VR R** | | **+0,01 %** | | **+0,34 %** |

(*) El VR histórico de Terrenos en la PG manual (253,0 M) es un valor pegado a mano ("valor residual al inicio"), no sale de la hoja (suma de VO = 14,9 M). Pregunta abierta para Ricardo: cómo se obtiene. Afecta el AXI de Terrenos.

(**) Son 18 activos (5 en MyU, 13 en M&E), todos altas 2006, donde el Excel tiene un ajuste manual pegado (VR reexpresado distinto de VO × coeficiente). Candidatos a cargarse como excepciones.

Lectura: con el criterio `excel` el motor reproduce el Excel manual fila por fila (salvo esos ajustes manuales y el VR histórico de Terrenos). El criterio `ricardo` se aleja del Excel por diseño: mide el efecto de pasar a trimestres (alta/baja prorrateadas), no un error. Rodados no cambia porque queda en años en ambos criterios.

## Errores técnicos corregidos para llegar a este resultado

1. **Filas debajo de "Totales"**: cada hoja del Excel tiene una fila de totales y debajo solo listados informativos (bajas de años anteriores, altas y bajas del mismo año, notas). El motor los leía como activos históricos (ej. Rodados +336 M de VO). Ahora se cortan en la fila de totales (en Terrenos la fila de total no tiene rótulo).
2. **`/ 4` sobre la VU de los rubros no Edificios**: el Excel los trae en años (Rodados 5), no en trimestres. Se reemplazó por `factor_unidad_archivo()` (VU y VUT LY al criterio vigente).
3. **VUT LY fraccionario** en rubros anuales cuando no venía del Excel (`(año−alta−1)+0,25`); ahora usa `MIN(VU, año_ejercicio − año_alta)` como el Excel.
4. **Parseo de fechas**: un texto suelto (encabezado repetido) en la columna "Año a tomar" anulaba todas las fechas de Software, que quedaba sin reexpresar (VR R −34 %). Ahora se parsea celda por celda.
5. **Terrenos sin "Año a tomar"**: usaba la fecha de capitalización (hasta 1963 → coeficiente IPIM de 1e13). Se aplica el piso 01/01/1992 (fecha ajustada, SPEC 4.3).

## Pendientes

- **Amortización del PG** ("Amortización s/revalúo") no es la acumulada: el Excel la arma solo con bienes 2018+ (en los rubros anuales coincide con `amort_hist_2018`; en Edificios, M&E y Terreno Mejoras incluye además años anteriores). No se usó como control.
- **PG interna del motor** (prueba vs revalúo): ya no tiene diferencias de miles de millones, pero no cierra en 0. El residuo es exactamente el término "bienes que agotaron VU LY" (`amort_bs_agotaron_vu_ly`), que en el Excel solo aplica a bienes 2018+.
- **Ajustes manuales** de activos 2006 en MyU / M&E y VR histórico de Terrenos (ver arriba).
- Bajas del ejercicio que el Excel lista debajo de "Totales": ya no se leen del Excel LY (correcto para el ejercicio siguiente); para el ejercicio en curso siguen viniendo de SAP.

## Ejercicio 2023: MARG 2022 + movimientos SAP 2023 = MARG 2023

Es el flujo de producción: base = `MARG - Revaluo AxI 2022...xlsx` (cierre 2022), se suman altas y transferencias 2023 y se restan las bajas de `Altas-bajas-Transf 12-2023 (Tax).xlsx`, con los índices IPC al 31/12/2023 (`inputs/parametros/indices_ipc_2023.xlsx`, extraídos del Excel 2023). Referencia: hojas PG / PG AXI y hojas por activo de `MARG - Revalúo AxI 2023.xlsb` (el `MARG-Revaluo-2023.xlsx` citado en el SPEC no está en el repo; se usó el `.xlsb`). Criterio `excel`, millones de $:

| Rubro | Activos modelo / Excel | VR dif | VR reexp dif | AXI modelo | AXI Excel |
|---|---|---|---|---|---|
| Cercos | 9 | 0 % | 0 % | 0 | 0 |
| Edificios | 4.068 / 4.068 | 0 % | 0 % | 6.375,86 | 6.375,86 |
| Terrenos | 20 | −96,8 % (*) | 0 % | 0 | −238,06 (*) |
| Eq de Oficina | 12.478 / 12.478 | 0 % | 0 % | 151,35 | 151,35 |
| Máquinas y Equipos | 27.166 / 27.166 | 0,00 % | 0,00 % | 10.580,6 | 10.580,6 |
| Máquinas Mejoras | 422 | 0 % | 0 % | 0 | 0 |
| MyU | 5.858 | 0 % | 0 % | 82,42 | 82,42 |
| Rodados | 5.096 | 0 % | 0 % | 3.090,66 | 3.090,66 |
| Terreno Mejoras | 903 / 903 | 0 % | 0 % | 965,03 | 965,03 |
| Software | 384 | 0 % | 0 % | 603,47 | 603,47 |
| **TOTAL** | **56.404** (Excel: 56.404) | −3,14 % (*) | **+0,0003 %** (29.196,9 vs 29.196,8) | 21.849,4 | 21.611,3 (*) |

(*) VR histórico de Terrenos: el Excel 2023 arrastra el valor pegado a mano de 2022 (253 M, menos 7,1 M de bajas) que no sale de su propia hoja (VO = 7,87 M). Toda la diferencia de VR y de AXI total (−238 M) es de ese renglón. Ver pendientes.

Las filas presentes en ambos coinciden una a una (VR, VUT, VU) en Edificios, Eq. de Oficina, Terreno Mejoras y el resto, salvo 12 activos 2006 de Máquinas y Equipos con ajuste manual (0,03 M).

El criterio `ricardo` (trimestres) da, vs el Excel 2023: Eq. de Oficina +18,9 % VR, Máq. y Equipos +2,3 %, MyU +12,9 %, Terreno Mejoras +1,8 %, Software −8,1 %; VR reexp total +0,26 %. Es el efecto de prorratear por trimestre, no un error.

### Qué hubo que cambiar para llegar a esto

1. **Bajas**: un activo con baja en 2023 sale por completo de la base (todas sus filas), de las altas y de las transferencias del ejercicio; la baja queda como fila propia. El Excel 2023 no tiene ninguna fila de un activo dado de baja. Se quitó además el filtro `ret_book_value ≈ 0` del importador (el conteo esperado de 1.717 bajas es el total).
2. **Altas con signo**: las altas conservan el signo de SAP (reversas restan). Antes `abs()` las volvía positivas (72 filas / −62,5 M de VO solo en Eq. de Oficina).
3. **Coeficiente pre-2018**: el Excel 2023 usa `=SI(año<2018; 1; IPC)` (el 2022 usaba IPIM). Opción `revaluo.coef_pre2018`: `"unitario"` (por defecto, 2023) o `"ipim"` (2022).
4. **Índices IPC del ejercicio**: el Excel 2022 llega hasta 31/12/2022; `importar_datos()` usa `indices_ipc_<año>.xlsx` si existe y elige el SAP del año.
5. **VUT LY al partir de la base del año anterior**: el inicio de 2023 es el cierre de 2022. En hojas anuales es la columna "VUT"; en Edificios "VUT" es el flujo (≤4, filas con fórmula) o el cierre pegado (>4), y el Excel tiene valores pegados por antigüedad real (p. ej. 200 trimestres en activos "1992"), por lo que no se recalcula por fórmula.
6. `_targets.R`: usa el Excel del año si existe, si no el del año anterior, y pasa el año a `importar_datos()`.

### Alineación con `15_proceso_manual_revaluo.md`

- Alta y baja en el mismo ejercicio: el documento dice que el neto es cero en la mayoría de los casos (la excepción, alta en febrero y baja en diciembre, deja una diferencia por coeficientes distintos). El Excel 2023 los saca por completo (10 altas de $ 0,01 en M&E, 21 en Eq. de Oficina y 2 altas + 2 transferencias en Edificios) y el motor hace lo mismo.
- Altas con fecha de posting (no la de capitalización original) y bajas con coeficiente punta a punta (`IPC - VR Bajas`): ya era así.
- **Bajas parciales**: el documento pide prorratear. En SAP 2023 hay 5 bajas parciales (todas en Máquinas y Equipos, ~3,0 M de VO restante) y el Excel igualmente saca el activo completo. El motor sigue al Excel; confirmar con Ricardo.

### Pendientes 2023

- VR histórico de Terrenos (253 M pegado a mano en la PG) y su AXI (−238 M). Parece venir del revalúo técnico del perito (`docs/15`, etapas 2-3), no de la lista de activos: requiere esa valuación como insumo.
- Las 5 bajas parciales de arriba.
- Bajas con `ret_book_value ≠ 0` (partes no totalmente depreciadas): hoy se tratan igual que las demás, como en el Excel.
- 69 bajas SAP sin base en el Excel 2022 (altas del año o activos fuera del inventario).

## Corrida de 2023 desde la app (9/11)

Se probó en la UI con el Excel LY 2022, el SAP 2023 y `MARG_Revaluo_AXI_2023.xlsx` como referencia. Los errores del primer intento tenían estas causas (ya corregidas):

| Síntoma en la UI | Causa | Corrección |
|---|---|---|
| Altas/Bajas/Transf SAP 1464 / 3880 / 1981 | La app no pasaba el año a `importar_datos` y tomaba el primer `.xlsx` de `inputs/SAP/` por orden alfabético: el SAP **2022** (2023 tiene 3339 / 1662 / 1583) | Se elige el SAP del ejercicio y se frena si el archivo es de otro año; el Paso 1 muestra el archivo usado |
| IPC: 1826 registros | La tabla del Excel 2022 termina el 31/12/2022: las altas 2023 tomaban coeficiente 1 sin aviso | Se frena si el IPC no llega al cierre del ejercicio; se lee `indices_ipc_2023.xlsx` (2191 registros) |
| PG de amortización con diferencias de −1 a −120 M | Se cuadraba la amortización **acumulada**, y el término "bienes que agotaron VU" es de la PG en base **flujo** del Excel | PG en base flujo (inicio = "Amort. Histórica" del LY); coincide fila por fila con la PG del Excel 2023 y cierra en 0 |
| Conteos SAP ERROR | Se comparaban las filas **ya filtradas por rubro** contra el total del archivo (4873/1717/1738 es el total del SAP 2023) | Se comparan filas de detalle sin filtrar; conteos esperados por año |
| "Negativos" ERROR en miles de activos | Marcaba los VO negativos (reversas) que el Excel del estudio también tiene, y ruido de punto flotante (−4e-10) | Solo se marca el negativo cuyo VO no es negativo, con tolerancia de 0,01 |
| Comparación contra "Price" muy distinta | `MARG_Revaluo_AXI_2023.xlsx` no es el Excel del estudio: es una exportación de una corrida anterior del modelo (hojas `PG`/`PG AXI` con las columnas propias de la app) | Referencia correcta: `inputs/parametros/Excel manual 2023 - PG y PG AXI.xlsx` (hojas PG y PG AXI del `.xlsb` del estudio, solo valores). `leer_pg_real` busca las filas por etiqueta |

Resultado tras las correcciones (criterio `excel`): 38 validaciones OK, 3 advertencias (Estructuras y caños, sin datos) y 2 errores, ambos de **Terrenos** contra la referencia (VR histórico y AXI, ver pendientes).

## Replicar el trabajo manual: segunda pasada (9/11)

Con el LY "PARA PROBAR", el SAP 2023 y la referencia correcta (`Excel manual 2023 - PG y PG AXI.xlsx`), el modelo replica la PG del Excel 2023 en todas las filas y rubros salvo Terrenos:

| Fila de la PG del Excel | Resultado del modelo |
|---|---|
| Amortización s/revalúo y todas las filas de la PG de amortización (inicio, altas, transferencias, bajas, agotaron VU, irregular) | Igual, diferencia 0 |
| Valor residual s/revalúo | Igual en todos los rubros menos Terrenos |
| Valor residual de las bajas | Igual: Edificios −11,23 M, Eq. de Oficina −1,25 M, Máquinas y Equipos −1,29 M, Rodados −0,24 M (antes Edificios −15,28 y Máquinas y Equipos −8,09) |
| Amortización s/revalúo de la PG AXI (reexpresada) | Igual al centavo: Edificios 166,98 M, Eq. de Oficina 479,09 M, Máquinas y Equipos 2.111,95 M |
| AXI por rubro | Igual: Edificios 6.375,86 M, Eq. de Oficina 151,35 M, Máquinas y Equipos 10.580,60 M, Rodados 3.090,66 M. Total 21.849,4 M contra 21.611,3 M del Excel: la diferencia, 238,06 M, es solo Terrenos |

Qué se corrigió para llegar a esto:

1. **Bajas desde la base LY.** El Excel arma el bloque "Bajas 2023" de cada hoja con los valores **congelados del LY** de cada fila (en Edificios 26 filas; el SAP traía 43 líneas con VO de retiro). Ahora la baja toma las filas de la base LY y el SAP solo dice qué activos y cuándo. Verificado fila por fila en Eq. de Oficina contra el bloque del Excel.
2. **PG de AXI sin las bajas del ejercicio**, como "s/revalúo". Incluirlas sumaba su AXI: Edificios +2,07 M y Máquinas y Equipos +6,9 M.
3. **Amortización reexpresada** (`amort_ejercicio_reexp`) = amortización del ejercicio × coeficiente de cada bien, también para los anteriores a 2018. `amort_hist_reexp` (solo 2018+) no coincide con la PG para Edificios, Máquinas y Equipos, Terreno Mejoras y Máquinas Mejoras.
4. **Comparación externa en tres niveles**: OK si replica (≤ 0,1 %), ADVERTENCIA si está dentro del 20 % pero no replica, ERROR si lo supera. Con solo el 20 % se daba por bueno el +2 M de AXI.
5. **Bajas no identificadas** (regla 2): 85 líneas SAP de activos que no están en la base ni son altas del ejercicio (78 en Máquinas y Equipos) no se calculan y se informan como advertencia.

Resultado de las validaciones: 51 OK, 6 advertencias (4 por bajas no identificadas y 2 por los totales de VR y AXI, que arrastran Terrenos) y 2 errores, ambos de Terrenos.

Sobre el año de baja de Edificios: el Excel amortiza 4 trimestres en el bloque de bajas y el código de Ricardo hasta el trimestre de la baja. No cambia ningún valor de la PG (el VR de bajas es el congelado a LY y las bajas no entran en "s/revalúo"), así que se dejó la regla de Ricardo sin tocar.
