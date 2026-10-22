# SPEC — Revalúo Impositivo de Bienes de Uso (AxI)
**Proyecto:** Automatización del revalúo impositivo anual de bienes de uso — Monsanto Argentina SRL (Bayer)
**Entorno de desarrollo:** Claude Code
**Versión de la spec:** 1.0 (2026-10-21)
**Estado:** Fase 0 (análisis del código R existente). No se desarrolla nada hasta aprobar el diccionario de cálculos.

---

## 0. Instrucciones para Claude Code (leer primero)

1. **Esta etapa es de análisis, no de desarrollo.** En la Fase 0 NO se modifica, refactoriza ni "mejora" el código R. Solo se lee, se ejecuta en modo lectura si hace falta y se documenta.
2. **Los archivos fuente son de solo lectura.** No sobrescribir los Excel de entrada ni el código R original. Trabajar sobre copias en `/work` o en una rama git.
3. **Nada se asume.** Si una fórmula, columna o regla no está clara en el código, se registra en `docs/preguntas_abiertas.md`. No se inventa la regla.
4. **Cada afirmación lleva su ubicación** en el código: `archivo.R:línea` o `función()`.
5. **Al terminar la Fase 0, detenerse** y presentar los entregables para revisión. No avanzar a la Fase 1 sin aprobación explícita.
6. Idioma de toda la documentación: **español**.

---

## 1. Contexto del proceso de negocio

Cada año se realiza el revalúo impositivo (ajuste por inflación impositivo) de los bienes de uso:

1. Se toma la **base del año anterior** (activos con su valor de origen, fechas y amortización).
2. Se **suman las altas** del año y se **incorporan las transferencias**.
3. Se **restan las bajas** del año.
4. Se calcula, por rubro, la **amortización acumulada**, la **amortización del ejercicio** y el **valor residual**.
5. Se **reexpresan** los valores por inflación (coeficientes IPC).
6. Se hacen **pruebas globales** y se compara con el estudio externo.

Objetivo final: un motor que tome la base del año anterior más los movimientos del año y calcule todo según reglas parametrizadas, con un frontend. Hoy existe un desarrollo en R y un modelo de referencia del estudio externo para 2023.

---

## 2. Insumos disponibles

| Insumo | Contenido | Uso en la Fase 0 |
|---|---|---|
| Código R existente | Desarrollo propio del revalúo | **Objeto principal del análisis** |
| `MARG-Revaluo-2023.xlsx` | Modelo del estudio externo 2023: 20 hojas, 56.404 activos y la hoja PG de pruebas globales | Referencia contra la que se compara cada fórmula del R |
| `Libro1.xlsx` | Reconstrucción parcial interna (Edificios, Altas y Transferencias) | Referencia secundaria |
| `Altas-bajas-Transf.xlsx` | Movimientos 2023 desde SAP: 4.876 altas, 4.045 bajas y 1.743 transferencias | Datos de entrada |
| `Reglas-Revaluo.xlsx` / `Presentacion.xlsx` | Reglas, glosario y clasificación por rubros | Fuente de reglas de negocio |
| `ipc_table.json` | Coeficientes IPC (2.191 registros diarios, 2018-2023) | Fuente de coeficientes |

> Si algún insumo no está en el repositorio, listarlo como faltante en `docs/preguntas_abiertas.md` y continuar con lo disponible.

---

## 3. FASE 0 — Análisis del código R (alcance actual)

### 3.1 Tareas

**T0.1 — Inventario del código**
- Listar todos los archivos `.R`, `.Rmd`, scripts de Shiny y configuraciones.
- Para cada archivo: propósito, funciones que define, paquetes que usa y archivos que lee o escribe.
- Entregable: `docs/01_inventario_codigo.md`

**T0.2 — Flujo de ejecución de punta a punta**
- Orden en que se ejecutan los scripts y funciones.
- Diagrama (Mermaid) del flujo de datos: archivos de entrada → transformaciones → cálculos → salidas.
- Identificar qué pasos son manuales: archivos que hay que tocar a mano, parámetros hardcodeados, rutas fijas.
- Entregable: `docs/02_flujo_ejecucion.md`

**T0.3 — Mapeo de datos de entrada**
- Para cada archivo de entrada: hojas o columnas que se leen, nombre original de la columna y nombre que toma en R.
- Tipo de dato y transformaciones aplicadas (limpieza, cambio de formato de fechas, filtros, joins).
- Claves de unión entre tablas (número de activo, subnúmero, clase).
- Entregable: `docs/03_mapeo_entradas.md`

**T0.4 — DICCIONARIO DE CÁLCULOS (entregable principal)**
- Una ficha por cada concepto (ver la lista mínima en la sección 4), con el formato de la sección 3.2.
- Entregable: `docs/04_diccionario_calculos.md`

**T0.5 — Comparación contra la referencia del estudio externo 2023**
- Para cada concepto, comparar la fórmula del R con la fórmula de referencia (sección 4) y con las celdas del Excel del estudio.
- Elegir **un activo real por rubro** (11 rubros) y hacer la traza numérica completa: valor en el R contra el valor en el Excel del estudio.
- Clasificar cada diferencia como **Idéntica**, **Diferencia de criterio**, **Error** o **No implementado**.
- Entregable: `docs/05_brechas_vs_referencia.md`

**T0.6 — Reglas hardcodeadas**
- Listar toda constante de negocio que esté en el código: vidas útiles, códigos excluidos, fechas de corte, años de corte y redondeos.
- Para cada una, indicar dónde está y proponer que pase a una tabla de parámetros. Es solo una propuesta; no se implementa.
- Entregable: `docs/06_parametros_hardcodeados.md`

**T0.7 — Preguntas abiertas**
- Todo lo ambiguo, lo contradictorio o lo que necesita decisión de negocio.
- Entregable: `docs/preguntas_abiertas.md`

### 3.2 Formato obligatorio de cada ficha del diccionario

```markdown
### [Nombre del concepto]  (sigla: XX)

| Campo | Detalle |
|---|---|
| Definición | Qué representa, en lenguaje de negocio |
| Tipo | Dato de entrada / Parámetro / Calculado |
| Origen del dato | Si es entrada: archivo, hoja, columna y transformación. Si es parámetro: tabla y valor. Si es calculado: conceptos de los que depende |
| Fórmula (notación) | p. ej. `AA = (VO / VU) × min(VUT, VU)` |
| Fórmula explicada | Paso a paso en palabras, incluido qué pasa en cada caso borde |
| Unidad | $, trimestres, años, coeficiente |
| Redondeo | Si redondea, en qué paso y a cuántos decimales |
| Casos borde | VU agotada, terrenos, pre-1992, pre-2018, altas y bajas del mismo año, transferencias, valores negativos o cero |
| Ubicación en R | `archivo.R:línea` / `función()` |
| Equivalente en el modelo del estudio | Hoja, columna y fórmula Excel |
| Coincide con la referencia | Sí / No / Parcial, con explicación |
| Ejemplo numérico | Un activo real con todos los valores intermedios |
```

---

## 4. Diccionario de referencia (lo que ya sabemos)

Esta es la **lógica de referencia** reconstruida del modelo del estudio externo 2023 y de las reglas confirmadas por el usuario. Claude Code debe **verificar cada punto contra el código R** y contra el Excel del estudio. Los puntos marcados **[A CONFIRMAR]** no están cerrados y deben resolverse en la Fase 0.

### 4.1 Datos de identificación y clasificación

| Concepto | Tipo | Origen / regla |
|---|---|---|
| **N° de activo + subnúmero** | Entrada | SAP / base del año anterior. Es la clave única del activo. |
| **Clase SAP** | Entrada | SAP. Determina el rubro según la tabla 4.2. |
| **Rubro** | Derivado | Lookup de la clase SAP en la tabla de rubros (4.2). Las clases fuera de la tabla **no se consideran**. |
| **Exclusiones** | Regla | Se excluyen: 600LA (obras en curso), 9050/9150/9250/9350 (leasing IFRS 16), 495LA (deterioros), 9750 (otros) y los activos "AS" (IFRS 16). |

### 4.2 Parámetros por rubro

| Rubro | Clases SAP | VU (años) | VU (trimestres) | Unidad usada en el cálculo |
|---|---|---|---|---|
| Edificios | 210LA, 220LA, 392LA | 50 | 200 | Trimestres |
| Terrenos | 110LA | — | 0 | No amortiza |
| Eq. de Oficina | 320LA | 3 | 12 | Trimestres |
| Máquinas y Equipos | 310LA, 350LA | 10 | 40 | Trimestres |
| Máquinas Mejoras | 370LA | 10 | 40 | Trimestres |
| Muebles y Útiles | 330LA | 3 | 12 | Trimestres |
| Rodados | 360LA | 5 | 20 | **Años** (en el estudio, VU y VUT de Rodados están en años) |
| Terreno Mejoras | 130LA, 250LA | 10 | 40 | Trimestres |
| Software | 510LA, 515LA, 610LA | 3 | 12 | Trimestres |
| Cercos | (en desuso) | 50 | 200 | Trimestres |
| Estructuras y caños | (en desuso) | 10 | 40 | Trimestres |

### 4.3 Fechas

**Fecha de alta original (FA)**
- *Origen:* Posting Date (Pstng Date) del activo en SAP. Para activos existentes viene de la base del año anterior.
- [A CONFIRMAR] Verificar qué fecha usa el R: Posting Date, Capitalization Date u otra.

**Fecha ajustada (FAJ)**
- *Fórmula:* `FAJ = SI(año(FA) < 1992 ; 01/01/1992 ; FA)`
- *Explicación:* los bienes dados de alta antes de 1992 se tratan como si hubieran entrado el 01/01/1992. La fecha ajustada se usa tanto para la vida útil transcurrida como para el coeficiente.

**Año a tomar / año de alta**
- *Fórmula:* `AÑO_ALTA = año(FAJ)`
- En el estudio existen las columnas "año archivo", "año a tomar" y "año alta" (Edificios: columnas 5, 6 y 7). [A CONFIRMAR] Documentar la diferencia entre las tres y cuál usa el R.

**Trimestre de alta**
- *Fórmula:* `TRIM_ALTA = REDONDEAR.MAS(mes(FAJ) / 3 ; 0)` → enero-marzo = 1, abril-junio = 2, julio-septiembre = 3, octubre-diciembre = 4.

### 4.4 Valor de origen (VO)

- *Tipo:* dato de entrada. No se calcula.
- *Origen:*
  - **Activos existentes:** VO de la base del año anterior (columna VO del archivo de revalúo previo).
  - **Altas del año:** valor de adquisición del reporte de altas SAP.
  - **Transferencias:** el VO se traslada del activo origen al activo destino (lógica del estudio: VO y amortización acumulada viajan juntos).
  - **Bajas:** se toma el VO del activo dado de baja, se revalúa y luego se retira.
- *Neteo:* si un activo tiene alta y baja en el mismo año, se netean.
- [A CONFIRMAR] Bajas parciales: ¿se tratan de forma proporcional? Transferencias: ¿conservan la fecha de alta original del activo origen?

### 4.5 Vida útil (VU)

- *Tipo:* parámetro.
- *Fórmula:* `VU = lookup(Rubro, tabla 4.2)`
- *Explicación:* en trimestres, salvo Rodados (años). Terrenos = 0, sin amortización.

### 4.6 Vida útil transcurrida al cierre anterior (VUT_LY) y al cierre actual (VUT)

- *Tipo:* calculado. En el estudio, VUT_LY también puede venir de la base del año anterior.
- *Fórmula de referencia [A CONFIRMAR el conteo exacto]:*
  ```
  VUT = (AÑO_CIERRE − AÑO_ALTA) × 4 + (4 − TRIM_ALTA + 1)
  VUT_LY = VUT − 4            (si el alta es anterior al año de análisis)
  VUT_LY = 0                  (si es alta del año)
  ```
- *Explicación:* cuenta los trimestres desde el trimestre de alta (incluido) hasta el 31/12 del año de análisis.
- **Claude Code debe verificar en el R y en el Excel del estudio** si el trimestre de alta se cuenta completo, si se cuenta desde el trimestre siguiente o si es otra convención. Es el punto más sensible del cálculo.
- *Rodados:* el mismo concepto, pero en años: `VUT = AÑO_CIERRE − AÑO_ALTA (+1 si cuenta el año de alta) [A CONFIRMAR]`.

### 4.7 Amortización por período (cuota)

- *Fórmula:* `CUOTA = VO / VU`
- *Explicación:* amortización lineal; cuota fija por trimestre (o por año en Rodados). Si VU = 0 (Terrenos), cuota = 0.

### 4.8 Amortización acumulada al cierre (AA)

- *Fórmula:* `AA = CUOTA × min(VUT ; VU) = (VO / VU) × min(VUT ; VU)`
- *Explicación:* cantidad de períodos transcurridos por la cuota, con tope en la vida útil. Si `VUT ≥ VU`, el bien está totalmente amortizado y `AA = VO`. Para Terrenos, `AA = 0`.

### 4.9 Amortización acumulada al inicio (AA_LY)

- *Fórmula:* `AA_LY = CUOTA × min(VUT_LY ; VU)`
- *Origen alternativo:* la amortización acumulada de la base del año anterior.
- **Control:** el AA_LY calculado tiene que coincidir con el AA del archivo del año anterior. Si no coincide, se registra como diferencia.

### 4.10 Amortización del ejercicio (AE)

- *Fórmula:* `AE = AA − AA_LY = CUOTA × [min(VUT ; VU) − min(VUT_LY ; VU)]`
- *Explicación:* períodos amortizados dentro del año por la cuota. Si la vida útil ya estaba agotada al inicio, AE = 0. En el año en que se agota, solo se amortizan los períodos restantes.
- *Rodados:* `AE = CUOTA × (VUT − VUT_LY)`, en años y con tope en VU.

### 4.11 Valor residual (VR)

- *Fórmula:* `VR = max(VO − AA ; 0)`
- *Explicación:* valor pendiente de amortizar al cierre, nunca negativo. Para Terrenos, `VR = VO`.

### 4.12 Coeficiente de actualización (COEF)

- *Tipo:* calculado por lookup.
- *Fórmula de referencia (estudio):*
  ```
  COEF = SI(año(FAJ) < 2018 ; 1 ; BUSCARV(FAJ ; tabla_IPC ; columna 4 ; FALSO))
  ```
- *Explicación:*
  - **Bienes con fecha anterior a 2018:** coeficiente = 1 (se mantienen a valor histórico) en el **escenario A**, que es el criterio del estudio y el de base. En el **escenario B**, alternativo, se aplica el IPC real. Tiene que existir un switch de escenario.
  - **Bienes desde 2018:** coeficiente de la tabla IPC según la fecha ajustada de alta.
- *Origen:* `ipc_table.json`, con registros diarios. [A CONFIRMAR] Documentar cómo se construye la columna 4 (IPC de cierre / IPC del mes de alta u otra fórmula), qué índice base usa y qué pasa si la fecha no está en la tabla.

### 4.13 Valores reexpresados

| Concepto | Fórmula | Explicación |
|---|---|---|
| **VO reexpresado** | `VO_R = VO × COEF` | Valor de origen en moneda de cierre |
| **AA reexpresada** | `AA_R = AA × COEF` | Amortización acumulada en moneda de cierre |
| **AE reexpresada** | `AE_R = AE × COEF` [A CONFIRMAR] | Amortización impositiva del ejercicio actualizada |
| **VR reexpresado** | `VR_R = VR × COEF` (equivale a `VO_R − AA_R`) | Valor residual impositivo actualizado |

### 4.14 Tratamiento de bajas

- Se calcula todo el revalúo del bien a la fecha de baja (VO, AA, VR y reexpresados) y **luego se retira** de la base.
- [A CONFIRMAR] ¿Se amortiza el año de la baja? ¿Hasta qué trimestre? ¿Se calcula el resultado impositivo de la venta (precio − VR reexpresado)?

### 4.15 Tratamiento de transferencias

- Lógica del estudio: se trasladan **VO y AA juntos** del activo origen al destino, con seguimiento por separado.
- [A CONFIRMAR] ¿Se mantiene la fecha de alta del origen? ¿Qué pasa si origen y destino son de rubros con distinta VU?

### 4.16 Pruebas globales (hoja PG del estudio)

- *Por rubro:* totales de VO, AA, AE, VR y reexpresados.
- *Control de cuadre:* `VO_inicio + Altas ± Transferencias − Bajas = VO_cierre` (lo mismo para AA).
- *Control global (referencia 2023):* VR total según la prueba = $7.585.493.061; amortización total según la prueba = $1.179.524.957.
- *Tolerancia:* las diferencias de menos de 0,001% se atribuyen a redondeo. En el estudio aparecen en Máquinas (amortización $5.304 / VR $14.253) y en MyU (VR $11.411).

---

## 5. Entregables de la Fase 0 (checklist)

- [ ] `docs/01_inventario_codigo.md`
- [ ] `docs/02_flujo_ejecucion.md` (con diagrama Mermaid)
- [ ] `docs/03_mapeo_entradas.md`
- [ ] `docs/04_diccionario_calculos.md` (**una ficha por concepto de la sección 4**, más cualquier concepto adicional que aparezca en el R)
- [ ] `docs/05_brechas_vs_referencia.md` (traza numérica de un activo por rubro)
- [ ] `docs/06_parametros_hardcodeados.md`
- [ ] `docs/preguntas_abiertas.md`
- [ ] Resumen ejecutivo de una página: qué hace bien el R, qué le falta, qué difiere del estudio y qué se recomienda reutilizar.

**Criterio de aceptación de la Fase 0:** el usuario puede leer el diccionario y entender, sin abrir el código, de dónde sale y cómo se calcula cada número del revalúo.

---

## 6. Fases siguientes (solo orientativas; se detallan al aprobar la Fase 0)

**Fase 1 — Motor de cálculo**
- Reglas como datos: tablas de rubros, vida útil, exclusiones, IPC y escenarios versionadas por año.
- Motor separado del frontend, ejecutable sin interfaz.
- Recalcular la amortización acumulada desde cero y conciliar contra la base del año anterior.
- **Caso de prueba fijo:** los resultados de 2023 tienen que replicar al estudio externo por rubro, dentro de la tolerancia. Cada cambio del motor corre esta prueba.
- Decisión de tecnología pendiente: seguir en R (Shiny + DuckDB/Parquet) o pasar a API + React. Se decide en base al resumen de la Fase 0.

**Fase 2 — Validaciones de carga y controles**
- Validaciones de altas, bajas y transferencias antes de calcular.
- Pruebas globales automáticas y semáforo de controles.

**Fase 3 — Frontend**
- Asistente por pasos: elegir año y base → cargar movimientos → revisar parámetros → calcular → controles → exportar → aprobar y cerrar el año.
- "Explicar este activo": traza completa del cálculo de un activo.
- Exportación a Excel con el formato del estudio.

**Fase 4 — Prueba con 2024**
- Base = 2023 validado + movimientos 2024 → comparar contra el estudio 2024.

---

## 7. Prompt sugerido para iniciar en Claude Code

```
Leé SPEC_revaluo_impositivo_BU.md completo. Estamos en la FASE 0 (solo análisis).
El código R está en ./R/ y los insumos en ./data/ (solo lectura).
Ejecutá las tareas T0.1 a T0.7 en orden y generá los entregables en ./docs/.
No modifiques ningún archivo existente. Para cada concepto de la sección 4,
completá la ficha con el formato 3.2, citando archivo:línea del R y la columna
del Excel del estudio. Todo lo que no puedas confirmar va a preguntas_abiertas.md.
Al terminar, mostrame el resumen ejecutivo y detenete.
```
