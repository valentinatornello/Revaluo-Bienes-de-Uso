# Indicador Global de Automatización — Documentación Técnica

## Descripción

El **Indicador Global de Automatización** es una métrica visual que aparece en la sección "Paso 6 — Validaciones" de la Shiny app. Mide la similitud entre los cálculos del motor R (revalúo automatizado) y los datos del manual de KPMG, expresada en porcentaje de **0% a 100%**.

- **100%** = Concordancia completa con KPMG
- **0%** = Discrepancia total (motor no ejecutó o errores críticos)

---

## Componentes del Cálculo

### 1️⃣ Consistencia Interna (20 puntos máximo)

**¿Qué valida?**
- Que el motor sea internamente coherente
- Fórmulas base:
  - `Amortización acumulada = Amortización trimestral × VUT cierre`
  - `Valor residual = Valor origen − Amortización acumulada`
  - `Valor residual reexp = Valor origen reexp − Amortización acumulada reexp`

**Scoring:**
- ✅ Si **todas** las validaciones internas pasan: **+20 puntos**
- ❌ Si **alguna** falla: **0 puntos** (binaria, no parcial)

**Ubicación en código:** `app.R`, función `calcular_automatizacion()`, línea ~98

```r
consistente <- isTRUE(val$consistente)
similitudes <- c(similitudes, if (consistente) 20 else 0)
```

---

### 2️⃣ Prueba Global por Rubro (40 puntos máximo)

**¿Qué valida?**
- Comparación rubro por rubro entre:
  - **s/prueba:** Saldos calculados por el motor
  - **s/revalúo:** Saldos del manual de KPMG
- Comparación en tres dimensiones:
  - Amortizaciones acumuladas
  - Valores residuales
  - Ajuste por inflación (AXI)

**Tolerancias aplicadas:**
| Diferencia | Clasificación | Descripción |
|-----------|--------------|-------------|
| < $1.000 | ✅ OK | Dentro de tolerancia (redondeo esperado) |
| $1.000–$10.000 | ⚠️ ADVERTENCIA | Diferencia moderada (requiere revisión) |
| > $10.000 | ❌ ERROR | Diferencia material (investigación urgente) |

**Scoring:**
- ✅ Si **todas las diferencias son OK** (< $1.000): **+40 puntos**
- ⚠️ Si hay **ADVERTENCIAS pero sin ERROR**: **+20 puntos**
- ❌ Si hay **algún ERROR**: **0 puntos**

**Ubicación en código:** `app.R`, función `calcular_automatizacion()`, líneas ~106–120

```r
pg_resultados <- resumen %>%
  filter(grepl("prueba_global|amortización.*prueba|valor_residual.*prueba", tipo, ignore.case = TRUE)) %>%
  pull(resultado)

if (length(pg_resultados) > 0) {
  if (all(pg_resultados == "OK", na.rm = TRUE)) {
    similitudes <- c(similitudes, 40)
  } else if (any(pg_resultados == "ERROR", na.rm = TRUE)) {
    similitudes <- c(similitudes, 0)
  } else {
    similitudes <- c(similitudes, 20)
  }
}
```

---

### 3️⃣ Validación Externa — KPMG (40 puntos máximo, **OPCIONAL**)

**¿Qué valida?**
- Se activa **solo si se carga el archivo manual de KPMG** en "Validación externa"
- Compara diferencias calculadas contra tolerancia **±20%** de los valores KPMG
- Busca en la tabla de validación por términos: `kpmg`, `precio`, `externo`

**Scoring:**
- ✅ Si **todas las diferencias están dentro de ±20%**: **+40 puntos**
- ⚠️ Si hay diferencias en rango **moderado (intermedio)**: **+20 puntos**
- ❌ Si hay diferencias **> ±20%**: **0 puntos**
- ℹ️ Si se cargó archivo KPMG pero **no hay validación específica**: **+20 puntos** (presunción de confianza)

**Ubicación en código:** `app.R`, función `calcular_automatizacion()`, líneas ~122–148

```r
if (!is.null(pg_real)) {
  validacion_externa <- resumen %>%
    filter(grepl("kpmg|precio|externo", tipo, ignore.case = TRUE)) %>%
    pull(resultado)
  
  if (length(validacion_externa) > 0) {
    if (all(validacion_externa == "OK", na.rm = TRUE)) {
      similitudes <- c(similitudes, 40)
    } else if (any(validacion_externa == "ERROR", na.rm = TRUE)) {
      similitudes <- c(similitudes, 0)
    } else {
      similitudes <- c(similitudes, 20)
    }
  } else {
    similitudes <- c(similitudes, 20)
  }
}
```

---

## Cálculo del Porcentaje Final

### Fórmula

```
Score Total = Consistencia Interna + Prueba Global + Validación Externa (opcional)
Max Score = 60 (sin KPMG) o 100 (con KPMG)
Porcentaje = (Score Total / Max Score) × 100, capped a 100%
```

### Ejemplos Numéricos

#### Ejemplo 1: Sin archivo KPMG
- Consistencia interna: ✅ → 20 puntos
- Prueba global: ⚠️ (ADVERTENCIA) → 20 puntos
- Validación externa: N/A → 0 puntos
- **Score = 40 / 60 = 66.7%** (Automatización **moderada**)

#### Ejemplo 2: Con KPMG, concordancia parcial
- Consistencia interna: ✅ → 20 puntos
- Prueba global: ✅ (todas OK) → 40 puntos
- Validación externa: ⚠️ (diferencias moderadas) → 20 puntos
- **Score = 80 / 100 = 80%** (Automatización **buena**)

#### Ejemplo 3: Concordancia total con KPMG
- Consistencia interna: ✅ → 20 puntos
- Prueba global: ✅ → 40 puntos
- Validación externa: ✅ → 40 puntos
- **Score = 100 / 100 = 100%** (Automatización **completa**)

---

## Presentación Visual (UI)

### Componentes HTML

**Archivo:** `app.R`, función `barra_automatizacion()`

1. **Encabezado + Porcentaje**
   - Etiqueta: "Automatización Global"
   - Valor numérico en grande: `XX.X%`
   - Color dinámico según rango

2. **Barra de progreso animada**
   - Ancho proporcional al porcentaje
   - Color de fondo se adapta al rango
   - Transición suave CSS (0.3s)

3. **Leyenda explicativa**
   - Texto pequeño: "Indicador de similitud con datos KPMG (100% = coincidencia completa)"

### Paleta de Colores

| Rango | Color | Hex | Significado |
|-------|-------|-----|------------|
| **95–100%** | 🟢 Verde | `#217346` | Automatización casi completa |
| **80–94%** | 🔵 Azul | `#2c7be5` | Automatización buena |
| **60–79%** | 🟠 Naranja | `#9C5700` | Automatización moderada |
| **<60%** | 🔴 Rojo | `#c00000` | Automatización baja |

### Ubicación en la UI

**Sección:** Paso 6 — Validaciones  
**Posición:** Antes de la tabla de validaciones y el "Estado general"  
**Condición:** Se renderiza solo si `estado$paso >= 6`

```r
# En app.R, línea ~950
output$paso6_ui <- renderUI({
  if (estado$paso < 6L) return(tags$p(style = "color:#aaa;", "En espera…"))
  
  # ... cargar datos ...
  
  tagList(
    # AQUÍ: Mostrar barra de automatización
    barra_automatizacion(automatizacion),
    
    # ... resto de validaciones ...
  )
})
```

---

## Criterios de Interpretación

### 📊 Rango de 95–100%: Automatización Casi Completa
- **Estado:** Listo para uso en produción
- **Acciones:**
  - ✅ Usar resultados del motor con confianza
  - 📝 Revisar solo rubros con diferencias documentadas
  - 🔄 Proceder a entrega a KPMG

### 📊 Rango de 80–94%: Automatización Buena
- **Estado:** Usable con validación moderada
- **Acciones:**
  - ⚠️ Revisar rubros con ADVERTENCIA
  - 📋 Documentar patrones de diferencias
  - 🔍 Si las ADVERTENCIAS son < $5.000 agregadas, OK; si > $5.000, investigar
  - ✅ Generalmente OK para usar

### 📊 Rango de 60–79%: Automatización Moderada
- **Estado:** Requiere validación manual antes de usar
- **Acciones:**
  - 🚨 Investigar todos los ERROR
  - 📞 Coordinar con KPMG para aclarar discrepancias
  - 🔧 Posibles correcciones: coeficientes, fechas, exclusiones
  - ❌ **No usar sin validación exhaustiva**

### 📊 Rango de <60%: Automatización Baja
- **Estado:** **NO USAR**
- **Acciones:**
  - 🔴 Motor tiene problemas críticos
  - 📞 Contactar responsable técnico
  - 🔧 Revisar archivo SAP, parámetros LY, índices
  - 🚫 Usar solo manual de KPMG hasta resolver

---

## Notas Operacionales

### Sobre Tolerancias y Redondeo
- Las ADVERTENCIAS ($1.000–$10.000) suelen deberse a **diferencias de redondeo**:
  - Excel usa precisión de celda (8 decimales)
  - R usa precisión de máquina (doble)
  - Diferencias acumuladas pueden ser $1.000–$5.000 en portafolios grandes
- **Patrón esperado:** Si todas las ADVERTENCIAS siguen el mismo rubro, probablemente es redondeo; si están distribuidas, investigar fórmulas

### Sobre Validación Externa (KPMG)
- **Sin archivo KPMG:** Máximo porcentaje alcanzable ≈ **60%** (sin el tercer componente)
- **Con archivo KPMG:** Máximo porcentaje alcanzable = **100%**
- **Recomendación:** Siempre cargar archivo KPMG para obtener indicador completo

### Sobre Errores Recurrentes
- **Error > $10.000 en Edificios:** Revisar aplicación de coeficiente punta a punta vs. índices mensuales
- **Error > $10.000 en Rodados:** Revisar tratamiento de bajas parciales (prorrateo)
- **Error > $10.000 en Terrenos:** Revisar si se excluyeron correctamente activos IFRS 16 (AS\*)
- **Error sistemático en AXI:** Revisar precisión de decimales del coeficiente; no redondear a 4-5 decimales

---

## Implementación Técnica (Referencia)

### Archivos afectados
- **app.R:** Función `calcular_automatizacion()` (líneas 93–165), función `barra_automatizacion()` (líneas 167–195), render `paso6_ui` (líneas ~950–975)
- **docs/15_proceso_manual_revaluo.md:** Sección "Indicador Global de Automatización" (para contexto conceptual)

### Dependencias R
- `tidyverse` (filter, pull)
- `shiny` (tags, renderUI, tagList)

### No requiere cambios en
- `R/*.R` (el motor calcula validaciones, el app solo interpreta)
- Base de datos o archivos externos

---

**Versión:** 1.0  
**Fecha de creación:** 2026-11-09  
**Responsable:** Implementación Shiny UI para motor de revalúo  
**Próximas mejoras:** Exportar porcentaje a Excel, alertas automáticas si < 80%, comparativa histórica año a año
