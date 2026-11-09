obtener_rutas_inputs <- function(inputs_dir = "inputs") {
  list(
    sap = file.path(inputs_dir, "SAP"),
    parametros = file.path(inputs_dir, "parametros")
  )
}
obtener_rutas_inputs()

leer_excepciones_fecha_base <- function(path_parametros) {
  path_csv <- file.path(path_parametros, "excepciones_fecha_base.csv")

  if (!file.exists(path_csv)) {
    return(SCHEMA_EXCEPCIONES_FECHA_BASE)
  }

  readr::read_csv(path_csv, show_col_types = FALSE) %>%
    dplyr::transmute(
      rubro = as.character(rubro),
      nro_activo_fijo = normalizar_clave_activo(nro_activo_fijo),
      fecha_base_reexpresion = as.Date(fecha_base_reexpresion),
      inicio_indice_desde = as.Date(inicio_indice_desde),
      motivo = as.character(motivo),
      fuente_manual = as.character(fuente_manual),
      activo = dplyr::coalesce(as.logical(activo), TRUE)
    )
}

HOJAS_CATEGORIAS <- c(
  "Cercos", "Edificios", "Terrenos", "Estructuras y caños",
  "Eq de Oficina", "Maquinas y Equipos", "Maquinas Mejoras",
  "MyU", "Rodados", "Terreno Mejoras", "Software"
)

FILAS_HEADER <- list(
  "Cercos"              = list(skip = 13, header_row = 13),
  "Edificios"           = list(skip = 16, header_row = 16),
  "Terrenos"            = list(skip = 5,  header_row = 5),
  "Estructuras y caños" = list(skip = 9,  header_row = 9),
  "Eq de Oficina"       = list(skip = 11, header_row = 11),
  "Maquinas y Equipos"  = list(skip = 10, header_row = 10),
  "Maquinas Mejoras"    = list(skip = 10, header_row = 10),
  "MyU"                 = list(skip = 12, header_row = 12),
  "Rodados"             = list(skip = 9,  header_row = 9),
  "Terreno Mejoras"     = list(skip = 9,  header_row = 9),
  "Software"            = list(skip = 9,  header_row = 9)
)

CLASS_A_RUBRO <- c(
  "110LA" = "Terrenos",
  "130LA" = "Terreno Mejoras",
  "210LA" = "Edificios",
  "220LA" = "Edificios",
  "250LA" = "Terreno Mejoras",
  "310LA" = "Maquinas y Equipos",
  "320LA" = "Eq de Oficina",
  "330LA" = "MyU",
  "350LA" = "Maquinas y Equipos",
  "360LA" = "Rodados",
  "370LA" = "Maquinas Mejoras",
  "392LA" = "Edificios",
  "510LA" = "Software",
  "515LA" = "Software",
  "610LA" = "Software",
  "600LA" = "Obras en curso"
)

parsear_fecha_ddmmyyyy <- function(x) {
  if (all(is.na(x))) return(as.Date(NA))
  as.Date(x, format = "%d.%m.%Y")
}

# parsea fechas de las hojas de indices, tolerando filas de encabezado/placeholder
# y seriales de Excel guardados como texto (ej. "43101") sin romper el vector entero
parsear_fecha_indice <- function(x) {
  if (inherits(x, c("Date", "POSIXct"))) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))

  convertir_uno <- function(v) {
    if (is.na(v)) return(as.Date(NA))
    numerico <- suppressWarnings(as.numeric(v))
    if (!is.na(numerico)) return(as.Date(numerico, origin = "1899-12-30"))
    tryCatch(as.Date(as.character(v)), error = function(e) as.Date(NA))
  }

  do.call(c, lapply(x, convertir_uno))
}

leer_hoja_categoria <- function(path_excel, hoja, config_hoja = NULL) {
  if (is.null(config_hoja)) {
    config_hoja <- FILAS_HEADER[[hoja]]
  }
  if (is.null(config_hoja)) {
    config_hoja <- list(skip = 0, header_row = 1)
  }

  raw <- readxl::read_excel(
    path_excel,
    sheet = hoja,
    col_names = FALSE,
    col_types = "text",
    .name_repair = "minimal"
  )

  # si no hay filas despues del header, no hay datos

  if (nrow(raw) <= config_hoja$header_row) {
    return(tibble::tibble())
  }

  header_row <- raw[config_hoja$header_row, ]
  col_names <- as.character(header_row)
  col_names[is.na(col_names) | col_names == ""] <- paste0("col_", which(is.na(col_names) | col_names == ""))
  col_names <- make.unique(col_names, sep = "_")

  # arrancamos despues del header para no incluirlo como dato
  datos <- raw[(config_hoja$header_row + 1):nrow(raw), ]
  names(datos) <- col_names

  cols_no_vacias <- purrr::map_lgl(datos, ~ !all(is.na(.x)))
  datos <- datos[, cols_no_vacias]

  datos <- datos %>%
    dplyr::filter(!dplyr::if_all(dplyr::everything(), is.na))

  datos$rubro <- hoja
  datos
}

leer_indices_ipim <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPIM", col_names = TRUE)
  d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(fecha = 1, ipim_periodo = 2, ipim_actual = 3, coeficiente = 4) %>%
    dplyr::mutate(
      fecha = parsear_fecha_indice(fecha),
      ipim_periodo = as.numeric(ipim_periodo),
      ipim_actual = as.numeric(ipim_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))
}

leer_indices_ipc <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPC", col_names = FALSE)
  d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(fecha = 1, ipc_periodo = 2, ipc_actual = 3, coeficiente = 4) %>%
    dplyr::mutate(
      fecha = parsear_fecha_indice(fecha),
      ipc_periodo = as.numeric(ipc_periodo),
      ipc_actual = as.numeric(ipc_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))
}

leer_indices_ipim_bajas <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPIM - VR Bajas", col_names = TRUE)
  d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(fecha = 1, ipim_periodo = 2, ipim_actual = 3, coeficiente = 4) %>%
    dplyr::mutate(
      fecha = parsear_fecha_indice(fecha),
      ipim_periodo = as.numeric(ipim_periodo),
      ipim_actual = as.numeric(ipim_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))
}

leer_indices_ipc_bajas <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPC - VR Bajas", col_names = FALSE)
  d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(fecha = 1, ipc_periodo = 2, ipc_actual = 3, coeficiente = 4) %>%
    dplyr::mutate(
      fecha = parsear_fecha_indice(fecha),
      ipc_periodo = as.numeric(ipc_periodo),
      ipc_actual = as.numeric(ipc_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))
}

leer_inventario_categorias <- function(path_excel) {
  categorias <- list()
  for (hoja in HOJAS_CATEGORIAS) {
    tryCatch({
      datos <- leer_hoja_categoria(path_excel, hoja)
      if (nrow(datos) > 0) {
        categorias[[hoja]] <- datos
      }
    }, error = function(e) {
      warning(sprintf("No se pudo leer la hoja '%s': %s", hoja, e$message))
    })
  }
  categorias
}

# lee las hojas PG / PG AXI del excel real (KPMG/Price) para validar contra el calculo propio.
# soporta dos layouts: el del manual (rubros como encabezados de columna, magnitud en fila fija)
# y el tabular (columna 'rubro' + una columna por magnitud, como el export propio)
leer_pg_real <- function(path_excel) {
  if (!file.exists(path_excel)) {
    stop(sprintf("el archivo '%s' no existe o no pudo guardarse", path_excel), call. = FALSE)
  }

  rubros <- PARAMETROS_RUBROS$rubro
  hojas_disponibles <- readxl::excel_sheets(path_excel)

  leer_hoja <- function(hoja) {
    if (!hoja %in% hojas_disponibles) {
      stop(sprintf(
        "el archivo '%s' no tiene la hoja '%s'; se necesitan las hojas 'PG' y 'PG AXI' (hojas encontradas: %s)",
        basename(path_excel), hoja, paste(hojas_disponibles, collapse = ", ")
      ), call. = FALSE)
    }
    readxl::read_excel(path_excel, sheet = hoja, col_names = FALSE, .name_repair = "minimal")
  }

  # celda vacia de un rubro presente = 0; rubro ausente en el archivo = NA (se reporta como advertencia)
  a_numerico <- function(x, pos) {
    valores <- suppressWarnings(as.numeric(x[pos]))
    valores[!is.na(pos) & is.na(valores)] <- 0
    stats::setNames(valores, rubros)
  }

  ubicar_rubros_en_columnas <- function(d) {
    for (i in seq_len(nrow(d))) {
      pos <- match(rubros, canonizar_rubro(unlist(d[i, ], use.names = FALSE)))
      if (sum(!is.na(pos)) >= length(rubros) / 2) {
        return(pos)
      }
    }
    NULL
  }

  extraer_serie_tabular <- function(d, magnitud) {
    objetivo <- normalizar_etiqueta(magnitud)
    for (i in seq_len(max(nrow(d) - 1L, 0L))) {
      encabezado <- normalizar_etiqueta(unlist(d[i, ], use.names = FALSE))
      col_valor <- match(objetivo, encabezado)
      col_rubro <- match("rubro", encabezado)
      if (is.na(col_valor) || is.na(col_rubro)) next
      cuerpo <- d[seq(i + 1L, nrow(d)), , drop = FALSE]
      pos <- match(rubros, canonizar_rubro(cuerpo[[col_rubro]]))
      if (all(is.na(pos))) next
      return(a_numerico(cuerpo[[col_valor]], pos))
    }
    NULL
  }

  # la fila de cada magnitud se busca por etiqueta (la posicion cambia de un anio a otro: en el manual 2022
  # "s/revaluo" esta en la fila 21 y en el 2023 en la 20); la fila fija queda como respaldo
  extraer_serie <- function(hoja, fila, magnitud, patron_etiqueta = NULL) {
    d <- leer_hoja(hoja)
    cols <- ubicar_rubros_en_columnas(d)
    if (!is.null(cols) && nrow(d) >= fila) {
      if (!is.null(patron_etiqueta)) {
        etiquetas <- apply(d, 1, function(x) { v <- x[!is.na(x)]; if (length(v)) as.character(v[1]) else "" })
        fila_etiqueta <- which(grepl(patron_etiqueta, etiquetas, ignore.case = TRUE))[1]
        if (!is.na(fila_etiqueta)) fila <- fila_etiqueta
      }
      return(a_numerico(unlist(d[fila, ], use.names = FALSE), cols))
    }
    serie <- extraer_serie_tabular(d, magnitud)
    if (!is.null(serie)) return(serie)
    stop(sprintf(
      paste0(
        "en el archivo '%s' no se reconoce el formato de la hoja '%s' (%d filas x %d columnas): ",
        "se esperaban los rubros como encabezados de columna con los valores en la fila %d, ",
        "o una columna 'rubro' junto a una columna '%s'"
      ),
      basename(path_excel), hoja, nrow(d), ncol(d), fila, magnitud
    ), call. = FALSE)
  }

  # "Amortizacion s/revaluo" del manual es la amortizacion DEL EJERCICIO (suma de "Amort. Historica"),
  # no la acumulada; "Valor residual s/revaluo" es el VR al cierre.
  patron_amort <- "^Amortizaci.n s/ ?rev"
  patron_vr <- "^Valor residual *s?/ ?rev"
  vr_revaluo <- extraer_serie("PG", 35, "vr_revaluo", patron_vr)
  vr_revaluo_reexp <- extraer_serie("PG AXI", 36, "vr_reexp", patron_vr)

  list(
    amort_revaluo = extraer_serie("PG", 19, "amort_revaluo", patron_amort),
    # amortizacion reexpresada del ejercicio (PG AXI); NULL si el archivo no la trae (exportaciones antiguas)
    amort_reexp_revaluo = tryCatch(
      extraer_serie("PG AXI", 20, "amort_ejercicio_reexp", patron_amort),
      error = function(e) NULL
    ),
    vr_revaluo = vr_revaluo,
    axi_resultado = vr_revaluo_reexp - vr_revaluo
  )
}

# busca el excel de validacion (manual de Price/KPMG) para un anio, excluyendo el archivo
# usado como input LY y los propios outputs del pipeline (MARG_Revaluo_AXI_*)
buscar_archivo_real <- function(anio_ejercicio, dir_parametros = file.path("inputs", "parametros")) {
  archivos <- list.files(dir_parametros, pattern = as.character(anio_ejercicio), full.names = TRUE)
  archivos <- archivos[grepl("\\.xlsx$", archivos, ignore.case = TRUE)]
  archivos <- archivos[!grepl("_v_", archivos)]
  archivos <- archivos[!grepl("^MARG_Revaluo_AXI", basename(archivos))]
  if (length(archivos) == 0) return(NA_character_)
  archivos[1]
}

leer_movimientos_sap <- function(path_sap, anio_ejercicio = NULL) {
  altas_excel <- readxl::read_excel(path_sap, sheet = "Altas")
  bajas_excel <- readxl::read_excel(path_sap, sheet = "Bajas")
  transf_excel <- readxl::read_excel(path_sap, sheet = "Transferencias")

  altas_raw <- altas_excel %>%
    janitor::clean_names() %>%
    dplyr::rename(
      nro_activo = asset,
      cap_date = cap_date,
      posting_date = pstng_date,
      descripcion = asset_description2,
      class = class,
      valor = suma_de_acquisition
    ) %>%
    dplyr::mutate(
      tipo_movimiento_sap = "alta",
      nro_activo = normalizar_clave_activo(nro_activo),
      posting_date = parsear_fecha_ddmmyyyy(posting_date),
      cap_date_parsed = parsear_fecha_ddmmyyyy(cap_date),
      valor = as.numeric(valor),
      rubro = dplyr::recode(class, !!!CLASS_A_RUBRO, .default = NA_character_)
    ) %>%
    dplyr::filter(
      es_fila_detalle_sap(nro_activo),
      !is.na(rubro),
      rubro != "Obras en curso",
      !grepl("^AS", nro_activo, ignore.case = TRUE)
    )

  bajas_raw <- bajas_excel %>%
    janitor::clean_names() %>%
    dplyr::rename(
      nro_activo = asset,
      cap_date = cap_date,
      posting_date = pstng_date,
      descripcion = asset_description,
      class = class,
      valor = retirement
    ) %>%
    dplyr::mutate(
      tipo_movimiento_sap = "baja",
      nro_activo = normalizar_clave_activo(nro_activo),
      posting_date = parsear_fecha_ddmmyyyy(posting_date),
      cap_date_parsed = parsear_fecha_ddmmyyyy(cap_date),
      valor = as.numeric(valor),
      depr_retired = as.numeric(depr_retired),
      ret_book_value = as.numeric(ret_book_value),
      rubro = dplyr::recode(class, !!!CLASS_A_RUBRO, .default = NA_character_)
    ) %>%
    dplyr::filter(
      es_fila_detalle_sap(nro_activo),
      !is.na(rubro),
      rubro != "Obras en curso",
      !grepl("^AS", nro_activo, ignore.case = TRUE)
    )

  transf_raw <- transf_excel %>%
    janitor::clean_names() %>%
    dplyr::rename(
      nro_activo = asset,
      cap_date = cap_date,
      posting_date = pstng_date,
      descripcion = asset_description2,
      class = class,
      valor = suma_de_transfer
    ) %>%
    dplyr::mutate(
      tipo_movimiento_sap = "transferencia",
      nro_activo = normalizar_clave_activo(nro_activo),
      posting_date = parsear_fecha_ddmmyyyy(posting_date),
      cap_date_parsed = parsear_fecha_ddmmyyyy(cap_date),
      valor = as.numeric(valor),
      transf_dep = as.numeric(suma_de_trans_o_dep),
      rubro = dplyr::recode(class, !!!CLASS_A_RUBRO, .default = NA_character_)
    ) %>%
    dplyr::filter(
      es_fila_detalle_sap(nro_activo),
      !is.na(rubro),
      rubro != "Obras en curso",
      !grepl("^AS", nro_activo, ignore.case = TRUE)
    )

  # filas_detalle cuenta las filas de detalle del archivo SAP antes de filtrar por rubro (el conteo esperado
  # es el del archivo); filas_importadas son las que quedan tras excluir rubros fuera de tabla, obras en curso e IFRS 16.
  contar_detalle <- function(hoja) {
    sum(es_fila_detalle_sap(janitor::clean_names(hoja)$asset))
  }
  conteos_anio <- if (is.null(anio_ejercicio)) {
    CONTEOS_MOVIMIENTOS_ESPERADOS[0, c("tipo_movimiento_sap", "conteo_esperado")]
  } else {
    dplyr::filter(CONTEOS_MOVIMIENTOS_ESPERADOS, anio == anio_ejercicio) %>%
      dplyr::select(tipo_movimiento_sap, conteo_esperado)
  }
  auditoria_movimientos <- tibble::tibble(
    tipo_movimiento_sap = c("alta", "baja", "transferencia"),
    filas_fuente = c(nrow(altas_excel), nrow(bajas_excel), nrow(transf_excel)),
    filas_detalle = c(contar_detalle(altas_excel), contar_detalle(bajas_excel), contar_detalle(transf_excel)),
    filas_importadas = c(nrow(altas_raw), nrow(bajas_raw), nrow(transf_raw)),
    filas_excluidas = filas_detalle - filas_importadas
  ) %>%
    dplyr::left_join(conteos_anio, by = "tipo_movimiento_sap") %>%
    dplyr::mutate(diferencia_conteo = filas_detalle - conteo_esperado)

  list(
    altas = altas_raw,
    bajas = bajas_raw,
    transferencias = transf_raw,
    auditoria_movimientos = auditoria_movimientos
  )
}

# Elige el archivo SAP del ejercicio: el indicado explicitamente, o el que lleva el anio en el nombre
# (ej. "Altas-bajas-Transf 12-2023 (Tax).xlsx"); si ninguno lo lleva, el mas reciente. Si el nombre trae otro
# anio se frena: sumar los movimientos de otro ejercicio duplica o pierde movimientos sin avisar.
elegir_archivo_sap <- function(dir_sap, anio_ejercicio = NULL, path_sap = NULL) {
  if (is.null(path_sap)) {
    archivos <- list.files(dir_sap, pattern = "\\.xlsx$", full.names = TRUE)
    archivos <- archivos[!grepl("^~\\$", basename(archivos))]
    if (length(archivos) == 0) return(NA_character_)
    con_anio <- if (is.null(anio_ejercicio)) archivos[0] else
      archivos[grepl(as.character(anio_ejercicio), basename(archivos), fixed = TRUE)]
    candidatos <- if (length(con_anio) > 0) con_anio else archivos
    path_sap <- candidatos[order(file.mtime(candidatos), decreasing = TRUE)][1]
  }
  if (!is.null(anio_ejercicio)) {
    anios_nombre <- as.integer(regmatches(basename(path_sap), gregexpr("20[0-9]{2}", basename(path_sap)))[[1]])
    if (length(anios_nombre) > 0 && !anio_ejercicio %in% anios_nombre) {
      stop(sprintf(
        paste0("El archivo SAP '%s' parece ser del ejercicio %s y se esta calculando %d. ",
               "Subi el 'Altas-bajas-Transf' del ejercicio %d."),
        basename(path_sap), paste(unique(anios_nombre), collapse = "/"), anio_ejercicio, anio_ejercicio
      ), call. = FALSE)
    }
  }
  path_sap
}

# Las altas y transferencias del ejercicio se reexpresan con el IPC del mes de alta: si la tabla no llega al
# cierre del ejercicio esos bienes toman coeficiente 1 (el ultimo valor disponible) sin ningun aviso.
validar_cobertura_ipc <- function(indices_ipc, anio_ejercicio) {
  cierre <- as.Date(sprintf("%d-12-31", anio_ejercicio))
  ultimo <- suppressWarnings(max(indices_ipc$fecha, na.rm = TRUE))
  if (!is.finite(as.numeric(ultimo)) || ultimo < cierre) {
    stop(sprintf(
      paste0("La tabla IPC llega hasta %s y el ejercicio %d cierra el %s. ",
             "Copia un Excel con las hojas 'IPC' e 'IPC - VR Bajas' a inputs/parametros/indices_ipc_%d.xlsx."),
      format(ultimo), anio_ejercicio, format(cierre), anio_ejercicio
    ), call. = FALSE)
  }
  invisible(TRUE)
}

importar_datos <- function(path_excel_ly, inputs_dir = "inputs", anio_ejercicio = NULL, path_sap = NULL) {
  rutas <- obtener_rutas_inputs(inputs_dir)

  inventario_ly <- leer_inventario_categorias(path_excel_ly)
  indices_ipim <- leer_indices_ipim(path_excel_ly)
  indices_ipim_bajas <- leer_indices_ipim_bajas(path_excel_ly)
  # Los indices IPC del ejercicio (hasta el 31/12 del anio) no estan en el Excel del anio anterior: si existe
  # inputs/parametros/indices_ipc_<anio>.xlsx (hojas "IPC" y "IPC - VR Bajas") se usan esos.
  path_indices <- if (!is.null(anio_ejercicio)) {
    file.path(rutas$parametros, sprintf("indices_ipc_%d.xlsx", anio_ejercicio))
  } else {
    NA_character_
  }
  if (!is.na(path_indices) && file.exists(path_indices)) {
    indices_ipc <- leer_indices_ipc(path_indices)
    indices_ipc_bajas <- leer_indices_ipc_bajas(path_indices)
  } else {
    indices_ipc <- leer_indices_ipc(path_excel_ly)
    indices_ipc_bajas <- leer_indices_ipc_bajas(path_excel_ly)
  }
  if (!is.null(anio_ejercicio)) validar_cobertura_ipc(indices_ipc, anio_ejercicio)
  excepciones_fecha_base <- leer_excepciones_fecha_base(rutas$parametros)

  archivo_sap <- elegir_archivo_sap(rutas$sap, anio_ejercicio, path_sap)

  if (!is.na(archivo_sap)) {
    movimientos <- leer_movimientos_sap(archivo_sap, anio_ejercicio)
  } else {
    movimientos <- list(
      altas = tibble::tibble(),
      bajas = tibble::tibble(),
      transferencias = tibble::tibble(),
      auditoria_movimientos = tibble::tibble()
    )
  }

  list(
    inventario_ly      = inventario_ly,
    indices_ipc        = indices_ipc,
    indices_ipim       = indices_ipim,
    indices_ipc_bajas  = indices_ipc_bajas,
    indices_ipim_bajas = indices_ipim_bajas,
    excepciones_fecha_base = excepciones_fecha_base,
    archivo_sap        = if (is.na(archivo_sap)) NA_character_ else basename(archivo_sap),
    altas              = movimientos$altas,
    bajas              = movimientos$bajas,
    transferencias     = movimientos$transferencias,
    auditoria_movimientos = movimientos$auditoria_movimientos
  )
}
