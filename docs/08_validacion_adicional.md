# Fase 0.5 — Validaciones Adicionales

---

## V-03 — División por 4 de la VU Asignada del LY en rubros no-Edificios

### Código involucrado

`02_limpiar_datos.R:87-93`:
```r
vu_rubro <- obtener_vu_asignada(rubro)
resultado$vu_asignada <- if (!is.na(idx_vu_asig)) {
  vu_archivo <- as.numeric(datos[[idx_vu_asig]])
  if (rubro == "Edificios") vu_archivo else vu_archivo / 4
} else {
  vu_rubro
}
```

### Análisis

La columna "VU Asignada" del Excel del estudio guarda:
- **Edificios:** trimestres (200). El R la toma tal cual → `vu_asignada = 200`. **Correcto.**
- **Todos los demás rubros:** **años**. Verificado hoja por hoja:

| Rubro | VU en el estudio (col H) | Unidad | Resultado del `/ 4` | VU correcta |
|---|---|---|---|---|
| Cercos | 50 | años | 50/4 = **12.5** | 50 |
| Eq de Oficina | 3 | años | 3/4 = **0.75** | 3 |
| Maquinas y Equipos | 10 | años | 10/4 = **2.5** | 10 |
| Maquinas Mejoras | 10 | años | 10/4 = **2.5** | 10 |
| MyU | 3 | años | 3/4 = **0.75** | 3 |
| Rodados | 5 | años | 5/4 = **1.25** | 5 |
| Terreno Mejoras | 10 | años | 10/4 = **2.5** | 10 |
| Software | 3 | años | 3/4 = **0.75** | 3 |

### Activo real por rubro — verificación del efecto

**Rodados**, activo `405489000878` (Row 10, hoja Rodados del estudio 2023):
- Estudio: VO=40.155,86 | VU Asignada (col H)=10 | VUT LY=10 | VUT=10 | Amort Acum=40.155,86
- Código R: lee VU=10, aplica `/4` → `vu_asignada = 2.5`
- Cuota R: `40.155,86 / 2.5 = 16.062,34` por año → **multiplicada por 4**
- Cuota correcta: `40.155,86 / 10 = 4.015,59` por año

Sin embargo, este activo ya tiene VUT=VU (agotada), así que el efecto es neutralizado: `amort_acum = cuota × min(VUT, VU) = 16.062,34 × 2.5 = 40.155,86`. El total cuadra pero por razones equivocadas (la cuota y la VU están ambas divididas/multiplicadas por 4).

**Pero hay un caso donde el error NO se cancela:** cuando `vut_ly` viene del Excel LY como dato (en años enteros) y `vu_asignada` fue dividida por 4, el cálculo `vut_ly < vu_asignada` comparará años con la VU reducida. Para el activo de arriba: `vut_ly=10` (años) vs `vu_asignada=2.5` → `10 >= 2.5` → VU ya agotada. Sin la división: `10 >= 10` → también agotada. Coinciden aquí. Pero para un activo con alta reciente donde VUT_LY < VU original:

**Eq de Oficina**, alta 2022, VU=3, VUT_LY=1:
- Estudio: VU=3 años, VUT LY=1, VUT=2
- R: `vu_asignada = 3/4 = 0.75`. Pero `vut_ly = 1` (del Excel, en años). `1 >= 0.75` → **VU ya agotada**. El R no amortizaría este activo cuando debería.
- Correcto: VU=3, VUT_LY=1, amort del ejercicio = VO/3 × 1 año.

### Conclusión V-03

**El `/4` es un error.** Para activos con VU agotada (la mayoría de pre-2018), el efecto se neutraliza. Pero para activos recientes con VUT_LY < VU, la comparación falla y puede suprimir amortización o distorsionar la cuota.

**Sin embargo**, hay un mecanismo de mitigación: si el Excel LY no tiene columna "VU Asignada" (posible en algunos formatos), el código usa `obtener_vu_asignada(rubro)` que devuelve el valor correcto (años para muebles, trimestres para Edificios). El error solo se manifiesta cuando la columna VU Asignada se detecta en el Excel por el regex `vu.*asignada`.

**Verificación adicional necesaria:** ejecutar el pipeline con el Excel 2023 y revisar cuántos activos tienen `vu_asignada != obtener_vu_asignada(rubro)` después de la limpieza.

---

## V-06 — `amort_hist_reexp` = 0 para bienes pre-2018

### Código involucrado

`04_calculo_axi.R:109-113,149-153`:
```r
amort_hist_2018 = if_else(anio_alta >= ANIO_CORTE_REVALUO, amort_hist_ejercicio, 0)
...
amort_hist_reexp = if_else(anio_alta >= ANIO_CORTE_REVALUO, amort_hist_2018 * coef_ipc, 0)
```

### Análisis

El campo `amort_hist_reexp` (amortización histórica reexpresada) representa la amortización del ejercicio multiplicada por el coeficiente de actualización. Para bienes pre-2018:
- `amort_hist_2018 = 0` (línea 113)
- `amort_hist_reexp = 0` (línea 153)

Esto significa que **la amortización del ejercicio de bienes pre-2018 NO se informa como reexpresada**.

### Qué informa el R como "amortización del ejercicio deducible"

El R tiene dos conceptos separados:
1. **`amort_hist_ejercicio`** (`04_calculo_axi.R:103-107`): amortización histórica del ejercicio. Se calcula para **todos** los activos (pre y post 2018). Participa en la PG histórica.
2. **`amort_hist_reexp`** (`04_calculo_axi.R:149-153`): amortización del ejercicio reexpresada. Es **0 para pre-2018**.

La PG AXI del estudio (Row 11, 13) muestra:
- Row 11: "Bienes con amort. irregular..." con montos significativos por rubro
- Row 13: "Amort. Historica 2018/2019/2020/2021/2023" — **nota que dice 2018+**

Esto confirma que la amortización reexpresada del estudio **solo incluye bienes desde 2018**, consistente con el escenario A (coef=1 para pre-2018: amort reexp = amort × 1 = amort histórica, que no se reporta aparte).

### Impacto

Con el criterio normativo (coef=1 para pre-2018), la amortización reexpresada de pre-2018 es igual a la histórica. No genera diferencia en el AXI (AXI = VR_reexp - VR = VR×1 - VR = 0 para pre-2018). El R es **consistente con este criterio** en el campo `amort_hist_reexp`.

Sin embargo, el total "Amortización del ejercicio" que el R reporta en la PG (`generar_pg_amortizaciones`, línea 58-61) incluye `amort_hist_ejercicio` de **todos** los activos. Lo que no incluye es la versión reexpresada para pre-2018, pero eso no afecta la PG histórica.

**Conclusión:** El tratamiento de `amort_hist_reexp = 0` para pre-2018 es **correcto** bajo el escenario A (coef=1). La amortización histórica del ejercicio de pre-2018 se incluye en la PG histórica normalmente.

---

## PA-16 — Bajas: ¿el estudio amortiza el año de baja?

### Evidencia del Excel del estudio 2023

#### Edificios — Bajas 2023

Activo `9` (Cámara fría n°1 Tucuman), Row 4824 de la hoja Edificios:
- Alta: 2015 | VO: 146.300 | VU: 200 trimestres
- **VUT LY (col L): 27** trimestres (al 31/12/2022)
- **VUT (col M): 31** trimestres (al cierre 2023)
- **Amort del ejercicio (K): 0** (o vacío)
- **Amort Acum (N): 2.926** = 146.300/200 × ... → cuota_trim = 731,50 × algo

El VUT pasó de 27 a 31 → **se sumaron 4 trimestres** en el año de baja. Esto significa que el estudio **SÍ amortiza Edificios en el año de baja** (los 4 trimestres completos del ejercicio).

Activo `405482001025` (Módulo Sanitario), Row 4826:
- Alta: 2017 | VO: 23.516,36 | VU: 200
- VUT LY (L): 20 | VUT (M): 24 → +4 trimestres
- Cuota: 23.516,36/200 = 117,58/trim. Amort del ejercicio = 470,33 (= 117,58 × 4)

**Confirmado: Edificios se amortizan 4 trimestres completos en el año de baja.**

#### Bienes muebles — Bajas de Rodados

No se encontraron bajas explícitas dentro de la hoja Rodados del estudio 2023 (las bajas de Rodados se "eliminan del revalúo y se exponen en la parte inferior" según el encabezado de Edificios, pero en Rodados todas las filas visibles son históricos/altas/transferencias con VU agotada).

**Evidencia indirecta de la hoja PG:**

La fila "Amortización de las bajas" del PG (Row 17) muestra:
```
Cercos=-686 | Edificios=0 | Eq Oficina=-6.679.046 | Maquinas=-8.615.038 |
MaqMejoras=-125.160 | MyU=-8.812.300 | Rodados=-563.761 | TerrenoMejoras=-68.103 |
Software=-80.149.397
```

**Esta fila es negativa** y se suma a la amortización del inicio para llegar a la amortización al cierre. Analizando la estructura completa de la PG de amortizaciones:

```
Amort al inicio (Row 11)
+ Amort de las altas (Row 12)
+ Amort transferencias (Row 13)
  [filas intermedias de correcciones]
- Amort de las bajas (Row 17)    ← ESTA FILA
= Amort s/prueba (Row 19)
```

La fila Row 17 para Edificios = 0, lo cual NO coincide con que calculan 4 trimestres de amort en el año de baja. Esto sugiere que **"Amortización de las bajas"** en la PG **no es la amortización del año de baja**, sino la **amortización acumulada que se retira** junto con el bien.

**Verificación cruzada con la fila Row 19 "Amort s/prueba":**
```
Amort s/prueba = 2.550 + 39.733.727 + ... = 1.179.524.957
```
Y Row 20 "Amort s/revalúo" = 1.179.530.261 con diferencia -5.304.

La prueba cuadra, lo que confirma que:
- "Amort de las bajas" = amort acumulada del bien hasta el inicio del ejercicio (LY), que se retira
- La amort del ejercicio de la baja se incluye en "Amort del ejercicio" general

### Conclusión PA-16

1. **Edificios:** el estudio amortiza 4 trimestres completos en el año de baja (VUT pasa de LY a LY+4).
2. **Bienes muebles:** no se pudo verificar directamente con activos individuales (los muebles visibles tienen VU agotada). Pero la estructura de la PG indica que la "Amortización de las bajas" es la **acumulada que se retira**, no la del año. La amortización del ejercicio de bienes dados de baja se contabiliza normalmente.
3. **El R:** para no-Edificios, computa `periodos_hasta_baja = 1` (año completo). Si la norma dice "año de baja sin amortización", hay conflicto. Pero **el estudio parece amortizar el año de baja** (al menos para Edificios).
4. **Recomendación:** Mantener el criterio del estudio (amortizar el año de baja) hasta tener confirmación normativa explícita. Documentar como decisión de criterio.

---

## V-08 — Estructura de las tablas "IPC - VR Bajas" e "IPIM - VR Bajas"

### Datos extraídos

**Hoja "IPC" (normal):** sheet19.xml
```
Fecha(serial)  IPC_periodo  IPC_cierre  Coeficiente
43101(2018-01-01)  126.9887   3533.19     27.8229
43102(2018-01-02)  126.9887   3533.19     27.8229
...
```

**Hoja "IPC - VR Bajas":** sheet20.xml
```
Fecha(serial)  IPC_periodo  IPC_referencia  Coeficiente
43101(2018-01-01)  126.9887   1134.59        8.9346
43102(2018-01-02)  126.9887   1134.59        8.9346
...
```

### Estructura

Ambas tablas tienen **exactamente la misma estructura**: 4 columnas, registros diarios desde 2018-01-01, indexadas por fecha de alta del bien.

La diferencia está en la **columna C (IPC de referencia)** y el **coeficiente resultante**:

| Tabla | Col B (IPC período) | Col C (IPC referencia) | Col D (Coeficiente) | Interpretación |
|---|---|---|---|---|
| **IPC** | IPC del mes de alta | **IPC al 31/12/2023** (3.533,19) | IPC_cierre / IPC_alta | Reexpresa a moneda de cierre del ejercicio |
| **IPC - VR Bajas** | IPC del mes de alta | **IPC a otra fecha** (1.134,59) | IPC_ref / IPC_alta | Reexpresa a otra fecha (¿fecha de baja?) |

El valor 1.134,59 como IPC de referencia para la tabla de bajas probablemente corresponde al IPC de una fecha intermedia del ejercicio (¿julio 2023? ¿promedio del año?). La fórmula del coeficiente es `Col C / Col B`.

### Cómo las usa el R

`04_calculo_axi.R:245-285` (`calcular_bajas_reexp`):
- Para bienes dados de baja, busca el coeficiente en la tabla de bajas usando `fecha_indice_reexp` (que para bajas SAP es la fecha de la baja).
- Los valores `amort_bajas` y `vr_bajas` se calculan **además** de los valores normales reexpresados.

### Conclusión V-08

Las tablas IPC/IPIM - VR Bajas están indexadas **por fecha de alta del bien** (misma estructura que las normales), pero usan un IPC de referencia diferente al cierre. Esto permite reexpresar el VR de la baja a una fecha distinta del cierre del ejercicio — posiblemente la fecha de baja o una fecha de corte específica para el cálculo del resultado de venta.

**No están indexadas por fecha de baja.** El lookup sigue siendo por fecha de alta del bien, igual que las tablas normales.

---

## V-14 — Bienes con amortización irregular (paso de trimestre a año)

### Evidencia del estudio

El shared string "Bienes con amort. irregular (paso de trimestre de alta a año completo)" aparece en el Excel del estudio 2023 (string index 14225). También aparece "Bienes con amort. irregular reexpresadas" (string index 14248).

Esto indica que algunos activos de bienes muebles (no Edificios) fueron originalmente calculados con amortización trimestral y luego migrados a anual. La migración genera una "irregularidad" en la amortización acumulada: los trimestres devengados bajo el cálculo anterior no coinciden exactamente con los años que deberían haberse contado.

### Dónde aparece en el estudio

En la PG AXI (Row 11), la fila etiquetada "Bienes con amort. irregular (paso de trimestre de alta a año completo)" muestra montos significativos por rubro:

| Rubro | Monto irregular |
|---|---|
| Cercos | 3.236 |
| Edificios | 127.277.287 |
| Eq de Oficina | 518.436.421 |
| Maquinas y Equipos | 1.701.475.531 |
| Maquinas Mejoras | 1.352.551 |
| MyU | 190.386.633 |
| Rodados | 1.317.841.754 |
| Terreno Mejoras | 129.010.791 |
| Software | 1.997.612.571 |

Estos montos son **amortización acumulada reexpresada** de activos con cálculo irregular.

En la hoja MyU del estudio, se menciona: "Los bienes que se encuentran en verde deben ser actualizados manualmente (no están por fórmulas) ya que venían arrastrando problemas."

### Cómo los trata el R

El código R **no tiene un mecanismo específico** para bienes con amortización irregular. Al importar un bien del LY:

1. Si el LY trae `VUT LY` como dato, se usa directo (`02_limpiar_datos.R:95-99`). Esto preserva la VUT del estudio, que ya incorpora el ajuste irregular.
2. Si `VU Asignada` viene del LY, se aplica el `/4` de V-03 (potencialmente erróneo).
3. La amortización acumulada **no se importa del LY** — se recalcula como `cuota × VUT_cierre`.

El problema surge porque:
- El estudio puede tener `amort_acum` calculada con la fórmula irregular (trimestres parciales convertidos a años)
- El R recalcula desde cero con `VO / VU × VUT`
- Si la VUT del LY incluye el ajuste irregular pero la VU fue dividida por 4, la amortización recalculada no coincidirá con la del estudio

### Ejemplo concreto

Un bien de Rodados con:
- Alta 2015, VU=5, VUT LY estudio=5 (VU agotada, en años)
- El estudio calculó originalmente en trimestres (20 trimestres) y luego migró a años (5)
- El R lee VUT_LY=5 del Excel → OK
- El R lee VU Asignada=5 del Excel → aplica `/4` → `vu_asignada=1.25`
- Cuota R: `VO / 1.25` = 4× la correcta
- Amort acum R: `cuota × min(5, 1.25)` = `(VO/1.25) × 1.25` = VO → coincide de casualidad

Para bienes con VU no agotada, el efecto del `/4` y la irregularidad se combinan de forma impredecible.

### Conclusión V-14

1. Los "bienes con amort. irregular" son activos migrados de cálculo trimestral a anual. Son significativos en monto (miles de millones en la PG AXI reexpresada).
2. El R no tiene tratamiento especial para ellos. Depende de que el VUT_LY del Excel preserve el ajuste.
3. El problema principal no es la irregularidad en sí, sino la combinación con V-03 (`/4`) que distorsiona VU.
4. **Recomendación para Fase 1:** Eliminar el `/4`, usar años directamente para muebles. Los bienes irregulares se reconciliarán automáticamente si VUT_LY viene del Excel.
