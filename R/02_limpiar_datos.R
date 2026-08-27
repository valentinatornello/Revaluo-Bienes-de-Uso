COLUMNAS_ESTANDAR <- c(
  "tipo_movimiento", "tipo_movimiento_calc", "subclasificacion_historico",
  "nro_activo_fijo", "descripcion",
  "anio_archivo", "fecha_alta", "anio_alta", "mes_alta",
  "vo", "vu_asignada", "vut_ly", "vut_ejercicio", "vut_cierre",
  "vu_restante", "rubro"
)

normalizar_hoja_categoria <- function(datos, rubro, anio_ejercicio) {
  if (nrow(datos) == 0) return(tibble::tibble())

  col_lower <- tolower(names(datos))

  idx_nro <- grep("activo.?fijo|n.*activo", col_lower)[1]
  idx_desc <- grep("descrip|denominaci", col_lower)[1]
  idx_fecha_archivo <- grep("a.*o.*archivo|a.*o.*cia|fe.*capit", col_lower)[1]
  idx_fecha_tomar <- grep("a.*o.*tomar", col_lower)[1]
  idx_anio_alta <- grep("^a.*o.*alta$", col_lower)[1]
  idx_mes_alta <- grep("mes.*alta", col_lower)[1]
  idx_vo <- grep("^vo$|val.*adq|val.*origen$", col_lower)[1]
  idx_vu_asig <- grep("vu.*asignada", col_lower)[1]
  idx_vut_ly <- grep("vut.*ly|vut.*l.*y", col_lower)[1]

  n <- nrow(datos)
  resultado <- tibble::tibble(rubro = rep(rubro, n))

  # tipo_movimiento_calc conserva la clasificacion original detectada en la hoja (uso interno de calculo,
  # p.ej. congelar amortizacion de bajas sin importar el anio en que ocurrieron).
  resultado$tipo_movimiento_calc <- detectar_tipo_movimiento(datos, rubro)
  resultado$anio_movimiento <- extraer_anio_movimiento(datos)

  # tipo_movimiento (para tabla/exportacion): todo lo que viene del excel LY y no es del
  # ejercicio actual se identifica como "historico"; altas/bajas/transferencias solo se
  # muestran como tales cuando corresponden al anio_ejercicio en curso.
  es_movimiento_clasificado <- resultado$tipo_movimiento_calc %in% c("alta", "transferencia", "baja", "alta_y_baja")
  es_del_ejercicio_actual <- !is.na(resultado$anio_movimiento) & resultado$anio_movimiento == anio_ejercicio

  resultado$tipo_movimiento <- dplyr::if_else(
    es_movimiento_clasificado & !es_del_ejercicio_actual,
    "historico",
    resultado$tipo_movimiento_calc
  )
  resultado$subclasificacion_historico <- dplyr::if_else(
    es_movimiento_clasificado & !es_del_ejercicio_actual,
    resultado$tipo_movimiento_calc,
    NA_character_
  )

  resultado$nro_activo_fijo <- if (!is.na(idx_nro)) {
    as.character(datos[[idx_nro]])
  } else {
    NA_character_
  }

  resultado$descripcion <- if (!is.na(idx_desc)) {
    as.character(datos[[idx_desc]])
  } else {
    NA_character_
  }

  if (!is.na(idx_fecha_tomar)) {
    fecha_raw <- datos[[idx_fecha_tomar]]
  } else if (!is.na(idx_fecha_archivo)) {
    fecha_raw <- datos[[idx_fecha_archivo]]
  } else {
    fecha_raw <- NA
  }

  resultado$fecha_alta <- parsear_fecha_alta(fecha_raw)
  resultado$anio_alta <- if (!is.na(idx_anio_alta)) {
    as.integer(datos[[idx_anio_alta]])
  } else {
    lubridate::year(resultado$fecha_alta)
  }
  resultado$mes_alta <- if (!is.na(idx_mes_alta)) {
    as.integer(datos[[idx_mes_alta]])
  } else {
    lubridate::month(resultado$fecha_alta)
  }

  resultado$vo <- if (!is.na(idx_vo)) {
    as.numeric(datos[[idx_vo]])
  } else {
    NA_real_
  }

  vu_rubro <- obtener_vu_asignada(rubro)
  resultado$vu_asignada <- if (!is.na(idx_vu_asig)) {
    vu_archivo <- as.numeric(datos[[idx_vu_asig]])
    if (rubro == "Edificios") vu_archivo else vu_archivo / 4
  } else {
    vu_rubro
  }

  resultado$vut_ly <- if (!is.na(idx_vut_ly)) {
    as.numeric(datos[[idx_vut_ly]])
  } else {
    NA_real_
  }

  resultado
}

detectar_tipo_movimiento <- function(datos, rubro) {
  primera_col <- tolower(as.character(datos[[1]]))
  dplyr::case_when(
    grepl("^totales", primera_col)                                 ~ "totales",
    grepl("^altas? y baja", primera_col)                           ~ "alta_y_baja",
    grepl("^altas?\\b", primera_col)                               ~ "alta",
    grepl("^transferencias?\\b", primera_col)                      ~ "transferencia",
    grepl("^bajas?\\b", primera_col)                               ~ "baja",
    grepl("^(ojo|ver|solo|destinado)", primera_col)                ~ "nota",
    !is.na(primera_col) & grepl("^[0-9.]+$", primera_col)         ~ "nota",
    TRUE                                                           ~ "historico"
  )
}

extraer_anio_movimiento <- function(datos) {
  primera_col <- as.character(datos[[1]])
  anio_str <- stringr::str_extract(primera_col, "\\d{4}")
  as.integer(anio_str)
}

parsear_fecha_alta <- function(fecha_raw) {
  if (all(is.na(fecha_raw))) return(as.Date(NA))

  if (is.numeric(fecha_raw)) {
    as.Date(as.numeric(fecha_raw), origin = "1899-12-30")
  } else if (inherits(fecha_raw, "POSIXct") || inherits(fecha_raw, "Date")) {
    as.Date(fecha_raw)
  } else {
    tryCatch(
      as.Date(as.numeric(as.character(fecha_raw)), origin = "1899-12-30"),
      warning = function(w) as.Date(as.character(fecha_raw)),
      error = function(e) as.Date(NA)
    )
  }
}

filtrar_ifrs16 <- function(datos) {
  if (!"nro_activo_fijo" %in% names(datos)) return(datos)
  datos %>%
    dplyr::filter(
      is.na(nro_activo_fijo) |
      !grepl("^AS", nro_activo_fijo, ignore.case = TRUE)
    )
}

limpiar_datos <- function(datos, anio_ejercicio = 2022) {
  inventario_ly <- datos$inventario_ly

  inventario_limpio <- list()

  for (rubro_nombre in names(inventario_ly)) {
    raw <- inventario_ly[[rubro_nombre]]
    if (is.null(raw) || nrow(raw) == 0) next

    limpio <- normalizar_hoja_categoria(raw, rubro_nombre, anio_ejercicio)
    limpio <- filtrar_ifrs16(limpio)
    limpio <- limpio %>%
      dplyr::filter(
        !tipo_movimiento %in% c("totales", "nota"),
        !is.na(vo) | !is.na(nro_activo_fijo)
      )

    inventario_limpio[[rubro_nombre]] <- limpio
  }

  datos$inventario_ly <- inventario_limpio
  datos
}
