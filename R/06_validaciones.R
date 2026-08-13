ejecutar_validaciones <- function(resultado_pg) {
  # TODO: implementar validaciones automáticas de consistencia.
  consistente <- if (is.null(resultado_pg)) {
    FALSE
  } else if (is.data.frame(resultado_pg)) {
    nrow(resultado_pg) > 0
  } else {
    length(resultado_pg) > 0
  }

  list(
    consistente = consistente,
    detalle = resultado_pg
  )
}
