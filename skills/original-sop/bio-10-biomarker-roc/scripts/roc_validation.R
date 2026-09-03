#!/usr/bin/env Rscript
# ==============================================================================
# roc_validation.R - Diagnostic Biomarker ROC & AUC Performance Evaluation
# ==============================================================================
# Skill: bio-10-biomarker-roc
# Description: Evaluates individual and multivariable combined diagnostic efficacy
#              of Hub biomarkers using receiver operating characteristic (ROC) curves,
#              DeLong confidence intervals, and logistic regression modeling.
# ==============================================================================

# Explicit library imports
suppressPackageStartupMessages({
  library(pROC)
  library(ggplot2)
})

# Set seed for reproducible bootstrapping
set.seed(12345)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    expr_file = "merged_file.txt",
    hub_file = "final_hub_genes.txt",
    group_file = NULL,
    output_dir = ".",
    output_single_pdf = "roc_single_gene.pdf",
    output_combined_pdf = "roc_combined.pdf",
    output_report = "auc_report.csv",
    auc_gate_single = 0.70,
    auc_gate_combined = 0.80
  )
  
  for (arg in args) {
    if (grepl("^--expr=", arg)) {
      params$expr_file <- sub("^--expr=", "", arg)
    } else if (grepl("^--hub=", arg)) {
      params$hub_file <- sub("^--hub=", "", arg)
    } else if (grepl("^--group=", arg)) {
      params$group_file <- sub("^--group=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      params$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--single-pdf=", arg)) {
      params$output_single_pdf <- sub("^--single-pdf=", "", arg)
    } else if (grepl("^--combined-pdf=", arg)) {
      params$output_combined_pdf <- sub("^--combined-pdf=", "", arg)
    } else if (grepl("^--report=", arg)) {
      params$output_report <- sub("^--report=", "", arg)
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript roc_validation.R [options]\n")
      cat("Options:\n")
      cat("  --expr=<path>          Expression matrix path [default: merged_file.txt]\n")
      cat("  --hub=<path>           Hub genes list [default: final_hub_genes.txt]\n")
      cat("  --group=<path>         Optional group CSV file [default: auto-parse sample names]\n")
      cat("  --output-dir=<dir>     Output directory [default: .]\n")
      cat("  --single-pdf=<file>    Single gene ROC plot filename [default: roc_single_gene.pdf]\n")
      cat("  --combined-pdf=<file>  Combined ROC plot filename [default: roc_combined.pdf]\n")
      cat("  --report=<file>        AUC summary CSV [default: auc_report.csv]\n")
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
  
  # Check inputs
  if (!file.exists(params$expr_file)) {
    fallback_expr <- "merged_data.csv"
    if (file.exists(fallback_expr)) {
      cat(sprintf("[WARN] '%s' not found, using fallback '%s'\n", params$expr_file, fallback_expr))
      params$expr_file <- fallback_expr
    } else {
      stop(sprintf("[ERROR] Expression file not found: %s", params$expr_file))
    }
  }
  
  if (!file.exists(params$hub_file)) {
    fallback_hub <- "LASSO.gene.txt"
    if (file.exists(fallback_hub)) {
      cat(sprintf("[WARN] '%s' not found, using fallback '%s'\n", params$hub_file, fallback_hub))
      params$hub_file <- fallback_hub
    } else {
      stop(sprintf("[ERROR] Hub genes file not found: %s", params$hub_file))
    }
  }
  
  # Read Hub Genes
  hub_lines <- readLines(params$hub_file, warn = FALSE)
  hub_genes <- trimws(gsub("[\"']", "", hub_lines))
  hub_genes <- hub_genes[hub_genes != "" & !is.na(hub_genes)]
  hub_genes <- unique(hub_genes)
  
  # Filter out possible header
  header_candidates <- c("gene", "genes", "geneNames", "Symbol")
  if (length(hub_genes) > 0 && hub_genes[1] %in% header_candidates) {
    hub_genes <- hub_genes[-1]
  }
  
  cat(sprintf("[INFO] Target Hub genes to validate: %d (%s)\n", 
              length(hub_genes), paste(hub_genes, collapse = ", ")))
  
  if (length(hub_genes) == 0) {
    stop("[ERROR] Zero valid hub genes found in file!")
  }
  
  # Read Expression Matrix
  first_line <- readLines(params$expr_file, n = 1, warn = FALSE)
  sep <- if (grepl(",", first_line)) "," else "\t"
  expr_raw <- read.table(
    params$expr_file, 
    header = TRUE, 
    sep = sep, 
    check.names = FALSE, 
    row.names = 1, 
    quote = ""
  )
  
  # Transpose: samples as rows, genes as columns
  expr_t <- as.data.frame(t(expr_raw))
  sample_names <- rownames(expr_t)
  
  # Extract response factor (binary classification)
  if (!is.null(params$group_file) && file.exists(params$group_file)) {
    cat(sprintf("[INFO] Reading group annotations from: %s\n", params$group_file))
    group_df <- read.csv(params$group_file, stringsAsFactors = FALSE, check.names = FALSE)
    sample_col <- if ("sample" %in% colnames(group_df)) "sample" else colnames(group_df)[1]
    label_col <- if ("group" %in% colnames(group_df)) "group" else colnames(group_df)[2]
    
    label_map <- setNames(as.character(group_df[[label_col]]), as.character(group_df[[sample_col]]))
    y_raw <- label_map[sample_names]
    if (any(is.na(y_raw))) {
      y_raw <- gsub("(.*)\\_(.*)", "\\2", sample_names)
    }
  } else {
    y_raw <- gsub("(.*)\\_(.*)", "\\2", sample_names)
    if (all(y_raw == sample_names)) {
      y_raw <- gsub("(.*)[\\.\\-](.*)", "\\2", sample_names)
    }
  }
  
  disease_labels <- gsub("[0-9]+$", "", y_raw)
  y <- as.factor(disease_labels)
  
  cat("[INFO] Sample distribution per class:\n")
  print(table(y))
  
  levels_y <- levels(y)
  if (length(levels_y) != 2) {
    stop(sprintf("[ERROR] ROC analysis requires exactly 2 classes, found: %s", paste(levels_y, collapse = ", ")))
  }
  
  # Match hub genes with columns in expression matrix
  matched_hubs <- intersect(hub_genes, colnames(expr_t))
  if (length(matched_hubs) == 0) {
    # Check case-insensitive match
    lower_cols <- tolower(colnames(expr_t))
    matched_idx <- match(tolower(hub_genes), lower_cols)
    matched_idx <- matched_idx[!is.na(matched_idx)]
    if (length(matched_idx) > 0) {
      matched_hubs <- colnames(expr_t)[matched_idx]
    }
  }
  
  cat(sprintf("[INFO] %d of %d Hub genes matched in expression matrix: %s\n", 
              length(matched_hubs), length(hub_genes), paste(matched_hubs, collapse = ", ")))
  
  if (length(matched_hubs) == 0) {
    stop("[ERROR] None of the Hub genes were found in the expression matrix columns!")
  }
  
  # 1. Single Gene ROC Calculations
  auc_records <- list()
  roc_objects <- list()
  
  for (gene in matched_hubs) {
    gene_expr <- as.numeric(expr_t[[gene]])
    
    # Calculate ROC curve
    roc_obj <- tryCatch({
      pROC::roc(response = y, predictor = gene_expr, quiet = TRUE, ci = TRUE)
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(roc_obj)) {
      roc_objects[[gene]] <- roc_obj
      auc_val <- as.numeric(roc_obj$auc)
      ci_vals <- as.numeric(roc_obj$ci) # lower, median, upper
      
      # Determine optimal Youden cutoff
      best_coords <- coords(roc_obj, "best", best.method = "youden", ret = c("threshold", "sensitivity", "specificity"))
      
      auc_records[[length(auc_records) + 1]] <- data.frame(
        Gene = gene,
        Type = "Single",
        AUC = round(auc_val, 4),
        CI_lower = round(ci_vals[1], 4),
        CI_upper = round(ci_vals[3], 4),
        Sensitivity = round(best_coords$sensitivity[1], 4),
        Specificity = round(best_coords$specificity[1], 4),
        Cutoff = round(best_coords$threshold[1], 4),
        stringsAsFactors = FALSE
      )
    }
  }
  
  # 2. Multivariable Logistic Regression Combined ROC (k-fold OUT-OF-FOLD; no in-sample AUC per contracts G-04)
  combined_roc <- NULL
  if (length(matched_hubs) >= 2) {
    cat("[INFO] Building multivariable logistic regression panel with k-fold OUT-OF-FOLD prediction...\n")
    sub_df <- expr_t[, matched_hubs, drop = FALSE]
    sub_df$disease <- ifelse(y == levels_y[2], 1, 0)
    
    # k-fold OOF probabilities (balanced; min 3 samples/fold; LOO fallback for tiny cohorts)
    n_oof <- nrow(sub_df)
    k_fold <- if (n_oof >= 12) 5 else if (n_oof >= 6) 3 else 2
    set.seed(12345)
    foldid <- integer(n_oof)
    for (lv in unique(sub_df$disease)) {
      idx <- which(sub_df$disease == lv)
      kk <- min(k_fold, length(idx))
      foldid[idx] <- sample(rep(seq_len(kk), length.out = length(idx)))
    }
    oof_prob <- rep(NA_real_, n_oof)
    for (k_idx in seq_len(k_fold)) {
      tr <- which(foldid != k_idx)
      te <- which(foldid == k_idx)
      if (length(unique(sub_df$disease[tr])) < 2 || length(te) < 1) next
      glm_k <- tryCatch(
        glm(disease ~ ., data = sub_df, subset = tr, family = binomial(link = "logit")),
        error = function(e) NULL
      )
      if (!is.null(glm_k)) {
        oof_prob[te] <- predict(glm_k, newdata = sub_df[te, , drop = FALSE], type = "response")
      }
    }
    
    if (all(!is.na(oof_prob)) && length(unique(oof_prob)) > 1) {
      combined_roc <- tryCatch({
        pROC::roc(response = sub_df$disease, predictor = oof_prob, quiet = TRUE, ci = TRUE)
      }, error = function(e) {
        NULL
      })
      
      if (!is.null(combined_roc)) {
        comb_auc <- as.numeric(combined_roc$auc)
        comb_ci <- as.numeric(combined_roc$ci)
        best_comb <- coords(combined_roc, "best", best.method = "youden", ret = c("threshold", "sensitivity", "specificity"))
        
        auc_records[[length(auc_records) + 1]] <- data.frame(
          Gene = paste("Combined_Panel (", length(matched_hubs), " genes)", sep = ""),
          Type = "Combined(OOF)",
          AUC = round(comb_auc, 4),
          CI_lower = round(comb_ci[1], 4),
          CI_upper = round(comb_ci[3], 4),
          Sensitivity = round(best_comb$sensitivity[1], 4),
          Specificity = round(best_comb$specificity[1], 4),
          Cutoff = round(best_comb$threshold[1], 4),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  report_df <- do.call(rbind, auc_records)
  
  # Export AUC summary table
  out_report_path <- file.path(params$output_dir, params$output_report)
  write.csv(report_df, file = out_report_path, row.names = FALSE)
  cat(sprintf("[SUCCESS] Exported AUC diagnostic report to: %s\n", out_report_path))
  
  # Print AUC table
  cat("\n========================================================\n")
  cat("           BIOMARKER ROC / AUC REPORT                   \n")
  cat("========================================================\n")
  print(report_df)
  cat("========================================================\n")
  
  # 3. Plot Single Gene ROC Curves
  palette_colors <- c("#2563EB", "#DC2626", "#059669", "#D97706", "#7C3AED", "#DB2777", "#4B5563")
  out_single_pdf <- file.path(params$output_dir, params$output_single_pdf)
  pdf(file = out_single_pdf, width = 6.5, height = 6.2)
  par(mar = c(4.5, 4.5, 3, 2))
  
  first_plot <- TRUE
  legend_labels <- c()
  legend_cols <- c()
  
  for (i in seq_along(roc_objects)) {
    gene_name <- names(roc_objects)[i]
    r_obj <- roc_objects[[i]]
    col <- palette_colors[((i - 1) %% length(palette_colors)) + 1]
    
    lbl <- sprintf("%s: AUC = %.3f (95%% CI: %.2f - %.2f)", 
                   gene_name, r_obj$auc, r_obj$ci[1], r_obj$ci[3])
    legend_labels <- c(legend_labels, lbl)
    legend_cols <- c(legend_cols, col)
    
    if (first_plot) {
      plot(r_obj, col = col, lwd = 2.2, legacy.axes = TRUE,
           main = "Hub Biomarker ROC Curves (Individual Evaluation)",
           xlab = "False Positive Rate (1 - Specificity)",
           ylab = "True Positive Rate (Sensitivity)",
           cex.lab = 1.1, cex.main = 1.15)
      first_plot <- FALSE
    } else {
      plot(r_obj, col = col, lwd = 2.2, add = TRUE)
    }
  }
  
  # Diagonal reference line
  abline(a = 0, b = 1, lty = 2, col = "grey60", lwd = 1.5)
  legend("bottomright", legend = legend_labels, col = legend_cols, lwd = 2.2, 
         cex = 0.8, bty = "n", inset = 0.02)
  dev.off()
  cat(sprintf("[SUCCESS] Saved individual ROC curves to: %s\n", out_single_pdf))
  
  # 4. Plot Combined Model ROC
  out_comb_pdf <- file.path(params$output_dir, params$output_combined_pdf)
  if (!is.null(combined_roc)) {
    pdf(file = out_comb_pdf, width = 6.5, height = 6.2)
    par(mar = c(4.5, 4.5, 3, 2))
    
    comb_lbl <- sprintf("Combined Panel: AUC = %.3f (95%% CI: %.2f - %.2f)",
                        combined_roc$auc, combined_roc$ci[1], combined_roc$ci[3])
    
    plot(combined_roc, col = "#DC2626", lwd = 2.8, legacy.axes = TRUE,
         main = "Multivariable Combined Biomarker Panel ROC",
         xlab = "False Positive Rate (1 - Specificity)",
         ylab = "True Positive Rate (Sensitivity)",
         cex.lab = 1.1, cex.main = 1.15)
    abline(a = 0, b = 1, lty = 2, col = "grey60", lwd = 1.5)
    legend("bottomright", legend = comb_lbl, col = "#DC2626", lwd = 2.8, 
           cex = 0.85, bty = "n", inset = 0.02)
    dev.off()
    cat(sprintf("[SUCCESS] Saved combined ROC curve to: %s\n", out_comb_pdf))
  }
  
  # Gate Verification: Single AUC >= 0.70 OR Combined AUC >= 0.80
  max_single_auc <- max(report_df$AUC[report_df$Type == "Single"], na.rm = TRUE)
  comb_auc_val <- if ("Combined(OOF)" %in% report_df$Type) report_df$AUC[report_df$Type == "Combined(OOF)"][1] else 0
  
  pass_gate <- (max_single_auc >= params$auc_gate_single) || (comb_auc_val >= params$auc_gate_combined)
  
  if (!pass_gate) {
    warning(sprintf("[GATE WARNING] Biomarker AUC performance did not reach standard threshold: Max Single AUC = %.3f (target >= %.2f), Combined AUC = %.3f (target >= %.2f)",
                    max_single_auc, params$auc_gate_single, comb_auc_val, params$auc_gate_combined))
  } else {
    cat(sprintf("[GATE PASS] AUC criteria met! Max Single AUC = %.3f, Combined AUC = %.3f\n", 
                max_single_auc, comb_auc_val))
  }
  
  cat("[STAGE COMPLETE] bio-10-biomarker-roc completed successfully.\n")
}

if (!interactive()) {
  main()
}
