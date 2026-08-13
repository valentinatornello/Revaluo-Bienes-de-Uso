library(targets)
tar_option_set(packages = c("tidyverse", "readxl", "openxlsx", "janitor", "lubridate"))

tar_source()

list(
  tar_target(datos_crudos, importar_datos("inputs")),
  tar_target(datos_limpios, limpiar_datos(datos_crudos)),
  tar_target(inventario, construir_rollforward(datos_limpios)),
  tar_target(axi, calcular_axi(inventario)),
  tar_target(pg, generar_prueba_global(axi)),
  tar_target(validacion, ejecutar_validaciones(pg)),
  tar_target(export, exportar_resultados(validacion))
)
