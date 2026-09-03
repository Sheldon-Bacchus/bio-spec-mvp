#!/usr/bin/env Rscript
# ==============================================================================
# hub_gene_intersection.R - Dual-Algorithm Machine Learning Intersection
# ==============================================================================
# Skill: bio-09-hub-literature
# Description: Takes feature gene subsets selected by LASSO regression (L1 penalty)
#              and Random Forest (permutation significance), computes their final
#              consensus intersection, and produces the definitive Hub gene panel.
# ==============================================================================

# Set random seed for reproducibility
set.seed(12345)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    lasso_file = "LASSO.gene.txt",
    rf_file = "rf_genes.txt",
    output_dir = ".",
    output_hub_file = "final_hub_genes.txt",
    output_summary = "hub_intersection_summary.txt"
  )
  
  for (arg in args) {
    if (grepl("^--lasso=", arg)) {
      params$lasso_file <- sub("^--lasso=", "", arg)
    } else if (grepl("^--rf=", arg)) {
      params$rf_file <- sub("^--rf=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      params$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--output-hub=", arg)) {
      params$output_hub_file <- sub("^--output-hub=", "", arg)
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript hub_gene_intersection.R [options]\n")
      cat("Options:\n")
      cat("  --lasso=<path>       Path to LASSO feature gene list [default: LASSO.gene.txt]\n")
      cat("  --rf=<path>          Path to Random Forest feature gene list [default: rf_genes.txt]\n")
      cat("  --output-dir=<dir>   Directory for output files [default: .]\n")
      cat("  --output-hub=<file>  Filename for final hub genes [default: final_hub_genes.txt]\n")
      quit(status = 0)
    }
  }
  return(params)
}

read_genes <- function(file_path, label) {
  if (!file.exists(file_path)) {
    stop(sprintf("[ERROR] %s file not found: %s", label, file_path))
  }
  
  lines <- readLines(file_path, warn = FALSE)
  # Remove quotes and whitespace
  genes <- trimws(gsub("[\"']", "", lines))
  # Remove header if present
  header_candidates <- c("gene", "genes", "geneNames", "Symbol")
  if (length(genes) > 0 && genes[1] %in% header_candidates) {
    genes <- genes[-1]
  }
  genes <- genes[genes != "" & !is.na(genes)]
  genes <- unique(genes)
  cat(sprintf("[INFO] %s contains %d features.\n", label, length(genes)))
  return(genes)
}

main <- function() {
  params <- parse_args()
  
  # Ensure output directory exists
  if (!dir.exists(params$output_dir)) {
    dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Load gene sets from both algorithms
  lasso_genes <- read_genes(params$lasso_file, "LASSO")
  rf_genes <- read_genes(params$rf_file, "Random Forest")
  
  # Dual-algorithm consensus intersection
  final_hub_genes <- intersect(lasso_genes, rf_genes)
  n_intersect <- length(final_hub_genes)
  
  # Set metrics
  union_genes <- union(lasso_genes, rf_genes)
  jaccard_index <- if (length(union_genes) > 0) n_intersect / length(union_genes) else 0
  lasso_only <- setdiff(lasso_genes, rf_genes)
  rf_only <- setdiff(rf_genes, lasso_genes)
  
  cat("\n========================================================\n")
  cat("         DUAL-ALGORITHM HUB INTERSECTION REPORT         \n")
  cat("========================================================\n")
  cat(sprintf("LASSO Selected Features:         %d\n", length(lasso_genes)))
  cat(sprintf("Random Forest Selected Features: %d\n", length(rf_genes)))
  cat(sprintf("Dual-Algorithm Consensus Hubs:   %d\n", n_intersect))
  cat(sprintf("Total Union Feature Pool:        %d\n", length(union_genes)))
  cat(sprintf("Jaccard Similarity Index:        %.3f\n", jaccard_index))
  cat("--------------------------------------------------------\n")
  
  # If intersection is empty, implement graceful fallback
  if (n_intersect == 0) {
    stop("[GATE ERROR] Intersection between LASSO and Random Forest is EMPTY. Refusing union fallback (contracts G-06: empty intersection requires human review).")
  }
  
  # Gate check: Final Hub genes non-empty (at least 1 gene)
  if (n_intersect < 1) {
    stop("[GATE ERROR] Both LASSO and Random Forest produced 0 features! Aborting.")
  }
  
  cat("Consensus Hub Gene List:\n")
  for (i in seq_along(final_hub_genes)) {
    cat(sprintf("  [%02d] %s\n", i, final_hub_genes[i]))
  }
  cat("========================================================\n\n")
  
  # Save final hub genes to file (Constitution contract: single column, no header, no quotes)
  out_hub_path <- file.path(params$output_dir, params$output_hub_file)
  write.table(
    final_hub_genes, 
    file = out_hub_path, 
    sep = "\t", 
    quote = FALSE, 
    row.names = FALSE, 
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved %d final hub genes to: %s\n", n_intersect, out_hub_path))
  
  # Write structured summary report
  out_summary_path <- file.path(params$output_dir, params$output_summary)
  summary_lines <- c(
    "# Dual-Algorithm Consensus Hub Gene Summary",
    sprintf("Timestamp: %s", Sys.time()),
    sprintf("LASSO Features Count: %d", length(lasso_genes)),
    sprintf("Random Forest Features Count: %d", length(rf_genes)),
    sprintf("Consensus Hub Count: %d", n_intersect),
    sprintf("Jaccard Index: %.4f", jaccard_index),
    "",
    "## Consensus Hub Genes:",
    paste0("- ", final_hub_genes),
    "",
    "## LASSO-Specific Features:",
    if (length(lasso_only) > 0) paste0("- ", lasso_only) else "- None",
    "",
    "## Random Forest-Specific Features:",
    if (length(rf_only) > 0) paste0("- ", rf_only) else "- None"
  )
  writeLines(summary_lines, con = out_summary_path)
  cat(sprintf("[SUCCESS] Saved summary metrics to: %s\n", out_summary_path))
  
  cat("[STAGE COMPLETE] bio-09-hub-literature hub intersection finished successfully.\n")
}

if (!interactive()) {
  main()
}
