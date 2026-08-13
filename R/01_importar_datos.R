obtener_rutas_inputs <- function(inputs_dir = "inputs") {
  list(
    sap = file.path(inputs_dir, "SAP"),
    altas = file.path(inputs_dir, "altas"),
    bajas = file.path(inputs_dir, "bajas"),
    transferencias = file.path(inputs_dir, "transferencias"),
    parametros = file.path(inputs_dir, "parametros")
  )
}

importar_datos <- function(inputs_dir = "inputs") {
  # TODO: implementar lectura y consolidación de archivos de entrada.
  rutas <- obtener_rutas_inputs(inputs_dir)
  stop(
    sprintf(
      "TODO: implementar importar_datos() para leer estas rutas: %s",
      paste(names(rutas), collapse = ", ")
    ),
    call. = FALSE
  )
}
