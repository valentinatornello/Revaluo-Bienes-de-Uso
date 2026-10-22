# T0.6 — Reglas y Parámetros Hardcodeados

## Resumen

Se identificaron 28 constantes de negocio embebidas en el código. Se propone migrar cada una a una tabla de parámetros versionada por año de ejercicio.

---

## 1. Tabla de rubros y vidas útiles

**Ubicación:** `utils.R:27-39` (`PARAMETROS_RUBROS`)

| Rubro | Clases SAP | VU (años) | VU (trim.) | Índice |
|---|---|---|---|---|
| Cercos | (vacío) | 50 | 200 | IPC |
| Edificios | 210LA,220LA,392LA | 50 | 200 | IPC |
| Terrenos | 110LA | NA | 0 | IPC |
| Estructuras y caños | (vacío) | 10 | 40 | IPC |
| Eq de Oficina | 320LA | 3 | 12 | IPC |
| Maquinas y Equipos | 310LA,350LA | 10 | 40 | IPC |
| Maquinas Mejoras | 370LA | 10 | 40 | IPC |
| MyU | 330LA | 3 | 12 | IPC |
| Rodados | 360LA | 5 | 20 | IPC |
| Terreno Mejoras | 130LA,250LA | 10 | 40 | IPC |
| Software | 510LA,515LA,610LA | 3 | 12 | IPC |

**Propuesta:** Tabla CSV/JSON versionada por año. Si las VU o el índice cambian de un año a otro, se carga la versión correspondiente. Actualmente todos los rubros usan IPC como índice declarado, pero el código usa IPIM para bienes pre-2018 (`04_calculo_axi.R:141`).

---

## 2. Mapeo clase SAP → rubro

**Ubicación:** `01_importar_datos.R:48-65` (`CLASS_A_RUBRO`)

```r
CLASS_A_RUBRO <- c(
  "110LA" = "Terrenos",
  "130LA" = "Terreno Mejoras",
  "210LA" = "Edificios",
  "220LA" = "Edificios",
  "250LA" = "Terreno Mejoras",
  "310LA" = "Maquinas y Equipos",
  "320LA" = "Eq de Oficina",
  "330LA" = "MyU",
  "350LA" = "Maquinas y Equipos",
  "360LA" = "Rodados",
  "370LA" = "Maquinas Mejoras",
  "392LA" = "Edificios",
  "510LA" = "Software",
  "515LA" = "Software",
  "610LA" = "Software",
  "600LA" = "Obras en curso"
)
```

**Propuesta:** Incluir este mapeo en la misma tabla de parámetros de rubros. Si se agregan nuevas clases SAP, solo se modifica la tabla.

---

## 3. Año de corte del revalúo (IPC vs IPIM)

**Ubicación:** `utils.R:42`

```r
ANIO_CORTE_REVALUO <- 2018
```

**Uso:** Determina si un bien se reexpresa con IPC (≥ 2018) o IPIM (< 2018). Referenciado en:
- `04_calculo_axi.R:110` — `amort_hist_2018`
- `04_calculo_axi.R:136` — `coef_ipc`
- `04_calculo_axi.R:143` — `vo_reexp`

**Propuesta:** Parámetro en la tabla de configuración del ejercicio. Poco probable que cambie, pero debe estar documentado.

---

## 4. Conteos esperados de movimientos SAP

**Ubicación:** `utils.R:44-49`

```r
CONTEOS_MOVIMIENTOS_ESPERADOS <- tibble::tribble(
  ~tipo_movimiento_sap, ~conteo_esperado,
  "alta",              4873L,
  "baja",              1717L,
  "transferencia",     1738L
)
```

**Propuesta:** Estos conteos son específicos del año 2022/2023. Deben ser un parámetro por año de ejercicio o eliminarse como validación hard (es frágil).

---

## 5. Tolerancias de validación

**Ubicación:** `utils.R:51-55`

| Constante | Valor | Uso |
|---|---|---|
| `TOLERANCIA_PRUEBA_GLOBAL` | `1` | Diferencia máxima ($) en PG para ser OK |
| `UMBRAL_ERROR_PRUEBA_GLOBAL` | `100` | Por encima es ERROR, entre 1 y 100 es ADVERTENCIA |
| `TOLERANCIA_CONSISTENCIA_INTERNA` | `0.01` | Tolerancia de redondeo para consistencia interna |
| `TOLERANCIA_VALIDACION_EXTERNA` | `0.20` | 20% de tolerancia contra el manual externo |

**Propuesta:** Parámetros configurables. La tolerancia externa del 20% es alta; podría reducirse a medida que el modelo converja.

---

## 6. Filas de header por hoja del Excel LY

**Ubicación:** `01_importar_datos.R:34-46` (`FILAS_HEADER`)

| Hoja | Skip | Header row |
|---|---|---|
| Cercos | 13 | 13 |
| Edificios | 16 | 16 |
| Terrenos | 5 | 5 |
| Estructuras y caños | 9 | 9 |
| Eq de Oficina | 11 | 11 |
| Maquinas y Equipos | 10 | 10 |
| Maquinas Mejoras | 10 | 10 |
| MyU | 12 | 12 |
| Rodados | 9 | 9 |
| Terreno Mejoras | 9 | 9 |
| Software | 9 | 9 |

**Propuesta:** Tabla parametrizable. Si el formato del Excel del estudio cambia, solo se actualiza la tabla. Nota: estos valores fueron calibrados contra el formato KPMG 2022; si cambian los encabezados del Excel, hay que recalibrar.

---

## 7. Nombres de hojas esperadas

**Ubicación:** `01_importar_datos.R:28-32` (`HOJAS_CATEGORIAS`)

```r
HOJAS_CATEGORIAS <- c(
  "Cercos", "Edificios", "Terrenos", "Estructuras y caños",
  "Eq de Oficina", "Maquinas y Equipos", "Maquinas Mejoras",
  "MyU", "Rodados", "Terreno Mejoras", "Software"
)
```

**Propuesta:** Derivar de la tabla de rubros para evitar duplicación.

---

## 8. Alias de rubros

**Ubicación:** `utils.R:82-105` (`ALIAS_RUBROS`)

24 entradas que mapean nombres alternativos (del estudio externo, con variantes de acentos y plurales) a los nombres canónicos.

**Propuesta:** Tabla externa. Si el estudio cambia la denominación, se actualiza sin tocar código.

---

## 9. Exclusiones hardcodeadas

**Ubicación:** `01_importar_datos.R:315-319` y `01_importar_datos.R:342-352`

Filtros aplicados en la lectura de movimientos SAP:
- `rubro != "Obras en curso"` (clase 600LA) — línea 318
- `!grepl("^AS", nro_activo, ignore.case = TRUE)` — línea 319 (IFRS 16)
- Para bajas: `abs(ret_book_value) < 0.01` — línea 352 (solo bajas totalmente depreciadas)

**Nota adicional:** Las exclusiones de la spec (9050/9150/9250/9350 leasing, 495LA deterioros, 9750 otros) no aparecen explícitamente en el código. Al no estar en `CLASS_A_RUBRO`, esas clases quedan con `rubro = NA` y se filtran por `!is.na(rubro)` en la línea 317. El efecto es el mismo, pero la exclusión es implícita.

**Propuesta:** Tabla explícita de exclusiones con código de clase y motivo. Que sea auditable.

---

## 10. Nombre del archivo del Excel LY

**Ubicación:** `_targets.R:14-17`

```r
PATH_EXCEL_LY <- file.path(
  "inputs", "parametros",
  sprintf("MARG - Revaluo AxI %d_v_28.04.23 IPIM e IPC.xlsx", ANIO_EJERCICIO)
)
```

**Problema:** El patrón de nombre incluye `_v_28.04.23`, que es específico de la versión del archivo KPMG 2022. No funciona para otros años sin editar.

**Propuesta:** Buscar dinámicamente por año (como hace `buscar_archivo_real()`) o pedir la ruta como parámetro.

---

## 11. Filas hardcodeadas en la lectura de PG

**Ubicación:** `01_importar_datos.R:271-272`

```r
vr_revaluo <- extraer_serie("PG", 35, "vr_revaluo")
vr_revaluo_reexp <- extraer_serie("PG AXI", 36, "vr_reexp")
```

Las filas 35 y 36 asumen un layout fijo de las hojas PG del estudio externo. Hay un fallback a formato tabular (`extraer_serie_tabular`), pero si ni el layout de fila fija ni el tabular coinciden, falla.

**Propuesta:** Hacer que la detección sea enteramente dinámica (el fallback tabular ya existe; eliminar la dependencia de filas fijas).

---

## 12. Nombres de columnas SAP esperados

**Ubicación:** `01_importar_datos.R:298-371`

Después de `janitor::clean_names()`, se renombran columnas específicas:
- Altas: `asset`, `cap_date`, `pstng_date`, `asset_description2`, `class`, `suma_de_acquisition`
- Bajas: `asset`, `cap_date`, `pstng_date`, `asset_description`, `class`, `retirement`, `depr_retired`, `ret_book_value`
- Transferencias: `asset`, `cap_date`, `pstng_date`, `asset_description2`, `class`, `suma_de_transfer`, `suma_de_trans_o_dep`

**Propuesta:** Tabla de mapeo columna SAP → columna interna, parametrizable si cambia el formato de extracción SAP.

---

## Resumen de propuestas

| # | Constante | Archivo:Línea | Propuesta |
|---|---|---|---|
| 1 | PARAMETROS_RUBROS | utils.R:27 | Tabla versionada por año |
| 2 | CLASS_A_RUBRO | 01_importar_datos.R:48 | Incluir en tabla de rubros |
| 3 | ANIO_CORTE_REVALUO | utils.R:42 | Parámetro en config del ejercicio |
| 4 | CONTEOS_MOVIMIENTOS_ESPERADOS | utils.R:44 | Parámetro por año o eliminar |
| 5 | Tolerancias (4) | utils.R:51-55 | Parámetros configurables |
| 6 | FILAS_HEADER | 01_importar_datos.R:34 | Tabla parametrizable |
| 7 | HOJAS_CATEGORIAS | 01_importar_datos.R:28 | Derivar de tabla de rubros |
| 8 | ALIAS_RUBROS | utils.R:82 | Tabla externa |
| 9 | Exclusiones (600LA, AS, bajas parciales) | 01_importar_datos.R:315-352 | Tabla explícita de exclusiones |
| 10 | Patrón nombre Excel LY | _targets.R:14 | Búsqueda dinámica o parámetro |
| 11 | Filas fijas PG (35, 36) | 01_importar_datos.R:271-272 | Detección dinámica |
| 12 | Nombres columnas SAP | 01_importar_datos.R:298-371 | Tabla de mapeo |
