#!/usr/bin/env Rscript
# ==============================================================================
# random_forest_importance.R - Random Forest Variable Importance & Permutation Test
# ==============================================================================
# Skill: bio-08-ml-randomforest
# Description: Evaluates classification importance (MeanDecreaseGini & MeanDecreaseAccuracy)
#              using Random Forest with permutation testing (rfPermute).
#              Generates significance-annotated importance plots and exports key features.
# ==============================================================================

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

# Explicit library imports
suppressPackageStartupMessages({
  library(randomForest)
  library(ggplot2)
  library(RColorBrewer)
})

# Optional packages loaded safely
has_rfPermute <- suppressWarnings(requireNamespace("rfPermute", quietly = TRUE))

# Set random seed for reproducibility
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
    output_richness = "richness.txt",
    output_genes = "rf_genes.txt",
    output_plot = "rf_importance.pdf",
    ntree = 500,
    nrep = 299,
    num_cores = 1,
    p_cutoff = 0.05
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
    } else if (grepl("^--output-richness=", arg)) {
      params$output_richness <- sub("^--output-richness=", "", arg)
    } else if (grepl("^--output-genes=", arg)) {
      params$output_genes <- sub("^--output-genes=", "", arg)
    } else if (grepl("^--output-plot=", arg)) {
      params$output_plot <- sub("^--output-plot=", "", arg)
    } else if (grepl("^--ntree=", arg)) {
      params$ntree <- as.integer(sub("^--ntree=", "", arg))
    } else if (grepl("^--nrep=", arg)) {
      params$nrep <- as.integer(sub("^--nrep=", "", arg))
    } else if (grepl("^--cores=", arg)) {
      params$num_cores <- as.integer(sub("^--cores=", "", arg))
    } else if (grepl("^--p-cutoff=", arg)) {
      params$p_cutoff <- as.numeric(sub("^--p-cutoff=", "", arg))
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript random_forest_importance.R [options]\n")
      cat("Options:\n")
      cat("  --input=<path>            Path to expression matrix [default: merged_file.txt]\n")
      cat("  --metadata=<path>         Canonical sample metadata CSV/TSV (required)\n")
      cat("  --manifest=<path>         Run manifest (required)\n")
      cat("  --source-revision=<s>     Source revision recorded in status (required)\n")
      cat("  --output-dir=<dir>        Directory for outputs [default: .]\n")
      cat("  --output-richness=<file>  Filename for importance table [default: richness.txt]\n")
      cat("  --output-genes=<file>     Filename for significant genes [default: rf_genes.txt]\n")
      cat("  --output-plot=<file>      Filename for bar plot PDF [default: rf_importance.pdf]\n")
      cat("  --ntree=<int>             Number of trees [default: 500]\n")
      cat("  --nrep=<int>              Number of permutations [default: 299]\n")
      cat("  --cores=<int>             Cores for permutation [default: 1]\n")
      cat("  --p-cutoff=<num>          Significance threshold [default: 0.05]\n")
      quit(status = 0)
    }
  }
  return(params)
}

main <- function() {
  params <- parse_args()

  if (!nzchar(params$input_file) || !nzchar(params$metadata) || !nzchar(params$manifest)) {
    contract_stop("--input, --metadata, and --manifest are required for Random Forest")
  }
  params$input_file <- assert_explicit_path(params$input_file, "Random Forest expression matrix", must_exist = TRUE)
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
  
  cat(sprintf("[INFO] Reading candidate gene expression: %s\n", params$input_file))
  metadata_contract <- read_metadata_contract(params$metadata)
  raw_mat <- read_expression_matrix_contract(params$input_file, metadata_contract)
  discovery_ids <- metadata_contract$sample_id[metadata_contract$partition == "discovery"]
  if (length(discovery_ids) < 4) {
    contract_stop("insufficient_discovery_samples: at least four discovery samples are required")
  }
  # Variable importance is a discovery/selection operation; validation samples
  # are never used to choose RF genes.
  expr_t <- as.data.frame(t(raw_mat[, discovery_ids, drop = FALSE]))
  sample_names <- rownames(expr_t)
  
  # Extract response strictly from the canonical metadata.
  disease_labels <- metadata_contract$group[match(sample_names, metadata_contract$sample_id)]
  if (any(is.na(disease_labels))) contract_stop("metadata_sample_mismatch")
  data_df <- expr_t
  data_df$disease <- as.factor(disease_labels)
  
  # Fix R formula column name collisions (syntactically valid names for RF)
  orig_gene_names <- setdiff(colnames(data_df), "disease")
  clean_gene_names <- make.names(orig_gene_names)
  name_mapping <- setNames(orig_gene_names, clean_gene_names)
  
  colnames(data_df)[seq_along(orig_gene_names)] <- clean_gene_names
  
  cat(sprintf("[INFO] Training dataset constructed: %d samples, %d genes.\n", 
              nrow(data_df), length(orig_gene_names)))
  cat("[INFO] Phenotype breakdown:\n")
  print(table(data_df$disease))
  if (length(unique(data_df$disease)) < 2 || min(table(data_df$disease)) < 2) {
    contract_stop("insufficient_class_size: every discovery class needs at least two samples")
  }
  
  # Execute Random Forest with Permutation Test
  richness_data <- NULL
  
  if (has_rfPermute) {
    cat(sprintf("[INFO] Executing rfPermute with %d trees and %d permutation iterations...\n", 
                params$ntree, params$nrep))
    rfp_model <- tryCatch({
      rfPermute::rfPermute(
        disease ~ ., 
        data = data_df, 
        ntree = params$ntree, 
        nrep = params$nrep, 
        num.cores = params$num_cores
      )
    }, error = function(e) {
      cat(sprintf("[WARN] rfPermute multi-threaded call failed: %s. Retrying with num.cores=1...\n", e$message))
      rfPermute::rfPermute(
        disease ~ ., 
        data = data_df, 
        ntree = params$ntree, 
        nrep = params$nrep, 
        num.cores = 1
      )
    })
    
    # Extract importance matrix
    imp_raw <- as.data.frame(randomForest::importance(rfp_model, decreasing = FALSE))
    
    # Check if p-values are available in rfPermute output
    p_vals <- tryCatch({
      rfPermute::rp.importance(rfp_model)
    }, error = function(e) {
      imp_raw
    })
    
    richness_data <- as.data.frame(imp_raw)
    
    # Identify MeanDecreaseGini and its p-value
    if ("MeanDecreaseGini.pval" %in% colnames(richness_data)) {
      richness_data$p_value <- richness_data$MeanDecreaseGini.pval
    } else if ("MeanDecreaseGini.pval" %in% colnames(p_vals)) {
      richness_data$p_value <- p_vals[rownames(richness_data), "MeanDecreaseGini.pval"]
    } else {
      stop("[GATE ERROR] rfPermute result lacks MeanDecreaseGini.pval and no valid empirical p-value source is available. Refusing fabricated p-values (contracts G-04).")
    }
  } else {
    cat("[INFO] 'rfPermute' package not available. Using standard randomForest permutation importance...\n")
    rf_model <- randomForest::randomForest(
      disease ~ ., 
      data = data_df, 
      ntree = params$ntree, 
      importance = TRUE
    )
    
    imp_raw <- as.data.frame(randomForest::importance(rf_model, type = 2)) # 2 = MeanDecreaseGini
    if (!"MeanDecreaseGini" %in% colnames(imp_raw)) {
      colnames(imp_raw)[1] <- "MeanDecreaseGini"
    }
    
    # Permutation estimation for p-values
    cat(sprintf("[INFO] Running %d label permutations for significance testing...\n", min(100, params$nrep)))
    actual_gini <- imp_raw$MeanDecreaseGini
    perm_gini <- matrix(0, nrow = nrow(imp_raw), ncol = min(100, params$nrep))
    
    for (p_idx in seq_len(ncol(perm_gini))) {
      perm_data <- data_df
      perm_data$disease <- sample(perm_data$disease)
      m_perm <- randomForest::randomForest(disease ~ ., data = perm_data, ntree = 200, importance = FALSE)
      perm_imp <- randomForest::importance(m_perm, type = 2)
      stopifnot("Permutation rownames must align with observed importance" = identical(rownames(perm_imp), rownames(imp_raw)))
      perm_gini[, p_idx] <- perm_imp[, 1]
    }
    
    p_vals_emp <- sapply(seq_along(actual_gini), function(i) {
      (sum(perm_gini[i, ] >= actual_gini[i]) + 1) / (ncol(perm_gini) + 1)
    })
    
    richness_data <- imp_raw
    richness_data$p_value <- p_vals_emp
  }
  
  # Ensure column names
  if (!"MeanDecreaseGini" %in% colnames(richness_data)) {
    # If Gini is under another name
    gini_col <- grep("Gini", colnames(richness_data), value = TRUE)
    if (length(gini_col) > 0) {
      richness_data$MeanDecreaseGini <- richness_data[[gini_col[1]]]
    } else {
      richness_data$MeanDecreaseGini <- richness_data[[1]]
    }
  }
  
  # Map cleaned names back to original gene symbols
  clean_rows <- rownames(richness_data)
  richness_data$name <- ifelse(clean_rows %in% names(name_mapping), name_mapping[clean_rows], clean_rows)
  rownames(richness_data) <- richness_data$name
  
  # Create significance label annotations
  richness_data$label <- ifelse(
    richness_data$p_value < 0.001, "***",
    ifelse(richness_data$p_value < 0.01, "**",
           ifelse(richness_data$p_value < params$p_cutoff, "*", "NS"))
  )
  
  # Sort genes by MeanDecreaseGini ascending for horizontal bar chart
  richness_data <- richness_data[order(richness_data$MeanDecreaseGini, decreasing = FALSE), ]
  richness_data$name <- factor(richness_data$name, levels = richness_data$name)
  
  # Save full richness table
  out_richness_path <- file.path(params$output_dir, params$output_richness)
  write.table(
    richness_data, 
    file = out_richness_path, 
    sep = "\t", 
    quote = FALSE, 
    col.names = TRUE, 
    row.names = FALSE
  )
  cat(sprintf("[SUCCESS] Exported variable importance table to: %s\n", out_richness_path))
  
  # Filter significant features (p < p_cutoff)
  sig_genes <- as.character(richness_data$name[richness_data$p_value < params$p_cutoff])
  
  # An empty significance set is a valid negative result. Never replace it with
  # ranked top-N genes because that changes the candidate estimand.
  if (length(sig_genes) == 0) {
    cat(sprintf("[NEGATIVE] No genes reached permutation p < %.2f; no top-N fallback applied.\n", params$p_cutoff))
    out_genes_path <- file.path(params$output_dir, params$output_genes)
    writeLines(character(), out_genes_path)
    write_stage_status(
      manifest, "bio-08-ml-randomforest", "negative",
      "no feature reached the permutation threshold; no top-N fallback was applied",
      commandArgs(trailingOnly = FALSE), c(params$input_file, params$metadata),
      c(out_richness_path, out_genes_path), sample_names,
      status_path = file.path(params$output_dir, "status", "bio-08-ml-randomforest.json"),
      exit_code = 0
    )
    return(invisible(FALSE))
  }
  
  # Gate check
  if (length(sig_genes) < 1) {
    stop("[GATE ERROR] Random Forest failed to select any significant features! Aborting.")
  }
  
  # Export rf_genes.txt (single column, no header)
  out_genes_path <- file.path(params$output_dir, params$output_genes)
  write.table(
    sig_genes, 
    file = out_genes_path, 
    sep = "\t", 
    quote = FALSE, 
    row.names = FALSE, 
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Exported %d significant RF genes to: %s\n", length(sig_genes), out_genes_path))
  
  # Generate publication-quality visualization
  # Limit displayed genes in PDF if candidate list is very long (> 40 genes)
  plot_data <- if (nrow(richness_data) > 40) tail(richness_data, 40) else richness_data
  
  palette_colors <- brewer.pal(8, "Accent")
  
  p <- ggplot(plot_data, aes(x = name, y = MeanDecreaseGini)) +
    geom_bar(aes(fill = label), stat = "identity", width = 0.7) +
    scale_fill_manual(
      values = c(
        "***" = "#B91C1C",
        "**"  = "#EA580C",
        "*"   = "#0284C7",
        "NS"  = "#9CA3AF"
      ),
      name = "Significance"
    ) +
    geom_text(
      aes(
        y = MeanDecreaseGini + max(MeanDecreaseGini) * 0.02,
        label = label
      ),
      hjust = 0,
      size = 4.2,
      fontface = "bold",
      color = "#1F2937"
    ) +
    coord_flip() +
    theme_classic(base_size = 11) +
    theme(
      axis.text.y = element_text(size = 9, color = "#111827"),
      axis.title = element_text(face = "bold", size = 11),
      plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
      legend.position = "right"
    ) +
    labs(
      title = "Random Forest Variable Importance (Gini Impurity)",
      x = "Candidate Gene Symbol",
      y = "Mean Decrease Gini",
      caption = "*** p < 0.001, ** p < 0.01, * p < 0.05"
    ) +
    expand_limits(y = max(plot_data$MeanDecreaseGini) * 1.12)
  
  out_plot_path <- file.path(params$output_dir, params$output_plot)
  pdf(file = out_plot_path, width = 7.5, height = max(6, nrow(plot_data) * 0.22))
  print(p)
  dev.off()
  cat(sprintf("[SUCCESS] Saved variable importance plot to: %s\n", out_plot_path))
  
  cat("========================================================\n")
  cat(sprintf("Total Evaluated Genes: %d\n", nrow(richness_data)))
  cat(sprintf("Selected RF Genes:     %d (p < %.2f)\n", length(sig_genes), params$p_cutoff))
  cat("Top Genes:\n")
  print(head(sig_genes, 10))
  cat("========================================================\n")
  write_stage_status(
    manifest, "bio-08-ml-randomforest", "success",
    "discovery-only RF permutation importance completed",
    commandArgs(trailingOnly = FALSE), c(params$input_file, params$metadata),
    c(out_richness_path, out_genes_path, out_plot_path), sample_names,
    status_path = file.path(params$output_dir, "status", "bio-08-ml-randomforest.json"),
    exit_code = 0
  )
  cat("[STAGE COMPLETE] bio-08-ml-randomforest completed successfully on discovery data.\n")
}

if (!interactive()) {
  main()
}
