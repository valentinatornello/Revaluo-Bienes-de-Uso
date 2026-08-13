# Reglas de negocio

## Reglas generales

1. Si el bien se adquirió antes de 2018, NO se revalúan con IPC las amortizaciones ni VO (quedan a valores históricos). Se usa IPIM para la confiscatoriedad.
2. Si se informan bajas de bienes que no se identifican en la base, se detallan al final del rubro con el número de asset.
3. Assets cuyo nombre empieza con "AS" son operaciones IFRS16 y se excluyen del cálculo de revalúo.
4. La VU se expresa en trimestres. Se considera el mes de alta para evaluar trimestres transcurridos.
5. Los terrenos NO se amortizan.
6. Si VU Transcurrida = VU Asignada, el bien ya no se amortiza más.
7. Revisar si altas están en bajas del mismo año y netear.
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
- Posting date se usa como fecha de alta para el cálculo

## Validaciones requeridas

- Amort acumulada = amort_trimestre × VUT cierre
- VR = VO - Amort acumulada
- VR Reexp = VO Reexp - Amort Acum Reexp
- PG: diferencia entre s/prueba y s/revalúo debe ser ~ 0
- Totales por rubro consistentes entre detalle y resumen
