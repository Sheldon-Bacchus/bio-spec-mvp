# go_db_probe.R
options(repos = c(CRAN = "https://cloud.r-project.org"))
library(BiocManager)
res <- tryCatch({
  install("GO.db", ask = FALSE, update = FALSE, type = "source")
  "OK"
}, error = function(e) paste("INSTALL_ERROR:", conditionMessage(e)))
cat("PROBE_RESULT:", res, "\n")
cat("GOdb_available:", requireNamespace("GO.db", quietly = TRUE), "\n")
# also probe RSQLite
cat("RSQLite:", requireNamespace("RSQLite", quietly = TRUE), "\n")
