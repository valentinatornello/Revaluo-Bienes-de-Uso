ejecutar_validaciones <- function(datos_pg) {
  resultado_axi <- datos_pg$resultado_axi
  prueba_global <- datos_pg$prueba_global

  val_internas <- validar_consistencia_interna(resultado_axi)
  val_pg_amort <- validar_pg_amortizaciones(prueba_global$amortizaciones)
  val_pg_vr <- validar_pg_valor_residual(prueba_global$valor_residual)
  val_vr_formula <- validar_vr_formula(resultado_axi)

  todas <- dplyr::bind_rows(val_internas, val_pg_amort, val_pg_vr, val_vr_formula)

  errores <- todas %>% dplyr::filter(resultado == "ERROR")
  advertencias <- todas %>% dplyr::filter(resultado == "ADVERTENCIA")

  consistente <- nrow(errores) == 0

  datos_pg$validacion <- list(
    consistente = consistente,
    resumen = todas,
    errores = errores,
    advertencias = advertencias,
    detalle = datos_pg
  )

  datos_pg
}

validar_consistencia_interna <- function(resultado_axi) {
  validaciones <- list()
  tolerancia <- 0.01

  for (rubro in names(resultado_axi)) {
    d <- resultado_axi[[rubro]]
    if (nrow(d) == 0) next

    amortizables <- d %>% dplyr::filter(vu_asignada > 0)

    if (nrow(amortizables) > 0) {
      check_amort_acum <- amortizables %>%
        dplyr::mutate(
          diff_amort = abs(amort_acum_cierre - (amort_trimestre * vut_cierre))
        ) %>%
        dplyr::filter(diff_amort > tolerancia)

      if (nrow(check_amort_acum) > 0) {
        validaciones <- append(validaciones, list(tibble::tibble(
          tipo = "consistencia_interna",
          rubro = rubro,
          descripcion = sprintf(
            "Amort acum != amort_trim * vut_cierre en %d activos",
            nrow(check_amort_acum)
          ),
          resultado = "ERROR",
          valor = nrow(check_amort_acum)
        )))
      }
    }

    check_vr <- d %>%
      dplyr::mutate(diff_vr = abs(vr - (vo - amort_acum_cierre))) %>%
      dplyr::filter(diff_vr > tolerancia)

    if (nrow(check_vr) > 0) {
      validaciones <- append(validaciones, list(tibble::tibble(
        tipo = "consistencia_interna",
        rubro = rubro,
        descripcion = sprintf(
          "VR != VO - Amort Acum en %d activos",
          nrow(check_vr)
        ),
        resultado = "ERROR",
        valor = nrow(check_vr)
      )))
    }
  }

  if (length(validaciones) == 0) {
    return(tibble::tibble(
      tipo = "consistencia_interna",
      rubro = "TODOS",
      descripcion = "Todas las consistencias internas pasan OK",
      resultado = "OK",
      valor = 0
    ))
  }

  dplyr::bind_rows(validaciones)
}

validar_pg_amortizaciones <- function(pg_amort) {
  tolerancia_pg <- 1

  errores <- pg_amort %>%
    dplyr::filter(abs(diferencia) > tolerancia_pg)

  if (nrow(errores) > 0) {
    tibble::tibble(
      tipo = "prueba_global_amort",
      rubro = errores$rubro,
      descripcion = sprintf(
        "PG Amort: diferencia = %.4f",
        errores$diferencia
      ),
      resultado = ifelse(abs(errores$diferencia) > 100, "ERROR", "ADVERTENCIA"),
      valor = errores$diferencia
    )
  } else {
    tibble::tibble(
      tipo = "prueba_global_amort",
      rubro = "TODOS",
      descripcion = "PG Amortizaciones cuadra OK",
      resultado = "OK",
      valor = 0
    )
  }
}

validar_pg_valor_residual <- function(pg_vr) {
  tolerancia_pg <- 1

  errores <- pg_vr %>%
    dplyr::filter(abs(diferencia) > tolerancia_pg)

  if (nrow(errores) > 0) {
    tibble::tibble(
      tipo = "prueba_global_vr",
      rubro = errores$rubro,
      descripcion = sprintf(
        "PG VR: diferencia = %.4f",
        errores$diferencia
      ),
      resultado = ifelse(abs(errores$diferencia) > 100, "ERROR", "ADVERTENCIA"),
      valor = errores$diferencia
    )
  } else {
    tibble::tibble(
      tipo = "prueba_global_vr",
      rubro = "TODOS",
      descripcion = "PG Valor Residual cuadra OK",
      resultado = "OK",
      valor = 0
    )
  }
}

validar_vr_formula <- function(resultado_axi) {
  validaciones <- list()
  tolerancia <- 0.01

  for (rubro in names(resultado_axi)) {
    d <- resultado_axi[[rubro]]
    if (nrow(d) == 0) next

    # validamos VR reexpresado para TODOS los activos, no solo post-2018
    reexp <- d %>%
      dplyr::mutate(
        diff_vr_reexp = abs(vr_reexp - (vo_reexp - amort_acum_cierre_reexp))
      ) %>%
      dplyr::filter(diff_vr_reexp > tolerancia)

    if (nrow(reexp) > 0) {
      validaciones <- append(validaciones, list(tibble::tibble(
        tipo = "vr_reexp_formula",
        rubro = rubro,
        descripcion = sprintf(
          "VR Reexp != VO Reexp - Amort Acum Reexp en %d activos",
          nrow(reexp)
        ),
        resultado = "ERROR",
        valor = nrow(reexp)
      )))
    }
  }

  if (length(validaciones) == 0) {
    return(tibble::tibble(
      tipo = "vr_reexp_formula",
      rubro = "TODOS",
      descripcion = "VR Reexpresado consistente en todos los rubros",
      resultado = "OK",
      valor = 0
    ))
  }

  dplyr::bind_rows(validaciones)
}
