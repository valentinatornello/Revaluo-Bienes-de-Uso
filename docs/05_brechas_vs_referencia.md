# T0.5 — Brechas entre el Código R y la Referencia del Estudio Externo 2023

## Resumen de brechas

| # | Concepto | Clasificación | Descripción |
|---|---|---|---|
| B-01 | Coeficiente pre-2018 | **Diferencia de criterio** | El R usa IPIM; el estudio (escenario A) usa coef=1 |
| B-02 | Fecha ajustada pre-1992 | **No implementado** | El R no aplica el corte automático a 01/01/1992 |
| B-03 | Bajas parciales | **No implementado** | El R solo procesa bajas totalmente depreciadas (ret_book_value ≈ 0) |
| B-04 | Unidad de Rodados (VUT) | **Diferencia de criterio** | El spec dice "años" y el R también, pero el cálculo intermedio pasa por trimestres y divide, pudiendo dar fracciones |
| B-05 | Índices separados para bajas | **Diferencia de criterio** | El R usa tablas IPC/IPIM de bajas separadas; el spec no las menciona |
| B-06 | Prorrateo primer año (no-Edificios) | **Diferencia de criterio** | El R no prorratea por mes para rubros no-Edificios: siempre cuenta 1 año |
| B-07 | amort_hist_2018 (AE solo post-2018) | **Diferencia de criterio** | El R tiene `amort_hist_2018` que es AE solo para ≥2018; para <2018 es 0 |
| B-08 | Transferencias: amort transferida | **No implementado** | `transf_dep` se lee pero no se usa en cálculos |
| B-09 | Switch de escenario A/B | **No implementado** | No existe un parámetro para alternar entre coef=1 y IPIM para pre-2018 |
| B-10 | VR nunca negativo | **Idéntica (por construcción)** | El spec dice `max(VO-AA; 0)`, el R no usa `max` pero el resultado es equivalente |
| B-11 | Resultado de venta de bajas | **No implementado** | El spec menciona `precio - VR_R`; el R no calcula resultado de venta |

---

## Detalle por concepto

### B-01 — Coeficiente pre-2018: IPIM vs coef=1

**Referencia (spec 4.12):** Escenario A (base del estudio): bienes pre-2018 → coef = 1 (valor histórico). Escenario B (alternativo): se aplica IPC real.

**Código R:** `04_calculo_axi.R:143-147`
```r
vo_reexp = if_else(anio_alta >= ANIO_CORTE_REVALUO,
                   vo * coef_ipc,
                   vo * coef_ipim)
```

**Brecha:** El R aplica **IPIM** para pre-2018, que no es ni el escenario A (coef=1) ni el B (IPC). Es un tercer criterio documentado en `reglas_negocio.md`: "Se usa IPIM para la confiscatoriedad". Esto afecta VO_R, AA_R, AA_LY_R, VR_R y por tanto el AXI total.

**Impacto:** Para la comparación numérica contra el estudio 2023, los valores reexpresados de bienes pre-2018 serán diferentes.

**Clasificación:** Diferencia de criterio.

---

### B-02 — Fecha ajustada pre-1992

**Referencia (spec 4.3):** `FAJ = SI(año(FA) < 1992; 01/01/1992; FA)` — bienes pre-1992 se tratan como si hubieran entrado el 01/01/1992.

**Código R:** `utils.R:119-156` — `aplicar_excepciones_fecha_base()` setea `fecha_indice_reexp = fecha_alta` por defecto. Solo se modifica si hay una excepción manual en el CSV.

**Brecha:** No hay lógica automática para el corte 1992. Si un activo tiene `fecha_alta = 1985-06-15`, su coeficiente se buscará con esa fecha, no con 1992-01-01. El mecanismo de excepciones existe pero requiere listar cada activo pre-1992 individualmente.

**Impacto:** Afecta el coeficiente de actualización de todos los bienes pre-1992. Si hay bienes pre-1992 en la base, sus coeficientes serán incorrectos respecto al estudio.

**Clasificación:** No implementado.

---

### B-03 — Bajas parciales

**Referencia (spec 4.14, 4.4):** [A CONFIRMAR] "¿Se tratan de forma proporcional?"

**Código R:** `01_importar_datos.R:348-352`
```r
# Solo se reconoce la baja cuando el bien queda totalmente depreciado (M = 0).
abs(ret_book_value) < 0.01
```

**Brecha:** Las bajas con `ret_book_value != 0` (bajas parciales o con valor residual contable no nulo) se excluyen completamente del cálculo. El comentario del código dice: "PENDIENTE: consultar con Pablo el tratamiento de las filas con M != 0".

**Impacto:** Si existen bajas parciales significativas, el inventario del R diferirá del estudio.

**Clasificación:** No implementado (pendiente definición de negocio).

---

### B-04 — VUT de Rodados: posible fracción en años

**Referencia (spec 4.6):** Rodados → VUT en años: `VUT = AÑO_CIERRE − AÑO_ALTA (+1?)`.

**Código R:** `utils.R:162-171` calcula VUT en trimestres, luego `04_calculo_axi.R:80-81` convierte:
```r
vut_ly = calcular_vut_ly(...) / 4L * periodos_por_anio
```
Para no-Edificios (`periodos_por_anio = 1`): `vut_ly = trimestres / 4`.

**Brecha:** Si un Rodado tiene trimestres que no son múltiplo de 4 (ej: alta en abril → TPA siempre = 1 para no-Edificios, así que trimestres = `(año_ej - año_alta - 1) * 4 + 1`), la división por 4 da un valor fraccionario. Ejemplo: `(2023-2020-1)*4 + 1 = 9 trimestres / 4 = 2.25 años`.

Sin embargo, dado que `trim_primer_anio = 1` para no-Edificios, el cálculo simplifica a: `vut_ly = ((año_ej - año_alta - 1) * 4 + 1) / 4 = año_ej - año_alta - 1 + 0.25`. La fracción 0.25 es constante. Si el bien fue dado de alta en cualquier mes, siempre tiene +0.25.

**Impacto:** La fracción 0.25 se propaga a la amortización. Puede generar diferencias de redondeo con el estudio si este usa años enteros.

**Clasificación:** Diferencia de criterio.

---

### B-05 — Tablas de índices separadas para bajas

**Referencia (spec 4.14):** Menciona que las bajas se revalúan y retiran, pero no especifica tablas de índices diferentes.

**Código R:** Lee 4 tablas de índices del Excel LY:
- `IPC` / `IPIM` — para activos normales
- `IPC - VR Bajas` / `IPIM - VR Bajas` — para bajas (`01_importar_datos.R:157-183`)

Y en `04_calculo_axi.R:245-285`, los bienes dados de baja se reexpresan con los índices de bajas, no con los normales.

**Brecha:** El uso de tablas de índices separadas para bajas no está documentado en el spec. Los coeficientes de bajas podrían diferir de los normales (ej: valorados a una fecha de corte diferente).

**Clasificación:** Diferencia de criterio (probablemente correcta pero no documentada).

---

### B-06 — Sin prorrateo del primer año para no-Edificios

**Referencia (spec 4.3):** El trimestre de alta se calcula para todos los rubros.

**Código R:** `04_calculo_axi.R:60-64`
```r
trim_primer_anio <- if (rubro_nombre == "Edificios") {
    calcular_trimestres_primer_anio(inv$mes_alta)
} else {
    rep.int(1L, nrow(inv))
}
```

**Brecha:** Para no-Edificios, el primer año siempre cuenta como 1 período completo, sin importar en qué mes se dio de alta. Un Rodado dado de alta en diciembre tiene el mismo VUT del primer año que uno dado de alta en enero. El estudio para Rodados puede prorratear en años o no — está [A CONFIRMAR].

**Clasificación:** Diferencia de criterio.

---

### B-07 — amort_hist_2018: amortización reexpresada solo post-2018

**Referencia (spec 4.13):** `AE_R = AE × COEF` [A CONFIRMAR].

**Código R:** `04_calculo_axi.R:109-113,149-153`
```r
amort_hist_2018 = if_else(anio_alta >= ANIO_CORTE_REVALUO, amort_hist_ejercicio, 0)
amort_hist_reexp = if_else(anio_alta >= ANIO_CORTE_REVALUO, amort_hist_2018 * coef_ipc, 0)
```

**Brecha:** La amortización del ejercicio reexpresada (`amort_hist_reexp`) es 0 para bienes pre-2018. Si el estudio reexpresa AE para pre-2018 (con IPIM o coef=1), habrá diferencia.

**Clasificación:** Diferencia de criterio (vinculada a B-01).

---

### B-08 — Amortización transferida no usada

**Referencia (spec 4.15):** "Se trasladan VO y AA juntos del activo origen al destino".

**Código R:** `01_importar_datos.R:370-371`
```r
transf_dep = as.numeric(suma_de_trans_o_dep)
```
Se lee pero no se usa en `normalizar_movimiento_sap()` ni en `construir_rollforward()`.

**Brecha:** La amortización acumulada transferida (`transf_dep`) no se incorpora al cálculo. El R recalcula la amortización desde cero basándose en `fecha_alta` (que para transferencias es `cap_date_parsed`). Si la amortización recalculada difiere de la transferida, habrá diferencia.

**Clasificación:** No implementado (parcial — se lee el dato pero no se usa).

---

### B-09 — Switch de escenario (A vs B)

**Referencia (spec 4.12):** "Tiene que existir un switch de escenario" entre A (coef=1 pre-2018) y B (IPC real).

**Código R:** No existe ningún parámetro de escenario. La lógica es fija: IPC para ≥2018, IPIM para <2018.

**Clasificación:** No implementado.

---

### B-10 — VR nunca negativo

**Referencia (spec 4.11):** `VR = max(VO − AA; 0)`.

**Código R:** `04_calculo_axi.R:127`: `vr = vo - amort_acum_cierre` (sin `max(..., 0)`).

**Brecha:** No hay diferencia funcional porque `amort_acum_cierre = CUOTA × min(VUT_C, VU)` y `CUOTA × VU = VO`, por lo que `AA ≤ VO` siempre. El `max` es redundante.

**Clasificación:** Idéntica (por equivalencia algebraica).

---

### B-11 — Resultado de venta de bajas

**Referencia (spec 4.14):** "¿Se calcula el resultado impositivo de la venta (precio − VR reexpresado)?"

**Código R:** No existe cálculo de resultado de venta. Las bajas solo calculan la reexpresión de AA y VR, pero no el resultado impositivo.

**Clasificación:** No implementado.

---

## Traza numérica por rubro

> **Nota:** No es posible ejecutar el código R ni leer los valores numéricos de los Excel del estudio desde esta herramienta. La traza numérica completa requiere ejecutar el pipeline con los datos reales. Se recomienda:
> 1. Ejecutar `tar_make()` con el Excel 2022 como LY y el Excel 2023 de validación
> 2. Comparar por rubro los totales de la PG propia vs la PG del estudio
> 3. Para un activo representativo de cada rubro, verificar todos los valores intermedios

### Rubros para la traza (un activo por rubro)

Se sugiere seleccionar activos que cubran los siguientes casos:

| Rubro | Caso a cubrir | Criterio de selección |
|---|---|---|
| Edificios | Bien histórico con VUT parcial | Alta pre-2018, VU no agotada |
| Terrenos | Sin amortización | Cualquier terreno |
| Eq de Oficina | VU corta (3 años) | Alta 2020 o 2021 |
| Maquinas y Equipos | VU media (10 años) | Alta post-2018 |
| Maquinas Mejoras | Igual que Máquinas | Alta post-2018 |
| MyU | VU corta, posible agotada | Alta 2019 o anterior (VU=3) |
| Rodados | Amortización en años | Alta 2019 (VU=5, debería agotar en 2024) |
| Terreno Mejoras | VU media | Cualquiera |
| Software | VU corta, probablemente agotada | Alta 2020 (VU=3, agotada en 2023) |
| Cercos | VU larga (50 años) | Si hay datos |
| Estructuras y caños | VU media | Si hay datos |

### Valores a verificar por activo

Para cada activo seleccionado, comparar R vs estudio:
1. `anio_alta`, `mes_alta`
2. `vo`
3. `vu_asignada`
4. `vut_ly`, `vut_ejercicio`, `vut_cierre`
5. `amort_trimestre` (cuota)
6. `amort_hist_ejercicio`
7. `amort_acum_cierre`, `amort_acum_ly`
8. `vr`
9. `coef_ipc` o `coef_ipim`
10. `vo_reexp`, `amort_acum_cierre_reexp`, `vr_reexp`

### Totales de referencia (spec 4.16)

| Magnitud | Valor referencia 2023 |
|---|---|
| VR total (PG) | $7.585.493.061 |
| Amortización total (PG) | $1.179.524.957 |

Diferencias conocidas del estudio (tolerancia de redondeo):
- Máquinas: amortización $5.304, VR $14.253
- MyU: VR $11.411
