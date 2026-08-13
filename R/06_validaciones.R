ejecutar_validaciones <- function(resultado_pg) {
  list(
    consistente = !is.null(resultado_pg),
    detalle = resultado_pg
  )
}
