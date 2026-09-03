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
  if (!is.null(params$group_file) && file.exists(params$group_file)) {
    cat(sprintf("[INFO] Extracting sample labels from metadata: %s\n", params$group_file))
    group_df <- read.csv(params$group_file, stringsAsFactors = FALSE, check.names = FALSE)
    sample_col <- if ("sample" %in% colnames(group_df)) "sample" else colnames(group_df)[1]
    label_col <- if ("group" %in% colnames(group_df)) "group" else colnames(group_df)[2]
    
    label_map <- setNames(as.character(group_df[[label_col]]), as.character(group_df[[sample_col]]))
    y_raw <- label_map[sample_names]
    
    if (any(is.na(y_raw))) {
      warning("[WARN] Some samples not matched in group file, falling back to sample name parsing.")
      y_raw <- gsub("(.*)\\_(.*)", "\\2", sample_names)
    }
  } else {
    # Extract phenotype from sample name suffix (e.g., GSE10030_biofilm1 -> biofilm, GSM123_Control -> Control)
    cat("[INFO] Parsing group labels directly from sample names.\n")
    y_raw <- gsub("(.*)\\_(.*)", "\\2", sample_names)
    # If regex did not split anything, try dot or hyphen
    if (all(y_raw == sample_names)) {
      y_raw <- gsub("(.*)[\\.\\-](.*)", "\\2", sample_names)
    }
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
  
  # 2. Cross-validation to find optimal lambda
  cat(sprintf("[INFO] Performing %d-fold cross-validation with deviance metric...\n", actual_nfolds))
  cvfit <- cv.glmnet(
    x, y, 
    family = params$family, 
    alpha = params$alpha, 
    type.measure = "deviance", 
    nfolds = actual_nfolds
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
  
  # If lambda.min yielded no genes, fallback to lambda.1se or top 3 coefficients
  if (length(selected_genes) == 0) {
    warning("[WARN] No non-zero coefficients at lambda.min. Selecting top features with largest absolute paths.")
    all_coefs_dense <- as.matrix(coef(fit, s = min(fit$lambda)))
    all_coefs_dense <- all_coefs_dense[rownames(all_coefs_dense) != "(Intercept)", , drop = FALSE]
    sorted_idx <- order(abs(all_coefs_dense[, 1]), decreasing = TRUE)
    top_n <- min(5, nrow(all_coefs_dense))
    selected_genes <- rownames(all_coefs_dense)[sorted_idx[1:top_n]]
    selected_coefs <- all_coefs_dense[sorted_idx[1:top_n], 1]
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
  
  # Export gene list
  out_gene_path <- file.path(params$output_dir, params$output_gene_file)
  write.table(
    selected_genes, 
    file = out_gene_path, 
    sep = "\t", 
    quote = FALSE, 
    row.names = FALSE, 
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved LASSO selected genes to: %s\n", out_gene_path))
  
  # Export full coefficient table
  out_coef_path <- file.path(params$output_dir, params$output_coef_file)
  write.csv(coef_df, file = out_coef_path, row.names = FALSE)
  cat(sprintf("[SUCCESS] Saved coefficient details to: %s\n", out_coef_path))
  
  cat("[STAGE COMPLETE] bio-07-ml-lasso completed successfully.\n")
}

if (!interactive()) {
  main()
}
