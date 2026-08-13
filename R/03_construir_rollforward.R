# construye el rollforward combinando inventario del año anterior con movimientos SAP del ejercicio

construir_rollforward <- function(datos_limpios, anio_ejercicio = 2022) {
  inventario <- datos_limpios$inventario_ly
  altas <- datos_limpios$altas
  bajas <- datos_limpios$bajas
  transferencias <- datos_limpios$transferencias

  resultado <- list()

  # armamos el set de categorias desde los rubros configurados Y el inventario historico
  rubros_config <- PARAMETROS_RUBROS$rubro
  rubros_inventario <- names(inventario)
  todos_rubros <- unique(c(rubros_config, rubros_inventario))

  for (rubro_nombre in todos_rubros) {
    inv_rubro <- inventario[[rubro_nombre]]

    # si no hay inventario previo para este rubro, inicializamos uno vacio
    if (is.null(inv_rubro) || nrow(inv_rubro) == 0) {
      inv_rubro <- tibble::tibble(
        rubro = character(),
        tipo_movimiento = character(),
        nro_activo_fijo = character(),
        descripcion = character(),
        fecha_alta = as.Date(character()),
        anio_alta = integer(),
        mes_alta = integer(),
        vo = numeric(),
        vu_asignada = numeric(),
        vut_ly = numeric(),
        origen = character()
      )
    } else {
      # normalizamos las filas del año anterior: las que eran movimientos previos
      # pasan a ser historicos para el ejercicio actual
      inv_rubro <- inv_rubro %>%
        dplyr::mutate(
          origen = dplyr::case_when(
            tipo_movimiento == "alta"           ~ paste0("alta_", anio_alta),
            tipo_movimiento == "transferencia"  ~ paste0("transferencia_", anio_alta),
            tipo_movimiento == "baja"           ~ paste0("baja_", anio_alta),
            TRUE                                ~ "historico"
          ),
          # las altas, transferencias y bajas de ejercicios anteriores ya son historico
          tipo_movimiento = dplyr::if_else(
            tipo_movimiento %in% c("alta", "transferencia") & anio_alta < anio_ejercicio,
            "historico",
            tipo_movimiento
          )
        ) %>%
        # sacamos las bajas de ejercicios previos porque ya estan dadas de baja
        dplyr::filter(!(tipo_movimiento == "baja" & anio_alta < anio_ejercicio))
    }

    # agregamos altas SAP del ejercicio actual
    if (nrow(altas) > 0) {
      altas_rubro <- filtrar_movimientos_por_rubro(altas, rubro_nombre)
      if (nrow(altas_rubro) > 0) {
        altas_norm <- normalizar_movimiento_sap(altas_rubro, rubro_nombre, "alta", anio_ejercicio)
        inv_rubro <- dplyr::bind_rows(inv_rubro, altas_norm)
      }
    }

    # agregamos transferencias SAP del ejercicio
    if (nrow(transferencias) > 0) {
      transf_rubro <- filtrar_movimientos_por_rubro(transferencias, rubro_nombre)
      if (nrow(transf_rubro) > 0) {
        transf_norm <- normalizar_movimiento_sap(transf_rubro, rubro_nombre, "transferencia", anio_ejercicio)
        inv_rubro <- dplyr::bind_rows(inv_rubro, transf_norm)
      }
    }

    # aplicamos bajas del ejercicio
    if (nrow(bajas) > 0) {
      bajas_rubro <- filtrar_movimientos_por_rubro(bajas, rubro_nombre)
      if (nrow(bajas_rubro) > 0) {
        inv_rubro <- aplicar_bajas(inv_rubro, bajas_rubro)
      }
    }

    # solo guardamos si quedo algo
    if (nrow(inv_rubro) > 0) {
      resultado[[rubro_nombre]] <- inv_rubro
    }
  }

  datos_limpios$inventario <- resultado
  datos_limpios
}

filtrar_movimientos_por_rubro <- function(movimientos, rubro_nombre) {
  params <- PARAMETROS_RUBROS %>%
    dplyr::filter(rubro == rubro_nombre)

  # si no hay parametros o no tiene codigos SAP, no podemos filtrar
  if (nrow(params) == 0 || is.na(params$codigos_sap) || params$codigos_sap == "") {
    return(tibble::tibble())
  }

  codigos <- trimws(unlist(strsplit(params$codigos_sap, ",")))

  col_clase <- grep("class|clase|codigo|asset_class", tolower(names(movimientos)), value = TRUE)
  if (length(col_clase) == 0) return(tibble::tibble())

  movimientos %>%
    dplyr::filter(.data[[col_clase[1]]] %in% codigos)
}

normalizar_movimiento_sap <- function(movimiento, rubro_nombre, tipo, anio_ejercicio = 2022) {
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

  # marcamos como baja tanto historicos como altas/transferencias del mismo ejercicio
  inventario %>%
    dplyr::mutate(
      es_baja = nro_activo_fijo %in% nros_baja,
      tipo_movimiento = dplyr::if_else(es_baja, "baja", tipo_movimiento)
    ) %>%
    dplyr::select(-es_baja)
}
