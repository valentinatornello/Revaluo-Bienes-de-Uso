load_required_packages <- function(
  packages = c(
    "tidyverse",
    "readxl",
    "openxlsx",
    "janitor",
    "lubridate",
    "targets"
  )
) {
  invisible(lapply(packages, library, character.only = TRUE))
}
