# T0.1 — Inventario del Código

## Resumen

El proyecto contiene 12 archivos de código R: 8 módulos del pipeline en `R/`, 1 definición de pipeline (`_targets.R`), 1 app Shiny (`app.R`), 1 test (`tests/test_reglas_negocio.R`) y 1 script auxiliar (`install_deps.R`).

---

## Archivos del pipeline (`R/`)

### 1. `R/utils.R` (217 líneas)

**Propósito:** Define constantes globales, parámetros de rubros, funciones utilitarias de normalización, cálculo de VUT y búsqueda de coeficientes.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `check_required_packages()` | 1 | Verifica paquetes instalados |
| `normalizar_clave_activo()` | 67 | Trim de número de activo |
| `normalizar_etiqueta()` | 72 | Minúsculas, sin acentos, sin puntuación |
| `canonizar_rubro()` | 108 | Mapea nombre libre → nombre canónico de rubro |
| `es_fila_detalle_sap()` | 112 | Detecta si una fila SAP es detalle (no totales) |
| `aplicar_excepciones_fecha_base()` | 119 | Override de fecha de reexpresión por activo |
| `calcular_trimestres_primer_anio()` | 158 | `4 - floor((mes_alta - 1) / 3)` |
| `calcular_vut_ly()` | 162 | VUT al cierre del año anterior, en trimestres |
| `calcular_vut_ejercicio()` | 173 | VUT devengada en el ejercicio |
| `buscar_coeficiente()` | 182 | Lookup de coeficiente IPC/IPIM por fecha |
| `obtener_vu_trimestres()` | 194 | VU en trimestres desde PARAMETROS_RUBROS |
| `obtener_vu_asignada()` | 199 | VU operativa: trimestres para Edificios, años para los demás |
| `obtener_periodos_por_anio()` | 210 | 4 para Edificios, 1 para el resto |
| `es_terreno()` | 214 | Retorna TRUE si rubro == "Terrenos" |

**Constantes y tablas:**
| Constante | Línea | Valor / Descripción |
|---|---|---|
| `PARAMETROS_RUBROS` | 27 | Tabla de 11 rubros con clases SAP, VU años/trimestres, índice |
| `ANIO_CORTE_REVALUO` | 42 | `2018` — umbral IPC vs IPIM |
| `CONTEOS_MOVIMIENTOS_ESPERADOS` | 44 | Altas: 4873, Bajas: 1717, Transferencias: 1738 |
| `TOLERANCIA_PRUEBA_GLOBAL` | 51 | `1` ($) |
| `UMBRAL_ERROR_PRUEBA_GLOBAL` | 52 | `100` ($) |
| `TOLERANCIA_CONSISTENCIA_INTERNA` | 53 | `0.01` |
| `TOLERANCIA_VALIDACION_EXTERNA` | 55 | `0.20` (20%) |
| `SCHEMA_EXCEPCIONES_FECHA_BASE` | 57 | Esquema vacío para excepciones |
| `ALIAS_RUBROS` | 82 | Mapeo de nombres alternativos → canónicos (24 entradas) |

**Paquetes:** tibble, stringr, dplyr, stats

**Lee:** nada directamente.
**Escribe:** nada.

---

### 2. `R/01_importar_datos.R` (434 líneas)

**Propósito:** Lectura de todos los insumos: Excel del año anterior (inventario por categoría + índices), movimientos SAP del ejercicio, excepciones de fecha base y archivo de validación externa.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `obtener_rutas_inputs()` | 1 | Retorna rutas de SAP y parametros |
| `leer_excepciones_fecha_base()` | 9 | Lee CSV de excepciones manuales |
| `parsear_fecha_ddmmyyyy()` | 67 | Parsea `dd.mm.yyyy` a Date |
| `parsear_fecha_indice()` | 74 | Parsea fechas flexibles (Date, serial Excel, texto) |
| `leer_hoja_categoria()` | 88 | Lee una hoja del Excel LY con header dinámico |
| `leer_indices_ipim()` | 129 | Lee hoja IPIM (4 columnas) |
| `leer_indices_ipc()` | 143 | Lee hoja IPC (4 columnas) |
| `leer_indices_ipim_bajas()` | 157 | Lee hoja "IPIM - VR Bajas" |
| `leer_indices_ipc_bajas()` | 171 | Lee hoja "IPC - VR Bajas" |
| `leer_inventario_categorias()` | 185 | Itera las 11 hojas de categorías |
| `leer_pg_real()` | 203 | Lee PG y PG AXI del Excel de validación externa |
| `buscar_archivo_real()` | 283 | Busca Excel de validación por año |
| `leer_movimientos_sap()` | 292 | Lee Altas, Bajas y Transferencias del Excel SAP |
| `importar_datos()` | 397 | Orquestador: invoca todas las lecturas |

**Constantes:**
| Constante | Línea | Descripción |
|---|---|---|
| `HOJAS_CATEGORIAS` | 28 | Vector con los 11 nombres de hojas |
| `FILAS_HEADER` | 34 | Lista con fila de skip/header por categoría |
| `CLASS_A_RUBRO` | 48 | Mapeo clase SAP → rubro (16 entradas, incluye 600LA→"Obras en curso") |

**Paquetes:** readxl, readr, dplyr, purrr, tibble, janitor, stringr, lubridate, stats

**Lee:**
- Excel LY (`inputs/parametros/MARG - Revaluo AxI {año}...xlsx`): hojas de 11 categorías + IPC + IPIM + IPC - VR Bajas + IPIM - VR Bajas
- Excel SAP (`inputs/SAP/*.xlsx`): hojas Altas, Bajas, Transferencias
- CSV de excepciones (`inputs/parametros/excepciones_fecha_base.csv`) — opcional
- Excel de validación externa (`inputs/parametros/MARG - Revalúo AxI {año}*.xlsx`): hojas PG y PG AXI

**Escribe:** nada.

---

### 3. `R/02_limpiar_datos.R` (172 líneas)

**Propósito:** Normalización del inventario LY: estandariza columnas, parsea fechas, clasifica tipo de movimiento (histórico / alta / baja / transferencia), filtra IFRS16.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `normalizar_hoja_categoria()` | 9 | Mapea columnas libres a columnas estándar por regex |
| `detectar_tipo_movimiento()` | 104 | Clasifica filas por texto de la primera columna |
| `extraer_anio_movimiento()` | 118 | Extrae año de 4 dígitos del texto de la primera columna |
| `parsear_fecha_alta()` | 124 | Convierte fecha desde múltiples formatos |
| `filtrar_ifrs16()` | 140 | Excluye activos con prefijo "AS" |
| `limpiar_datos()` | 149 | Orquestador: aplica normalización por rubro |

**Constantes:**
| Constante | Línea | Descripción |
|---|---|---|
| `COLUMNAS_ESTANDAR` | 1 | Vector con los 16 nombres de columnas normalizadas |

**Paquetes:** tibble, dplyr, purrr, lubridate, stringr

**Lee/Escribe:** nada (trabaja sobre datos en memoria).

---

### 4. `R/03_construir_rollforward.R` (163 líneas)

**Propósito:** Combina el inventario del año anterior con los movimientos SAP del ejercicio (altas, bajas, transferencias) para producir el inventario actualizado.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `construir_rollforward()` | 3 | Orquestador: agrega movimientos SAP al inventario LY |
| `normalizar_movimiento_sap()` | 109 | Convierte un alta o transferencia SAP al esquema estándar |
| `normalizar_baja_sap()` | 140 | Convierte una baja SAP al esquema estándar |

**Paquetes:** dplyr, tibble, lubridate, purrr

**Lee/Escribe:** nada (trabaja sobre datos en memoria).

**Nota:** Si el inventario LY ya incluye los movimientos del año (caso de los Excel de KPMG), el pipeline detecta esta situación (`tiene_mov_anio`) y no duplica los movimientos SAP (`03_construir_rollforward.R:36`).

---

### 5. `R/04_calculo_axi.R` (285 líneas)

**Propósito:** Módulo central. Calcula amortización histórica y reexpresión por inflación para cada activo.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `calcular_axi()` | 9 | Orquestador: despacha a terrenos o amortizable por rubro |
| `calcular_rubro_amortizable()` | 42 | Calcula VUT, amortización, reexpresión para rubros amortizables |
| `calcular_terrenos()` | 196 | Reexpresa VO de terrenos (sin amortización) |
| `calcular_bajas_reexp()` | 245 | Reexpresión específica para bienes dados de baja |

**Paquetes:** dplyr, tidyr, lubridate

**Lee/Escribe:** nada (trabaja sobre datos en memoria).

---

### 6. `R/05_prueba_global.R` (169 líneas)

**Propósito:** Genera las pruebas globales de cuadre por rubro: amortizaciones, valor residual y AXI.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `generar_prueba_global()` | 1 | Orquestador: llama las tres PG |
| `generar_pg_amortizaciones()` | 17 | PG de amortizaciones: inicio + altas + transf - bajas + ajustes = cierre |
| `generar_pg_valor_residual()` | 82 | PG de VR: inicio + altas + transf - bajas - amort_ejercicio = cierre |
| `generar_pg_axi()` | 141 | PG de AXI: VR reexp - VR hist = AXI resultado |

**Paquetes:** tibble, dplyr, purrr

**Lee/Escribe:** nada.

---

### 7. `R/06_validaciones.R` (402 líneas)

**Propósito:** Suite de validaciones automáticas sobre los resultados del cálculo.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `ejecutar_validaciones()` | 1 | Orquestador: ejecuta todas las validaciones |
| `validar_consistencia_interna()` | 41 | Amort acum == amort_trim × vut_cierre; VR == VO - amort acum |
| `validar_pg_amortizaciones()` | 103 | PG amort: diferencia < tolerancia |
| `validar_pg_valor_residual()` | 131 | PG VR: diferencia < tolerancia |
| `validar_contra_real()` | 159 | Compara contra el Excel externo (Price/KPMG) con tolerancia 20% |
| `validar_vr_formula()` | 253 | VR reexp == VO reexp - amort acum reexp |
| `validar_conteos_movimientos()` | 295 | Conteos de altas/bajas/transf vs esperados |
| `validar_valores_reexpresados_negativos()` | 332 | Detecta VO/VR reexp negativos |
| `validar_excepciones_fecha_base()` | 373 | Reporta excepciones aplicadas |

**Paquetes:** tibble, dplyr, purrr

**Lee/Escribe:** nada.

---

### 8. `R/07_exportar_resultados.R` (257 líneas)

**Propósito:** Genera los archivos Excel de salida: revalúo final, validaciones y resumen.

**Funciones definidas:**
| Función | Línea | Descripción |
|---|---|---|
| `obtener_rutas_outputs()` | 1 | Retorna rutas de reportes, auditoría y excel_final |
| `exportar_resultados()` | 9 | Orquestador: genera los 3 Excel |
| `exportar_excel_revaluo()` | 44 | Una hoja por rubro + PG + PG AXI + índices |
| `exportar_hoja_pg()` | 141 | Escribe hojas PG y PG AXI |
| `exportar_hoja_indices()` | 164 | Escribe hojas IPC e IPIM |
| `exportar_validaciones()` | 176 | Excel con formato condicional (verde/rojo/amarillo) |
| `exportar_resumen()` | 205 | Resumen AXI por rubro con totales |
| `exportar_solo_auditoria()` | 236 | Solo validaciones (cuando hay errores) |

**Paquetes:** openxlsx, tibble

**Lee:** nada.
**Escribe:**
- `outputs/excel_final/MARG_Revaluo_AXI_{año}.xlsx`
- `outputs/auditoria/validaciones_{año}.xlsx`
- `outputs/reportes/resumen_revaluo_{año}.xlsx`

---

## Archivos raíz

### 9. `_targets.R` (40 líneas)

**Propósito:** Define el pipeline de targets con la secuencia de ejecución.

**Targets definidos (en orden):**
1. `datos_crudos` ← `importar_datos()`
2. `datos_limpios` ← `limpiar_datos()`
3. `inventario` ← `construir_rollforward()`
4. `axi` ← `calcular_axi()`
5. `prueba_global` ← `generar_prueba_global()`
6. `pg_real` ← `leer_pg_real()` (opcional)
7. `validacion` ← `ejecutar_validaciones()`
8. `resultados_exportados` ← `exportar_resultados()` o `exportar_solo_auditoria()`

**Parámetros globales:**
- `ANIO_EJERCICIO`: variable de entorno o año actual - 1
- `PATH_EXCEL_LY`: ruta al Excel del año anterior

**Paquetes:** targets, tidyverse, readxl, openxlsx, janitor, lubridate, readr

---

### 10. `app.R` (946 líneas)

**Propósito:** Frontend Shiny que envuelve el pipeline en una interfaz paso a paso.

**Estructura:**
- **UI:** sidebar con parámetros + carga de archivos; mainPanel con 6 pasos + referencias
- **Server:** ejecuta el pipeline secuencialmente (pasos 1-6), renderiza tablas por paso, ofrece descarga de 3 Excel

**Paquetes:** shiny, tidyverse, readxl, openxlsx, janitor, lubridate

**Lee:** los mismos archivos que el pipeline (vía funciones de `R/`).
**Escribe:** archivos temporales en `tempdir()` para descarga.

---

### 11. `tests/test_reglas_negocio.R` (169 líneas)

**Propósito:** Tests manuales con `stopifnot()` que verifican reglas de negocio clave.

**Tests cubiertos:**
- VU asignada: Edificios = 200 trimestres, Rodados = 5 años
- Periodos por año: Edificios = 4, Rodados = 1
- Amortización de Edificios y Rodados (año completo y parcial)
- Amortización con baja
- Normalización de movimientos SAP (altas y bajas)
- Excepciones de fecha base
- Detección de filas detalle SAP
- Rollforward con históricos + altas + bajas + transferencias

**Paquetes:** tidyverse

---

### 12. `install_deps.R` (27 líneas)

**Propósito:** Script de diagnóstico de conexión e instalación de paquetes.

---

## Resumen de paquetes utilizados

| Paquete | Usado en |
|---|---|
| shiny | app.R |
| tidyverse (dplyr, purrr, tibble, stringr, lubridate, readr) | Todos los módulos |
| readxl | 01_importar_datos.R, app.R |
| openxlsx | 07_exportar_resultados.R, app.R |
| janitor | 01_importar_datos.R (clean_names) |
| targets | _targets.R |
| tidyr | 04_calculo_axi.R (replace_na) |

## Estructura de directorios

```
Revaluo-Bienes-de-Uso/
  R/
    utils.R
    01_importar_datos.R
    02_limpiar_datos.R
    03_construir_rollforward.R
    04_calculo_axi.R
    05_prueba_global.R
    06_validaciones.R
    07_exportar_resultados.R
  _targets.R
  app.R
  tests/
    test_reglas_negocio.R
  install_deps.R
  inputs/
    SAP/              ← Excel de Altas/Bajas/Transferencias
    parametros/       ← Excel LY, Excel de validación externa
    altas/            ← vacío (placeholder)
    bajas/            ← vacío (placeholder)
    transferencias/   ← vacío (placeholder)
  data/
    raw/              ← vacío
    intermediate/     ← vacío
    processed/        ← vacío
  outputs/
    excel_final/      ← MARG_Revaluo_AXI_{año}.xlsx
    auditoria/        ← validaciones_{año}.xlsx
    reportes/         ← resumen_revaluo_{año}.xlsx
  docs/
    flujo_proceso.md
    metodologia.md
    reglas_negocio.md
```
