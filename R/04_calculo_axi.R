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
  if (!"fecha_baja" %in% names(inv)) inv$fecha_baja <- as.Date(NA)

  # Normaliza nulos para poder calcular en forma consistente (VO, VU, año y mes de alta).
  inv <- inv %>%
    dplyr::mutate(
      vo = tidyr::replace_na(vo, 0),
      vu_asignada = tidyr::replace_na(vu_asignada, 0),
      anio_alta = tidyr::replace_na(anio_alta, anio_ejercicio),
      mes_alta = tidyr::replace_na(mes_alta, 1)
    )

  inv <- aplicar_excepciones_fecha_base(inv, excepciones_fecha_base)

  trim_primer_anio <- if (periodos_por_anio == 4L) {
    calcular_trimestres_primer_anio(inv$mes_alta)
  } else {
    rep.int(1L, nrow(inv))
  }
  # Ejercicio de baja: Edificios devenga los trimestres que fije revaluo.baja_edificios (por defecto, los anteriores al
  # de la baja) y los muebles no devengan (revaluo.baja_muebles_amortiza). Ver periodos_devengados_baja().
  es_baja_fila <- inv$tipo_movimiento_calc %in% "baja"
  periodos_hasta_baja <- rep.int(periodos_por_anio, nrow(inv))
  if (any(es_baja_fila)) {
    periodos_hasta_baja[es_baja_fila] <-
      periodos_devengados_baja(rubro_nombre, inv$fecha_baja[es_baja_fila], periodos_por_anio)
  }
  # Baja de un bien dado de alta en el mismo ejercicio: descuenta los periodos previos al alta (piso en cero).
  periodos_previos_alta <- periodos_por_anio - trim_primer_anio
  periodos_primer_anio <- dplyr::if_else(
    es_baja_fila,
    pmax(periodos_hasta_baja - periodos_previos_alta, 0L),
    as.integer(trim_primer_anio)
  )

  # La vida util transcurrida se cuenta desde la fecha REAL del bien; el piso de 1992 es solo para el indice.
  anio_vut <- inv$anio_alta
  mes_vut <- inv$mes_alta
  if ("fecha_alta_real" %in% names(inv)) {
    usar_real <- !is.na(inv$fecha_alta_real) & inv$fecha_alta_real < FECHA_MINIMA_REEXPRESION
    anio_vut[usar_real] <- lubridate::year(inv$fecha_alta_real[usar_real])
    mes_vut[usar_real] <- lubridate::month(inv$fecha_alta_real[usar_real])
  }

  # Excel manual: VUT LY = MIN(VU, anio_ejercicio - anio_alta) para rubros anuales; los trimestrales
  # cuentan trimestres desde el trimestre de alta.
  vut_ly_calculada <- if (periodos_por_anio == 4L) {
    calcular_vut_ly(anio_vut, mes_vut, anio_ejercicio, inv$vu_asignada)
  } else {
    pmin(inv$vu_asignada, pmax(anio_ejercicio - anio_vut, 0L))
  }

  inv <- inv %>%
    dplyr::mutate(
      # Los rubros trimestrales devengan por trimestre; los anuales, por anio completo.
      trim_primer_anio = trim_primer_anio,
      periodos_hasta_baja = periodos_hasta_baja,

      vut_ly = dplyr::if_else(!is.na(vut_ly), vut_ly, vut_ly_calculada),

      # piso en cero: con la VUT LY por encima de la VU no se resta vida util al cierre
      vut_ejercicio = pmax(
        pmin(
          dplyr::if_else(
            anio_alta == anio_ejercicio,
            periodos_primer_anio,
            periodos_hasta_baja
          ),
          vu_asignada - vut_ly
        ),
        0
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

      # tope en la VU: hay filas del historico con VUT informada mayor a la VU
      amort_acum_ly = dplyr::if_else(
        vu_asignada > 0,
        amort_trimestre * pmin(vut_ly, vu_asignada),
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

      coef_ipim = coeficiente_pre_2018(fecha_indice_reexp, indices_ipim),
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

      # "Amort. Reexp." del Excel: amortizacion del ejercicio por el coeficiente de cada bien (los anteriores a 2018
      # llevan su coeficiente, que es 1 salvo criterio IPIM); es la base de "Amortizacion s/revaluo" de la PG AXI.
      amort_ejercicio_reexp = amort_hist_ejercicio * dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        coef_ipc,
        coef_ipim
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

  inv <- calcular_bajas_reexp(inv, indices_ipc_bajas, indices_ipim_bajas, anio_ejercicio)

  inv
}

# Para terrenos: no amortiza, solo reexpresa VO con IPC/IPIM según año de alta
# y mantiene VR igual al VO reexpresado.
calcular_terrenos <- function(inv, indices_ipc, indices_ipim, anio_ejercicio,
                              excepciones_fecha_base = SCHEMA_EXCEPCIONES_FECHA_BASE) {
  if (!"tipo_movimiento_calc" %in% names(inv)) inv$tipo_movimiento_calc <- NA_character_

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
      coef_ipim = coeficiente_pre_2018(fecha_indice_reexp, indices_ipim),

      vo_reexp = dplyr::if_else(
        anio_alta >= ANIO_CORTE_REVALUO,
        vo * coef_ipc,
        vo * coef_ipim
      ),
      amort_hist_reexp = 0,
      amort_acum_ly_reexp = 0,
      amort_acum_cierre_reexp = 0,
      amort_ejercicio_reexp = 0,
      vr_reexp = vo_reexp,

      es_baja = tipo_movimiento_calc %in% "baja",
      coef_ipc_bajas = 0,
      coef_ipim_bajas = 0,
      coef_baja = dplyr::if_else(
        es_baja, dplyr::if_else(anio_alta >= ANIO_CORTE_REVALUO, coef_ipc, coef_ipim), 0
      )
    )

  separar_saldo_baja(inv)
}

# Coeficiente de reexpresion de las bajas (tabla "VR Bajas"): bienes anteriores a 2018 -> coeficiente_pre_2018()
# (1 por defecto, como el Excel manual 2023); dados de alta en el propio ejercicio -> 1; resto -> IPC de bajas.
calcular_coeficientes_bajas <- function(inv, indices_ipc_bajas, indices_ipim_bajas, anio_ejercicio = NA_integer_) {
  es_baja <- inv$tipo_movimiento_calc %in% "baja"
  coef_ipc <- rep(0, nrow(inv))
  coef_ipim <- rep(0, nrow(inv))

  idx_ipc <- which(es_baja & inv$anio_alta >= ANIO_CORTE_REVALUO)
  if (length(idx_ipc) > 0) {
    coef_ipc[idx_ipc] <- buscar_coeficiente(inv$fecha_indice_reexp[idx_ipc], indices_ipc_bajas)
    coef_ipc[idx_ipc[inv$anio_alta[idx_ipc] %in% anio_ejercicio]] <- 1
  }

  idx_ipim <- which(es_baja & inv$anio_alta < ANIO_CORTE_REVALUO)
  if (length(idx_ipim) > 0) {
    coef_ipim[idx_ipim] <- coeficiente_pre_2018(inv$fecha_indice_reexp[idx_ipim], indices_ipim_bajas)
  }

  list(ipc = coef_ipc, ipim = coef_ipim)
}

# Calcula la reexpresión de amortización acumulada y VR únicamente para bienes dados de baja,
# usando IPC o IPIM de bajas según corresponda por año de alta, y separa su saldo del cierre.
calcular_bajas_reexp <- function(inv, indices_ipc_bajas, indices_ipim_bajas, anio_ejercicio = NA_integer_) {
  coef <- calcular_coeficientes_bajas(inv, indices_ipc_bajas, indices_ipim_bajas, anio_ejercicio)

  inv <- inv %>%
    dplyr::mutate(
      es_baja = (tipo_movimiento_calc == "baja"),
      coef_ipc_bajas = coef$ipc,
      coef_ipim_bajas = coef$ipim,
      coef_baja = dplyr::if_else(
        es_baja, dplyr::if_else(anio_alta >= ANIO_CORTE_REVALUO, coef_ipc_bajas, coef_ipim_bajas), 0
      )
    )

  separar_saldo_baja(inv)
}

# Un bien dado de baja no tiene saldo al cierre: VO, amortizacion acumulada y valor residual de cierre (historicos y
# reexpresados) quedan en 0 y lo que se retira va en columnas propias (*_baja), reexpresado con coef_baja.
separar_saldo_baja <- function(inv) {
  inv %>%
    dplyr::mutate(
      vo_baja = dplyr::if_else(es_baja, vo, 0),
      amort_acum_baja = dplyr::if_else(es_baja, amort_acum_cierre, 0),
      vr_baja = dplyr::if_else(es_baja, vr, 0),
      vo_baja_reexp = vo_baja * coef_baja,
      amort_bajas = amort_acum_baja * coef_baja,
      vr_bajas = vr_baja * coef_baja,
      vo_cierre = dplyr::if_else(es_baja, 0, vo),
      amort_acum_cierre = dplyr::if_else(es_baja, 0, amort_acum_cierre),
      vr = dplyr::if_else(es_baja, 0, vr),
      vo_reexp = dplyr::if_else(es_baja, 0, vo_reexp),
      amort_acum_cierre_reexp = dplyr::if_else(es_baja, 0, amort_acum_cierre_reexp),
      vr_reexp = dplyr::if_else(es_baja, 0, vr_reexp)
    )
}
