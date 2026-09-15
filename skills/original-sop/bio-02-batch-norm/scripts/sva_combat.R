#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-02-batch-norm
# Script: sva_combat.R
# Description: Multi-dataset expression matrix merging, gene intersection extraction,
#              batch effect removal via sva::ComBat (Empirical Bayes),
#              and before/after quality control boxplot generation.
# Reproducibility: set.seed(12345)
# ==============================================================================

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

suppressPackageStartupMessages({
  library(limma)
  library(sva)
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
  indir = ".",
  pattern = ".*\\.normalize\\.txt$",             # Deprecated; never used for discovery
  input_files = "",                          # Required comma-separated list of files
  pd = "",                                   # Deprecated alias; canonical metadata is required
  metadata = "",                             # Canonical sample metadata CSV/TSV
  manifest = "",                             # Run manifest JSON
  source_revision = "",
  outdir = ".",
  out_prenorm = "merge.preNorm.txt",
  out_norm = "merge.normalize.txt",
  out_boxplot = "boxplot_comparison.pdf"
)

opt <- parse_args(defaults)

if (!nzchar(opt$input_files) || !nzchar(opt$metadata) || !nzchar(opt$manifest)) {
  contract_stop("--input-files, --metadata, and --manifest are required; current-directory discovery and group heuristics are disabled")
}
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

cat("[INFO] Starting ComBat Batch Effect Removal Pipeline\n")

# ------------------------------------------------------------------------------
# Step 1: Collect Input Dataset Files
# ------------------------------------------------------------------------------
files <- trimws(unlist(strsplit(opt$input_files, ",", fixed = TRUE)))
files <- vapply(files, assert_explicit_path, character(1), label = "batch input", must_exist = TRUE)

if (length(files) < 1) {
  contract_stop("at least one explicit expression matrix is required for batch effect removal")
}

cat(sprintf("[INFO] Processing %d dataset files:\n", length(files)))
for (f in files) cat(sprintf("  - %s\n", basename(f)))

# ------------------------------------------------------------------------------
# Step 2: Extract Gene Intersections Across All Datasets
# ------------------------------------------------------------------------------
gene_list <- list()
dataset_mats <- list()
dataset_tags <- c()
metadata_contract <- read_metadata_contract(opt$metadata)
all_sample_ids <- character()

for (i in seq_along(files)) {
  f <- files[i]
  tag <- paste0("input_", i)
  dataset_tags <- c(dataset_tags, tag)

  m <- read_expression_matrix_contract(f)
  if (length(intersect(colnames(m), all_sample_ids)) > 0) {
    contract_stop(sprintf("duplicate_sample_id across batch inputs: %s", paste(intersect(colnames(m), all_sample_ids), collapse = ", ")))
  }
  all_sample_ids <- c(all_sample_ids, colnames(m))
  
  # Avereps for any within-dataset replicates
  m <- avereps(m)
  
  gene_list[[tag]] <- rownames(m)
  dataset_mats[[tag]] <- m
}

if (!identical(as.character(all_sample_ids), as.character(metadata_contract$sample_id))) {
  contract_stop("sample_order_mismatch: concatenated batch matrices must equal canonical metadata order")
}

common_genes <- Reduce(intersect, gene_list)
cat(sprintf("[INFO] Found %d common genes intersected across all %d datasets.\n", length(common_genes), length(files)))

if (length(common_genes) < 50) {
  stop("[ERROR] Common gene intersection is too small (<50 genes). Check gene symbol identifiers across datasets.")
}

# ------------------------------------------------------------------------------
# Step 3: Merge Matrices and Construct Batch Label Vector
# ------------------------------------------------------------------------------
all_tab <- NULL
batch_vec <- c()

for (i in seq_along(dataset_mats)) {
  tag <- dataset_tags[i]
  m_sub <- dataset_mats[[tag]][common_genes, , drop = FALSE]
  
  if (is.null(all_tab)) {
    all_tab <- m_sub
  } else {
    all_tab <- cbind(all_tab, m_sub)
  }
  batch_vec <- c(batch_vec, rep(tag, ncol(m_sub)))
}

cat(sprintf("[INFO] Combined matrix dimensions: %d genes across %d samples\n", nrow(all_tab), ncol(all_tab)))
batch_vec <- as.character(metadata_contract$batch)
if (length(batch_vec) != ncol(all_tab) || length(unique(batch_vec)) < 2) {
  contract_stop("batch_levels: canonical metadata must contain at least two batch levels aligned to the merged matrix")
}
cat("[INFO] Canonical batch composition:\n")
print(table(batch_vec))

# Export pre-batch matrix
out_prenorm_path <- file.path(opt$outdir, opt$out_prenorm)
cat(sprintf("[INFO] Exporting pre-normalization matrix to %s\n", out_prenorm_path))
write.table(data.frame(Symbol = rownames(all_tab), all_tab, check.names = FALSE),
            file = out_prenorm_path, sep = "\t", quote = FALSE, row.names = FALSE)

# ------------------------------------------------------------------------------
# Step 4: ComBat Batch Effect Removal
# ------------------------------------------------------------------------------
batch_factor <- as.factor(metadata_contract$batch)

mod <- NULL
groups <- metadata_contract$group
if (length(unique(groups)) > 1) {
  mod <- model.matrix(~ as.factor(groups))
  cat("[INFO] Constructed biological condition design matrix from canonical metadata.\n")
}

cat("[INFO] Running sva::ComBat (par.prior = TRUE)...\n")
combat_tab <- ComBat(dat = as.matrix(all_tab), batch = batch_factor, mod = mod, par.prior = TRUE)

# Export ComBat normalized matrix
out_norm_path <- file.path(opt$outdir, opt$out_norm)
cat(sprintf("[INFO] Exporting ComBat normalized matrix to %s\n", out_norm_path))
write.table(data.frame(Symbol = rownames(combat_tab), combat_tab, check.names = FALSE),
            file = out_norm_path, sep = "\t", quote = FALSE, row.names = FALSE)

# Also output as CSV for downstream compatibility if needed
write.csv(combat_tab, file = file.path(opt$outdir, "merge.normalize.csv"), quote = FALSE)

# ------------------------------------------------------------------------------
# Step 5: Before / After Boxplot Comparison Generation
# ------------------------------------------------------------------------------
boxplot_path <- file.path(opt$outdir, opt$out_boxplot)
cat(sprintf("[INFO] Generating before/after boxplot comparison to %s\n", boxplot_path))

# Assign colors according to batch
batch_levels <- levels(batch_factor)
palette <- rainbow(length(batch_levels), alpha = 0.6)
sample_colors <- palette[as.numeric(batch_factor)]

pdf(boxplot_path, width = 14, height = 7)
par(mfrow = c(1, 2), mar = c(8, 4, 3, 1) + 0.1)

# Boxplot Before
boxplot(all_tab, col = sample_colors, las = 2, outline = FALSE,
        main = "Before Batch Correction (Raw / Merged)",
        ylab = "Expression (log2)", cex.axis = 0.6)
legend("topright", legend = batch_levels, fill = palette, bty = "n", cex = 0.8)

# Boxplot After
boxplot(combat_tab, col = sample_colors, las = 2, outline = FALSE,
        main = "After ComBat Batch Correction",
        ylab = "Expression (log2)", cex.axis = 0.6)
legend("topright", legend = batch_levels, fill = palette, bty = "n", cex = 0.8)

dev.off()

cat(sprintf("[SUCCESS] Stage 02 ComBat batch removal complete. Output: %s\n", out_norm_path))

if (exists("write_stage_status") && nzchar(opt$manifest)) {
  write_stage_status(
    manifest,
    "bio-02-batch-norm",
    "success",
    "batch correction completed with canonical sample and batch metadata",
    commandArgs(trailingOnly = FALSE),
    c(files, opt$metadata),
    c(out_prenorm_path, out_norm_path, boxplot_path),
    metadata_contract$sample_id,
    status_path = file.path(opt$outdir, "status", "bio-02-batch-norm.json"),
    exit_code = 0
  )
}
