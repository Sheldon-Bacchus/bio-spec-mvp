#!/usr/bin/env Rscript
# ==============================================================================
# gene_expression_match.R - Match Candidate Genes to Expression Matrix
# ==============================================================================
# Skill: bio-07-ml-lasso (Preparation Step)
# Description: Subsets normalized whole-genome expression matrix to only include
#              the candidate hub genes from previous intersection, preparing
#              a structured feature table for LASSO and Random Forest models.
# ==============================================================================

# Set random seed for reproducibility
set.seed(12345)

# Parse command line arguments
parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    expr_file = "merge.normalize.txt",
    gene_file = "candidate_hub_genes.txt",
    output_dir = ".",
    output_txt = "merged_file.txt",
    output_csv = "merged_data.csv",
    gene_col_expr = "geneNames"
  )
  
  for (arg in args) {
    if (grepl("^--expr=", arg)) {
      params$expr_file <- sub("^--expr=", "", arg)
    } else if (grepl("^--genes=", arg)) {
      params$gene_file <- sub("^--genes=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      params$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--out-txt=", arg)) {
      params$output_txt <- sub("^--out-txt=", "", arg)
    } else if (grepl("^--out-csv=", arg)) {
      params$output_csv <- sub("^--out-csv=", "", arg)
    } else if (grepl("^--gene-col=", arg)) {
      params$gene_col_expr <- sub("^--gene-col=", "", arg)
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript gene_expression_match.R [options]\n")
      cat("Options:\n")
      cat("  --expr=<path>        Path to normalized expression matrix [default: merge.normalize.txt]\n")
      cat("  --genes=<path>       Path to candidate genes file [default: candidate_hub_genes.txt]\n")
      cat("  --output-dir=<dir>   Directory for output files [default: .]\n")
      cat("  --out-txt=<file>     Filename for output TXT [default: merged_file.txt]\n")
      cat("  --out-csv=<file>     Filename for output CSV [default: merged_data.csv]\n")
      cat("  --gene-col=<name>    Gene symbol column in expr matrix [default: geneNames or rownames]\n")
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
  
  if (!file.exists(params$expr_file)) {
    stop(sprintf("[ERROR] Expression matrix file not found: %s (contracts G-01: no legacy typo alias)", params$expr_file))
  }
  
  if (!file.exists(params$gene_file)) {
    fallback_gene <- "molgene.csv"
    if (file.exists(fallback_gene)) {
      cat(sprintf("[WARN] '%s' not found, using existing fallback '%s'\n", params$gene_file, fallback_gene))
      params$gene_file <- fallback_gene
    } else {
      stop(sprintf("[ERROR] Candidate gene list file not found: %s", params$gene_file))
    }
  }
  
  cat(sprintf("[INFO] Loading expression matrix: %s\n", params$expr_file))
  # Detect expression matrix delimiter
  first_line_expr <- readLines(params$expr_file, n = 1, warn = FALSE)
  sep_expr <- if (grepl(",", first_line_expr)) "," else "\t"
  
  expr_data <- read.table(
    params$expr_file, 
    header = TRUE, 
    sep = sep_expr, 
    check.names = FALSE, 
    stringsAsFactors = FALSE, 
    quote = "\"'", 
    fill = TRUE
  )
  
  # Check if gene symbols are in rownames or in a dedicated column
  if (params$gene_col_expr %in% colnames(expr_data)) {
    cat(sprintf("[INFO] Using column '%s' as gene identifier in expression matrix.\n", params$gene_col_expr))
  } else if ("geneNames" %in% colnames(expr_data)) {
    params$gene_col_expr <- "geneNames"
  } else if ("Symbol" %in% colnames(expr_data)) {
    params$gene_col_expr <- "Symbol"
  } else if ("gene" %in% colnames(expr_data)) {
    params$gene_col_expr <- "gene"
  } else {
    # If first column is non-numeric, assume it is geneNames
    if (!is.numeric(expr_data[[1]])) {
      params$gene_col_expr <- colnames(expr_data)[1]
      cat(sprintf("[INFO] Using first column '%s' as gene identifier.\n", params$gene_col_expr))
    } else {
      # Treat rownames as gene names
      expr_data <- cbind(geneNames = rownames(expr_data), expr_data)
      params$gene_col_expr <- "geneNames"
    }
  }
  
  # Standardize column name to 'geneNames'
  colnames(expr_data)[which(colnames(expr_data) == params$gene_col_expr)] <- "geneNames"
  
  cat(sprintf("[INFO] Loading candidate genes: %s\n", params$gene_file))
  # Read gene list file
  first_line_gene <- readLines(params$gene_file, n = 1, warn = FALSE)
  sep_gene <- if (grepl(",", first_line_gene)) "," else "\t"
  
  gene_raw <- tryCatch({
    read.table(params$gene_file, header = TRUE, sep = sep_gene, stringsAsFactors = FALSE, 
               check.names = FALSE, quote = "\"'")
  }, error = function(e) {
    readLines(params$gene_file, warn = FALSE)
  })
  
  if (is.vector(gene_raw) && !is.data.frame(gene_raw)) {
    candidate_genes <- unique(trimws(gene_raw))
  } else if (ncol(gene_raw) == 1) {
    candidate_genes <- unique(trimws(as.character(gene_raw[[1]])))
  } else {
    # If file has multiple columns, find column with gene names
    if ("geneNames" %in% colnames(gene_raw)) {
      candidate_genes <- unique(trimws(as.character(gene_raw$geneNames)))
    } else if ("Symbol" %in% colnames(gene_raw)) {
      candidate_genes <- unique(trimws(as.character(gene_raw$Symbol)))
    } else if (!is.null(rownames(gene_raw)) && !all(rownames(gene_raw) == as.character(seq_len(nrow(gene_raw))))) {
      candidate_genes <- unique(trimws(rownames(gene_raw)))
    } else {
      candidate_genes <- unique(trimws(as.character(gene_raw[[1]])))
    }
  }
  
  candidate_genes <- candidate_genes[candidate_genes != "" & !is.na(candidate_genes)]
  cat(sprintf("[INFO] Parsed %d target candidate genes.\n", length(candidate_genes)))
  
  # Create data frame for merging
  gene_df <- data.frame(geneNames = candidate_genes, stringsAsFactors = FALSE)
  
  # Merge expression matrix with candidate genes
  merged_data <- merge(gene_df, expr_data, by = "geneNames")
  n_matched <- nrow(merged_data)
  
  cat("========================================================\n")
  cat(sprintf("Requested Candidate Genes: %d\n", length(candidate_genes)))
  cat(sprintf("Matched Genes in Matrix:   %d\n", n_matched))
  cat(sprintf("Sample Columns Available:  %d\n", ncol(merged_data) - 1))
  cat("========================================================\n")
  
  if (n_matched < 1) {
    stop("[GATE ERROR] Zero candidate genes were matched in the expression matrix! Check gene symbols or casing.")
  }
  
  if (n_matched < length(candidate_genes)) {
    unmatched <- setdiff(candidate_genes, merged_data$geneNames)
    cat(sprintf("[WARN] %d genes could not be found in expression matrix: %s\n", 
                length(unmatched), paste(head(unmatched, 5), collapse = ", ")))
  }
  
  # Output file paths
  out_txt_path <- file.path(params$output_dir, params$output_txt)
  out_csv_path <- file.path(params$output_dir, params$output_csv)
  
  # Save tab-separated file (merged_file.txt)
  write.table(
    merged_data, 
    file = out_txt_path, 
    sep = "\t", 
    row.names = FALSE, 
    quote = FALSE
  )
  cat(sprintf("[SUCCESS] Saved matched expression matrix to: %s\n", out_txt_path))
  
  # Save CSV file (merged_data.csv)
  write.csv(
    merged_data, 
    file = out_csv_path, 
    row.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved matched expression matrix to: %s\n", out_csv_path))
  
  cat("[STAGE COMPLETE] Gene expression matching finished successfully.\n")
}

if (!interactive()) {
  main()
}
