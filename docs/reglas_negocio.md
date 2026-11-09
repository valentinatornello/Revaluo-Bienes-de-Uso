# Reglas de negocio

## Contexto

El cálculo del Revalúo de Bienes de Uso es una obligación impositiva argentina que se ejecuta año a año. Hasta ahora lo realizaba KPMG; al pasar a ser auditor, el equipo interno asume el cálculo. Se valida contra los ejercicios 2022, 2023 y 2024 (resultados KPMG) para producción a partir de 2025.

## Reglas generales

1. Si el bien se adquirió antes de 2018, NO se revalúan con IPC las amortizaciones ni VO (quedan a valores históricos). Se usa IPIM para la confiscatoriedad. En el código el coeficiente de los bienes pre-2018 es 1 por defecto (Excel manual 2023: `=SI(año<2018;1;IPC)`); con `options(revaluo.coef_pre2018 = "ipim")` usa el IPIM del Excel 2022.
2. Si se informan bajas de bienes que no se identifican en la base, se detallan al final del rubro con el número de asset.
3. Assets cuyo nombre empieza con "AS" son operaciones IFRS16 y se excluyen del cálculo de revalúo.
4. La VU se expresa en trimestres. Se considera el mes de alta para evaluar trimestres transcurridos. En el código esto es el criterio `"ricardo"` (`options(revaluo.criterio_unidad_vu = "ricardo")`, o `CRITERIO_UNIDAD_VU=ricardo` en `_targets.R`): todos los rubros en trimestres salvo Rodados (años, SPEC 4.2). El criterio por defecto, `"excel"`, replica las fórmulas del Excel manual del estudio (Edificios en trimestres, el resto en años) para poder comparar contra él.
5. Los terrenos NO se amortizan.
6. Si VU Transcurrida = VU Asignada, el bien ya no se amortiza más.
7. Revisar si altas están en bajas del mismo año y netear. En el código: un activo con baja en el ejercicio sale por completo (base, altas y transferencias del ejercicio) y la baja queda como fila propia; las altas conservan el signo de SAP (las reversas restan). Pendiente confirmar el tratamiento de bajas parciales (`docs/15_proceso_manual_revaluo.md` pide prorratear; el Excel 2023 saca el activo completo).
8. Discriminar cálculos entre antes y después de 2018.

## Vidas útiles por rubro

- Cercos: 50 años (200 trimestres) - IPC
- Edificios (210LA, 220LA, 392LA): 50 años (200 trimestres) - IPC
- Terrenos (110LA): no amortiza - IPC
- Estructuras y caños: 10 años (40 trimestres) - IPC
- Eq. de Oficina (320LA): 3 años (12 trimestres) - IPC
- Máquinas y Equipos (310LA, 350LA): 10 años (40 trimestres) - IPC
- Máquinas Mejoras (370LA): 10 años (40 trimestres) - IPC
- Muebles y Útiles (330LA): 3 años (12 trimestres) - IPC
- Rodados (360LA): 5 años (20 trimestres) - IPC
- Terreno Mejoras (130LA, 250LA): 10 años (40 trimestres) - IPC
- Software (510LA, 515LA, 610LA): 3 años (12 trimestres) - IPC

## Fuentes de datos

- Altas, Bajas y Transferencias del ejercicio: extraídos de SAP
- Inventario histórico: archivo de revalúo del año anterior
- Índices de actualización: tablas IPC e IPIM incluidas en el Excel de revalúo
- Altas: se usa Posting Date (PSTNG date) como fecha de alta
- Transferencias: se usa Cap Date (fecha de capitalización) como fecha de alta
- Bajas: valores congelados a LY (se pegan como valores para mantener los datos a inicio del ejercicio)

## Validaciones requeridas

- Amort acumulada = amort_trimestre × VUT cierre
- VR = VO - Amort acumulada
- VR Reexp = VO Reexp - Amort Acum Reexp
- PG: diferencia entre s/prueba y s/revalúo debe ser ~ 0
- Totales por rubro consistentes entre detalle y resumen
