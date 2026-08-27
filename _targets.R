library(targets)
tar_option_set(packages = c("tidyverse", "readxl", "openxlsx", "janitor", "lubridate", "readr"))

tar_source()

ANIO_EJERCICIO <- {
  anio_env <- suppressWarnings(as.integer(Sys.getenv("ANIO_EJERCICIO", unset = "")))
  if (is.na(anio_env)) {
    as.integer(format(Sys.Date(), "%Y")) - 1L
  } else {
    anio_env
  }
}
PATH_EXCEL_LY <- file.path(
  "inputs", "parametros",
  sprintf("MARG - Revaluo AxI %d_v_28.04.23 IPIM e IPC.xlsx", ANIO_EJERCICIO)
)

list(
  tar_target(datos_crudos, importar_datos(PATH_EXCEL_LY, "inputs")),
  tar_target(datos_limpios, limpiar_datos(datos_crudos, ANIO_EJERCICIO)),
  tar_target(inventario, construir_rollforward(datos_limpios, ANIO_EJERCICIO)),
  tar_target(axi, calcular_axi(inventario, ANIO_EJERCICIO)),
  tar_target(prueba_global, generar_prueba_global(axi, ANIO_EJERCICIO)),
  tar_target(pg_real, {
    path_real <- buscar_archivo_real(ANIO_EJERCICIO)
    if (!is.na(path_real)) leer_pg_real(path_real) else NULL
  }),
  tar_target(validacion, ejecutar_validaciones(prueba_global, pg_real)),
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
