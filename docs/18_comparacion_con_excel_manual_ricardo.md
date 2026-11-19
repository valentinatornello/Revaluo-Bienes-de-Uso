# Motor R contra el Excel manual de Ricardo: diferencias de cálculo y criterio

Fecha: 15/11/2026. Este documento **no modifica código**: lista los cambios que harían falta
para que el motor reproduzca el Excel manual validado del ejercicio 2023. La decisión de
implementarlos, y cómo, queda del lado del motor.

## Alcance y límites

- **Qué se comparó.** El código de esta rama (`feature/replicar-revaluo-manual-2023`, commit
  `4e3b107`) contra las reglas del Excel manual validado (v4 del ejercicio 2023 y archivo
  operativo 2024). Los números de línea corresponden a ese commit.
- **Archivos leídos.** `R/04_calculo_axi.R`, `R/03_construir_rollforward.R`, `R/utils.R` y la
  parte de `R/02_limpiar_datos.R` que lee el histórico. No se revisaron en detalle `R/05`
  (prueba global), `R/06` (validaciones), `R/07` (exportación) ni `app.R`.
- **Es una comparación de código, no de números.** El motor no se corrió: no hubo R disponible.
  Falta confirmar cada punto con una corrida contra el Excel.
- **Fuente de las reglas.** Archivo maestro del Excel manual (hojas Criterios, Parametros,
  Columnas y Ejemplos). No está en este repo; lo comparte Ricardo.

## Lo que ya coincide

| Tema | Excel manual | Motor R |
|---|---|---|
| Unidad | Edificios en trimestres, resto en años | Igual con el criterio por defecto (`"excel"`) |
| Vidas útiles por rubro | Tabla de rubros | `PARAMETROS_RUBROS`, mismos valores |
| Año de alta | Cuenta completo (trimestre de alta en Edificios) | Igual |
| Fecha de las altas | Pstng Date | `posting_date` |
| Fecha de las transferencias | Cap.date | `cap_date_parsed` |
| Bienes anteriores a 2018 | Coeficiente 1 | Igual por defecto (`"unitario"`) |
| Vida útil propia del bien | Columna de VU informada | Lee "VU Asignada" de cada fila |
| Vida útil transcurrida inicial | VUT de cierre del año anterior | Lee "VUT" del archivo anterior |
| Baja parcial | Sale el bien entero (parámetro) | Sale el bien entero |
| Bajas sin bien en la base | Se informan, no se calculan | `bajas_no_identificadas` |

## Diferencias que cambian el resultado

| # | Tema | Excel manual (criterio validado) | Motor R hoy | Dónde | Cambio necesario |
|---|---|---|---|---|---|
| 1 | Edificios, año de baja | Trimestres **anteriores** al de la baja (LIG art. 87: "hasta el trimestre inmediato anterior a aquel en que los bienes se enajenen o desafecten"). Agosto = 2 | Incluye el trimestre de la baja. Agosto = 3 | `R/04_calculo_axi.R`, líneas 65 a 69 | Quitar el `+ 1L`. Dejarlo como parámetro con cuatro valores: N = trimestres anteriores (ley, valor por defecto), S = incluye el de la baja, A = año completo, E = nada (lo que hace el estudio) |
| 2 | Bienes muebles, año de baja | **No** se amortiza | Amortiza el año completo | `R/04_calculo_axi.R`, línea 65 | En rubros anuales con baja en el ejercicio, períodos = 0. Parámetro S/N, por defecto N |
| 3 | Baja de un bien dado de alta el mismo año (Edificios) | Descuenta los trimestres previos al alta | Toma los períodos del primer año, sin mirar la baja | `R/04_calculo_axi.R`, líneas 87 a 94 | Períodos de baja menos (4 − períodos del primer año), con piso en cero |
| 4 | Coeficiente de las bajas anteriores a 2018 | 1 | Busca el coeficiente en la tabla IPIM de bajas, aunque el criterio general sea `"unitario"` | `R/04_calculo_axi.R`, líneas 268 a 272 | Usar `coeficiente_pre_2018()` también en las bajas |
| 5 | Coeficiente de las bajas dadas de alta en el mismo ejercicio | 1 | Busca en la tabla de bajas | `R/04_calculo_axi.R`, líneas 262 a 266 | Si el año de alta es el del ejercicio, coeficiente 1 |
| 6 | Saldo de cierre de un bien dado de baja | VO, amortización acumulada y valor residual de cierre = 0; la baja va en columnas propias (VO, amortización acumulada y valor residual de la baja) | La fila de baja conserva `amort_acum_cierre`, `vr`, `vo_reexp` y `vr_reexp` como si siguiera | `R/04_calculo_axi.R`, líneas 96 a 178 | Separar "al cierre" de "de la baja". Verificar cómo lo resta hoy `R/05_prueba_global.R` |
| 7 | Índices IPC | INDEC, nivel general nacional, 4 decimales, tabla mensual propia; coeficiente = índice de cierre / índice del mes de alta | Lee la columna de coeficientes ya calculada del archivo del estudio | `R/01_importar_datos.R`, líneas 133 a 180 y 476 a 479 | Leer índices propios y calcular el coeficiente. La tabla del estudio 2023 tiene dos meses con el índice redondeado a 2 decimales (01/2021 y 11/2022) y el motor los hereda |
| 8 | Bien con "VU Asignada" vacía en el histórico | Usa la vida útil del rubro | La vida útil queda en 0: no amortiza y su amortización acumulada da 0 | Lectura de VU en `R/02_limpiar_datos.R`; `R/04_calculo_axi.R`, línea 53 | Si la VU de la fila está vacía, tomar la del rubro |
| 9 | Amortización acumulada al inicio | Cuota × mínimo(VUT inicial, VU) | Cuota × VUT inicial, sin tope | `R/04_calculo_axi.R`, líneas 124 a 128 | Agregar el tope. En el histórico hay filas con VUT informada mayor a la VU, y sin el tope la prueba global no cierra |
| 10 | Períodos del ejercicio cuando la VUT supera la VU | Piso en cero | `vu_asignada - vut_ly` puede dar negativo y baja la VUT de cierre | `R/04_calculo_axi.R`, líneas 87 a 96 | `pmax(0, ...)` |
| 11 | VUT inicial calculada por fecha, bien anterior a 1992 | Cuenta desde la fecha **real**; el piso de 1992 es solo para el coeficiente | Cuenta desde `anio_alta`, que puede venir ya llevado a 1992 | `R/04_calculo_axi.R`, líneas 73 a 77; `R/utils.R`, líneas 172 a 181 | Guardar la fecha real aparte de la fecha para el índice. Afecta a transferencias de bienes muy antiguos, que quedan con menos vida transcurrida de la que tienen |

## Diferencias de estructura y control

No cambian el número, sí la confiabilidad.

| # | Tema | Excel manual | Motor R hoy | Cambio sugerido |
|---|---|---|---|---|
| 12 | Clases excluidas | Se listan aparte (obras en curso, leasing IFRS 16, deterioros, otras) y entran en el control de transferencias | Las clases sin mapeo quedan en blanco y se descartan sin aviso (solo 600LA tiene nombre) | Reportar lo excluido, por clase, con cantidad e importe |
| 13 | Control de transferencias | Tienen que netear en cero, contando las puntas de clases excluidas | No se encontró un control equivalente en lo leído | Agregar la validación |
| 14 | Control de saldo inicial | VO y amortización acumulada iniciales = cierre anterior, por rubro | No se encontró en lo leído | Agregar la validación |
| 15 | Altas de un activo que también tiene baja en el año | La fila de alta queda y el activo se marca como baja | Se eliminan el alta y la transferencia del activo (regla 7) | Definir cuál queda. El saldo de cierre es el mismo; cambian el total de altas y el de bajas |
| 16 | Vida transcurrida de Edificios en el histórico | "VU Asignada" − "VU restante" | Si "VUT" es mayor a 4 la toma como cierre; si no, suma VUT LY + VUT | Comparar fila por fila antes de decidir: son dos lecturas distintas de la misma hoja |
| 17 | Criterio de unidad `"ricardo"` | No existe: el criterio validado es el de `"excel"` (Edificios en trimestres, resto en años) | Opción alternativa con todo en trimestres salvo Rodados | Renombrar o quitar la opción para que no se confunda con el criterio vigente |
| 18 | Ajuste `amort_bs_agotaron_vu_ly` | No existe | Calcula un ajuste negativo para bienes con vida agotada | Confirmar que no entra en ningún total |

## Sentido esperado de las diferencias principales

Sin corrida del motor; es el sentido del efecto, no el importe.

| Diferencia | Efecto sobre el resultado del motor respecto del Excel |
|---|---|
| 1. Trimestre de baja incluido en Edificios | Más amortización del ejercicio: un trimestre más por cada fila de Edificios dada de baja con vida útil pendiente |
| 2. Muebles amortizan el año de baja | Más amortización del ejercicio: una cuota anual por cada bien mueble dado de baja con vida útil pendiente. Es probablemente la de mayor impacto, por cantidad de filas |
| 4. Coeficiente IPIM en bajas anteriores a 2018 | Valor residual de las bajas reexpresado mayor |
| 7. Índices del estudio | Reexpresados apenas menores en los bienes dados de alta en los dos meses redondeados |
| 8. VU vacía | Menos amortización acumulada en los bienes afectados |

## Qué falta para cerrar la comparación

- Correr el motor con estos cambios y comparar por rubro contra el Excel, en los ocho conceptos
  (VO, amortización del ejercicio, amortización acumulada, valor residual y sus reexpresados).
- Revisar la prueba global (`R/05`) contra la del Excel: saldo inicial + altas ± transferencias
  − bajas = cierre, en VO, amortización acumulada y valor residual.
- Revisar la aplicación y la exportación.
