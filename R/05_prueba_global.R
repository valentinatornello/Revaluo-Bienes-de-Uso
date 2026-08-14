generar_prueba_global <- function(datos_axi) {
  resultado_axi <- datos_axi$resultado_axi

  pg_amort <- generar_pg_amortizaciones(resultado_axi)
  pg_vr <- generar_pg_valor_residual(resultado_axi)
  pg_axi <- generar_pg_axi(resultado_axi)

  datos_axi$prueba_global <- list(
    amortizaciones = pg_amort,
    valor_residual = pg_vr,
    axi = pg_axi
  )

  datos_axi
}

generar_pg_amortizaciones <- function(resultado_axi) {
  rubros <- names(resultado_axi)
  anio_ejercicio <- 2022

  pg <- tibble::tibble(rubro = rubros)

  es_mov_actual <- function(d) {
    !is.na(d$anio_movimiento) & d$anio_movimiento == anio_ejercicio
  }
  es_existente <- function(d) {
    !es_mov_actual(d) & d$tipo_movimiento != "baja"
  }

  pg$amort_inicio <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_existente(d) | (es_mov_actual(d) & d$tipo_movimiento == "baja")
    sum(d$amort_acum_ly[idx], na.rm = TRUE)
  }, numeric(1))

  pg$amort_altas <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_mov_actual(d) & d$tipo_movimiento == "alta"
    sum(d$amort_acum_cierre[idx], na.rm = TRUE)
  }, numeric(1))

  pg$amort_transferencias <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_mov_actual(d) & d$tipo_movimiento == "transferencia"
    sum(d$amort_acum_cierre[idx], na.rm = TRUE)
  }, numeric(1))

  pg$amort_bajas <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_mov_actual(d) & d$tipo_movimiento == "baja"
    -sum(d$amort_acum_ly[idx], na.rm = TRUE)
  }, numeric(1))

  pg$bs_agotaron_vu_ly <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    sum(d$amort_bs_agotaron_vu_ly[es_existente(d)], na.rm = TRUE)
  }, numeric(1))

  pg$amort_hist_ejercicio_total <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- es_existente(d) & !d$es_vu_agotada_ly
    sum(d$amort_hist_ejercicio[idx], na.rm = TRUE)
  }, numeric(1))

  pg$amort_prueba <- pg$amort_inicio +
    pg$amort_altas +
    pg$amort_transferencias +
    pg$amort_bajas +
    pg$bs_agotaron_vu_ly +
    pg$amort_hist_ejercicio_total

  pg$amort_revaluo <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    idx <- !(es_mov_actual(d) & d$tipo_movimiento == "baja")
    sum(d$amort_acum_cierre[idx], na.rm = TRUE)
  }, numeric(1))

  pg$diferencia <- pg$amort_prueba - pg$amort_revaluo

  pg
}

generar_pg_valor_residual <- function(resultado_axi) {
  rubros <- names(resultado_axi)
  anio_ejercicio <- 2022

  pg <- tibble::tibble(rubro = rubros)

  es_mov_actual <- function(d) {
    !is.na(d$anio_movimiento) & d$anio_movimiento == anio_ejercicio
  }
  es_existente <- function(d) {
    !es_mov_actual(d) & d$tipo_movimiento != "baja"
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

generar_pg_axi <- function(resultado_axi) {
  rubros <- names(resultado_axi)

  pg <- tibble::tibble(rubro = rubros)

  pg$vr_reexp <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    sum(d$vr_reexp, na.rm = TRUE)
  }, numeric(1))

  pg$vo_reexp <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    sum(d$vo_reexp, na.rm = TRUE)
  }, numeric(1))

  pg$amort_acum_reexp <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    sum(d$amort_acum_cierre_reexp, na.rm = TRUE)
  }, numeric(1))

  pg$vr_hist <- vapply(rubros, function(r) {
    d <- resultado_axi[[r]]
    sum(d$vr, na.rm = TRUE)
  }, numeric(1))

  pg$axi_resultado <- pg$vr_reexp - pg$vr_hist

  pg
}
