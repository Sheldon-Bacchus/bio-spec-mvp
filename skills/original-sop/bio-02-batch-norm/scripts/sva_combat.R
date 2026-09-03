#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-02-batch-norm
# Script: sva_combat.R
# Description: Multi-dataset expression matrix merging, gene intersection extraction,
#              batch effect removal via sva::ComBat (Empirical Bayes),
#              and before/after quality control boxplot generation.
# Reproducibility: set.seed(12345)
# ==============================================================================

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
  indir = ".",
  pattern = ".*\\.normalize\\.txt$",
  input_files = "",                          # Comma-separated list of files (overrides pattern)
  pd = "",                                   # Phenotype/group file to protect biological condition
  outdir = ".",
  out_prenorm = "merge.preNorm.txt",
  out_norm = "merge.normalize.txt",
  out_boxplot = "boxplot_comparison.pdf"
)

opt <- parse_args(defaults)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting ComBat Batch Effect Removal Pipeline\n")

# ------------------------------------------------------------------------------
# Step 1: Collect Input Dataset Files
# ------------------------------------------------------------------------------
if (nchar(opt$input_files) > 0) {
  files <- trimws(unlist(strsplit(opt$input_files, ",")))
} else {
  files <- list.files(path = opt$indir, pattern = opt$pattern, full.names = TRUE)
  # Filter out previously merged files if present
  files <- files[!grepl("merge\\.preNorm|merge\\.normalize", basename(files))]
}

if (length(files) < 2) {
  stop(sprintf("[ERROR] At least 2 dataset files are required for batch effect removal. Found %d.", length(files)))
}

cat(sprintf("[INFO] Processing %d dataset files:\n", length(files)))
for (f in files) cat(sprintf("  - %s\n", basename(f)))

# ------------------------------------------------------------------------------
# Step 2: Extract Gene Intersections Across All Datasets
# ------------------------------------------------------------------------------
gene_list <- list()
dataset_mats <- list()
dataset_tags <- c()

for (i in seq_along(files)) {
  f <- files[i]
  tag <- sub("\\..*", "", basename(f))
  dataset_tags <- c(dataset_tags, tag)
  
  df <- read.table(f, header = TRUE, sep = "\t", quote = "", check.names = FALSE, fill = TRUE)
  genes <- as.character(df[[1]])
  m <- as.matrix(df[, -1, drop = FALSE])
  rownames(m) <- genes
  mode(m) <- "numeric"
  
  # Avereps for any within-dataset replicates
  m <- avereps(m)
  
  # Rename columns to ensure uniqueness across datasets: Tag_SampleID
  colnames(m) <- paste0(tag, "_", colnames(m))
  
  gene_list[[tag]] <- rownames(m)
  dataset_mats[[tag]] <- m
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
cat("[INFO] Batch composition:\n")
print(table(batch_vec))

# Export pre-batch matrix
out_prenorm_path <- file.path(opt$outdir, opt$out_prenorm)
cat(sprintf("[INFO] Exporting pre-normalization matrix to %s\n", out_prenorm_path))
write.table(data.frame(Symbol = rownames(all_tab), all_tab, check.names = FALSE),
            file = out_prenorm_path, sep = "\t", quote = FALSE, row.names = FALSE)

# ------------------------------------------------------------------------------
# Step 4: ComBat Batch Effect Removal
# ------------------------------------------------------------------------------
batch_factor <- as.factor(batch_vec)

mod <- NULL
if (nchar(opt$pd) > 0 && file.exists(opt$pd)) {
  cat(sprintf("[INFO] Loading phenotype data from %s to protect biological covariates...\n", opt$pd))
  pd <- read.csv(opt$pd, stringsAsFactors = FALSE)
  
  # Match samples
  sample_col <- if ("sample" %in% colnames(pd)) "sample" else colnames(pd)[1]
  group_col <- if ("group" %in% colnames(pd)) "group" else colnames(pd)[2]
  
  # Find matching names either directly or with tag prefix
  pd_samples <- pd[[sample_col]]
  mat_samples <- colnames(all_tab)
  
  # Check direct match or suffix match
  matched_indices <- match(mat_samples, pd_samples)
  if (any(is.na(matched_indices))) {
    # Try matching without batch prefix
    stripped_samples <- sub("^[^_]+_", "", mat_samples)
    matched_indices <- match(stripped_samples, pd_samples)
  }
  
  if (!any(is.na(matched_indices))) {
    groups <- pd[[group_col]][matched_indices]
    if (length(unique(groups)) > 1) {
      mod <- model.matrix(~ as.factor(groups))
      cat(sprintf("[INFO] Constructed biological condition design matrix protecting '%s'.\n", group_col))
    }
  } else {
    cat("[WARN] Could not match all sample names with phenotype data. Proceeding without biological condition matrix.\n")
  }
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
