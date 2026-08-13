# Metodología de Cálculo - Revalúo AXI

## Estructura general

El cálculo se realiza por activo individual, agrupado en 11 categorías (rubros). Cada rubro tiene una vida útil asignada expresada en trimestres y un índice de actualización (IPC para bienes 2018+, IPIM para pre-2018).

## Categorías y parámetros

| Rubro | Códigos SAP | VU (años) | VU (trim.) | Índice |
|---|---|---|---|---|
| Cercos | - | 50 | 200 | IPC |
| Edificios | 210LA, 220LA, 392LA | 50 | 200 | IPC |
| Terrenos | 110LA | No amortiza | 0 | IPC |
| Estructuras y caños | - | 10 | 40 | IPC |
| Eq. de Oficina | 320LA | 3 | 12 | IPC |
| Máquinas y Equipos | 310LA, 350LA | 10 | 40 | IPC |
| Máquinas Mejoras | 370LA | 10 | 40 | IPC |
| Muebles y Útiles | 330LA | 3 | 12 | IPC |
| Rodados | 360LA | 5 | 20 | IPC |
| Terreno Mejoras | 130LA, 250LA | 10 | 40 | IPC |
| Software | 510LA, 515LA, 610LA | 3 | 12 | IPC |

## Paso a paso del cálculo por activo

### 1. Amortización histórica

1. **Trimestres 1er año de alta**: `floor((12 - mes_alta + 1) / 3)`
2. **VUT LY** (vida útil transcurrida al cierre del año anterior): acumulado de trimestres desde el alta hasta el 31/12 del año anterior
3. **VUT ejercicio**: 4 trimestres si es año completo, o trimestres del primer año si el alta es del ejercicio corriente
4. **VUT cierre**: `min(VUT_LY + VUT_ejercicio, VU_asignada)`
5. **VU restante**: `VU_asignada - VUT_cierre`
6. **Amort. trimestre**: `VO / VU_asignada`
7. **Amort. histórica del ejercicio**: `Amort_trimestre × VUT_ejercicio`
8. **Amort. acumulada al cierre**: `Amort_trimestre × VUT_cierre`
9. **VR (Valor Residual)**: `VO - Amort_acum_cierre`

### 2. Reexpresión por inflación

#### Bienes con alta >= 2018 (IPC):
1. **Coeficiente IPC**: `IPC_cierre / IPC_fecha_alta` (lookup por posting date)
2. **VO Reexpresado**: `VO × Coeficiente`
3. **Amort. Reexpresada**: `Amort_hist_ejercicio × Coeficiente`
4. **Amort. Acum. LY Reexpresada**: `Amort_acum_LY × Coeficiente`
5. **VR Reexpresado**: `VO_reexp - Amort_acum_cierre_reexp`

#### Bienes con alta < 2018 (IPIM - confiscatoriedad):
1. **Coeficiente IPIM**: `IPIM_cierre / IPIM_fecha_alta`
2. **VO Reexpresado IPIM**: `VO × Coeficiente_IPIM`
3. **VR Reexpresado IPIM**: `VR × Coeficiente_IPIM`

### 3. Casos especiales

- **Terrenos**: no se amortizan, solo se reexpresan
- **VU agotada**: si VUT_LY >= VU_asignada, no se amortiza más en el ejercicio
- **IFRS16**: activos con prefijo "AS" se excluyen del cálculo
- **Altas y bajas en mismo ejercicio**: se netean

## Prueba Global

Control de consistencia que verifica:
- **Amortizaciones**: Amort_inicio + Amort_altas + Amort_transf - Amort_bajas + Ajustes = Amort_cierre
- **Valor Residual**: VR_inicio + Altas_VO + Transf_VO - Bajas_VO - Amort_ejercicio = VR_cierre
- La diferencia entre s/prueba y s/revalúo debe ser cercana a 0
