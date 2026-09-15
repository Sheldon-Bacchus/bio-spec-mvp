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

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

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
        key <- gsub("-", "_", sub("=.*$", "", key_val))
        res[[key]] <- sub("^[^=]*=", "", key_val)
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
  input = "",
  metadata = "",
  manifest = "",
  source_revision = "",
  group_col = "group",
  batch_col = "batch",
  outdir = ".",
  output = "pca_qc.pdf"
)

opt <- parse_args(defaults)

if (!nzchar(opt$input) || !nzchar(opt$metadata) || !nzchar(opt$manifest)) {
  contract_stop("--input, --metadata, and --manifest are required; PCA metadata inference is disabled")
}
opt$input <- assert_explicit_path(opt$input, "PCA expression matrix", must_exist = TRUE)
opt$metadata <- assert_explicit_path(opt$metadata, "sample metadata", must_exist = TRUE)
opt$manifest <- assert_explicit_path(opt$manifest, "manifest", must_exist = TRUE)
manifest <- validate_manifest_context(
  opt$manifest,
  source_revision = if (nzchar(opt$source_revision)) opt$source_revision else NULL,
  metadata_path = opt$metadata
)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat(sprintf("[INFO] Starting PCA QC Analysis on %s\n", opt$input))

# ------------------------------------------------------------------------------
# Step 1: Read Expression Matrix
# ------------------------------------------------------------------------------
metadata_contract <- read_metadata_contract(opt$metadata)
exp_mat <- read_expression_matrix_contract(opt$input, metadata_contract)

cat(sprintf("[INFO] Loaded expression matrix: %d genes across %d samples\n", nrow(exp_mat), ncol(exp_mat)))

# ------------------------------------------------------------------------------
# Step 2: Read Canonical Metadata
# ------------------------------------------------------------------------------
sample_names <- colnames(exp_mat)
meta_df <- data.frame(
  sample_id = metadata_contract$sample_id,
  Group = metadata_contract$group,
  Batch = metadata_contract$batch,
  stringsAsFactors = FALSE
)
if (!identical(as.character(sample_names), as.character(meta_df$sample_id))) {
  contract_stop("sample_order_mismatch: PCA matrix and canonical metadata differ")
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

write_stage_status(
  manifest,
  "bio-02-batch-norm-pca-qc",
  "success",
  "PCA QC rendered from canonical sample, group, and batch metadata",
  commandArgs(trailingOnly = FALSE),
  c(opt$input, opt$metadata),
  out_pdf_path,
  sample_names,
  status_path = file.path(opt$outdir, "status", "bio-02-batch-norm-pca-qc.json"),
  exit_code = 0
)
