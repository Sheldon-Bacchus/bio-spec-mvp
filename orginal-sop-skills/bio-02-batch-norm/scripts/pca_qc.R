#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-02-batch-norm
# Script: pca_qc.R
# Description: Principal Component Analysis (PCA) Quality Control visualization:
#              computes PCA via prcomp(), plots samples colored by biological group
#              and batch identifier using ggplot2, and outputs multi-panel pca_qc.pdf.
# Quality Gate: Biological groups should separate; batch sources should mix.
# Reproducibility: set.seed(12345)
# ==============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(gridExtra)
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
        res[[parts[1]]] <- parts[2]
      } else if (i + 1 <= length(args) && !grepl("^--", args[i + 1])) {
        res[[key_val]] <- args[i + 1]
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
  input = "merge.normalize.txt",
  pd = "PD.csv",
  group_col = "group",
  batch_col = "batch",
  outdir = ".",
  output = "pca_qc.pdf"
)

opt <- parse_args(defaults)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat(sprintf("[INFO] Starting PCA QC Analysis on %s\n", opt$input))

# ------------------------------------------------------------------------------
# Step 1: Read Expression Matrix
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) {
  stop(sprintf("[ERROR] Input expression matrix not found: %s", opt$input))
}

exp_df <- read.table(opt$input, header = TRUE, sep = "\t", quote = "", check.names = FALSE, fill = TRUE)
genes <- as.character(exp_df[[1]])
exp_mat <- as.matrix(exp_df[, -1, drop = FALSE])
rownames(exp_mat) <- genes
mode(exp_mat) <- "numeric"

cat(sprintf("[INFO] Loaded expression matrix: %d genes across %d samples\n", nrow(exp_mat), ncol(exp_mat)))

# ------------------------------------------------------------------------------
# Step 2: Read Metadata / Infer Groups and Batches
# ------------------------------------------------------------------------------
sample_names <- colnames(exp_mat)
meta_df <- data.frame(sample = sample_names, stringsAsFactors = FALSE)

if (file.exists(opt$pd)) {
  cat(sprintf("[INFO] Reading phenotype metadata from %s\n", opt$pd))
  pd <- if (grepl("\\.csv$", opt$pd, ignore.case = TRUE)) {
    read.csv(opt$pd, stringsAsFactors = FALSE)
  } else {
    read.table(opt$pd, header = TRUE, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
  }
  
  sample_col <- if ("sample" %in% colnames(pd)) "sample" else colnames(pd)[1]
  
  # Match samples
  m_idx <- match(sample_names, pd[[sample_col]])
  if (any(is.na(m_idx))) {
    # Try match after stripping prefix (e.g. GSE10030_GSM...)
    stripped <- sub("^[^_]+_", "", sample_names)
    m_idx <- match(stripped, pd[[sample_col]])
  }
  
  if (opt$group_col %in% colnames(pd) && !all(is.na(m_idx))) {
    meta_df$Group <- pd[[opt$group_col]][m_idx]
  } else {
    meta_df$Group <- ifelse(grepl("biofilm|treat|tumor|case", sample_names, ignore.case = TRUE), "Biofilm", "Planktonic")
  }
  
  if (opt$batch_col %in% colnames(pd) && !all(is.na(m_idx))) {
    meta_df$Batch <- pd[[opt$batch_col]][m_idx]
  } else {
    meta_df$Batch <- sapply(strsplit(sample_names, "_"), `[`, 1)
  }
} else {
  cat("[WARN] Phenotype file not provided or not found. Inferring metadata from sample names.\n")
  meta_df$Group <- ifelse(grepl("biofilm|treat|tumor|case", sample_names, ignore.case = TRUE), "Biofilm", "Planktonic")
  meta_df$Batch <- sapply(strsplit(sample_names, "_"), `[`, 1)
}

# Ensure factors
meta_df$Group[is.na(meta_df$Group)] <- "Unknown"
meta_df$Batch[is.na(meta_df$Batch)] <- "Batch1"
meta_df$Group <- as.factor(meta_df$Group)
meta_df$Batch <- as.factor(meta_df$Batch)

# ------------------------------------------------------------------------------
# Step 3: Run Principal Component Analysis (prcomp)
# ------------------------------------------------------------------------------
# Remove zero-variance genes
gene_vars <- apply(exp_mat, 1, var, na.rm = TRUE)
valid_genes <- gene_vars > 1e-6
if (sum(!valid_genes) > 0) {
  cat(sprintf("[INFO] Filtered %d zero-variance genes prior to PCA\n", sum(!valid_genes)))
  exp_mat <- exp_mat[valid_genes, , drop = FALSE]
}

cat("[INFO] Computing PCA via prcomp()...\n")
pca_res <- prcomp(t(exp_mat), scale. = TRUE)

var_explained <- (pca_res$sdev^2) / sum(pca_res$sdev^2) * 100
pc1_var <- round(var_explained[1], 2)
pc2_var <- round(var_explained[2], 2)

pca_data <- data.frame(
  Sample = sample_names,
  PC1 = pca_res$x[, 1],
  PC2 = pca_res$x[, 2],
  Group = meta_df$Group,
  Batch = meta_df$Batch,
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------------------------
# Step 4: Generate ggplot2 Visualizations
# ------------------------------------------------------------------------------
theme_custom <- theme_bw(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

# Plot A: Biological Group Separation
p_group <- ggplot(pca_data, aes(x = PC1, y = PC2, color = Group, shape = Group)) +
  geom_point(size = 3.5, alpha = 0.85) +
  stat_ellipse(aes(fill = Group), geom = "polygon", alpha = 0.15, level = 0.95, show.legend = FALSE) +
  labs(
    title = "PCA: Biological Group Separation",
    subtitle = "Quality Gate: Samples should cluster by biological phenotype",
    x = sprintf("PC1 (%0.1f%% variance)", pc1_var),
    y = sprintf("PC2 (%0.1f%% variance)", pc2_var)
  ) +
  theme_custom

# Plot B: Batch Effect Mixing
p_batch <- ggplot(pca_data, aes(x = PC1, y = PC2, color = Batch, shape = Batch)) +
  geom_point(size = 3.5, alpha = 0.85) +
  stat_ellipse(aes(fill = Batch), geom = "polygon", alpha = 0.15, level = 0.95, show.legend = FALSE) +
  labs(
    title = "PCA: Batch Distribution & Mixing",
    subtitle = "Quality Gate: Batches should intermix (no batch-specific clusters)",
    x = sprintf("PC1 (%0.1f%% variance)", pc1_var),
    y = sprintf("PC2 (%0.1f%% variance)", pc2_var)
  ) +
  theme_custom

# ------------------------------------------------------------------------------
# Step 5: Save Multi-Panel QC Plot to PDF
# ------------------------------------------------------------------------------
out_pdf_path <- file.path(opt$outdir, opt$output)
cat(sprintf("[INFO] Saving 2-panel PCA QC figure to %s\n", out_pdf_path))

pdf(out_pdf_path, width = 12, height = 5.5)
grid.arrange(p_group, p_batch, ncol = 2)
dev.off()

cat(sprintf("[SUCCESS] PCA QC completed successfully. File generated: %s\n", out_pdf_path))
