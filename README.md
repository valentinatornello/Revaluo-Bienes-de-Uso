# Revalúo de Bienes de Uso

## Descripción

Proyecto para automatizar el cálculo del Revalúo de Bienes de Uso (Ajuste por Inflación Impositivo) de Monsanto/Bayer Argentina, reemplazando el proceso manual que realizaba el equipo de KPMG.

**Contexto**: KPMG realizaba este cálculo anualmente sobre archivos Excel con ~56.000 activos distribuidos en 11 categorías. Al pasar KPMG a ser auditor de la compañía, ya no puede ejecutar esta tarea por conflicto de interés. Este proyecto internaliza el proceso con un flujo automatizado en R que produce el mismo output pero con mayor trazabilidad y menor riesgo de error.

## Objetivo

### Objetivo general

Automatizar el cálculo del revalúo de bienes de uso para ejecutarlo de forma interna a partir del ejercicio 2025, produciendo un output equivalente al de KPMG pero más limpio y estructurado.

### Estrategia de validación

El modelo se valida contra los resultados históricos de KPMG para tres ejercicios consecutivos:

| Ejercicio | Archivo KPMG | Estado |
|---|---|---|
| 2022 | `MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC.xlsx` | En validación |
| 2023 | Pendiente | Pendiente |
| 2024 | Pendiente | Pendiente |

Una vez que el modelo reproduzca los resultados de los tres ejercicios, se considerará validado para producción (2025+).

### Output deseado

El output final es un archivo Excel con la siguiente estructura:

- **Detalle por categoría (Class)**: una hoja por rubro con el cálculo activo por activo
- **Prueba Global por Class**: reconciliación individual por cada categoría
- **Prueba Global Total**: consolidación de todas las categorías
- **Amortizaciones globales**: resumen de amortización histórica y reexpresada
- **Hojas de índices**: tablas IPC e IPIM utilizadas en el cálculo
- **Resumen ejecutivo**: resultado del AXI por categoría

### Objetivos específicos

- Consolidar en un único flujo las fuentes de información del proceso.
- Integrar de forma controlada los movimientos del ejercicio.
- Reconstruir el inventario histórico de activos por rubro.
- Aplicar los cálculos de ajuste por inflación y amortización según los criterios definidos.
- Ejecutar validaciones automáticas que aseguren la consistencia de los resultados.
- Generar salidas aptas para revisión por los equipos de Impuestos y Contabilidad.
- Garantizar la trazabilidad completa de cada transformación y cálculo.

## Alcance

- **Lectura y consolidación de archivos SAP**: ingesta de los extractos del sistema y homogeneización de estructuras.
- **Integración de altas, bajas y transferencias**: incorporación de los movimientos del ejercicio a la base histórica.
- **Reconstrucción del inventario histórico de activos**: actualización del stock por rubro y por activo, conservando el historial necesario para los cálculos.
- **Cálculo de ajuste por inflación**: aplicación de reglas de actualización monetaria sobre los bienes alcanzados.
- **Generación de Prueba Global (PG)**: preparación de métricas y saldos para la instancia de control global.
- **Validaciones automáticas de consistencia**: cruces entre saldos, detección de diferencias y controles de integridad.
- **Trazabilidad de cálculos**: registro de cada transformación aplicada, desde los datos originales hasta el resultado final.
- **Exportación para revisión de Impuestos y Contabilidad**: generación de archivos de salida con el detalle necesario para el cierre y la auditoría.

## Configuración del entorno

1. Instalar `renv` si no está disponible: `install.packages("renv")`.
2. Restaurar dependencias del proyecto: `renv::restore()`.

## Flujo del proceso

1. **Recepción de insumos**: archivos del ejercicio y archivos históricos del período anterior.
2. **Estandarización**: corrección de formatos, nombres de campos y tipos de dato.
3. **Integración de movimientos**: incorporación de altas, bajas y transferencias.
4. **Reconstrucción del inventario**: actualización del stock de bienes de uso por rubro.
5. **Cálculos**: amortizaciones, actualizaciones, ajuste por inflación y Prueba Global.
6. **Validación**: controles automáticos de consistencia antes de emitir resultados.
7. **Exportación**: generación de archivos de salida para revisión y cierre.

## Entradas

- Archivos extraídos de SAP.
- Archivos de Altas, Bajas y Transferencias del ejercicio.
- Archivo histórico de revalúo del período anterior.
- Criterios de vida útil y amortización por rubro.
- Índices y parámetros de actualización aplicables (IPC e IPIM).
- Archivos auxiliares de validación y soporte.

## Salidas

- Inventario reconstruido de bienes de uso.
- Detalle de movimientos integrados al período.
- Cálculo del revalúo y del ajuste por inflación.
- Resultados de la Prueba Global.
- Validaciones de consistencia.
- Archivos exportables para revisión funcional.

## Estructura del repositorio

```
revaluo-bienes-de-uso/
├── data/              # Datos crudos, intermedios y procesados
├── inputs/            # Fuentes de entrada organizadas por tipo
├── outputs/           # Reportes, auditoría y archivo final de salida
├── R/                 # Scripts del flujo de procesamiento
├── docs/              # Documentación funcional y metodológica
├── tests/             # Pruebas automatizadas
└── _targets.R         # Definición del pipeline (targets)
```

### Descripción de directorios

| Directorio | Contenido |
|---|---|
| `data/` | Datos en sus distintas etapas: crudos tal como se reciben, intermedios generados por el pipeline y procesados listos para cálculo. |
| `inputs/` | Fuentes de entrada organizadas por tipo (SAP, Altas, Bajas, Transferencias, históricos, índices). |
| `outputs/` | Resultados del proceso: reportes finales, archivos de auditoría y salidas para revisión. |
| `R/` | Scripts con las funciones y etapas del flujo de procesamiento. |
| `docs/` | Documentación funcional del proceso, reglas de negocio y metodología de cálculo. |
| `tests/` | Pruebas automatizadas para validar transformaciones y cálculos. |

## Beneficios esperados

- Reducción del tiempo operativo del proceso.
- Disminución de errores por manipulación manual.
- Reproducibilidad de los cálculos entre períodos.
- Menor dependencia de desarrollos externos.
- Mayor capacidad de auditoría y revisión.
- Conservación del conocimiento de negocio dentro de la organización.

## Principios de diseño

- **Reproducibilidad**: un mismo conjunto de entradas debe producir siempre el mismo resultado.
- **Transparencia**: cada transformación y cálculo debe poder explicarse y rastrearse.
- **Modularidad**: el proceso se organiza en etapas reutilizables y mantenibles.
- **Auditabilidad**: debe existir evidencia suficiente para validar cómo se obtuvo cada salida.

## Tecnologías

- **R**: lenguaje principal del proyecto.
- **tidyverse**: transformación, limpieza y modelado de datos.
- **readxl**: lectura de archivos Excel de entrada.
- **openxlsx**: generación y exportación de archivos Excel de salida.
- **janitor**: normalización de nombres de columnas y estructuras.
- **lubridate**: tratamiento de fechas y períodos.
- **targets**: orquestación del pipeline y ejecución reproducible.
- **renv**: gestión de dependencias y control del entorno.

## Equipo

- Pablo Fernández
- Ricardo Molina
- Valentina Tornello

## Estado actual

Pipeline funcional ejecutando los 7 pasos del cálculo end-to-end con datos reales del ejercicio 2022:

- **Importación**: lee las 11 hojas del Excel de KPMG + archivo SAP (Altas, Bajas, Transferencias)
- **Limpieza**: normaliza ~65.000 filas, filtra IFRS16 y filas de control
- **Rollforward**: integra movimientos del ejercicio con detección de duplicados
- **Cálculo AXI**: amortización histórica + reexpresión IPC/IPIM por activo
- **Prueba Global**: reconciliación por categoría (4/10 rubros con diferencia = 0)
- **Validaciones**: consistencia interna perfecta (VR = VO - Amort Acum)
- **Exportación**: genera 3 archivos Excel (resultado, validaciones, resumen)

Próximos pasos: ajustar edge cases de la PG para las categorías restantes, validar contra ejercicios 2023 y 2024.
