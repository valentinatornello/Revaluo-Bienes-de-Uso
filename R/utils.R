required_packages <- c(
  "tidyverse",
  "readxl",
  "openxlsx",
  "janitor",
  "lubridate",
  "targets"
)

load_required_packages <- function(packages = required_packages) {
  invisible(lapply(packages, library, character.only = TRUE))
}
