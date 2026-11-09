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
- Se toma el valor de Suma_de_Acquisition **con su signo** como VO (las reversas restan; antes se usaba el valor absoluto)

**Bajas:**
- Campos leidos: Asset, Cap_Date, Pstng_Date, Asset_Description, Class, Retirement, Depr_Retired, Ret_Book_Value
- Se reconocen **todas** las bajas, tambien las de bienes no totalmente depreciados (`Ret_Book_Value != 0`): el Excel manual 2023 saca a todos esos activos de la base. (Antes se filtraba `abs(Ret_Book_Value) < 0.01`.)
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

### 4.4 Conversion de VU Asignada y VUT LY

El Excel del estudio trae la VU Asignada y el VUT LY de **Edificios en trimestres** (200) y los de **todos los demas rubros en anios** (ej. Rodados = 5). El motor los lleva a la unidad del criterio vigente multiplicando por `factor_unidad_archivo(rubro)`:

- Criterio `"excel"` (por defecto): factor 1 para todos (sin conversion, como el Excel manual).
- Criterio `"ricardo"`: factor 4 para los rubros que pasan a trimestres (todos salvo Edificios, que ya viene en trimestres, y Rodados, que sigue en anios).

(Antes se dividia por 4 la VU de los rubros no Edificios, lo que distorsionaba la amortizacion: ej. Rodados 5 anios quedaba en 1,25.)

### 4.7 Base del ejercicio anterior, VUT LY e indices

- **Archivo SAP:** `importar_datos(path, inputs, anio, path_sap)` usa el SAP indicado; si no, el que lleva el anio en el nombre (ej. `...12-2023 (Tax).xlsx`) y, si ninguno lo lleva, el mas reciente. Si el nombre trae otro anio se frena con un error (antes se tomaba el primer `.xlsx` de `inputs/SAP/` por orden alfabetico, que con 2022 y 2023 en la carpeta era el de 2022: se sumaban los movimientos del ejercicio anterior). El Paso 1 muestra el archivo usado.
- **IPC del ejercicio:** si la tabla IPC no llega al 31/12 del ejercicio se frena (esos bienes tomarian coeficiente 1 sin aviso). El IPC se lee de `inputs/parametros/indices_ipc_<anio>.xlsx` (hojas "IPC" e "IPC - VR Bajas") si existe; si no, del Excel base.
- Si el Excel base no trae movimientos del ejercicio en curso (ej. 2023 parte del cierre 2022), el inicio del ejercicio es el cierre del archivo: en hojas anuales el VUT LY pasa a ser la columna "VUT"; en Edificios "VUT" es el flujo del ejercicio (1 a 4 trimestres: cierre = VUT LY + VUT) o el cierre pegado a mano (mayor a 4: se toma tal cual).
- Coeficiente de bienes anteriores a 2018: 1 por defecto (Excel 2023); `options(revaluo.coef_pre2018 = "ipim")` usa el IPIM (Excel 2022).

### 4.5 Filtros aplicados

- Se eliminan las filas que estan debajo de la fila de totales de cada hoja (rotulada "Totales" o, en Terrenos, la fila sin N° de activo ni fecha de alta): ahi el Excel del estudio solo lista bajas de anios anteriores, altas y bajas del mismo anio y notas, que no integran los totales del rubro
- Se eliminan activos IFRS 16 (numero de activo comienza con "AS")
- Se eliminan filas de tipo "totales" y "nota"
- Se eliminan filas donde tanto VO como nro_activo_fijo son NA

### 4.6 Fecha de alta

- Se usa la columna "Año a tomar" (o la fecha del archivo si no existe). Si la hoja no trae "Año a tomar" (Terrenos), se aplica la fecha ajustada del estudio: antes de 01/01/1992 se toma 01/01/1992.
- El parseo de fechas es celda por celda: un texto suelto en la columna no anula el resto.

---

## 5. PASO 3 — CONSTRUCCION DEL ROLLFORWARD (03_construir_rollforward.R)

### 5.1 Objetivo

Combinar el inventario del ejercicio anterior (LY) con los movimientos SAP del ejercicio actual para obtener el inventario completo al cierre.

### 5.2 Deteccion de movimientos ya incluidos

El motor detecta si el Excel LY ya contiene movimientos del ejercicio actual (caso de archivos KPMG que ya incluian todo). Si los detecta, **NO incorpora los movimientos SAP** para evitar duplicacion.

La deteccion se hace verificando si algun activo en el inventario tiene `anio_movimiento == anio_ejercicio`.

### 5.3 Incorporacion de movimientos SAP (cuando no estan en LY)

Para cada rubro, si NO se detectaron movimientos del ejercicio en el LY (el Excel base es el del ejercicio anterior):

**Activos con baja en el ejercicio (regla 7, neteo):** antes de incorporar nada, los activos que figuran en las bajas SAP del rubro salen de la base LY como activos normales (pasan a ser filas de baja, ver abajo) y de las altas y transferencias del ejercicio. El Excel manual los muestra asi: el activo desaparece del cuerpo de la hoja y se lista en el bloque "Bajas" debajo de los totales. Pendiente: el documento `docs/15_proceso_manual_revaluo.md` pide prorratear las bajas parciales; hoy se saca el activo completo (5 casos en 2023, todos en Maquinas y Equipos).

**Altas (normalizar_movimiento_sap):**
- Se crea una fila con: tipo_movimiento = "alta", origen = "alta_{anio}"
- Fecha de alta = Posting Date del SAP
- VO = valor SAP con su signo (las reversas restan)
- VU Asignada = la del rubro en la unidad del criterio vigente (ver 6.2.1)
- VUT LY = NA (se calculara en el paso 4)

**Transferencias (normalizar_movimiento_sap):**
- Se crea una fila con: tipo_movimiento = "transferencia", origen = "transferencia_{anio}"
- Fecha de alta = Cap_Date (fecha de capitalizacion, NO Posting Date)
- VO = valor tal cual (puede ser positivo o negativo)
- direccion_movimiento = "salida" si valor < 0, "entrada" si valor >= 0

**Bajas del ejercicio (valores congelados a LY):** los activos que figuran en las bajas SAP del rubro se toman de la base LY con sus valores tal cual (VO, VU, VUT LY, fecha de alta y la columna "Amort. Histórica" del LY) y se retipan como baja (`tipo_movimiento = "baja"`, `origen = "baja_{anio}"`); `fecha_baja` = menor Posting Date SAP del activo. El SAP solo dice que activos y cuando: su monto de retiro no se usa (un activo puede tener varias lineas de retiro o retiros parciales, y el Excel saca el activo completo con sus valores LY). Verificado contra el bloque "Bajas 2023" de cada hoja del Excel 2023 (Eq. de Oficina: VO 11.608.938, acumulada 10.361.335, VR 1.247.603, flujo 1.173.606; igual en el modelo).

**Bajas no identificadas (regla 2):** una baja SAP cuyo activo no esta en la base LY (ni es alta del ejercicio, que se netea) no se calcula; se informa en `bajas_no_identificadas` y como ADVERTENCIA en las validaciones (2023: 85 lineas, 78 en Maquinas y Equipos).

`normalizar_baja_sap()` (fila de baja armada con los montos de SAP: fecha_alta = Posting Date, VO = Retirement) ya no se usa en el rollforward.

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

La unidad de devengamiento depende del rubro y del **criterio de unidad** vigente (`options(revaluo.criterio_unidad_vu = ...)`, variable de entorno `CRITERIO_UNIDAD_VU` en `_targets.R`; ver `obtener_periodos_por_anio()` en `utils.R`):

| Criterio | Edificios | Rodados | Resto de los rubros |
|---|---|---|---|
| `"excel"` (por defecto) | trimestres (4) | anios (1) | anios (1) |
| `"ricardo"` (SPEC 4.2) | trimestres (4) | anios (1) | trimestres (4) |

- `"excel"` replica las formulas del Excel manual del estudio: Edificios con trimestres; el resto con `VUT LY = MIN(VU, anio_ejercicio - anio_alta)` y `VUT = MIN(anio_ejercicio - anio_alta + 1, VU)`, el anio de alta cuenta completo.
- `"ricardo"` aplica la logica de Edificios (trimestre de alta, trimestre de baja, VU en trimestres) a todos los rubros salvo Rodados.
- La VU y el VUT LY que trae el Excel LY estan en trimestres para Edificios y en anios para el resto; `factor_unidad_archivo()` los lleva a la unidad del criterio vigente (no hay mas `/ 4`).

#### 6.2.2 Trimestres del primer anio de alta

Solo se usa en rubros trimestrales (Edificios y, con criterio `"ricardo"`, el resto salvo Rodados). Calcula cuantos trimestres del primer anio corresponde devengar segun el mes de alta:

```
trim_primer_anio = 4 - floor((mes_alta - 1) / 3)
```

Ejemplos:
- Alta en enero (mes 1): 4 - floor(0/3) = 4 trimestres
- Alta en abril (mes 4): 4 - floor(3/3) = 3 trimestres
- Alta en julio (mes 7): 4 - floor(6/3) = 2 trimestres
- Alta en octubre (mes 10): 4 - floor(9/3) = 1 trimestre

Para rubros anuales, trim_primer_anio = 1 (siempre un periodo completo).

#### 6.2.3 Periodos hasta baja (rubros trimestrales)

Para bienes trimestrales dados de baja, se calcula hasta que trimestre del anio corresponde devengar:

```
periodos_hasta_baja = floor((mes_baja - 1) / 3) + 1
```

Ejemplos:
- Baja en marzo: floor(2/3) + 1 = 1 (primer trimestre)
- Baja en junio: floor(5/3) + 1 = 2 (segundo trimestre)
- Baja en diciembre: floor(11/3) + 1 = 4 (cuarto trimestre, anio completo)

Para rubros anuales y para no-bajas: periodos_hasta_baja = periodos_por_anio (siempre completo).

#### 6.2.4 VUT LY (Vida Util Transcurrida al cierre del ejercicio anterior)

Si el archivo LY ya trae el dato VUT LY, se usa directamente (convertido a la unidad del criterio).

Si no viene (caso de altas del ejercicio y transferencias), se calcula:

- **Rubros trimestrales:**
```
Si anio_alta == anio_ejercicio:
  vut_ly = 0 (el bien no existia al cierre anterior)
Sino:
  vut_ly = min((anio_ejercicio - anio_alta - 1) * 4 + trim_primer_anio, vu_asignada)
```
- **Rubros anuales (formula del Excel manual):**
```
vut_ly = min(vu_asignada, anio_ejercicio - anio_alta)     (entero; 0 si el alta es del ejercicio)
```

#### 6.2.5 VUT del ejercicio (periodos devengados en el ejercicio actual)

```
Si anio_alta == anio_ejercicio:
  vut_ejercicio = trim_primer_anio  (trimestres restantes del primer anio en rubros trimestrales, 1 en anuales)
Sino:
  vut_ejercicio = periodos_hasta_baja  (4 en trimestrales sin baja, 1 en anuales)

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

La PG replica la del Excel del estudio, que trabaja con la **amortizacion del ejercicio (flujo)** y no con la acumulada: "Amortizacion s/revaluo" del Excel es la suma de la columna "Amort. Historica" del ejercicio (verificado al centavo contra la PG 2023 en todos los rubros). La amortizacion del ejercicio anterior sale de la columna "Amort. Historica" del Excel LY (`amort_hist_ly`).

Para cada rubro se calcula:

| Componente                     | Formula                                                                                         |
|--------------------------------|-------------------------------------------------------------------------------------------------|
| amort_inicio                   | Suma de amort_hist_ly (flujo del ejercicio anterior) de activos existentes + activos dados de baja en el ejercicio (su flujo se conserva en la fila de baja) |
| amort_altas                    | Suma de amort_hist_ejercicio de las altas del ejercicio                                         |
| amort_transferencias           | Suma de amort_hist_ejercicio de las transferencias del ejercicio                                |
| amort_bajas                    | -Suma de amort_hist_ly de las bajas del ejercicio (signo negativo: se revierte)                 |
| bs_agotaron_vu_ly              | -Suma de amort_hist_ly de activos existentes con VU agotada al cierre anterior (su amortizacion del ejercicio anterior no se repite). Equivale a la columna "Amortizacion del LY de bienes agotados" del Excel |
| amort_irregular                | Suma de (amort_hist_ejercicio - amort_hist_ly) de activos existentes con VU no agotada: primer periodo parcial del ejercicio anterior (ej. Edificios dados de alta a mitad de anio). Equivale a "Bienes con amort. irregular" del Excel |
| **amort_prueba**               | amort_inicio + amort_altas + amort_transferencias + amort_bajas + bs_agotaron_vu_ly + amort_irregular |
| **amort_revaluo**              | Suma de amort_hist_ejercicio de todos los activos EXCEPTO las bajas del ejercicio (= "Amortizacion s/revaluo" del Excel) |
| **diferencia**                 | amort_prueba - amort_revaluo (debe tender a 0)                                                  |

Nota: `amort_bs_agotaron_vu_ly` (columna calculada en `04_calculo_axi.R`) ya no entra en la PG: calculaba cuota x periodos para *todos* los bienes agotados (5 a 10 veces lo que reporta el Excel). Se conserva en el resultado por compatibilidad.

Control contra el Excel 2023 (millones de $): inicio Edificios 23,03, Eq. de Oficina 82,58; "agotaron VU" Software -80,15, MyU -8,81; irregular Edificios 3,21. El modelo da los mismos valores.

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

Replica "s/revaluo" de la PG AXI del Excel del estudio: **sin las bajas del ejercicio** (salen del saldo; en el Excel se listan aparte). Incluirlas sumaba su AXI y desviaba el total (Edificios +2 M, Maquinas y Equipos +7 M). Para cada rubro:

| Componente                     | Formula                                                     |
|--------------------------------|-------------------------------------------------------------|
| vo_reexp                       | Suma de vo_reexp de los activos que no son bajas del ejercicio |
| amort_acum_reexp               | Suma de amort_acum_cierre_reexp (idem)                      |
| amort_ejercicio_reexp          | Suma de amort_ejercicio_reexp = amort_hist_ejercicio x coeficiente de cada bien (1 para anteriores a 2018 salvo criterio IPIM). Es "Amortizacion s/revaluo" de la PG AXI; coincide al centavo con el Excel 2023 |
| vr_reexp                       | Suma de vr_reexp (idem)                                     |
| vr_hist                        | Suma de vr (idem)                                           |
| **axi_resultado**              | vr_reexp - vr_hist                                          |

El AXI (Ajuste por Inflacion Impositivo) es la diferencia entre el Valor Residual reexpresado y el Valor Residual historico. Contra el Excel 2023 coincide en todos los rubros salvo Terrenos (VR historico pegado a mano en el Excel).

Nota: `amort_hist_reexp` (solo bienes 2018+, columna "Amort. Reexp. 2018/2019/..." del Excel) se conserva; la PG usa `amort_ejercicio_reexp` porque "Amortizacion s/revaluo" del Excel incluye tambien los bienes anteriores a 2018.

La PG de valor residual usa como "Bajas valor residual" el VR congelado a LY de las bajas (`vr_ly`), igual que el Excel (Edificios -11,23 M, Eq. de Oficina -1,25 M, Maquinas y Equipos -1,29 M en 2023).

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

Compara las filas de detalle del archivo SAP (antes de filtrar por rubro, IFRS 16 y obras en curso) contra los conteos esperados del ejercicio (`CONTEOS_MOVIMIENTOS_ESPERADOS` en `utils.R`, por anio):
- 2023: altas 4873, bajas 1717, transferencias 1738
- 2022: altas 2978, bajas 4042, transferencias 2125

Si difiere: ERROR. Si el ejercicio no esta en la tabla: ADVERTENCIA (conteo omitido). La auditoria tambien informa `filas_importadas` (las que quedan tras los filtros). Antes se comparaban las filas ya filtradas contra el total del archivo, por lo que el control nunca podia cuadrar.

### 8.6 Valores reexpresados negativos (validar_valores_reexpresados_negativos)

Marca activos con VO o VR reexpresado negativo **cuyo VO no es negativo** (un VO negativo es una reversa o una transferencia de salida, y el Excel del estudio tiene esas filas). El ruido de punto flotante (|valor| < 0,01) no cuenta:
```
Si vo >= 0 y (vo_reexp < -0,01 o vr_reexp < -0,01): ERROR
```

### 8.7 Excepciones de fecha base (validar_excepciones_fecha_base)

Reporta cuantos activos por rubro tienen una excepcion de fecha base aplicada. No genera ERROR, solo informativo (OK con detalle).

### 8.8 Comparacion contra real — Price/KPMG (validar_contra_real)

Si se proporciono el archivo de validacion externa (Excel del manual Price/KPMG), compara por rubro y en total:

**Magnitudes comparadas:**
- Amortizacion del ejercicio (amort_revaluo vs "Amortizacion s/revaluo" del Excel; las filas se buscan por etiqueta en las hojas PG y PG AXI, porque la posicion cambia de un anio a otro)
- Valor Residual (vr_revaluo vs manual)
- AXI (axi_resultado vs manual)
- Amortizacion AXI (amort_ejercicio_reexp vs "Amortizacion s/revaluo" de la PG AXI), si el archivo la trae

**Calculo de diferencia porcentual:**
```
pct = |propio - real| / |real|

Si |real| <= 0.01 y |diferencia| <= 0.01: pct = 0
Si |real| <= 0.01 y |diferencia| > 0.01: pct = 1 (100%)
```

**Resultado:**
```
Si pct <= 0,1% (UMBRAL_REPLICA_EXTERNA): OK (replica el Excel)
Si pct <= 20% (TOLERANCIA_VALIDACION_EXTERNA): ADVERTENCIA (dentro de la tolerancia pero no lo replica)
Si pct > 20%: ERROR
```
(Antes era OK hasta 20%, lo que daba por bueno, por ejemplo, 2 M de diferencia de AXI en Edificios.)

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
