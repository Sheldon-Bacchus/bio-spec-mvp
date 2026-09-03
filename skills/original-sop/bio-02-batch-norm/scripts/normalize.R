#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-02-batch-norm
# Script: normalize.R
# Description: Parameterized normalization of microarray expression matrices:
#              log2 transformation detection and application, quantile normalization
#              via limma::normalizeBetweenArrays, and structured matrix export.
# Reproducibility: set.seed(12345)
# ==============================================================================

suppressPackageStartupMessages({
  library(limma)
})

set.seed(12345)

# ------------------------------------------------------------------------------
# Argument Parser Helper
# ------------------------------------------------------------------------------
parse_args <- function(defaults) {
  args <- commandArgs(trailingOnly = TRUE)
  res <- defaults
  i <- 1
  while (i <= length(args)) {
    arg <- args[i]
    if (grepl("^--", arg)) {
      key_val <- sub("^--", "", arg)
      if (grepl("=", key_val)) {
        parts <- strsplit(key_val, "=", fixed = TRUE)[[1]]
        key <- gsub("-", "_", parts[1])
        res[[key]] <- parts[2]
      } else if (i + 1 <= length(args) && !grepl("^--", args[i + 1])) {
        res[[gsub("-", "_", key_val)]] <- args[i + 1]
        i <- i + 1
      } else {
        res[[key_val]] <- TRUE
      }
    }
    i <- i + 1
  }
  return(res)
}

# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------
defaults <- list(
  input = "biofilm.genesyb_mean.exprs.txt",
  geo_id = "GSE10030",
  con_file = "s1.txt",
  treat_file = "s2.txt",
  method = "quantile",
  outdir = "."
)

opt <- parse_args(defaults)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat(sprintf("[INFO] Starting Normalization for %s\n", opt$geo_id))
cat(sprintf("[INFO] Input file: %s\n", opt$input))
cat(sprintf("[INFO] Normalization method: %s\n", opt$method))

# ------------------------------------------------------------------------------
# Step 1: Read Expression Matrix
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) {
  stop(sprintf("[ERROR] Input file not found: %s", opt$input))
}

raw_df <- read.table(opt$input, header = TRUE, sep = "\t", quote = "", check.names = FALSE, fill = TRUE)
gene_names <- as.character(raw_df[[1]])
exp_mat <- as.matrix(raw_df[, -1, drop = FALSE])
rownames(exp_mat) <- gene_names
mode(exp_mat) <- "numeric"

# Handle replicate gene symbols
exp_mat <- avereps(exp_mat)
cat(sprintf("[INFO] Matrix dimensions: %d genes across %d samples\n", nrow(exp_mat), ncol(exp_mat)))

# ------------------------------------------------------------------------------
# Step 2: Log2 Transformation Check
# ------------------------------------------------------------------------------
qx <- as.numeric(quantile(exp_mat, c(0, 0.25, 0.5, 0.75, 0.99, 1.0), na.rm = TRUE))
LogC <- ((qx[5] > 100) || ((qx[6] - qx[1]) > 50 && qx[2] > 0))

if (LogC) {
  cat("[INFO] Expression values exceed normal log2 thresholds. Performing log2(x + 1) transformation...\n")
  exp_mat[exp_mat < 0] <- 0
  exp_mat <- log2(exp_mat + 1)
} else {
  cat("[INFO] Expression values are already in log2 scale. Skipping log2 transformation.\n")
}

# ------------------------------------------------------------------------------
# Step 3: Quantile Normalization (normalizeBetweenArrays)
# ------------------------------------------------------------------------------
cat(sprintf("[INFO] Running limma::normalizeBetweenArrays (method='%s')...\n", opt$method))
norm_mat <- normalizeBetweenArrays(exp_mat, method = opt$method)

# ------------------------------------------------------------------------------
# Step 4: Sample Ordering & Partitioning (If group files exist)
# ------------------------------------------------------------------------------
final_mat <- norm_mat

if (file.exists(opt$con_file) && file.exists(opt$treat_file)) {
  cat("[INFO] Applying sample grouping from con_file and treat_file...\n")
  sample1 <- read.table(opt$con_file, header = FALSE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
  sample2 <- read.table(opt$treat_file, header = FALSE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
  
  con_samples <- intersect(trimws(as.character(sample1[, 1])), colnames(norm_mat))
  treat_samples <- intersect(trimws(as.character(sample2[, 1])), colnames(norm_mat))
  
  if (length(con_samples) > 0 && length(treat_samples) > 0) {
    con_data <- norm_mat[, con_samples, drop = FALSE]
    treat_data <- norm_mat[, treat_samples, drop = FALSE]
    final_mat <- cbind(con_data, treat_data)
    cat(sprintf("[INFO] Organized samples: %d Control, %d Treat\n", length(con_samples), length(treat_samples)))
  } else {
    cat("[WARN] Specified sample IDs not found in matrix columns. Preserving original matrix column order.\n")
  }
}

# ------------------------------------------------------------------------------
# Step 5: Export Normalized File
# ------------------------------------------------------------------------------
output_file <- file.path(opt$outdir, sprintf("%s.normalize.txt", opt$geo_id))
out_df <- data.frame(Symbol = rownames(final_mat), final_mat, check.names = FALSE)
write.table(out_df, file = output_file, sep = "\t", quote = FALSE, row.names = FALSE)

cat(sprintf("[SUCCESS] Saved normalized matrix to %s (%d genes, %d samples)\n",
            output_file, nrow(final_mat), ncol(final_mat)))
