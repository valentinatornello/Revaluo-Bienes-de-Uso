# T0.3 — Mapeo de Datos de Entrada

## 1. Excel del Año Anterior (LY)

**Archivo:** `inputs/parametros/MARG - Revaluo AxI {año}_v_28.04.23 IPIM e IPC.xlsx`
**Lectura:** `leer_inventario_categorias()` → `leer_hoja_categoria()` (`01_importar_datos.R:88-127`)

### 1.1 Hojas de categorías (11 hojas)

Cada hoja tiene un header en una fila variable (ver `FILAS_HEADER`, `01_importar_datos.R:34-46`). Las columnas se detectan por regex sobre los nombres, no por posición.

**Mapeo de columnas (detección por regex en `02_limpiar_datos.R:14-23`):**

| Columna original (regex de detección) | Nombre interno en R | Tipo final | Transformación |
|---|---|---|---|
| `activo.?fijo\|n.*activo` | `nro_activo_fijo` | character | `as.character()` |
| `descrip\|denominaci` | `descripcion` | character | `as.character()` |
| `a.*o.*tomar` (prioridad) o `a.*o.*archivo\|a.*o.*cia\|fe.*capit` | `fecha_alta` | Date | `parsear_fecha_alta()`: intenta serial Excel → Date, luego POSIXct → Date, luego texto → Date |
| `^a.*o.*alta$` | `anio_alta` | integer | `as.integer()`. Si no existe, se calcula como `year(fecha_alta)` |
| `mes.*alta` | `mes_alta` | integer | `as.integer()`. Si no existe, se calcula como `month(fecha_alta)` |
| `^vo$\|val.*adq\|val.*origen$` | `vo` | numeric | `as.numeric()` |
| `vu.*asignada` | `vu_asignada` | numeric | Para Edificios: se toma tal cual (trimestres). Para otros: se divide por 4 (`02_limpiar_datos.R:91`). Si no existe: se usa `obtener_vu_asignada(rubro)` |
| `vut.*ly\|vut.*l.*y` | `vut_ly` | numeric | `as.numeric()`. Si no existe: se calcula con `calcular_vut_ly()` |

**Columnas generadas (no vienen del Excel):**

| Columna | Origen | Lógica |
|---|---|---|
| `rubro` | Nombre de la hoja | Se asigna directamente (`01_importar_datos.R:125`) |
| `tipo_movimiento_calc` | Primera columna del Excel | `detectar_tipo_movimiento()` por regex: "Altas" → alta, "Bajas" → baja, "Transferencias" → transferencia, numérico → nota, otro → historico |
| `tipo_movimiento` | Derivado | Si el movimiento es del año actual → conserva tipo; si no → "historico" |
| `subclasificacion_historico` | Derivado | Para históricos reclasificados: conserva el tipo original (alta/baja/transferencia) |
| `anio_movimiento` | Primera columna del Excel | `extraer_anio_movimiento()`: extrae 4 dígitos del texto |

**Filtros aplicados:**
- IFRS 16: excluye `nro_activo_fijo` con prefijo "AS" (`02_limpiar_datos.R:141-147`)
- Filas de totales y notas: excluye `tipo_movimiento %in% c("totales", "nota")` (`02_limpiar_datos.R:161`)
- Filas vacías: excluye si `is.na(vo) & is.na(nro_activo_fijo)` (`02_limpiar_datos.R:162`)

---

### 1.2 Hoja IPC

**Lectura:** `leer_indices_ipc()` (`01_importar_datos.R:143-155`)

| Columna Excel (posición) | Nombre interno | Tipo | Transformación |
|---|---|---|---|
| Columna 1 | `fecha` | Date | `parsear_fecha_indice()` |
| Columna 2 | `ipc_periodo` | numeric | `as.numeric()` |
| Columna 3 | `ipc_actual` | numeric | `as.numeric()` |
| Columna 4 | `coeficiente` | numeric | `as.numeric()` |

**Filtro:** `!is.na(fecha)` — elimina filas sin fecha.

**Nota:** La hoja IPC se lee **sin** header (`col_names = FALSE`); la hoja IPIM se lee **con** header (`col_names = TRUE`). Esto es una inconsistencia menor en el código (`01_importar_datos.R:131` vs `01_importar_datos.R:144`).

---

### 1.3 Hoja IPIM

**Lectura:** `leer_indices_ipim()` (`01_importar_datos.R:129-141`)

Mismo esquema que IPC pero los nombres internos son `ipim_periodo`, `ipim_actual`, `coeficiente`.

---

### 1.4 Hoja "IPC - VR Bajas"

**Lectura:** `leer_indices_ipc_bajas()` (`01_importar_datos.R:171-183`)

Mismo esquema que IPC. Se usa exclusivamente para la reexpresión de bienes dados de baja.

---

### 1.5 Hoja "IPIM - VR Bajas"

**Lectura:** `leer_indices_ipim_bajas()` (`01_importar_datos.R:157-169`)

Mismo esquema que IPIM. Se usa exclusivamente para la reexpresión de bienes dados de baja.

---

## 2. Excel de Movimientos SAP

**Archivo:** `inputs/SAP/*.xlsx` (se toma el primer `.xlsx` del directorio)
**Lectura:** `leer_movimientos_sap()` (`01_importar_datos.R:292-395`)

### 2.1 Hoja "Altas"

| Columna original (post clean_names) | Nombre interno | Tipo | Transformación |
|---|---|---|---|
| `asset` | `nro_activo` | character | `normalizar_clave_activo()` (trim) |
| `cap_date` | `cap_date` | character | Se mantiene texto; se parsea aparte |
| `pstng_date` | `posting_date` | Date | `parsear_fecha_ddmmyyyy()` (dd.mm.yyyy) |
| `asset_description2` | `descripcion` | character | — |
| `class` | `class` | character | Se mapea a `rubro` vía `CLASS_A_RUBRO` |
| `suma_de_acquisition` | `valor` | numeric | `as.numeric()` |

**Columnas derivadas:**
- `rubro`: `dplyr::recode(class, !!!CLASS_A_RUBRO)` — línea 313
- `cap_date_parsed`: `parsear_fecha_ddmmyyyy(cap_date)` — línea 311
- `tipo_movimiento_sap`: `"alta"` — línea 308

**Filtros:**
- `es_fila_detalle_sap(nro_activo)`: excluye totales, grand total, subtotales — línea 316
- `!is.na(rubro)`: excluye clases no mapeadas — línea 317
- `rubro != "Obras en curso"`: excluye 600LA — línea 318
- `!grepl("^AS", nro_activo)`: excluye IFRS 16 — línea 319

---

### 2.2 Hoja "Bajas"

| Columna original (post clean_names) | Nombre interno | Tipo | Transformación |
|---|---|---|---|
| `asset` | `nro_activo` | character | `normalizar_clave_activo()` |
| `cap_date` | `cap_date` | character | Parseado a `cap_date_parsed` |
| `pstng_date` | `posting_date` | Date | `parsear_fecha_ddmmyyyy()` |
| `asset_description` | `descripcion` | character | — |
| `class` | `class` | character | → `rubro` |
| `retirement` | `valor` | numeric | `as.numeric()` |
| `depr_retired` | `depr_retired` | numeric | `as.numeric()` |
| `ret_book_value` | `ret_book_value` | numeric | `as.numeric()` |

**Filtros adicionales respecto a altas:**
- `abs(ret_book_value) < 0.01` — línea 352: solo bajas donde el valor residual contable es ~0 (totalmente depreciado). Bajas parciales quedan excluidas.

**Nota:** El campo `asset_description` (sin "2") difiere del de altas (`asset_description2`). Es un detalle del reporte SAP.

---

### 2.3 Hoja "Transferencias"

| Columna original (post clean_names) | Nombre interno | Tipo | Transformación |
|---|---|---|---|
| `asset` | `nro_activo` | character | `normalizar_clave_activo()` |
| `cap_date` | `cap_date` | character | Parseado a `cap_date_parsed` |
| `pstng_date` | `posting_date` | Date | `parsear_fecha_ddmmyyyy()` |
| `asset_description2` | `descripcion` | character | — |
| `class` | `class` | character | → `rubro` |
| `suma_de_transfer` | `valor` | numeric | `as.numeric()` |
| `suma_de_trans_o_dep` | `transf_dep` | numeric | `as.numeric()` |

**Nota:** `transf_dep` (amortización transferida) se lee pero no se usa en el cálculo posterior. Queda almacenada pero no participa en fórmulas.

---

## 3. CSV de Excepciones de Fecha Base (opcional)

**Archivo:** `inputs/parametros/excepciones_fecha_base.csv`
**Lectura:** `leer_excepciones_fecha_base()` (`01_importar_datos.R:9-26`)

| Columna CSV | Nombre interno | Tipo | Descripción |
|---|---|---|---|
| `rubro` | `rubro` | character | Nombre del rubro |
| `nro_activo_fijo` | `nro_activo_fijo` | character | Normalizado con `normalizar_clave_activo()` |
| `fecha_base_reexpresion` | `fecha_base_reexpresion` | Date | Fecha base para la reexpresión |
| `inicio_indice_desde` | `inicio_indice_desde` | Date | Fecha desde la cual tomar el índice |
| `motivo` | `motivo` | character | Justificación de la excepción |
| `fuente_manual` | `fuente_manual` | character | Fuente documental |
| `activo` | `activo` | logical | Si la excepción está activa (default TRUE) |

**Uso:** `aplicar_excepciones_fecha_base()` (`utils.R:119-156`) reemplaza `fecha_indice_reexp` del activo por `inicio_indice_desde` (o `fecha_base_reexpresion` si no hay `inicio_indice_desde`).

---

## 4. Excel de Validación Externa (opcional)

**Archivo:** `inputs/parametros/MARG - Revalúo AxI {año}*.xlsx`
**Lectura:** `leer_pg_real()` (`01_importar_datos.R:203-279`)

### Hojas leídas:

| Hoja | Dato extraído | Método |
|---|---|---|
| `PG` | `amort_revaluo` | Fila 19 o columna "amort_revaluo" |
| `PG` | `vr_revaluo` | Fila 35 o columna "vr_revaluo" |
| `PG AXI` | `vr_reexp` | Fila 36 o columna "vr_reexp" |

**Detección de layout:** Intenta primero ubicar los rubros como encabezados de columna (layout pivotado); si falla, busca formato tabular con columna "rubro".

**Valor derivado:** `axi_resultado = vr_revaluo_reexp - vr_revaluo` — calculado en el código, no leído del Excel (`01_importar_datos.R:277`).

---

## 5. Claves de unión entre tablas

| Unión | Clave | Dónde se aplica |
|---|---|---|
| Inventario LY ↔ Movimientos SAP | `rubro` | `03_construir_rollforward.R:38-58` (por rubro, no por activo individual) |
| Inventario ↔ Excepciones fecha base | `rubro` + `nro_activo_fijo` | `utils.R:150` (left_join) |
| Activo ↔ Coeficiente IPC/IPIM | `fecha_indice_reexp` ≤ `tabla_indices$fecha` | `utils.R:186-191` (búsqueda por fecha más cercana anterior) |
| Clase SAP → Rubro | `class` | `CLASS_A_RUBRO` lookup (`01_importar_datos.R:313`) |

**Nota importante:** Los movimientos SAP (altas, bajas, transferencias) se incorporan **por rubro**, no se cruzan por número de activo individual con el inventario existente. Esto significa que si un activo en altas ya existe en el inventario LY, se agrega como fila separada — no se actualiza la fila existente. El neteo altas/bajas del mismo año se maneja a nivel de tipo_movimiento_calc, no mediante un join.
