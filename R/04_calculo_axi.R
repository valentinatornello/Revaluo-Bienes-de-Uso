# Calcula la amortización de los rubros de bienes de uso y terrenos, reexpresando los valores originales 
# y la amortización acumulada al cierre del ejercicio, según corresponda, y considerando las bajas de bienes de uso.
#' @param datos_rollforward Lista con los datos de inventario, índices IPC e IPIM, y los índices de IPC e IPIM para las bajas.
#' @param anio_ejercicio Año del ejercicio para el cual se realiza el cálculo de amortización.
#' @return Lista con los datos de inventario actualizados con los cálculos de amortización y reexpresión.
# Esto debe ir cambiando segun el año seleccionado en la ShinyApp.
# Orquesta el cálculo AXI por rubro: si es terreno reexpresa VO; si es amortizable calcula
# vida útil, amortizaciones y reexpresión, y deja el resultado dentro de datos_rollforward.
calcular_axi <- function(datos_rollforward, anio_ejercicio = 2022) {
  inventario <- datos_rollforward$inventario
  indices_ipc <- datos_rollforward$indices_ipc
  indices_ipim <- datos_rollforward$indices_ipim
  indices_ipc_bajas <- datos_rollforward$indices_ipc_bajas
  indices_ipim_bajas <- datos_rollforward$indices_ipim_bajas
  excepciones_fecha_base <- datos_rollforward$excepciones_fecha_base

  resultado <- list()
# Si el inventario de un rubro es nulo o tiene cero filas, se omite el cálculo para ese rubro.
  for (rubro_nombre in names(inventario)) {
    inv <- inventario[[rubro_nombre]]
    if (is.null(inv) || nrow(inv) == 0) next

    if (es_terreno(rubro_nombre)) {
      inv <- calcular_terrenos(
        inv, indices_ipc, indices_ipim, anio_ejercicio, excepciones_fecha_base
      )
    } else {
      inv <- calcular_rubro_amortizable(
        inv, rubro_nombre, indices_ipc, indices_ipim,
        indices_ipc_bajas, indices_ipim_bajas,
        anio_ejercicio, excepciones_fecha_base
      )
    }

    resultado[[rubro_nombre]] <- inv
  }

  datos_rollforward$resultado_axi <- resultado
  datos_rollforward
}

calcular_rubro_amortizable <- function(inv, rubro_nombre, indices_ipc, indices_ipim,
                                        indices_ipc_bajas, indices_ipim_bajas,
                                        anio_ejercicio,
                                        excepciones_fecha_base = SCHEMA_EXCEPCIONES_FECHA_BASE) {
  periodos_por_anio <- obtener_periodos_por_anio(rubro_nombre)

  # Normaliza nulos para poder calcular en forma consistente (VO, VU, año y mes de alta).
  inv <- inv %>%
    dplyr::mutate(
      vo = tidyr::replace_na(vo, 0),
      vu_asignada = tidyr::replace_na(vu_asignada, 0),
      anio_alta = tidyr::replace_na(anio_alta, anio_ejercicio),
      mes_alta = tidyr::replace_na(mes_alta, 1)
    )

  inv <- aplicar_excepciones_fecha_base(inv, excepciones_fecha_base)

  inv <- inv %>%
    dplyr::mutate(
      # Edificios devenga por trimestre; los otros rubros, por año.
      trim_primer_anio = dplyr::if_else(
        periodos_por_anio == 4L,
        calcular_trimestres_primer_anio(mes_alta),
        1L
      ),

      vut_ly = dplyr::if_else(
        !is.na(vut_ly),
        vut_ly,
        calcular_vut_ly(anio_alta, mes_alta, anio_ejercicio, vu_asignada) /
          4L * periodos_por_anio
      ),

      vut_ejercicio = pmin(
        dplyr::if_else(
          anio_alta == anio_ejercicio,
          trim_primer_anio,
          periodos_por_anio
        ),
        vu_asignada - vut_ly
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
      # Reexpresa VO y amortizaciones: IPC para altas desde 2018, IPIM para anteriores.
      coef_ipc = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        buscar_coeficiente(fecha_indice_reexp, indices_ipc),
        1
      ),

      coef_ipim = buscar_coeficiente(fecha_indice_reexp, indices_ipim),
# EVALUAR SI ES EL IPC O EL IPIM EL COEFICIENTE AL QUE TENEMOS QUE MULTIPLICAR EL VO DE LOS BIENES DADOS DE BAJA, SEGUN EL ANIO DE ALTA
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
  # Si la VU ya estaba agotada al cierre anterior, calcula el ajuste negativo del ejercicio
  # para no sobre-amortizar y reflejar el trimestre que no corresponde computar.
  inv <- inv %>%
    dplyr::mutate(
      es_vu_agotada_ly = (vut_ly >= vu_asignada & vu_asignada > 0),

      # para bienes que agotaron la VU en el ejercicio anterior, calculamos el
      # ajuste como la amortizacion que se habria devengado si la VU no estuviera
      # agotada (o sea, el triimestre normal que no se computa)
      amort_bs_agotaron_vu_ly = dplyr::if_else(
        es_vu_agotada_ly,
        -amort_trimestre * dplyr::if_else(
          anio_alta == anio_ejercicio,
          trim_primer_anio,
          pmin(periodos_por_anio, vu_asignada - vut_ly + periodos_por_anio)
        ),
        0
      )
    )

  inv <- calcular_bajas_reexp(inv, indices_ipc_bajas, indices_ipim_bajas)
# 
  # Para movimientos de baja, anula devengado del ejercicio y deja saldos al valor de LY.
  # se usa tipo_movimiento_calc para congelar tambien las bajas historicas (de cualquier anio)
  inv <- inv %>%
    dplyr::mutate(
      vut_ejercicio = dplyr::if_else(tipo_movimiento_calc == "baja", 0, vut_ejercicio),
      vut_cierre = dplyr::if_else(tipo_movimiento_calc == "baja", vut_ly, vut_cierre),
      vu_restante = dplyr::if_else(tipo_movimiento_calc == "baja", pmax(vu_asignada - vut_ly, 0), vu_restante),
      amort_hist_ejercicio = dplyr::if_else(tipo_movimiento_calc == "baja", 0, amort_hist_ejercicio),
      amort_hist_2018 = dplyr::if_else(tipo_movimiento_calc == "baja", 0, amort_hist_2018),
      amort_acum_cierre = dplyr::if_else(tipo_movimiento_calc == "baja", amort_acum_ly, amort_acum_cierre),
      vr = dplyr::if_else(tipo_movimiento_calc == "baja", vr_ly, vr),
      amort_acum_cierre_reexp = dplyr::if_else(tipo_movimiento_calc == "baja", amort_acum_ly_reexp, amort_acum_cierre_reexp),
      vr_reexp = dplyr::if_else(tipo_movimiento_calc == "baja", vo_reexp - amort_acum_ly_reexp, vr_reexp)
    )

  inv
}

# Para terrenos: no amortiza, solo reexpresa VO con IPC/IPIM según año de alta
# y mantiene VR igual al VO reexpresado.
calcular_terrenos <- function(inv, indices_ipc, indices_ipim, anio_ejercicio,
                              excepciones_fecha_base = SCHEMA_EXCEPCIONES_FECHA_BASE) {
  inv <- inv %>%
    dplyr::mutate(
      vo = tidyr::replace_na(vo, 0),
      anio_alta = tidyr::replace_na(anio_alta, anio_ejercicio),
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
      amort_bs_agotaron_vu_ly = 0
    )

  inv <- aplicar_excepciones_fecha_base(inv, excepciones_fecha_base)

  inv <- inv %>%
    dplyr::mutate(
      coef_ipc = buscar_coeficiente(fecha_indice_reexp, indices_ipc),
      coef_ipim = buscar_coeficiente(fecha_indice_reexp, indices_ipim),

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

# Calcula la reexpresión de amortización acumulada y VR únicamente para bienes dados de baja,
# usando IPC o IPIM de bajas según corresponda por año de alta.
calcular_bajas_reexp <- function(inv, indices_ipc_bajas, indices_ipim_bajas) {
  inv <- inv %>%
    dplyr::mutate(
      es_baja = (tipo_movimiento_calc == "baja"),

      coef_ipc_bajas = dplyr::if_else(
        es_baja & anio_alta >= ANIO_CORTE_REVALUO,
        buscar_coeficiente(fecha_indice_reexp, indices_ipc_bajas),
        0
      ),

      coef_ipim_bajas = dplyr::if_else(
        es_baja & anio_alta < ANIO_CORTE_REVALUO,
        buscar_coeficiente(fecha_indice_reexp, indices_ipim_bajas),
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
