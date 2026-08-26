obtener_rutas_outputs <- function(outputs_dir = "outputs") {
  list(
    reportes = file.path(outputs_dir, "reportes"),
    auditoria = file.path(outputs_dir, "auditoria"),
    excel_final = file.path(outputs_dir, "excel_final")
  )
}

exportar_resultados <- function(datos_validados, outputs_dir = "outputs", anio_ejercicio = 2022) {
  rutas <- obtener_rutas_outputs(outputs_dir)

  for (dir_path in rutas) {
    if (!dir.exists(dir_path)) dir.create(dir_path, recursive = TRUE)
  }

  ruta_excel <- file.path(
    rutas$excel_final,
    sprintf("MARG_Revaluo_AXI_%d.xlsx", anio_ejercicio)
  )
  exportar_excel_revaluo(datos_validados, ruta_excel, anio_ejercicio)

  ruta_validaciones <- file.path(
    rutas$auditoria,
    sprintf("validaciones_%d.xlsx", anio_ejercicio)
  )
  exportar_validaciones(datos_validados, ruta_validaciones)
  ruta_resumen <- file.path(
    rutas$reportes,
    sprintf("resumen_revaluo_%d.xlsx", anio_ejercicio)
  )
  exportar_resumen(datos_validados, ruta_resumen, anio_ejercicio)

  list(
    rutas = rutas,
    archivos = list(
      excel = ruta_excel,
      validaciones = ruta_validaciones,
      resumen = ruta_resumen
    ),
    resultado = datos_validados
  )
}

exportar_excel_revaluo <- function(datos, ruta, anio_ejercicio = 2022) {
  wb <- openxlsx::createWorkbook()
  resultado_axi <- datos$resultado_axi

  for (rubro in names(resultado_axi)) {
    d <- resultado_axi[[rubro]]
    if (is.null(d) || nrow(d) == 0) next

    cols_export <- intersect(
      c("tipo_movimiento", "nro_activo_fijo", "descripcion",
        "anio_alta", "mes_alta", "vo", "vu_asignada",
        "trim_primer_anio", "vut_ly", "vut_ejercicio", "vut_cierre",
        "vu_restante", "amort_trimestre", "amort_hist_ejercicio",
        "amort_hist_2018", "amort_acum_cierre", "amort_acum_ly",
        "amort_acum_ly_reexp", "vr", "fecha_indice_reexp",
        "regla_fecha_base_aplicada", "motivo_excepcion_fecha_base",
        "valor_sap_original", "direccion_movimiento", "importe_movimiento_control",
        "coef_ipc", "coef_ipim",
        "vo_reexp", "amort_hist_reexp", "amort_acum_cierre_reexp",
        "vr_reexp", "amort_bajas", "vr_bajas"),
      names(d)
    )

    sheet_name <- substr(rubro, 1, 31)
    openxlsx::addWorksheet(wb, sheet_name)

    encabezado <- tibble::tibble(
      info = c(
        sprintf("MONSANTO ARGENTINA SRL - 
        REVALUO IMPOSITIVO BIENES DE USO AL 31-12-%d", anio_ejercicio),
        sprintf("Rubro: %s", rubro),
        ""
      )
    )
    openxlsx::writeData(wb, sheet_name, encabezado, 
    startRow = 1, colNames = FALSE)
    openxlsx::writeData(wb, sheet_name, d[, cols_export], 
    startRow = 4, colNames = TRUE)

    header_style <- openxlsx::createStyle(
      textDecoration = "bold",
      fgFill = "#D9E1F2",
      border = "TopBottomLeftRight"
    )
    openxlsx::addStyle(
      wb, sheet_name, header_style,
      rows = 4, cols = seq_along(cols_export)
    )

    num_style <- openxlsx::createStyle(numFmt = "#,##0.00")
    cols_num <- which(cols_export %in% c(
      "vo", "amort_trimestre", "amort_hist_ejercicio", "amort_hist_2018",
      "amort_acum_cierre", "amort_acum_ly", "amort_acum_ly_reexp",
      "vr", "vo_reexp", "amort_hist_reexp", "amort_acum_cierre_reexp",
      "vr_reexp", "amort_bajas", "vr_bajas"
    ))
    if (length(cols_num) > 0) {
      openxlsx::addStyle(
        wb, sheet_name, num_style,
        rows = 5:(nrow(d) + 4), cols = cols_num,
        gridExpand = TRUE
      )
    }

    totales <- tibble::tibble(
      label = "TOTALES"
    )
    fila_total <- nrow(d) + 5
    openxlsx::writeData(wb, sheet_name, totales, 
    startRow = fila_total, colNames = FALSE)

    for (col_idx in cols_num) {
      col_name <- cols_export[col_idx]
      total_val <- sum(d[[col_name]], na.rm = TRUE)
      openxlsx::writeData(
        wb, sheet_name, total_val,
        startRow = fila_total, startCol = col_idx
      )
    }

    total_style <- openxlsx::createStyle(
      textDecoration = "bold",
      border = "TopBottom"
    )
    openxlsx::addStyle(
      wb, sheet_name, total_style,
      rows = fila_total, cols = seq_along(cols_export)
    )
  }

  exportar_hoja_pg(wb, datos$prueba_global)
  exportar_hoja_indices(wb, datos)

  openxlsx::saveWorkbook(wb, ruta, overwrite = TRUE)
  message(sprintf("Excel exportado: %s", ruta))
}

exportar_hoja_pg <- function(wb, prueba_global) {
  openxlsx::addWorksheet(wb, "PG")

  openxlsx::writeData(wb, "PG", "PRUEBAS GLOBALES - 
  AMORTIZACIONES", startRow = 1)
  openxlsx::writeData(wb, "PG", prueba_global$amortizaciones, 
  startRow = 3, colNames = TRUE)

  fila_vr <- nrow(prueba_global$amortizaciones) + 6
  openxlsx::writeData(wb, "PG", "PRUEBAS GLOBALES - 
  VALOR RESIDUAL", startRow = fila_vr)
  openxlsx::writeData(
    wb, "PG", prueba_global$valor_residual,
    startRow = fila_vr + 2, colNames = TRUE
  )

  openxlsx::addWorksheet(wb, "PG AXI")
  openxlsx::writeData(wb, "PG AXI", "PRUEBAS GLOBALES - 
  AXI (IPIM e IPC)", startRow = 1)
  openxlsx::writeData(wb, "PG AXI", prueba_global$axi, 
  startRow = 3, colNames = TRUE)
}

exportar_hoja_indices <- function(wb, datos) {
  if (!is.null(datos$indices_ipc) && nrow(datos$indices_ipc) > 0) {
    openxlsx::addWorksheet(wb, "IPC")
    openxlsx::writeData(wb, "IPC", datos$indices_ipc, colNames = TRUE)
  }

  if (!is.null(datos$indices_ipim) && nrow(datos$indices_ipim) > 0) {
    openxlsx::addWorksheet(wb, "IPIM")
    openxlsx::writeData(wb, "IPIM", datos$indices_ipim, colNames = TRUE)
  }
}

exportar_validaciones <- function(datos, ruta) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Validaciones")

  resumen <- datos$validacion$resumen
  openxlsx::writeData(wb, "Validaciones", resumen, colNames = TRUE)

  ok_style <- openxlsx::createStyle(fgFill = "#C6EFCE")
  err_style <- openxlsx::createStyle(fgFill = "#FFC7CE")
  warn_style <- openxlsx::createStyle(fgFill = "#FFEB9C")

  for (i in seq_len(nrow(resumen))) {
    style <- switch(resumen$resultado[i],
      "OK" = ok_style,
      "ERROR" = err_style,
      "ADVERTENCIA" = warn_style
    )
    if (!is.null(style)) {
      openxlsx::addStyle(
        wb, "Validaciones", style,
        rows = i + 1, cols = 1:ncol(resumen)
      )
    }
  }

  openxlsx::saveWorkbook(wb, ruta, overwrite = TRUE)
  message(sprintf("Validaciones exportadas: %s", ruta))
}

exportar_resumen <- function(datos, ruta, anio_ejercicio = 2022) {
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Resumen")

  pg_axi <- datos$prueba_global$axi
  openxlsx::writeData(
    wb, "Resumen",
    sprintf("MONSANTO ARGENTINA SRL - REVALUO AXI %d", anio_ejercicio),
    startRow = 1
  )
  openxlsx::writeData(wb, "Resumen", pg_axi, startRow = 3, colNames = TRUE)

  total_row <- nrow(pg_axi) + 4
  openxlsx::writeData(wb, "Resumen", "TOTAL", startRow = total_row, startCol = 1)
  for (col in c("vr_reexp", "vo_reexp", "amort_acum_reexp", "vr_hist", "axi_resultado")) {
    col_idx <- which(names(pg_axi) == col)
    if (length(col_idx) > 0) {
      openxlsx::writeData(
        wb, "Resumen",
        sum(pg_axi[[col]], na.rm = TRUE),
        startRow = total_row, startCol = col_idx
      )
    }
  }

  openxlsx::saveWorkbook(wb, ruta, overwrite = TRUE)
  message(sprintf("Resumen exportado: %s", ruta))
}

# exporta solo validaciones y auditoria cuando hay errores, sin generar el excel final
exportar_solo_auditoria <- function(datos_validados, outputs_dir = "outputs", anio_ejercicio = 2022) {
  rutas <- obtener_rutas_outputs(outputs_dir)

  for (dir_path in rutas) {
    if (!dir.exists(dir_path)) dir.create(dir_path, recursive = TRUE)
  }

  ruta_validaciones <- file.path(
    rutas$auditoria,
    sprintf("validaciones_%d.xlsx", anio_ejercicio)
  )
  exportar_validaciones(datos_validados, ruta_validaciones)

  list(
    rutas = rutas,
    archivos = list(
      validaciones = ruta_validaciones
    ),
    resultado = datos_validados
  )
}
