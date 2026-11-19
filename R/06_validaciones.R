ejecutar_validaciones <- function(datos_pg, pg_real = NULL, tolerancia_externa = TOLERANCIA_VALIDACION_EXTERNA) {
  resultado_axi <- datos_pg$resultado_axi
  prueba_global <- datos_pg$prueba_global

  val_internas <- validar_consistencia_interna(resultado_axi)
  val_pg_amort <- validar_pg_amortizaciones(prueba_global$amortizaciones)
  val_pg_vr <- validar_pg_valor_residual(prueba_global$valor_residual)
  val_vr_formula <- validar_vr_formula(resultado_axi)
  val_movimientos <- validar_conteos_movimientos(datos_pg$auditoria_movimientos)
  val_bajas_no_id <- validar_bajas_no_identificadas(datos_pg$bajas_no_identificadas)
  val_valores_negativos <- validar_valores_reexpresados_negativos(resultado_axi)
  val_excepciones_fecha <- validar_excepciones_fecha_base(resultado_axi)
  val_contra_real <- validar_contra_real(prueba_global, pg_real, tolerancia_externa)
  val_saldo_inicial <- validar_saldo_inicial(datos_pg$control_saldo_inicial, resultado_axi)
  val_transferencias <- validar_control_transferencias(datos_pg$control_transferencias)
  val_excluidos <- validar_clases_excluidas(datos_pg$excluidos_sap)
  val_ipc <- validar_indices_ipc_redondeados(datos_pg$meses_ipc_redondeados)
  val_vu_rubro <- validar_vu_completada_con_rubro(resultado_axi)

  todas <- dplyr::bind_rows(
    val_internas,
    val_pg_amort,
    val_pg_vr,
    val_vr_formula,
    val_movimientos,
    val_bajas_no_id,
    val_valores_negativos,
    val_excepciones_fecha,
    val_contra_real,
    val_saldo_inicial,
    val_transferencias,
    val_excluidos,
    val_ipc,
    val_vu_rubro
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

    # Las bajas no tienen saldo al cierre (van en columnas *_baja): se controlan aparte
    amortizables <- d %>% dplyr::filter(vu_asignada > 0, tipo_movimiento_calc != "baja")

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
      dplyr::filter(tipo_movimiento_calc != "baja") %>%
      dplyr::mutate(diff_vr = abs(vr - (vo - amort_acum_cierre))) %>%
      dplyr::filter(diff_vr > tolerancia)

    # En una baja, lo que se retira (VO - amortizacion acumulada) tiene que ser el valor residual de la baja
    columnas_baja <- c("vr_baja", "vo_baja", "amort_acum_baja", "vo_cierre")
    check_baja <- d[0, ]
    if (all(columnas_baja %in% names(d))) {
      check_baja <- d %>%
        dplyr::filter(tipo_movimiento_calc == "baja") %>%
        dplyr::mutate(
          diff_baja = abs(vr_baja - (vo_baja - amort_acum_baja)),
          cierre_no_cero = abs(vo_cierre) + abs(amort_acum_cierre) + abs(vr)
        ) %>%
        dplyr::filter(diff_baja > tolerancia | cierre_no_cero > tolerancia)
    }
    if (nrow(check_baja) > 0) {
      validaciones <- append(validaciones, list(tibble::tibble(
        tipo = "consistencia_interna",
        rubro = rubro,
        descripcion = sprintf(
          "Baja con saldo de cierre distinto de cero o VR baja != VO baja - amort baja en %d activos",
          nrow(check_baja)
        ),
        resultado = "ERROR",
        valor = nrow(check_baja)
      )))
    }
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

# OK = replica el Excel (diferencia <= UMBRAL_REPLICA_EXTERNA); ADVERTENCIA = dentro de la tolerancia pero no lo
# replica (la tolerancia del 20% por si sola daba OK a diferencias de millones); ERROR = fuera de la tolerancia
resultado_comparacion <- function(pct, tolerancia_pct) {
  dplyr::case_when(
    pct <= UMBRAL_REPLICA_EXTERNA ~ "OK",
    pct <= tolerancia_pct ~ "ADVERTENCIA",
    TRUE ~ "ERROR"
  )
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
      # rubro sin datos propios (ej. Estructuras y caños, en desuso) y en 0 en la referencia: coinciden
      if (is.na(propio) && !is.na(real) && abs(real) <= TOLERANCIA_CONSISTENCIA_INTERNA) propio <- 0
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
        resultado = resultado_comparacion(pct, tolerancia_pct),
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
      resultado = resultado_comparacion(pct_total, tolerancia_pct),
      valor = pct_total
    )

    dplyr::bind_rows(filas_rubro, fila_total)
  }

  amort_propio <- stats::setNames(prueba_global$amortizaciones$amort_revaluo, prueba_global$amortizaciones$rubro)
  vr_propio <- stats::setNames(prueba_global$valor_residual$vr_revaluo, prueba_global$valor_residual$rubro)
  axi_propio <- stats::setNames(prueba_global$axi$axi_resultado, prueba_global$axi$rubro)

  comparaciones <- list(
    comparar_magnitud("Amortizacion", amort_propio, pg_real$amort_revaluo),
    comparar_magnitud("Valor Residual", vr_propio, pg_real$vr_revaluo),
    comparar_magnitud("AXI", axi_propio, pg_real$axi_resultado)
  )
  if (!is.null(pg_real$amort_reexp_revaluo) && "amort_ejercicio_reexp" %in% names(prueba_global$axi)) {
    amort_reexp_propio <- stats::setNames(prueba_global$axi$amort_ejercicio_reexp, prueba_global$axi$rubro)
    comparaciones <- append(comparaciones, list(
      comparar_magnitud("Amortizacion AXI", amort_reexp_propio, pg_real$amort_reexp_revaluo)
    ))
  }
  dplyr::bind_rows(comparaciones)
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

  if (all(is.na(auditoria_movimientos$conteo_esperado))) {
    return(tibble::tibble(
      tipo = "conteos_movimientos_sap",
      rubro = "TODOS",
      descripcion = "No hay conteos esperados para este ejercicio (CONTEOS_MOVIMIENTOS_ESPERADOS en utils.R); conteo omitido",
      resultado = "ADVERTENCIA",
      valor = NA_real_
    ))
  }

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

# Regla 2: las bajas SAP de activos que no estan en la base (ni son altas del ejercicio) no se calculan; se informan
# para detallarlas al final del rubro con su numero de activo.
validar_bajas_no_identificadas <- function(bajas_no_identificadas) {
  if (is.null(bajas_no_identificadas) || nrow(bajas_no_identificadas) == 0) {
    return(tibble::tibble(
      tipo = "bajas_no_identificadas",
      rubro = "TODOS",
      descripcion = "Todas las bajas SAP se identifican en la base",
      resultado = "OK",
      valor = 0
    ))
  }

  por_rubro <- bajas_no_identificadas %>%
    dplyr::group_by(rubro) %>%
    dplyr::summarise(n = dplyr::n_distinct(nro_activo), valor = sum(abs(valor), na.rm = TRUE), .groups = "drop")

  tibble::tibble(
    tipo = "bajas_no_identificadas",
    rubro = por_rubro$rubro,
    descripcion = sprintf(
      "%d activos dados de baja en SAP no estan en la base ni son altas del ejercicio (valor retirado %.0f): no se calculan",
      por_rubro$n, por_rubro$valor
    ),
    resultado = "ADVERTENCIA",
    valor = por_rubro$n
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

    # Un VO negativo es una reversa o una transferencia de salida (el Excel del estudio tiene esas filas): esta
    # justificado que su VR/VO reexpresado sea negativo. Solo se marca el negativo que NO viene de un VO negativo.
    negativos <- d %>%
      dplyr::filter(
        tipo_movimiento_calc != "transferencia" | is.na(direccion_movimiento) | direccion_movimiento != "salida",
        vo >= 0,
        vo_reexp < -TOLERANCIA_CONSISTENCIA_INTERNA | vr_reexp < -TOLERANCIA_CONSISTENCIA_INTERNA
      )

    if (nrow(negativos) > 0) {
      validaciones <- append(validaciones, list(tibble::tibble(
        tipo = "valores_reexpresados_negativos",
        rubro = rubro,
        descripcion = sprintf("VO/VR reexpresado negativo sin VO negativo en %d activos", nrow(negativos)),
        resultado = "ERROR",
        valor = nrow(negativos)
      )))
    }
  }

  if (length(validaciones) == 0) {
    return(tibble::tibble(
      tipo = "valores_reexpresados_negativos",
      rubro = "TODOS",
      descripcion = "No hay VO/VR reexpresados negativos no justificados (los negativos provienen de VO negativos: reversas y transferencias de salida)",
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

resultado_por_diferencia <- function(diferencia) {
  dplyr::case_when(
    is.na(diferencia) ~ "ADVERTENCIA",
    abs(diferencia) <= TOLERANCIA_PRUEBA_GLOBAL ~ "OK",
    abs(diferencia) <= UMBRAL_ERROR_PRUEBA_GLOBAL ~ "ADVERTENCIA",
    TRUE ~ "ERROR"
  )
}

# Saldo inicial: el VO y la amortizacion acumulada con que arranca el calculo tienen que ser los del cierre anterior,
# por rubro. Se compara contra la fila "Totales" del Excel LY y la amortizacion acumulada que calcula el motor
# (cuota x VUT LY con tope en la VU) contra la columna "Amort. Acum" de cada fila.
validar_saldo_inicial <- function(control_saldo_inicial, resultado_axi) {
  if (is.null(control_saldo_inicial) || nrow(control_saldo_inicial) == 0) {
    return(tibble::tibble(
      tipo = "saldo_inicial", rubro = "TODOS",
      descripcion = "No hay datos del Excel LY para controlar el saldo inicial",
      resultado = "ADVERTENCIA", valor = NA_real_
    ))
  }

  filas <- purrr::map_dfr(seq_len(nrow(control_saldo_inicial)), function(i) {
    ctrl <- control_saldo_inicial[i, ]
    d <- resultado_axi[[ctrl$rubro]]
    amort_motor <- NA_real_
    amort_archivo <- NA_real_
    if (!is.null(d) && "amort_acum_archivo" %in% names(d) && any(!is.na(d$amort_acum_archivo))) {
      amort_motor <- sum(d$amort_acum_ly[!is.na(d$amort_acum_archivo)], na.rm = TRUE)
      amort_archivo <- sum(d$amort_acum_archivo, na.rm = TRUE)
    }
    tibble::tibble(
      rubro = ctrl$rubro,
      magnitud = c("VO", "Amortizacion acumulada"),
      motor = c(ctrl$vo_filas, amort_motor),
      referencia = c(ctrl$vo_totales, amort_archivo),
      diferencia = motor - referencia
    )
  }) %>%
    dplyr::filter(!(is.na(motor) & is.na(referencia)))

  if (nrow(filas) == 0) {
    return(tibble::tibble(
      tipo = "saldo_inicial", rubro = "TODOS",
      descripcion = "El Excel LY no trae fila de totales ni columna de amortizacion acumulada para controlar",
      resultado = "ADVERTENCIA", valor = NA_real_
    ))
  }

  # ERROR solo si la diferencia es material (mas de 0,1% del saldo): los ajustes manuales pegados en el Excel LY
  # (p. ej. amortizacion acumulada de bienes 2006 de MyU) dan diferencias chicas que se informan como advertencia
  filas <- filas %>% dplyr::mutate(resultado = dplyr::case_when(
    is.na(diferencia) ~ "ADVERTENCIA",
    abs(diferencia) <= TOLERANCIA_PRUEBA_GLOBAL ~ "OK",
    abs(diferencia) <= pmax(UMBRAL_ERROR_PRUEBA_GLOBAL, 0.001 * abs(referencia)) ~ "ADVERTENCIA",
    TRUE ~ "ERROR"
  ))
  if (all(filas$resultado == "OK")) {
    return(tibble::tibble(
      tipo = "saldo_inicial", rubro = "TODOS",
      descripcion = "VO y amortizacion acumulada iniciales coinciden con el cierre anterior en todos los rubros",
      resultado = "OK", valor = 0
    ))
  }
  filas <- filas %>% dplyr::filter(resultado != "OK")
  tibble::tibble(
    tipo = "saldo_inicial",
    rubro = filas$rubro,
    descripcion = sprintf("%s inicial: motor=%.2f | cierre anterior=%.2f | dif=%.2f",
                          filas$magnitud, filas$motor, filas$referencia, filas$diferencia),
    resultado = filas$resultado,
    valor = filas$diferencia
  )
}

# Las transferencias netean en cero entre todas las clases, contando las puntas de las clases excluidas
validar_control_transferencias <- function(control_transferencias) {
  if (is.null(control_transferencias) || nrow(control_transferencias) == 0) {
    return(tibble::tibble(
      tipo = "control_transferencias", rubro = "TODOS",
      descripcion = "No hay transferencias SAP para controlar",
      resultado = "ADVERTENCIA", valor = NA_real_
    ))
  }
  tibble::tibble(
    tipo = "control_transferencias",
    rubro = "TODOS",
    descripcion = sprintf(
      "Transferencias SAP: neto de todas las clases = %.2f (incluidas %.2f, excluidas %.2f); tiene que ser 0",
      control_transferencias$neto_todas, control_transferencias$neto_incluidas, control_transferencias$neto_excluidas
    ),
    resultado = resultado_por_diferencia(control_transferencias$neto_todas),
    valor = control_transferencias$neto_todas
  )
}

# Lo que SAP trae y no entra al calculo (obras en curso, IFRS 16, clases sin rubro) se informa por clase.
# Obras en curso e IFRS 16 son exclusiones conocidas; una clase sin rubro es nueva y se avisa.
validar_clases_excluidas <- function(excluidos_sap) {
  if (is.null(excluidos_sap) || nrow(excluidos_sap) == 0) {
    return(tibble::tibble(
      tipo = "clases_excluidas", rubro = "TODOS",
      descripcion = "SAP no trae movimientos de clases excluidas",
      resultado = "OK", valor = 0
    ))
  }
  por_clase <- excluidos_sap %>%
    dplyr::group_by(clase, motivo) %>%
    dplyr::summarise(filas = sum(filas), importe = sum(importe), .groups = "drop")
  tibble::tibble(
    tipo = "clases_excluidas",
    rubro = dplyr::coalesce(por_clase$clase, "(sin clase)"),
    descripcion = sprintf("Excluida del calculo (%s): %d movimientos, importe %.0f",
                          por_clase$motivo, por_clase$filas, por_clase$importe),
    resultado = ifelse(por_clase$motivo == MOTIVO_EXCLUSION_SIN_RUBRO, "ADVERTENCIA", "OK"),
    valor = por_clase$filas
  )
}

# El INDEC publica el IPC con 4 decimales; un indice con 2 o menos esta redondeado y mueve el coeficiente
validar_indices_ipc_redondeados <- function(meses_ipc_redondeados) {
  if (is.null(meses_ipc_redondeados) || length(meses_ipc_redondeados) == 0) {
    return(tibble::tibble(
      tipo = "indices_ipc", rubro = "TODOS",
      descripcion = "Los indices IPC tienen 4 decimales",
      resultado = "OK", valor = 0
    ))
  }
  tibble::tibble(
    tipo = "indices_ipc", rubro = "TODOS",
    descripcion = sprintf(
      paste0("Indice IPC con 2 decimales o menos (posiblemente redondeado) en %s: cargar los valores del INDEC ",
             "en inputs/parametros/indices_ipc_indec.csv"),
      paste(format(meses_ipc_redondeados, "%m/%Y"), collapse = ", ")
    ),
    resultado = "ADVERTENCIA", valor = length(meses_ipc_redondeados)
  )
}

# Un bien con "VU Asignada" vacia en el historico toma la vida util del rubro: se informa cuantos son
validar_vu_completada_con_rubro <- function(resultado_axi) {
  conteo <- purrr::map_dfr(names(resultado_axi), function(rubro) {
    d <- resultado_axi[[rubro]]
    if (!"vu_del_rubro" %in% names(d)) return(tibble::tibble())
    tibble::tibble(rubro = rubro, n = sum(d$vu_del_rubro, na.rm = TRUE))
  })
  conteo <- conteo[conteo$n > 0, ]
  if (nrow(conteo) == 0) {
    return(tibble::tibble(
      tipo = "vu_vacia", rubro = "TODOS",
      descripcion = "Todos los bienes del historico traen su VU Asignada",
      resultado = "OK", valor = 0
    ))
  }
  tibble::tibble(
    tipo = "vu_vacia", rubro = conteo$rubro,
    descripcion = sprintf("%d bienes con VU Asignada vacia en el historico: se uso la vida util del rubro", conteo$n),
    resultado = "ADVERTENCIA", valor = conteo$n
  )
}
