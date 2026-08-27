check_required_packages <- function(
  packages = c(
    "tidyverse",
    "readxl",
    "openxlsx",
    "janitor",
    "lubridate",
    "readr",
    "targets"
  )
) {
  missing_packages <- packages[!vapply(packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]

  if (length(missing_packages) > 0) {
    stop(
      sprintf(
        "Faltan paquetes requeridos: %s",
        paste(missing_packages, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

PARAMETROS_RUBROS <- tibble::tribble(
  ~rubro,                ~codigos_sap,              ~vu_anios, ~vu_trimestres, ~indice, ~sheet_excel,
  "Cercos",              "",                         50,        200,           "IPC",   "Cercos",
  "Edificios",           "210LA,220LA,392LA",        50,        200,           "IPC",   "Edificios",
  "Terrenos",            "110LA",                    NA,          0,           "IPC",   "Terrenos",
  "Estructuras y caños", "",                         10,         40,           "IPC",   "Estructuras y caños",
  "Eq de Oficina",       "320LA",                     3,         12,           "IPC",   "Eq de Oficina",
  "Maquinas y Equipos",  "310LA,350LA",              10,         40,           "IPC",   "Maquinas y Equipos",
  "Maquinas Mejoras",    "370LA",                    10,         40,           "IPC",   "Maquinas Mejoras",
  "MyU",                 "330LA",                     3,         12,           "IPC",   "MyU",
  "Rodados",             "360LA",                     5,         20,           "IPC",   "Rodados",
  "Terreno Mejoras",     "130LA,250LA",              10,         40,           "IPC",   "Terreno Mejoras",
  "Software",            "510LA,515LA,610LA",         3,         12,           "IPC",   "Software"
)

ANIO_CORTE_REVALUO <- 2018

CONTEOS_MOVIMIENTOS_ESPERADOS <- tibble::tribble(
  ~tipo_movimiento_sap, ~conteo_esperado,
  "alta",              4873L,
  "baja",              1717L,
  "transferencia",     1738L
)

TOLERANCIA_PRUEBA_GLOBAL <- 1
UMBRAL_ERROR_PRUEBA_GLOBAL <- 100
TOLERANCIA_CONSISTENCIA_INTERNA <- 0.01
# tolerancia porcentual aceptada al comparar contra el manual real (Price/KPMG): 20% de diferencia = 80% de igualdad
TOLERANCIA_VALIDACION_EXTERNA <- 0.20

SCHEMA_EXCEPCIONES_FECHA_BASE <- tibble::tibble(
  rubro = character(),
  nro_activo_fijo = character(),
  fecha_base_reexpresion = as.Date(character()),
  inicio_indice_desde = as.Date(character()),
  motivo = character(),
  fuente_manual = character(),
  activo = logical()
)

normalizar_clave_activo <- function(x) {
  stringr::str_trim(as.character(x))
}

# minusculas, sin acentos ni puntuacion: permite comparar etiquetas de excel escritas de distinta forma
normalizar_etiqueta <- function(x) {
  x <- as.character(x)
  x <- chartr("áéíóúàèìòùäëïöüâêîôûãõñçÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÃÕÑÇ",
              "aeiouaeiouaeiouaeiouaoncAEIOUAEIOUAEIOUAEIOUAONC", x)
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(x)
}

# equivalencias entre las etiquetas de rubro del manual externo (Price/KPMG) y las propias
ALIAS_RUBROS <- c(
  "cercos"                        = "Cercos",
  "edificios"                     = "Edificios",
  "terrenos"                      = "Terrenos",
  "estructuras y canos"           = "Estructuras y ca\u00f1os",
  "estructuras y canerias"        = "Estructuras y ca\u00f1os",
  "eq de oficina"                 = "Eq de Oficina",
  "equipo de oficina"             = "Eq de Oficina",
  "equipos de oficina"            = "Eq de Oficina",
  "maquinas y equipos"            = "Maquinas y Equipos",
  "maquinarias y equipos"         = "Maquinas y Equipos",
  "maquinas mejoras"              = "Maquinas Mejoras",
  "mejoras maquinas"              = "Maquinas Mejoras",
  "mejoras maquinas y equipos"    = "Maquinas Mejoras",
  "mejoras de maquinas y equipos" = "Maquinas Mejoras",
  "myu"                           = "MyU",
  "muebles y utiles"              = "MyU",
  "rodados"                       = "Rodados",
  "terreno mejoras"               = "Terreno Mejoras",
  "terrenos mejoras"              = "Terreno Mejoras",
  "mejoras terrenos"              = "Terreno Mejoras",
  "mejoras de terrenos"           = "Terreno Mejoras",
  "software"                      = "Software"
)

# devuelve el nombre canonico de rubro para cada etiqueta, o NA si no corresponde a ningun rubro
canonizar_rubro <- function(x) {
  unname(ALIAS_RUBROS[normalizar_etiqueta(x)])
}

es_fila_detalle_sap <- function(nro_activo) {
  activo <- normalizar_clave_activo(nro_activo)
  !is.na(activo) &
    activo != "" &
    !grepl("^(total|grand total|subtotal|totales?)\\b", activo, ignore.case = TRUE)
}

aplicar_excepciones_fecha_base <- function(inv, excepciones_fecha_base = SCHEMA_EXCEPCIONES_FECHA_BASE) {
  if (!"fecha_alta" %in% names(inv)) {
    inv$fecha_alta <- as.Date(NA)
  }

  inv <- inv %>%
    dplyr::mutate(
      nro_activo_fijo = normalizar_clave_activo(nro_activo_fijo),
      fecha_indice_reexp = fecha_alta,
      regla_fecha_base_aplicada = FALSE,
      motivo_excepcion_fecha_base = NA_character_
    )

  if (is.null(excepciones_fecha_base) || nrow(excepciones_fecha_base) == 0) {
    return(inv)
  }

  excepciones_activas <- excepciones_fecha_base %>%
    dplyr::filter(dplyr::coalesce(activo, TRUE)) %>%
    dplyr::mutate(
      nro_activo_fijo = normalizar_clave_activo(nro_activo_fijo),
      fecha_indice_excepcion = dplyr::coalesce(inicio_indice_desde, fecha_base_reexpresion)
    ) %>%
    dplyr::select(
      rubro,
      nro_activo_fijo,
      fecha_indice_excepcion,
      motivo_excepcion_fecha_base = motivo
    )

  inv %>%
    dplyr::left_join(excepciones_activas, by = c("rubro", "nro_activo_fijo")) %>%
    dplyr::mutate(
      fecha_indice_reexp = dplyr::coalesce(fecha_indice_excepcion, fecha_indice_reexp),
      regla_fecha_base_aplicada = !is.na(fecha_indice_excepcion)
    ) %>%
    dplyr::select(-fecha_indice_excepcion)
}

calcular_trimestres_primer_anio <- function(mes_alta) {
  4L - floor((mes_alta - 1L) / 3L)
}

calcular_vut_ly <- function(anio_alta, mes_alta, anio_ejercicio, vu_asignada) {
  trim_primer_anio <- calcular_trimestres_primer_anio(mes_alta)

  vut <- ifelse(
    anio_alta == anio_ejercicio,
    0,
    (anio_ejercicio - anio_alta - 1L) * 4L + trim_primer_anio
  )
  pmin(vut, vu_asignada)
}

calcular_vut_ejercicio <- function(anio_alta, mes_alta, anio_ejercicio, vu_asignada, vut_ly) {
  vut_ej <- ifelse(
    anio_alta == anio_ejercicio,
    calcular_trimestres_primer_anio(mes_alta),
    4
  )
  pmin(vut_ej, vu_asignada - vut_ly)
}

buscar_coeficiente <- function(fechas_alta, tabla_indices) {
  tabla_indices <- tabla_indices %>%
    dplyr::arrange(fecha)

  vapply(fechas_alta, function(f) {
    if (is.na(f)) return(1)
    idx <- max(which(tabla_indices$fecha <= f), 0)
    if (idx == 0) idx <- 1
    tabla_indices$coeficiente[idx]
  }, numeric(1))
}

obtener_vu_trimestres <- function(rubro) {
  match_idx <- match(rubro, PARAMETROS_RUBROS$rubro)
  ifelse(is.na(match_idx), NA_real_, PARAMETROS_RUBROS$vu_trimestres[match_idx])
}

obtener_vu_asignada <- function(rubro) {
  match_idx <- match(rubro, PARAMETROS_RUBROS$rubro)
  if (is.na(match_idx)) return(NA_real_)

  if (rubro == "Edificios") {
    PARAMETROS_RUBROS$vu_trimestres[match_idx]
  } else {
    PARAMETROS_RUBROS$vu_anios[match_idx]
  }
}

obtener_periodos_por_anio <- function(rubro) {
  ifelse(rubro == "Edificios", 4L, 1L)
}

es_terreno <- function(rubro) {
  rubro == "Terrenos"
}
