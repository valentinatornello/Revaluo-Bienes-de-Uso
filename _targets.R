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
  tar_target(datos_limpios, limpiar_datos(datos_crudos, ANIO_EJERCICIO)),
  tar_target(inventario, construir_rollforward(datos_limpios, ANIO_EJERCICIO)),
  tar_target(axi, calcular_axi(inventario, ANIO_EJERCICIO)),
  tar_target(prueba_global, generar_prueba_global(axi)),
  tar_target(validacion, ejecutar_validaciones(prueba_global)),
  tar_target(
    resultados_exportados,
    if (isTRUE(validacion$validacion$consistente)) {
      exportar_resultados(validacion, "outputs", ANIO_EJERCICIO)
    } else {
      # si hay errores, exportamos solo diagnostico pero NO el excel final
      warning("Validacion con errores. Se exporta solo auditoria, no el revaluo final.")
      exportar_solo_auditoria(validacion, "outputs", ANIO_EJERCICIO)
    }
  )
)
