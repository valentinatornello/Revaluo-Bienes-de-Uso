# Cambios del código según el doc de Ricardo (docs/18) y la comparación con el Excel manual

Fecha: 19/11/2026. Richard, acá está cada cambio que hicimos en el motor a partir de tu documento `18_comparacion_con_excel_manual_ricardo.md`, explicando qué pasó en la corrida de 2023 y las preguntas que me quedaron abiertas.

## Lo primero: ¿subió el % de automatización?

No subió... pero tiene sentido, te explico por qué. No te preocupes, venimos bien. Los porcentajes no son buenos indicadores en estos casos.

| Medida (ejercicio 2023, contra el Excel manual) | Antes | Ahora |
|---|---|---|
| Comparaciones de la prueba global que replican el Excel (VR, amortización, AXI, por rubro y total) | 44 de 48 (91,7 %) | 44 de 48 (91,7 %) |
| Celdas fila por fila que coinciden con las hojas por rubro del Excel (VO, VU, VUT, amortización, VR y reexpresados) | 507.444 de 507.496 (99,990 %) | 507.440 de 507.496 (99,989 %) |
| Indicador de la app (Paso 6) | 60 % (con 20 puntos que no medían nada) | 40 % (ya corregido el filtro) |
| Validaciones | 51 OK, 6 advertencias, 2 errores | 57 OK, 9 advertencias, 2 errores |

- Ya antes el motor coincidía con el Excel en todo menos en **Terrenos**. Las 4 comparaciones que no replican son todas de Terrenos (VR y AXI, del rubro y del total): el VR histórico de 253 M que el Excel trae pegado a mano.
- Casi todos los cambios que pedías tocan las **bajas**, y las bajas no entran en las filas "s/revalúo" de la prueba global. Por eso no mueven el %. Lo que mejoran es que las bajas ahora quedan bien armadas y que hay controles nuevos.
- Las 4 celdas que dejaron de coincidir son del mismo bien (MyU 405488001171, punto 8 de abajo): ahora el motor sigue tu regla y el Excel 2023 tiene ahí un error.
- Lo que sí subiría el % es resolver Terrenos. Con eso los 2 errores desaparecen, el indicador de la app pasaría de 40 % a 100 %, y las 4 comparaciones restantes replicarían.
- Corregimos el indicador de la app: el componente "validación externa" daba siempre 20 puntos, porque buscaba los textos "kpmg|precio|externo" y las validaciones contra el Excel se llaman `comparacion_real_*`. Ahora el filtro en `app.R` (`calcular_automatizacion()`) incluye `comparacion_real`. Por eso el indicador real hoy es **40 %** y no 60 %: el 60 % incluía 20 puntos que no medían nada. No es que el motor haya empeorado, es el número verdadero porque lo estaba calculando mal, perdónnn. 

## Lo que quedaría automatizar: un solo rubro

- De los 10 rubros, 9 replican al 100 % la prueba global del Excel (valor residual, amortización y AXI). El que falta es **Terrenos**. SEGUN EL MOTOR. confirmalo plis
- Todo el desvío que queda en el total es de ahí: el valor residual de Terrenos da 7,87 M en el motor y 245,93 M en el Excel, o sea 238,06 M de diferencia, que es exactamente la diferencia del AXI total (21.849,4 M contra 21.611,3 M).
- Fila por fila, el 99,989 % de las celdas coincide con el Excel!!
- En cuanto Terrenos replique, el indicador pasa de 40 % a 100 %, sin tocar nada de los otros 9 rubros.

Para cerrarlo te pido que me expliques bien cómo funcionan los cálculos de Terrenos, paso a paso, y los agregamos al motor. Lo que necesito entender está detallado en la pregunta 5.



Los parámetros nuevos se cambian con `options(...)` (o en `_targets.R`) y los valores por default son los de tu doc.

| # | Qué pasaba | Qué hace ahora | Dónde | Efecto en 2023 |
|---|---|---|---|---|
| 1 | Edificios amortizaba hasta el trimestre de la baja, inclusive (agosto = 3) | Por defecto amortiza los trimestres **anteriores** al de la baja (agosto = 2), como la LIG art. 87. Parámetro `revaluo.baja_edificios`: `"N"` anteriores (defecto), `"S"` incluye el de la baja, `"A"` año completo, `"E"` nada | `utils.R` (`criterio_baja_edificios`, `periodos_devengados_baja`), `04_calculo_axi.R` | 26 bajas de Edificios: amortización del ejercicio de baja 305.764 antes, 228.995 ahora (con `"E"` sería 0). No cambia la prueba global |
| 2 | Los muebles amortizaban el año completo en el año de baja | Por defecto **no** amortizan. Parámetro `revaluo.baja_muebles_amortiza`: `"N"` (defecto) o `"S"` | `utils.R`, `04_calculo_axi.R` | 1.532 bajas de muebles: amortización del ejercicio de baja 1,95 M antes, 0 ahora. El VR de la baja de muebles ahora coincide con el de la PG del Excel (Eq. de Oficina 1,25 M, Máquinas y Equipos 1,29 M, Rodados 0,24 M) |
| 3 | La baja de un Edificio dado de alta el mismo año tomaba los trimestres del primer año sin mirar la baja | Períodos de baja menos los trimestres previos al alta, con piso en cero | `04_calculo_axi.R` | En 2023 no hay ningún caso (las altas con baja en el año se netean). Cubierto con test |
| 4 | Las bajas anteriores a 2018 buscaban el coeficiente en la tabla IPIM de bajas aunque el criterio fuera `"unitario"` | Usan `coeficiente_pre_2018()`: coeficiente 1 por defecto | `04_calculo_axi.R` (`calcular_coeficientes_bajas`) | Coeficiente medio de las bajas pre-2018 antes: 39,7 en Edificios, 42,5 en Máquinas y Equipos, 26,0 en Rodados. Ahora 1. VR reexpresado de las bajas de Edificios: 234,0 M antes, 25,0 M ahora. No entra en la prueba global |
| 5 | Las bajas dadas de alta en el ejercicio buscaban coeficiente en la tabla de bajas | Coeficiente 1 | `04_calculo_axi.R` | Sin casos en 2023. Cubierto con test |
| 6 | La fila de baja conservaba saldo de cierre como si el bien siguiera | VO, amortización acumulada y VR de cierre (históricos y reexpresados) quedan en 0. Lo que se retira va en columnas propias: `vo_baja`, `amort_acum_baja`, `vr_baja`, `vo_baja_reexp` (y las que ya existían, `amort_bajas` y `vr_bajas`, reexpresadas). Se agregó `vo_cierre` | `04_calculo_axi.R` (`separar_saldo_baja`), `06_validaciones.R`, `07_exportar_resultados.R` | La prueba global resta las bajas de las columnas del LY (`vr_ly`, `amort_hist_ly`), no del cierre, así que no cambia. La validación interna ahora controla que la baja tenga cierre en 0 y que `vr_baja = vo_baja - amort_acum_baja` |
| 7 | Leía el coeficiente IPC ya calculado del Excel | Recalcula el coeficiente como índice de cierre / índice del mes con todos los decimales. Si existe `inputs/parametros/indices_ipc_indec.csv` (columnas `fecha`, `indice`) usa esos índices del INDEC. Avisa los meses con índice de 2 decimales o menos | `01_importar_datos.R` (`recalcular_coeficiente_ipc`, `leer_indices_ipc_propios`, `aplicar_indices_ipc_propios`, `meses_con_indice_redondeado`), `06_validaciones.R` | Detectó justo los dos meses que marcaste: 01/2021 y 11/2022. Mientras no carguemos los valores del INDEC el número no cambia y queda la advertencia |
| 8 | Un bien con "VU Asignada" vacía en el histórico quedaba con VU 0: no amortizaba | Toma la vida útil del rubro y avisa cuántos son | `02_limpiar_datos.R`, `06_validaciones.R` (`validar_vu_completada_con_rubro`) | 1 bien, en MyU (ver preguntas). Todos los demás traen su VU |
| 9 | Amortización acumulada inicial = cuota × VUT LY, sin tope | Cuota × mínimo(VUT LY, VU) | `04_calculo_axi.R` | En la base 2022 no hay filas con VUT mayor a la VU: no cambia ningún número. Cubierto con test |
| 10 | Los períodos del ejercicio podían dar negativo si la VUT superaba la VU | `pmax(0, ...)` | `04_calculo_axi.R` | Igual que el 9: sin casos en 2023 |
| 11 | La VUT calculada por fecha usaba el año llevado a 1992 | Para bienes con fecha real anterior a 1992 cuenta desde la fecha real. El piso de 1992 queda solo para el índice | `02_limpiar_datos.R` (columna `fecha_alta_real`), `04_calculo_axi.R` | Ninguna fila de 2023 usa el cálculo por fecha (todas traen VUT LY). Cubierto con test |

## Cambios de estructura y control

| # | Qué hicimos | Resultado en 2023 |
|---|---|---|
| 12 | SAP: reportamos lo excluido por tipo, clase, motivo, cantidad e importe (`excluidos_sap`). Obras en curso, IFRS 16 y los "códigos no utilizados" del archivo de reglas (9050, 9150, 9250, 9350, 9750, 495LA, 430LA) son exclusiones conocidas (OK). Una clase sin rubro que no esté en esa lista da advertencia (`validar_clases_excluidas`) | 600LA obras en curso (1.601 movimientos), IFRS 16 en las clases 9050, 9150 y 9750 (133 movimientos) y la clase 495LA, código no utilizado (10 altas de importe 0,02): todo OK. Además va a una hoja "Excluidos SAP" del Excel final |
| 13 | Control de transferencias: el neto de todas las clases, contando las puntas excluidas, tiene que dar 0 (`validar_control_transferencias`) | Neto 0. Las transferencias incluidas netean +3.631 M y las de obras en curso, excluidas, −3.631 M |
| 14 | Control de saldo inicial por rubro (`validar_saldo_inicial`): VO contra la fila "Totales" del Excel LY, y amortización acumulada inicial del motor contra la columna "Amort. Acum" fila por fila | VO coincide en los 10 rubros. La amortización acumulada coincide salvo 4 bienes 2006 de MyU con ajuste manual pegado en el LY: diferencia de −10.050 sobre 148,6 M, advertencia (es error solo si pasa del 0,1 % del saldo) |
| 15 | Altas de un activo que también tiene baja | No lo cambiamos: queda la regla 7 (se eliminan alta y transferencia). Ver pregunta 6 |
| 16 | Vida transcurrida de Edificios: comparamos las dos lecturas fila por fila en el LY 2022 | Las 2.547 filas con "VU restante" informada dan lo mismo con las dos lecturas ("VU Asignada" − "VU restante" y la que hace el motor). No cambiamos nada |
| 17 | El criterio `"ricardo"` se renombró a `"trimestres"` para que no se confunda con el criterio vigente (`"excel"`). Si alguien pasa `"ricardo"` sigue funcionando, con un aviso | Actualizado en `utils.R`, `_targets.R`, `reglas_negocio.md` y los tests |
| 18 | `amort_bs_agotaron_vu_ly`: confirmamos que no entra en ningún total. La prueba global usa `es_vu_agotada_ly` con el flujo del LY, y la exportación no la trae | Sin cambios |

## Lo que faltaba según el archivo "Reglas Revalúo.xlsx"

Revisamos el archivo de reglas completo (hojas Reglas, Calculos, notas de los videos, proceso Price, Glosario y Res. final 2024) contra el motor. Las reglas de terrenos sin amortización, activos AS (IFRS 16) apartados y bienes con VUT = VU sin más amortización ya estaban cubiertas. Encontramos esto:

| Qué dice el archivo | Qué hacía el motor | Qué hicimos |
|---|---|---|
| Regla 2: las bajas de SAP que no se identifican en la base se detallan **al final del rubro con el número de asset** | Las guardaba con su número, pero el Excel final solo mostraba el conteo en las validaciones | El Excel final ahora las detalla al final de la hoja de cada rubro (número de activo, descripción y valor) y en una hoja "Bajas no identificadas" con todas (85 líneas, 69 activos en 2023) |
| Regla 3: los AS (IFRS 16) "se dejan apartados" y no van en el anexo | Se excluían y se informaban en las validaciones | Además van a la hoja "Excluidos SAP" del Excel final, por clase |
| Glosario: "Códigos no utilizados" (9050, 9150, 9250, 9350, 9750, 600LA, 495LA, 430LA) | 495LA daba advertencia de "clase sin rubro" | Pasaron a exclusiones conocidas (OK) |

Lo que el archivo dice y todavía no está en el motor (va en las preguntas de abajo): baja parcial, AXI de traslados por número de documento, Rodados agro, las clases 410LA y 810LA, la hoja "Edificios PG" y el balance de sumas y saldos como control.

Una pista sobre Terrenos: la hoja "Res. final 2024" muestra Terrenos con valor residual histórico de 245.932.358,59 y reexpresado de 7.873.522,54. El reexpresado es exactamente lo que calcula el motor. El histórico es el mismo número que en la PG de 2023, o sea que no sale de las altas y bajas del año.

## Herramienta nueva para comparar con el Excel

- `R/08_comparar_excel_manual.R` (`comparar_filas_con_excel`): compara fila por fila el resultado del motor con las hojas por rubro del Excel del estudio. Cruza por número de activo y VO, y compara VO, VU, VUT de cierre, amortización del ejercicio, amortización acumulada, VR, VO reexpresado, amortización reexpresada y VR reexpresado.
- `tests/comparar_con_excel_manual.R`: corre el ejercicio completo y muestra la prueba global y la comparación fila por fila. Cómo se corre está en el encabezado del archivo. El Excel del estudio tiene que estar en `.xlsx` (el `.xlsb` lo convertimos abriéndolo en Excel).
- Las 4.068 filas de Edificios, 12.478 de Eq. de Oficina, 27.166 de Máquinas y Equipos, etc. están todas en ambos lados: no sobra ni falta ninguna.

Lo que no coincide hoy contra el Excel (56 celdas):

| Rubro | Cantidad | Qué es |
|---|---|---|
| Máquinas y Equipos | 13 filas, 17.048 de amortización y 29.395 de VR | Ajustes manuales pegados en el Excel (los bienes 2006 que ya teníamos identificados) |
| MyU | 1 bien, 1.361 de VR | Bien con VU vacía (punto 8) |
| Edificios | 1 fila, 4 trimestres de VUT | Una fila con 4 trimestres de diferencia en la VUT; la amortización acumulada de esa fila sí coincide |

## Tests

- `tests/test_reglas_negocio.R` pasa completo. Actualizamos los casos que fijaban el criterio viejo de baja (trimestre de la baja inclusive, muebles con año completo) y agregamos casos para los cuatro valores de `revaluo.baja_edificios`, `revaluo.baja_muebles_amortiza`, baja el mismo año, coeficientes de bajas, VU vacía, tope de la VU, fecha real, controles de saldo inicial, de transferencias y de clases excluidas (incluidos los códigos no utilizados), la exportación de las bajas no identificadas, índices IPC y el comparador.
- Corrimos 2023 completo con el criterio de ley (`"N"` y muebles sin amortizar), con el del estudio (`"E"`), con el viejo (`"S"`) y con año completo (`"A"`; en estas tres, muebles con año completo). La prueba global y el AXI dan exactamente lo mismo en todas, como esperábamos: las bajas no entran en "s/revalúo".

## Preguntas para hacerte

1. **Edificios, año de baja.** El VR de las bajas de Edificios en la PG del Excel 2023 es el valor congelado a LY (11,23 M), que equivale a `"E"` (no amortizar nada). Con el criterio de ley (`"N"`) el VR de las bajas da 11,00 M y no coincide con la PG. En tu doc el Excel validado usa trimestres anteriores. ¿Cuál va en la PG? Por ahora la PG sigue usando el valor congelado a LY.
2. **Muebles, año de baja.** Con "sin amortización" el VR de las bajas de muebles coincide con la PG del Excel en Eq. de Oficina, Máquinas y Equipos y Rodados. ¿Lo confirmás como criterio final?
3. **Bien 405488001171 (MyU).** VO 1.360,69, alta 2006, VUT LY 16 y VU vacía. El LY 2022 dice que su amortización acumulada es 1.360,69 (totalmente amortizado) y el Excel 2023 lo deja con VR 1.360,69 porque la VU vacía no amortiza. ¿Es un error del Excel 2023, como entendemos?
4. **Índices del INDEC.** ¿Nos pasás los índices IPC nivel general nacional con 4 decimales, al menos de 01/2021 y 11/2022? Van en `inputs/parametros/indices_ipc_indec.csv`, con columnas `fecha` (cualquier día del mes) e `indice`. Si incluye el último mes del año, también se usa como índice de cierre.
5. **Terrenos (lo único que falta).** El valor residual histórico de 253 M del Excel 2022 (245,9 M en la PG de este año) y el AXI de −238 M no salen de la hoja de Terrenos, que suma 7,87 M de VO. ¿Nos podés explicar paso a paso cómo se calculan? Nos sirve que nos cuentes: (a) de dónde sale el dato de partida y quién lo da (¿revalúo técnico del perito?); (b) cómo se llega del dato al valor residual histórico y al reexpresado; (c) qué hay que actualizar cada año y qué queda fijo; (d) cómo se tratan las altas, bajas y transferencias de Terrenos (el Excel 2023 arrastra el valor de 2022 menos 7,1 M de bajas). Pista: en la hoja "Res. final 2024" el histórico de Terrenos vuelve a ser 245.932.358,59, igual que en 2023, y el reexpresado es 7.873.522,54, que es lo que calcula el motor. ¿El histórico es el saldo contable de Terrenos del balance de sumas y saldos? Si es así, el balance es el insumo que nos falta. Con eso lo programamos y lo dejamos como parámetro o insumo del motor, con su validación.
6. **Altas de un activo con baja en el año.** Hoy se eliminan el alta y la transferencia (regla 7). En el Excel queda la fila de alta y el activo se marca como baja. El saldo de cierre es el mismo, cambian el total de altas y el de bajas. ¿Cuál dejamos?
7. **Fecha real de los bienes anteriores a 1992.** La nota de las hojas dice que la columna E ("Año a tomar") se modifica cuando la fecha del archivo es anterior al año en que se dio de alta. Entonces "Año S/ Archivo" no siempre es la fecha real. Usamos esa columna solo cuando es anterior a 1992. ¿Es la columna correcta?
8. **Ajustes manuales del Excel.** 13 filas de Máquinas y Equipos y 4 bienes 2006 de MyU tienen valores pegados a mano (amortización del ejercicio en 0, VR distinto, amortización acumulada distinta de la calculada). ¿Los cargamos como excepciones para que el motor las replique, o preferís que el motor calcule y las diferencias queden informadas?
9. **Bajas SAP que no están en la base.** Son 69 activos (63 en Máquinas y Equipos, 4 en Software, 1 en Edificios y 1 en Máquinas Mejoras). No se calculan y ahora se detallan con su número de activo al final del rubro y en la hoja "Bajas no identificadas". El archivo de reglas dice que esto genera diferencias contra el saldo contable. ¿Los buscamos en otro archivo (el stock inicial) o está bien así?
10. **Baja parcial.** Las notas de los videos dicen que hay que dar de baja el mismo % en los saldos ajustados por inflación. El Excel 2023 saca el activo entero (5 bajas parciales en Máquinas y Equipos, unos 3,0 M de VO restante). ¿Prorrateamos como dicen las notas o seguimos al Excel?
11. **Traslados.** Las notas dicen que traslado de alta más traslado de baja tiene que dar AXI cero, y que se matchean por número de documento (los activos tienen distinto número). Hoy controlamos que el valor neto dé 0 (da 0 en 2023), pero no el AXI por documento. ¿Nos confirmás que el archivo de transferencias de SAP trae el número de documento para hacer ese control?
12. **Rodados agro.** El archivo de reglas pregunta si los rodados agro tienen 4 años de vida útil en vez de 5. Hoy el motor usa 5 para todos. ¿Cómo se identifican los rodados agro y qué vida útil tienen?
13. **Clases 410LA y 810LA.** El glosario las muestra como goodwill y activos para la venta, y no están en la lista de códigos no utilizados. Hoy dan advertencia si aparecen. ¿Se excluyen del revalúo?
14. **Hoja "Edificios PG".** El glosario la marca con "VER" y el Excel del estudio la tiene. El motor no la usa. ¿Qué contiene y hay que replicarla?
15. **Balance de sumas y saldos.** La hoja Input lo lista como insumo de SAP junto con la consulta de activos fijos (S_ALR_87011964). Hoy el motor no los usa. ¿Los usamos como control contra la contabilidad (y para Terrenos, si se confirma la pista de la pregunta 5)? Si nos pasás uno, armamos el control.
16. **Año 2024.** La hoja "Res. final 2024" tiene los resultados 2024 por rubro (VR y amortización, históricos y reexpresados). Si tenés el SAP 2024 y el Excel 2023 como base, corremos 2024 y lo validamos contra esos números.
