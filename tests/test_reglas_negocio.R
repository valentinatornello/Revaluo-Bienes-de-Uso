library(tidyverse)

source("R/utils.R")
source("R/01_importar_datos.R")
source("R/02_limpiar_datos.R")
source("R/03_construir_rollforward.R")
source("R/04_calculo_axi.R")
source("R/05_prueba_global.R")
source("R/06_validaciones.R")

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

activo_baja <- activo_prueba %>%
  dplyr::mutate(
    fecha_alta = as.Date("2022-01-01"),
    anio_alta = 2022L,
    fecha_baja = as.Date("2023-04-01"),
    tipo_movimiento_calc = "baja"
  )
resultado_edificios_baja <- calcular_rubro_amortizable(
  activo_baja[1, ], "Edificios", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
resultado_rodados_baja <- calcular_rubro_amortizable(
  activo_baja[2, ], "Rodados", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
stopifnot(resultado_edificios_baja$vut_ejercicio == 2)
stopifnot(resultado_edificios_baja$amort_hist_ejercicio == 1)
stopifnot(resultado_rodados_baja$vut_ejercicio == 1)
stopifnot(resultado_rodados_baja$amort_hist_ejercicio == 20)

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

stopifnot(nrow(edificios) == 5)
stopifnot(sort(edificios$vo[edificios$tipo_movimiento == "alta"]) == c(-10, 20))
# las bajas B1/B2 no estan en la base ni son altas del ejercicio: no se calculan y se informan
stopifnot(!any(edificios$tipo_movimiento == "baja"))
stopifnot(nrow(rollforward$bajas_no_identificadas) == 2, all(rollforward$bajas_no_identificadas$rubro == "Edificios"))
stopifnot(any(edificios$direccion_movimiento == "salida", na.rm = TRUE))
stopifnot(any(edificios$direccion_movimiento == "entrada", na.rm = TRUE))

# criterio "excel" (por defecto): fuera de Edificios la VU/VUT se llevan en anios, como el Excel manual.
stopifnot(criterio_unidad_vu() == "excel")
stopifnot(factor_unidad_archivo("MyU") == 1, factor_unidad_archivo("Edificios") == 1)

activo_sin_vut_ly <- tibble::tibble(
  rubro = "Eq de Oficina",
  nro_activo_fijo = "X1",
  fecha_alta = as.Date("2021-05-01"),
  anio_alta = 2021L,
  mes_alta = 5L,
  vo = 300,
  vu_asignada = 5,
  vut_ly = NA_real_,
  tipo_movimiento_calc = "historico"
)
resultado_anual <- calcular_rubro_amortizable(
  activo_sin_vut_ly, "Eq de Oficina", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
stopifnot(resultado_anual$vut_ly == 2)
stopifnot(resultado_anual$vut_ejercicio == 1)
stopifnot(resultado_anual$vut_cierre == 3)

# hoja tipo Excel del estudio: lo que esta debajo de la fila "Totales" no se calcula.
hoja_con_totales <- tibble::tibble(
  tipo = c("Altas 2020", NA, "Totales", NA),
  nro = c("1", "2", NA, "3"),
  fecha = "43831",
  VO = c("100", "200", "300", "50"),
  vu = "10",
  vut = "1"
)
names(hoja_con_totales) <- c("tipo", "N\u00b0 Activo Fijo", "A\u00f1o a tomar", "VO", "VU Asignada", "VUT LY")
datos_hoja <- list(inventario_ly = list(MyU = hoja_con_totales))
limpio_hoja <- limpiar_datos(datos_hoja, 2023)$inventario_ly$MyU
stopifnot(nrow(limpio_hoja) == 2)
stopifnot(sum(limpio_hoja$vo) == 300)
stopifnot(all(limpio_hoja$vu_asignada == 10), all(limpio_hoja$vut_ly == 1))

# Terrenos no trae la columna "Anio a tomar": aplica el piso 01/01/1992 de la fecha ajustada.
hoja_terrenos <- tibble::tibble(
  tipo = NA_character_,
  activo = "T1",
  fecha = "25355",
  valor = "100"
)
names(hoja_terrenos) <- c("tipo", "Activo fijo", "Fe.capit.", "Val.adq.")
limpio_terrenos <- limpiar_datos(list(inventario_ly = list(Terrenos = hoja_terrenos)), 2023)$inventario_ly$Terrenos
stopifnot(limpio_terrenos$fecha_alta == as.Date("1992-01-01"), limpio_terrenos$anio_alta == 1992)

# un texto suelto en la columna de fechas no anula las demas fechas
fechas <- parsear_fecha_alta(c("43831", "A\u00f1o a tomar", NA))
stopifnot(fechas[1] == as.Date("2020-01-01"), is.na(fechas[2]), is.na(fechas[3]))

# criterio "ricardo": trimestres para todos los rubros salvo Rodados (anios).
options(revaluo.criterio_unidad_vu = "ricardo")
stopifnot(obtener_periodos_por_anio("MyU") == 4, obtener_periodos_por_anio("Rodados") == 1)
stopifnot(obtener_vu_asignada("MyU") == 12, obtener_vu_asignada("Rodados") == 5)
stopifnot(factor_unidad_archivo("MyU") == 4, factor_unidad_archivo("Rodados") == 1)
stopifnot(factor_unidad_archivo("Edificios") == 1)

limpio_ricardo <- limpiar_datos(datos_hoja, 2023)$inventario_ly$MyU
stopifnot(all(limpio_ricardo$vu_asignada == 40), all(limpio_ricardo$vut_ly == 4))

activo_trimestral <- tibble::tibble(
  rubro = "MyU",
  nro_activo_fijo = "M1",
  fecha_alta = as.Date("2023-04-01"),
  anio_alta = 2023L,
  mes_alta = 4L,
  vo = 120,
  vu_asignada = 12,
  vut_ly = 0,
  tipo_movimiento_calc = "historico"
)
resultado_trimestral <- calcular_rubro_amortizable(
  activo_trimestral, "MyU", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
stopifnot(resultado_trimestral$vut_ejercicio == 3)
stopifnot(resultado_trimestral$amort_hist_ejercicio == 30)

baja_trimestral <- activo_trimestral %>%
  dplyr::mutate(
    fecha_alta = as.Date("2022-01-01"), anio_alta = 2022L, mes_alta = 1L,
    fecha_baja = as.Date("2023-04-01"), tipo_movimiento_calc = "baja"
  )
resultado_baja_trimestral <- calcular_rubro_amortizable(
  baja_trimestral, "MyU", indices_prueba, indices_prueba,
  indices_prueba, indices_prueba, 2023
)
stopifnot(resultado_baja_trimestral$vut_ejercicio == 2)

options(revaluo.criterio_unidad_vu = NULL)

# coeficiente pre-2018: 1 por defecto (Excel 2023), IPIM si se pide (Excel 2022)
tabla_ipim_prueba <- tibble::tibble(fecha = as.Date("1990-01-01"), coeficiente = 50)
stopifnot(coeficiente_pre_2018(as.Date("2000-05-01"), tabla_ipim_prueba) == 1)
options(revaluo.coef_pre2018 = "ipim")
stopifnot(coeficiente_pre_2018(as.Date("2000-05-01"), tabla_ipim_prueba) == 50)
options(revaluo.coef_pre2018 = NULL)

# un activo con baja en el ejercicio se toma de la base LY con sus valores congelados y sale de las altas/transferencias
datos_baja <- list(
  inventario_ly = list(
    Rodados = tibble::tibble(
      rubro = "Rodados", tipo_movimiento = "historico", subclasificacion_historico = NA_character_,
      anio_movimiento = NA_integer_, nro_activo_fijo = c("R1", "R2"), descripcion = "Hist",
      fecha_alta = as.Date("2020-01-01"), anio_alta = 2020L, mes_alta = 1L, vo = 100, vu_asignada = 5, vut_ly = 3,
      amort_hist_ly = c(7, 20)
    )
  ),
  altas = tibble::tibble(rubro = "Rodados", nro_activo = c("R1", "R3"), descripcion = "Alta",
                         posting_date = as.Date("2023-02-01"), cap_date_parsed = as.Date("2023-02-01"), valor = 10),
  bajas = tibble::tibble(rubro = "Rodados", nro_activo = c("R1", "R9"), descripcion = "Baja",
                         posting_date = as.Date(c("2023-03-01", "2023-04-01")),
                         cap_date_parsed = as.Date("2020-01-01"), valor = c(40, 5)),
  transferencias = tibble::tibble()
)
rollforward_baja <- construir_rollforward(datos_baja, 2023)
rodados_baja <- rollforward_baja$inventario$Rodados
fila_baja <- rodados_baja[rodados_baja$nro_activo_fijo == "R1" & rodados_baja$tipo_movimiento == "baja", ]
stopifnot(sum(rodados_baja$nro_activo_fijo == "R1" & rodados_baja$tipo_movimiento != "baja") == 0)
stopifnot(nrow(fila_baja) == 1)
stopifnot(all(c("R2", "R3") %in% rodados_baja$nro_activo_fijo))
# valores congelados a LY: el VO de la fila es el de la base (100), no el retiro de SAP (40); fecha de baja = posting date SAP
stopifnot(fila_baja$vo == 100, fila_baja$vut_ly == 3, fila_baja$vu_asignada == 5, fila_baja$anio_alta == 2020L)
stopifnot(fila_baja$fecha_baja == as.Date("2023-03-01"), fila_baja$tipo_movimiento_calc == "baja")
# la amortizacion del ejercicio anterior de la baja se conserva (la PG la necesita)
stopifnot(fila_baja$amort_hist_ly == 7)
# R9 no esta en la base ni es alta del ejercicio: no se calcula y se informa
stopifnot(!"R9" %in% rodados_baja$nro_activo_fijo)
stopifnot(rollforward_baja$bajas_no_identificadas$nro_activo == "R9")
informe_no_id <- validar_bajas_no_identificadas(rollforward_baja$bajas_no_identificadas)
stopifnot(informe_no_id$resultado == "ADVERTENCIA", informe_no_id$valor == 1)

# PG de amortizacion en base flujo: inicio + altas + transferencias + bajas + agotados + irregular = s/revaluo
axi_prueba <- list(Rodados = tibble::tibble(
  anio_movimiento = c(NA, NA, 2023L, 2023L, 2023L),
  tipo_movimiento = c("historico", "historico", "alta", "transferencia", "baja"),
  tipo_movimiento_calc = c("historico", "historico", "alta", "transferencia", "baja"),
  amort_hist_ly = c(10, 5, NA, NA, 2),
  amort_hist_ejercicio = c(12, 0, 3, 4, 1),
  es_vu_agotada_ly = c(FALSE, TRUE, FALSE, FALSE, FALSE)
))
pg_flujo <- generar_pg_amortizaciones(axi_prueba, 2023)
stopifnot(pg_flujo$amort_inicio == 17, pg_flujo$amort_altas == 3, pg_flujo$amort_transferencias == 4)
stopifnot(pg_flujo$amort_bajas == -2, pg_flujo$bs_agotaron_vu_ly == -5, pg_flujo$amort_irregular == 2)
stopifnot(pg_flujo$amort_revaluo == 19, pg_flujo$diferencia == 0)

# PG de AXI como "s/revaluo" del Excel: sin las bajas del ejercicio; amortizacion reexpresada = flujo x coeficiente
axi_bajas <- list(Rodados = tibble::tibble(
  anio_movimiento = c(NA, 2023L), tipo_movimiento = c("historico", "baja"),
  vr = c(10, 4), vr_reexp = c(30, 12), vo_reexp = c(50, 20), amort_acum_cierre_reexp = c(20, 8),
  amort_ejercicio_reexp = c(6, 2)
))
pg_axi_prueba <- generar_pg_axi(axi_bajas, 2023)
stopifnot(pg_axi_prueba$vr_reexp == 30, pg_axi_prueba$vr_hist == 10, pg_axi_prueba$axi_resultado == 20)
stopifnot(pg_axi_prueba$amort_ejercicio_reexp == 6)

# negativos: un VO negativo (reversa) justifica un VR reexpresado negativo; el ruido de punto flotante no cuenta
neg <- validar_valores_reexpresados_negativos(list(Rodados = tibble::tibble(
  tipo_movimiento_calc = c("alta", "historico", "historico"), vo = c(-5, 10, 10),
  vo_reexp = c(-50, 100, 100), vr_reexp = c(-50, -1e-9, 5)
)))
stopifnot(neg$resultado == "OK")
neg_error <- validar_valores_reexpresados_negativos(list(Rodados = tibble::tibble(
  tipo_movimiento_calc = "historico", vo = 10, vo_reexp = 100, vr_reexp = -3
)))
stopifnot(neg_error$resultado == "ERROR")

# conteos SAP: sin conteo esperado para el ejercicio se avisa, no se da por bueno
sin_esperado <- validar_conteos_movimientos(tibble::tibble(
  tipo_movimiento_sap = "alta", filas_detalle = 10L, conteo_esperado = NA_integer_, diferencia_conteo = NA_integer_
))
stopifnot(sin_esperado$resultado == "ADVERTENCIA")

# seleccion del archivo SAP: el del ejercicio, y se frena si es de otro anio
dir_sap_prueba <- file.path(tempdir(), "sap_prueba")
dir.create(dir_sap_prueba, showWarnings = FALSE)
file.create(file.path(dir_sap_prueba, c("Altas-bajas-Transf 12-2022 (Tax).xlsx", "Altas-bajas-Transf 12-2023 (Tax).xlsx")))
stopifnot(grepl("2023", elegir_archivo_sap(dir_sap_prueba, 2023)))
stopifnot(grepl("2022", elegir_archivo_sap(dir_sap_prueba, 2022)))
frena_otro_anio <- tryCatch(
  { elegir_archivo_sap(dir_sap_prueba, 2023, file.path(dir_sap_prueba, "Altas-bajas-Transf 12-2022 (Tax).xlsx")); FALSE },
  error = function(e) TRUE
)
stopifnot(frena_otro_anio)

# el IPC debe llegar al cierre del ejercicio
ipc_corto <- tibble::tibble(fecha = as.Date(c("2022-01-01", "2022-12-31")), coeficiente = c(2, 1))
stopifnot(tryCatch({ validar_cobertura_ipc(ipc_corto, 2023); FALSE }, error = function(e) TRUE))
stopifnot(validar_cobertura_ipc(ipc_corto, 2022))

# "Amort. Historica" del LY (flujo del ejercicio anterior), sin confundirla con la columna 2018/2019/...
hoja_flujo <- tibble::tibble(tipo = "Altas 2022", nro = "1", vo = "100", vu = "10", ly = "7", ly2018 = "9")
names(hoja_flujo) <- c("tipo", "N\u00b0 Activo Fijo", "VO", "VU Asignada", "Amort. Hist\u00f3rica", "Amort. Hist\u00f3rica 2018/2019")
stopifnot(limpiar_datos(list(inventario_ly = list(MyU = hoja_flujo)), 2022)$inventario_ly$MyU$amort_hist_ly == 7)

# base del ejercicio anterior (sin movimientos del ejercicio): el inicio del ejercicio es el cierre del archivo
hoja_anual <- tibble::tibble(tipo = c("Altas 2022", NA), nro = c("1", "2"), vo = c("100", "100"),
                             vu = "10", vut_ly = c("0", "4"), vut = c("1", "5"))
names(hoja_anual) <- c("tipo", "N\u00b0 Activo Fijo", "VO", "VU Asignada", "VUT LY", "VUT")
limpio_anual <- limpiar_datos(list(inventario_ly = list(MyU = hoja_anual)), 2023)$inventario_ly$MyU
stopifnot(limpio_anual$vut_ly == c(1, 5))
limpio_mismo_anio <- limpiar_datos(list(inventario_ly = list(MyU = hoja_anual)), 2022)$inventario_ly$MyU
stopifnot(limpio_mismo_anio$vut_ly == c(0, 4))

cat("OK\n")