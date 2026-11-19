# Comparacion fila por fila del calculo del motor contra las hojas por rubro del Excel manual del estudio.
# Herramienta de control: no forma parte del pipeline. El Excel tiene que estar en .xlsx (si viene en .xlsb, abrirlo
# en Excel y guardarlo como "Libro de Excel (*.xlsx)").

# campo del motor -> etiqueta normalizada de la columna del Excel
CAMPOS_COMPARACION_EXCEL <- c(
  vo = "vo",
  vu_asignada = "vu asignada",
  vut_cierre = "vut",
  amort_hist_ejercicio = "amort historica",
  amort_acum_cierre = "amort acum",
  vr = "vr 2023",
  vo_reexp = "vo reexp",
  amort_ejercicio_reexp = "amort reexp",
  vr_reexp = "vr reexp"
)

# Terrenos tiene otro diseno de hoja: solo VO y VR reexpresado
CAMPOS_COMPARACION_EXCEL_TERRENOS <- c(vo = "val adq", vr_reexp = "vr reexp")

leer_filas_excel_estudio <- function(path_excel, rubro) {
  config <- FILAS_HEADER[[rubro]]
  raw <- readxl::read_excel(path_excel, sheet = rubro, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  if (nrow(raw) <= config$header_row) return(tibble::tibble())

  etiquetas <- normalizar_etiqueta(as.character(raw[config$header_row, ]))
  datos <- raw[(config$header_row + 1):nrow(raw), ]
  nombres_unicos <- make.unique(ifelse(is.na(etiquetas) | etiquetas == "", paste0("col", seq_along(etiquetas)), etiquetas))
  names(datos) <- nombres_unicos

  col_nro <- grep("^activo fijo|^n activo fijo", nombres_unicos)[1]
  col_vo <- if (rubro == "Terrenos") "val adq" else "vo"
  nro <- as.character(datos[[col_nro]])
  vo <- suppressWarnings(as.numeric(datos[[col_vo]]))

  # fin del detalle: fila "Totales" (o, sin rotulo, la primera fila sin N° de activo ni anio de alta con importe)
  primera <- tolower(as.character(datos[[1]]))
  col_anio <- grep("^ano alta$", nombres_unicos)[1]
  anio_alta <- if (is.na(col_anio)) rep(NA_character_, nrow(datos)) else as.character(datos[[col_anio]])
  es_total <- grepl("^totales", primera) | (is.na(nro) & is.na(anio_alta) & !is.na(vo))
  fila_total <- which(es_total)[1]
  if (!is.na(fila_total)) datos <- datos[seq_len(fila_total - 1L), ]
  nro <- nro[seq_len(nrow(datos))]
  vo <- vo[seq_len(nrow(datos))]

  datos <- datos[(!is.na(nro) | !is.na(vo)) & !grepl("^AS", nro, ignore.case = TRUE), ]
  datos <- datos[!is.na(suppressWarnings(as.numeric(datos[[col_vo]]))), ]
  datos$nro_activo_fijo <- as.character(datos[[col_nro]])

  # En Edificios la columna "VUT" del Excel es el flujo del ejercicio (1 a 4 trimestres, filas con formula: cierre =
  # VUT LY + VUT) o el cierre pegado a mano (mayor a 4). Se lleva a cierre para compararla con vut_cierre.
  if (rubro == "Edificios" && all(c("vut", "vut ly") %in% names(datos))) {
    vut <- suppressWarnings(as.numeric(datos[["vut"]]))
    vut_ly <- suppressWarnings(as.numeric(datos[["vut ly"]]))
    datos[["vut"]] <- as.character(dplyr::if_else(!is.na(vut) & vut > 4, vut, dplyr::coalesce(vut_ly, 0) + dplyr::coalesce(vut, 0)))
  }
  datos
}

# Compara el resultado del motor (resultado_axi) con el Excel; devuelve una lista con el resumen por rubro y campo
# y el detalle de las filas que no coinciden.
comparar_filas_con_excel <- function(resultado_axi, path_excel, tolerancia = 0.01) {
  resumenes <- list()
  diferencias <- list()
  solo_en <- list()

  for (rubro in names(resultado_axi)) {
    if (!rubro %in% names(FILAS_HEADER)) next
    excel <- tryCatch(leer_filas_excel_estudio(path_excel, rubro), error = function(e) tibble::tibble())
    if (nrow(excel) == 0) next

    motor <- resultado_axi[[rubro]] %>% dplyr::filter(tipo_movimiento_calc != "baja")
    campos <- if (rubro == "Terrenos") CAMPOS_COMPARACION_EXCEL_TERRENOS else CAMPOS_COMPARACION_EXCEL
    campos <- campos[campos %in% names(excel)]

    col_vo_excel <- if (rubro == "Terrenos") "val adq" else "vo"
    clave <- function(nro, vo) paste(nro, formatC(round(as.numeric(vo), 2), format = "f", digits = 2), sep = "|")
    motor$clave_base <- clave(motor$nro_activo_fijo, motor$vo)
    excel$clave_base <- clave(excel$nro_activo_fijo, excel[[col_vo_excel]])
    motor$clave <- paste(motor$clave_base, stats::ave(seq_len(nrow(motor)), motor$clave_base, FUN = seq_along), sep = "#")
    excel$clave <- paste(excel$clave_base, stats::ave(seq_len(nrow(excel)), excel$clave_base, FUN = seq_along), sep = "#")

    solo_en[[rubro]] <- tibble::tibble(
      rubro = rubro,
      filas_motor = nrow(motor), filas_excel = nrow(excel),
      solo_motor = sum(!motor$clave %in% excel$clave), solo_excel = sum(!excel$clave %in% motor$clave)
    )

    comunes <- intersect(motor$clave, excel$clave)
    m <- motor[match(comunes, motor$clave), ]
    e <- excel[match(comunes, excel$clave), ]

    for (campo in names(campos)) {
      if (!campo %in% names(m)) next
      valor_motor <- as.numeric(m[[campo]])
      valor_excel <- suppressWarnings(as.numeric(e[[campos[[campo]]]]))
      valor_excel[is.na(valor_excel)] <- 0
      valor_motor[is.na(valor_motor)] <- 0
      dif <- valor_motor - valor_excel
      coincide <- abs(dif) <= tolerancia | abs(dif) <= 1e-9 * pmax(abs(valor_excel), 1)
      resumenes[[length(resumenes) + 1L]] <- tibble::tibble(
        rubro = rubro, campo = campo, filas = length(comunes), coinciden = sum(coincide),
        total_motor = sum(valor_motor), total_excel = sum(valor_excel), dif_total = sum(dif)
      )
      if (any(!coincide)) {
        diferencias[[length(diferencias) + 1L]] <- tibble::tibble(
          rubro = rubro, campo = campo, nro_activo_fijo = m$nro_activo_fijo[!coincide],
          motor = valor_motor[!coincide], excel = valor_excel[!coincide], dif = dif[!coincide]
        )
      }
    }
  }

  list(
    resumen = dplyr::bind_rows(resumenes),
    filas = dplyr::bind_rows(solo_en),
    diferencias = dplyr::bind_rows(diferencias)
  )
}
