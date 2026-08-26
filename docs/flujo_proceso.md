# Flujo del proceso

## Contexto y motivación

El cálculo del Revalúo de Bienes de Uso (Ajuste por Inflación Impositivo) de MARG era realizado hasta ahora por el equipo de KPMG. Dado que KPMG pasa a ser auditor de la compañía, ya no puede continuar ejecutando esta tarea por conflicto de interés. Este proyecto automatiza el proceso para que el equipo interno pueda ejecutarlo de forma autónoma a partir del ejercicio 2025.

### Estrategia de validación

Para garantizar que el modelo produce resultados correctos, se validará contra los cálculos históricos de KPMG:

1. **2022**: validación inicial con el Excel de KPMG (`MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC.xlsx`)
2. **2023**: segunda validación contra el ejercicio 2023
3. **2024**: tercera validación contra el ejercicio 2024

Una vez que el modelo reproduzca los resultados de KPMG para los tres ejercicios, se considerará validado y listo para producción a partir de 2025.

### Output deseado

El output final es un archivo Excel equivalente al que producía KPMG, pero con una estructura más limpia:

- **Una hoja por categoría (Class)**: detalle activo por activo con todos los cálculos
- **Prueba Global por Class**: reconciliación de amortizaciones y valor residual por cada categoría individual
- **Prueba Global Total**: consolidación de todas las categorías
- **Amortizaciones globales**: resumen de amortización histórica y reexpresada
- **Hojas de índices**: tablas IPC e IPIM utilizadas
- **Resumen ejecutivo**: resultado del AXI por categoría

## Pipeline de ejecución (targets)

```
importar_datos ──> limpiar_datos ──> construir_rollforward ──> calcular_axi ──> generar_prueba_global ──> ejecutar_validaciones ──> exportar_resultados
```

### Modo de uso

El pipeline se diseñó para ejecutar año a año, tomando como input el Excel de revalúo del año anterior:

```
Año X-1 Excel (resultado KPMG o ejecución previa)
         │
         ├── Inventario histórico de activos
         └── Tablas de índices IPC/IPIM
                    │
                    ▼
    ┌──────────────────────────────┐
    │   SAP: Altas, Bajas,        │
    │   Transferencias del año X  │
    └──────────────────────────────┘
                    │
                    ▼
           Pipeline en R
                    │
                    ▼
         Año X Excel (output)
```

Para la fase de validación (2022-2024), el Excel del año X ya contiene los movimientos del año (generado por KPMG), por lo que el pipeline detecta automáticamente esta situación y no duplica los movimientos de SAP.

## Detalle por etapa

### 1. Importar datos (`01_importar_datos.R`)
- Lee el Excel de revalúo del año anterior (todas las hojas de categorías)
- Lee las tablas de índices IPC e IPIM (incluyendo versiones para bajas)
- Lee archivos de Altas, Bajas y Transferencias del ejercicio desde `inputs/`
- **Salida**: lista con inventario_ly, indices, altas, bajas, transferencias

### 2. Limpiar datos (`02_limpiar_datos.R`)
- Estandariza nombres de columnas
- Parsea fechas (posting date) y tipos numéricos
- Clasifica activos por rubro según código SAP
- Filtra activos IFRS16 (prefijo "AS")
- **Salida**: datos normalizados por categoría

### 3. Construir rollforward (`03_construir_rollforward.R`)
- Parte del inventario del año anterior
- Incorpora altas del ejercicio
- Incorpora transferencias (alta + baja)
- Aplica bajas
- Marca origen de cada movimiento
- **Salida**: inventario actualizado con movimientos del ejercicio

### 4. Calcular AXI (`04_calculo_axi.R`)
- Calcula amortización histórica: VUT, amort trimestre, amort acumulada, VR
- Busca coeficientes IPC/IPIM según fecha de alta
- Calcula reexpresión: VO reexp, amort reexp, VR reexp
- Casos especiales: terrenos (no amortiza), VU agotada
- **Salida**: dataframe con columnas históricas + reexpresadas por activo

### 5. Prueba Global (`05_prueba_global.R`)
- Resume por rubro: amort al inicio, altas, transferencias, bajas, ajustes
- Compara amort s/prueba vs amort s/revalúo
- Calcula VR s/prueba vs VR s/revalúo
- Genera PG AXI con VR reexpresado
- **Salida**: tablas de prueba global

### 6. Validaciones (`06_validaciones.R`)
- Consistencia interna: VR = VO - Amort Acum
- PG amortizaciones: diferencia < tolerancia
- PG valor residual: diferencia < tolerancia
- VR reexpresado consistente
- **Salida**: resumen de validaciones con OK/ERROR/ADVERTENCIA

### 7. Exportar resultados (`07_exportar_resultados.R`)
- Genera Excel con una hoja por categoría
- Incluye hojas PG y PG AXI
- Incluye hojas de índices
- Exporta validaciones con formato condicional
- Exporta resumen ejecutivo
- **Salida**: archivos .xlsx en `outputs/`
