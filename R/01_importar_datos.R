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
      "importar_datos() no está implementada aún. Se esperan archivos en: %s",
      paste(unlist(rutas), collapse = ", ")
    ),
    call. = FALSE
  )
}
