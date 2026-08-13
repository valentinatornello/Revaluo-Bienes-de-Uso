construir_rollforward <- function(datos_limpios) {
  inventario <- datos_limpios$inventario_ly
  altas <- datos_limpios$altas
  bajas <- datos_limpios$bajas
  transferencias <- datos_limpios$transferencias

  resultado <- list()

  for (rubro_nombre in names(inventario)) {
    inv_rubro <- inventario[[rubro_nombre]]
    if (is.null(inv_rubro) || nrow(inv_rubro) == 0) next

    inv_rubro <- inv_rubro %>%
      dplyr::mutate(origen = dplyr::case_when(
        tipo_movimiento == "alta"           ~ paste0("alta_", anio_alta),
        tipo_movimiento == "transferencia"  ~ paste0("transferencia_", anio_alta),
        tipo_movimiento == "baja"           ~ paste0("baja_", anio_alta),
        TRUE                                ~ "historico"
      ))

    if (nrow(altas) > 0) {
      altas_rubro <- filtrar_movimientos_por_rubro(altas, rubro_nombre)
      if (nrow(altas_rubro) > 0) {
        altas_norm <- normalizar_movimiento_sap(altas_rubro, rubro_nombre, "alta")
        inv_rubro <- dplyr::bind_rows(inv_rubro, altas_norm)
      }
    }

    if (nrow(transferencias) > 0) {
      transf_rubro <- filtrar_movimientos_por_rubro(transferencias, rubro_nombre)
      if (nrow(transf_rubro) > 0) {
        transf_norm <- normalizar_movimiento_sap(transf_rubro, rubro_nombre, "transferencia")
        inv_rubro <- dplyr::bind_rows(inv_rubro, transf_norm)
      }
    }

    if (nrow(bajas) > 0) {
      bajas_rubro <- filtrar_movimientos_por_rubro(bajas, rubro_nombre)
      if (nrow(bajas_rubro) > 0) {
        inv_rubro <- aplicar_bajas(inv_rubro, bajas_rubro)
      }
    }

    resultado[[rubro_nombre]] <- inv_rubro
  }

  datos_limpios$inventario <- resultado
  datos_limpios
}

filtrar_movimientos_por_rubro <- function(movimientos, rubro_nombre) {
  params <- PARAMETROS_RUBROS %>%
    dplyr::filter(rubro == rubro_nombre)

  if (nrow(params) == 0 || params$codigos_sap == "") {
    return(tibble::tibble())
  }

  codigos <- trimws(unlist(strsplit(params$codigos_sap, ",")))

  col_clase <- grep("class|clase|codigo|asset_class", tolower(names(movimientos)), value = TRUE)
  if (length(col_clase) == 0) return(tibble::tibble())

  movimientos %>%
    dplyr::filter(.data[[col_clase[1]]] %in% codigos)
}

normalizar_movimiento_sap <- function(movimiento, rubro_nombre, tipo) {
  anio_ejercicio <- 2022
  vu_trim <- obtener_vu_trimestres(rubro_nombre)

  col_nro <- grep("asset|activo|numero", tolower(names(movimiento)), value = TRUE)[1]
  col_desc <- grep("desc|text|nombre", tolower(names(movimiento)), value = TRUE)[1]
  col_fecha <- grep("posting|fecha|capitali", tolower(names(movimiento)), value = TRUE)[1]
  col_valor <- grep("acqui|valor|amount|importe", tolower(names(movimiento)), value = TRUE)[1]

  tibble::tibble(
    rubro = rubro_nombre,
    tipo_movimiento = tipo,
    nro_activo_fijo = if (!is.na(col_nro)) as.character(movimiento[[col_nro]]) else NA_character_,
    descripcion = if (!is.na(col_desc)) as.character(movimiento[[col_desc]]) else NA_character_,
    fecha_alta = if (!is.na(col_fecha)) as.Date(movimiento[[col_fecha]]) else as.Date(NA),
    anio_alta = lubridate::year(fecha_alta),
    mes_alta = lubridate::month(fecha_alta),
    vo = if (!is.na(col_valor)) as.numeric(movimiento[[col_valor]]) else NA_real_,
    vu_asignada = vu_trim,
    vut_ly = 0,
    origen = paste0(tipo, "_", anio_ejercicio)
  )
}

aplicar_bajas <- function(inventario, bajas) {
  col_nro_baja <- grep("asset|activo|numero", tolower(names(bajas)), value = TRUE)[1]

  if (is.na(col_nro_baja)) return(inventario)

  nros_baja <- as.character(bajas[[col_nro_baja]])

  inventario %>%
    dplyr::mutate(
      es_baja = nro_activo_fijo %in% nros_baja,
      tipo_movimiento = ifelse(es_baja & tipo_movimiento == "historico", "baja", tipo_movimiento)
    ) %>%
    dplyr::select(-es_baja)
}
