# Proceso Manual de Revalúo de Bienes de Uso

## Descripción General

Este documento describe el flujo manual de revalúo de terrenos y edificios. El proceso mezcla datos provenientes de SAP, ajuste por inflación, valuación externa (perito) y asignaciones manuales. Conviene automatizarlo por etapas dado su complejidad.

### Contexto Normativo: Taxes vs. Contabilidad

**IMPORTANTE:** El revalúo de bienes de uso aplica de manera diferente según el contexto:

- **TAXES (Impositivo - a cargo de KPMG):** Se aplica la RT 22 con criterio de **punta a punta** (diciembre a diciembre). Todos los activos fijos deben ajustarse por inflación, sin excepciones. El ajuste se aplica sobre el saldo histórico del activo. Esta aproximación es obligatoria para declaraciones impositivas y tiene reglas muy específicas sobre qué valores aplicar.

- **CONTABILIDAD (Balance local):** La metodología es conceptualmente similar pero con matices en la presentación y algunas decisiones sobre capitalización vs. resultados. Ejemplo: la amortización de la porción revaluada puede llevarse a patrimonio neto (histórico) o a resultados (criterio revisado en 2022), según política contable adoptada.

**Nota especial sobre IFRS 16:** Los activos de leasing bajo IFRS 16 se excluyen del revalúo para balance local (impositivo), aunque figuran en SAP con prefijo "AS******".

---

## 1. Preparar y Conciliar la Base

### 1.1 Armar el Anexo Histórico
- **Objetivo:** Construir el anexo histórico combinando la base de SAP con los movimientos del ejercicio.
- **Fuentes:** Base de SAP + movimientos del ejercicio (altas, bajas y traslados)
- **Acciones:**
  - Registrar todos los movimientos del período
  - Conciliar el resultado con SAP antes de continuar
  - No proceder a las etapas siguientes hasta confirmar la conciliación
- **Nota especial - Leasing IFRS 16:** Los bienes que comienzan con el prefijo "AS******" corresponden a asientos técnicos de leasing bajo IFRS 16 y no son bienes físicos. Para el balance local (impositivo) **no se incluyen en el revalúo**.

### 1.2 Separar Bienes Sujetos a Revalúo
- **Bienes revaluados:** Terrenos y edificios (incluidas mejoras sobre terrenos)
- **Bienes no revaluados:** El resto de los activos fijos siguen el cálculo habitual de punta a punta
- **Criterio de separación:** La nomenclatura del inventario identifica el tipo de bien

## 1. Preparar y Conciliar la Base

### 1.1 Armar el Anexo Histórico
- **Objetivo:** Construir el anexo histórico combinando la base de SAP con los movimientos del ejercicio.
- **Fuentes:** Base de SAP + movimientos del ejercicio (altas, bajas y traslados)
- **Acciones:**
  - Registrar todos los movimientos del período
  - Conciliar el resultado con SAP antes de continuar
  - No proceder a las etapas siguientes hasta confirmar la conciliación
- **Nota especial - Leasing IFRS 16:** Los bienes que comienzan con el prefijo "AS******" corresponden a asientos técnicos de leasing bajo IFRS 16 y no son bienes físicos. Para el balance local (impositivo) **no se incluyen en el revalúo**.

### 1.2 Separar Bienes Sujetos a Revalúo
- **Bienes revaluados:** Terrenos y edificios (incluidas mejoras sobre terrenos)
- **Bienes no revaluados:** El resto de los activos fijos siguen el cálculo habitual de punta a punta
- **Criterio de separación:** La nomenclatura del inventario identifica el tipo de bien

### 1.3 Concepto de "Punta a Punta" en Ajuste por Inflación

El ajuste por inflación se aplica bajo el criterio **punta a punta**, que significa:

- **Período:** De diciembre del año anterior a diciembre del año actual
- **Aplicación universal:** Todos los activos fijos deben ajustarse por inflación, sin excepciones, independientemente de cuándo hayan sido dados de alta, baja o trasladados durante el ejercicio
- **Índice único por período:** Se utiliza un coeficiente de represión calculado como:
  - **Coeficiente = Índice Diciembre Año Actual / Índice Diciembre Año Anterior**
- **Precisión de decimales:** Se recomienda mantener todos los decimales del coeficiente (no redondear a 4-5 decimales) para evitar diferencias de cruce en saldos finales

**Justificación:** En los anexos comparativos se presentan saldos al cierre, por lo que tiene sentido ajustarlos punta a punta, partiendo de esos saldos históricos comparativos ajustados por inflación, independientemente de que después los activos se hayan dado de baja.

### 1.4 Aplicar Ajuste por Inflación

**Secuencia de cálculo (AxI - Ajuste por Inflación):**

1. **Ajustar saldos comparativos iniciales (al cierre del año anterior):**
   - Todos los saldos al cierre del período anterior (históricos) se multiplican por el coeficiente punta a punta
   - Resultado: saldos al cierre del período anterior, ajustados por inflación

2. **Sobre esos saldos ajustados, aplicar movimientos del ejercicio:**
   - Altas: se ajustan por el coeficiente del mes en que se capitalizaron (fecha de posting)
   - Bajas: se ajustan por el coeficiente punta a punta (mismo que los saldos iniciales), no por el mes de baja
   - Traslados: movimientos internos entre categorías, sin ajuste adicional

3. **Luego comparar con valor de mercado del perito** (para bienes revaluados)

**Nota sobre depreciación acumulada:** Se aplica el mismo coeficiente punta a punta a la depreciación acumulada que se aplica al valor de origen.

---

## 2. Distribuir el Revalúo Anterior para Obtener Saldos Iniciales

### 2.1 Partir del Informe del Año Anterior
- **Estructura diferente:** El informe del perito agrupa valores por ítem o inmueble (ej. una línea por edificio)
- **vs. SAP:** SAP contiene numerosos activos individuales dentro de cada ítem
- **Ejemplo:** Un edificio en SAP puede estar representado por 10 activos diferentes; el perito lo valúa como una sola unidad

### 2.2 Relacionar Activos con Códigos del Perito
- **Nomenclatura:** Usar códigos asignados por el perito
  - `TE` = Terrenos
  - `ED` = Edificios
  - `MT` = Mejoras sobre terrenos
- **Fuente:** Inventario del año anterior
- **Objetivo:** Vincular cada activo de SAP con el código que lo identifica en el informe de valuación

### 2.3 Distribuir el Valor del Ítem
- **Método de prorrateo:**
  1. Tomar el valor residual de cada activo en SAP (saldo anterior)
  2. Calcular su proporción respecto del total asociado al código
  3. Aplicar esa proporción al valor del informe para ese código
  4. Resultado: cada activo recibe su prorrata del valor del ítem

- **Validación:** Comprobar que las asignaciones sumen exactamente el valor del informe para cada código
- **Nota:** Los activos asociados a más de un código deben conservar la asignación compartida indicada en el registro histórico

### 2.4 Excluir Activos Dados de Baja
- **Acción:** Comunicar al perito qué activos fueron dados de baja
- **Redistribución:** 
  - Si el código tiene otros activos vigentes, redistribuir el valor entre ellos
  - Si no queda ningún activo asociado al código, el ítem no debería aparecer en la valuación del año actual
- **Control:** Verificar que no aparezcan ítems huérfanos sin activos asociados

### 2.5 Tratar las Altas Nuevas
- **Opción 1 – Activos relacionados:** Si el bien es complementario a activos existentes, reutilizar el código del perito
- **Opción 2 – Ítem nuevo:** Si no tiene correspondencia, solicitar al perito que asigne un código
- **Revisión:** Revisar códigos agregados o corregidos en el intercambio de archivos
- **Documentación:** Dejar rastro de las asignaciones nuevas para auditoría

### 2.6 Construir Saldos Iniciales Distribuidos

**Construcción de la posición inicial para el ejercicio:**

1. **Partir de saldos al cierre del período anterior**, ajustados por inflación (del paso 1.3)
2. **Agregar movimientos dentro del mismo período anterior** si corresponde
3. **Aplicar la distribución del revalúo del año anterior** sobre esos activos
4. **Resultado:** Cada activo tiene un saldo inicial propio que refleja la prorrata del revalúo

**Secuencia correcta:** 
- Si un bien se dio de alta y de baja dentro del **mismo ejercicio**, registrar ambos movimientos en la posición inicial
  - Alta: valor histórico en la fecha de alta × coeficiente del mes de alta
  - Baja: valor histórico × coeficiente punta a punta (se anula con el alta si son del mismo ejercicio)
  - Resultado final: cero en la mayoría de casos (excepto si el alta fue en febrero y la baja en diciembre, quedando diferencias por períodos distintos de ajuste)

- Completar esta etapa **antes** de calcular el ajuste por inflación del año siguiente

**Control manual:** Después de aplicar la fórmula general de distribución, revisar caso por caso:
- Si un activo fue dado de baja completamente (valor residual = 0), su AxI debe ser cero
- Si valor residual > 0, verificar si fue baja parcial → aplicar prorrateo proporcional

---

## 3. Preparar y Revisar la Valuación del Ejercicio

### 3.1 Preparar Archivo para el Perito
- **Contenido a enviar:**
  - Patrimonio de terrenos y edificios (base después de ajuste por inflación)
  - Valores distribuidos por activo individual
  - Movimientos del ejercicio (altas, bajas, traslados)
  - Lista de activos dados de baja para excluir de la valuación

- **Formato:** Según acuerdo con el perito (históricamente en Excel)

### 3.2 Acompañar el Proceso de Valuación
- **Interacción:** Durante el proceso pueden solicitarse datos adicionales y realizarse visitas a plantas
- **Salida esperada:** 
  - Valuación detallada por código (perito)
  - Resumen agrupado por ítem (perito)
- **Duración:** Proceso iterativo que requiere seguimiento

### 3.3 Validar el Informe Recibido
Antes de aceptar la valuación, verificar:
- [ ] Códigos coherentes con el envío inicial
- [ ] Altas nuevas reciben códigos válidos
- [ ] Bajas excluidas no aparecen en la valuación
- [ ] Totales distribuidos coinciden con valores agrupados del informe
- [ ] Activos con asignación compartida mantienen la prorrata indicada
- [ ] No hay ítems huérfanos

---

## 4. Registrar el Ajuste y Calcular Amortización

### 4.1 Comparar Valor Ajustado vs. Valor de Mercado
- **Por cada rubro (terreno/edificio):**
  
| Escenario | Acción |
|-----------|--------|
| Mercado > Ajustado | Registrar el mayor valor contra patrimonio neto |
| Mercado < Ajustado | Registrar primero ajuste por inflación, luego reducir el valor del activo contra patrimonio neto para no superar tope de mercado |

- **Justificación normativa:** Criterio de valor de realización

### 4.2 Calcular Amortización de la Porción Revaluada

**Diferencia clave: Taxes vs. Contabilidad**

#### Tratamiento en TAXES (KPMG)
- La amortización de la porción revaluada se calcula por separado
- Se usa la vida útil remanente del bien
- La depreciación acumulada se ajusta por el coeficiente punta a punta
- El resultado es el valor neto (valor de origen ajustado menos depreciación acumulada ajustada)

#### Tratamiento en CONTABILIDAD (Balance Local)
- **Criterio vigente (desde 2022):** Llevar la amortización a resultados
- **Criterio histórico:** Se imputaba a patrimonio neto
- **Decisión:** Según política contable adoptada por la organización
  - Si se lleva a resultados: afecta el resultado del ejercicio
  - Si se lleva a patrimonio neto: afecta la comparabilidad pero preserva el patrimonio puro

### 4.3 Actualizar Anexo e Histórico de Distribuciones
- **Actualizar:** Incorporar los ajustes anuales al anexo
- **Mantener:** Histórico de distribuciones año a año
- **Área discutida:** La asignación de revalúos a saldos históricos es aún materia de revisión; no quedó resuelta como criterio definitivo en la reunión
- **Recomendación:** Documentar la política elegida y aplicarla de manera consistente año a año

---

## Preguntas Abiertas y Resoluciones

### ¿Por Qué Distribuir el Importe del Informe?
Porque el perito valúa inmuebles o ítems agrupados (una sola línea por edificio), pero SAP registra numerosos activos individuales dentro de cada inmueble. La distribución permite:
- Reconstruir saldos iniciales de cada activo
- Atribuir correctamente los ajustes y amortización a nivel de detalle en SAP
- Mantener trazabilidad en auditoría

### ¿Se Puede Dejar de Hacer el Revalúo?
**Pendiente de resolución.** Se comentó que Deloitte había interpretado que una vez adoptado el criterio, habría que continuarlo. Se propuso volver a analizarlo con Deloitte e IGJ, pero no quedó decidido. **Acción:** Coordinar con asesores externos antes de suspender el revalúo.

### ¿El Informe Debe Separar Mejoras sobre Terrenos y Edificios?
**Pendiente de decisión.** Se planteó solicitar al perito una sola línea consolidada (como se presenta en el anexo), considerando que es principalmente un tema de exposición. Debe coordinarse con el perito. **Acción:** Confirmar formato con el perito antes de enviar el archivo de valuación.

### ¿Cómo Tratar el Terreno Clasificado como "Activo Mantenido para la Venta"?
- **Revisión:** Verificar si aún cumple las condiciones para esa clasificación al cierre
- **Tasación:** Validar la tasación usada como tope de valor
- **Criterio:** Aplicar norma contable vigente para activos no corrientes mantenidos para la venta

---

## Orden de Trabajo Recomendado

1. **Etapa 1:** Cerrar anexo histórico y conciliaciones con SAP (sin avanzar si no se concilia)
2. **Etapa 2:** Aplicar ajuste por inflación a saldos y movimientos
   - Calcular coeficiente punta a punta con todos los decimales
   - Ajustar saldos comparativos iniciales
   - Ajustar altas (por mes de capitalización/posting)
   - Ajustar bajas (por coeficiente punta a punta)
3. **Etapa 3:** Realizar distribuciones del revalúo anterior y construir saldos iniciales distribuidos
4. **Etapa 4:** Preparar y enviar información al perito
5. **Etapa 5:** Validar informe recibido
6. **Etapa 6:** Registrar ajustes y calcular amortización

**Evitar:** Hacer todas las etapas simultáneamente; esto genera inconsistencias y aumenta los errores de conciliación.

---

## Validaciones y Controles Clave

### Control de Altas, Bajas y Traslados

**Alta de activos:**
- Registrar el valor histórico × coeficiente del mes de capitalización (fecha de posting)
- Si es una alta sobre un activo viejo, tomar la fecha de posting actual, no la de la capitalización original

**Baja de activos:**
- Registrar el valor histórico × coeficiente punta a punta
- Si la baja es parcial, prorratear proporcionalmente: si se da baja un 60% en valor histórico, también se da baja ese 60% del valor ajustado
- **Control post-fórmula:** Si valor residual histórico = 0 → AxI debe ser 0. Si no es así, revisar bajas parciales

**Traslados:**
- Movimientos internos entre categorías (ej. de obra en curso a edificio)
- Registrar con signo negativo en origen y positivo en destino
- Valores ajustados se trasladan igual

### Control de Cierre

**Reconciliación SAP:**
- Saldos iniciales AxI + Altas AxI - Bajas AxI + Traslados netos = Saldo final SAP (AxI)
- Debe coincidir exactamente con lo que figura en SAP para cada línea

**Verificación de ceros:**
- Si un bien se dio de alta y baja en el mismo ejercicio, generalmente el neto es cero
  - Excepción: si las fechas de ajuste son distintas (alta en febrero, baja en diciembre)

---

## Notas Operacionales para 2022 en Adelante

### Información de Altas, Bajas y Transferencias
- **Fuente:** Detalle compartido en mail (saldos históricos de SAP al 31-12-2022)
- **Contenido:** Movimientos que afectan el patrimonio de bienes revaluados
- **Datos requeridos para cada movimiento:**
  - Número de activo (código SAP)
  - Valor histórico
  - Fecha de posting (alta/baja/traslado)
  - Tipo de movimiento
  - Centro de costo o almacén destino (para traslados)

### Bienes Excluidos del Revalúo Local
- **Identificación:** Activos que comienzan con "AS******" (IFRS 16 leasing)
- **Razón:** Son asientos técnicos, no bienes físicos reales
- **Tratamiento:** No incluir en revalúo para balance local (impositivo)
- **Nota:** Para IFRS (consolidado), estos activos se pueden tratar de manera diferente según la política de IFRS adoptada

### Revalúo Técnico 2022 y Posteriores
- **Pendiente:** Información de valuación técnica al 31-12-2022
- **Impacto:** Afecta los saldos iniciales distribuidos para el año siguiente
- **Coordinación:** Solicitar al perito con suficiente anticipación
- **Contenido esperado:** Valores por código/ítem, incluyendo separación clara de terrenos, edificios y mejoras

### Roles y Responsabilidades

#### KPMG (Taxes)
- Calcula AxI bajo RT 22 con criterio punta a punta
- Proporciona valuaciones técnicas de inmuebles (perito)
- Define y aplica coeficientes de represión (IPC/IPIM)
- Reporta para declaraciones impositivas

#### Contabilidad (Interna)
- Integra AxI de KPMG en saldos iniciales
- Distribuye valores del informe del perito entre activos SAP
- Registra revalúos contra patrimonio neto o resultados (según política)
- Prepara anexos para estados contables consolidados (IFRS) y locales

---

---

## Propuesta de Automatización

Dada la complejidad y el alto riesgo manual, se recomienda automatizar progresivamente:

1. **Fase 1:** Conciliación automática anexo histórico vs. SAP
2. **Fase 2:** Cálculo automático de ajuste por inflación (parámetros de IPC/IPIM)
   - Calcular coeficiente punta a punta con precisión de decimales
   - Aplicar a saldos comparativos
   - Aplicar por fecha a altas y bajas
3. **Fase 3:** Distribución automática de valores del informe del perito
   - Prorrateo según peso de valor residual
   - Validación de sumas
4. **Fase 4:** Validación automática de totales y coherencia de códigos
5. **Fase 5:** Registro de ajustes y cálculo de amortización revaluada
6. **Fase 6:** Exportación a formatos de KPMG y contabilidad (con sus respectivas diferencias)

El presente motor de cálculos en R (targets) busca implementar estas automatizaciones de forma gradual, manteniendo validaciones manuales en puntos críticos.

---

## Glosario de Términos

- **AxI / Ajuste por Inflación:** Revalorización de activos por cambios en el nivel de precios general de la economía
- **Punta a Punta:** Índice de represión de diciembre año anterior a diciembre año actual
- **Coeficiente de Represión:** Factor multiplicador (índice actual / índice base)
- **Valor de Origen (VO):** Costo histórico del activo
- **Depreciación Acumulada (DA):** Desgaste contabilizado desde la adquisición
- **Valor Residual:** VO - DA (lo que queda de valor neto)
- **Valor Neto AxI:** (VO × coef punta a punta) - (DA × coef punta a punta)
- **Revalúo de Mercado:** Valuación externa por perito independiente (terrenos y edificios)
- **Distribución:** Prorrateo del valor del informe del perito entre activos SAP individuales
- **Baja Total:** El bien desaparece completamente (VO residual = 0)
- **Baja Parcial:** Solo se da baja parte del bien (VO residual > 0)

---

---

## Indicador Global de Automatización

### ¿Qué es?

El **Porcentaje de Automatización** es un indicador que mide la similitud entre los cálculos del motor R y los datos del Excel de KPMG. Un valor de **100% significa concordancia total**, mientras que valores más bajos indican desviaciones que requieren investigación manual.

### Cómo se calcula

El indicador combina tres componentes principales:

#### 1. **Consistencia Interna (20 puntos máximo)**
- Valida que internamente el motor sea lógicamente consistente
- Verifica: `Amort acum = Amort trim × VUT cierre` y `VR = VO − Amort acum` para cada activo
- ✅ Si pasa: +20 puntos
- ❌ Si falla: 0 puntos

#### 2. **Prueba Global por Rubro (40 puntos máximo)**
- Compara saldos calculados (s/prueba) vs. saldos KPMG (s/revalúo) por rubro
- Usa criterios de tolerancia:
  - **Diferencia < $1000:** OK
  - **Diferencia $1000–$10.000:** ADVERTENCIA (tolerancia contable)
  - **Diferencia > $10.000:** ERROR (requiere investigación)
- ✅ Si todas las diferencias son OK: +40 puntos
- ⚠️ Si hay ADVERTENCIA: +20 puntos
- ❌ Si hay ERROR: 0 puntos

#### 3. **Validación Externa (KPMG) — Opcional (40 puntos máximo)**
- Se activa solo si se carga el archivo manual del Excel de KPMG
- Compara diferencias contra tolerancia ±20% de los valores KPMG
- ✅ Si todas las diferencias están dentro de ±20%: +40 puntos
- ⚠️ Si hay diferencias en rango moderado: +20 puntos
- ❌ Si hay diferencias > ±20%: 0 puntos

### Interpretación de rangos

| Rango | Significado | Acción Recomendada |
|-------|-------------|-------------------|
| **95–100%** | Automatización casi completa | Usar resultados del motor con confianza |
| **80–94%** | Automatización buena | Revisar rubros con ADVERTENCIA; OK para usar |
| **60–79%** | Automatización moderada | Investigar ERROR; validar manualmente con KPMG |
| **<60%** | Automatización baja | No usar sin validación manual exhaustiva |

### Ejemplos de cálculo

**Caso 1: Sin archivo KPMG**
- Consistencia interna: ✅ +20
- Prueba global: ⚠️ (ADVERTENCIA) +20
- Externo: N/A
- **Resultado:** (20 + 20 + 0) / 60 = **66.7%** (Automatización moderada)

**Caso 2: Con archivo KPMG y concordancia total**
- Consistencia interna: ✅ +20
- Prueba global: ✅ +40
- Externo: ✅ +40
- **Resultado:** (20 + 40 + 40) / 100 = **100%** (Automatización completa)

### Notas operacionales

- **Tolerancias:** Las ADVERTENCIAS ($1000–$10.000) suelen deberse a redondeo Excel vs. R. Validar manualmente si el patrón es consistente.
- **Archivo KPMG:** Subir el Excel de KPMG en "Validación externa" para obtener el tercer componente. Sin él, máximo alcanzable es ~60%.
- **Revisión post-cálculo:** Incluso con 100%, siempre revisar rubros con ERROR o diferencias atípicas.

---

**Fecha de actualización:** Basado en reunión del motor AXI, mail de procedimientos 2022 e implementación UI v1.0  
**Versión:** 2.1 (integración Taxes vs. Contabilidad, detalles VTT AXI-es-ES, indicador de automatización)  
**Estado:** Documento de referencia; revisar periódicamente con asesores externos (KPMG, auditores)
