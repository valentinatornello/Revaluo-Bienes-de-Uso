calcular_axi <- function(datos_rollforward, anio_ejercicio = 2022) {
  inventario <- datos_rollforward$inventario
  indices_ipc <- datos_rollforward$indices_ipc
  indices_ipim <- datos_rollforward$indices_ipim
  indices_ipc_bajas <- datos_rollforward$indices_ipc_bajas
  indices_ipim_bajas <- datos_rollforward$indices_ipim_bajas

  resultado <- list()

  for (rubro_nombre in names(inventario)) {
    inv <- inventario[[rubro_nombre]]
    if (is.null(inv) || nrow(inv) == 0) next

    if (es_terreno(rubro_nombre)) {
      inv <- calcular_terrenos(inv, indices_ipc, indices_ipim, anio_ejercicio)
    } else {
      inv <- calcular_rubro_amortizable(
        inv, indices_ipc, indices_ipim,
        indices_ipc_bajas, indices_ipim_bajas,
        anio_ejercicio
      )
    }

    resultado[[rubro_nombre]] <- inv
  }

  datos_rollforward$resultado_axi <- resultado
  datos_rollforward
}

calcular_rubro_amortizable <- function(inv, indices_ipc, indices_ipim,
                                        indices_ipc_bajas, indices_ipim_bajas,
                                        anio_ejercicio) {
  inv <- inv %>%
    dplyr::mutate(
      vo = tidyr::replace_na(vo, 0),
      vu_asignada = tidyr::replace_na(vu_asignada, 0),
      anio_alta = tidyr::replace_na(anio_alta, anio_ejercicio),
      mes_alta = tidyr::replace_na(mes_alta, 1)
    )

  inv <- inv %>%
    dplyr::mutate(
      trim_primer_anio = calcular_trimestres_primer_anio(mes_alta),

      vut_ly = dplyr::if_else(
        !is.na(vut_ly),
        vut_ly,
        calcular_vut_ly(anio_alta, mes_alta, anio_ejercicio, vu_asignada)
      ),

      vut_ejercicio = calcular_vut_ejercicio(
        anio_alta, mes_alta, anio_ejercicio, vu_asignada, vut_ly
      ),

      vut_cierre = pmin(vut_ly + vut_ejercicio, vu_asignada),

      vu_restante = pmax(vu_asignada - vut_cierre, 0),

      amort_trimestre = dplyr::if_else(
        vu_asignada > 0,
        vo / vu_asignada,
        0
      ),

      amort_hist_ejercicio = dplyr::if_else(
        vut_ly < vu_asignada,
        amort_trimestre * vut_ejercicio,
        0
      ),

      amort_hist_2018 = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        amort_hist_ejercicio,
        0
      ),

      amort_acum_cierre = dplyr::if_else(
        vu_asignada > 0,
        amort_trimestre * vut_cierre,
        0
      ),

      amort_acum_ly = dplyr::if_else(
        vu_asignada > 0,
        amort_trimestre * vut_ly,
        0
      ),

      vr = vo - amort_acum_cierre,

      vr_ly = vo - amort_acum_ly
    )

  inv <- inv %>%
    dplyr::mutate(
      coef_ipc = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        buscar_coeficiente(fecha_alta, indices_ipc),
        1
      ),

      coef_ipim = buscar_coeficiente(fecha_alta, indices_ipim),

      vo_reexp = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        vo * coef_ipc,
        vo * coef_ipim
      ),

      amort_hist_reexp = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        amort_hist_2018 * coef_ipc,
        0
      ),

      amort_acum_ly_reexp = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        amort_acum_ly * coef_ipc,
        amort_acum_ly * coef_ipim
      ),

      amort_acum_cierre_reexp = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        amort_acum_cierre * coef_ipc,
        amort_acum_cierre * coef_ipim
      ),

      vr_reexp = vo_reexp - amort_acum_cierre_reexp
    )

  inv <- inv %>%
    dplyr::mutate(
      es_vu_agotada_ly = (vut_ly >= vu_asignada & vu_asignada > 0),

      # para bienes que agotaron la VU en el ejercicio anterior, calculamos el
      # ajuste como la amortizacion que se habria devengado si la VU no estuviera
      # agotada (o sea, el trimestre normal que no se computa)
      amort_bs_agotaron_vu_ly = dplyr::if_else(
        es_vu_agotada_ly,
        -amort_trimestre * dplyr::if_else(
          anio_alta == anio_ejercicio,
          calcular_trimestres_primer_anio(mes_alta),
          pmin(4, vu_asignada - vut_ly + 4)
        ),
        0
      )
    )

  inv <- calcular_bajas_reexp(inv, indices_ipc_bajas, indices_ipim_bajas)

  inv
}

calcular_terrenos <- function(inv, indices_ipc, indices_ipim, anio_ejercicio) {
  inv <- inv %>%
    dplyr::mutate(
      vo = tidyr::replace_na(vo, 0),
      vu_asignada = 0,
      amort_trimestre = 0,
      amort_hist_ejercicio = 0,
      amort_hist_2018 = 0,
      amort_acum_cierre = 0,
      amort_acum_ly = 0,
      vr = vo,
      vr_ly = vo,
      vut_ly = 0,
      vut_ejercicio = 0,
      vut_cierre = 0,
      vu_restante = 0,
      trim_primer_anio = 0,
      es_vu_agotada_ly = FALSE,
      amort_bs_agotaron_vu_ly = 0,

      coef_ipc = buscar_coeficiente(fecha_alta, indices_ipc),
      coef_ipim = buscar_coeficiente(fecha_alta, indices_ipim),

      # para terrenos pre-2018 usamos IPIM, post-2018 usamos IPC
      vo_reexp = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        vo * coef_ipc,
        vo * coef_ipim
      ),
      amort_hist_reexp = 0,
      amort_acum_ly_reexp = 0,
      amort_acum_cierre_reexp = 0,
      vr_reexp = vo_reexp,

      amort_bajas = 0,
      vr_bajas = 0
    )

  inv
}

calcular_bajas_reexp <- function(inv, indices_ipc_bajas, indices_ipim_bajas) {
  inv <- inv %>%
    dplyr::mutate(
      es_baja = (tipo_movimiento == "baja"),

      coef_ipc_bajas = dplyr::if_else(
        es_baja & anio_alta >= ANIO_CORTE_REVALUO,
        buscar_coeficiente(fecha_alta, indices_ipc_bajas),
        0
      ),

      coef_ipim_bajas = dplyr::if_else(
        es_baja & anio_alta < ANIO_CORTE_REVALUO,
        buscar_coeficiente(fecha_alta, indices_ipim_bajas),
        0
      ),

      # reexpresamos amort y VR de bajas usando el coeficiente correspondiente
      amort_bajas = dplyr::if_else(
        es_baja,
        dplyr::if_else(
          anio_alta >= ANIO_CORTE_REVALUO,
          amort_acum_cierre * coef_ipc_bajas,
          amort_acum_cierre * coef_ipim_bajas
        ),
        0
      ),

      vr_bajas = dplyr::if_else(
        es_baja,
        dplyr::if_else(
          anio_alta >= ANIO_CORTE_REVALUO,
          vr * coef_ipc_bajas,
          vr * coef_ipim_bajas
        ),
        0
      )
    )

  inv
}
