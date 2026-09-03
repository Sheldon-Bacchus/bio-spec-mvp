# install_toydata_pkgs.R
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
bioc_pkgs <- c("limma","sva","WGCNA","impute","Biobase","pheatmap","clusterProfiler","enrichplot","org.Hs.eg.db","pathview","ggrepel","flashClust","UpSetR")
cran_pkgs <- c("glmnet","pROC","randomForest","VennDiagram","ggplot2","dplyr","gridExtra","RColorBrewer","rfPermute")
BiocManager::install(c(bioc_pkgs, cran_pkgs), ask = FALSE, update = FALSE)
cat("INSTALL_DONE\n")
