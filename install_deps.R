# Diagnostico de conexion
cat("Probando conexion a internet...\n")

# Probar con wininet (metodo nativo de Windows)
options(download.file.method = "wininet")

tryCatch({
  readLines("https://cloud.r-project.org", n = 1)
  cat("Conexion OK con wininet\n")
}, error = function(e) {
  cat("Error wininet:", e$message, "\n")
})

# Probar proxy del sistema
cat("\nProxy del sistema:\n")
cat(Sys.getenv("http_proxy"), "\n")
cat(Sys.getenv("https_proxy"), "\n")
cat(Sys.getenv("HTTP_PROXY"), "\n")
cat(Sys.getenv("HTTPS_PROXY"), "\n")

# Intentar instalar con wininet
cat("\nIntentando instalar paquetes...\n")
install.packages(
  c("shiny", "tidyverse", "readxl", "openxlsx", "janitor", "lubridate"),
  repos = "https://cloud.r-project.org",
  method = "wininet"
)
