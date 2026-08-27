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

# lee las hojas PG / PG AXI del excel real (KPMG/Price) para validar contra el calculo propio
leer_pg_real <- function(path_excel) {
  if (!file.exists(path_excel)) return(NULL)

  rubros <- PARAMETROS_RUBROS$rubro
  cols <- 2:(length(rubros) + 1)

  extraer_fila <- function(hoja, fila) {
    hojas_disponibles <- readxl::excel_sheets(path_excel)
    if (!hoja %in% hojas_disponibles) {
      stop(sprintf(
        "El archivo real '%s' no tiene la hoja '%s' (hojas disponibles: %s)",
        basename(path_excel), hoja, paste(hojas_disponibles, collapse = ", ")
      ))
    }
    d <- readxl::read_excel(path_excel, sheet = hoja, col_names = FALSE, .name_repair = "minimal")
    if (nrow(d) < fila || ncol(d) < max(cols)) {
      stop(sprintf(
        "El archivo real '%s', hoja '%s', no tiene la fila/columnas esperadas (fila %d, columnas hasta %d)",
        basename(path_excel), hoja, fila, max(cols)
      ))
    }
    valores <- as.numeric(unlist(d[fila, cols]))
    valores[is.na(valores)] <- 0
    stats::setNames(valores, rubros)
  }

  vr_revaluo <- extraer_fila("PG", 35)
  vr_revaluo_reexp <- extraer_fila("PG AXI", 36)

  list(
    amort_revaluo = extraer_fila("PG", 19),
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

leer_movimientos_sap <- function(path_sap) {
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
      !grepl("^AS", nro_activo, ignore.case = TRUE),
      # Ret. book value (col. M) = Retirement (col. K) + Depr. retired (col. L).
      # Solo se reconoce la baja cuando el bien queda totalmente depreciado (M = 0).
      # PENDIENTE: consultar con Pablo el tratamiento de las filas con M != 0
      # (quedan excluidas del rollforward hasta esa definición).
      abs(ret_book_value) < 0.01
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

  auditoria_movimientos <- tibble::tibble(
    tipo_movimiento_sap = c("alta", "baja", "transferencia"),
    filas_fuente = c(nrow(altas_excel), nrow(bajas_excel), nrow(transf_excel)),
    filas_detalle = c(nrow(altas_raw), nrow(bajas_raw), nrow(transf_raw)),
    filas_excluidas = filas_fuente - filas_detalle
  ) %>%
    dplyr::left_join(CONTEOS_MOVIMIENTOS_ESPERADOS, by = "tipo_movimiento_sap") %>%
    dplyr::mutate(diferencia_conteo = filas_detalle - conteo_esperado)

  list(
    altas = altas_raw,
    bajas = bajas_raw,
    transferencias = transf_raw,
    auditoria_movimientos = auditoria_movimientos
  )
}

importar_datos <- function(path_excel_ly, inputs_dir = "inputs") {
  rutas <- obtener_rutas_inputs(inputs_dir)

  inventario_ly <- leer_inventario_categorias(path_excel_ly)
  indices_ipc <- leer_indices_ipc(path_excel_ly)
  indices_ipim <- leer_indices_ipim(path_excel_ly)
  indices_ipc_bajas <- leer_indices_ipc_bajas(path_excel_ly)
  indices_ipim_bajas <- leer_indices_ipim_bajas(path_excel_ly)
  excepciones_fecha_base <- leer_excepciones_fecha_base(rutas$parametros)

  archivos_sap <- list.files(rutas$sap, pattern = "\\.xlsx$", full.names = TRUE)
  archivos_sap <- archivos_sap[!grepl("^~\\$", basename(archivos_sap))]

  if (length(archivos_sap) > 0) {
    movimientos <- leer_movimientos_sap(archivos_sap[1])
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
    altas              = movimientos$altas,
    bajas              = movimientos$bajas,
    transferencias     = movimientos$transferencias,
    auditoria_movimientos = movimientos$auditoria_movimientos
  )
}
