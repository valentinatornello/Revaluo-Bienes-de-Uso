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
  bajas_no_identificadas <- list()
  # Regla 7: un activo con baja en el ejercicio sale por completo (base, altas y transferencias del ejercicio);
  # la baja queda como fila propia. Solo aplica cuando los movimientos vienen de SAP.
  if (!tiene_mov_anio && nrow(bajas_sap) > 0) {
    claves_baja <- dplyr::distinct(bajas_sap, rubro, nro_activo)
    if (nrow(altas_sap) > 0) altas_sap <- dplyr::anti_join(altas_sap, claves_baja, by = c("rubro", "nro_activo"))
    if (nrow(transf_sap) > 0) transf_sap <- dplyr::anti_join(transf_sap, claves_baja, by = c("rubro", "nro_activo"))
  }
  rubros_config <- PARAMETROS_RUBROS$rubro
  rubros_inventario <- names(inventario)
  todos_rubros <- unique(c(rubros_config, rubros_inventario))

  for (rubro_nombre in todos_rubros) {
    inv_rubro <- inventario[[rubro_nombre]]
    if (is.null(inv_rubro)) next

    inv_rubro <- inv_rubro %>%
      dplyr::mutate(origen = dplyr::case_when(
        tipo_movimiento == "alta"          ~ paste0("alta_", anio_ejercicio),
        tipo_movimiento == "transferencia" ~ paste0("transferencia_", anio_ejercicio),
        tipo_movimiento == "baja"          ~ paste0("baja_", anio_ejercicio),
        tipo_movimiento == "alta_y_baja"   ~ paste0("alta_y_baja_", anio_ejercicio),
        !is.na(subclasificacion_historico) ~ paste0(
          "historico_", subclasificacion_historico, "_",
          dplyr::coalesce(as.integer(anio_movimiento), anio_alta)
        ),
        TRUE                               ~ "historico"
      ))

    if (!tiene_mov_anio) {
      # Bajas del ejercicio (regla del Excel del estudio): los activos dados de baja se toman de la base LY con sus
      # valores CONGELADOS a LY (VO, VU, VUT LY, fecha de alta) y se retipan como baja; el SAP solo dice que activos
      # y cuando. Quedan fuera de las altas/transferencias del ejercicio (neteo, regla 7). Una baja SAP sin fila en
      # la base ni alta del ejercicio no se identifica: no se calcula y se informa (regla 2).
      if (nrow(bajas_sap) > 0) {
        bajas_rubro <- bajas_sap %>% dplyr::filter(rubro == rubro_nombre)
        if (nrow(bajas_rubro) > 0) {
          fechas_baja <- bajas_rubro %>%
            dplyr::group_by(nro_activo) %>%
            dplyr::summarise(fecha_baja = suppressWarnings(min(posting_date, na.rm = TRUE)), .groups = "drop")
          es_baja_base <- inv_rubro$nro_activo_fijo %in% fechas_baja$nro_activo
          base_baja <- inv_rubro[es_baja_base, ]
          inv_rubro <- inv_rubro[!es_baja_base, ]

          if (nrow(base_baja) > 0) {
            bajas_base <- base_baja %>%
              dplyr::mutate(
                tipo_movimiento = "baja",
                tipo_movimiento_calc = "baja",
                subclasificacion_historico = NA_character_,
                anio_movimiento = anio_ejercicio,
                origen = paste0("baja_", anio_ejercicio),
                fecha_baja = fechas_baja$fecha_baja[match(nro_activo_fijo, fechas_baja$nro_activo)],
                direccion_movimiento = "salida",
                importe_movimiento_control = -abs(vo)
              )
            bajas_para_agregar <- bajas_base
          } else {
            bajas_para_agregar <- NULL
          }

          sin_base <- bajas_rubro %>% dplyr::filter(!nro_activo %in% base_baja$nro_activo_fijo)
          if (nrow(sin_base) > 0) {
            bajas_no_identificadas <- append(bajas_no_identificadas, list(
              tibble::tibble(rubro = rubro_nombre, nro_activo = sin_base$nro_activo,
                             descripcion = sin_base$descripcion, valor = sin_base$valor)
            ))
          }
        } else {
          bajas_para_agregar <- NULL
        }
      } else {
        bajas_para_agregar <- NULL
      }

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

      if (!is.null(bajas_para_agregar)) {
        inv_rubro <- dplyr::bind_rows(inv_rubro, bajas_para_agregar)
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
      # sin base LY en este rubro, sus bajas no se pueden identificar
      bajas_r <- bajas_sap %>% dplyr::filter(rubro == rubro_nombre)
      if (nrow(bajas_r) > 0) {
        bajas_no_identificadas <- append(bajas_no_identificadas, list(
          tibble::tibble(rubro = rubro_nombre, nro_activo = bajas_r$nro_activo,
                         descripcion = bajas_r$descripcion, valor = bajas_r$valor)
        ))
      }
      if (length(partes) > 0) {
        resultado[[rubro_nombre]] <- dplyr::bind_rows(partes)
      }
    }
  }

  datos_limpios$bajas_no_identificadas <- dplyr::bind_rows(bajas_no_identificadas)
  datos_limpios$inventario <- resultado
  datos_limpios
}

normalizar_movimiento_sap <- function(mov, rubro_nombre, tipo, anio_ejercicio) {
  vu_asignada <- obtener_vu_asignada(rubro_nombre)

  fecha_ref <- if (tipo == "transferencia") mov$cap_date_parsed 
  else mov$posting_date

  tibble::tibble(
    rubro = rubro_nombre,
    tipo_movimiento = tipo,
    tipo_movimiento_calc = tipo,
    subclasificacion_historico = NA_character_,
    nro_activo_fijo = as.character(mov$nro_activo),
    descripcion = as.character(mov$descripcion),
    fecha_alta = fecha_ref,
    anio_alta = lubridate::year(fecha_ref),
    mes_alta = lubridate::month(fecha_ref),
    # Las altas conservan el signo de SAP (las reversas restan): el Excel manual las netea, no las invierte.
    vo = mov$valor,
    valor_sap_original = mov$valor,
    direccion_movimiento = dplyr::case_when(
      tipo == "transferencia" & mov$valor < 0 ~ "salida",
      tipo == "transferencia" & mov$valor >= 0 ~ "entrada",
      TRUE ~ tipo
    ),
    importe_movimiento_control = mov$valor,
    vu_asignada = vu_asignada,
    vut_ly = NA_real_,
    anio_movimiento = anio_ejercicio,
    origen = paste0(tipo, "_", anio_ejercicio)
  )
}

normalizar_baja_sap <- function(bajas, rubro_nombre, anio_ejercicio) {
  vu_asignada <- obtener_vu_asignada(rubro_nombre)

  tibble::tibble(
    rubro = rubro_nombre,
    tipo_movimiento = "baja",
    tipo_movimiento_calc = "baja",
    subclasificacion_historico = NA_character_,
    nro_activo_fijo = as.character(bajas$nro_activo),
    descripcion = as.character(bajas$descripcion),
    fecha_alta = bajas$posting_date,
    fecha_baja = bajas$posting_date,
    anio_alta = lubridate::year(bajas$cap_date_parsed),
    mes_alta = lubridate::month(bajas$cap_date_parsed),
    vo = abs(bajas$valor),
    valor_sap_original = bajas$valor,
    direccion_movimiento = "salida",
    importe_movimiento_control = -abs(bajas$valor),
    vu_asignada = vu_asignada,
    vut_ly = NA_real_,
    anio_movimiento = anio_ejercicio,
    origen = paste0("baja_", anio_ejercicio)
  )
}
