# Fase 0.5 — Impacto de Brechas y Análisis Normativo

## 1. Unidad real de VU, VUT_LY y VUT en el Excel del estudio 2023

Verificación hoja por hoja del Excel `MARG - Revalúo AxI 2023_VF pruebas.xlsx`:

| Rubro | Texto del estudio | VU en el estudio | VUT en el estudio | Instrucción para año siguiente |
|---|---|---|---|---|
| **Edificios** | "Se amortizan en 200 trimetres (50 años)." | 200 trimestres | **Trimestres** | "sumarle 4 (Trimestres) a la columna de VUT" |
| **Cercos** | "Se amortizan en 50 años." | 50 años | **Años** | "sumarle 1 año a la columna de VUT" |
| **Eq de Oficina** | "Se amortizan en 3 años." | 3 años | **Años** | "sumarle 1 año a la columna de VUT" |
| **Máquinas y Equipos** | "Se amortizan en 10 años." | 10 años | **Años** | "sumarle 1 año a la columna de VUT" |
| **Máquinas Mejoras** | (sin texto explícito; sigue patrón Máquinas) | 10 años | **Años** | — |
| **MyU** | (sin texto explícito; sigue patrón Eq Oficina) | 3 años | **Años** | — |
| **Rodados** | "Se amortizan en 5 años." | 5 años | **Años** | (no explícito; consistente con "1 año") |
| **Terreno Mejoras** | (130LA, 250LA) | 10 años | **Años** | "sumarle 1 año a la columna de VUT" |
| **Software** | (510LA, 515LA, 610LA) | 3 años | **Años** | — |
| **Estructuras y caños** | "Hace tiempo que no se dan de alta bienes de este tipo" | 10 años | **Años** | — |
| **Terrenos** | (110LA) | 0 (no amortiza) | N/A | N/A |

**Hallazgo adicional:** El shared string "Bienes con amort. irregular (paso de trimestre de alta a año completo)" indica que hubo una migración de algunos activos de cálculo trimestral a anual. Esto confirma que **el estudio usa años (no trimestres) para todos los bienes muebles**.

**Conclusión para Tarea 1:** Ningún rubro de bienes muebles está calculado en trimestres en el estudio. Solo Edificios usa trimestres. Esto **coincide** con el criterio normativo (Ley de Ganancias: inmuebles 2% anual = 200 trimestres; muebles en años).

El código R (`utils.R:199-208`, `utils.R:210-212`) implementa correctamente esta distinción: `obtener_vu_asignada()` retorna trimestres para Edificios y años para el resto; `obtener_periodos_por_anio()` retorna 4 para Edificios y 1 para el resto.

---

## 2. B-04 revisada: VUT fraccionario en no-Edificios

### Dónde y por qué el R genera fracciones

El problema está en `04_calculo_axi.R:77-82`:

```r
vut_ly = dplyr::if_else(
  !is.na(vut_ly),
  vut_ly,                                          # si viene del LY → se usa directo
  calcular_vut_ly(anio_alta, mes_alta, ...) /      # calcula en TRIMESTRES
    4L * periodos_por_anio                          # divide por 4, multiplica por 1
)
```

La función `calcular_vut_ly()` (`utils.R:162-171`) **siempre calcula en trimestres**:
```r
vut = (anio_ejercicio - anio_alta - 1) * 4 + trim_primer_anio
```

Donde `trim_primer_anio = 4 - floor((mes_alta - 1) / 3)` da 4 (Q1), 3 (Q2), 2 (Q3), 1 (Q4).

Para no-Edificios (`periodos_por_anio = 1`), la conversión es `vut_trim / 4`:

| Ejemplo | anio_alta | mes_alta | anio_ej | trim_1er_año | vut_trim | vut_ly = vut_trim/4 |
|---|---|---|---|---|---|---|
| Alta Q1 | 2020 | 1 | 2023 | 4 | (2×4)+4 = 12 | **3.00** |
| Alta Q2 | 2020 | 4 | 2023 | 3 | (2×4)+3 = 11 | **2.75** |
| Alta Q3 | 2020 | 7 | 2023 | 2 | (2×4)+2 = 10 | **2.50** |
| Alta Q4 | 2020 | 10 | 2023 | 1 | (2×4)+1 = 9 | **2.25** |

**Solo las altas del Q1 dan entero.** Las altas de Q2, Q3 y Q4 producen VUT_LY fraccionario (0.75, 0.50, 0.25).

### Activos afectados

Todos los bienes muebles cuyo `vut_ly` NO viene del Excel LY y cuya fecha de alta no cae en Q1 (enero-marzo). Esto ocurre cuando:
- El LY no tiene columna "VUT LY" (poco probable para datos históricos)
- O el valor de VUT LY del Excel es NA

En la práctica, **cuando el dato viene del LY, se usa directo y no hay fracción**. La fracción solo aparece cuando el R recalcula VUT_LY para datos nuevos (altas/transferencias SAP sin VUT_LY previo).

### Impacto

Para un Rodado dado de alta en abril (Q2) con VO=100.000 y VU=5:
- VUT_LY(R) = 2.75 → amort_acum_ly = 100.000/5 × 2.75 = **55.000**
- VUT_LY(correcto) = 3 (años enteros, año de alta completo) → amort_acum_ly = 100.000/5 × 3 = **60.000**
- Diferencia: **$5.000** por activo

**Este es un error, no una diferencia de criterio.** La Ley de Ganancias dice que para bienes muebles, el año de alta cuenta como año completo. El VUT debe ser entero.

### Corrección propuesta (para Fase 1)

Para no-Edificios, `vut_ly` debería calcularse como:
```r
vut_ly = if_else(anio_alta >= anio_ejercicio, 0, anio_ejercicio - anio_alta)
```
Sin pasar por trimestres. Esto da años enteros y el año de alta se cuenta completo.

---

## 3. B-06 reclasificada: primer año completo para bienes muebles

**Clasificación actualizada: CRITERIO CORRECTO.**

El código R (`04_calculo_axi.R:60-64`) asigna `trim_primer_anio = 1` para todos los no-Edificios, lo que hace que el año de alta siempre cuente completo. Esto coincide con:
- La norma (Ley de Ganancias: año de alta = año completo para muebles)
- El estudio (todas las instrucciones dicen "sumarle 1 año a VUT")

**Verificación contra el estudio:** El texto "Para realizar el calculo de amortizacion del proximo año solo hay que sumarle 1 año a la columna de VUT" aparece en Cercos, Eq de Oficina, Maquinas y Equipos, y Terreno Mejoras. Rodados dice "Se amortizan en 5 años" sin detallar el prorrateo, pero el patrón es consistente.

**Excepción — Edificios:** Para Edificios, el estudio calcula "Trimestres 1° Año de Alta" y usa amortización trimestral. El trimestre de alta cuenta completo, coincide con el R.

---

## 4. Tratamiento de bajas en el R

### Bienes muebles (no-Edificios)

**Código:** `04_calculo_axi.R:65-66,84-91`

```r
periodos_hasta_baja <- rep.int(periodos_por_anio, nrow(inv))  # = 1 para no-Edificios
```

Luego:
```r
vut_ejercicio = pmin(
  if_else(anio_alta == anio_ejercicio, trim_primer_anio, periodos_hasta_baja),
  vu_asignada - vut_ly
)
```

Para no-Edificios con baja: `periodos_hasta_baja = 1`, así que **se amortizan 1 año completo** en el año de baja.

**Criterio normativo:** "Año de baja = sin amortización" (Ley de Ganancias).

**Conclusión:** El R amortiza 1 año en el año de baja para bienes muebles. Según la norma, debería ser 0. **Esto es un error.**

Sin embargo, la PG del estudio muestra fila "Amortización de las bajas" con valores no-cero (Row 17 del PG), lo que sugiere que el estudio SÍ calcula alguna amortización para bajas. Verificar si el estudio sigue la norma estricta o un criterio diferente requiere examinar activos individuales de baja.

### Edificios (amortización trimestral de bajas)

**Código:** `04_calculo_axi.R:66-69`

```r
es_baja_edificio <- rubro_nombre == "Edificios" &
  inv$tipo_movimiento_calc == "baja" & !is.na(inv$fecha_baja)
periodos_hasta_baja[es_baja_edificio] <-
  as.integer(floor((lubridate::month(inv$fecha_baja[es_baja_edificio]) - 1L) / 3L) + 1L)
```

**Resultado:** Para Edificios, se amortiza hasta el trimestre de la baja (inclusive):
- Baja en enero-marzo → 1 trimestre
- Baja en abril-junio → 2 trimestres
- Baja en julio-septiembre → 3 trimestres
- Baja en octubre-diciembre → 4 trimestres (año completo)

**Criterio normativo para inmuebles:** La Ley de Ganancias no especifica prorrateo trimestral de bajas para inmuebles, pero dado que la amortización es trimestral, contar hasta el trimestre de baja es razonable. El estudio usa este criterio (por la estructura de las fórmulas observadas).

---

## 5. Índice para bienes desde 2018: IPC vs IPIM

### Qué usa el R

**Código:** `04_calculo_axi.R:135-147`

```r
coef_ipc = if_else(anio_alta >= ANIO_CORTE_REVALUO,
                   buscar_coeficiente(fecha_indice_reexp, indices_ipc), 1)
coef_ipim = buscar_coeficiente(fecha_indice_reexp, indices_ipim)

vo_reexp = if_else(anio_alta >= 2018, vo * coef_ipc, vo * coef_ipim)
```

- **Bienes ≥ 2018:** usan **IPC**. Correcto según Ley 27.430/27.468.
- **Bienes < 2018:** usan **IPIM**. Esto NO es el escenario base de la norma (coef=1).

### Qué usa el estudio

El Excel del estudio 2023 tiene hojas "IPC" e "IPIM e IPC". La columna "Coeficiente" en el PG muestra valores > 1 para bienes post-2018 y = 1 (o IPIM) para pre-2018.

Dado que la columna M (TOTAL) de la PG del estudio dice amort s/revalúo = $1.179.524.957 (histórica) vs la PG AXI que dice $5.510.659.529 (reexpresada), el ratio es ~4.67x, lo cual es consistente con inflación Argentina 2018-2023 aplicada selectivamente.

**Conclusión:** El R usa IPC para ≥ 2018 (**correcto**). Para < 2018, el R usa IPIM (criterio de confiscatoriedad) en vez de coef=1 (criterio normativo base). Según la instrucción del usuario: **coeficiente pre-2018 = 1 por defecto, con switch a IPIM/IPC como escenario B.**

---

## 6. Tabla comparativa R vs Estudio — Hoja PG 2023

> **Nota:** No fue posible ejecutar el pipeline R en esta sesión (readxl/openxlsx crashean con segfault en R 4.6.1 — los paquetes necesitan recompilación). Los datos del estudio se extrajeron del XML del Excel. La comparación completa requiere ejecutar `tar_make()` y volcar la PG del R.

### Datos del estudio 2023 (extraídos de la hoja PG)

Mapeo de columnas del PG: B=Cercos, C=Edificios, D=Terrenos, E=Estructuras y caños, F=Eq de Oficina, G=Maquinas y Equipos, H=Maquinas Mejoras, I=MyU, J=Rodados, K=Terreno Mejoras, L=Software.

**Amortización acumulada s/revalúo (Row 19-20 PG):**

| Rubro | Amort s/prueba ($) | Amort s/revalúo ($) | Diferencia ($) |
|---|---|---|---|
| Cercos | 2.550 | 2.550 | 0 |
| Edificios | 39.733.727 | 39.733.727 | 0 |
| Terrenos | 0 | 0 | 0 |
| Estructuras y caños | 0 | 0 | 0 |
| Eq de Oficina | 104.286.242 | 104.286.242 | 0 |
| Maquinas y Equipos | 404.710.723 | 404.716.027 | **-5.304** |
| Maquinas Mejoras | 1.219.750 | 1.219.750 | 0 |
| MyU | 44.924.626 | 44.924.626 | 0 |
| Rodados | 316.048.703 | 316.048.703 | 0 |
| Terreno Mejoras | 40.837.468 | 40.837.468 | 0 |
| Software | 227.761.168 | 227.761.168 | 0 |
| **TOTAL** | **1.179.524.957** | **1.179.530.261** | **-5.304** |

**Valor residual s/revalúo (Row 35-36 PG):**

| Rubro | VR s/prueba ($) | VR s/revalúo ($) | Diferencia ($) |
|---|---|---|---|
| Cercos | 2.580 | 2.580 | 0 |
| Edificios | 2.600.198.170 | 2.600.198.170 | 0 |
| Terrenos | 245.932.359 | 245.932.359 | 0 |
| Eq de Oficina | 93.979.868 | 93.979.868 | 0 |
| Maquinas y Equipos | 3.001.724.926 | 3.001.739.179 | **-14.253** |
| Maquinas Mejoras | 2.401.160 | 2.401.160 | 0 |
| MyU | 59.717.119 | 59.728.530 | **-11.411** |
| Rodados | 970.220.355 | 970.220.355 | 0 |
| Terreno Mejoras | 332.969.741 | 332.969.741 | 0 |
| Software | 278.346.781 | 278.346.781 | 0 |
| **TOTAL** | **7.585.493.061** | **7.585.518.724** | **-25.664** |

Las diferencias internas del estudio ($5.304 en Maquinas amort, $14.253 en Maquinas VR, $11.411 en MyU VR) son < 0.001% del total y se atribuyen a redondeo, como indica el propio estudio.

**VR Reexpresado (PG AXI Row 36-37):**

| Rubro | VR Reexp s/prueba ($) | VR Reexp s/revalúo ($) | Diferencia ($) |
|---|---|---|---|
| **TOTAL** | **29.196.822.605** | **29.196.848.269** | **-25.664** |

### Para completar la comparación R vs Estudio

Ejecutar en la máquina local:
```r
# En la consola de R con paquetes funcionales:
source("R/utils.R")
source("R/01_importar_datos.R")
source("R/02_limpiar_datos.R")
source("R/03_construir_rollforward.R")
source("R/04_calculo_axi.R")
source("R/05_prueba_global.R")
source("R/06_validaciones.R")

datos <- importar_datos("inputs/parametros/MARG - Revalúo AxI 2023_VF pruebas.xlsx", "inputs")
datos <- limpiar_datos(datos, 2023)
datos <- construir_rollforward(datos, 2023)
datos <- calcular_axi(datos, 2023)
datos <- generar_prueba_global(datos, 2023)

# Comparar:
datos$prueba_global$amortizaciones  # vs tabla de arriba
datos$prueba_global$valor_residual  # vs tabla de arriba
datos$prueba_global$axi             # vs PG AXI
```

### Brechas esperadas en la comparación R vs Estudio

| Brecha | Rubros afectados | Dirección esperada | Magnitud estimada |
|---|---|---|---|
| **B-01** (IPIM vs coef=1 para pre-2018) | Todos los rubros con bienes pre-2018 | VR_R del R será **mayor** que el estudio (IPIM > 1) | **Alta** — puede ser del orden de miles de millones $ dada la inflación acumulada |
| **B-02** (sin corte pre-1992) | Edificios, Terreno Mejoras, Cercos | Coeficiente incorrecto para bienes muy antiguos | **Media** — pocos activos afectados pero coef muy diferente |
| **B-04** (VUT fraccionario) | Todos los muebles con altas SAP no-Q1 | Amortización del R será **menor** (VUT_LY subestimado) | **Baja** — solo afecta datos sin VUT_LY del Excel |
| **B-08** (transf_dep no usada) | Rubros con transferencias | Amort acum puede diferir si el recálculo no coincide | **Variable** |

---

## 7. Preguntas marcadas como RESUELTAS

Las siguientes preguntas de `docs/preguntas_abiertas.md` quedan resueltas con el criterio normativo indicado por el usuario:

| Pregunta | Resolución |
|---|---|
| **PA-01** (Coeficiente pre-2018) | **RESUELTA.** Coeficiente = 1 por defecto (Ley de Ganancias). Switch a IPIM o IPC como escenario B. |
| **PA-02** (Pre-1992) | **RESUELTA.** Corte automático a 01/01/1992. |
| **PA-04** (Prorrateo primer año muebles) | **RESUELTA.** Año de alta = año completo (norma). El R lo hace correctamente. |
| **PA-06** (Transferencias) | **RESUELTA.** Mover VO y amortización acumulada juntos (usar `transf_dep`). |
| **PA-11** (Insumos faltantes) | **PARCIALMENTE RESUELTA.** Rodados = 5 años, unidad = años. Altas y bajas del mismo año se netean. Clases fuera de la tabla no se calculan pero se reportan. Edificios en trimestres, resto en años. |

**Preguntas que siguen abiertas:**

| Pregunta | Estado |
|---|---|
| PA-03 (Bajas parciales) | Abierta — ¿se ignoran o se tratan proporcionalmente? |
| PA-05 (Índices separados para bajas) | Abierta — no aclarada por el criterio normativo |
| PA-07 (Amortización en año de baja para muebles) | **NUEVA EVIDENCIA:** la norma dice 0 en año de baja; el R calcula 1 año. Verificar qué hace el estudio |
| PA-08 (Fecha de índice para bajas SAP) | Abierta |
| PA-09 (Año archivo vs Año a tomar vs Año alta) | Abierta |
| PA-10 (Columna 4 de tabla IPC) | Abierta |
| PA-12 (Conteos esperados) | Abierta |
| PA-13 (Columna indice en PARAMETROS_RUBROS) | Abierta |
| PA-14 (VU Edificios en LY: ¿trimestres o años?) | Abierta |
| PA-15 (Redondeo) | Abierta |

---

## 8. Actualización al Diccionario de Cálculos

Ver `docs/04_diccionario_calculos.md` — actualizado con columna "Norma" en cada ficha relevante.
