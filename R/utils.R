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
