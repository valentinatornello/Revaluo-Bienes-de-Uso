ejecutar_validaciones <- function(datos_pg, pg_real = NULL, tolerancia_externa = TOLERANCIA_VALIDACION_EXTERNA) {
  resultado_axi <- datos_pg$resultado_axi
  prueba_global <- datos_pg$prueba_global

  val_internas <- validar_consistencia_interna(resultado_axi)
  val_pg_amort <- validar_pg_amortizaciones(prueba_global$amortizaciones)
  val_pg_vr <- validar_pg_valor_residual(prueba_global$valor_residual)
  val_vr_formula <- validar_vr_formula(resultado_axi)
  val_movimientos <- validar_conteos_movimientos(datos_pg$auditoria_movimientos)
  val_valores_negativos <- validar_valores_reexpresados_negativos(resultado_axi)
  val_excepciones_fecha <- validar_excepciones_fecha_base(resultado_axi)
  val_contra_real <- validar_contra_real(prueba_global, pg_real, tolerancia_externa)

  todas <- dplyr::bind_rows(
    val_internas,
    val_pg_amort,
    val_pg_vr,
    val_vr_formula,
    val_movimientos,
    val_valores_negativos,
    val_excepciones_fecha,
    val_contra_real
  )

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
  tolerancia <- TOLERANCIA_CONSISTENCIA_INTERNA

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
  tolerancia_pg <- TOLERANCIA_PRUEBA_GLOBAL

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
      resultado = ifelse(abs(errores$diferencia) > UMBRAL_ERROR_PRUEBA_GLOBAL, "ERROR", "ADVERTENCIA"),
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
  tolerancia_pg <- TOLERANCIA_PRUEBA_GLOBAL

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
      resultado = ifelse(abs(errores$diferencia) > UMBRAL_ERROR_PRUEBA_GLOBAL, "ERROR", "ADVERTENCIA"),
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

validar_contra_real <- function(prueba_global, pg_real, tolerancia_pct = TOLERANCIA_VALIDACION_EXTERNA) {
  if (is.null(pg_real)) {
    return(tibble::tibble(
      tipo = "comparacion_real",
      rubro = "TODOS",
      descripcion = "No se proporciono archivo real (Price/KPMG) para comparar; validacion externa omitida",
      resultado = "ADVERTENCIA",
      valor = NA_real_
    ))
  }

  obtener_valor <- function(valores, nombre) {
    if (nombre %in% names(valores)) valores[[nombre]] else NA_real_
  }

  comparar_magnitud <- function(nombre_magnitud, propio_named, real_named) {
    rubros <- names(real_named)

    filas_rubro <- purrr::map_dfr(rubros, function(r) {
      propio <- obtener_valor(propio_named, r)
      real <- obtener_valor(real_named, r)
      diferencia <- propio - real

      if (is.na(propio) || is.na(real)) {
        return(tibble::tibble(
          tipo = paste0("comparacion_real_", nombre_magnitud),
          rubro = r,
          descripcion = sprintf(
            "%s [%s]: sin datos suficientes para comparar (propio=%s, Price=%s)",
            nombre_magnitud, r,
            ifelse(is.na(propio), "NA", sprintf("%.0f", propio)),
            ifelse(is.na(real), "NA", sprintf("%.0f", real))
          ),
          resultado = "ADVERTENCIA",
          valor = NA_real_
        ))
      }

      pct <- if (abs(real) > TOLERANCIA_CONSISTENCIA_INTERNA) {
        abs(diferencia) / abs(real)
      } else if (abs(diferencia) <= TOLERANCIA_CONSISTENCIA_INTERNA) {
        0
      } else {
        1
      }

      tibble::tibble(
        tipo = paste0("comparacion_real_", nombre_magnitud),
        rubro = r,
        descripcion = sprintf(
          "%s [%s]: propio=%.0f | Price=%.0f | dif=%.0f | %.1f%% de diferencia (tolerancia %.0f%%, %.1f%% de igualdad)",
          nombre_magnitud, r, propio, real, diferencia, pct * 100, tolerancia_pct * 100, (1 - pct) * 100
        ),
        resultado = ifelse(pct <= tolerancia_pct, "OK", "ERROR"),
        valor = pct
      )
    })

    propio_total <- sum(propio_named[rubros], na.rm = TRUE)
    real_total <- sum(real_named, na.rm = TRUE)
    diferencia_total <- propio_total - real_total
    pct_total <- if (abs(real_total) > TOLERANCIA_CONSISTENCIA_INTERNA) {
      abs(diferencia_total) / abs(real_total)
    } else if (abs(diferencia_total) <= TOLERANCIA_CONSISTENCIA_INTERNA) {
      0
    } else {
      1
    }

    fila_total <- tibble::tibble(
      tipo = paste0("comparacion_real_", nombre_magnitud),
      rubro = "TOTAL",
      descripcion = sprintf(
        "%s [TOTAL]: propio=%.0f | Price=%.0f | dif=%.0f | %.1f%% de diferencia (tolerancia %.0f%%, %.1f%% de igualdad)",
        nombre_magnitud, propio_total, real_total, diferencia_total, pct_total * 100, tolerancia_pct * 100, (1 - pct_total) * 100
      ),
      resultado = ifelse(pct_total <= tolerancia_pct, "OK", "ERROR"),
      valor = pct_total
    )

    dplyr::bind_rows(filas_rubro, fila_total)
  }

  amort_propio <- stats::setNames(prueba_global$amortizaciones$amort_revaluo, prueba_global$amortizaciones$rubro)
  vr_propio <- stats::setNames(prueba_global$valor_residual$vr_revaluo, prueba_global$valor_residual$rubro)
  axi_propio <- stats::setNames(prueba_global$axi$axi_resultado, prueba_global$axi$rubro)

  dplyr::bind_rows(
    comparar_magnitud("Amortizacion", amort_propio, pg_real$amort_revaluo),
    comparar_magnitud("Valor Residual", vr_propio, pg_real$vr_revaluo),
    comparar_magnitud("AXI", axi_propio, pg_real$axi_resultado)
  )
}

validar_vr_formula <- function(resultado_axi) {
  validaciones <- list()
  tolerancia <- TOLERANCIA_CONSISTENCIA_INTERNA

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

validar_conteos_movimientos <- function(auditoria_movimientos) {
  if (is.null(auditoria_movimientos) || nrow(auditoria_movimientos) == 0) {
    return(tibble::tibble(
      tipo = "conteos_movimientos_sap",
      rubro = "TODOS",
      descripcion = "No hay auditoria de movimientos SAP para validar conteos",
      resultado = "ADVERTENCIA",
      valor = NA_real_
    ))
  }

  diferencias <- auditoria_movimientos %>%
    dplyr::filter(!is.na(conteo_esperado), diferencia_conteo != 0)

  if (nrow(diferencias) == 0) {
    return(tibble::tibble(
      tipo = "conteos_movimientos_sap",
      rubro = "TODOS",
      descripcion = "Conteos de movimientos SAP coinciden con el detalle esperado",
      resultado = "OK",
      valor = 0
    ))
  }

  tibble::tibble(
    tipo = "conteos_movimientos_sap",
    rubro = diferencias$tipo_movimiento_sap,
    descripcion = sprintf(
      "Conteo detalle SAP observado %d vs esperado %d",
      diferencias$filas_detalle,
      diferencias$conteo_esperado
    ),
    resultado = "ERROR",
    valor = diferencias$diferencia_conteo
  )
}

validar_valores_reexpresados_negativos <- function(resultado_axi) {
  validaciones <- list()

  for (rubro in names(resultado_axi)) {
    d <- resultado_axi[[rubro]]
    if (nrow(d) == 0) next

    if (!"direccion_movimiento" %in% names(d)) {
      d$direccion_movimiento <- NA_character_
    }

    negativos <- d %>%
      dplyr::filter(
        tipo_movimiento_calc != "transferencia" | is.na(direccion_movimiento) | direccion_movimiento != "salida",
        vo_reexp < 0 | vr_reexp < 0
      )

    if (nrow(negativos) > 0) {
      validaciones <- append(validaciones, list(tibble::tibble(
        tipo = "valores_reexpresados_negativos",
        rubro = rubro,
        descripcion = sprintf("VO/VR reexpresado negativo en %d activos", nrow(negativos)),
        resultado = "ERROR",
        valor = nrow(negativos)
      )))
    }
  }

  if (length(validaciones) == 0) {
    return(tibble::tibble(
      tipo = "valores_reexpresados_negativos",
      rubro = "TODOS",
      descripcion = "No hay VO/VR reexpresados negativos no justificados",
      resultado = "OK",
      valor = 0
    ))
  }

  dplyr::bind_rows(validaciones)
}

validar_excepciones_fecha_base <- function(resultado_axi) {
  aplicadas <- purrr::map_dfr(names(resultado_axi), function(rubro) {
    d <- resultado_axi[[rubro]]
    if (!"regla_fecha_base_aplicada" %in% names(d)) return(tibble::tibble())

    d %>%
      dplyr::filter(regla_fecha_base_aplicada) %>%
      dplyr::summarise(valor = dplyr::n(), .groups = "drop") %>%
      dplyr::filter(valor > 0) %>%
      dplyr::mutate(rubro = rubro)
  })

  if (nrow(aplicadas) == 0) {
    return(tibble::tibble(
      tipo = "excepciones_fecha_base",
      rubro = "TODOS",
      descripcion = "No se aplicaron excepciones de fecha base",
      resultado = "OK",
      valor = 0
    ))
  }

  tibble::tibble(
    tipo = "excepciones_fecha_base",
    rubro = aplicadas$rubro,
    descripcion = sprintf("Excepciones de fecha base aplicadas en %d activos", aplicadas$valor),
    resultado = "OK",
    valor = aplicadas$valor
  )
}
