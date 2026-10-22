# DOCUMENTACION COMPLETA DEL MOTOR DE CALCULO
# Revaluo Impositivo — Bienes de Uso AgroBayer (Monsanto Argentina SRL)
# Generado el 2026-09-29

---

## INDICE

1. Vision general
2. Parametros globales y constantes
3. Paso 1 — Importacion de datos
4. Paso 2 — Limpieza y normalizacion
5. Paso 3 — Construccion del rollforward
6. Paso 4 — Calculo AXI (amortizacion y reexpresion)
7. Paso 5 — Prueba global
8. Paso 6 — Validaciones
9. Paso 7 — Exportacion de resultados
10. Glosario de variables calculadas

---

## 1. VISION GENERAL

El motor calcula el Ajuste por Inflacion Impositivo (AXI) de los bienes de uso de Monsanto Argentina SRL. Hasta el ejercicio 2024 este calculo era realizado por KPMG; a partir de 2025, lo ejecuta el equipo interno mediante esta herramienta.

El pipeline toma como input:
- El Excel de revaluo del ejercicio anterior (inventario historico + indices IPC/IPIM)
- Un archivo SAP con Altas, Bajas y Transferencias del ejercicio actual

Y produce como output:
- Excel con detalle activo por activo por rubro, con todos los calculos historicos y reexpresados
- Pruebas globales de cuadre
- Validaciones automaticas
- Resumen ejecutivo del AXI

El flujo es:
```
importar_datos -> limpiar_datos -> construir_rollforward -> calcular_axi -> generar_prueba_global -> ejecutar_validaciones -> exportar_resultados
```

---

## 2. PARAMETROS GLOBALES Y CONSTANTES

### 2.1 Rubros y vidas utiles

El motor maneja 11 rubros de bienes de uso. Cada uno tiene una vida util (VU) expresada en anios y en trimestres, y un indice de actualizacion asociado:

| Rubro                | Codigos SAP           | VU (anios) | VU (trimestres) | Indice |
|----------------------|-----------------------|------------|-----------------|--------|
| Cercos               | (sin codigo)          | 50         | 200             | IPC    |
| Edificios            | 210LA, 220LA, 392LA   | 50         | 200             | IPC    |
| Terrenos             | 110LA                 | N/A        | 0               | IPC    |
| Estructuras y canos  | (sin codigo)          | 10         | 40              | IPC    |
| Eq de Oficina        | 320LA                 | 3          | 12              | IPC    |
| Maquinas y Equipos   | 310LA, 350LA          | 10         | 40              | IPC    |
| Maquinas Mejoras     | 370LA                 | 10         | 40              | IPC    |
| MyU                  | 330LA                 | 3          | 12              | IPC    |
| Rodados              | 360LA                 | 5          | 20              | IPC    |
| Terreno Mejoras      | 130LA, 250LA          | 10         | 40              | IPC    |
| Software             | 510LA, 515LA, 610LA   | 3          | 12              | IPC    |

**Nota clave sobre Edificios:** La VU Asignada para Edificios se expresa en trimestres (200). Para todos los demas rubros amortizables, la VU Asignada se expresa en anios (ej: 50, 10, 5, 3). Esto impacta directamente en como se calcula la amortizacion por periodo.

**Nota sobre Terrenos:** Los terrenos NO amortizan (VU = 0). Solo se les reexpresa el Valor de Origen.

### 2.2 Anio de corte para reexpresion

```
ANIO_CORTE_REVALUO = 2018
```

- Bienes adquiridos **desde 2018 en adelante**: se reexpresan con IPC.
- Bienes adquiridos **antes de 2018**: se reexpresan con IPIM (confiscatoriedad).

### 2.3 Tolerancias de validacion

| Constante                         | Valor  | Uso                                                      |
|-----------------------------------|--------|----------------------------------------------------------|
| TOLERANCIA_PRUEBA_GLOBAL          | 1      | Diferencia maxima aceptable en PG antes de ser reportada |
| UMBRAL_ERROR_PRUEBA_GLOBAL        | 100    | Por encima de 100 es ERROR; entre 1 y 100 es ADVERTENCIA|
| TOLERANCIA_CONSISTENCIA_INTERNA   | 0.01   | Tolerancia para chequeos VR = VO - Amort Acum            |
| TOLERANCIA_VALIDACION_EXTERNA     | 0.20   | 20% de diferencia porcentual vs manual Price/KPMG        |

### 2.4 Mapeo de clases SAP a rubros

Cada movimiento SAP tiene un campo "Class" que se traduce a un rubro contable:

| Clase SAP | Rubro                |
|-----------|----------------------|
| 110LA     | Terrenos             |
| 130LA     | Terreno Mejoras      |
| 210LA     | Edificios            |
| 220LA     | Edificios            |
| 250LA     | Terreno Mejoras      |
| 310LA     | Maquinas y Equipos   |
| 320LA     | Eq de Oficina        |
| 330LA     | MyU                  |
| 350LA     | Maquinas y Equipos   |
| 360LA     | Rodados              |
| 370LA     | Maquinas Mejoras     |
| 392LA     | Edificios            |
| 510LA     | Software             |
| 515LA     | Software             |
| 610LA     | Software             |
| 600LA     | Obras en curso (se excluye del calculo) |

---

## 3. PASO 1 — IMPORTACION DE DATOS (01_importar_datos.R)

### 3.1 Fuentes de datos

El motor lee tres fuentes:

**A) Excel de revaluo del ejercicio anterior (LY = Last Year)**
Contiene:
- 11 hojas de categorias (una por rubro), cada una con el inventario de activos y sus datos historicos
- 4 hojas de indices: "IPC", "IPIM", "IPC - VR Bajas", "IPIM - VR Bajas"

**B) Archivo SAP de movimientos del ejercicio**
Un .xlsx con 3 hojas:
- "Altas": bienes nuevos adquiridos en el ejercicio
- "Bajas": bienes retirados en el ejercicio
- "Transferencias": bienes transferidos entre clases

**C) Excepciones de fecha base (opcional)**
Archivo CSV en inputs/parametros/excepciones_fecha_base.csv que permite sobreescribir la fecha de alta usada para buscar el coeficiente de reexpresion de activos especificos.

### 3.2 Lectura de hojas de categorias

Cada hoja tiene su encabezado (header) en una fila distinta segun el rubro:

| Rubro                | Fila del header |
|----------------------|-----------------|
| Cercos               | 13              |
| Edificios            | 16              |
| Terrenos             | 5               |
| Estructuras y canos  | 9               |
| Eq de Oficina        | 11              |
| Maquinas y Equipos   | 10              |
| Maquinas Mejoras     | 10              |
| MyU                  | 12              |
| Rodados              | 9               |
| Terreno Mejoras      | 9               |
| Software             | 9               |

Los datos se leen como texto y luego se convierten a los tipos apropiados. Las columnas vacias y filas enteramente nulas se eliminan.

### 3.3 Lectura de indices

Cada hoja de indices (IPC, IPIM, IPC - VR Bajas, IPIM - VR Bajas) tiene 4 columnas:

| Columna     | Contenido                                  |
|-------------|---------------------------------------------|
| Columna 1   | Fecha del periodo                           |
| Columna 2   | Indice del periodo                          |
| Columna 3   | Indice actual / de cierre                   |
| Columna 4   | Coeficiente de actualizacion (cierre/periodo)|

Las fechas pueden venir como Date de Excel, serial numerico, o texto "dd.mm.yyyy". El motor las parsea automaticamente.

### 3.4 Lectura de movimientos SAP

**Altas:**
- Campos leidos: Asset, Cap_Date, Pstng_Date, Asset_Description2, Class, Suma_de_Acquisition
- Se usa **Posting Date (Pstng_Date)** como fecha de alta del bien
- Se toma el valor absoluto de Suma_de_Acquisition como VO

**Bajas:**
- Campos leidos: Asset, Cap_Date, Pstng_Date, Asset_Description, Class, Retirement, Depr_Retired, Ret_Book_Value
- **Filtro critico**: solo se reconocen bajas donde `abs(Ret_Book_Value) < 0.01` (bien totalmente depreciado)
- Se usa Posting Date como fecha de baja
- Se usa Cap_Date como fecha original de alta (para calcular antiguedad)

**Transferencias:**
- Campos leidos: Asset, Cap_Date, Pstng_Date, Asset_Description2, Class, Suma_de_Transfer, Suma_de_Trans_O_Dep
- Se usa **Cap_Date** (fecha de capitalizacion) como fecha de referencia (NO Posting Date)
- Si valor < 0 es una "salida"; si >= 0 es una "entrada"

**Filtros comunes a los tres tipos:**
- Se excluyen filas de totales/subtotales
- Se excluyen activos con numero que empiece con "AS" (IFRS 16)
- Se excluyen activos de clase 600LA (Obras en curso)
- Se excluyen activos cuyo rubro no se puede mapear

---

## 4. PASO 2 — LIMPIEZA Y NORMALIZACION (02_limpiar_datos.R)

### 4.1 Normalizacion de cada hoja de categoria

Para cada rubro, se buscan las columnas por patron de nombre (regex):
- Numero de activo: `activo.?fijo` o `n.*activo`
- Descripcion: `descrip` o `denominaci`
- Fecha de alta: primero busca "ano a tomar", sino "ano archivo" o "fe.*capit"
- Ano de alta: `^a.*o.*alta$`
- Mes de alta: `mes.*alta`
- VO (Valor de Origen): `^vo$`, `val.*adq` o `val.*origen$`
- VU Asignada: `vu.*asignada`
- VUT LY: `vut.*ly`

### 4.2 Deteccion de tipo de movimiento

La primera columna de cada fila indica el tipo de movimiento:
- Si empieza con "Altas y baja" -> `alta_y_baja`
- Si empieza con "Alta" -> `alta`
- Si empieza con "Transferencia" -> `transferencia`
- Si empieza con "Baja" -> `baja`
- Si empieza con "Totales" -> `totales` (se descarta)
- Si empieza con "ojo/ver/solo/destinado" o es solo un numero -> `nota` (se descarta)
- Todo lo demas -> `historico`

### 4.3 Reclasificacion temporal de movimientos

Los movimientos que vienen del Excel LY (ejercicio anterior) se reclasifican:
- Si el movimiento es del **ejercicio actual** (su ano coincide con anio_ejercicio): conserva su tipo original (alta, baja, transferencia)
- Si el movimiento es de un **ejercicio anterior**: se marca como `tipo_movimiento = "historico"` y se guarda el tipo original en `subclasificacion_historico`

Esto es importante porque los movimientos historicos ya estan reflejados en el inventario LY y no deben tratarse como movimientos nuevos.

### 4.4 Conversion de VU Asignada

- Para **Edificios**: la VU Asignada se lee tal cual del archivo (ya viene en trimestres)
- Para **todos los demas rubros**: la VU Asignada se lee del archivo y se **divide por 4** (el archivo la trae en trimestres pero internamente el motor la usa en anios para estos rubros)

### 4.5 Filtros aplicados

- Se eliminan activos IFRS 16 (numero de activo comienza con "AS")
- Se eliminan filas de tipo "totales" y "nota"
- Se eliminan filas donde tanto VO como nro_activo_fijo son NA

---

## 5. PASO 3 — CONSTRUCCION DEL ROLLFORWARD (03_construir_rollforward.R)

### 5.1 Objetivo

Combinar el inventario del ejercicio anterior (LY) con los movimientos SAP del ejercicio actual para obtener el inventario completo al cierre.

### 5.2 Deteccion de movimientos ya incluidos

El motor detecta si el Excel LY ya contiene movimientos del ejercicio actual (caso de archivos KPMG que ya incluian todo). Si los detecta, **NO incorpora los movimientos SAP** para evitar duplicacion.

La deteccion se hace verificando si algun activo en el inventario tiene `anio_movimiento == anio_ejercicio`.

### 5.3 Incorporacion de movimientos SAP (cuando no estan en LY)

Para cada rubro, si NO se detectaron movimientos del ejercicio en el LY:

**Altas (normalizar_movimiento_sap):**
- Se crea una fila con: tipo_movimiento = "alta", origen = "alta_{anio}"
- Fecha de alta = Posting Date del SAP
- VO = valor absoluto del monto SAP
- VU Asignada = la del rubro (en trimestres para Edificios, en anios para el resto)
- VUT LY = NA (se calculara en el paso 4)

**Transferencias (normalizar_movimiento_sap):**
- Se crea una fila con: tipo_movimiento = "transferencia", origen = "transferencia_{anio}"
- Fecha de alta = Cap_Date (fecha de capitalizacion, NO Posting Date)
- VO = valor tal cual (puede ser positivo o negativo)
- direccion_movimiento = "salida" si valor < 0, "entrada" si valor >= 0

**Bajas (normalizar_baja_sap):**
- Se crea una fila con: tipo_movimiento = "baja", origen = "baja_{anio}"
- fecha_alta = Posting Date (fecha de baja efectiva)
- fecha_baja = Posting Date (se preserva para calculos de Edificios)
- anio_alta y mes_alta = tomados de Cap_Date (fecha de capitalizacion original del bien)
- VO = valor absoluto del Retirement
- importe_movimiento_control = -abs(valor) (signo negativo para control)

### 5.4 Marcado de origen

Cada activo recibe una etiqueta de `origen` que indica de donde viene:
- `"historico"`: activo del inventario LY sin movimiento especial
- `"historico_baja_{anio}"`: activo historico que fue baja en un ejercicio anterior
- `"historico_alta_{anio}"`: activo historico que fue alta en un ejercicio anterior
- `"historico_transferencia_{anio}"`: activo historico que fue transferencia en un ejercicio anterior
- `"alta_{anio}"`: alta del ejercicio actual
- `"baja_{anio}"`: baja del ejercicio actual
- `"transferencia_{anio}"`: transferencia del ejercicio actual
- `"alta_y_baja_{anio}"`: alta y baja en el mismo ejercicio

### 5.5 Rubros nuevos

Si un movimiento SAP corresponde a un rubro que no existia en el inventario LY (ej: un rubro que no tenia activos el anio anterior), se crea el rubro con solo los movimientos SAP.

---

## 6. PASO 4 — CALCULO AXI (04_calculo_axi.R)

Este es el paso central del motor. Se ejecuta por rubro, con logica diferente para Terrenos vs. rubros amortizables.

### 6.1 TERRENOS (calcular_terrenos)

Los terrenos NO amortizan. El calculo es simple:

```
vu_asignada = 0
amort_trimestre = 0
amort_hist_ejercicio = 0
amort_acum_cierre = 0
amort_acum_ly = 0
vr = vo                          (Valor Residual = Valor de Origen, porque no hay amortizacion)
vr_ly = vo

Reexpresion:
  Si anio_alta >= 2018:
    vo_reexp = vo * coeficiente_IPC(fecha_alta)
  Si anio_alta < 2018:
    vo_reexp = vo * coeficiente_IPIM(fecha_alta)

vr_reexp = vo_reexp               (porque no hay amortizacion)
amort_acum_cierre_reexp = 0
```

### 6.2 RUBROS AMORTIZABLES (calcular_rubro_amortizable)

#### 6.2.1 Periodos por anio

La unidad de devengamiento depende del rubro:
- **Edificios**: devengamiento por **trimestre** -> periodos_por_anio = 4
- **Todos los demas rubros**: devengamiento por **anio** -> periodos_por_anio = 1

#### 6.2.2 Trimestres del primer anio de alta

Solo relevante para Edificios. Calcula cuantos trimestres del primer anio corresponde devengar segun el mes de alta:

```
trim_primer_anio = 4 - floor((mes_alta - 1) / 3)
```

Ejemplos:
- Alta en enero (mes 1): 4 - floor(0/3) = 4 trimestres
- Alta en abril (mes 4): 4 - floor(3/3) = 3 trimestres
- Alta en julio (mes 7): 4 - floor(6/3) = 2 trimestres
- Alta en octubre (mes 10): 4 - floor(9/3) = 1 trimestre

Para rubros NO Edificios, trim_primer_anio = 1 (siempre un periodo completo).

#### 6.2.3 Periodos hasta baja (Edificios)

Para edificios dados de baja, se calcula hasta que trimestre del anio corresponde devengar:

```
periodos_hasta_baja = floor((mes_baja - 1) / 3) + 1
```

Ejemplos:
- Baja en marzo: floor(2/3) + 1 = 1 (primer trimestre)
- Baja en junio: floor(5/3) + 1 = 2 (segundo trimestre)
- Baja en diciembre: floor(11/3) + 1 = 4 (cuarto trimestre, anio completo)

Para rubros NO Edificios y para no-bajas: periodos_hasta_baja = periodos_por_anio (siempre completo).

#### 6.2.4 VUT LY (Vida Util Transcurrida al cierre del ejercicio anterior)

Si el archivo LY ya trae el dato VUT LY, se usa directamente.

Si no viene (caso de altas del ejercicio), se calcula:

```
vut_ly_trimestres = calcular_vut_ly(anio_alta, mes_alta, anio_ejercicio, vu_asignada)

Donde calcular_vut_ly:
  Si anio_alta == anio_ejercicio:
    vut = 0 (el bien no existia al cierre anterior)
  Sino:
    vut = (anio_ejercicio - anio_alta - 1) * 4 + trim_primer_anio
    vut = min(vut, vu_asignada)  (nunca supera la VU total)
```

Luego se convierte a la unidad del rubro:
```
vut_ly = vut_ly_trimestres / 4 * periodos_por_anio
```
- Para Edificios (periodos_por_anio=4): queda en trimestres
- Para otros rubros (periodos_por_anio=1): queda en anios

#### 6.2.5 VUT del ejercicio (periodos devengados en el ejercicio actual)

```
Si anio_alta == anio_ejercicio:
  vut_ejercicio = trim_primer_anio  (trimestres restantes del primer anio para Edificios, 1 para otros)
Sino:
  vut_ejercicio = periodos_hasta_baja  (4 para Edificios sin baja, 1 para otros)

vut_ejercicio = min(vut_ejercicio, vu_asignada - vut_ly)
```

El `min()` asegura que no se exceda la VU total del bien.

#### 6.2.6 VUT al cierre

```
vut_cierre = min(vut_ly + vut_ejercicio, vu_asignada)
```

#### 6.2.7 VU restante

```
vu_restante = max(vu_asignada - vut_cierre, 0)
```

#### 6.2.8 Amortizacion por periodo (amort_trimestre)

A pesar de llamarse "amort_trimestre", es la amortizacion por periodo:

```
Si vu_asignada > 0:
  amort_trimestre = vo / vu_asignada
Sino:
  amort_trimestre = 0
```

- Para **Edificios**: vu_asignada esta en trimestres (200), asi que amort_trimestre es la amortizacion por trimestre
- Para **otros rubros**: vu_asignada esta en anios (ej: 50), asi que amort_trimestre es la amortizacion por anio

#### 6.2.9 Amortizacion historica del ejercicio

```
Si vut_ly < vu_asignada (aun queda VU por devengar):
  amort_hist_ejercicio = amort_trimestre * vut_ejercicio
Sino:
  amort_hist_ejercicio = 0  (VU ya agotada, no se amortiza mas)
```

#### 6.2.10 Amortizacion historica post-2018

```
Si anio_alta >= 2018:
  amort_hist_2018 = amort_hist_ejercicio
Sino:
  amort_hist_2018 = 0
```

Se usa para la reexpresion por IPC (solo bienes post-2018).

#### 6.2.11 Amortizacion acumulada al cierre y al LY

```
Si vu_asignada > 0:
  amort_acum_cierre = amort_trimestre * vut_cierre
  amort_acum_ly = amort_trimestre * vut_ly
Sino:
  amort_acum_cierre = 0
  amort_acum_ly = 0
```

#### 6.2.12 Valor Residual (VR)

```
vr = vo - amort_acum_cierre
vr_ly = vo - amort_acum_ly
```

#### 6.2.13 Busqueda de coeficientes de reexpresion

Se busca el coeficiente en la tabla de indices correspondiente segun la fecha de alta (o fecha de excepcion si aplica):

```
buscar_coeficiente(fecha, tabla_indices):
  Ordena la tabla por fecha ascendente
  Busca la ultima fecha en la tabla que sea <= fecha_alta
  Devuelve el coeficiente de esa fila
  Si no encuentra ninguna, devuelve el coeficiente de la primera fila
  Si la fecha es NA, devuelve 1
```

**Asignacion de coeficientes:**
```
Si anio_alta >= 2018:
  coef_ipc = buscar_coeficiente(fecha_alta, indices_IPC)
  coef_ipim = (no se usa directamente, pero se calcula igual)
Sino:
  coef_ipc = 1 (no aplica IPC para pre-2018)
  coef_ipim = buscar_coeficiente(fecha_alta, indices_IPIM)
```

#### 6.2.14 Reexpresion del Valor de Origen

```
Si anio_alta >= 2018:
  vo_reexp = vo * coef_ipc
Sino:
  vo_reexp = vo * coef_ipim
```

#### 6.2.15 Reexpresion de amortizaciones

**Amortizacion historica reexpresada (del ejercicio):**
```
Si anio_alta >= 2018:
  amort_hist_reexp = amort_hist_2018 * coef_ipc
Sino:
  amort_hist_reexp = 0  (pre-2018 no reexpresa amort historica con IPC)
```

**Amortizacion acumulada LY reexpresada:**
```
Si anio_alta >= 2018:
  amort_acum_ly_reexp = amort_acum_ly * coef_ipc
Sino:
  amort_acum_ly_reexp = amort_acum_ly * coef_ipim
```

**Amortizacion acumulada al cierre reexpresada:**
```
Si anio_alta >= 2018:
  amort_acum_cierre_reexp = amort_acum_cierre * coef_ipc
Sino:
  amort_acum_cierre_reexp = amort_acum_cierre * coef_ipim
```

#### 6.2.16 Valor Residual reexpresado

```
vr_reexp = vo_reexp - amort_acum_cierre_reexp
```

#### 6.2.17 Ajuste por VU agotada en LY

Para bienes cuya VU ya estaba totalmente agotada al cierre del ejercicio anterior (vut_ly >= vu_asignada):

```
es_vu_agotada_ly = (vut_ly >= vu_asignada) y (vu_asignada > 0)

Si es_vu_agotada_ly:
  Si anio_alta == anio_ejercicio:
    ajuste = -amort_trimestre * trim_primer_anio
  Sino:
    ajuste = -amort_trimestre * min(periodos_por_anio, vu_asignada - vut_ly + periodos_por_anio)
Sino:
  ajuste = 0
```

Este ajuste negativo (`amort_bs_agotaron_vu_ly`) se resta en la prueba global para no sobre-amortizar bienes que ya completaron su vida util.

#### 6.2.18 Reexpresion de bajas (calcular_bajas_reexp)

Para bienes con tipo_movimiento_calc == "baja", se usan las tablas de indices de bajas (IPC - VR Bajas / IPIM - VR Bajas):

```
Si es_baja y anio_alta >= 2018:
  coef_ipc_bajas = buscar_coeficiente(fecha_alta, indices_IPC_bajas)
  amort_bajas = amort_acum_cierre * coef_ipc_bajas
  vr_bajas = vr * coef_ipc_bajas

Si es_baja y anio_alta < 2018:
  coef_ipim_bajas = buscar_coeficiente(fecha_alta, indices_IPIM_bajas)
  amort_bajas = amort_acum_cierre * coef_ipim_bajas
  vr_bajas = vr * coef_ipim_bajas

Si no es baja:
  amort_bajas = 0
  vr_bajas = 0
```

#### 6.2.19 Excepciones de fecha base

El motor permite sobreescribir la fecha usada para buscar el coeficiente de reexpresion. Esto se configura en un CSV (excepciones_fecha_base.csv) con:
- rubro, nro_activo_fijo, fecha_base_reexpresion, inicio_indice_desde, motivo, fuente_manual, activo

Cuando un activo tiene una excepcion activa, se usa `inicio_indice_desde` (o `fecha_base_reexpresion` si la primera es NA) en lugar de la fecha de alta para buscar el coeficiente.

---

## 7. PASO 5 — PRUEBA GLOBAL (05_prueba_global.R)

La prueba global es un control de cuadre que verifica la consistencia del calculo comparando el saldo obtenido "segun prueba" (reconstruido componente por componente) contra el saldo "segun revaluo" (sumado directamente del inventario calculado).

Se generan tres pruebas globales: Amortizaciones, Valor Residual y AXI.

### 7.1 Definiciones auxiliares

Para cada rubro, los activos se clasifican en:

- **es_mov_actual**: activos cuyo anio_movimiento == anio_ejercicio (altas, bajas, transferencias del ejercicio)
- **es_existente**: activos que NO son del ejercicio actual Y cuyo tipo_movimiento_calc NO es "baja" (es decir, activos historicos vigentes)

### 7.2 Prueba Global de Amortizaciones (generar_pg_amortizaciones)

Para cada rubro se calcula:

| Componente                     | Formula                                                                                         |
|--------------------------------|-------------------------------------------------------------------------------------------------|
| amort_inicio                   | Suma de amort_acum_ly de activos existentes + activos que son bajas del ejercicio actual         |
| amort_altas                    | Suma de amort_acum_cierre de las altas del ejercicio                                            |
| amort_transferencias           | Suma de amort_acum_cierre de las transferencias del ejercicio                                   |
| amort_bajas                    | -Suma de amort_acum_ly de las bajas del ejercicio (signo negativo: se revierte)                 |
| bs_agotaron_vu_ly              | Suma de amort_bs_agotaron_vu_ly de activos existentes (ajuste negativo por VU agotada)          |
| amort_hist_ejercicio_total     | Suma de amort_hist_ejercicio de activos existentes cuya VU NO esta agotada                      |
| **amort_prueba**               | amort_inicio + amort_altas + amort_transferencias + amort_bajas + bs_agotaron_vu_ly + amort_hist_ejercicio_total |
| **amort_revaluo**              | Suma de amort_acum_cierre de todos los activos EXCEPTO las bajas del ejercicio                  |
| **diferencia**                 | amort_prueba - amort_revaluo (debe tender a 0)                                                  |

### 7.3 Prueba Global de Valor Residual (generar_pg_valor_residual)

Para cada rubro:

| Componente                     | Formula                                                                                         |
|--------------------------------|-------------------------------------------------------------------------------------------------|
| vr_inicio                      | Suma de vr_ly de activos existentes + activos que son bajas del ejercicio actual                 |
| altas_vr                       | Suma de vr de las altas del ejercicio                                                           |
| transferencias_vr              | Suma de vr de las transferencias del ejercicio                                                  |
| bajas_vo                       | -Suma de vr_ly de las bajas del ejercicio (signo negativo)                                      |
| amort_ejercicio                | -Suma de amort_hist_ejercicio de activos existentes cuya VU NO esta agotada (signo negativo)    |
| **vr_prueba**                  | vr_inicio + altas_vr + transferencias_vr + bajas_vo + amort_ejercicio                           |
| **vr_revaluo**                 | Suma de vr de todos los activos EXCEPTO las bajas del ejercicio                                 |
| **diferencia**                 | vr_prueba - vr_revaluo (debe tender a 0)                                                       |

### 7.4 Prueba Global AXI (generar_pg_axi)

Para cada rubro:

| Componente                     | Formula                                                     |
|--------------------------------|-------------------------------------------------------------|
| vo_reexp                       | Suma de vo_reexp de todos los activos del rubro             |
| amort_acum_reexp               | Suma de amort_acum_cierre_reexp de todos los activos        |
| vr_reexp                       | Suma de vr_reexp de todos los activos                       |
| vr_hist                        | Suma de vr de todos los activos                             |
| **axi_resultado**              | vr_reexp - vr_hist                                          |

El AXI (Ajuste por Inflacion Impositivo) es la diferencia entre el Valor Residual reexpresado y el Valor Residual historico.

---

## 8. PASO 6 — VALIDACIONES (06_validaciones.R)

El motor ejecuta 8 tipos de validaciones automaticas. Cada validacion produce un resultado: OK, ADVERTENCIA o ERROR.

### 8.1 Consistencia interna (validar_consistencia_interna)

Para cada rubro, verifica activo por activo:

**Chequeo 1 — Amortizacion acumulada:**
```
Para activos con vu_asignada > 0:
  |amort_acum_cierre - (amort_trimestre * vut_cierre)| <= 0.01
```
Si la diferencia excede 0.01: ERROR.

**Chequeo 2 — Valor Residual:**
```
Para todos los activos:
  |vr - (vo - amort_acum_cierre)| <= 0.01
```
Si la diferencia excede 0.01: ERROR.

### 8.2 Prueba Global de Amortizaciones (validar_pg_amortizaciones)

```
Para cada rubro en la tabla PG Amortizaciones:
  Si |diferencia| > 100: ERROR
  Si |diferencia| > 1 y <= 100: ADVERTENCIA
  Si |diferencia| <= 1: OK
```

### 8.3 Prueba Global de Valor Residual (validar_pg_valor_residual)

Misma logica que la PG de Amortizaciones pero aplicada a la tabla PG VR:
```
  Si |diferencia| > 100: ERROR
  Si |diferencia| > 1 y <= 100: ADVERTENCIA
  Si |diferencia| <= 1: OK
```

### 8.4 Formula VR Reexpresado (validar_vr_formula)

Para cada rubro, verifica activo por activo:
```
|vr_reexp - (vo_reexp - amort_acum_cierre_reexp)| <= 0.01
```
Si algun activo falla: ERROR.

### 8.5 Conteos de movimientos SAP (validar_conteos_movimientos)

Compara la cantidad de filas de detalle procesadas contra conteos esperados hardcodeados:
- Altas esperadas: 4873
- Bajas esperadas: 1717
- Transferencias esperadas: 1738

Si difiere: ERROR. (Nota: estos conteos corresponden a un ejercicio especifico de validacion y pueden no aplicar a todos los anios.)

### 8.6 Valores reexpresados negativos (validar_valores_reexpresados_negativos)

Busca activos cuyo VO reexpresado o VR reexpresado sea negativo, excluyendo transferencias de salida (que legítimamente pueden ser negativas):
```
Si vo_reexp < 0 o vr_reexp < 0 (y no es transferencia de salida): ERROR
```

### 8.7 Excepciones de fecha base (validar_excepciones_fecha_base)

Reporta cuantos activos por rubro tienen una excepcion de fecha base aplicada. No genera ERROR, solo informativo (OK con detalle).

### 8.8 Comparacion contra real — Price/KPMG (validar_contra_real)

Si se proporciono el archivo de validacion externa (Excel del manual Price/KPMG), compara por rubro y en total:

**Magnitudes comparadas:**
- Amortizacion acumulada (amort_revaluo vs manual)
- Valor Residual (vr_revaluo vs manual)
- AXI (axi_resultado vs manual)

**Calculo de diferencia porcentual:**
```
pct = |propio - real| / |real|

Si |real| <= 0.01 y |diferencia| <= 0.01: pct = 0
Si |real| <= 0.01 y |diferencia| > 0.01: pct = 1 (100%)
```

**Resultado:**
```
Si pct <= 20%: OK
Si pct > 20%: ERROR
```

Se reporta rubro por rubro y tambien un TOTAL. Se muestra: valor propio, valor Price, diferencia, porcentaje de diferencia y porcentaje de igualdad.

Si no se proporciono archivo de validacion: ADVERTENCIA ("validacion externa omitida").

### 8.9 Resultado global

```
consistente = TRUE si no hay ningun ERROR en ninguna validacion
consistente = FALSE si hay al menos un ERROR
```

Las ADVERTENCIAS no impiden que el resultado sea consistente.

---

## 9. PASO 7 — EXPORTACION DE RESULTADOS (07_exportar_resultados.R)

### 9.1 Excel de Revaluo Final (MARG_Revaluo_AXI_{anio}.xlsx)

Contiene:
- **Una hoja por rubro** con encabezado "MONSANTO ARGENTINA SRL - REVALUO IMPOSITIVO BIENES DE USO AL 31-12-{anio}" y detalle activo por activo con las siguientes columnas (cuando existen):

  tipo_movimiento, subclasificacion_historico, nro_activo_fijo, descripcion,
  anio_alta, mes_alta, vo, vu_asignada, trim_primer_anio, vut_ly, vut_ejercicio,
  vut_cierre, vu_restante, amort_trimestre, amort_hist_ejercicio, amort_hist_2018,
  amort_acum_cierre, amort_acum_ly, amort_acum_ly_reexp, vr, fecha_indice_reexp,
  regla_fecha_base_aplicada, motivo_excepcion_fecha_base, valor_sap_original,
  direccion_movimiento, importe_movimiento_control, coef_ipc, coef_ipim,
  vo_reexp, amort_hist_reexp, amort_acum_cierre_reexp, vr_reexp, amort_bajas, vr_bajas

- Cada hoja tiene una fila de totales al final.
- **Hoja "PG"**: Pruebas Globales de Amortizaciones y Valor Residual
- **Hoja "PG AXI"**: Prueba Global del AXI
- **Hoja "IPC"**: tabla de indices IPC utilizada
- **Hoja "IPIM"**: tabla de indices IPIM utilizada

### 9.2 Excel de Validaciones (validaciones_{anio}.xlsx)

Contiene una hoja "Validaciones" con el resumen de todas las validaciones ejecutadas:
- Columnas: tipo, rubro, descripcion, resultado, valor
- Formato condicional: verde (OK), rojo (ERROR), amarillo (ADVERTENCIA)

### 9.3 Excel de Resumen (resumen_revaluo_{anio}.xlsx)

Contiene una hoja "Resumen" con:
- Titulo "MONSANTO ARGENTINA SRL - REVALUO AXI {anio}"
- Tabla con: rubro, vr_reexp, vo_reexp, amort_acum_reexp, vr_hist, axi_resultado
- Fila de TOTAL al final

---

## 10. GLOSARIO DE VARIABLES CALCULADAS

| Variable                    | Descripcion                                                                               |
|-----------------------------|-------------------------------------------------------------------------------------------|
| vo                          | Valor de Origen historico del bien                                                        |
| vu_asignada                 | Vida Util total asignada (trimestres para Edificios, anios para los demas)                |
| vut_ly                      | Vida Util Transcurrida al cierre del ejercicio anterior                                   |
| vut_ejercicio               | Periodos devengados en el ejercicio actual                                                |
| vut_cierre                  | Vida Util Transcurrida al cierre del ejercicio actual = vut_ly + vut_ejercicio            |
| vu_restante                 | Vida Util restante = vu_asignada - vut_cierre                                             |
| trim_primer_anio            | Trimestres del primer anio de alta (Edificios) o 1 (otros rubros)                        |
| periodos_hasta_baja         | Trimestre del anio hasta el que devenga un edificio dado de baja                          |
| amort_trimestre             | Amortizacion por periodo = vo / vu_asignada                                               |
| amort_hist_ejercicio        | Amortizacion historica devengada en el ejercicio = amort_trimestre * vut_ejercicio         |
| amort_hist_2018             | Amortizacion historica del ejercicio solo para bienes post-2018                            |
| amort_acum_cierre           | Amortizacion acumulada al cierre = amort_trimestre * vut_cierre                            |
| amort_acum_ly               | Amortizacion acumulada al cierre del ejercicio anterior = amort_trimestre * vut_ly         |
| vr                          | Valor Residual historico = vo - amort_acum_cierre                                          |
| vr_ly                       | Valor Residual al cierre del ejercicio anterior = vo - amort_acum_ly                       |
| coef_ipc                    | Coeficiente IPC para la fecha de alta (1 si pre-2018)                                     |
| coef_ipim                   | Coeficiente IPIM para la fecha de alta                                                    |
| vo_reexp                    | Valor de Origen reexpresado = vo * coef_ipc (post-2018) o vo * coef_ipim (pre-2018)       |
| amort_hist_reexp            | Amortizacion historica del ejercicio reexpresada (solo post-2018, por IPC)                 |
| amort_acum_ly_reexp         | Amortizacion acumulada LY reexpresada (IPC post-2018, IPIM pre-2018)                      |
| amort_acum_cierre_reexp     | Amortizacion acumulada al cierre reexpresada (IPC post-2018, IPIM pre-2018)                |
| vr_reexp                    | Valor Residual reexpresado = vo_reexp - amort_acum_cierre_reexp                            |
| es_vu_agotada_ly            | TRUE si la VU estaba totalmente agotada al cierre anterior                                 |
| amort_bs_agotaron_vu_ly     | Ajuste negativo para bienes con VU agotada (evita sobre-amortizacion en PG)                |
| coef_ipc_bajas              | Coeficiente IPC de bajas (post-2018, usando tabla "IPC - VR Bajas")                        |
| coef_ipim_bajas             | Coeficiente IPIM de bajas (pre-2018, usando tabla "IPIM - VR Bajas")                       |
| amort_bajas                 | Amortizacion acumulada reexpresada del bien dado de baja                                   |
| vr_bajas                    | Valor Residual reexpresado del bien dado de baja                                           |
| fecha_indice_reexp          | Fecha usada para buscar el coeficiente (= fecha_alta, salvo excepcion)                     |
| regla_fecha_base_aplicada   | TRUE si se aplico una excepcion de fecha base para este activo                             |
| motivo_excepcion_fecha_base | Razon de la excepcion (texto libre del CSV de excepciones)                                 |
| tipo_movimiento             | Clasificacion para exportacion: historico, alta, baja, transferencia, alta_y_baja           |
| tipo_movimiento_calc        | Clasificacion original usada internamente para calculos (no se reclasifica a "historico")   |
| subclasificacion_historico  | Para movimientos reclasificados como "historico": el tipo original (alta, baja, etc.)       |
| origen                      | Etiqueta de trazabilidad: de donde proviene el activo (historico, alta_2023, baja_2023, etc)|
| direccion_movimiento        | Para transferencias: "entrada" o "salida" segun el signo del valor                         |
| valor_sap_original          | Valor tal cual viene del archivo SAP (sin abs())                                           |
| importe_movimiento_control  | Valor con signo para control: positivo en altas, negativo en bajas                         |

---

*Fin del documento.*
