# Flujo del proceso

## Pipeline de ejecución (targets)

```
importar_datos ──> limpiar_datos ──> construir_rollforward ──> calcular_axi ──> generar_prueba_global ──> ejecutar_validaciones ──> exportar_resultados
```

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
