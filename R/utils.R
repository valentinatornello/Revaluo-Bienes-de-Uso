check_required_packages <- function(
  packages = c(
    "tidyverse",
    "readxl",
    "openxlsx",
    "janitor",
    "lubridate",
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

calcular_trimestres_primer_anio <- function(mes_alta) {
  pmax(floor((12 - mes_alta + 1) / 3), 0)
}

calcular_vut_ly <- function(anio_alta, mes_alta, anio_ejercicio, vu_asignada) {
  anios_completos <- anio_ejercicio - anio_alta - 1
  trim_primer_anio <- calcular_trimestres_primer_anio(mes_alta)

  vut <- ifelse(
    anio_alta == anio_ejercicio,
    0,
    ifelse(
      anio_alta == anio_ejercicio - 1,
      trim_primer_anio,
      trim_primer_anio + pmax(anios_completos - 1, 0) * 4 + 4
    )
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

es_terreno <- function(rubro) {
  rubro == "Terrenos"
}
