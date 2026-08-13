# Revalúo de Bienes de Uso

Proyecto para automatizar el cálculo del Revalúo de Bienes de Uso de Monsanto/Bayer Argentina, reemplazando las tareas manuales realizadas sobre múltiples archivos Excel por un flujo reproducible desarrollado en R.

## Descripción

El proceso actual depende de la consolidación manual de información proveniente de SAP y de archivos históricos de trabajo, lo que implica un alto riesgo de errores, baja trazabilidad y una fuerte dependencia del conocimiento operativo de personas específicas. La solución propuesta busca transformar este esquema en un proceso estandarizado, transparente y auditable.

La iniciativa está orientada a automatizar las cuentas de 2025 en adelante. Como etapa de validación, se utilizarán datos de 2022, 2023 y 2024 para comprobar si el modelo reproduce el mismo resultado obtenido previamente por el equipo de KPMG. Este proyecto surge porque ese equipo pasará a cumplir el rol de auditor y ya no podrá continuar ejecutando esta tarea operativa.

## Objetivo

### Objetivo general

Centralizar la información de SAP y de los archivos históricos para ejecutar el revalúo de bienes de uso de forma estandarizada, transparente y auditable, con capacidad de sostener el proceso para las cuentas 2025 en adelante.

### Objetivos específicos

- Consolidar en un único flujo las fuentes de información del proceso.
- Integrar de forma controlada los movimientos del ejercicio.
- Reconstruir el inventario histórico de activos por rubro.
- Aplicar los cálculos de ajuste por inflación y amortización según los criterios definidos.
- Ejecutar validaciones automáticas que aseguren la consistencia de los resultados.
- Validar el modelo contra los resultados históricos de 2022, 2023 y 2024 elaborados por KPMG.
- Generar salidas aptas para revisión por los equipos de Impuestos y Contabilidad.
- Replicar el output funcional esperado en Excel, con una presentación más limpia y ordenada.
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

## Flujo del proceso

1. **Recepción de insumos**: archivos del ejercicio y archivos históricos del período anterior.
2. **Estandarización**: corrección de formatos, nombres de campos y tipos de dato.
3. **Integración de movimientos**: incorporación de altas, bajas y transferencias.
4. **Reconstrucción del inventario**: actualización del stock de bienes de uso por rubro.
5. **Cálculos**: amortizaciones, actualizaciones, ajuste por inflación y Prueba Global.
6. **Validación histórica**: contraste de los resultados del modelo contra los ejercicios 2022, 2023 y 2024 preparados por KPMG.
7. **Validación**: controles automáticos de consistencia antes de emitir resultados.
8. **Exportación**: generación de archivos de salida para revisión y cierre.

## MARG – Reexp. de amortizaciones

Partir de:

- Archivo revalúo LY.
- Archivo altas, bajas y transferencias FY que se liquida (archivo ABT), modificando previamente el formato de fechas de `.` a `/` (`find and select` → `replace`).

En el archivo revalúo LY, rubro por rubro (class):

1. **Incorporar altas y transferencias del FY** (surgen del archivo ABT). Importante: no modificar aún el año detallado en el recuadro, por el cálculo de las amortizaciones de las bajas que deben quedar a LY.
2. **Tener en cuenta las fechas del archivo ABT**:
   - **Altas**: considerar la fecha detallada en la columna `PSTNG date`.
   - **Transferencias**: considerar la fecha detallada en la columna `CAP date`.
3. **Extraer el resto de los datos**:
   - **N° activo fijo**: `asset`.
   - **Descripción**: `asset description`.
   - **VO**: suma de `aquisition` / suma de `transfer`.
   - **VU asignada**: se aclara para cada rubro en el archivo del revalúo (criterio de amortización año de alta).
4. **Extraer las bajas** a partir de las detalladas por rubro en el archivo ABT (`vlookup` y control). Luego, cortar (filtrando y utilizando `find and select` → `go to special` → `visible cells only`) y copiar al final de ese rubro, pegando a valor para conservar los datos a LY. Controlar el resultado.
5. **Detallar bajas no presentes en el archivo de revalúo**: si en el archivo ABT se informan bienes dados de baja que no están en el archivo del revalúo, igualmente deben detallarse al final del rubro con el número de `asset`.
6. **Completar el resto de las columnas**, con especial atención en las columnas de altas y transferencias. En la columna `bienes que agotaron BU LY`, detallar los bienes que agotaron su vida útil el año anterior. Actualizar los índices de actualización (`IPIM` para altas hasta 2017, `IPC` para altas a partir de 2018). Aclaración: para el FY2023 se actualizaron únicamente las altas a partir de 2018.
7. **Al finalizar cada rubro, realizar las pruebas globales**. La amortización al inicio corresponde al dato LY (amortización al cierre).

## Configuración del entorno

1. Instalar `renv` si no está disponible: `install.packages("renv")`.
2. Restaurar dependencias del proyecto: `renv::restore()`.

## Entradas

- Archivos extraídos de SAP.
- Archivos de Altas, Bajas y Transferencias del ejercicio.
- Archivo histórico de revalúo del período anterior.
- Criterios de vida útil y amortización por rubro.
- Índices y parámetros de actualización aplicables.
- Archivos auxiliares de validación y soporte.

## Salidas

- Inventario reconstruido de bienes de uso.
- Detalle de movimientos integrados al período.
- Cálculo del revalúo y del ajuste por inflación.
- Prueba Global separada por `class` y consolidada total.
- Amortizaciones globales y demás cuadros de control necesarios para revisión.
- Validaciones de consistencia.
- Archivo Excel final con el mismo output funcional que KPMG, en un formato más limpio y ordenado.

## Estructura del repositorio

```text
revaluo-bienes-de-uso/
├── data/        # Datos crudos, intermedios y procesados
├── inputs/      # Fuentes de entrada organizadas por tipo
├── outputs/     # Reportes, auditoría y archivo final de salida
├── R/           # Scripts del flujo de procesamiento
├── docs/        # Documentación funcional y metodológica
├── tests/       # Pruebas automatizadas
└── _targets.R   # Definición del pipeline (targets)
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

## Estado actual

Fase inicial de diseño y modelado del flujo de automatización. Se encuentra en curso el relevamiento funcional del proceso, la identificación de reglas de negocio, la estructuración del pipeline técnico y la definición de las validaciones necesarias para reproducir los resultados históricos de KPMG antes de operar sobre las cuentas 2025 en adelante.

## Equipo

- Pablo Fernández
- Ricardo Molina
- Valentina Tornello
