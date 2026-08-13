importar_datos <- function(inputs_dir = "inputs") {
  list(
    sap = file.path(inputs_dir, "SAP"),
    altas = file.path(inputs_dir, "altas"),
    bajas = file.path(inputs_dir, "bajas"),
    transferencias = file.path(inputs_dir, "transferencias"),
    parametros = file.path(inputs_dir, "parametros")
  )
}
