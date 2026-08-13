# Revaluo-Bienes-de-Uso
Automatización del proceso de Revalúo de Bienes de Uso mediante R, consolidando información proveniente de SAP y archivos de trabajo históricos para generar cálculos trazables, reproducibles y auditables de ajuste por inflación y revalúo impositivo.

## Objetivo

Este proyecto tiene como objetivo automatizar el proceso de cálculo del Revalúo de Bienes de Uso utilizado por Monsanto/Bayer Argentina, reemplazando tareas manuales realizadas sobre múltiples archivos Excel por un flujo reproducible desarrollado en R.

La solución busca centralizar la información proveniente de SAP y de los archivos históricos de trabajo, permitiendo ejecutar el proceso de manera estandarizada, transparente y auditable.

## Alcance

El modelo contempla:

- Lectura y consolidación de archivos SAP.
- Integración de movimientos de Altas, Bajas y Transferencias.
- Reconstrucción del inventario histórico de activos.
- Aplicación de cálculos de Ajuste por Inflación.
- Generación de Prueba Global (PG).
- Validaciones automáticas de consistencia.
- Trazabilidad completa de cada cálculo realizado.
- Exportación de resultados para revisión por los equipos de Impuestos y Contabilidad.

## Beneficios esperados

- Reducción del tiempo operativo.
- Disminución de errores manuales.
- Reproducibilidad del proceso.
- Menor dependencia de desarrollos externos.
- Mayor capacidad de auditoría y revisión.
- Conservación del conocimiento de negocio dentro de la organización.

## Equipo

- Pablo Fernández
- Ricardo Molina
- Valentina Tornello

## Tecnologías

- R
- tidyverse
- readxl
- openxlsx
- janitor
- lubridate
- targets
- renv

## Estado actual

Fase inicial de diseño y modelado del flujo de automatización.
