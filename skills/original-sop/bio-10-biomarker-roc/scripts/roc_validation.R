#!/usr/bin/env Rscript
# ==============================================================================
# roc_validation.R - Diagnostic Biomarker ROC & AUC Performance Evaluation
# ==============================================================================
# Skill: bio-10-biomarker-roc
# Description: Evaluates individual and multivariable combined diagnostic efficacy
#              of Hub biomarkers using receiver operating characteristic (ROC) curves,
#              DeLong confidence intervals, and logistic regression modeling.
# ==============================================================================

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

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
    expr_file = "",
    hub_file = "",
    group_file = "",
    metadata = "",
    manifest = "",
    source_revision = "",
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
    } else if (grepl("^--metadata=", arg)) {
      params$metadata <- sub("^--metadata=", "", arg)
    } else if (grepl("^--manifest=", arg)) {
      params$manifest <- sub("^--manifest=", "", arg)
    } else if (grepl("^--source-revision=", arg)) {
      params$source_revision <- sub("^--source-revision=", "", arg)
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
      cat("  --metadata=<path>      Canonical sample metadata CSV/TSV (required)\n")
      cat("  --manifest=<path>      Run manifest (required)\n")
      cat("  --source-revision=<s>  Source revision recorded in status (required)\n")
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

  if (!nzchar(params$expr_file) || !nzchar(params$hub_file) || !nzchar(params$metadata) || !nzchar(params$manifest)) {
    contract_stop("--expr, --hub, --metadata, and --manifest are required; no filename/group inference is permitted")
  }
  params$expr_file <- assert_explicit_path(params$expr_file, "ROC expression matrix", must_exist = TRUE)
  params$hub_file <- assert_explicit_path(params$hub_file, "hub gene list", must_exist = TRUE)
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
  metadata_contract <- read_metadata_contract(params$metadata)
  expr_raw <- read_expression_matrix_contract(params$expr_file, metadata_contract)
  discovery_ids <- metadata_contract$sample_id[metadata_contract$partition == "discovery"]
  validation_ids <- metadata_contract$sample_id[metadata_contract$partition == "validation"]
  if (length(discovery_ids) < 4 || length(validation_ids) < 2) {
    contract_stop("validation_partition_size: discovery needs at least four samples and validation needs at least two samples")
  }
  # The hub list is locked before this stage. Score it only on the independent
  # validation partition; discovery samples are reserved for model fitting.
  expr_t <- as.data.frame(t(expr_raw[, validation_ids, drop = FALSE]))
  sample_names <- rownames(expr_t)

  disease_labels <- metadata_contract$group[match(sample_names, metadata_contract$sample_id)]
  if (any(is.na(disease_labels))) contract_stop("metadata_sample_mismatch")
  y <- as.factor(disease_labels)
  
  cat("[INFO] Sample distribution per class:\n")
  print(table(y))
  
  levels_y <- levels(y)
  if (length(levels_y) != 2) {
    contract_stop(sprintf("ROC analysis requires exactly 2 classes, found: %s", paste(levels_y, collapse = ", ")))
  }
  if (min(table(y)) < 2) contract_stop("validation_class_size: each validation class needs at least two samples")
  
  # Match hub genes with columns in expression matrix
  matched_hubs <- intersect(hub_genes, colnames(expr_t))
  
  cat(sprintf("[INFO] %d of %d Hub genes matched in expression matrix: %s\n", 
              length(matched_hubs), length(hub_genes), paste(matched_hubs, collapse = ", ")))
  
  if (length(matched_hubs) == 0) {
    contract_stop("hub_gene_match: none of the locked hub genes are present in the expression matrix")
  }
  if (length(setdiff(hub_genes, matched_hubs)) > 0) {
    contract_stop(sprintf("hub_gene_match: locked hub genes missing from validation matrix: %s", paste(setdiff(hub_genes, matched_hubs), collapse = ", ")))
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
        Assessment = "independent_validation",
        SelectionPartition = "discovery",
        ValidationPartition = "validation",
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
  
  # 2. Multivariable Logistic Regression Combined ROC. Fit only on discovery
  # data and score the locked panel once on the independent validation data.
  combined_roc <- NULL
  if (length(matched_hubs) >= 2) {
    cat("[INFO] Fitting the locked panel on discovery data and scoring validation data...\n")
    discovery_df <- as.data.frame(t(expr_raw[, discovery_ids, drop = FALSE]))
    validation_df <- expr_t[, matched_hubs, drop = FALSE]
    discovery_df <- discovery_df[, matched_hubs, drop = FALSE]
    discovery_df$disease <- factor(metadata_contract$group[match(rownames(discovery_df), metadata_contract$sample_id)], levels = levels_y)
    validation_df$disease <- factor(y, levels = levels_y)
    if (length(unique(discovery_df$disease)) == 2 && length(unique(validation_df$disease)) == 2) {
      glm_fit <- tryCatch(
        glm(disease ~ ., data = discovery_df, family = binomial(link = "logit")),
        error = function(e) NULL
      )
      validation_prob <- if (!is.null(glm_fit)) {
        predict(glm_fit, newdata = validation_df[, matched_hubs, drop = FALSE], type = "response")
      } else {
        rep(NA_real_, nrow(validation_df))
      }
    } else {
      validation_prob <- rep(NA_real_, nrow(validation_df))
    }

    if (all(!is.na(validation_prob)) && length(unique(validation_prob)) > 1) {
      combined_roc <- tryCatch({
        pROC::roc(response = validation_df$disease, predictor = validation_prob, quiet = TRUE, ci = TRUE)
      }, error = function(e) {
        NULL
      })
      
      if (!is.null(combined_roc)) {
        comb_auc <- as.numeric(combined_roc$auc)
        comb_ci <- as.numeric(combined_roc$ci)
        best_comb <- coords(combined_roc, "best", best.method = "youden", ret = c("threshold", "sensitivity", "specificity"))
        
        auc_records[[length(auc_records) + 1]] <- data.frame(
          Gene = paste("Combined_Panel (", length(matched_hubs), " genes)", sep = ""),
          Type = "Combined(IndependentValidation)",
          Assessment = "independent_validation",
          SelectionPartition = "discovery",
          ValidationPartition = "validation",
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
  
  report_df <- if (length(auc_records) > 0) do.call(rbind, auc_records) else data.frame(
    Gene = character(), Type = character(), Assessment = character(),
    SelectionPartition = character(), ValidationPartition = character(),
    AUC = numeric(), CI_lower = numeric(), CI_upper = numeric(),
    Sensitivity = numeric(), Specificity = numeric(), Cutoff = numeric(),
    stringsAsFactors = FALSE
  )
  
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
  
  if (length(roc_objects) == 0) {
    plot.new()
    text(0.5, 0.55, "No valid ROC curve could be computed", cex = 1.1)
    text(0.5, 0.40, "Status: negative", cex = 0.9)
  } else {
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
             main = "Hub Biomarker ROC Curves (Independent Validation)",
             xlab = "False Positive Rate (1 - Specificity)",
             ylab = "True Positive Rate (Sensitivity)",
             cex.lab = 1.1, cex.main = 1.15)
        first_plot <- FALSE
      } else {
        plot(r_obj, col = col, lwd = 2.2, add = TRUE)
      }
    }
  }
  
  # Diagonal reference line
  abline(a = 0, b = 1, lty = 2, col = "grey60", lwd = 1.5)
  if (length(legend_labels) > 0) {
    legend("bottomright", legend = legend_labels, col = legend_cols, lwd = 2.2,
           cex = 0.8, bty = "n", inset = 0.02)
  }
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
  } else {
    pdf(file = out_comb_pdf, width = 6.5, height = 6.2)
    plot.new()
    text(0.5, 0.55, "No valid combined ROC curve could be computed", cex = 1.05)
    text(0.5, 0.40, "Status: negative", cex = 0.9)
    dev.off()
  }
  
  # Gate Verification: Single AUC >= 0.70 OR independent combined AUC >= 0.80.
  max_single_auc <- if (any(report_df$Type == "Single")) max(report_df$AUC[report_df$Type == "Single"], na.rm = TRUE) else 0
  comb_auc_val <- if ("Combined(IndependentValidation)" %in% report_df$Type) report_df$AUC[report_df$Type == "Combined(IndependentValidation)"][1] else 0
  
  pass_gate <- (max_single_auc >= params$auc_gate_single) || (comb_auc_val >= params$auc_gate_combined)
  
  if (!pass_gate) {
    cat(sprintf("[NEGATIVE] Biomarker AUC did not reach the declared threshold: Max Single AUC = %.3f (target >= %.2f), Combined AUC = %.3f (target >= %.2f).\n",
                max_single_auc, params$auc_gate_single, comb_auc_val, params$auc_gate_combined))
  } else {
    cat(sprintf("[GATE PASS] AUC criteria met! Max Single AUC = %.3f, Combined AUC = %.3f\n", 
                max_single_auc, comb_auc_val))
  }
  
  roc_status <- if (pass_gate) "success" else "negative"
  roc_reason <- if (pass_gate) {
    "independent validation AUC gate passed"
  } else {
    "AUC did not meet the declared threshold; metric remains a typed negative result"
  }
  write_stage_status(
    manifest, "bio-10-biomarker-roc", roc_status, roc_reason,
    commandArgs(trailingOnly = FALSE), c(params$expr_file, params$hub_file, params$metadata),
    c(out_report_path, out_single_pdf, out_comb_pdf), sample_names,
    status_path = file.path(params$output_dir, "status", "bio-10-biomarker-roc.json"),
    exit_code = 0
  )
  cat(sprintf("[STAGE %s] bio-10-biomarker-roc completed: %s.\n", toupper(roc_status), roc_reason))
}

if (!interactive()) {
  main()
}
