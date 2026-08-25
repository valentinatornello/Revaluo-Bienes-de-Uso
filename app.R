# app.R — Shiny app para Revalúo Impositivo Bienes de Uso
# Permite cargar archivos SAP, ejecutar el pipeline paso a paso y descargar los outputs.
library(shiny)
library(tidyverse)
library(readxl)
library(openxlsx)
library(janitor)
library(lubridate)

# Permitir archivos grandes (hasta 200 MB)
options(shiny.maxRequestSize = 200 * 1024^2)

# Cargar el pipeline y exponer las operaciones usadas por la interfaz.
pipeline_env <- new.env(parent = environment())
for (script in c(
  "R/utils.R",
  "R/01_importar_datos.R",
  "R/02_limpiar_datos.R",
  "R/03_construir_rollforward.R",
  "R/04_calculo_axi.R",
  "R/05_prueba_global.R",
  "R/06_validaciones.R",
  "R/07_exportar_resultados.R"
)) {
  sys.source(script, envir = pipeline_env)
}

importar_datos <- function(path_excel_ly, inputs_dir = "inputs") {
  pipeline_env$importar_datos(path_excel_ly, inputs_dir)
}

limpiar_datos <- function(datos, anio_ejercicio) {
  pipeline_env$limpiar_datos(datos, anio_ejercicio)
}

construir_rollforward <- function(datos_limpios, anio_ejercicio) {
  pipeline_env$construir_rollforward(datos_limpios, anio_ejercicio)
}

calcular_axi <- function(datos_rollforward, anio_ejercicio) {
  pipeline_env$calcular_axi(datos_rollforward, anio_ejercicio)
}

generar_prueba_global <- function(datos_axi, anio_ejercicio) {
  pipeline_env$generar_prueba_global(datos_axi, anio_ejercicio)
}

ejecutar_validaciones <- function(datos_pg) {
  pipeline_env$ejecutar_validaciones(datos_pg)
}

exportar_excel_revaluo <- function(datos, ruta, anio_ejercicio) {
  pipeline_env$exportar_excel_revaluo(datos, ruta, anio_ejercicio)
}

exportar_validaciones <- function(datos, ruta) {
  pipeline_env$exportar_validaciones(datos, ruta)
}

exportar_resumen <- function(datos, ruta, anio_ejercicio) {
  pipeline_env$exportar_resumen(datos, ruta, anio_ejercicio)
}

ANIO_EJERCICIO_DEFAULT <- as.integer(format(Sys.Date(), "%Y")) - 1L

# ─────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────

fmt_num <- function(x) {
  if (is.numeric(x)) formatC(x, format = "f", digits = 2, big.mark = ",") else as.character(x)
}

status_badge <- function(ok) {
  if (isTRUE(ok)) {
    tags$span(class = "badge-ok", "\u2714 OK")
  } else {
    tags$span(class = "badge-error", "\u2718 ERROR")
  }
}

resultado_color <- function(r) {
  switch(r,
    "OK"          = "color:#217346;font-weight:bold",
    "ERROR"       = "color:#c00000;font-weight:bold",
    "ADVERTENCIA" = "color:#9C5700;font-weight:bold",
    ""
  )
}

# ─────────────────────────────────────────────
#  UI
# ─────────────────────────────────────────────

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { font-family: 'Segoe UI', sans-serif; background: #f4f6f9; }
      .sidebar-panel { background: #fff; border-radius: 8px; padding: 16px;
                       box-shadow: 0 1px 4px rgba(0,0,0,.1); }
      .step-box { background: #fff; border-radius: 8px; padding: 16px; margin-bottom: 16px;
                  box-shadow: 0 1px 4px rgba(0,0,0,.1); }
      .step-title { font-size: 1.05rem; font-weight: 700; margin-bottom: 8px;
                    border-left: 4px solid #2c7be5; padding-left: 8px; }
      .badge-ok    { background:#217346; color:#fff; border-radius:4px; padding:2px 8px; }
      .badge-error { background:#c00000; color:#fff; border-radius:4px; padding:2px 8px; }
      .badge-warn  { background:#9C5700; color:#fff; border-radius:4px; padding:2px 8px; }
      table.summary-table { border-collapse: collapse; width: 100%; font-size:.85rem; }
      table.summary-table th { background:#2c7be5; color:#fff; padding:6px 10px; }
      table.summary-table td { border-bottom: 1px solid #e0e0e0; padding:4px 10px; }
      .run-btn { background:#2c7be5; color:#fff; border:none; border-radius:6px;
                 padding:10px 24px; font-size:1rem; cursor:pointer; width:100%; margin-top:8px; }
      .run-btn:hover { background:#1a5eb8; }
      .section-header { font-size:1.2rem; font-weight:700; color:#2c7be5; margin: 12px 0 6px 0; }
      .info-btn { background:none; border:1px solid #2c7be5; color:#2c7be5; border-radius:50%;
                  width:22px; height:22px; font-size:.75rem; cursor:pointer; padding:0;
                  line-height:1; vertical-align:middle; margin-left:4px; }
      .info-btn:hover { background:#2c7be5; color:#fff; }
      .schema-table { border-collapse:collapse; width:100%; font-size:.82rem; margin-top:6px; }
      .schema-table th { background:#2c7be5; color:#fff; padding:5px 10px; text-align:left; }
      .schema-table td { border-bottom:1px solid #e0e0e0; padding:4px 10px; }
      .schema-table tr:last-child td { border-bottom:none; }
      .tab-note { background:#fff8e1; border-left:3px solid #f9a825; padding:6px 10px;
                  border-radius:4px; font-size:.82rem; margin-bottom:8px; }
    "))
  ),

  titlePanel("📊 Revalúo Impositivo — Bienes de Uso AgroBayer"),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      div(class = "sidebar-panel",

        div(class = "section-header", "⚙️ Parámetros"),
        numericInput("anio_ejercicio", "Año de ejercicio:", value = ANIO_EJERCICIO_DEFAULT,
                     min = 2000, max = 2100, step = 1),

        hr(),
        div(class = "section-header",
          "📂 Archivo de parámetros (Excel LY)",
          tags$button(class = "info-btn", id = "btn_info_ly",
                      onclick = "Shiny.setInputValue('show_info_ly', Math.random())",
                      "ℹ")
        ),
        fileInput("archivo_ly", NULL,
                  accept = ".xlsx",
                  buttonLabel = "Seleccionar…",
                  placeholder = "MARG - Revaluo AxI …"),
        helpText("Debe contener las hojas de categorías e índices IPC / IPIM."),

        hr(),
        div(class = "section-header",
          "📥 Cargar Altas / Bajas / Transferencias SAP",
          tags$button(class = "info-btn", id = "btn_info_sap",
                      onclick = "Shiny.setInputValue('show_info_sap', Math.random())",
                      "ℹ")
        ),
        fileInput("archivo_sap", NULL,
                  accept = ".xlsx",
                  buttonLabel = "Seleccionar…",
                  placeholder = "Archivo SAP (.xlsx)"),
        helpText("El archivo se copiará a inputs/SAP/ y será usado en el cálculo."),
        uiOutput("sap_status"),

        hr(),
        actionButton("btn_run", "▶ Ejecutar pipeline", class = "run-btn"),
        uiOutput("run_status"),

        hr(),
        div(class = "section-header", "📤 Descargar outputs"),
        downloadButton("dl_revaluo",     "Revalúo final (.xlsx)"),
        br(), br(),
        downloadButton("dl_validaciones","Validaciones (.xlsx)"),
        br(), br(),
        downloadButton("dl_resumen",     "Resumen AXI (.xlsx)")
      )
    ),

    mainPanel(
      width = 9,

      # ── Paso 1 ──────────────────────────────
      div(class = "step-box",
        div(class = "step-title", "Paso 1 — Importar datos"),
        uiOutput("paso1_ui")
      ),

      # ── Paso 2 ──────────────────────────────
      div(class = "step-box",
        div(class = "step-title", "Paso 2 — Limpieza y normalización"),
        uiOutput("paso2_ui")
      ),

      # ── Paso 3 ──────────────────────────────
      div(class = "step-box",
        div(class = "step-title", "Paso 3 — Roll-forward (inventario del ejercicio)"),
        uiOutput("paso3_ui")
      ),

      # ── Paso 4 ──────────────────────────────
      div(class = "step-box",
        div(class = "step-title", "Paso 4 — Cálculo AXI (reexpresión)"),
        uiOutput("paso4_ui")
      ),

      # ── Paso 5 ──────────────────────────────
      div(class = "step-box",
        div(class = "step-title", "Paso 5 — Prueba global"),
        uiOutput("paso5_ui")
      ),

      # ── Paso 6 ──────────────────────────────
      div(class = "step-box",
        div(class = "step-title", "Paso 6 — Validaciones"),
        uiOutput("paso6_ui")
      )
    )
  )
)

# 
# ─────────────────────────────────────────────
#  SERVER
# ─────────────────────────────────────────────
# Tener en cuenta que maximum size ha sido excedido, 
# por lo que se debe aumentar el límite de tamaño de carga de archivos en Shiny.
options(shiny.maxRequestSize = 100 * 1024^2)  # 100 MB

server <- function(input, output, session) {

  # ── Modales de información de formato ───────

  # Helper para construir una tabla HTML de esquema
  schema_table <- function(cols) {
    rows <- lapply(cols, function(r) {
      tags$tr(tags$td(tags$code(r[[1]])), tags$td(r[[2]]), tags$td(r[[3]]))
    })
    tags$table(class = "schema-table",
      tags$thead(tags$tr(tags$th("Columna"), tags$th("Tipo"), tags$th("Descripción"))),
      tags$tbody(rows)
    )
  }

  observeEvent(input$show_info_ly, {
    showModal(modalDialog(
      title = "📂 Formato esperado — Archivo de parámetros (LY)",
      size  = "l",
      easyClose = TRUE,
      footer = modalButton("Cerrar"),

      tags$p(class = "tab-note",
        "⚠ El archivo debe ser un .xlsx con múltiples hojas. ",
        "A continuación se describe cada hoja requerida."
      ),

      tags$h5("Hojas de categorías (una por rubro)"),
      tags$p("Nombres de hoja: ",
        tags$code("Cercos"), ", ",
        tags$code("Edificios"), ", ",
        tags$code("Terrenos"), ", ",
        tags$code("Estructuras y caños"), ", ",
        tags$code("Eq de Oficina"), ", ",
        tags$code("Maquinas y Equipos"), ", ",
        tags$code("Maquinas Mejoras"), ", ",
        tags$code("MyU"), ", ",
        tags$code("Rodados"), ", ",
        tags$code("Terreno Mejoras"), ", ",
        tags$code("Software")
      ),
      tags$p("Cada hoja contiene filas de activos con columnas como:"),
      schema_table(list(
        list("N° Activo Fijo",   "Texto",  "Número/código del activo"),
        list("Descripción",      "Texto",  "Descripción del bien"),
        list("Año Archivo / Cap Date", "Fecha", "Fecha de activación del bien"),
        list("VO",               "Numérico", "Valor de origen histórico"),
        list("VU Asignada",      "Numérico", "Vida útil en trimestres"),
        list("VUT LY",           "Numérico", "Trimestres usados al cierre del año anterior")
      )),
      tags$p(style = "font-size:.8rem; color:#555;",
        "Nota: el encabezado puede encontrarse en filas distintas según el rubro ",
        "(p.ej. fila 13 en Cercos, fila 16 en Edificios). ",
        "La app detecta el header automáticamente según la configuración interna."
      ),

      tags$hr(),

      tags$h5("Hojas de índices"),
      tags$p("Se requieren las siguientes hojas con 4 columnas cada una:"),
      schema_table(list(
        list("Columna 1", "Fecha",    "Fecha del período (formato fecha Excel)"),
        list("Columna 2", "Numérico", "Índice del período"),
        list("Columna 3", "Numérico", "Índice actual / de cierre"),
        list("Columna 4", "Numérico", "Coeficiente de actualización")
      )),
      tags$ul(
        tags$li(tags$code("IPC"), " — índice para bienes post-2018"),
        tags$li(tags$code("IPIM"), " — índice para bienes pre-2018"),
        tags$li(tags$code("IPC - VR Bajas"), " — índice IPC para cálculo de bajas"),
        tags$li(tags$code("IPIM - VR Bajas"), " — índice IPIM para cálculo de bajas")
      )
    ))
  })

  observeEvent(input$show_info_sap, {
    showModal(modalDialog(
      title = "📥 Formato esperado — Archivo SAP (Altas / Bajas / Transferencias)",
      size  = "l",
      easyClose = TRUE,
      footer = modalButton("Cerrar"),

      tags$p(class = "tab-note",
        "⚠ El archivo debe ser un .xlsx con exactamente tres hojas: ",
        tags$code("Altas"), ", ", tags$code("Bajas"), " y ", tags$code("Transferencias"), "."
      ),

      tags$h5("Hoja: Altas"),
      schema_table(list(
        list("Asset",              "Texto",   "Número de activo SAP"),
        list("Cap_Date",           "Fecha",   "Fecha de capitalización (dd.mm.yyyy)"),
        list("PstngDate / Pstng_Date", "Fecha", "Fecha de registro contable (dd.mm.yyyy)"),
        list("Asset_Description2", "Texto",   "Descripción del bien"),
        list("Class",              "Texto",   "Clase SAP (p.ej. 210LA, 360LA)"),
        list("Suma_de_Acquisition","Numérico","Valor de adquisición")
      )),

      tags$h5("Hoja: Bajas"),
      schema_table(list(
        list("Asset",           "Texto",   "Número de activo SAP"),
        list("Cap_Date",        "Fecha",   "Fecha de capitalización (dd.mm.yyyy)"),
        list("Pstng_Date",      "Fecha",   "Fecha de registro contable (dd.mm.yyyy)"),
        list("Asset_Description","Texto",  "Descripción del bien"),
        list("Class",           "Texto",   "Clase SAP"),
        list("Retirement",      "Numérico","Valor de baja"),
        list("Depr_Retired",    "Numérico","Amortización acumulada retirada")
      )),

      tags$h5("Hoja: Transferencias"),
      schema_table(list(
        list("Asset",              "Texto",   "Número de activo SAP"),
        list("Cap_Date",           "Fecha",   "Fecha de capitalización (dd.mm.yyyy)"),
        list("Pstng_Date",         "Fecha",   "Fecha de registro contable (dd.mm.yyyy)"),
        list("Asset_Description2", "Texto",   "Descripción del bien"),
        list("Class",              "Texto",   "Clase SAP"),
        list("Suma_de_Transfer",   "Numérico","Valor transferido"),
        list("Suma_de_Trans_O_Dep","Numérico","Amortización transferida")
      )),

      tags$hr(),
      tags$p(style = "font-size:.8rem; color:#555;",
        "Las fechas deben estar en formato ", tags$code("dd.mm.yyyy"),
        " (texto) o como fecha Excel numérica. ",
        "Las filas con activo que comience con 'AS' (IFRS 16) se excluyen automáticamente. ",
        "La clase SAP se usa para mapear cada activo a su rubro contable."
      )
    ))
  })

  # ── Estado reactivo del pipeline ────────────
  estado <- reactiveValues(
    paso = 0L,      # hasta qué paso llegó exitosamente
    error_msg = NULL,
    datos_crudos    = NULL,
    datos_limpios   = NULL,
    inventario      = NULL,
    axi             = NULL,
    prueba_global   = NULL,
    validacion      = NULL,
    archivos_output = NULL
  )

  # ── Copiar archivo SAP al cargar ────────────
  observeEvent(input$archivo_sap, { 
    req(input$archivo_sap)
    dest_dir <- file.path("inputs", "SAP")
    if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)
    dest_path <- file.path(dest_dir, basename(input$archivo_sap$name))
    file.copy(input$archivo_sap$datapath, dest_path, overwrite = TRUE)
    output$sap_status <- renderUI({
      tags$p(style = "color:green; font-size:.85rem;",
             paste0("✔ Copiado a inputs/SAP/", input$archivo_sap$name))
    })
  })

  # ── Ejecutar pipeline ───────────────────────
  observeEvent(input$btn_run, {
    req(input$archivo_ly)

    estado$paso        <- 0L
    estado$error_msg   <- NULL
    estado$archivos_output <- NULL

    path_ly      <- input$archivo_ly$datapath
    anio         <- as.integer(input$anio_ejercicio)

    output$run_status <- renderUI(
      tags$p(style = "color:#555; font-size:.85rem;", "⏳ Ejecutando…")
    )

    # Guardar LY en parametros para que las funciones lo encuentren
    dir.create(file.path("inputs", "parametros"), recursive = TRUE, showWarnings = FALSE)
    path_ly_dest <- file.path("inputs", "parametros", basename(input$archivo_ly$name))
    file.copy(path_ly, path_ly_dest, overwrite = TRUE)

    # ── Paso 1: importar ────────────────────
    tryCatch({
      estado$datos_crudos <- importar_datos(path_ly_dest, "inputs")
      estado$paso <- 1L
    }, error = function(e) {
      estado$error_msg <- paste("Paso 1 — Error al importar datos:", e$message)
      output$run_status <- renderUI(
        tags$p(style = "color:red; font-size:.85rem;", estado$error_msg)
      )
    })
    if (!is.null(estado$error_msg)) return()

    # ── Paso 2: limpiar ─────────────────────
    tryCatch({
      estado$datos_limpios <- limpiar_datos(estado$datos_crudos, anio)
      estado$paso <- 2L
    }, error = function(e) {
      estado$error_msg <- paste("Paso 2 — Error al limpiar datos:", e$message)
      output$run_status <- renderUI(
        tags$p(style = "color:red; font-size:.85rem;", estado$error_msg)
      )
    })
    if (!is.null(estado$error_msg)) return()

    # ── Paso 3: rollforward ─────────────────
    tryCatch({
      estado$inventario <- construir_rollforward(estado$datos_limpios, anio)
      estado$paso <- 3L
    }, error = function(e) {
      estado$error_msg <- paste("Paso 3 — Error en rollforward:", e$message)
      output$run_status <- renderUI(
        tags$p(style = "color:red; font-size:.85rem;", estado$error_msg)
      )
    })
    if (!is.null(estado$error_msg)) return()

    # ── Paso 4: cálculo AXI ─────────────────
    tryCatch({
      estado$axi <- calcular_axi(estado$inventario, anio)
      estado$paso <- 4L
    }, error = function(e) {
      estado$error_msg <- paste("Paso 4 — Error en cálculo AXI:", e$message)
      output$run_status <- renderUI(
        tags$p(style = "color:red; font-size:.85rem;", estado$error_msg)
      )
    })
    if (!is.null(estado$error_msg)) return()

    # ── Paso 5: prueba global ────────────────
    tryCatch({
      estado$prueba_global <- generar_prueba_global(estado$axi, anio)
      estado$paso <- 5L
    }, error = function(e) {
      estado$error_msg <- paste("Paso 5 — Error en prueba global:", e$message)
      output$run_status <- renderUI(
        tags$p(style = "color:red; font-size:.85rem;", estado$error_msg)
      )
    })
    if (!is.null(estado$error_msg)) return()

    # ── Paso 6: validaciones ─────────────────
    tryCatch({
      estado$validacion <- ejecutar_validaciones(estado$prueba_global)
      estado$paso <- 6L
    }, error = function(e) {
      estado$error_msg <- paste("Paso 6 — Error en validaciones:", e$message)
      output$run_status <- renderUI(
        tags$p(style = "color:red; font-size:.85rem;", estado$error_msg)
      )
    })
    if (!is.null(estado$error_msg)) return()

    # ── Exportar outputs en memoria ──────────
    tryCatch({
      tmp_dir <- tempdir()
      out_revaluo      <- file.path(tmp_dir, sprintf("MARG_Revaluo_AXI_%d.xlsx", anio))
      out_validaciones <- file.path(tmp_dir, sprintf("validaciones_%d.xlsx", anio))
      out_resumen      <- file.path(tmp_dir, sprintf("resumen_revaluo_%d.xlsx", anio))

      exportar_excel_revaluo(estado$validacion, out_revaluo, anio)
      exportar_validaciones(estado$validacion, out_validaciones)
      exportar_resumen(estado$validacion, out_resumen, anio)

      estado$archivos_output <- list(
        revaluo      = out_revaluo,
        validaciones = out_validaciones,
        resumen      = out_resumen
      )
    }, error = function(e) {
      # outputs no son críticos para mostrar resultados
      warning("No se pudieron generar los archivos de output: ", e$message)
    })

    output$run_status <- renderUI(
      tags$p(style = "color:green; font-size:.85rem;",
             "✔ Pipeline completado correctamente")
    )
  })

  # ────────────────────────────────────────────────────────────
  #  RENDERS DE CADA PASO
  # ────────────────────────────────────────────────────────────

  # ── Paso 1 ──────────────────────────────────
  output$paso1_ui <- renderUI({
    if (estado$paso < 1L) return(tags$p(style = "color:#aaa;", "En espera…"))

    dc <- estado$datos_crudos
    rubros <- names(dc$inventario_ly)
    n_altas <- if (!is.null(dc$altas)) nrow(dc$altas) else 0
    n_bajas <- if (!is.null(dc$bajas)) nrow(dc$bajas) else 0
    n_transf <- if (!is.null(dc$transferencias)) nrow(dc$transferencias) else 0

    tagList(
      tags$table(class = "summary-table",
        tags$thead(tags$tr(lapply(c("Elemento", "Detalle"), tags$th))),
        tags$tbody(
          tags$tr(tags$td("Rubros cargados"), tags$td(paste(rubros, collapse = ", "))),
          tags$tr(tags$td("Índices IPC"), tags$td(paste(nrow(dc$indices_ipc), "registros"))),
          tags$tr(tags$td("Índices IPIM"), tags$td(paste(nrow(dc$indices_ipim), "registros"))),
          tags$tr(tags$td("Altas SAP"), tags$td(paste(n_altas, "filas"))),
          tags$tr(tags$td("Bajas SAP"), tags$td(paste(n_bajas, "filas"))),
          tags$tr(tags$td("Transferencias SAP"), tags$td(paste(n_transf, "filas")))
        )
      )
    )
  })

  # ── Paso 2 ──────────────────────────────────
  output$paso2_ui <- renderUI({
    if (estado$paso < 2L) return(tags$p(style = "color:#aaa;", "En espera…"))

    inv <- estado$datos_limpios$inventario_ly
    if (is.null(inv) || length(inv) == 0) return(tags$p("Sin datos de inventario."))

    rows <- lapply(names(inv), function(r) {
      d <- inv[[r]]
      tipos <- if (nrow(d) > 0) paste(sort(unique(d$tipo_movimiento)), collapse = ", ") else "—"
      tags$tr(
        tags$td(r),
        tags$td(nrow(d)),
        tags$td(tipos)
      )
    })
 # Separar el número de filas por movimiento y mostrarlo en la tabla de resumen # RECORDAR
    tags$table(class = "summary-table",
      tags$thead(tags$tr(lapply(c("Rubro", "Filas", "Tipos de movimiento"), tags$th))),
      tags$tbody(rows)
    )
  })

  # ── Paso 3 ──────────────────────────────────
  output$paso3_ui <- renderUI({
    if (estado$paso < 3L) return(tags$p(style = "color:#aaa;", "En espera…"))

    inv <- estado$inventario$inventario
    if (is.null(inv) || length(inv) == 0) return(tags$p("Sin datos de inventario."))

    rows <- lapply(names(inv), function(r) {
      d <- inv[[r]]
      origenes <- if (!is.null(d$origen)) paste(sort(unique(d$origen)), collapse = ", ") else "—"
      vo_total <- if ("vo" %in% names(d)) sum(d$vo, na.rm = TRUE) else NA
      tags$tr(
        tags$td(r),
        tags$td(nrow(d)),
        tags$td(origenes),
        tags$td(fmt_num(vo_total))
      )
    })

    tags$table(class = "summary-table",
      tags$thead(tags$tr(lapply(c("Rubro", "Activos", "Orígenes", "VO total"), tags$th))),
      tags$tbody(rows)
    )
  })

  # ── Paso 4 ──────────────────────────────────
  output$paso4_ui <- renderUI({
    if (estado$paso < 4L) return(tags$p(style = "color:#aaa;", "En espera…"))

    res <- estado$axi$resultado_axi
    if (is.null(res) || length(res) == 0) return(tags$p("Sin resultados."))

    rows <- lapply(names(res), function(r) {
      d <- res[[r]]
      vo_reexp   <- if ("vo_reexp" %in% names(d)) fmt_num(sum(d$vo_reexp, na.rm = TRUE)) else "—"
      amort_reexp <- if ("amort_acum_cierre_reexp" %in% names(d)) fmt_num(sum(d$amort_acum_cierre_reexp, na.rm = TRUE)) else "—"
      vr_reexp   <- if ("vr_reexp" %in% names(d)) fmt_num(sum(d$vr_reexp, na.rm = TRUE)) else "—"
      vr_hist    <- if ("vr" %in% names(d)) fmt_num(sum(d$vr, na.rm = TRUE)) else "—"
      axi_val    <- if (all(c("vr_reexp","vr") %in% names(d)))
                      fmt_num(sum(d$vr_reexp, na.rm = TRUE) - sum(d$vr, na.rm = TRUE))
                    else "—"
      tags$tr(
        tags$td(r),
        tags$td(vo_reexp),
        tags$td(amort_reexp),
        tags$td(vr_reexp),
        tags$td(vr_hist),
        tags$td(axi_val)
      )
    })

    tags$table(class = "summary-table",
      tags$thead(tags$tr(lapply(
        c("Rubro", "VO reexp.", "Amort. acum. reexp.", "VR reexp.", "VR histórico", "AXI"),
        tags$th))),
      tags$tbody(rows)
    )
  })

  # ── Paso 5 ──────────────────────────────────
  output$paso5_ui <- renderUI({
    if (estado$paso < 5L) return(tags$p(style = "color:#aaa;", "En espera…"))

    pg <- estado$prueba_global$prueba_global
    if (is.null(pg)) return(tags$p("Sin prueba global."))

    render_pg_table <- function(df, titulo) {
      if (is.null(df) || nrow(df) == 0) return(NULL)
      col_names <- names(df)

      rows_data <- lapply(seq_len(nrow(df)), function(i) {
        tds <- lapply(col_names, function(cn) {
          v <- df[[cn]][i]
          txt <- if (is.numeric(v)) fmt_num(v) else as.character(v)
          style_extra <- if (cn == "diferencia" && is.numeric(v)) {
            if (abs(v) > 100) "color:red;font-weight:bold" else if (abs(v) > 1) "color:#9C5700" else "color:green"
          } else ""
          tags$td(style = style_extra, txt)
        })
        do.call(tags$tr, tds)
      })

      tagList(
        tags$p(style = "font-weight:bold; margin-top:12px;", titulo),
        tags$table(class = "summary-table",
          tags$thead(tags$tr(lapply(col_names, tags$th))),
          tags$tbody(rows_data)
        )
      )
    }

    tagList(
      render_pg_table(pg$amortizaciones, "Prueba Global — Amortizaciones"),
      render_pg_table(pg$valor_residual, "Prueba Global — Valor Residual"),
      render_pg_table(pg$axi,            "Prueba Global — AXI")
    )
  })

  # ── Paso 6 ──────────────────────────────────
  output$paso6_ui <- renderUI({
    if (estado$paso < 6L) return(tags$p(style = "color:#aaa;", "En espera…"))

    val <- estado$validacion$validacion
    if (is.null(val)) return(tags$p("Sin validaciones."))

    consistente <- isTRUE(val$consistente)
    resumen <- val$resumen

    rows <- lapply(seq_len(nrow(resumen)), function(i) {
      r <- resumen[i, ]
      tags$tr(
        tags$td(r$tipo),
        tags$td(r$rubro),
        tags$td(r$descripcion),
        tags$td(style = resultado_color(r$resultado), r$resultado),
        tags$td(fmt_num(r$valor))
      )
    })

    tagList(
      tags$p(
        style = "font-size:1.1rem; margin-bottom:8px;",
        "Estado general: ", status_badge(consistente)
      ),
      tags$table(class = "summary-table",
        tags$thead(tags$tr(lapply(c("Tipo", "Rubro", "Descripción", "Resultado", "Valor"), tags$th))),
        tags$tbody(rows)
      )
    )
  })

  # ────────────────────────────────────────────────────────────
  #  DOWNLOADS
  # ────────────────────────────────────────────────────────────

  output$dl_revaluo <- downloadHandler(
    filename = function() sprintf("MARG_Revaluo_AXI_%d.xlsx", as.integer(input$anio_ejercicio)),
    content  = function(file) {
      req(estado$archivos_output)
      file.copy(estado$archivos_output$revaluo, file)
    }
  )

  output$dl_validaciones <- downloadHandler(
    filename = function() sprintf("validaciones_%d.xlsx", as.integer(input$anio_ejercicio)),
    content  = function(file) {
      req(estado$archivos_output)
      file.copy(estado$archivos_output$validaciones, file)
    }
  )

  output$dl_resumen <- downloadHandler(
    filename = function() sprintf("resumen_revaluo_%d.xlsx", as.integer(input$anio_ejercicio)),
    content  = function(file) {
      req(estado$archivos_output)
      file.copy(estado$archivos_output$resumen, file)
    }
  )
}

# ─────────────────────────────────────────────
shinyApp(ui, server)
