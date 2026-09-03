# retry_s05_2.R
options(repos = c(CRAN = "https://cloud.r-project.org"))
library(BiocManager)
install(c("DOSE", "enrichplot", "clusterProfiler"), ask = FALSE, update = FALSE)
for (p in c("DOSE", "enrichplot", "clusterProfiler", "GO.db"))
  cat(sprintf("%-18s %s\n", p, requireNamespace(p, quietly = TRUE)))
cat("S05_RETRY2_DONE\n")
