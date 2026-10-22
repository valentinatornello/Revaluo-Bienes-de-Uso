# T0.7 — Preguntas Abiertas

Cada pregunta tiene un código (PA-##) para referencia cruzada con los demás documentos.

> **Actualización Fase 0.5 (2026-10-21):** Preguntas PA-01, PA-02, PA-04, PA-06 marcadas como RESUELTAS. Se agrega PA-16 (bajas de muebles).

---

## Preguntas RESUELTAS

### PA-01 — ~~Coeficiente de reexpresión para bienes pre-2018~~ **RESUELTA**

**Resolución (criterio normativo Ley de Ganancias):** Coeficiente = 1 por defecto para bienes anteriores a 01/01/2018. Solo bienes desde 2018 se actualizan con IPC (Ley 27.430/27.468). El R debe implementar un switch de escenario: escenario A (base) = coef 1; escenario B (opcional) = IPIM para confiscatoriedad.

---

### PA-02 — ~~Fecha ajustada pre-1992~~ **RESUELTA**

**Resolución:** Corte automático a 01/01/1992. Bienes con fecha de alta anterior a 1992 se tratan como alta al 01/01/1992 para VUT y coeficiente. El estudio confirma: "Con respecto a los bienes con fecha de alta menor a 12/1992, ya se encontraban reexpresados a Marzo de 1992. Se tomo como año Base para realizar el calculo de AXI. Se actualizan a partir de Abril 1992."

---

### PA-04 — ~~Prorrateo del primer año para muebles~~ **RESUELTA**

**Resolución:** Año de alta = año completo para bienes muebles (Ley de Ganancias). El R lo implementa correctamente (`trim_primer_anio = 1` para no-Edificios). El estudio confirma: todas las instrucciones dicen "sumarle 1 año a la columna de VUT". B-06 reclasificada como criterio correcto.

---

### PA-06 — ~~Amortización transferida~~ **RESUELTA**

**Resolución:** Mover VO y amortización acumulada juntos (usar `transf_dep` del SAP). La fecha de alta del bien original se conserva (cap_date).

---

### PA-11b — ~~Rodados, neteo, clases fuera de tabla, unidades~~ **RESUELTA**

**Resolución:**
- Rodados: 5 años, VUT en años enteros.
- Altas y bajas del mismo año: se netean.
- Clases fuera de la tabla de rubros: no se calculan pero se reportan en una hoja aparte.
- Unidades: Edificios en trimestres (200 trim = 50 años), resto en años enteros (criterio normativo).

---

## Preguntas sobre criterios de cálculo (abiertas)

---

### PA-02 — Fecha ajustada pre-1992: ¿implementar el corte automático?

**Contexto:** El spec (sección 4.3) define `FAJ = SI(año(FA) < 1992; 01/01/1992; FA)`. El código R no implementa este ajuste automático. Solo hay un mecanismo de excepciones manuales por CSV (`utils.R:119-156`).

**Pregunta:**
1. ¿Hay bienes con fecha de alta anterior a 1992 en la base actual?
2. Si los hay: ¿se debe implementar el corte automático a 01/01/1992, o las excepciones manuales son suficientes?
3. El corte afecta tanto la VUT como el coeficiente. ¿Se aplica a ambos o solo al coeficiente?

**Impacto:** Afecta VUT y coeficientes de bienes pre-1992.

**Referencia:** Brecha B-02.

---

### PA-03 — Bajas parciales: ¿cómo se tratan?

**Contexto:** El código R filtra las bajas a solo aquellas con `abs(ret_book_value) < 0.01` (`01_importar_datos.R:352`). El comentario dice: "PENDIENTE: consultar con Pablo".

**Pregunta:**
1. ¿Qué hacer con las bajas donde `ret_book_value != 0`?
2. ¿Se tratan de forma proporcional (baja parcial del VO y la amortización)?
3. ¿O se ignoran hasta que el bien esté totalmente depreciado?
4. ¿Cuántas bajas con `ret_book_value != 0` hay en 2023? ¿Son significativas en monto?

**Impacto:** Puede excluir bajas relevantes del cálculo.

**Referencia:** Brecha B-03.

---

### PA-04 — Prorrateo del primer año para Rodados y otros rubros no-Edificios

**Contexto:** El código R (`04_calculo_axi.R:60-64`) asigna `trim_primer_anio = 1` para todos los rubros excepto Edificios. Esto significa que un Rodado dado de alta en diciembre computa 1 año completo de amortización.

El spec (sección 4.6) marca [A CONFIRMAR] cómo se cuenta el año de alta para Rodados.

**Pregunta:**
1. ¿El estudio prorratea el primer año de Rodados por mes o siempre cuenta 1 año completo?
2. ¿Y para los demás rubros no-Edificios (Software, Eq Oficina, MyU, etc.)?
3. Si hay prorrateo: ¿por trimestre (`ceil(mes/3)/4`) o por mes (`mes/12`)?

**Impacto:** Afecta la amortización del año de alta y la VUT de todos los rubros excepto Edificios.

**Referencia:** Brecha B-06.

---

### PA-05 — Tablas de índices separadas para bajas

**Contexto:** El código R lee 4 tablas de índices del Excel LY (`01_importar_datos.R:129-183`):
- `IPC` / `IPIM` — normales
- `IPC - VR Bajas` / `IPIM - VR Bajas` — para bajas

**Pregunta:**
1. ¿Cuál es la diferencia entre los índices normales y los de bajas? ¿Fecha de corte diferente?
2. ¿El estudio usa índices separados para las bajas o los mismos?
3. ¿Se deben usar los índices de bajas además de los normales (como hace el R) o en reemplazo?

**Impacto:** Afecta la reexpresión de todos los bienes dados de baja.

**Referencia:** Brecha B-05.

---

### PA-06 — Amortización transferida: ¿recalcular o trasladar?

**Contexto:** El spec (sección 4.15) dice "se trasladan VO y AA juntos del activo origen al destino". El código R lee `transf_dep` (amortización transferida) pero no la usa en el cálculo (`01_importar_datos.R:370-371`); recalcula AA desde cero usando `cap_date_parsed`.

**Pregunta:**
1. ¿La amortización del activo transferido debe ser la transferida desde SAP, o se recalcula?
2. Si se recalcula: ¿la fecha de alta del bien transferido es la fecha original (cap_date)?
3. ¿Qué pasa si el rubro de origen y destino tienen VU diferentes?
4. ¿Se mantiene la fecha de alta del bien original (para el coeficiente)?

**Impacto:** Diferencia en la amortización acumulada de activos transferidos.

**Referencia:** Brecha B-08.

---

### PA-07 — Bajas: ¿se amortizan en el año de baja?

**Contexto:** El spec (sección 4.14) pregunta [A CONFIRMAR]: "¿Se amortiza el año de la baja? ¿Hasta qué trimestre?"

En el código R (`04_calculo_axi.R:60-69`), las bajas de Edificios tienen `periodos_hasta_baja` = trimestre de la fecha de baja. Para no-Edificios, `periodos_hasta_baja = 1` (año completo).

Además, los valores de bajas que vienen del LY se congelan al inicio del ejercicio (`reglas_negocio.md:39`: "se pegan como valores para mantener los datos a inicio del ejercicio").

**Pregunta:**
1. ¿Es correcto que las bajas de no-Edificios amorticen el año completo de la baja?
2. ¿O deberían amortizar solo hasta el trimestre de la baja (como Edificios)?
3. Para las bajas que vienen del LY (ya clasificadas): ¿los valores están congelados al inicio o al cierre?

**Impacto:** Afecta la amortización del ejercicio de bienes dados de baja.

---

### PA-08 — Fecha de índice para bajas SAP

**Contexto:** En `normalizar_baja_sap()` (`03_construir_rollforward.R:151`), `fecha_alta = bajas$posting_date` (fecha de la baja). Luego `aplicar_excepciones_fecha_base()` setea `fecha_indice_reexp = fecha_alta`. Esto hace que el coeficiente se busque por la fecha de la **baja**, no por la fecha original del bien.

Sin embargo, `anio_alta` y `mes_alta` sí vienen de `cap_date_parsed` (fecha original), que es lo correcto para la VUT.

**Pregunta:**
1. ¿El coeficiente de reexpresión de una baja debe buscarse por la fecha original del bien o por la fecha de la baja?
2. ¿Es intencional que `fecha_alta` y `anio_alta/mes_alta` apunten a fechas diferentes en las bajas?

**Impacto:** Puede cambiar significativamente el coeficiente aplicado a las bajas.

---

### PA-16 — Amortización en año de baja para bienes muebles (NUEVA — Fase 0.5)

**Contexto:** La Ley de Ganancias indica que para bienes muebles, el año de baja = sin amortización. El código R (`04_calculo_axi.R:65-66`) asigna `periodos_hasta_baja = 1` para no-Edificios, computando 1 año completo de amortización en el año de baja.

Sin embargo, la hoja PG del estudio 2023 muestra "Amortización de las bajas" con valores no-cero, lo que sugiere que el estudio también calcula alguna amortización para bienes dados de baja.

**Pregunta:**
1. ¿El estudio sigue la norma estricta (0 amortización en año de baja para muebles)?
2. ¿O el estudio calcula la amortización del año de baja y luego la retira junto con la acumulada?
3. Para Edificios: el R calcula hasta el trimestre de la baja. ¿Es correcto según la norma?

**Impacto:** Afecta la amortización del ejercicio y la PG para todos los bienes dados de baja en el año.

---

## Preguntas sobre datos

### PA-09 — Diferencia entre "Año Archivo", "Año a Tomar" y "Año Alta"

**Contexto:** El spec (sección 4.3) señala que en el estudio (Edificios, columnas 5-7) existen tres columnas de fecha. El código R prioriza "Año a Tomar" si existe; si no, usa "Año Archivo" (`02_limpiar_datos.R:61-66`).

**Pregunta:**
1. ¿Cuál es la diferencia conceptual entre las tres?
2. ¿Cuál es la correcta para el cálculo de VUT y del coeficiente?
3. ¿Varía según el rubro?

---

### PA-10 — Columna 4 de la tabla IPC: ¿cómo se construye?

**Contexto:** El spec (sección 4.12) dice [A CONFIRMAR]: "Documentar cómo se construye la columna 4 (IPC de cierre / IPC del mes de alta u otra fórmula), qué índice base usa y qué pasa si la fecha no está en la tabla."

El código R toma directamente `coeficiente` de la columna 4 (`01_importar_datos.R:133,148`), sin calcularlo.

**Pregunta:**
1. ¿La columna 4 es `IPC_cierre / IPC_periodo`?
2. ¿Qué pasa si la fecha de alta no tiene un registro exacto en la tabla? El R toma la fecha anterior más cercana (`utils.R:188-189`), ¿es correcto?
3. ¿El índice base es el mismo para todos los años o cambia?

---

### PA-11 — Insumos faltantes del spec

**Contexto:** El spec (sección 2) lista insumos que no se encontraron en el repositorio:

| Insumo del spec | Estado |
|---|---|
| `MARG-Revaluo-2023.xlsx` (modelo del estudio externo 2023) | Se encontró `MARG - Revalúo AxI 2023_VF pruebas.xlsx` en `inputs/parametros/` — verificar si es el correcto |
| `Libro1.xlsx` (reconstrucción parcial interna) | No encontrado |
| `Reglas-Revaluo.xlsx` / `Presentacion.xlsx` | No encontrado |
| `ipc_table.json` (2.191 registros diarios) | No encontrado como archivo JSON independiente. Los índices se leen de las hojas del Excel LY |

**Pregunta:**
1. ¿El archivo `MARG - Revalúo AxI 2023_VF pruebas.xlsx` es el modelo del estudio 2023 referido en el spec?
2. ¿Se necesitan `Libro1.xlsx` y `Reglas-Revaluo.xlsx` para la Fase 0, o la información ya está capturada en el código?
3. ¿El `ipc_table.json` del spec es un archivo separado o son las hojas IPC del Excel?

---

### PA-12 — Conteos esperados de movimientos: ¿de qué año son?

**Contexto:** `CONTEOS_MOVIMIENTOS_ESPERADOS` (`utils.R:44-49`) lista:
- Altas: 4.873
- Bajas: 1.717
- Transferencias: 1.738

El spec (sección 2) menciona: 4.876 altas, 4.045 bajas, 1.743 transferencias.

**Pregunta:**
1. ¿Los conteos del código son del ejercicio 2022 y los del spec del 2023?
2. Las bajas del código (1.717) difieren mucho de las del spec (4.045). ¿La diferencia se debe al filtro de `ret_book_value ≈ 0`?
3. ¿Estos conteos deben actualizarse cada año o eliminarse como validación?

---

## Preguntas sobre la arquitectura futura

### PA-13 — Consistencia entre la tabla de rubros y el código

**Contexto:** `PARAMETROS_RUBROS` declara `indice = "IPC"` para todos los rubros (`utils.R:29-39`), pero el código aplica IPIM para bienes pre-2018. La columna `indice` de la tabla no se usa en ningún cálculo.

**Pregunta:**
1. ¿Se debería usar esta columna para parametrizar IPC vs IPIM?
2. ¿O el criterio siempre depende del año de alta, no del rubro?

---

### PA-14 — VU de Edificios: ¿trimestres o años en el Excel del LY?

**Contexto:** El código para Edificios toma `vu_asignada` tal cual del LY (`02_limpiar_datos.R:91`: `if (rubro == "Edificios") vu_archivo else vu_archivo / 4`). Esto asume que Edificios ya viene en trimestres en el Excel.

**Pregunta:**
1. ¿El Excel del estudio trae VU de Edificios en trimestres (200) o en años (50)?
2. Si el Excel trae años, la conversión actual sería incorrecta (se debería multiplicar por 4, no tomar tal cual).

---

### PA-15 — Redondeo

**Contexto:** El spec (formato 3.2) pide documentar si hay redondeo y en qué paso. El código R no aplica redondeo explícito en ningún punto del cálculo.

**Pregunta:**
1. ¿El estudio redondea valores intermedios (ej: cuota, amort acumulada)?
2. ¿El Excel del estudio usa precisión de celda o fórmulas con ROUND?
3. Las diferencias de centavos en la PG: ¿se atribuyen a redondeo del estudio o del R?
