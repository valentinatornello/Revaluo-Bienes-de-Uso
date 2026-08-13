obtener_rutas_outputs <- function(outputs_dir = "outputs") {
  list(
    reportes = file.path(outputs_dir, "reportes"),
    auditoria = file.path(outputs_dir, "auditoria"),
    excel_final = file.path(outputs_dir, "excel_final")
  )
}

exportar_resultados <- function(resultado, outputs_dir = "outputs") {
  c(
    obtener_rutas_outputs(outputs_dir),
    list(resultado = resultado)
  )
}
