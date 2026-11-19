generar_prueba_global <- function(datos_axi, anio_ejercicio = 2022) {
  resultado_axi <- datos_axi$resultado_axi

  pg_amort <- generar_pg_amortizaciones(resultado_axi, anio_ejercicio)
  pg_vr <- generar_pg_valor_residual(resultado_axi, anio_ejercicio)
  pg_axi <- generar_pg_axi(resultado_axi, anio_ejercicio)

  datos_axi$prueba_global <- list(
    amortizaciones = pg_amort,
    valor_residual = pg_vr,
    axi = pg_axi
  )

  datos_axi
}

generar_pg_amortizaciones <- function(resultado_axi, anio_ejercicio = 2022) {
  rubros <- names(resultado_axi)

  pg <- tibble::tibble(rubro = rubros)

  es_mov_actual <- function(d) {
    !is.na(d$anio_movimiento) & d$anio_movimiento == anio_ejercicio
  }
  es_existente <- function(d) {
    !es_mov_actual(d) & d$tipo_movimiento_calc != "baja"
  }
  # amortizacion del ejercicio anterior ("Amort. Historica" del Excel LY); 0 si no se pudo leer
  flujo_ly <- function(d) {
    if ("amort_hist_ly" %in% names(d)) tidyr::replace_na(d$amort_hist_ly, 0) else rep(0, nrow(d))
  }
  # la PG del Excel del estudio trabaja con la amortizacion del EJERCICIO (flujo), no con la acumulada:
  #   s/prueba = inicio (flujo anterior) + altas + transferencias + bajas + bienes que agotaron VU LY + irregular
  #   s/revaluo = suma de "Amort. Historica" del ejercicio de todos los bienes que no son bajas
  suma_por_rubro <- function(valor, filtro) {
    vapply(rubros, function(r) {
      d <- resultado_axi[[r]]
      sum(valor(d)[filtro(d)], na.rm = TRUE)
    }, numeric(1))
  }

  pg$amort_inicio <- suma_por_rubro(
    flujo_ly,
    function(d) es_existente(d) | (es_mov_actual(d) & d$tipo_movimiento == "baja")
  )

  pg$amort_altas <- suma_por_rubro(
    function(d) d$amort_hist_ejercicio,
    function(d) es_mov_actual(d) & d$tipo_movimiento == "alta"
  )

  pg$amort_transferencias <- suma_por_rubro(
    function(d) d$amort_hist_ejercicio,
    function(d) es_mov_actual(d) & d$tipo_movimiento == "transferencia"
  )

  pg$amort_bajas <- -suma_por_rubro(
    flujo_ly,
    function(d) es_mov_actual(d) & d$tipo_movimiento == "baja"
  )

  # bienes cuya VU se agoto al cierre anterior: su amortizacion del ejercicio anterior no se repite
  pg$bs_agotaron_vu_ly <- -suma_por_rubro(
    flujo_ly,
    function(d) es_existente(d) & d$es_vu_agotada_ly
  )

  # diferencia entre la amortizacion de este ejercicio y la del anterior en bienes que siguen amortizando
  # (primer periodo parcial del ejercicio anterior, etc.); equivale a "Bienes con amort. irregular" del Excel
  pg$amort_irregular <- suma_por_rubro(
    function(d) d$amort_hist_ejercicio - flujo_ly(d),
    function(d) es_existente(d) & !d$es_vu_agotada_ly
  )

  pg$amort_prueba <- pg$amort_inicio +
    pg$amort_altas +
    pg$amort_transferencias +
    pg$amort_bajas +
    pg$bs_agotaron_vu_ly +
    pg$amort_irregular

  pg$amort_revaluo <- suma_por_rubro(
    function(d) d$amort_hist_ejercicio,
    function(d) !(es_mov_actual(d) & d$tipo_movimiento == "baja")
  )

  pg$diferencia <- pg$amort_prueba - pg$amort_revaluo

  pg
}

generar_pg_valor_residual <- function(resultado_axi, anio_ejercicio = 2022) {
  rubros <- names(resultado_axi)

  pg <- tibble::tibble(rubro = rubros)

  es_mov_actual <- function(d) {
    !is.na(d$anio_movimiento) & d$anio_movimiento == anio_ejercicio
  }
  es_existente <- function(d) {
    !es_mov_actual(d) & d$tipo_movimiento_calc != "baja"
  }

  pg$vr_inicio <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_existente(d) | (es_mov_actual(d) & d$tipo_movimiento == "baja")
    sum(d$vr_ly[idx], na.rm = TRUE)
  }, numeric(1))

  pg$altas_vr <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_mov_actual(d) & d$tipo_movimiento == "alta"
    sum(d$vr[idx], na.rm = TRUE)
  }, numeric(1))

  pg$transferencias_vr <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_mov_actual(d) & d$tipo_movimiento == "transferencia"
    sum(d$vr[idx], na.rm = TRUE)
  }, numeric(1))

  # como el Excel: el VR de las bajas es el valor congelado a LY (VO - amort. acumulada del LY), el mismo que
  # figuraba en la base al inicio del ejercicio
  pg$bajas_vo <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_mov_actual(d) & d$tipo_movimiento == "baja"
    -sum(d$vr_ly[idx], na.rm = TRUE)
  }, numeric(1))

  pg$amort_ejercicio <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_existente(d) & !d$es_vu_agotada_ly
    -sum(d$amort_hist_ejercicio[idx], na.rm = TRUE)
  }, numeric(1))

  pg$vr_prueba <- pg$vr_inicio +
    pg$altas_vr +
    pg$transferencias_vr +
    pg$bajas_vo +
    pg$amort_ejercicio

  pg$vr_revaluo <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- !(es_mov_actual(d) & d$tipo_movimiento == "baja")
    sum(d$vr[idx], na.rm = TRUE)
  }, numeric(1))

  pg$diferencia <- pg$vr_prueba - pg$vr_revaluo

  pg
}

generar_pg_axi <- function(resultado_axi, anio_ejercicio = 2022) {
  rubros <- names(resultado_axi)

  pg <- tibble::tibble(rubro = rubros)

  # Como "s/revaluo" del Excel del estudio: sin las bajas del ejercicio (salen del saldo; en el Excel se
  # listan aparte). Incluirlas suma su AXI y desvia el total (ej. Edificios +2 M, Maquinas y Equipos +7 M).
  sin_bajas <- function(d) {
    !(!is.na(d$anio_movimiento) & d$anio_movimiento == anio_ejercicio & d$tipo_movimiento == "baja")
  }
  suma_sin_bajas <- function(columna) {
    vapply(rubros, function(r) {
      d <- resultado_axi[[r]]
      sum(d[[columna]][sin_bajas(d)], na.rm = TRUE)
    }, numeric(1))
  }

  pg$vr_reexp <- suma_sin_bajas("vr_reexp")
  pg$vo_reexp <- suma_sin_bajas("vo_reexp")
  pg$amort_acum_reexp <- suma_sin_bajas("amort_acum_cierre_reexp")
  # "Amortizacion s/revaluo" de la PG AXI del Excel (amortizacion del ejercicio reexpresada)
  pg$amort_ejercicio_reexp <- suma_sin_bajas("amort_ejercicio_reexp")
  pg$vr_hist <- suma_sin_bajas("vr")

  pg$axi_resultado <- pg$vr_reexp - pg$vr_hist

  pg
}
