# Revalúo de Bienes de Uso

Proyecto para automatizar el cálculo del Revalúo de Bienes de Uso de Monsanto/Bayer Argentina mediante un flujo reproducible en R.

## Objetivo

Centralizar la información de SAP y archivos históricos para ejecutar el proceso de forma estandarizada, transparente y auditable.

## Alcance

- Lectura y consolidación de archivos SAP.
- Integración de altas, bajas y transferencias.
- Reconstrucción del inventario histórico de activos.
- Cálculo de ajuste por inflación.
- Generación de Prueba Global.
- Validaciones automáticas de consistencia.
- Trazabilidad de cálculos.
- Exportación para revisión de Impuestos y Contabilidad.

## Estructura

- `data/`: datos crudos, intermedios y procesados.
- `inputs/`: fuentes de entrada por tipo.
- `outputs/`: reportes, auditoría y salida final.
- `R/`: scripts del flujo de procesamiento.
- `docs/`: documentación funcional y metodológica.
- `tests/`: espacio para pruebas automatizadas.

## Equipo

- Pablo Fernández
- Ricardo Molina
- Valentina Tornello
