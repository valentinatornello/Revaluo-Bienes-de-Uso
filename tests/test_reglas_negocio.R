library(tidyverse)

source("R/utils.R")
source("R/03_construir_rollforward.R")
source("R/04_calculo_axi.R")

stopifnot(obtener_vu_asignada("Edificios") == 200)
stopifnot(obtener_vu_asignada("Rodados") == 5)
stopifnot(obtener_periodos_por_anio("Edificios") == 4)
stopifnot(obtener_periodos_por_anio("Rodados") == 1)

indices_prueba <- tibble::tibble(fecha = as.Date("2022-01-01"), coeficiente = 1)
activo_prueba <- tibble::tibble(
  rubro = c("Edificios", "Rodados"),
  nro_activo_fijo = c("E1", "R1"),
  fecha_alta = as.Date(c("2023-01-01", "2023-01-01")),
  anio_alta = 2023L,
  mes_alta = 1L,
  vo = 100,
  vu_asignada = c(200, 5),
  vut_ly = 0,
  tipo_movimiento_calc = "historico"
)
resultado_edificios <- calcular_rubro_amortizable(
  activo_prueba[1, ], "Edificios", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
resultado_rodados <- calcular_rubro_amortizable(
  activo_prueba[2, ], "Rodados", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
stopifnot(resultado_edificios$vut_ejercicio == 4)
stopifnot(resultado_edificios$amort_hist_ejercicio == 2)
stopifnot(resultado_rodados$vut_ejercicio == 1)
stopifnot(resultado_rodados$amort_hist_ejercicio == 20)

activo_alta_parcial <- activo_prueba %>%
  dplyr::mutate(
    fecha_alta = as.Date("2023-04-01"),
    mes_alta = 4L
  )
resultado_edificios_parcial <- calcular_rubro_amortizable(
  activo_alta_parcial[1, ], "Edificios", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
resultado_rodados_parcial <- calcular_rubro_amortizable(
  activo_alta_parcial[2, ], "Rodados", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
stopifnot(resultado_edificios_parcial$vut_ejercicio == 3)
stopifnot(resultado_edificios_parcial$amort_hist_ejercicio == 1.5)
stopifnot(resultado_rodados_parcial$vut_ejercicio == 1)
stopifnot(resultado_rodados_parcial$amort_hist_ejercicio == 20)

movimiento_rodados <- tibble::tibble(
  nro_activo = "R-SAP",
  descripcion = "Rodado de prueba",
  posting_date = as.Date("2023-04-01"),
  cap_date_parsed = as.Date("2023-04-01"),
  valor = 100
)
alta_rodados <- normalizar_movimiento_sap(
  movimiento_rodados, "Rodados", "alta", 2023
)
baja_rodados <- normalizar_baja_sap(movimiento_rodados, "Rodados", 2023)
stopifnot(alta_rodados$vu_asignada == 5)
stopifnot(baja_rodados$vu_asignada == 5)

inv <- tibble::tibble(
  rubro = c("Edificios", "Edificios"),
  nro_activo_fijo = c("100", "200"),
  fecha_alta = as.Date(c("1980-01-01", "1980-01-01"))
)

excepciones <- tibble::tibble(
  rubro = "Edificios",
  nro_activo_fijo = "100",
  fecha_base_reexpresion = as.Date("1992-03-01"),
  inicio_indice_desde = as.Date("1992-04-01"),
  motivo = "Manual indica reexpresado hasta marzo 1992",
  fuente_manual = "nota Edificios",
  activo = TRUE
)

inv_con_excepciones <- aplicar_excepciones_fecha_base(inv, excepciones)

stopifnot(inv_con_excepciones$fecha_indice_reexp[1] == as.Date("1992-04-01"))
stopifnot(isTRUE(inv_con_excepciones$regla_fecha_base_aplicada[1]))
stopifnot(inv_con_excepciones$fecha_indice_reexp[2] == as.Date("1980-01-01"))
stopifnot(!isTRUE(inv_con_excepciones$regla_fecha_base_aplicada[2]))

stopifnot(es_fila_detalle_sap("123456"))
stopifnot(!es_fila_detalle_sap("Total 31.12.2023"))
stopifnot(!es_fila_detalle_sap("Grand Total"))
stopifnot(!es_fila_detalle_sap(NA_character_))

datos_rollforward <- list(
  inventario_ly = list(
    Edificios = tibble::tibble(
      rubro = "Edificios",
      tipo_movimiento = "historico",
      subclasificacion_historico = NA_character_,
      anio_movimiento = NA_integer_,
      nro_activo_fijo = "H1",
      descripcion = "Hist",
      fecha_alta = as.Date("2022-01-01"),
      anio_alta = 2022L,
      mes_alta = 1L,
      vo = 100,
      vu_asignada = 200,
      vut_ly = 0
    )
  ),
  altas = tibble::tibble(
    rubro = "Edificios",
    nro_activo = c("A1", "A2"),
    descripcion = c("Alta 1", "Alta 2"),
    posting_date = as.Date(c("2023-01-01", "2023-02-01")),
    cap_date_parsed = as.Date(c("2023-01-01", "2023-02-01")),
    valor = c(-10, 20)
  ),
  bajas = tibble::tibble(
    rubro = "Edificios",
    nro_activo = c("B1", "B2"),
    descripcion = c("Baja 1", "Baja 2"),
    posting_date = as.Date(c("2023-03-01", "2023-04-01")),
    cap_date_parsed = as.Date(c("2020-01-01", "2020-02-01")),
    valor = c(-5, 6)
  ),
  transferencias = tibble::tibble(
    rubro = "Edificios",
    nro_activo = c("T1", "T2"),
    descripcion = c("Transf 1", "Transf 2"),
    posting_date = as.Date(c("2023-05-01", "2023-06-01")),
    cap_date_parsed = as.Date(c("2021-01-01", "2021-02-01")),
    valor = c(-7, 8)
  )
)

rollforward <- construir_rollforward(datos_rollforward, 2023)
edificios <- rollforward$inventario$Edificios

stopifnot(nrow(edificios) == 7)
stopifnot(all(edificios$vo[edificios$tipo_movimiento == "alta"] >= 0))
stopifnot(all(edificios$vo[edificios$tipo_movimiento == "baja"] >= 0))
stopifnot(any(edificios$direccion_movimiento == "salida", na.rm = TRUE))
stopifnot(any(edificios$direccion_movimiento == "entrada", na.rm = TRUE))

cat("OK\n")