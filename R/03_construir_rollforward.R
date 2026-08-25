# construye el rollforward combinando inventario del año anterior con movimientos SAP del ejercicio

construir_rollforward <- function(datos_limpios, anio_ejercicio = 2022) {
  inventario <- datos_limpios$inventario_ly
  altas_sap <- datos_limpios$altas
  bajas_sap <- datos_limpios$bajas
  transf_sap <- datos_limpios$transferencias

  tiene_mov_anio <- any(purrr::map_lgl(inventario, function(inv) {
    any(!is.na(inv$anio_movimiento) & inv$anio_movimiento == anio_ejercicio)
  }))

  resultado <- list()

  rubros_config <- PARAMETROS_RUBROS$rubro
  rubros_inventario <- names(inventario)
  todos_rubros <- unique(c(rubros_config, rubros_inventario))

  for (rubro_nombre in todos_rubros) {
    inv_rubro <- inventario[[rubro_nombre]]
    if (is.null(inv_rubro)) next

    inv_rubro <- inv_rubro %>%
      dplyr::mutate(origen = dplyr::case_when(
        tipo_movimiento == "alta"          ~ paste0("alta_", 
        dplyr::coalesce(as.integer(anio_movimiento), anio_alta)),
        tipo_movimiento == "transferencia" ~ paste0("transferencia_", 
        dplyr::coalesce(as.integer(anio_movimiento), anio_alta)),
        tipo_movimiento == "baja"          ~ paste0("baja_", 
        dplyr::coalesce(as.integer(anio_movimiento), anio_alta)),
        tipo_movimiento == "alta_y_baja"   ~ paste0("alta_y_baja_", 
        dplyr::coalesce(as.integer(anio_movimiento), anio_alta)),
        TRUE                               ~ "historico"
      ))

    if (!tiene_mov_anio) {
      if (nrow(altas_sap) > 0) {
        altas_rubro <- altas_sap %>% dplyr::filter(rubro == rubro_nombre)
        if (nrow(altas_rubro) > 0) {
      altas_norm <- normalizar_movimiento_sap(altas_rubro, 
      rubro_nombre, "alta", anio_ejercicio)
          inv_rubro <- dplyr::bind_rows(inv_rubro, altas_norm)
        }
      }

      if (nrow(transf_sap) > 0) {
        transf_rubro <- transf_sap %>% dplyr::filter(rubro == rubro_nombre)
        if (nrow(transf_rubro) > 0) {
          transf_norm <- normalizar_movimiento_sap(transf_rubro, rubro_nombre, 
          "transferencia", anio_ejercicio)
          inv_rubro <- dplyr::bind_rows(inv_rubro, transf_norm)
        }
      }

      if (nrow(bajas_sap) > 0) {
        bajas_rubro <- bajas_sap %>% dplyr::filter(rubro == rubro_nombre)
        if (nrow(bajas_rubro) > 0) {
          bajas_norm <- normalizar_baja_sap(bajas_rubro, rubro_nombre, 
          anio_ejercicio)
          inv_rubro <- dplyr::bind_rows(inv_rubro, bajas_norm)
        }
      }
    }

    if (nrow(inv_rubro) > 0) {
      resultado[[rubro_nombre]] <- inv_rubro
    }
  }

  if (!tiene_mov_anio) {
    rubros_nuevos <- unique(c(
      altas_sap$rubro, transf_sap$rubro, bajas_sap$rubro
    ))
    rubros_nuevos <- rubros_nuevos[!is.na(rubros_nuevos)]
    rubros_sin_inventario <- setdiff(rubros_nuevos, names(resultado))

    for (rubro_nombre in rubros_sin_inventario) {
      partes <- list()
      altas_r <- altas_sap %>% dplyr::filter(rubro == rubro_nombre)
      if (nrow(altas_r) > 0) {
        partes <- append(partes, list(
          normalizar_movimiento_sap(altas_r, rubro_nombre, 
          "alta", anio_ejercicio)
        ))
      }
      transf_r <- transf_sap %>% dplyr::filter(rubro == rubro_nombre)
      if (nrow(transf_r) > 0) {
        partes <- append(partes, list(
          normalizar_movimiento_sap(transf_r, rubro_nombre, "transferencia", 
          anio_ejercicio)
        ))
      }
      bajas_r <- bajas_sap %>% dplyr::filter(rubro == rubro_nombre)
      if (nrow(bajas_r) > 0) {
        partes <- append(partes, list(
          normalizar_baja_sap(bajas_r, rubro_nombre, anio_ejercicio)
        ))
      }
      if (length(partes) > 0) {
        resultado[[rubro_nombre]] <- dplyr::bind_rows(partes)
      }
    }
  }

  datos_limpios$inventario <- resultado
  datos_limpios
}

normalizar_movimiento_sap <- function(mov, rubro_nombre, tipo, anio_ejercicio) {
  vu_trim <- obtener_vu_trimestres(rubro_nombre)

  fecha_ref <- if (tipo == "transferencia") mov$cap_date_parsed 
  else mov$posting_date

  tibble::tibble(
    rubro = rubro_nombre,
    tipo_movimiento = tipo,
    nro_activo_fijo = as.character(mov$nro_activo),
    descripcion = as.character(mov$descripcion),
    fecha_alta = fecha_ref,
    anio_alta = lubridate::year(fecha_ref),
    mes_alta = lubridate::month(fecha_ref),
    vo = if (tipo == "alta") abs(mov$valor) else mov$valor,
    valor_sap_original = mov$valor,
    direccion_movimiento = dplyr::case_when(
      tipo == "transferencia" & mov$valor < 0 ~ "salida",
      tipo == "transferencia" & mov$valor >= 0 ~ "entrada",
      TRUE ~ tipo
    ),
    importe_movimiento_control = if (tipo == "alta") abs(mov$valor) else mov$valor,
    vu_asignada = vu_trim,
    vut_ly = NA_real_,
    origen = paste0(tipo, "_", anio_ejercicio)
  )
}

normalizar_baja_sap <- function(bajas, rubro_nombre, anio_ejercicio) {
  vu_trim <- obtener_vu_trimestres(rubro_nombre)

  tibble::tibble(
    rubro = rubro_nombre,
    tipo_movimiento = "baja",
    nro_activo_fijo = as.character(bajas$nro_activo),
    descripcion = as.character(bajas$descripcion),
    fecha_alta = bajas$posting_date,
    anio_alta = lubridate::year(bajas$cap_date_parsed),
    mes_alta = lubridate::month(bajas$cap_date_parsed),
    vo = abs(bajas$valor),
    valor_sap_original = bajas$valor,
    direccion_movimiento = "salida",
    importe_movimiento_control = -abs(bajas$valor),
    vu_asignada = vu_trim,
    vut_ly = NA_real_,
    origen = paste0("baja_", anio_ejercicio)
  )
}
