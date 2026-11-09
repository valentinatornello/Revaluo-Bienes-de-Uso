library(targets)
tar_option_set(packages = c("tidyverse", "readxl", "openxlsx", "janitor", "lubridate", "readr"))

tar_source()

# "excel" replica el Excel manual (anios fuera de Edificios); "ricardo" lleva el resto a trimestres salvo Rodados.
# Al cambiarlo hay que invalidar el pipeline (targets::tar_invalidate(everything())).
options(revaluo.criterio_unidad_vu = Sys.getenv("CRITERIO_UNIDAD_VU", unset = "excel"))

ANIO_EJERCICIO <- {
  anio_env <- suppressWarnings(as.integer(Sys.getenv("ANIO_EJERCICIO", unset = "")))
  if (is.na(anio_env)) {
    as.integer(format(Sys.Date(), "%Y")) - 1L
  } else {
    anio_env
  }
}
# Excel base: el del ejercicio si existe (ya trae sus movimientos); si no, el del ejercicio anterior
# (ej. 2023 parte del cierre 2022 y suma los movimientos SAP 2023).
PATH_EXCEL_LY <- {
  ruta_excel <- function(anio) {
    file.path("inputs", "parametros", sprintf("MARG - Revaluo AxI %d_v_28.04.23 IPIM e IPC.xlsx", anio))
  }
  if (file.exists(ruta_excel(ANIO_EJERCICIO))) ruta_excel(ANIO_EJERCICIO) else ruta_excel(ANIO_EJERCICIO - 1L)
}

list(
  tar_target(datos_crudos, importar_datos(PATH_EXCEL_LY, "inputs", ANIO_EJERCICIO)),
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
