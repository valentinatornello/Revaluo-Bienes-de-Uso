# Fase 0.5+ — Análisis de Bajas, Art. 39 Ley 24.073 y PG Baseline

---

## 1. Bajas de muebles: ¿doble cómputo? (art. 62 LIG)

### Datos del estudio 2023

**Bajas de Maquinas y Equipos 2023** (Excel hoja Maquinas y Equipos, sección Bajas 2023):

| Activo | Alta | VO ($) | VU | VUT_LY | VUT | delta | Amort hist ej | Amort acum |
|---|---|---|---|---|---|---|---|---|
| 405483007215 | 2005 | 456.248 | 10 | 10 | 10 | **0** | 0 | 456.248 |
| 405483008097 | 2005 | 277.014 | 13 | 13 | 13 | **0** | 0 | 277.014 |
| 405483008596 | 2006 | 134.345 | 7 | 7 | 7 | **0** | 0 | 134.345 |
| 405483008767 | 2006 | 10.155 | 5 | 5 | 5 | **0** | 0 | 10.155 |
| 405483008833 | 2006 | 55.674 | 10 | 10 | 10 | **0** | 0 | 55.674 |

**Observación clave:** En todas las bajas de muebles 2023, **VUT_LY = VUT = VU** y **delta = 0**. La VU ya estaba agotada antes de la baja. El estudio **no amortiza el año de baja** para estos activos porque no hay amortización pendiente.

**Bajas de Maquinas 2015** (datos que sí tienen amort_hist):

| Activo | VO ($) | VU | amort_hist | amort_acum | VR |
|---|---|---|---|---|---|
| 405483003135 | 22.773 | 10 | 2.277 | 22.773 | 72.112 |
| 405483006621 | 1.700 | 10 | 170 | 1.700 | 5.756 |
| 405483006692 | 13.015 | 10 | 1.302 | 13.015 | 42.882 |

Acá `amort_hist = VO/VU` (cuota anual exacta) y `amort_acum = VO` (VU agotada). El VR es > 0 porque incluye la reexpresión IPIM.

### Conclusión sobre doble cómputo (art. 62 LIG)

No se pudo verificar doble cómputo porque **todas las bajas de muebles encontradas en el estudio 2023 tienen VU agotada** (VUT = VU). En estos casos:
- Amortización del año de baja = 0 (no queda nada por amortizar)
- Costo computable = VO - amort_acum = 0 (en valores históricos)
- No hay riesgo de doble cómputo

**Para verificar el doble cómputo se necesitaría una baja de mueble con VU no agotada** (ej: un bien con VU=10 y solo 5 años de uso). En la base 2023 no hay ninguno. Si existieran, la regla del art. 62 exige que la amortización deducida en el año de baja se reste del costo computable.

---

## 2. Bajas de Edificios: año completo vs trimestre anterior

### Datos del estudio 2023

**Edificios — Bajas 2023** (Excel hoja Edificios, sección Bajas 2023, datos de extracción Node.js confirmados):

| Activo | Desc | Alta | VO ($) | VU (trim) | VUT_LY | VUT | delta trim |
|---|---|---|---|---|---|---|---|
| 9 | Cámara fría n°1 Tucumán | 2015 | 146.300 | 200 | 27 | 31 | **+4** |
| 405482001004 | Cámara fría n°2 Tucumán | 2015 | 132.100 | 200 | 27 | 31 | **+4** |
| 405482001025 | Módulo sanitario 20 feet | 2017 | 23.516 | 200 | 20 | 24 | **+4** |

### Comparación de criterios

Para el activo "Cámara fría n°1" (VO=146.300, VU=200, cuota=731,50/trim):

| Criterio | VUT del año de baja | Amort ejercicio ($) | Fundamento |
|---|---|---|---|
| **Estudio** | 4 trimestres | 731,50 × 4 = **2.926,00** | Año completo |
| **R actual** | Hasta trim de baja incl. | Depende de la fecha de baja | `floor((mes_baja-1)/3)+1` trimestres |
| **Art. 87 LIG** | Trim **anterior** al de baja | 731,50 × (trim_baja − 1) | "hasta el trimestre inmediato anterior a aquel en que los bienes se enajenen" |

**Diferencia en $ por activo:**

Si la baja ocurrió en Q2 (abril-junio 2023):

| | Trim amortizados | Amort ejercicio | Diferencia vs estudio |
|---|---|---|---|
| Estudio (4 trim) | 4 | $2.926,00 | — |
| R (hasta trim baja incl = Q2) | 2 | $1.463,00 | −$1.463,00 |
| Art. 87 (trim anterior = Q1) | 1 | $731,50 | −$2.194,50 |

Si la baja ocurrió en Q4 (oct-dic 2023):

| | Trim amortizados | Amort ejercicio | Diferencia vs estudio |
|---|---|---|---|
| Estudio (4 trim) | 4 | $2.926,00 | — |
| R (hasta trim baja incl = Q4) | 4 | $2.926,00 | $0 |
| Art. 87 (trim anterior = Q3) | 3 | $2.194,50 | −$731,50 |

**El art. 87 dice claramente "hasta el trimestre inmediato anterior a aquel en que los bienes se enajenen o desafecten".** El estudio amortiza 4 trimestres completos (año entero), lo cual contradice la norma salvo que la baja ocurra en Q1 del año siguiente. El R amortiza hasta el trimestre de baja inclusive, que también excede la norma en 1 trimestre.

### Recomendación

El criterio normativo correcto es: **trimestre anterior al de la baja**. Para la Fase 1, este debería ser el default, con switch a "trimestre de baja inclusive" o "año completo" si el estudio o Impuestos lo justifican.

---

## 3. Art. 39, Ley 24.073 — Texto literal y análisis

### Texto literal (fuente: InfoLEG, texto actualizado)

> **ARTICULO 39.** A los fines de las actualizaciones de valores previstas en la ley 11.683, texto ordenado en 1978 y sus modificaciones, y en las normas de los tributos regidos por la misma, no alcanzados por las disposiciones de la ley 23.928, las tablas e índices que a esos fines elabora la DIRECCIÓN GENERAL IMPOSITIVA para ser aplicadas a partir del 1º de abril de 1992 deberán, en todos los casos, tomar como límite máximo las variaciones operadas hasta el mes de marzo de 1992, inclusive.
>
> En idéntico sentido se procederá respecto de las actualizaciones previstas en el Código Aduanero (ley 22.415 y sus modificaciones).
>
> El PODER EJECUTIVO NACIONAL en oportunidad de proceder al ordenamiento de las citadas disposiciones deberá efectuar las adecuaciones de texto pertinentes en virtud de lo establecido en el párrafo anterior.

### Qué implica para bienes anteriores a 1992

El art. 39 de la Ley 24.073 **congela** los índices de actualización al nivel de marzo de 1992. Desde abril 1992, los índices publicados por DGI/AFIP no pueden reflejar variaciones posteriores a marzo 1992.

Para bienes de uso adquiridos **antes de 1992:**

1. **Actualización sí hubo** hasta marzo 1992. El costo de adquisición original se actualizó con los índices vigentes hasta ese mes. Esto produce un coeficiente > 1 (del mes de compra hasta marzo 1992).

2. **Desde abril 1992:** el coeficiente queda congelado. No hay actualización adicional. El art. 93 LIG confirma: "las actualizaciones previstas en esta ley se practicarán conforme lo establecido en el artículo 39 de la Ley N° 24.073".

3. **Desde 2018:** la Ley 27.430 introduce el IPC para bienes adquiridos en ejercicios desde el 01/01/2018, sin modificar el tratamiento de bienes anteriores.

**Consecuencias prácticas:**

| Período de adquisición | Tratamiento | Coeficiente |
|---|---|---|
| Antes de marzo 1992 | Actualizado hasta marzo 1992 con índices históricos; congelado después | > 1 (índice mar-1992 / índice compra) |
| Abril 1992 — dic 2017 | Congelado desde abril 1992 | = 1 (no hay actualización) |
| Desde enero 2018 | IPC (art. 93 segundo párrafo) | IPC cierre / IPC compra |

**Para el estudio:** los bienes pre-1992 ya estaban "reexpresados a marzo de 1992" según el encabezado de Edificios. Esto confirma que el coeficiente de estos bienes **no es 1** sino el cociente del índice a marzo 1992 sobre el índice de la fecha de compra original. El estudio usa la fecha base 1992 (no la original) para buscar el coeficiente, lo cual da coef=1 **desde** 1992, pero el VO ya incorpora la actualización **hasta** 1992.

**Para el R:**
- No implementa el corte pre-1992 → busca el coeficiente con la fecha original → si hay datos de índices para fechas pre-1992 en la tabla, aplicaría un coeficiente incorrecto
- La corrección B-02 (corte automático a 01/01/1992) es necesaria pero insuficiente: el VO de estos bienes ya debería estar actualizado a valores de marzo 1992 en la base del LY

---

## 4. PG Baseline del R (año 2022, sin cambios)

### Totales del R

| Magnitud | R baseline | Observación |
|---|---|---|
| Amort acum s/revalúo | $5.649.171.870 | — |
| VR s/revalúo | $2.279.176.819 | — |
| VR reexpresado | $29.544.688.949 | Inflado por B-01 (IPIM pre-2018) |
| AXI resultado | $27.265.512.130 | Inflado por B-01 |

### Problemas detectados

1. **VR negativos masivos** (22.153 activos con VO/VR reexpresado negativo). Causa: V-03 (`/4` en VU de muebles). Con VU=0.75 para Eq Oficina, la cuota es 4× la correcta y la amort_acum excede el VO.

2. **PG no cuadra** (diferencias de miles de millones en amort y VR). Causa combinada de V-03 y la división VUT_LY (del Excel en años) / VU (dividida por 4).

3. **Comparación con PG real falló**: `leer_pg_real()` no pudo mapear los rubros de la hoja PG del Excel 2022 (formato pivotado diferente).

4. **AXI = $27.3B** está inflado por B-01 (IPIM × VO para bienes pre-2018 amplifica el VR reexpresado).

### Tabla IPC vs IPC-VR Bajas

| Campo | IPC (normal) | IPC-VR Bajas |
|---|---|---|
| Col B (IPC período) | 126,9887 | 126,9887 |
| Col C (IPC referencia) | **3.533,19** (IPC dic 2023) | **1.134,59** (IPC dic 2022) |
| Col D (coeficiente) | **27,82** | **8,93** |
| Ratio normal/bajas | — | 3,11× |

**Interpretación:** La tabla IPC-VR Bajas actualiza al cierre del **ejercicio anterior** (dic 2022), no al cierre actual (dic 2023). Esto es consistente con el art. 62 penúltimo párrafo LIG: "actualizarán los costos... hasta la fecha de cierre del ejercicio anterior a aquél en que se realice la enajenación".

El R busca el coeficiente de bajas usando `fecha_indice_reexp` (que para bajas SAP es la fecha de posting de la baja, no la de alta). **Esto es un error:** debería buscar por fecha de alta del bien, no por fecha de la baja. La tabla está indexada por fecha de alta.
