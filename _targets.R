library(targets)
tar_option_set(packages = c("tidyverse", "readxl", "openxlsx", "janitor", "lubridate"))

tar_source()

ANIO_EJERCICIO <- 2022
PATH_EXCEL_LY <- file.path(
  "inputs", "parametros",
  "MARG - Revaluo AxI 2022_v_28.04.23 IPIM e IPC.xlsx"
)

list(
  tar_target(datos_crudos, importar_datos(PATH_EXCEL_LY, "inputs")),
  tar_target(datos_limpios, limpiar_datos(datos_crudos)),
  tar_target(inventario, construir_rollforward(datos_limpios)),
  tar_target(axi, calcular_axi(inventario)),
  tar_target(prueba_global, generar_prueba_global(axi)),
  tar_target(validacion, ejecutar_validaciones(prueba_global)),
  tar_target(
    resultados_exportados,
    if (isTRUE(validacion$validacion$consistente)) {
      exportar_resultados(validacion, "outputs")
    } else {
      warning("Validacion con errores. Se exporta de todos modos con advertencias.")
      exportar_resultados(validacion, "outputs")
    }
  )
)
