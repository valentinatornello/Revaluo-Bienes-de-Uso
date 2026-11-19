# Respuestas a Preguntas Abiertas — Documentación de Proceso Manual (Valentina)

**Fecha:** 2026-11-09  
**Responsable:** Valentina Tornello  
**Nota importante:** Las respuestas que siguen se basan en la documentación actualizada del proceso manual (docs/15_proceso_manual_revaluo.md) y el análisis del VTT (AXI-es-ES.vtt). Estas respuestas son del análisis de Valentina y pueden requerir validación con Ricardo u otros expertos internos/KPMG.

---

## PA-03 — Bajas parciales: ¿cómo se tratan?

**Estado:** ✅ **RESPONDIDA (parcialmente documentada)**

**Respuesta (Valentina):**

Según la documentación del proceso manual (sección 2.6), las bajas parciales se tratan **proporcionalmente**:

1. **Baja total** (residual histórico = 0):
   - Se retira el 100% del valor ajustado por inflación
   - Se aplica el coeficiente punta a punta
   - Resultado: AxI de la baja = 0

2. **Baja parcial** (residual histórico > 0):
   - Se prorratea el AxI proporcionalmente
   - Ejemplo: si se da baja el 60% del valor histórico, se retira el 60% del valor AxI ajustado
   - **No se ignora** hasta que esté totalmente depreciado
   - Se requiere control manual post-fórmula: si `VO residual = 0 después de baja` → `AxI debe ser 0`. Si no, hubo error.

**Control clave del código R:**
- El filtro actual (`ret_book_value < 0.01`) puede estar excluyendo bajas parciales relevantes
- Se recomienda: revisar si hay bajas con `ret_book_value != 0` y monto significativo
- Si las hay, implementar prorrateo proporcional en lugar de exclusión

**Impacto:** Puede sub-registrar bajas de monto significativo en contabilidad local.

---

## PA-07 — Bajas: ¿se amortizan en el año de baja?

**Estado:** ✅ **RESPONDIDA (documentada con distinción Taxes/Contabilidad)**

**Respuesta (Valentina):**

La respuesta difiere según contexto:

### Para TAXES (KPMG, RT 22)
Según el VTT (AXI-es-ES.vtt), **las bajas se ajustan por coeficiente punta a punta**, no por el mes de baja:

- El valor histórico de la baja se multiplica por el **coeficiente punta a punta** (dic anterior a dic actual)
- Se aplica al saldo histórico completo (valor de origen + depreciación acumulada)
- **No hay amortización adicional en el año de baja**; lo que cambia es el ajuste por inflación
- Si se dio de alta en febrero y baja en diciembre, ambos usan el mismo coeficiente punta a punta

### Para CONTABILIDAD Local (Ley de Ganancias)
- **Bienes muebles:** Año de baja = sin amortización adicional
- **Edificios:** Se amortiza hasta el **trimestre de baja** (no año completo)
- El código R implementa esto: `periodos_hasta_baja = 1` para no-Edificios, `trimestre_baja` para Edificios

### Control post-fórmula
- Si valor residual histórico = 0 → AxI debe ser 0
- Si valor residual > 0 → fue baja parcial → prorratear AxI proporcionalmente
- Revisar línea a línea los casos que no pasen esta validación

**Impacto:** Crítico para conciliación SAP. Diferencia de criterios entre Taxes y Contabilidad debe documentarse.

---

## PA-08 — Fecha de índice para bajas SAP

**Estado:** ✅ **RESPONDIDA (documentada)**

**Respuesta (Valentina):**

Según la documentación del proceso manual (sección 2.6 y VTT):

**Para TAXES (KPMG):**
- El coeficiente de reexpresión se busca por la **fecha original del bien** (cap_date), no por la fecha de baja
- Esta es la fecha que aparece en SAP como "posting_date" de la capitalización original
- El coeficiente punta a punta se aplica igual a todos los activos, sin importar si se dan de baja o no
- La **fecha de baja no afecta el índice a aplicar**

**Inconsistencia en el código R:**
- `normalizar_baja_sap()` (`03_construir_rollforward.R:151`) asigna `fecha_alta = bajas$posting_date` (fecha de baja)
- Luego busca el índice por esa fecha → **INCORRECTO**
- Debe usar `cap_date_parsed` (fecha original) en su lugar

**Corrección recomendada:**
- Usar siempre la fecha original del bien (cap_date) para buscar el coeficiente
- Usar la fecha de baja solo para fines de registro/control, no para índices

**Impacto:** Puede cambiar significativamente el AxI de las bajas si la fecha de baja y cap_date son distantes.

---

## PA-16 — Amortización en año de baja para bienes muebles

**Estado:** ✅ **RESPONDIDA (documentada)**

**Respuesta (Valentina):**

Según la Ley de Ganancias y la documentación actualizada:

### Norma impositiva
- **Bienes muebles:** En el año de baja, **no se computa amortización adicional**
- **Edificios:** Se amortiza hasta el **trimestre de la baja**

### Lo que hace el código R
- Para no-Edificios: `periodos_hasta_baja = 1` (año completo) → **INCORRECTO según norma**
- Para Edificios: `periodos_hasta_baja = trimestre de baja` → **CORRECTO**

### Lo que probablemente hace el estudio 2023 (KPMG)
- La hoja "Amortización de las bajas" muestra valores no-cero
- Es probable que KPMG **calcule la amortización del año de baja y luego la retira** como parte del asiento de baja
- Esto es una práctica de presentación contable, no contraría la norma (solo aclara qué amortización se "consume" en la baja)

### Recomendación
- **Para TAXES:** Validar con KPMG si aplican `periodos_hasta_baja = 0` o calculan y retiran
- **Para Contabilidad local:** Implementar `periodos_hasta_baja = 0` para bienes muebles, `trimestre_baja` para Edificios

**Impacto:** Crítico. Puede generar diferencias de cálculo entre motor R y estudio KPMG en todas las bajas del ejercicio.

---

## Preguntas SIN Respuesta en esta Documentación

Las siguientes preguntas abiertas **NO fueron respondidas** en el proceso manual documentado:

- **PA-02:** Corte automático a 01/01/1992 (requiere análisis histórico de bienes)
- **PA-03:** Conteo y monto de bajas parciales (requiere análisis de datos SAP)
- **PA-04:** Prorrateo año edificios vs. muebles (requiere validación con KPMG)
- **PA-05:** Tablas de índices separadas para bajas (requiere validación con KPMG)
- **PA-06:** Amortización transferida (requiere clarificación en SAP)
- **PA-09 a PA-15:** Varias preguntas sobre datos, arquitectura y redondeo (requieren análisis técnico específico)

---

**Próximos pasos:** Coordinar estas respuestas con Ricardo, KPMG y los auditores para validación formal.
