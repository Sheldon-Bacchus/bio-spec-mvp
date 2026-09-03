#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-05-enrichment
# Script: enrichment_analysis.R
# Description: Functional over-representation enrichment analysis using clusterProfiler:
#              performs GO enrichment (BP, CC, MF) and KEGG pathway enrichment,
#              generates barplots, dotplots, and gene-concept networks (cnetplot),
#              and exports structured enrichment results (GO_enrichment.csv, KEGG_enrichment.csv).
# Reproducibility: set.seed(12345)
# ==============================================================================

suppressPackageStartupMessages({
  library(clusterProfiler)
  library(enrichplot)
  library(ggplot2)
})

set.seed(12345)

# ------------------------------------------------------------------------------
# Argument Parser Helper
# ------------------------------------------------------------------------------
parse_args <- function(defaults) {
  args <- commandArgs(trailingOnly = TRUE)
  res <- defaults
  i <- 1
  while (i <= length(args)) {
    arg <- args[i]
    if (grepl("^--", arg)) {
      key_val <- sub("^--", "", arg)
      if (grepl("=", key_val)) {
        parts <- strsplit(key_val, "=", fixed = TRUE)[[1]]
        res[[parts[1]]] <- parts[2]
      } else if (i + 1 <= length(args) && !grepl("^--", args[i + 1])) {
        res[[key_val]] <- args[i + 1]
        i <- i + 1
      } else {
        res[[key_val]] <- TRUE
      }
    }
    i <- i + 1
  }
  return(res)
}

# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------
defaults <- list(
  input = "diff.txt",
  species = "human",                        # "human" (hsa) or "pae" (Pseudomonas aeruginosa)
  org_db = "org.Hs.eg.db",
  p_cutoff = "0.05",
  q_cutoff = "0.05",
  show_category = "15",
  outdir = "."
)

opt <- parse_args(defaults)
opt$p_cutoff <- as.numeric(opt$p_cutoff)
opt$q_cutoff <- as.numeric(opt$q_cutoff)
opt$show_category <- as.integer(opt$show_category)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting Functional Enrichment Analysis (clusterProfiler)\n")
cat(sprintf("[INFO] Input gene file: %s\n", opt$input))
cat(sprintf("[INFO] Target species: %s\n", opt$species))

# ------------------------------------------------------------------------------
# Step 1: Read Input Gene List & LogFC Values
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) {
  stop(sprintf("[ERROR] Input gene file not found: %s", opt$input))
}

# Support both tables with headers and plain single-column gene lists
input_lines <- readLines(opt$input, n = 5)
has_header <- grepl("id|symbol|logfc|gene", input_lines[1], ignore.case = TRUE)

gene_symbols <- c()
gene_fc_vec <- NULL

if (has_header) {
  gene_tab <- read.table(opt$input, header = TRUE, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)
  sym_col <- if ("id" %in% colnames(gene_tab)) "id" else colnames(gene_tab)[1]
  gene_symbols <- as.character(gene_tab[[sym_col]])
  
  if ("logFC" %in% colnames(gene_tab)) {
    gene_fc_vec <- as.numeric(gene_tab$logFC)
    names(gene_fc_vec) <- gene_symbols
  }
} else {
  gene_tab <- read.table(opt$input, header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  gene_symbols <- as.character(gene_tab[, 1])
}

gene_symbols <- unique(na.omit(trimws(gene_symbols)))
gene_symbols <- gene_symbols[gene_symbols != "" & gene_symbols != "---"]
cat(sprintf("[INFO] Extracted %d unique gene symbols for enrichment analysis.\n", length(gene_symbols)))

# ------------------------------------------------------------------------------
# Step 2: Species Resolution & Gene Identifier Conversion
# ------------------------------------------------------------------------------
is_human <- grepl("human|hsa|homo", opt$species, ignore.case = TRUE)
is_pae <- grepl("pae|pseudomonas|pa01|pao1", opt$species, ignore.case = TRUE)

entrez_ids <- c()
kegg_organism <- if (is_pae) "pae" else "hsa"

if (is_human) {
  cat("[INFO] Loading human annotation database (org.Hs.eg.db)...\n")
  if (!requireNamespace("org.Hs.eg.db", quietly = TRUE)) {
    stop("[ERROR] R package 'org.Hs.eg.db' is required for human GO analysis.")
  }
  library(org.Hs.eg.db)
  
  cat("[INFO] Converting gene Symbols to ENTREZ IDs via bitr()...\n")
  id_map <- bitr(gene_symbols, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
  entrez_ids <- unique(id_map$ENTREZID)
  cat(sprintf("[INFO] Successfully mapped %d / %d symbols to Entrez IDs.\n", length(entrez_ids), length(gene_symbols)))
  
  if (!is.null(gene_fc_vec)) {
    fc_matched <- gene_fc_vec[id_map$SYMBOL]
    names(fc_matched) <- id_map$ENTREZID
    gene_fc_vec <- fc_matched[!is.na(names(fc_matched))]
  }
} else if (is_pae) {
  cat("[INFO] Pseudomonas aeruginosa PAO1 detected. Using PA locus tags for KEGG organism 'pae'.\n")
  entrez_ids <- gene_symbols
} else {
  entrez_ids <- gene_symbols
}

# ------------------------------------------------------------------------------
# Step 3: Gene Ontology (GO) Enrichment Analysis
# ------------------------------------------------------------------------------
go_df_all <- data.frame()

if (is_human) {
  cat("[INFO] Running enrichGO across sub-ontologies (BP, CC, MF)...\n")
  go_results_list <- list()
  
  for (ont in c("BP", "CC", "MF")) {
    cat(sprintf("  - Processing GO Sub-ontology: %s...\n", ont))
    ego <- enrichGO(
      gene = entrez_ids,
      OrgDb = org.Hs.eg.db,
      ont = ont,
      pAdjustMethod = "BH",
      pvalueCutoff = opt$p_cutoff,
      qvalueCutoff = opt$q_cutoff,
      readable = TRUE
    )
    
    if (!is.null(ego) && nrow(as.data.frame(ego)) > 0) {
      ego_df <- as.data.frame(ego)
      ego_df$Ontology <- ont
      go_results_list[[ont]] <- ego_df
      
      # Plot individual ontology barplot and dotplot
      pdf(file.path(opt$outdir, sprintf("GO_%s_barplot.pdf", ont)), width = 9, height = 6)
      print(barplot(ego, showCategory = opt$show_category, title = paste("GO Enrichment -", ont)))
      dev.off()
      
      pdf(file.path(opt$outdir, sprintf("GO_%s_dotplot.pdf", ont)), width = 9, height = 6)
      print(dotplot(ego, showCategory = opt$show_category, title = paste("GO Enrichment -", ont)))
      dev.off()
    }
  }
  
  if (length(go_results_list) > 0) {
    go_df_all <- do.call(rbind, go_results_list)
  }
} else {
  cat("[WARN] Non-human organism specified. Direct enrichGO requires dedicated OrgDb. Checking KEGG enrichment...\n")
}

# Export GO enrichment results table
go_out_file <- file.path(opt$outdir, "GO_enrichment.csv")
cat(sprintf("[INFO] Exporting GO enrichment table to %s (%d terms)\n", go_out_file, nrow(go_df_all)))
write.csv(go_df_all, file = go_out_file, row.names = FALSE, quote = TRUE)

# ------------------------------------------------------------------------------
# Step 4: KEGG Pathway Enrichment Analysis
# ------------------------------------------------------------------------------
cat(sprintf("[INFO] Running enrichKEGG (organism = '%s', pCutoff = %.2f)...\n", kegg_organism, opt$p_cutoff))
kegg_res <- tryCatch({
  enrichKEGG(
    gene = entrez_ids,
    organism = kegg_organism,
    pAdjustMethod = "BH",
    pvalueCutoff = opt$p_cutoff,
    qvalueCutoff = opt$q_cutoff
  )
}, error = function(e) {
  cat(sprintf("[WARN] enrichKEGG online query returned error: %s\n", e$message))
  return(NULL)
})

kegg_df <- data.frame()

if (!is.null(kegg_res) && nrow(as.data.frame(kegg_res)) > 0) {
  if (is_human) {
    kegg_res <- setReadable(kegg_res, OrgDb = org.Hs.eg.db, keyType = "ENTREZID")
  }
  kegg_df <- as.data.frame(kegg_res)
  cat(sprintf("[INFO] Identified %d significantly enriched KEGG pathways.\n", nrow(kegg_df)))
  
  # 1. KEGG Barplot
  pdf(file.path(opt$outdir, "KEGG_barplot.pdf"), width = 9, height = 6)
  print(barplot(kegg_res, showCategory = opt$show_category, title = "KEGG Pathway Enrichment"))
  dev.off()
  
  # 2. KEGG Dotplot
  pdf(file.path(opt$outdir, "KEGG_dotplot.pdf"), width = 9, height = 6)
  print(dotplot(kegg_res, showCategory = opt$show_category, title = "KEGG Pathway Enrichment"))
  dev.off()
  
  # 3. KEGG Cnetplot (Gene-Concept Network)
  tryCatch({
    pdf(file.path(opt$outdir, "KEGG_cnetplot.pdf"), width = 10, height = 8)
    if (!is.null(gene_fc_vec)) {
      print(cnetplot(kegg_res, showCategory = 5, foldChange = gene_fc_vec,
                     colorEdge = TRUE, circular = FALSE))
    } else {
      print(cnetplot(kegg_res, showCategory = 5, colorEdge = TRUE, circular = FALSE))
    }
    dev.off()
  }, error = function(e) {
    cat(sprintf("[WARN] cnetplot failed: %s\n", e$message))
  })
} else {
  cat("[WARN] No KEGG pathways reached significant threshold.\n")
}

# Export KEGG enrichment results table
kegg_out_file <- file.path(opt$outdir, "KEGG_enrichment.csv")
cat(sprintf("[INFO] Exporting KEGG enrichment table to %s (%d pathways)\n", kegg_out_file, nrow(kegg_df)))
write.csv(kegg_df, file = kegg_out_file, row.names = FALSE, quote = TRUE)

cat("[SUCCESS] Stage 05 Functional Enrichment completed successfully.\n")
