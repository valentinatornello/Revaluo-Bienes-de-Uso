obtener_rutas_inputs <- function(inputs_dir = "inputs") {
  list(
    sap = file.path(inputs_dir, "SAP"),
    altas = file.path(inputs_dir, "altas"),
    bajas = file.path(inputs_dir, "bajas"),
    transferencias = file.path(inputs_dir, "transferencias"),
    parametros = file.path(inputs_dir, "parametros")
  )
}

HOJAS_CATEGORIAS <- c(
  "Cercos", "Edificios", "Terrenos", "Estructuras y caños",
  "Eq de Oficina", "Maquinas y Equipos", "Maquinas Mejoras",
  "MyU", "Rodados", "Terreno Mejoras", "Software"
)

FILAS_HEADER <- list(
  "Cercos"                = list(skip = 12, header_row = 13),
  "Edificios"             = list(skip = 16, header_row = 17),
  "Terrenos"              = list(skip = 4,  header_row = 5),
  "Estructuras y caños" = list(skip = 8,  header_row = 9),
  "Eq de Oficina"         = list(skip = 10, header_row = 11),
  "Maquinas y Equipos"    = list(skip = 9,  header_row = 10),
  "Maquinas Mejoras"      = list(skip = 10, header_row = 11),
  "MyU"                   = list(skip = 10, header_row = 11),
  "Rodados"               = list(skip = 9,  header_row = 10),
  "Terreno Mejoras"       = list(skip = 10, header_row = 11),
  "Software"              = list(skip = 10, header_row = 11)
)

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

  # arrancamos despues del header para no incluirlo como dato
  datos <- raw[(config_hoja$header_row + 1):nrow(raw), ]
  names(datos) <- col_names

  datos <- datos %>%
    dplyr::filter(!dplyr::if_all(dplyr::everything(), is.na))

  datos$rubro <- hoja
  datos
}

leer_indices_ipim <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPIM", col_names = TRUE)
  d <- d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(
      fecha = 1,
      ipim_periodo = 2,
      ipim_actual = 3,
      coeficiente = 4
    ) %>%
    dplyr::mutate(
      fecha = as.Date(fecha),
      ipim_periodo = as.numeric(ipim_periodo),
      ipim_actual = as.numeric(ipim_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))

  d
}

leer_indices_ipc <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPC", col_names = FALSE)
  d <- d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(
      fecha = 1,
      ipc_periodo = 2,
      ipc_actual = 3,
      coeficiente = 4
    ) %>%
    dplyr::mutate(
      fecha = as.Date(fecha),
      ipc_periodo = as.numeric(ipc_periodo),
      ipc_actual = as.numeric(ipc_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))

  d
}

leer_indices_ipim_bajas <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPIM - VR Bajas", col_names = TRUE)
  d <- d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(
      fecha = 1,
      ipim_periodo = 2,
      ipim_actual = 3,
      coeficiente = 4
    ) %>%
    dplyr::mutate(
      fecha = as.Date(fecha),
      ipim_periodo = as.numeric(ipim_periodo),
      ipim_actual = as.numeric(ipim_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))

  d
}

leer_indices_ipc_bajas <- function(path_excel) {
  d <- readxl::read_excel(path_excel, sheet = "IPC - VR Bajas", col_names = FALSE)
  d <- d %>%
    dplyr::select(1:4) %>%
    dplyr::rename(
      fecha = 1,
      ipc_periodo = 2,
      ipc_actual = 3,
      coeficiente = 4
    ) %>%
    dplyr::mutate(
      fecha = as.Date(fecha),
      ipc_periodo = as.numeric(ipc_periodo),
      ipc_actual = as.numeric(ipc_actual),
      coeficiente = as.numeric(coeficiente)
    ) %>%
    dplyr::filter(!is.na(fecha))

  d
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

importar_datos <- function(path_excel_ly, inputs_dir = "inputs") {
  rutas <- obtener_rutas_inputs(inputs_dir)

  inventario_ly <- leer_inventario_categorias(path_excel_ly)
  indices_ipc <- leer_indices_ipc(path_excel_ly)
  indices_ipim <- leer_indices_ipim(path_excel_ly)
  indices_ipc_bajas <- leer_indices_ipc_bajas(path_excel_ly)
  indices_ipim_bajas <- leer_indices_ipim_bajas(path_excel_ly)

  archivos_altas <- list.files(rutas$altas, pattern = "\\.xlsx$", full.names = TRUE)
  altas <- if (length(archivos_altas) > 0) {
    purrr::map_dfr(archivos_altas, ~ readxl::read_excel(.x) %>% janitor::clean_names())
  } else {
    tibble::tibble()
  }

  archivos_bajas <- list.files(rutas$bajas, pattern = "\\.xlsx$", full.names = TRUE)
  bajas <- if (length(archivos_bajas) > 0) {
    purrr::map_dfr(archivos_bajas, ~ readxl::read_excel(.x) %>% janitor::clean_names())
  } else {
    tibble::tibble()
  }

  archivos_transf <- list.files(rutas$transferencias, pattern = "\\.xlsx$", full.names = TRUE)
  transferencias <- if (length(archivos_transf) > 0) {
    purrr::map_dfr(archivos_transf, ~ readxl::read_excel(.x) %>% janitor::clean_names())
  } else {
    tibble::tibble()
  }

  list(
    inventario_ly    = inventario_ly,
    indices_ipc      = indices_ipc,
    indices_ipim     = indices_ipim,
    indices_ipc_bajas = indices_ipc_bajas,
    indices_ipim_bajas = indices_ipim_bajas,
    altas            = altas,
    bajas            = bajas,
    transferencias   = transferencias
  )
}
