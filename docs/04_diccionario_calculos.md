# T0.4 — Diccionario de Cálculos

> **Actualización Fase 0.5 (2026-10-21):** Se agrega fila "Norma" a las fichas relevantes, según la Ley de Ganancias t.o. 2019 y su decreto reglamentario. Se corrige la clasificación de B-06. Se identifica B-04 como error (no diferencia de criterio).

---

### N° de Activo Fijo (sigla: NAF)

| Campo | Detalle |
|---|---|
| Definición | Identificador único del activo. Combina número de activo + subnúmero en SAP |
| Tipo | Dato de entrada |
| Origen del dato | **Inventario LY:** columna detectada por regex `activo.?fijo\|n.*activo` (`02_limpiar_datos.R:14`). **Movimientos SAP:** columna `asset` post `clean_names()` (`01_importar_datos.R:300,326,356`) |
| Fórmula (notación) | N/A (dato directo) |
| Fórmula explicada | Se normaliza con `normalizar_clave_activo()` que aplica `str_trim()` (`utils.R:68`). Se usa como texto, no como numérico |
| Unidad | Texto |
| Redondeo | No aplica |
| Casos borde | Filas de totales ("Total", "Grand Total", "Subtotales") se excluyen vía `es_fila_detalle_sap()` (`utils.R:112-117`). Activos con prefijo "AS" (IFRS 16) se excluyen en dos puntos: lectura SAP (`01_importar_datos.R:319`) y limpieza LY (`02_limpiar_datos.R:141-147`) |
| Ubicación en R | `02_limpiar_datos.R:49-53` / `01_importar_datos.R:309` / `utils.R:67-69` |
| Equivalente en el modelo del estudio | Columna "N° Activo Fijo" en cada hoja de categoría |
| Coincide con la referencia | Sí — misma clave |
| Ejemplo numérico | `"000000012345"` después del trim |

---

### Clase SAP (sigla: CLS)

| Campo | Detalle |
|---|---|
| Definición | Código de clasificación del activo en SAP que determina el rubro contable |
| Tipo | Dato de entrada |
| Origen del dato | Columna `class` del Excel SAP (`01_importar_datos.R:305,331,361`). En el inventario LY no viene como columna separada; el rubro ya está determinado por la hoja |
| Fórmula (notación) | N/A |
| Fórmula explicada | Se mapea a rubro mediante la tabla `CLASS_A_RUBRO` con `dplyr::recode()`. Clases no mapeadas quedan como `NA` y se filtran |
| Unidad | Texto |
| Redondeo | No aplica |
| Casos borde | Clase `600LA` ("Obras en curso") se mapea pero luego se excluye explícitamente (`01_importar_datos.R:318`). Clases no incluidas en `CLASS_A_RUBRO` (ej: 9050, 9150, 9250, 9350, 495LA, 9750) quedan con `rubro = NA` y se filtran implícitamente por `!is.na(rubro)` |
| Ubicación en R | `01_importar_datos.R:48-65` (tabla), `01_importar_datos.R:313` (recode) |
| Equivalente en el modelo del estudio | Clasificación por hoja del Excel |
| Coincide con la referencia | Sí — el mapeo cubre las mismas 16 clases. Las exclusiones son equivalentes (implícitas vs explícitas) |
| Ejemplo numérico | `"210LA"` → Edificios |

---

### Rubro (sigla: RBR)

| Campo | Detalle |
|---|---|
| Definición | Categoría contable del activo, que determina la vida útil y la unidad de amortización |
| Tipo | Derivado |
| Origen del dato | **Inventario LY:** nombre de la hoja del Excel (`01_importar_datos.R:125`). **Movimientos SAP:** lookup de la clase SAP en `CLASS_A_RUBRO` (`01_importar_datos.R:313`) |
| Fórmula (notación) | `RBR = CLASS_A_RUBRO[CLS]` |
| Fórmula explicada | Para datos del LY, el rubro es el nombre de la hoja. Para movimientos SAP, se obtiene por lookup. Existen 11 rubros activos |
| Unidad | Texto |
| Redondeo | No aplica |
| Casos borde | Rubros "Cercos" y "Estructuras y caños" están definidos en parámetros pero no tienen clases SAP asignadas (están vacíos en `PARAMETROS_RUBROS`). Solo aparecen si existen como hojas en el Excel LY |
| Ubicación en R | `01_importar_datos.R:48-65`, `01_importar_datos.R:125`, `utils.R:27-39` |
| Equivalente en el modelo del estudio | Nombre de cada hoja (Edificios, Terrenos, etc.) |
| Coincide con la referencia | Sí |
| Ejemplo numérico | Clase `360LA` → Rubro "Rodados" |

---

### Fecha de Alta (sigla: FA)

| Campo | Detalle |
|---|---|
| Definición | Fecha de incorporación del activo. Se usa para calcular la vida útil transcurrida y determinar el coeficiente de actualización |
| Tipo | Dato de entrada |
| Origen del dato | **Inventario LY:** columna "Año a Tomar" (prioridad) o "Año Archivo" / "Cap Date" (`02_limpiar_datos.R:61-69`). **Altas SAP:** `posting_date` (`01_importar_datos.R:311`). **Transferencias SAP:** `cap_date_parsed` (fecha de capitalización original) (`03_construir_rollforward.R:112-113`). **Bajas SAP:** `posting_date` como `fecha_alta`, pero `cap_date_parsed` para `anio_alta/mes_alta` (`03_construir_rollforward.R:151-153`) |
| Fórmula (notación) | N/A (dato directo, con parsing) |
| Fórmula explicada | Se parsea desde múltiples formatos: serial Excel, fecha `dd.mm.yyyy`, POSIXct, Date. Para el inventario LY se usa `parsear_fecha_alta()` (`02_limpiar_datos.R:124-138`). Para SAP se usa `parsear_fecha_ddmmyyyy()` (`01_importar_datos.R:67-70`) |
| Unidad | Fecha |
| Redondeo | No aplica |
| Casos borde | **Pre-1992:** el spec indica que se debería ajustar a 01/01/1992 (`FAJ`), pero el R **NO implementa este ajuste automáticamente**. Solo el mecanismo de excepciones manuales (`excepciones_fecha_base.csv`) permite overrides individuales. **Bajas:** la `fecha_alta` se pone como la fecha de baja (posting_date), no la fecha original — esto afecta `fecha_indice_reexp` (ver ficha COEF). Pero `anio_alta` y `mes_alta` sí vienen de `cap_date_parsed` (fecha original) |
| Ubicación en R | `02_limpiar_datos.R:61-69` (LY), `01_importar_datos.R:311,336,361` (SAP), `03_construir_rollforward.R:112-113,151-153` (normalización) |
| Equivalente en el modelo del estudio | Columnas "Año Archivo", "Año a Tomar", "Año Alta" (Edificios: col 5, 6, 7) |
| Coincide con la referencia | **Parcial** — el R toma "Año a Tomar" como prioridad, que coincide con el estudio. Pero NO aplica el corte pre-1992 de forma automática. Para transferencias, el estudio usa la fecha original y el R también (cap_date), lo cual coincide |
| Ejemplo numérico | Posting date `"15.03.2020"` → `2020-03-15` |

---

### Año de Alta (sigla: AA_ANIO)

| Campo | Detalle |
|---|---|
| Definición | Año de la fecha de alta, usado para calcular VUT |
| Tipo | Dato de entrada / Derivado |
| Origen del dato | **Inventario LY:** columna "Año Alta" si existe; si no, `year(fecha_alta)` (`02_limpiar_datos.R:70-74`). **Movimientos SAP:** `year(posting_date)` para altas, `year(cap_date_parsed)` para transferencias y bajas (`03_construir_rollforward.R:122,152`) |
| Fórmula (notación) | `AA_ANIO = año(FA)` o columna directa |
| Fórmula explicada | Es el componente principal del cálculo de VUT. NO se aplica el corte 1992 sobre este valor |
| Unidad | Año (entero) |
| Redondeo | Truncado a entero |
| Casos borde | Para bajas SAP, `anio_alta` viene de `cap_date_parsed`, no de `posting_date` — es la fecha original del bien, no la de la baja |
| Ubicación en R | `02_limpiar_datos.R:70-74`, `03_construir_rollforward.R:122,152` |
| Equivalente en el modelo del estudio | Columna "Año Alta" |
| Coincide con la referencia | Sí (para activos post-1992). Para pre-1992, el estudio usa `max(año, 1992)` y el R no |
| Ejemplo numérico | Fecha `2020-03-15` → `anio_alta = 2020` |

---

### Mes de Alta (sigla: MA)

| Campo | Detalle |
|---|---|
| Definición | Mes de la fecha de alta, usado para calcular el trimestre de alta |
| Tipo | Dato de entrada / Derivado |
| Origen del dato | **Inventario LY:** columna "Mes Alta" si existe; si no, `month(fecha_alta)` (`02_limpiar_datos.R:75-79`). **SAP:** `month(posting_date)` o `month(cap_date_parsed)` (`03_construir_rollforward.R:123,153`) |
| Fórmula (notación) | `MA = mes(FA)` |
| Unidad | Mes (1-12) |
| Ubicación en R | `02_limpiar_datos.R:75-79`, `03_construir_rollforward.R:123,153` |
| Equivalente en el modelo del estudio | Columna "Mes Alta" |
| Coincide con la referencia | Sí |
| Ejemplo numérico | Fecha `2020-03-15` → `mes_alta = 3` |

---

### Trimestres del Primer Año (sigla: TPA)

| Campo | Detalle |
|---|---|
| Definición | Cantidad de trimestres (o períodos) que se computan en el año de alta del bien. Solo aplica a Edificios |
| Tipo | Calculado |
| Origen del dato | `mes_alta` |
| Fórmula (notación) | **Edificios:** `TPA = 4 - floor((MA - 1) / 3)`. **Otros rubros:** `TPA = 1` (fijo) |
| Fórmula explicada | Para Edificios: si el alta es en enero-marzo (Q1), cuenta 4 trimestres; abril-junio (Q2), cuenta 3; julio-septiembre (Q3), cuenta 2; octubre-diciembre (Q4), cuenta 1. Para los demás rubros, siempre se cuenta 1 período (1 año) sin importar el mes de alta |
| Unidad | Trimestres (Edificios) / Años (otros) |
| Redondeo | Resultado entero (floor) |
| Casos borde | Para un alta en enero: `4 - floor(0/3) = 4` trimestres. Para otros rubros, el alta en cualquier mes da siempre 1 año completo — no hay prorrateo por mes |
| Ubicación en R | `utils.R:158-159` (`calcular_trimestres_primer_anio`), `04_calculo_axi.R:60-64` (asignación condicional por rubro) |
| Equivalente en el modelo del estudio | En Edificios: "Trim 1er Año". En Rodados y otros: se computa 1 año completo |
| Coincide con la referencia | **Sí** — Edificios: trimestre de alta completo. Bienes muebles: año de alta completo |
| Norma | Ley de Ganancias: bienes muebles, año de alta = año completo. Edificios: trimestre de alta completo (2% anual trimestral). **El R implementa esto correctamente** |
| Ejemplo numérico | Edificio alta en abril (mes=4): `4 - floor(3/3) = 4 - 1 = 3` trimestres |

---

### Valor de Origen (sigla: VO)

| Campo | Detalle |
|---|---|
| Definición | Valor de adquisición o incorporación del bien, en valores históricos |
| Tipo | Dato de entrada |
| Origen del dato | **Inventario LY:** columna "VO" / "Val. Adquisición" / "Valor Origen" (`02_limpiar_datos.R:20,81-85`). **Altas SAP:** `abs(suma_de_acquisition)` (`03_construir_rollforward.R:125`). **Bajas SAP:** `abs(retirement)` (`03_construir_rollforward.R:155`). **Transferencias SAP:** `suma_de_transfer` (con signo) (`03_construir_rollforward.R:125`) |
| Fórmula (notación) | N/A (dato directo) |
| Fórmula explicada | Se toma `abs()` para altas y bajas para asegurar que el VO sea positivo. Para transferencias se conserva el signo: negativo = salida, positivo = entrada |
| Unidad | $ (pesos) |
| Redondeo | Sin redondeo explícito |
| Casos borde | **NA se reemplaza por 0** en el cálculo AXI (`04_calculo_axi.R:51`): `vo = tidyr::replace_na(vo, 0)`. **Transferencias** con valor negativo: representan la salida del activo del rubro origen. El `direccion_movimiento` se marca como "salida" o "entrada" (`03_construir_rollforward.R:127-130`). **Neteo:** no se netea automáticamente; si un activo tiene alta y baja en el mismo año, aparecen como filas separadas con `tipo_movimiento_calc` = "alta_y_baja" si vienen del LY, o como filas independientes si vienen del SAP |
| Ubicación en R | `02_limpiar_datos.R:81-85`, `03_construir_rollforward.R:125,155`, `04_calculo_axi.R:51` |
| Equivalente en el modelo del estudio | Columna "VO" o "Val. Adquisición" en cada hoja de categoría |
| Coincide con la referencia | Sí — mismo dato de entrada |
| Ejemplo numérico | Alta SAP con `suma_de_acquisition = -50000` → `vo = abs(-50000) = 50000` |

---

### Vida Útil Asignada (sigla: VU)

| Campo | Detalle |
|---|---|
| Definición | Vida útil total del bien según su rubro. Determina el período total de amortización |
| Tipo | Parámetro |
| Origen del dato | Tabla `PARAMETROS_RUBROS` (`utils.R:27-39`) vía `obtener_vu_asignada()` (`utils.R:199-208`). Si el inventario LY trae una columna "VU Asignada", se usa esa (con ajuste: para Edificios se toma tal cual, para otros se divide por 4) (`02_limpiar_datos.R:87-93`) |
| Fórmula (notación) | **Edificios:** `VU = vu_trimestres` (200). **Otros:** `VU = vu_anios` (3, 5, 10, 50). **Terrenos:** `VU = 0` |
| Fórmula explicada | Edificios trabaja en trimestres (200 trim = 50 años). Todos los demás rubros trabajan en años. Terrenos no amortizan (VU=0). La función `obtener_vu_asignada()` retorna el valor en la unidad operativa del rubro |
| Unidad | Trimestres (Edificios) / Años (otros rubros) |
| Redondeo | No aplica |
| Casos borde | **Edificios vs LY:** si el LY trae `vu_asignada` para Edificios, se toma tal cual (asumiendo que ya está en trimestres, `02_limpiar_datos.R:91`). Para otros rubros, el valor del LY se divide por 4 (`02_limpiar_datos.R:91`). **VU = 0** (Terrenos): la amortización queda en 0, evitando división por cero |
| Ubicación en R | `utils.R:27-39` (tabla), `utils.R:199-208` (`obtener_vu_asignada`), `02_limpiar_datos.R:87-93` |
| Equivalente en el modelo del estudio | Columna "VU Asignada" por hoja |
| Coincide con la referencia | **Sí** — los valores coinciden con la tabla 4.2 del spec. Para Rodados: spec dice VU=5 años, 20 trimestres, pero la unidad usada es años. El R usa `vu_anios=5` para Rodados, que coincide |
| Norma | Ley de Ganancias: inmuebles (Edificios) 2% anual = 50 años = 200 trimestres. Bienes muebles: amortización anual, VU en años enteros. Terrenos no amortizan |
| Ejemplo numérico | Edificios: VU = 200 trimestres. Rodados: VU = 5 años. Terrenos: VU = 0 |

---

### Vida Útil Transcurrida al Cierre Anterior (sigla: VUT_LY)

| Campo | Detalle |
|---|---|
| Definición | Cantidad de períodos amortizados hasta el 31/12 del año anterior al ejercicio |
| Tipo | Dato de entrada / Calculado |
| Origen del dato | **Inventario LY:** columna "VUT LY" si existe (`02_limpiar_datos.R:95-99`). **Si no existe:** se calcula con `calcular_vut_ly()` y se convierte a la unidad del rubro |
| Fórmula (notación) | Si no viene del LY: `VUT_LY_trim = (AÑO_EJERCICIO - AA_ANIO - 1) × 4 + TPA_edificios`. Luego: `VUT_LY = VUT_LY_trim / 4 × periodos_por_anio`. Si alta es del año actual: `VUT_LY = 0` |
| Fórmula explicada | 1. `calcular_vut_ly()` (`utils.R:162-171`) calcula en trimestres: años completos anteriores × 4 + trimestres del primer año. Aplica tope con `pmin(vut, vu_asignada)`. 2. En `04_calculo_axi.R:80-81`: el resultado se divide por 4 y se multiplica por `periodos_por_anio` (4 para Edificios, 1 para otros). Para Edificios: queda en trimestres. Para otros: queda en años. 3. Si el LY trae el valor, se usa directamente |
| Unidad | Trimestres (Edificios) / Años (otros rubros) |
| Redondeo | No explícito. `pmin()` trunca al máximo de VU |
| Casos borde | **Alta del año actual:** VUT_LY = 0. **VU agotada:** `pmin` limita a VU máxima. **LY disponible vs calculado:** si el LY trae VUT_LY, se usa ese valor; la conversión de trimestres del cálculo solo aplica si el dato no viene del archivo |
| Ubicación en R | `utils.R:162-171` (cálculo), `04_calculo_axi.R:77-82` (asignación) |
| Equivalente en el modelo del estudio | Columna "VUT LY" por hoja |
| Coincide con la referencia | **Parcial (ERROR en no-Edificios)** — Para Edificios: algebraicamente correcto. Para no-Edificios: el cálculo pasa por trimestres y divide por 4, generando **fracciones** (ej: 2.25, 2.50, 2.75 años). Ver B-04 en `docs/07_impacto_brechas.md` |
| Norma | Ley de Ganancias: bienes muebles → VUT en años enteros. Año de alta = año completo. Correcto: `VUT_LY = anio_ejercicio - anio_alta` (sin pasar por trimestres). Edificios: VUT en trimestres, trimestre de alta completo |
| Ejemplo numérico | Edificio con anio_alta=2020, mes_alta=4, anio_ejercicio=2023: `TPA = 3`. `VUT_LY = 11` trimestres. **Correcto.** Rodado con anio_alta=2020, mes_alta=4, anio_ejercicio=2023: R calcula `VUT_LY = 2.25` años. **Incorrecto** — debería ser `3` años (2020→2021→2022 = 3 años completos antes de 2023) |

---

### Vida Útil Transcurrida en el Ejercicio (sigla: VUT_EJ)

| Campo | Detalle |
|---|---|
| Definición | Períodos amortizados dentro del ejercicio actual |
| Tipo | Calculado |
| Origen del dato | `anio_alta`, `mes_alta`, `anio_ejercicio`, `vu_asignada`, `vut_ly` |
| Fórmula (notación) | `VUT_EJ = pmin(SI(AA_ANIO == AÑO_EJ; TPA; periodos_hasta_baja); VU - VUT_LY)` |
| Fórmula explicada | Si es alta del año: se computan los trimestres del primer año (Edificios) o 1 año (otros). Si no es alta del año: se computan 4 trimestres (Edificios) o 1 año (otros), o menos si es baja de Edificio (trimestres hasta la fecha de baja). Se limita por la VU restante: `vu_asignada - vut_ly` |
| Unidad | Trimestres (Edificios) / Años (otros) |
| Redondeo | No explícito |
| Casos borde | **VU agotada:** si `vut_ly >= vu_asignada`, entonces `VU - VUT_LY ≤ 0` y `VUT_EJ = 0`. **Baja de Edificio:** `periodos_hasta_baja = floor((mes_baja - 1) / 3) + 1` = trimestre de la baja (`04_calculo_axi.R:68-69`). **Bajas de no-Edificios:** `periodos_hasta_baja = 1` (año completo, sin prorrateo por mes de baja) |
| Norma | Ley de Ganancias: bienes muebles → año de baja = **sin amortización** (VUT_EJ debería ser 0 para bajas de muebles). Edificios: se amortiza hasta el trimestre de baja. **El R NO implementa correctamente la baja de muebles** — les computa 1 año |
| Ubicación en R | `04_calculo_axi.R:84-91` |
| Equivalente en el modelo del estudio | Implícito en la diferencia VUT − VUT_LY |
| Coincide con la referencia | **Parcial** — para Edificios coincide. Para otros rubros, el R siempre da 1 año (sin prorrateo), mientras que el spec para Rodados marca `VUT = AÑO_CIERRE − AÑO_ALTA (+1?)` que sería equivalente. El prorrateo de bajas solo aplica a Edificios |
| Ejemplo numérico | Edificio con alta en 2023, mes=7: `TPA = 4 - floor(6/3) = 2` trimestres. Rodado existente (no alta del año): `VUT_EJ = min(1, VU-VUT_LY)` |

---

### VUT al Cierre (sigla: VUT_C)

| Campo | Detalle |
|---|---|
| Definición | Vida útil transcurrida total al 31/12 del año de ejercicio |
| Tipo | Calculado |
| Origen del dato | `vut_ly`, `vut_ejercicio`, `vu_asignada` |
| Fórmula (notación) | `VUT_C = pmin(VUT_LY + VUT_EJ; VU)` |
| Fórmula explicada | Suma de períodos ya amortizados + períodos del ejercicio, con tope en la vida útil total |
| Unidad | Trimestres (Edificios) / Años (otros) |
| Redondeo | No explícito |
| Casos borde | `pmin` asegura que no se exceda la VU |
| Ubicación en R | `04_calculo_axi.R:93` |
| Equivalente en el modelo del estudio | Columna "VUT Cierre" |
| Coincide con la referencia | Sí |
| Ejemplo numérico | Edificio: VUT_LY=11, VUT_EJ=4, VU=200 → VUT_C = min(15, 200) = 15 |

---

### VU Restante (sigla: VUR)

| Campo | Detalle |
|---|---|
| Definición | Períodos de vida útil pendientes de amortizar al cierre |
| Tipo | Calculado |
| Fórmula (notación) | `VUR = pmax(VU - VUT_C; 0)` |
| Ubicación en R | `04_calculo_axi.R:95` |
| Equivalente en el modelo del estudio | Columna "VU Restante" |
| Coincide con la referencia | Sí |

---

### Amortización por Período / Cuota (sigla: CUOTA)

| Campo | Detalle |
|---|---|
| Definición | Amortización lineal por período (trimestre para Edificios, año para el resto) |
| Tipo | Calculado |
| Origen del dato | `vo`, `vu_asignada` |
| Fórmula (notación) | `CUOTA = SI(VU > 0; VO / VU; 0)` |
| Fórmula explicada | Amortización lineal simple. Si VU = 0 (Terrenos), la cuota es 0 |
| Unidad | $/trimestre (Edificios), $/año (otros) |
| Redondeo | Sin redondeo explícito |
| Casos borde | **Terrenos:** VU=0 → CUOTA=0, evita división por cero. **VO=0:** CUOTA=0 |
| Ubicación en R | `04_calculo_axi.R:97-101` |
| Equivalente en el modelo del estudio | Columna "Amort Trimestre" |
| Coincide con la referencia | Sí — `CUOTA = VO / VU` lineal |
| Ejemplo numérico | Edificio: VO=1.000.000, VU=200 → CUOTA = 5.000/trimestre. Rodado: VO=100.000, VU=5 → CUOTA = 20.000/año |

---

### Amortización del Ejercicio (sigla: AE)

| Campo | Detalle |
|---|---|
| Definición | Amortización histórica devengada en el ejercicio actual |
| Tipo | Calculado |
| Origen del dato | `amort_trimestre` (CUOTA), `vut_ejercicio`, `vut_ly`, `vu_asignada` |
| Fórmula (notación) | `AE = SI(VUT_LY < VU; CUOTA × VUT_EJ; 0)` |
| Fórmula explicada | Si la VU no estaba agotada al inicio del año, se amortizan los períodos del ejercicio. Si ya estaba agotada (`VUT_LY ≥ VU`), la amortización del ejercicio es 0 |
| Unidad | $ |
| Redondeo | No explícito |
| Casos borde | **VU agotada:** AE = 0. **Último año de amortización:** VUT_EJ ya está limitado por `VU - VUT_LY`, así que AE cubre solo los períodos restantes. **Bienes pre-2018:** existe también `amort_hist_2018` que es AE solo para bienes ≥ 2018 (línea 109-113); para pre-2018 es 0 |
| Ubicación en R | `04_calculo_axi.R:103-107` (`amort_hist_ejercicio`), `04_calculo_axi.R:109-113` (`amort_hist_2018`) |
| Equivalente en el modelo del estudio | Columna "Amort Hist Ejercicio" |
| Coincide con la referencia | Sí — `AE = CUOTA × [min(VUT;VU) − min(VUT_LY;VU)]` es equivalente algebraicamente |
| Ejemplo numérico | Edificio: CUOTA=5.000, VUT_EJ=4 → AE = 20.000. Si VUT_LY ya era 200 → AE = 0 |

---

### Amortización Acumulada al Cierre (sigla: AA)

| Campo | Detalle |
|---|---|
| Definición | Amortización acumulada total al 31/12 del ejercicio |
| Tipo | Calculado |
| Fórmula (notación) | `AA = SI(VU > 0; CUOTA × VUT_C; 0)` |
| Fórmula explicada | Cuota por los períodos transcurridos totales |
| Unidad | $ |
| Redondeo | No explícito |
| Casos borde | **Bien totalmente amortizado:** `VUT_C = VU` → `AA = VO`. **Terrenos:** AA = 0 |
| Ubicación en R | `04_calculo_axi.R:115-119` (`amort_acum_cierre`) |
| Equivalente en el modelo del estudio | Columna "Amort Acum Cierre" |
| Coincide con la referencia | Sí — `AA = (VO/VU) × min(VUT;VU)` |
| Ejemplo numérico | Edificio: CUOTA=5.000, VUT_C=15 → AA = 75.000 |

---

### Amortización Acumulada al Inicio (sigla: AA_LY)

| Campo | Detalle |
|---|---|
| Definición | Amortización acumulada al 31/12 del año anterior |
| Tipo | Calculado |
| Fórmula (notación) | `AA_LY = SI(VU > 0; CUOTA × VUT_LY; 0)` |
| Fórmula explicada | Cuota por los períodos transcurridos al cierre anterior |
| Unidad | $ |
| Ubicación en R | `04_calculo_axi.R:121-125` (`amort_acum_ly`) |
| Equivalente en el modelo del estudio | Columna "Amort Acum LY" |
| Coincide con la referencia | Sí |
| Ejemplo numérico | Edificio: CUOTA=5.000, VUT_LY=11 → AA_LY = 55.000 |

---

### Valor Residual al Cierre (sigla: VR)

| Campo | Detalle |
|---|---|
| Definición | Valor pendiente de amortizar al cierre del ejercicio |
| Tipo | Calculado |
| Fórmula (notación) | `VR = VO - AA` |
| Fórmula explicada | Valor de origen menos amortización acumulada. NO tiene `max(..., 0)` explícito; el `pmin` en VUT_C evita que AA > VO |
| Unidad | $ |
| Redondeo | No explícito |
| Casos borde | **Totalmente amortizado:** VR = 0. **Terrenos:** VR = VO (AA=0). **Nota:** el spec dice `VR = max(VO − AA; 0)`, pero el R no aplica `max`. Dado que AA ≤ VO por construcción (CUOTA×min(VUT,VU) ≤ VO), el resultado es equivalente salvo errores de redondeo |
| Ubicación en R | `04_calculo_axi.R:127` |
| Equivalente en el modelo del estudio | Columna "VR" |
| Coincide con la referencia | Sí (por equivalencia algebraica) |
| Ejemplo numérico | VO=1.000.000, AA=75.000 → VR = 925.000 |

---

### VR al Inicio (sigla: VR_LY)

| Campo | Detalle |
|---|---|
| Definición | Valor residual al 31/12 del año anterior |
| Tipo | Calculado |
| Fórmula (notación) | `VR_LY = VO - AA_LY` |
| Ubicación en R | `04_calculo_axi.R:129` |
| Equivalente en el modelo del estudio | Implícito; usado en la prueba global |
| Coincide con la referencia | Sí |

---

### Fecha de Índice para Reexpresión (sigla: FIR)

| Campo | Detalle |
|---|---|
| Definición | Fecha usada para buscar el coeficiente de actualización IPC/IPIM |
| Tipo | Derivado |
| Origen del dato | Por defecto es `fecha_alta`. Se puede override por activo con `excepciones_fecha_base.csv` |
| Fórmula (notación) | `FIR = COALESCE(fecha_indice_excepcion; fecha_alta)` |
| Fórmula explicada | Si existe una excepción para el activo (por rubro + nro_activo_fijo), se usa la fecha de la excepción. Si no, se usa la fecha de alta |
| Unidad | Fecha |
| Casos borde | **Bajas SAP:** `fecha_alta` es el `posting_date` de la baja (no la fecha original). Esto hace que el coeficiente se busque por la fecha de la baja, no por la fecha original del bien. Puede ser intencional para usar el índice al momento de la baja. **Pre-1992:** no hay ajuste automático a 1992 |
| Ubicación en R | `utils.R:127` (default), `utils.R:149-155` (excepción) |
| Equivalente en el modelo del estudio | La fecha con la que se busca el coeficiente |
| Coincide con la referencia | **Parcial** — el estudio usa `FAJ = SI(año<1992; 01/01/1992; FA)`. El R no implementa el corte 1992 automáticamente; requiere excepciones manuales |

---

### Coeficiente de Actualización IPC (sigla: COEF_IPC)

| Campo | Detalle |
|---|---|
| Definición | Coeficiente de reexpresión por IPC para bienes con alta desde 2018 |
| Tipo | Calculado (lookup) |
| Origen del dato | `fecha_indice_reexp`, `indices_ipc`, `anio_alta` |
| Fórmula (notación) | `COEF_IPC = SI(AA_ANIO >= 2018; buscar_coeficiente(FIR, indices_ipc); 1)` |
| Fórmula explicada | Para bienes ≥ 2018: busca en la tabla IPC la fila con la fecha más cercana anterior o igual a FIR y toma el coeficiente. Para bienes < 2018: coef_ipc = 1 (no se usa IPC) |
| Unidad | Coeficiente (adimensional) |
| Redondeo | No aplica |
| Casos borde | **Fecha no encontrada:** si FIR es anterior a todas las fechas de la tabla IPC, se toma el primer registro (`utils.R:189`). **Fecha NA:** retorna 1 (`utils.R:187`) |
| Ubicación en R | `04_calculo_axi.R:135-139`, `utils.R:182-192` |
| Equivalente en el modelo del estudio | Columna 4 de la hoja IPC del Excel, aplicada vía BUSCARV |
| Coincide con la referencia | **Sí** para ≥ 2018. Para < 2018, el estudio usa coef=1 (escenario A base), y el R también pone coef_ipc=1 |

---

### Coeficiente de Actualización IPIM (sigla: COEF_IPIM)

| Campo | Detalle |
|---|---|
| Definición | Coeficiente de reexpresión por IPIM, usado para bienes pre-2018 |
| Tipo | Calculado (lookup) |
| Origen del dato | `fecha_indice_reexp`, `indices_ipim` |
| Fórmula (notación) | `COEF_IPIM = buscar_coeficiente(FIR, indices_ipim)` |
| Fórmula explicada | Se calcula para TODOS los activos (no solo pre-2018), pero solo se usa para bienes con `anio_alta < 2018`. Mismo mecanismo de lookup que COEF_IPC |
| Unidad | Coeficiente (adimensional) |
| Ubicación en R | `04_calculo_axi.R:141` |
| Equivalente en el modelo del estudio | El estudio (escenario A) no usa IPIM — usa coef=1 para pre-2018. El uso de IPIM corresponde a un criterio diferente (confiscatoriedad) |
| Coincide con la referencia | **NO** — el estudio (escenario A base) pone coef=1 para pre-2018. El R aplica IPIM. PA-01 RESUELTA: coef=1 por defecto |
| Norma | Ley 27.430/27.468: solo bienes desde 01/01/2018 con IPC. Anteriores: coef = 1 (escenario base) |

---

### VO Reexpresado (sigla: VO_R)

| Campo | Detalle |
|---|---|
| Definición | Valor de origen ajustado a moneda de cierre |
| Tipo | Calculado |
| Fórmula (notación) | `VO_R = SI(AA_ANIO >= 2018; VO × COEF_IPC; VO × COEF_IPIM)` |
| Fórmula explicada | Bienes ≥ 2018 se reexpresan con IPC. Bienes < 2018 se reexpresan con IPIM (no quedan a valor histórico como en el escenario A del estudio) |
| Unidad | $ |
| Redondeo | No explícito |
| Ubicación en R | `04_calculo_axi.R:143-147` |
| Equivalente en el modelo del estudio | Columna "VO Reexp" |
| Coincide con la referencia | **NO para pre-2018** — el estudio (escenario A) tendría `VO_R = VO × 1 = VO`. El R usa `VO × COEF_IPIM`. PA-01 RESUELTA: coef=1 por defecto |
| Norma | `VO_R = SI(anio_alta >= 2018; VO × COEF_IPC; VO)` (escenario base). Escenario B opcional: IPIM para pre-2018 |
| Ejemplo numérico | Bien 2020 con VO=100.000, COEF_IPC=1.5 → VO_R=150.000. Bien 2015 con VO=100.000, COEF_IPIM=3.2 → VO_R=320.000 |

---

### Amortización Histórica Reexpresada (sigla: AE_R)

| Campo | Detalle |
|---|---|
| Definición | Amortización del ejercicio ajustada por inflación (solo bienes ≥ 2018) |
| Tipo | Calculado |
| Fórmula (notación) | `AE_R = SI(AA_ANIO >= 2018; amort_hist_2018 × COEF_IPC; 0)` |
| Fórmula explicada | Solo se reexpresa la amortización del ejercicio para bienes post-2018. Para pre-2018, AE_R = 0 |
| Unidad | $ |
| Ubicación en R | `04_calculo_axi.R:149-153` (`amort_hist_reexp`) |
| Equivalente en el modelo del estudio | [A CONFIRMAR] — el spec marca AE_R como `AE × COEF` sin distinguir pre/post 2018 |
| Coincide con la referencia | **Parcial** — el R solo reexpresa AE para ≥ 2018. El spec sugiere `AE_R = AE × COEF` para todos. Diferencia por el tratamiento pre-2018 |

---

### Amortización Acumulada al Inicio Reexpresada (sigla: AA_LY_R)

| Campo | Detalle |
|---|---|
| Definición | Amortización acumulada al inicio del ejercicio, reexpresada |
| Tipo | Calculado |
| Fórmula (notación) | `AA_LY_R = SI(AA_ANIO >= 2018; AA_LY × COEF_IPC; AA_LY × COEF_IPIM)` |
| Ubicación en R | `04_calculo_axi.R:155-159` (`amort_acum_ly_reexp`) |
| Coincide con la referencia | Parcial — mismo tema pre-2018 (IPC=1 en el estudio vs IPIM en el R) |

---

### Amortización Acumulada al Cierre Reexpresada (sigla: AA_R)

| Campo | Detalle |
|---|---|
| Definición | Amortización acumulada al cierre del ejercicio, reexpresada |
| Tipo | Calculado |
| Fórmula (notación) | `AA_R = SI(AA_ANIO >= 2018; AA × COEF_IPC; AA × COEF_IPIM)` |
| Ubicación en R | `04_calculo_axi.R:161-165` (`amort_acum_cierre_reexp`) |
| Equivalente en el modelo del estudio | Columna "Amort Acum Cierre Reexp" |
| Coincide con la referencia | Parcial — mismo tema pre-2018 |

---

### VR Reexpresado (sigla: VR_R)

| Campo | Detalle |
|---|---|
| Definición | Valor residual ajustado a moneda de cierre. Es el resultado clave del revalúo |
| Tipo | Calculado |
| Fórmula (notación) | `VR_R = VO_R - AA_R` |
| Fórmula explicada | Equivale a `(VO − AA) × COEF` solo si el coeficiente es el mismo para VO y AA. En el R, ambos usan el mismo coeficiente (IPC o IPIM según año), así que `VR_R = VR × COEF` es equivalente |
| Unidad | $ |
| Redondeo | No explícito |
| Casos borde | **Terrenos:** VR_R = VO_R (sin amortización). **Totalmente amortizado:** VR_R = 0 |
| Ubicación en R | `04_calculo_axi.R:167` |
| Equivalente en el modelo del estudio | Columna "VR Reexp" |
| Coincide con la referencia | Sí (algebraicamente `VO_R − AA_R = VR × COEF`). La diferencia está en el COEF usado, no en la fórmula |

---

### Ajuste VU Agotada LY (sigla: AVA)

| Campo | Detalle |
|---|---|
| Definición | Ajuste negativo para bienes cuya VU ya estaba agotada al cierre del año anterior. Se usa en la prueba global |
| Tipo | Calculado |
| Fórmula (notación) | `AVA = SI(VUT_LY >= VU y VU > 0; -CUOTA × periodos_del_ejercicio; 0)` |
| Fórmula explicada | Para bienes que ya estaban totalmente amortizados, calcula la amortización "fantasma" que se habría devengado si la VU no estuviera agotada, y la registra como ajuste negativo. Esto cuadra la prueba global de amortizaciones |
| Unidad | $ |
| Ubicación en R | `04_calculo_axi.R:171-187` (`amort_bs_agotaron_vu_ly`) |
| Equivalente en el modelo del estudio | Fila "Bs. que agotaron la VU en LY" de la hoja PG |
| Coincide con la referencia | Sin referencia explícita en el spec — es un mecanismo interno del R para cuadrar la PG |

---

### Reexpresión de Bajas (sigla: BAJA_R)

| Campo | Detalle |
|---|---|
| Definición | Amortización y VR de bienes dados de baja, reexpresados con índices específicos de bajas |
| Tipo | Calculado |
| Fórmula (notación) | `amort_bajas = SI(es_baja; SI(AA_ANIO >= 2018; AA × COEF_IPC_BAJAS; AA × COEF_IPIM_BAJAS); 0)` / `vr_bajas = SI(es_baja; SI(AA_ANIO >= 2018; VR × COEF_IPC_BAJAS; VR × COEF_IPIM_BAJAS); 0)` |
| Fórmula explicada | Las bajas tienen sus propias tablas de índices ("IPC - VR Bajas" y "IPIM - VR Bajas") separadas de las tablas normales. El coeficiente se busca con la misma `fecha_indice_reexp` |
| Unidad | $ |
| Casos borde | Solo se aplica a filas con `tipo_movimiento_calc == "baja"`. Las tablas de índices de bajas pueden diferir de las normales |
| Ubicación en R | `04_calculo_axi.R:245-285` (`calcular_bajas_reexp`) |
| Equivalente en el modelo del estudio | [A CONFIRMAR] — el spec menciona revalúo de bajas pero no detalla índices separados |
| Coincide con la referencia | **No confirmado** — el uso de tablas de índices separadas para bajas no se describe en el spec. Ver PA-05 |

---

### Terrenos (sigla: TERR)

| Campo | Detalle |
|---|---|
| Definición | Tratamiento especial: no amortiza, solo reexpresa VO |
| Tipo | Calculado |
| Fórmula (notación) | `VU=0, AA=0, VR=VO, VR_R=VO_R` |
| Fórmula explicada | Todas las columnas de amortización se setean a 0. Solo se aplica la reexpresión de VO |
| Ubicación en R | `04_calculo_axi.R:196-241` (`calcular_terrenos`) |
| Equivalente en el modelo del estudio | Hoja "Terrenos" del Excel — sin columnas de amortización |
| Coincide con la referencia | Sí |

---

### Resultado AXI (sigla: AXI)

| Campo | Detalle |
|---|---|
| Definición | Ajuste por inflación impositivo: diferencia entre VR reexpresado y VR histórico |
| Tipo | Calculado |
| Fórmula (notación) | `AXI = VR_R - VR` |
| Fórmula explicada | Mide el efecto de la inflación sobre el valor residual de cada activo |
| Unidad | $ |
| Ubicación en R | `05_prueba_global.R:166` (`axi_resultado`) — se calcula a nivel de prueba global, no por activo individual |
| Equivalente en el modelo del estudio | Hoja "PG AXI", columna "AXI Resultado" |
| Coincide con la referencia | Sí |
| Ejemplo numérico | VR_R=150.000, VR=100.000 → AXI = 50.000 |

---

### Prueba Global — Amortizaciones (sigla: PG_A)

| Campo | Detalle |
|---|---|
| Definición | Control de cuadre de amortizaciones por rubro |
| Tipo | Calculado |
| Fórmula (notación) | `PG_A = amort_inicio + amort_altas + amort_transf + amort_bajas + bs_agotaron_vu_ly + amort_hist_ejercicio` |
| Fórmula explicada | Reconstruye la amortización acumulada al cierre sumando: inicio + movimientos del ejercicio + ajustes. El resultado (`amort_prueba`) debe coincidir con `amort_revaluo` (suma directa de AA al cierre). La diferencia debe ser ~0 |
| Unidad | $ |
| Ubicación en R | `05_prueba_global.R:17-79` |
| Equivalente en el modelo del estudio | Hoja "PG" — sección de amortizaciones |
| Coincide con la referencia | Sí — misma lógica de cuadre |

---

### Prueba Global — Valor Residual (sigla: PG_VR)

| Campo | Detalle |
|---|---|
| Definición | Control de cuadre de valor residual por rubro |
| Tipo | Calculado |
| Fórmula (notación) | `PG_VR = vr_inicio + altas_vr + transf_vr + bajas_vo + amort_ejercicio` |
| Fórmula explicada | Reconstruye el VR al cierre. `amort_ejercicio` resta (es negativo). `bajas_vo` resta (negativo). El resultado debe coincidir con la suma directa de VR por rubro |
| Unidad | $ |
| Ubicación en R | `05_prueba_global.R:82-139` |
| Equivalente en el modelo del estudio | Hoja "PG" — sección de valor residual |
| Coincide con la referencia | Sí |
