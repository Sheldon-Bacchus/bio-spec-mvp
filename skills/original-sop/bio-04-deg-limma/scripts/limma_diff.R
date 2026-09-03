#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-04-deg-limma
# Script: limma_diff.R
# Description: Parameterized differential expression analysis using limma:
#              linear modeling (lmFit), empirical Bayes shrinkage (eBayes),
#              FDR multiple testing correction, DEG threshold filtering,
#              and structured outputs (all.txt, diff.txt, diffGeneExp.txt, heatmap.pdf).
# Reproducibility: set.seed(12345)
# ==============================================================================

suppressPackageStartupMessages({
  library(limma)
  library(pheatmap)
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
  input = "merge.normalize.txt",
  pd = "",                                   # Optional PD.csv or group.txt
  s1 = "s1.txt",                             # Control sample file
  s2 = "s2.txt",                             # Treat sample file
  logfc = "1.0",                             # Absolute logFC threshold
  fdr = "0.05",                              # Adjusted p-value threshold
  top_heatmap = "50",                        # Number of top DEGs in heatmap
  outdir = "."
)

opt <- parse_args(defaults)
opt$logfc <- as.numeric(opt$logfc)
opt$fdr <- as.numeric(opt$fdr)
opt$top_heatmap <- as.integer(opt$top_heatmap)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting limma Differential Expression Analysis\n")
cat(sprintf("[INFO] Input matrix: %s\n", opt$input))
cat(sprintf("[INFO] Thresholds: |logFC| > %.2f, adj.P.Val < %.4f\n", opt$logfc, opt$fdr))

# ------------------------------------------------------------------------------
# Step 1: Read Expression Matrix
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) {
  stop(sprintf("[ERROR] Input matrix not found: %s", opt$input))
}

exp_df <- read.table(opt$input, header = TRUE, sep = "\t", quote = "", check.names = FALSE, fill = TRUE)
genes <- as.character(exp_df[[1]])
exp_mat <- as.matrix(exp_df[, -1, drop = FALSE])
rownames(exp_mat) <- genes
mode(exp_mat) <- "numeric"

# Average replicate gene symbols
exp_mat <- avereps(exp_mat)

# Filter low-expressed or zero-variance genes
valid_rows <- apply(exp_mat, 1, function(x) !all(is.na(x)) && var(x, na.rm = TRUE) > 1e-6)
exp_mat <- exp_mat[valid_rows, , drop = FALSE]
cat(sprintf("[INFO] Cleaned matrix dimensions: %d genes across %d samples\n", nrow(exp_mat), ncol(exp_mat)))

# ------------------------------------------------------------------------------
# Step 2: Determine Sample Groups
# ------------------------------------------------------------------------------
all_samples <- colnames(exp_mat)
con_samples <- c()
treat_samples <- c()

# Method A: Use s1 and s2 files if available
if (file.exists(opt$s1) && file.exists(opt$s2)) {
  cat(sprintf("[INFO] Reading sample groupings from %s and %s\n", opt$s1, opt$s2))
  s1_tab <- read.table(opt$s1, header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  s2_tab <- read.table(opt$s2, header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  con_samples <- intersect(trimws(as.character(s1_tab[, 1])), all_samples)
  treat_samples <- intersect(trimws(as.character(s2_tab[, 1])), all_samples)
}

# Method B: Use pd/group file if provided
if ((length(con_samples) == 0 || length(treat_samples) == 0) && nchar(opt$pd) > 0 && file.exists(opt$pd)) {
  cat(sprintf("[INFO] Reading grouping from metadata file: %s\n", opt$pd))
  pd <- if (grepl("\\.csv$", opt$pd)) read.csv(opt$pd) else read.table(opt$pd, header = TRUE, sep = "\t")
  s_col <- if ("sample" %in% colnames(pd)) "sample" else colnames(pd)[1]
  g_col <- if ("group" %in% colnames(pd)) "group" else colnames(pd)[2]
  
  con_samples <- intersect(pd[[s_col]][grepl("control|plank|normal|mock", pd[[g_col]], ignore.case = TRUE)], all_samples)
  treat_samples <- intersect(pd[[s_col]][grepl("treat|biofilm|tumor|case", pd[[g_col]], ignore.case = TRUE)], all_samples)
}

# Method C: Fallback inference from sample names
if (length(con_samples) == 0 || length(treat_samples) == 0) {
  cat("[WARN] Inferring sample groups directly from sample column names...\n")
  is_treat <- grepl("treat|biofilm|tumor|case|_t", all_samples, ignore.case = TRUE)
  con_samples <- all_samples[!is_treat]
  treat_samples <- all_samples[is_treat]
}

if (length(con_samples) == 0 || length(treat_samples) == 0) {
  stop("[ERROR] Unable to partition samples into Control and Treat groups.")
}

cat(sprintf("[INFO] Partitioned samples: %d Control, %d Treat\n", length(con_samples), length(treat_samples)))

# Subset and order expression matrix
sub_mat <- cbind(exp_mat[, con_samples, drop = FALSE], exp_mat[, treat_samples, drop = FALSE])
group_labels <- factor(c(rep("Control", length(con_samples)), rep("Treat", length(treat_samples))),
                       levels = c("Control", "Treat"))

# ------------------------------------------------------------------------------
# Step 3: Limma Linear Modeling and Empirical Bayes
# ------------------------------------------------------------------------------
cat("[INFO] Fitting linear model via lmFit (~0 + Group)...\n")
design <- model.matrix(~ 0 + group_labels)
colnames(design) <- c("Control", "Treat")

fit <- lmFit(sub_mat, design)
contrast_matrix <- makeContrasts(Treat - Control, levels = design)
fit_contrast <- contrasts.fit(fit, contrast_matrix)
fit_ebayes <- eBayes(fit_contrast)

cat("[INFO] Calculating topTable statistics with FDR correction...\n")
all_diff <- topTable(fit_ebayes, adjust.method = "fdr", number = Inf)

# Ensure gene Symbol column is present
all_diff_export <- data.frame(
  id = rownames(all_diff),
  all_diff,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# Export all results (Data Contract)
all_file <- file.path(opt$outdir, "all.txt")
cat(sprintf("[INFO] Exporting full differential table to %s\n", all_file))
write.table(all_diff_export, file = all_file, sep = "\t", quote = FALSE, row.names = FALSE)

# ------------------------------------------------------------------------------
# Step 4: Filter Significant DEGs
# ------------------------------------------------------------------------------
sig_mask <- (abs(all_diff$logFC) >= opt$logfc) & (all_diff$adj.P.Val < opt$fdr)
diff_sig <- all_diff[sig_mask, , drop = FALSE]

diff_sig_export <- data.frame(
  id = rownames(diff_sig),
  diff_sig,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

diff_file <- file.path(opt$outdir, "diff.txt")
cat(sprintf("[INFO] Exporting %d significant DEGs to %s\n", nrow(diff_sig), diff_file))
write.table(diff_sig_export, file = diff_file, sep = "\t", quote = FALSE, row.names = FALSE)

# Also export bare gene list for downstream intersecting (Data Contract)
deg_list_file <- file.path(opt$outdir, "candidate_hub_genes_deg.txt")
write.table(rownames(diff_sig), file = deg_list_file, quote = FALSE, row.names = FALSE, col.names = FALSE)

# Export expression values of significant DEGs
if (nrow(diff_sig) > 0) {
  diff_exp_mat <- sub_mat[rownames(diff_sig), , drop = FALSE]
  diff_exp_export <- data.frame(
    id = rownames(diff_exp_mat),
    diff_exp_mat,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  diff_exp_file <- file.path(opt$outdir, "diffGeneExp.txt")
  write.table(diff_exp_export, file = diff_exp_file, sep = "\t", quote = FALSE, row.names = FALSE)
}

# ------------------------------------------------------------------------------
# Step 5: Clustered Heatmap Visualization (pheatmap)
# ------------------------------------------------------------------------------
heatmap_file <- file.path(opt$outdir, "heatmap.pdf")
cat(sprintf("[INFO] Generating clustered DEG heatmap to %s\n", heatmap_file))

if (nrow(diff_sig) >= 2) {
  # Sort by logFC to pick top up and down genes
  diff_sig_sorted <- diff_sig[order(diff_sig$logFC, decreasing = TRUE), ]
  n_show <- opt$top_heatmap
  
  if (nrow(diff_sig_sorted) > (2 * n_show)) {
    top_up <- head(rownames(diff_sig_sorted), n_show)
    top_down <- tail(rownames(diff_sig_sorted), n_show)
    selected_genes <- c(top_up, top_down)
  } else {
    selected_genes <- rownames(diff_sig_sorted)
  }
  
  hm_mat <- sub_mat[selected_genes, , drop = FALSE]
  
  annotation_col <- data.frame(Group = group_labels)
  rownames(annotation_col) <- colnames(hm_mat)
  
  pdf(heatmap_file, width = 10, height = max(8, length(selected_genes) * 0.15))
  pheatmap(
    hm_mat,
    annotation_col = annotation_col,
    color = colorRampPalette(c("#2166AC", "#F7F7F7", "#B2182B"))(50),
    cluster_cols = FALSE,
    show_colnames = FALSE,
    scale = "row",
    fontsize = 8,
    fontsize_row = 6,
    main = sprintf("Top Differential Genes (|logFC| > %.1f, FDR < %.2f)", opt$logfc, opt$fdr)
  )
  dev.off()
} else {
  cat("[WARN] Less than 2 significant genes found. Skipping heatmap generation.\n")
}

# Quality Gate Check
stopifnot("Gate Fail: all.txt is missing" = file.exists(all_file))
stopifnot("Gate Fail: diff.txt is missing" = file.exists(diff_file))
cat(sprintf("[SUCCESS] Stage 04 limma DEG analysis complete: %d significant genes identified.\n", nrow(diff_sig)))
