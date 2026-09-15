#!/usr/bin/env Rscript
# ==============================================================================
# lasso_regression.R - LASSO Penalized Logistic Regression Feature Selection
# ==============================================================================
# Skill: bio-07-ml-lasso
# Description: Implements L1 regularization (alpha = 1) and 10-fold cross-validation
#              deviance to select optimal sparse feature subsets from candidate genes.
# ==============================================================================

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

# Explicit library imports
suppressPackageStartupMessages({
  library(glmnet)
})

# Set seed for reproducible cross-validation fold splitting
set.seed(12345)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    input_file = "",
    group_file = "",
    metadata = "",
    manifest = "",
    source_revision = "",
    output_dir = ".",
    output_gene_file = "LASSO.gene.txt",
    output_coef_file = "lasso_coefficients.csv",
    output_lasso_pdf = "lasso.pdf",
    output_cvfit_pdf = "cvfit.pdf",
    nfolds = 10,
    family = "binomial",
    alpha = 1
  )
  
  for (arg in args) {
    if (grepl("^--input=", arg)) {
      params$input_file <- sub("^--input=", "", arg)
    } else if (grepl("^--group=", arg)) {
      params$group_file <- sub("^--group=", "", arg)
    } else if (grepl("^--metadata=", arg)) {
      params$metadata <- sub("^--metadata=", "", arg)
    } else if (grepl("^--manifest=", arg)) {
      params$manifest <- sub("^--manifest=", "", arg)
    } else if (grepl("^--source-revision=", arg)) {
      params$source_revision <- sub("^--source-revision=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      params$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--output-genes=", arg)) {
      params$output_gene_file <- sub("^--output-genes=", "", arg)
    } else if (grepl("^--output-coef=", arg)) {
      params$output_coef_file <- sub("^--output-coef=", "", arg)
    } else if (grepl("^--output-lasso-pdf=", arg)) {
      params$output_lasso_pdf <- sub("^--output-lasso-pdf=", "", arg)
    } else if (grepl("^--output-cvfit-pdf=", arg)) {
      params$output_cvfit_pdf <- sub("^--output-cvfit-pdf=", "", arg)
    } else if (grepl("^--nfolds=", arg)) {
      params$nfolds <- as.integer(sub("^--nfolds=", "", arg))
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript lasso_regression.R [options]\n")
      cat("Options:\n")
      cat("  --input=<path>        Path to matched expression matrix [default: merged_file.txt]\n")
      cat("  --metadata=<path>     Canonical sample metadata CSV/TSV (required)\n")
      cat("  --manifest=<path>     Run manifest (required)\n")
      cat("  --source-revision=<s> Source revision recorded in status (required)\n")
      cat("  --output-dir=<dir>    Directory for output files [default: .]\n")
      cat("  --output-genes=<file> Filename for selected genes [default: LASSO.gene.txt]\n")
      cat("  --nfolds=<int>        Cross-validation folds [default: 10]\n")
      quit(status = 0)
    }
  }
  return(params)
}

main <- function() {
  params <- parse_args()

  if (!nzchar(params$input_file) || !nzchar(params$metadata) || !nzchar(params$manifest)) {
    contract_stop("--input, --metadata, and --manifest are required for LASSO")
  }
  params$input_file <- assert_explicit_path(params$input_file, "LASSO expression matrix", must_exist = TRUE)
  params$metadata <- assert_explicit_path(params$metadata, "sample metadata", must_exist = TRUE)
  params$manifest <- assert_explicit_path(params$manifest, "manifest", must_exist = TRUE)
  manifest <- validate_manifest_context(
    params$manifest,
    source_revision = if (nzchar(params$source_revision)) params$source_revision else NULL,
    metadata_path = params$metadata
  )
  
  # Ensure output directory exists
  if (!dir.exists(params$output_dir)) {
    dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (!file.exists(params$input_file)) {
    stop(sprintf("[ERROR] Input expression file not found: %s", params$input_file))
  }
  
  cat(sprintf("[INFO] Reading merged candidate expression: %s\n", params$input_file))
  metadata_contract <- read_metadata_contract(params$metadata)
  matrix_values <- read_expression_matrix_contract(params$input_file, metadata_contract)
  # Feature selection is locked to discovery samples only.
  discovery_ids <- metadata_contract$sample_id[metadata_contract$partition == "discovery"]
  if (length(discovery_ids) < 4) {
    contract_stop("insufficient_discovery_samples: at least four discovery samples are required")
  }
  rt <- t(matrix_values[, discovery_ids, drop = FALSE])
  cat(sprintf("[INFO] Matrix transposed: %d samples, %d candidate genes.\n", nrow(rt), ncol(rt)))
  
  # Extract response vector y
  sample_names <- rownames(rt)
  y <- factor(metadata_contract$group[match(sample_names, metadata_contract$sample_id)])
  if (any(is.na(y))) contract_stop("metadata_sample_mismatch")
  
  cat("[INFO] Class label distribution:\n")
  print(table(y))
  
  if (length(unique(y)) < 2) {
    stop(sprintf("[ERROR] Expected at least 2 distinct classes in response, but found: %s", 
                 paste(unique(y), collapse = ", ")))
  }
  
  x <- as.matrix(rt)
  
  # Ensure no NA/NaN/Inf in feature matrix
  if (any(!is.finite(x))) {
    cat("[WARN] Found non-finite values in expression matrix. Imputing with column medians.\n")
    for (j in seq_len(ncol(x))) {
      bad <- !is.finite(x[, j])
      if (any(bad)) {
        x[bad, j] <- median(x[!bad, j], na.rm = TRUE)
      }
    }
  }
  
  # Do not silently reduce below two folds: an underpowered discovery partition
  # is a typed failure rather than a fabricated selection result.
  min_class_size <- min(table(y))
  if (min_class_size < 2) {
    contract_stop("insufficient_class_size: every discovery class needs at least two samples")
  }
  actual_nfolds <- min(params$nfolds, min_class_size)
  if (actual_nfolds < params$nfolds) {
    cat(sprintf("[INFO] Adjusting nfolds to %d due to smallest class size (%d).\n", 
                actual_nfolds, min_class_size))
  }
  
  # 1. Fit LASSO Logistic Regression
  cat("[INFO] Fitting glmnet binomial model with alpha = 1 (L1 penalty)...\n")
  fit <- glmnet(x, y, family = params$family, alpha = params$alpha)
  
  # Plot LASSO coefficient paths
  lasso_pdf_path <- file.path(params$output_dir, params$output_lasso_pdf)
  pdf(file = lasso_pdf_path, width = 6.5, height = 6)
  par(mar = c(4.5, 4.5, 3, 2))
  plot(fit, xvar = "lambda", label = TRUE, lwd = 1.8, cex.lab = 1.1)
  title("LASSO Coefficient Shrinkage Paths", line = 2.2)
  dev.off()
  cat(sprintf("[SUCCESS] Saved LASSO trajectory plot to: %s\n", lasso_pdf_path))
  
  # 2. Cross-validation to find optimal lambda (stratified foldid, reproducible)
  cat(sprintf("[INFO] Performing %d-fold stratified cross-validation with deviance metric...\n", actual_nfolds))
  set.seed(12345)
  foldid <- integer(nrow(x))
  for (lv in levels(y)) {
    idx <- which(y == lv)
    k <- min(actual_nfolds, length(idx))
    folds <- sample(rep(seq_len(k), length.out = length(idx)))
    foldid[idx] <- folds
  }
  cvfit <- cv.glmnet(
    x, y, 
    family = params$family, 
    alpha = params$alpha, 
    type.measure = "deviance", 
    nfolds = actual_nfolds,
    foldid = foldid
  )
  
  # Plot cross-validation curve
  cvfit_pdf_path <- file.path(params$output_dir, params$output_cvfit_pdf)
  pdf(file = cvfit_pdf_path, width = 6.5, height = 6)
  par(mar = c(4.5, 4.5, 3, 2))
  plot(cvfit, cex.lab = 1.1)
  title(sprintf("10-Fold Cross-Validation (lambda.min = %.4f)", cvfit$lambda.min), line = 2.2)
  dev.off()
  cat(sprintf("[SUCCESS] Saved cross-validation plot to: %s\n", cvfit_pdf_path))
  
  # 3. Extract non-zero coefficients at lambda.min
  coef_matrix <- coef(fit, s = cvfit$lambda.min)
  non_zero_indices <- which(coef_matrix != 0)
  
  all_selected_genes <- rownames(coef_matrix)[non_zero_indices]
  # Exclude (Intercept)
  selected_genes <- all_selected_genes[all_selected_genes != "(Intercept)"]
  selected_coefs <- coef_matrix[non_zero_indices][all_selected_genes != "(Intercept)"]
  
  # lambda.min 无基因时禁止静默凑数（contracts G-04: report, do not fabricate）
  if (length(selected_genes) == 0) {
    out_gene_path <- file.path(params$output_dir, params$output_gene_file)
    writeLines(character(), out_gene_path)
    write_stage_status(
      manifest, "bio-07-ml-lasso", "negative",
      "LASSO selected no genes at lambda.min; no top-N fallback was applied",
      commandArgs(trailingOnly = FALSE), c(params$input_file, params$metadata),
      c(out_gene_path, lasso_pdf_path, cvfit_pdf_path), sample_names,
      status_path = file.path(params$output_dir, "status", "bio-07-ml-lasso.json"),
      exit_code = 0
    )
    cat("[NEGATIVE] LASSO selected no genes; preserving a typed negative result.\n")
    return(invisible(FALSE))
  }
  
  # Summary table
  coef_df <- data.frame(
    Gene = selected_genes,
    Coefficient = selected_coefs,
    Abs_Coefficient = abs(selected_coefs),
    stringsAsFactors = FALSE
  )
  coef_df <- coef_df[order(coef_df$Abs_Coefficient, decreasing = TRUE), ]
  
  cat("========================================================\n")
  cat(sprintf("Optimal Lambda (min):    %.6f\n", cvfit$lambda.min))
  cat(sprintf("Lambda (1se):            %.6f\n", cvfit$lambda.1se))
  cat(sprintf("Features Selected:       %d\n", length(selected_genes)))
  cat("========================================================\n")
  print(coef_df[, c("Gene", "Coefficient")])
  
  # Gate verification: At least 1 gene selected
  if (length(selected_genes) < 1) {
    stop("[GATE ERROR] LASSO failed to select any characteristic genes! Aborting.")
  }
  
  # Export gene list (lambda.min)
  out_gene_path <- file.path(params$output_dir, params$output_gene_file)
  write.table(
    selected_genes, 
    file = out_gene_path, 
    sep = "\t", 
    quote = FALSE, 
    row.names = FALSE, 
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved LASSO selected genes (lambda.min) to: %s\n", out_gene_path))

  # Export lambda.1se gene list (contracts: dual-lambda reporting)
  coef_1se <- coef(fit, s = cvfit$lambda.1se)
  genes_1se <- rownames(coef_1se)[as.numeric(coef_1se) != 0]
  genes_1se <- genes_1se[genes_1se != "(Intercept)"]
  out_1se_path <- file.path(params$output_dir, "LASSO.gene.1se.txt")
  write.table(genes_1se, file = out_1se_path, sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  cat(sprintf("[SUCCESS] Saved LASSO selected genes (lambda.1se, n=%d) to: %s\n", length(genes_1se), out_1se_path))
  
  # Export full coefficient table
  out_coef_path <- file.path(params$output_dir, params$output_coef_file)
  write.csv(coef_df, file = out_coef_path, row.names = FALSE)
  cat(sprintf("[SUCCESS] Saved coefficient details to: %s\n", out_coef_path))
  
  write_stage_status(
    manifest, "bio-07-ml-lasso", "success",
    "discovery-only LASSO selection and stratified cross-validation completed",
    commandArgs(trailingOnly = FALSE), c(params$input_file, params$metadata),
    c(out_gene_path, out_1se_path, out_coef_path, lasso_pdf_path, cvfit_pdf_path), sample_names,
    status_path = file.path(params$output_dir, "status", "bio-07-ml-lasso.json"),
    exit_code = 0
  )
  cat("[STAGE COMPLETE] bio-07-ml-lasso completed successfully on discovery data.\n")
}

if (!interactive()) {
  main()
}
