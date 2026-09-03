#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-01-geo-dataprep
# Script: geo_preprocess.R
# Description: Parameterized preprocessing of GEO microarray expression matrices:
#              probe-to-gene mapping with replicate averaging (avereps),
#              missing value imputation via impute.knn, log2 checks,
#              and structured outputs adhering to Bio-Pipeline data contracts.
# Reproducibility: set.seed(12345)
# ==============================================================================

# Explicit library imports
suppressPackageStartupMessages({
  library(limma)
  library(impute)
  library(Biobase)
})

# Set fixed seed for reproducibility
set.seed(12345)

# ------------------------------------------------------------------------------
# Command line arguments parser helper
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
# Default configuration
# ------------------------------------------------------------------------------
defaults <- list(
  matrix = "biofilm.probeid.exprs.txt",      # Probe expression matrix or series matrix
  platform = "GPL84.txt",                    # Platform annotation table (Probe ID to Symbol)
  probe_col = "ID",                          # Column name or index for probe ID in annotation
  symbol_col = "Gene.Symbol",                # Column name or index for gene symbol in annotation
  gse_id = "GSE10030",                       # Dataset accession identifier
  outdir = ".",                              # Output directory
  k = "10",                                  # KNN neighbors
  rowmax = "0.5",                            # Max allowable missing fraction per gene
  colmax = "0.8",                            # Max allowable missing fraction per sample
  sample_con = "",                           # Comma-separated control sample IDs (optional)
  sample_treat = ""                          # Comma-separated treat sample IDs (optional)
)

opt <- parse_args(defaults)
opt$k <- as.integer(opt$k)
opt$rowmax <- as.numeric(opt$rowmax)
opt$colmax <- as.numeric(opt$colmax)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat(sprintf("[INFO] Starting GEO Preprocessing for %s\n", opt$gse_id))
cat(sprintf("[INFO] Input matrix: %s\n", opt$matrix))
cat(sprintf("[INFO] Platform annotation: %s\n", opt$platform))
cat(sprintf("[INFO] Output directory: %s\n", opt$outdir))

# ------------------------------------------------------------------------------
# Step 1: Read Expression Matrix
# ------------------------------------------------------------------------------
if (!file.exists(opt$matrix)) {
  stop(sprintf("[ERROR] Input matrix file does not exist: %s", opt$matrix))
}

cat("[INFO] Reading raw expression matrix...\n")
raw_mat <- read.table(opt$matrix, header = TRUE, sep = "\t", check.names = FALSE, quote = "", fill = TRUE)

# Determine probe column (first column by default)
probe_col_idx <- 1
probe_ids <- as.character(raw_mat[[probe_col_idx]])
sample_exprs <- as.matrix(raw_mat[, -probe_col_idx, drop = FALSE])
rownames(sample_exprs) <- probe_ids

# Ensure numeric values
mode(sample_exprs) <- "numeric"
cat(sprintf("[INFO] Loaded matrix with %d probes and %d samples\n", nrow(sample_exprs), ncol(sample_exprs)))

# ------------------------------------------------------------------------------
# Step 2: Read Platform Annotation and Map Probes to Gene Symbols
# ------------------------------------------------------------------------------
if (file.exists(opt$platform)) {
  cat("[INFO] Reading platform annotation file...\n")
  anno <- read.table(opt$platform, header = TRUE, sep = "\t", quote = "", check.names = FALSE, fill = TRUE, stringsAsFactors = FALSE)
  
  # Resolve probe and symbol column names
  p_col <- if (opt$probe_col %in% colnames(anno)) opt$probe_col else colnames(anno)[1]
  s_col <- if (opt$symbol_col %in% colnames(anno)) opt$symbol_col else {
    # Heuristic search for Gene Symbol column
    sym_candidates <- grep("symbol|gene_symbol|gene_id|genesymbol", colnames(anno), ignore.case = TRUE, value = TRUE)
    if (length(sym_candidates) > 0) sym_candidates[1] else colnames(anno)[2]
  }
  
  cat(sprintf("[INFO] Using probe column: '%s', symbol column: '%s'\n", p_col, s_col))
  
  anno_probes <- as.character(anno[[p_col]])
  anno_symbols <- as.character(anno[[s_col]])
  
  # Filter invalid symbols (empty, NA, "---")
  valid_idx <- !is.na(anno_symbols) & anno_symbols != "" & anno_symbols != "---" & !is.na(anno_probes)
  anno_map <- data.frame(ProbeID = anno_probes[valid_idx], Symbol = anno_symbols[valid_idx], stringsAsFactors = FALSE)
  
  # Clean symbols that contain multiple identifiers (split by /// or // and take first)
  anno_map$Symbol <- trimws(sapply(strsplit(anno_map$Symbol, "///|//"), `[`, 1))
  
  # Intersect with matrix probes
  matched_probes <- intersect(rownames(sample_exprs), anno_map$ProbeID)
  cat(sprintf("[INFO] Matched %d probes to valid gene symbols\n", length(matched_probes)))
  
  if (length(matched_probes) == 0) {
    stop("[ERROR] Zero probes matched between matrix and annotation platform!")
  }
  
  matched_exprs <- sample_exprs[matched_probes, , drop = FALSE]
  matched_symbols <- anno_map$Symbol[match(matched_probes, anno_map$ProbeID)]
  
} else {
  cat(sprintf("[WARN] Annotation platform file '%s' not found. Assuming matrix rownames are already gene symbols.\n", opt$platform))
  matched_exprs <- sample_exprs
  matched_symbols <- rownames(sample_exprs)
}

# ------------------------------------------------------------------------------
# Step 3: Handle Multiple Probes Mapping to Same Gene (avereps)
# ------------------------------------------------------------------------------
cat("[INFO] Averaging expression for replicate gene symbols using limma::avereps...\n")
gene_exprs <- avereps(matched_exprs, ID = matched_symbols)
cat(sprintf("[INFO] Unique genes after replicate collapse: %d\n", nrow(gene_exprs)))

# ------------------------------------------------------------------------------
# Step 4: Missing Value Filtering and KNN Imputation
# ------------------------------------------------------------------------------
# Check QC gate: genes with > 20% missing values
na_ratio_gene <- rowMeans(is.na(gene_exprs))
high_na_genes <- sum(na_ratio_gene > 0.20)
if (high_na_genes > 0) {
  cat(sprintf("[WARN] Found %d genes with >20%% missing values. Removing prior to KNN...\n", high_na_genes))
  gene_exprs <- gene_exprs[na_ratio_gene <= 0.20, , drop = FALSE]
}

total_nas <- sum(is.na(gene_exprs))
if (total_nas > 0) {
  cat(sprintf("[INFO] Found %d missing values (%.2f%%). Running impute.knn (k=%d, rowmax=%.2f, colmax=%.2f, rng.seed=12345)...\n",
              total_nas, 100 * total_nas / length(gene_exprs), opt$k, opt$rowmax, opt$colmax))
  
  knn_res <- impute.knn(as.matrix(gene_exprs),
                        k = opt$k,
                        rowmax = opt$rowmax,
                        colmax = opt$colmax,
                        rng.seed = 12345)
  gene_exprs <- knn_res$data
} else {
  cat("[INFO] No missing values detected in expression matrix. Imputation skipped.\n")
}

# ------------------------------------------------------------------------------
# Step 5: Check and Apply Log2 Transformation If Needed
# ------------------------------------------------------------------------------
qx <- as.numeric(quantile(gene_exprs, c(0, 0.25, 0.5, 0.75, 0.99, 1.0), na.rm = TRUE))
needs_log2 <- ((qx[5] > 100) || ((qx[6] - qx[1]) > 50 && qx[2] > 0))

if (needs_log2) {
  cat("[INFO] Data values appear unlogged (99th percentile > 100). Applying log2(x + 1)...\n")
  gene_exprs[gene_exprs < 0] <- 0
  gene_exprs <- log2(gene_exprs + 1)
} else {
  cat("[INFO] Data appears already log2-transformed. Preserving values.\n")
}

# ------------------------------------------------------------------------------
# Step 6: Export Normalized Matrix (Data Contract: row=Gene, col=Sample)
# ------------------------------------------------------------------------------
out_norm_file <- file.path(opt$outdir, sprintf("%s.normalize.txt", opt$gse_id))
cat(sprintf("[INFO] Exporting normalized expression matrix to %s\n", out_norm_file))

out_df <- data.frame(Symbol = rownames(gene_exprs), gene_exprs, check.names = FALSE)
write.table(out_df, file = out_norm_file, sep = "\t", quote = FALSE, row.names = FALSE)

# ------------------------------------------------------------------------------
# Step 7: Generate Group Metadata File (group.txt / PD.csv)
# ------------------------------------------------------------------------------
group_file <- file.path(opt$outdir, "group.txt")
pd_csv_file <- file.path(opt$outdir, "PD.csv")

samples <- colnames(gene_exprs)
sample_groups <- rep("Unknown", length(samples))

if (nchar(opt$sample_con) > 0 || nchar(opt$sample_treat) > 0) {
  con_vec <- trimws(unlist(strsplit(opt$sample_con, ",")))
  treat_vec <- trimws(unlist(strsplit(opt$sample_treat, ",")))
  
  sample_groups[samples %in% con_vec] <- "Control"
  sample_groups[samples %in% treat_vec] <- "Treat"
} else {
  # Infer groups if sample names contain hints or split into halves
  is_control <- grepl("control|planktonic|norm|mock|wt|con|_p", samples, ignore.case = TRUE)
  is_treat <- grepl("treat|biofilm|tumor|mutant|case|_t", samples, ignore.case = TRUE)
  
  if (any(is_control) || any(is_treat)) {
    sample_groups[is_control] <- "Control"
    sample_groups[is_treat] <- "Treat"
  } else {
    # Default fallback: split first half Control, second half Treat
    mid <- ceiling(length(samples) / 2)
    sample_groups[1:mid] <- "Control"
    sample_groups[(mid + 1):length(samples)] <- "Treat"
  }
}

group_df <- data.frame(sample = samples, group = sample_groups, stringsAsFactors = FALSE)
cat(sprintf("[INFO] Exporting sample grouping to %s and %s\n", group_file, pd_csv_file))
write.table(group_df, file = group_file, sep = "\t", quote = FALSE, row.names = FALSE)
write.csv(group_df, file = pd_csv_file, row.names = FALSE, quote = FALSE)

# ------------------------------------------------------------------------------
# Quality Gate Validation
# ------------------------------------------------------------------------------
stopifnot("Gate Fail: Normalized matrix file missing" = file.exists(out_norm_file))
stopifnot("Gate Fail: Normalized matrix is empty" = nrow(gene_exprs) > 0)
stopifnot("Gate Fail: Sample count mismatch between group and matrix" = nrow(group_df) == ncol(gene_exprs))
stopifnot("Gate Fail: Missing values remain in final matrix" = sum(is.na(gene_exprs)) == 0)

cat(sprintf("[SUCCESS] Stage 01 GEO Preprocessing complete: %d genes across %d samples.\n",
            nrow(gene_exprs), ncol(gene_exprs)))
