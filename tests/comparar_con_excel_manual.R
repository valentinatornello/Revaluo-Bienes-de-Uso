# Corre el ejercicio contra el Excel manual del estudio y compara fila por fila (VO, VU, VUT, amortizacion, VR y
# reexpresados) y por rubro en la prueba global.
#
# Uso (desde la raiz del proyecto):
#   Rscript tests/comparar_con_excel_manual.R <ejercicio> <Excel LY> <Excel del estudio en .xlsx> <Excel PG y PG AXI>
# Ejemplo 2023:
#   Rscript tests/comparar_con_excel_manual.R 2023 "inputs/parametros/MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC -PARA PROBAR .xlsx" "<ruta>/MARG - Revaluo AxI 2023.xlsx" "inputs/parametros/Excel manual 2023 - PG y PG AXI.xlsx"
# Si el Excel del estudio viene en .xlsb, abrirlo en Excel y guardarlo como "Libro de Excel (*.xlsx)".
# Los criterios de baja se cambian con options(revaluo.baja_edificios = "N"/"S"/"A"/"E") y
# options(revaluo.baja_muebles_amortiza = "S"/"N") antes de correr.
# También es importante saber que se compara lo que el usuario carga en el sistema, 
#el motor compara internamente según las reglas definidas, pero acá solo se valida contra el Excel manual.

suppressMessages(library(tidyverse))
for (f in list.files("R", full.names = TRUE)) source(f)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("Faltan argumentos: ejercicio, Excel LY, Excel del estudio (.xlsx) y Excel PG/PG AXI", call. = FALSE)
anio <- as.integer(args[1])

datos <- importar_datos(args[2], "inputs", anio) %>%
  limpiar_datos(anio) %>%
  construir_rollforward(anio) %>%
  calcular_axi(anio) %>%
  generar_prueba_global(anio)
datos <- ejecutar_validaciones(datos, leer_pg_real(args[4]))

options(width = 200, tibble.width = Inf)
resumen <- datos$validacion$resumen
cmp_pg <- resumen %>% filter(grepl("^comparacion_real", tipo))
cat(sprintf("\nPrueba global vs Excel: %d de %d comparaciones replican (%.1f%%)\n",
            sum(cmp_pg$resultado == "OK"), nrow(cmp_pg), 100 * mean(cmp_pg$resultado == "OK")))
print(cmp_pg %>% filter(resultado != "OK") %>% select(tipo, rubro, resultado, descripcion), n = 50)

cmp <- comparar_filas_con_excel(datos$resultado_axi, args[3])
cat(sprintf("\nFila por fila vs Excel: %d celdas comparadas, %d coinciden (%.3f%%)\n",
            sum(cmp$resumen$filas), sum(cmp$resumen$coinciden), 100 * sum(cmp$resumen$coinciden) / sum(cmp$resumen$filas)))
print(cmp$filas, n = 20)
print(cmp$resumen %>% filter(coinciden < filas) %>% select(rubro, campo, filas, coinciden, dif_total), n = 50)
