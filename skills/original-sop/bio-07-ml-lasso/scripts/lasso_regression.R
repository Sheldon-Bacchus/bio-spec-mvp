#!/usr/bin/env Rscript
# ==============================================================================
# lasso_regression.R - LASSO Penalized Logistic Regression Feature Selection
# ==============================================================================
# Skill: bio-07-ml-lasso
# Description: Implements L1 regularization (alpha = 1) and 10-fold cross-validation
#              deviance to select optimal sparse feature subsets from candidate genes.
# ==============================================================================

# Explicit library imports
suppressPackageStartupMessages({
  library(glmnet)
})

# Set seed for reproducible cross-validation fold splitting
set.seed(12345)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    input_file = "merged_file.txt",
    group_file = NULL,
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
    } else if (grepl("^--output-dir=", arg)) {
      params$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--output-genes=", arg)) {
      params$output_gene_file <- sub("^--output-genes=", "", arg)
    } else if (grepl("^--nfolds=", arg)) {
      params$nfolds <- as.integer(sub("^--nfolds=", "", arg))
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript lasso_regression.R [options]\n")
      cat("Options:\n")
      cat("  --input=<path>        Path to matched expression matrix [default: merged_file.txt]\n")
      cat("  --group=<path>        Optional sample group metadata CSV file\n")
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
  
  # Ensure output directory exists
  if (!dir.exists(params$output_dir)) {
    dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (!file.exists(params$input_file)) {
    stop(sprintf("[ERROR] Input expression file not found: %s", params$input_file))
  }
  
  cat(sprintf("[INFO] Reading merged candidate expression: %s\n", params$input_file))
  rt <- read.table(
    params$input_file, 
    header = TRUE, 
    sep = "\t", 
    check.names = FALSE, 
    row.names = 1, 
    quote = ""
  )
  
  # Transpose matrix: samples as rows, genes as columns
  rt <- t(rt)
  cat(sprintf("[INFO] Matrix transposed: %d samples, %d candidate genes.\n", nrow(rt), ncol(rt)))
  
  # Extract response vector y
  sample_names <- rownames(rt)
  if (is.null(params$group_file) || !file.exists(params$group_file)) {
    stop("[GATE ERROR] --group file is REQUIRED for LASSO (contracts G-03 fail-closed: explicit metadata only). Provide sample group metadata CSV.")
  }
  cat(sprintf("[INFO] Extracting sample labels from metadata: %s\n", params$group_file))
  group_df <- read.csv(params$group_file, stringsAsFactors = FALSE, check.names = FALSE)
  sample_col <- if ("sample" %in% colnames(group_df)) "sample" else colnames(group_df)[1]
  label_col <- if ("group" %in% colnames(group_df)) "group" else colnames(group_df)[2]
  
  label_map <- setNames(as.character(group_df[[label_col]]), as.character(group_df[[sample_col]]))
  y_raw <- label_map[sample_names]
  
  unmatched <- sum(is.na(y_raw))
  if (unmatched > 0) {
    stop(sprintf("[GATE ERROR] %d samples did not match the group file (fail-closed on label mismatch). Check sample names / batch prefixes.", unmatched))
  }
  
  # Remove trailing numbers if present (e.g., biofilm1 -> biofilm, normal2 -> normal)
  y_clean <- gsub("[0-9]+$", "", y_raw)
  y <- as.factor(y_clean)
  
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
  
  # Adjust folds if sample size is smaller than default nfolds
  min_class_size <- min(table(y))
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
    stop("[GATE ERROR] LASSO selected NO genes at lambda.min. Check feature matrix / separability. Refusing top-N fabrication (contracts G-04).")
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
  
  cat("[STAGE COMPLETE] bio-07-ml-lasso completed successfully.\n")
}

if (!interactive()) {
  main()
}
