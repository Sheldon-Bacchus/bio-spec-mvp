#!/usr/bin/env Rscript
# ==============================================================================
# venn_intersection.R - Multi-gene Set Intersection and Venn Diagram Generation
# ==============================================================================
# Skill: bio-06-gene-intersection
# Shared run and provenance contracts.
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)
# Description: Takes candidate genes from WGCNA key modules and limma DEGs,
#              calculates their intersection, plots a publication-ready Venn
#              diagram, and exports candidate hub genes.
# ==============================================================================

# Explicit library imports
suppressPackageStartupMessages({
  library(VennDiagram)
  library(grid)
})

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
    deg_col = NULL,
    manifest = "",
    source_revision = ""
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
    } else if (grepl("^--manifest=", arg)) {
      params$manifest <- sub("^--manifest=", "", arg)
    } else if (grepl("^--source-revision=", arg)) {
      params$source_revision <- sub("^--source-revision=", "", arg)
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
  file_path <- assert_explicit_path(file_path, label, must_exist = TRUE)
  cat(sprintf("[INFO] Reading %s from: %s\n", label, file_path))
  lines <- readLines(file_path, warn = FALSE)
  if (length(lines) == 0) return(character())
  first_line <- trimws(lines[[1]])
  has_header <- grepl("(^|[\\t,])(gene|genes|genename|genesymbol|symbol|id)([\\t,]|$)", first_line, ignore.case = TRUE)
  if (!has_header) {
    genes <- trimws(gsub("[\\\"']", "", lines))
  } else {
    sep <- if (grepl(",", first_line, fixed = TRUE)) "," else "\t"
    df <- if (sep == ",") {
      read.csv(file_path, header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
    } else {
      read.table(file_path, header = TRUE, sep = sep, stringsAsFactors = FALSE,
                 check.names = FALSE, quote = "\"'", fill = TRUE, comment.char = "")
    }
    if (!is.null(specified_col) && specified_col %in% colnames(df)) {
      genes <- as.character(df[[specified_col]])
    } else {
      candidates <- c("geneNames", "gene", "Gene", "genes", "Symbol", "symbol",
                      "gene_name", "GeneSymbol", "ID", "id")
      match_idx <- which(colnames(df) %in% candidates)
      genes <- as.character(df[[if (length(match_idx) > 0) match_idx[[1]] else 1]])
    }
    genes <- trimws(gsub("[\\\"']", "", genes))
  }
  genes <- unique(genes[!is.na(genes) & nzchar(genes)])
  cat(sprintf("[INFO] Extracted %d unique genes from %s\n", length(genes), label))
  genes
}

main <- function() {
  params <- parse_args()

  if (!nzchar(params$manifest)) {
    contract_stop("--manifest is required for an auditable intersection run")
  }
  params$manifest <- assert_explicit_path(params$manifest, "manifest", must_exist = TRUE)
  manifest <- validate_manifest_context(
    params$manifest,
    source_revision = if (nzchar(params$source_revision)) params$source_revision else NULL
  )
  params$wgcna_file <- assert_explicit_path(params$wgcna_file, "WGCNA gene list", must_exist = TRUE)
  params$deg_file <- assert_explicit_path(params$deg_file, "DEG gene list", must_exist = TRUE)
  
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
  
  # Generate the diagnostic plot. An empty intersection is a valid negative
  # result, so it receives a text-only PDF instead of a union/top-N substitute.
  pdf(file = out_plot_path, width = 6.5, height = 6)
  if (n_intersect == 0) {
    plot.new()
    text(0.5, 0.6, "Empty candidate intersection", cex = 1.2)
    text(0.5, 0.4, "Status: negative; no union fallback", cex = 0.9)
  } else {
    gene_list <- list("WGCNA Module" = wgcna_genes, "Limma DEGs" = deg_genes)
    venn_plot <- venn.diagram(
      x = gene_list, filename = NULL, col = "transparent",
      fill = c("#3B82F6", "#EF4444"), alpha = c(0.5, 0.5), cex = 1.4,
      fontfamily = "sans", fontface = "bold",
      cat.col = c("#1E40AF", "#991B1B"), cat.cex = 1.2,
      cat.fontfamily = "sans", cat.fontface = "bold",
      cat.default.pos = "outer", cat.pos = c(-20, 20),
      cat.dist = c(0.05, 0.05), margin = 0.1
    )
    grid.draw(venn_plot)
  }
  dev.off()
  cat(sprintf("[SUCCESS] Saved Venn diagram to: %s\n", out_plot_path))
  
  # Summary output for downstream integration
  cat("\nTop Candidate Hub Genes:\n")
  print(head(candidate_hub_genes, 20))
  summary_path <- file.path(params$output_dir, "intersection_status.json")
  status <- if (n_intersect > 0) "success" else "negative"
  reason <- if (n_intersect > 0) "declared WGCNA/DEG intersection computed" else "declared WGCNA/DEG intersection is empty; no union fallback"
  write_stage_status(
    manifest, "bio-06-gene-intersection", status, reason,
    commandArgs(trailingOnly = FALSE), c(params$wgcna_file, params$deg_file),
     c(out_genes_path, out_plot_path, summary_path),
    character(), status_path = file.path(params$output_dir, "status", "bio-06-gene-intersection.json"),
    exit_code = 0
  )
  write_json_contract(list(status = status, reason = reason, candidate_count = n_intersect), summary_path)
  cat(sprintf("\n[STAGE %s] bio-06-gene-intersection finished: %s.\n", toupper(status), reason))
}

# Run main if invoked directly
if (!interactive()) {
  main()
}
