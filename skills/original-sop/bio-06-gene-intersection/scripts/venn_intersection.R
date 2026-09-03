#!/usr/bin/env Rscript
# ==============================================================================
# venn_intersection.R - Multi-gene Set Intersection and Venn Diagram Generation
# ==============================================================================
# Skill: bio-06-gene-intersection
# Description: Takes candidate genes from WGCNA key modules and limma DEGs,
#              calculates their intersection, plots a publication-ready Venn
#              diagram, and exports candidate hub genes.
# ==============================================================================

# Explicit library imports
suppressPackageStartupMessages({
  library(VennDiagram)
  library(grid)
})

# Disable VennDiagram logging to log file (redirect to console/suppress)
futile.logger::flog.threshold(futile.logger::ERROR, name = "VennDiagramLogger")

# Set random seed for reproducibility
set.seed(12345)

# Parse command line arguments
parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    wgcna_file = "module_genes.csv",
    deg_file = "diff.txt",
    output_dir = ".",
    output_genes = "candidate_hub_genes.txt",
    output_plot = "venn_plot.pdf",
    wgcna_col = NULL,
    deg_col = NULL
  )
  
  for (arg in args) {
    if (grepl("^--wgcna=", arg)) {
      params$wgcna_file <- sub("^--wgcna=", "", arg)
    } else if (grepl("^--deg=", arg)) {
      params$deg_file <- sub("^--deg=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      params$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--output-genes=", arg)) {
      params$output_genes <- sub("^--output-genes=", "", arg)
    } else if (grepl("^--output-plot=", arg)) {
      params$output_plot <- sub("^--output-plot=", "", arg)
    } else if (grepl("^--wgcna-col=", arg)) {
      params$wgcna_col <- sub("^--wgcna-col=", "", arg)
    } else if (grepl("^--deg-col=", arg)) {
      params$deg_col <- sub("^--deg-col=", "", arg)
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript venn_intersection.R [options]\n")
      cat("Options:\n")
      cat("  --wgcna=<path>        Path to WGCNA module genes file [default: module_genes.csv]\n")
      cat("  --deg=<path>          Path to DEG file [default: diff.txt]\n")
      cat("  --output-dir=<dir>    Directory for output files [default: .]\n")
      cat("  --output-genes=<file> Filename for intersection genes [default: candidate_hub_genes.txt]\n")
      cat("  --output-plot=<file>  Filename for Venn PDF plot [default: venn_plot.pdf]\n")
      cat("  --wgcna-col=<name>    Column name for WGCNA gene symbols [default: auto-detect]\n")
      cat("  --deg-col=<name>      Column name for DEG gene symbols [default: auto-detect]\n")
      quit(status = 0)
    }
  }
  return(params)
}

# Helper to read gene list from various formats (.csv, .txt, .tsv)
read_gene_list <- function(file_path, specified_col = NULL, label = "dataset") {
  if (!file.exists(file_path)) {
    stop(sprintf("[ERROR] Input file does not exist: %s (%s)", file_path, label))
  }
  
  cat(sprintf("[INFO] Reading %s from: %s\n", label, file_path))
  
  # Try tab-separated first, then comma-separated
  content <- tryCatch({
    # Check first line to detect separator
    first_line <- readLines(file_path, n = 1, warn = FALSE)
    sep <- if (grepl(",", first_line)) "," else "\t"
    read.table(file_path, header = TRUE, sep = sep, stringsAsFactors = FALSE, 
               check.names = FALSE, quote = "\"'", fill = TRUE)
  }, error = function(e) {
    # Fallback to single column vector
    readLines(file_path, warn = FALSE)
  })
  
  if (is.vector(content) && !is.data.frame(content)) {
    genes <- trimws(content)
    genes <- genes[genes != "" & !is.na(genes)]
    return(unique(genes))
  }
  
  df <- content
  if (ncol(df) == 1) {
    genes <- as.character(df[[1]])
  } else if (!is.null(specified_col) && specified_col %in% colnames(df)) {
    genes <- as.character(df[[specified_col]])
  } else {
    # Auto-detect gene symbol column
    candidate_cols <- c("geneNames", "gene", "Gene", "genes", "Symbol", "symbol", 
                        "gene_name", "GeneSymbol", "ID", "id", "row.names")
    match_idx <- which(colnames(df) %in% candidate_cols)
    if (length(match_idx) > 0) {
      genes <- as.character(df[[match_idx[1]]])
    } else {
      # Use first column or row names if first column is numeric
      if (is.numeric(df[[1]]) && !is.null(rownames(df))) {
        genes <- rownames(df)
      } else {
        genes <- as.character(df[[1]])
      }
    }
  }
  
  genes <- trimws(genes)
  genes <- genes[genes != "" & !is.na(genes)]
  genes <- unique(genes)
  cat(sprintf("[INFO] Extracted %d unique genes from %s\n", length(genes), label))
  return(genes)
}

main <- function() {
  params <- parse_args()
  
  # Ensure output directory exists
  if (!dir.exists(params$output_dir)) {
    dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  out_genes_path <- file.path(params$output_dir, params$output_genes)
  out_plot_path <- file.path(params$output_dir, params$output_plot)
  
  # Read input gene lists
  wgcna_genes <- read_gene_list(params$wgcna_file, params$wgcna_col, "WGCNA module genes")
  deg_genes <- read_gene_list(params$deg_file, params$deg_col, "limma DEG genes")
  
  # Calculate set intersection
  candidate_hub_genes <- intersect(wgcna_genes, deg_genes)
  n_intersect <- length(candidate_hub_genes)
  
  cat("========================================================\n")
  cat(sprintf("WGCNA Module Genes:       %d\n", length(wgcna_genes)))
  cat(sprintf("Limma DEG Genes:          %d\n", length(deg_genes)))
  cat(sprintf("Intersection (Candidate): %d\n", n_intersect))
  cat("========================================================\n")
  
  # QC Gate Check: Candidate hub genes >= 2
  if (n_intersect < 2) {
    warning(sprintf("[GATE WARNING] Candidate hub genes count (%d) is less than the gate threshold of 2.", n_intersect))
    if (n_intersect == 0) {
      stop("[GATE ERROR] Zero intersecting genes found between WGCNA and limma DEG sets! Aborting.")
    }
  }
  
  # Export candidate hub gene list (Constitution contract: single column, no header, no quotes)
  write.table(
    candidate_hub_genes,
    file = out_genes_path,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE,
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved candidate hub genes to: %s\n", out_genes_path))
  
  # Generate publication-quality Venn Diagram
  gene_list <- list(
    "WGCNA Module" = wgcna_genes,
    "Limma DEGs" = deg_genes
  )
  
  venn_plot <- venn.diagram(
    x = gene_list,
    filename = NULL, # Render to grid object
    col = "transparent",
    fill = c("#3B82F6", "#EF4444"),
    alpha = c(0.5, 0.5),
    cex = 1.4,
    fontfamily = "sans",
    fontface = "bold",
    cat.col = c("#1E40AF", "#991B1B"),
    cat.cex = 1.2,
    cat.fontfamily = "sans",
    cat.fontface = "bold",
    cat.default.pos = "outer",
    cat.pos = c(-20, 20),
    cat.dist = c(0.05, 0.05),
    margin = 0.1
  )
  
  pdf(file = out_plot_path, width = 6.5, height = 6)
  grid.draw(venn_plot)
  dev.off()
  cat(sprintf("[SUCCESS] Saved Venn diagram to: %s\n", out_plot_path))
  
  # Summary output for downstream integration
  cat("\nTop Candidate Hub Genes:\n")
  print(head(candidate_hub_genes, 20))
  cat("\n[STAGE COMPLETE] bio-06-gene-intersection finished successfully.\n")
}

# Run main if invoked directly
if (!interactive()) {
  main()
}
