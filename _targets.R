library(targets)
tar_option_set(packages = c("tidyverse", "readxl", "openxlsx", "janitor", "lubridate"))

tar_source()

list(
  tar_target(datos_crudos, importar_datos("inputs")),
  tar_target(datos_limpios, limpiar_datos(datos_crudos)),
  tar_target(inventario, construir_rollforward(datos_limpios)),
  tar_target(axi, calcular_axi(inventario)),
  tar_target(prueba_global, generar_prueba_global(axi)),
  tar_target(validacion, ejecutar_validaciones(prueba_global)),
  tar_target(
    resultados_exportados,
    if (isTRUE(validacion$consistente)) {
      exportar_resultados(validacion)
    } else {
      stop("Validación inconsistente: se cancela la exportación.", call. = FALSE)
    }
  )
)
