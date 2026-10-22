# Impacto Acumulativo de Correcciones — PG 2022

Pipeline ejecutado con el Excel 2022 (`MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC.xlsx`) como LY y año de ejercicio 2022.

## Tabla resumen

| # | Corrección | Amort acum ($) | VR ($) | VR reexp ($) | AXI ($) | PG diff ($) | Neg reexp |
|---|---|---|---|---|---|---|---|
| 0 | **BASELINE** (sin cambios) | 5.649.171.870 | 2.279.176.819 | 29.544.688.949 | 27.265.512.130 | 13.737.563.635 | 19.512 |
| 1 | **V-03** (quitar `/4` en VU muebles) | 3.351.619.494 | 4.576.729.195 | 36.331.673.965 | 31.754.944.770 | **221.475.480** | 19.512 |
| 2 | + **V-08** (bajas: fecha alta para coef) | 3.351.619.494 | 4.576.729.195 | 36.331.673.965 | 31.754.944.770 | 221.475.480 | 19.512 |
| 3 | + **B-01** (coef=1 pre-2018) | 3.351.619.494 | 4.576.729.195 | **9.881.508.745** | **5.304.779.550** | 221.475.480 | **18.907** |
| 4 | + **B-04** (VUT años enteros) | 3.351.619.823 | 4.576.728.866 | 9.881.508.416 | 5.304.779.550 | 221.475.744 | 18.907 |
| 5 | + V-05 (noop con B-01) | — | — | — | — | — | — |
| 6 | + **B-02** (corte pre-1992) | — | — | — | — | — | — |
| 7 | + **V-09** (edif trim anterior) | 3.351.619.823 | 4.576.728.866 | 9.881.508.416 | 5.304.779.550 | 221.475.744 | 18.907 |

## Impacto individual de cada corrección

### V-03 — Quitar `/4` en VU de muebles

| Magnitud | Delta vs baseline |
|---|---|
| Amort acum | **−$2.297.552.376** (−40,7%) |
| VR | **+$2.297.552.376** |
| PG diff total | 13.737M → **221M** (−98,4%) |

**El fix más importante.** Eliminó $13.500M de diferencia en la PG y corrigió la cuota de todos los muebles. La amortización bajó porque la cuota correcta (VO/VU en años) es 4× menor que la errónea (VO/(VU/4)). Pero 19.512 activos con VR reexp negativo persisten — son transferencias salida y bienes donde el IPIM todavía infla los valores incorrectamente.

### V-08 — Fecha de alta (no de baja) para coeficiente de bajas

**Impacto: $0.** No hay bajas del SAP en este run (el Excel 2022 ya incluye los movimientos del año → `tiene_mov_anio = TRUE` → no se incorporan bajas SAP). La corrección no tuvo efecto en este dataset porque las bajas ya venían del LY con `fecha_alta` = fecha original.

### B-01 — Coeficiente = 1 para pre-2018

| Magnitud | Delta vs step anterior |
|---|---|
| VR reexp | 36.332M → **9.882M** (−72,8%) |
| AXI | 31.755M → **5.305M** (−83,3%) |
| Activos neg | 19.512 → **18.907** (−605) |

**Segundo fix más importante.** Elimina la inflación ficticia del IPIM sobre bienes pre-2018. El AXI baja de $31.755M a $5.305M — el 83% del AXI del baseline era artificial.

### B-04 — VUT en años enteros para muebles

| Magnitud | Delta vs step anterior |
|---|---|
| Amort acum | +$329 |
| VR | −$329 |
| VR reexp | −$329 |

**Impacto mínimo** ($329 en total). Esto se debe a que la mayoría de los activos con VUT_LY no-entero ya estaban con VU agotada, por lo que la fracción 0.25 no afectaba el cálculo (estaba capped por `pmin`). El fix es correcto pero su efecto numérico es marginal en la base 2022.

### V-05, B-02, V-09 — Sin impacto adicional

- **V-05:** No-op (con B-01 ya aplicado, amort_hist_reexp para pre-2018 = amort × 1).
- **B-02:** Sin efecto. Los bienes pre-1992 en este dataset ya tienen `fecha_alta` ≥ 1992 en el LY (el estudio ya aplicó el corte). El fix sería relevante si se recalculara desde datos SAP originales.
- **V-09:** Sin efecto medible. Las bajas de Edificios del LY ya vienen con VUT incorporado y no pasan por el cálculo de `periodos_hasta_baja`. El fix aplica solo a bajas SAP nuevas.

## Estado final vs estudio

| Magnitud | R corregido | Observación |
|---|---|---|
| Amort acum | $3.351.619.823 | — |
| VR | $4.576.728.866 | — |
| VR reexp | $9.881.508.416 | — |
| AXI | $5.304.779.550 | — |
| PG diff amort | $221.475.744 | Aún significativa; puede ser V-03 residual en activos con VU especial |
| PG diff VR | ~$0 | Cuadra |
| Neg reexp | 18.907 | Transferencias salida legítimas + posibles errores residuales |

La PG de VR cuadra ($0 de diferencia), pero la PG de amortizaciones tiene $221M de diferencia residual. Esto puede deberse a:
1. Activos con VU no estándar en el Excel (ej: VU=21, VU=13 que no son parámetros del rubro)
2. Activos "irregulares" (paso de trimestre a año) con amort acum que no se recalcula limpiamente
3. Redondeos acumulados sobre 56.000+ activos

## Conclusión

Las dos correcciones de mayor impacto son **V-03** (quitar `/4`) y **B-01** (coef=1 pre-2018). Juntas eliminan el 98% del error en la PG y el 83% del AXI inflado. Las demás correcciones son conceptualmente correctas pero no tienen efecto numérico en la base 2022 porque los datos del LY ya incorporan los ajustes del estudio.

Para medir el efecto de V-08, B-02 y V-09 se necesita correr con el Excel 2022 como LY real + movimientos SAP de 2023 (no el Excel del estudio 2023 que ya tiene todo incorporado).
