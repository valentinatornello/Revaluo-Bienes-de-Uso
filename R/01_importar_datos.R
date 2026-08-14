obtener_rutas_inputs <- function(inputs_dir = "inputs") {
  list(
    sap = file.path(inputs_dir, "SAP"),
    parametros = file.path(inputs_dir, "parametros")
  )
}
obtener_rutas_inputs()

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
      fecha = as.Date(fecha),
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
      fecha = as.Date(fecha),
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
      fecha = as.Date(fecha),
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
      fecha = as.Date(fecha),
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

leer_movimientos_sap <- function(path_sap) {
  altas_raw <- readxl::read_excel(path_sap, sheet = "Altas") %>%
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
      posting_date = parsear_fecha_ddmmyyyy(posting_date),
      cap_date_parsed = parsear_fecha_ddmmyyyy(cap_date),
      valor = as.numeric(valor),
      rubro = dplyr::recode(class, !!!CLASS_A_RUBRO, .default = NA_character_)
    ) %>%
    dplyr::filter(
      !is.na(rubro),
      rubro != "Obras en curso",
      !grepl("^AS", nro_activo, ignore.case = TRUE)
    )

  bajas_raw <- readxl::read_excel(path_sap, sheet = "Bajas") %>%
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
      posting_date = parsear_fecha_ddmmyyyy(posting_date),
      cap_date_parsed = parsear_fecha_ddmmyyyy(cap_date),
      valor = as.numeric(valor),
      depr_retired = as.numeric(depr_retired),
      rubro = dplyr::recode(class, !!!CLASS_A_RUBRO, .default = NA_character_)
    ) %>%
    dplyr::filter(
      !is.na(rubro),
      rubro != "Obras en curso",
      !grepl("^AS", nro_activo, ignore.case = TRUE)
    )

  transf_raw <- readxl::read_excel(path_sap, sheet = "Transferencias") %>%
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
      posting_date = parsear_fecha_ddmmyyyy(posting_date),
      cap_date_parsed = parsear_fecha_ddmmyyyy(cap_date),
      valor = as.numeric(valor),
      transf_dep = as.numeric(suma_de_trans_o_dep),
      rubro = dplyr::recode(class, !!!CLASS_A_RUBRO, .default = NA_character_)
    ) %>%
    dplyr::filter(
      !is.na(rubro),
      rubro != "Obras en curso",
      !grepl("^AS", nro_activo, ignore.case = TRUE)
    )

  list(
    altas = altas_raw,
    bajas = bajas_raw,
    transferencias = transf_raw
  )
}

importar_datos <- function(path_excel_ly, inputs_dir = "inputs") {
  rutas <- obtener_rutas_inputs(inputs_dir)

  inventario_ly <- leer_inventario_categorias(path_excel_ly)
  indices_ipc <- leer_indices_ipc(path_excel_ly)
  indices_ipim <- leer_indices_ipim(path_excel_ly)
  indices_ipc_bajas <- leer_indices_ipc_bajas(path_excel_ly)
  indices_ipim_bajas <- leer_indices_ipim_bajas(path_excel_ly)

  archivos_sap <- list.files(rutas$sap, pattern = "\\.xlsx$", full.names = TRUE)
  archivos_sap <- archivos_sap[!grepl("^~\\$", basename(archivos_sap))]

  if (length(archivos_sap) > 0) {
    movimientos <- leer_movimientos_sap(archivos_sap[1])
  } else {
    movimientos <- list(
      altas = tibble::tibble(),
      bajas = tibble::tibble(),
      transferencias = tibble::tibble()
    )
  }

  list(
    inventario_ly      = inventario_ly,
    indices_ipc        = indices_ipc,
    indices_ipim       = indices_ipim,
    indices_ipc_bajas  = indices_ipc_bajas,
    indices_ipim_bajas = indices_ipim_bajas,
    altas              = movimientos$altas,
    bajas              = movimientos$bajas,
    transferencias     = movimientos$transferencias
  )
}
