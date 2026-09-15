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

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

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
        key <- gsub("-", "_", sub("=.*$", "", key_val))
        res[[key]] <- sub("^[^=]*=", "", key_val)
      } else if (i + 1 <= length(args) && !grepl("^--", args[i + 1])) {
        res[[gsub("-", "_", key_val)]] <- args[i + 1]
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
  input = "",
  species = "",                             # Must be explicit and agree with metadata
  id_type = "",                             # Must be explicit and agree with metadata
  universe = "",                            # Detected-gene universe, explicit path
  org_db = "org.Hs.eg.db",
  metadata = "",                            # Canonical sample metadata CSV/TSV
  manifest = "",                            # Run manifest JSON
  source_revision = "",
  p_cutoff = "0.05",
  q_cutoff = "0.05",
  show_category = "15",
  outdir = "."
)

opt <- parse_args(defaults)
opt$p_cutoff <- as.numeric(opt$p_cutoff)
opt$q_cutoff <- as.numeric(opt$q_cutoff)
opt$show_category <- as.integer(opt$show_category)

if (!nzchar(opt$input) || !nzchar(opt$species) || !nzchar(opt$id_type) ||
    !nzchar(opt$universe) || !nzchar(opt$metadata) || !nzchar(opt$manifest)) {
  contract_stop("--input, --species, --id-type, --universe, --metadata, and --manifest are required")
}
opt$input <- assert_explicit_path(opt$input, "enrichment input", must_exist = TRUE)
opt$universe <- assert_explicit_path(opt$universe, "detected-gene universe", must_exist = TRUE)
opt$metadata <- assert_explicit_path(opt$metadata, "sample metadata", must_exist = TRUE)
opt$manifest <- assert_explicit_path(opt$manifest, "manifest", must_exist = TRUE)
manifest <- validate_manifest_context(
  opt$manifest,
  source_revision = if (nzchar(opt$source_revision)) opt$source_revision else NULL,
  metadata_path = opt$metadata
)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting Functional Enrichment Analysis (clusterProfiler)\n")
cat(sprintf("[INFO] Input gene file: %s\n", opt$input))
cat(sprintf("[INFO] Target species: %s\n", opt$species))

# ------------------------------------------------------------------------------
# Step 1: Read Input Gene List & LogFC Values
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) contract_stop(sprintf("enrichment input not found: %s", opt$input))

species_key <- tolower(trimws(opt$species))
if (grepl("human|hsa|homo sapiens", species_key)) {
  expected_species <- "Homo sapiens"
  kegg_organism <- "hsa"
} else if (grepl("pae|pseudomonas|pa01|pao1", species_key)) {
  expected_species <- "Pseudomonas aeruginosa"
  kegg_organism <- "pae"
} else {
  contract_stop(sprintf("unknown_species: '%s' has no declared annotation mapping", opt$species))
}
metadata_contract <- read_metadata_contract(opt$metadata, expected_species = expected_species)
metadata_id_types <- unique(tolower(metadata_contract$id_type))
if (length(metadata_id_types) != 1 || !identical(metadata_id_types[[1]], tolower(trimws(opt$id_type)))) {
  contract_stop("id_type_mismatch: enrichment id type must match canonical metadata")
}

read_gene_vector <- function(file_path, label) {
  lines <- readLines(file_path, warn = FALSE)
  if (length(lines) == 0) contract_stop(sprintf("%s is empty", label))
  first <- trimws(lines[[1]])
  has_header <- grepl("^(id|gene|symbol|ensembl|entrez)([[:space:],]|$)", first, ignore.case = TRUE)
  if (has_header) {
    sep <- if (grepl(",", first, fixed = TRUE)) "," else "\t"
    tab <- if (sep == ",") read.csv(file_path, header = TRUE, check.names = FALSE, stringsAsFactors = FALSE) else read.table(file_path, header = TRUE, sep = sep, quote = "", check.names = FALSE, stringsAsFactors = FALSE)
    candidates <- intersect(c("id", "gene", "symbol", "Gene", "Symbol", "ENSEMBL", "ENTREZID"), colnames(tab))
    col <- if (length(candidates) > 0) candidates[[1]] else colnames(tab)[[1]]
    values <- as.character(tab[[col]])
  } else {
    values <- trimws(gsub("[\\\"']", "", lines))
  }
  values <- unique(values[!is.na(values) & nzchar(values) & values != "---"])
  if (length(values) == 0) contract_stop(sprintf("%s contains no usable identifiers", label))
  values
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

universe_symbols <- read_gene_vector(opt$universe, "detected-gene universe")
if (!all(gene_symbols %in% universe_symbols)) {
  missing_from_universe <- setdiff(gene_symbols, universe_symbols)
  contract_stop(sprintf("input_universe_mismatch: %d input identifiers are absent from detected-gene universe", length(missing_from_universe)))
}

# ------------------------------------------------------------------------------
# Step 2: Species Resolution & Gene Identifier Conversion
# ------------------------------------------------------------------------------
is_human <- identical(kegg_organism, "hsa")
is_pae <- identical(kegg_organism, "pae")

entrez_ids <- c()
universe_ids <- c()

from_type <- switch(
  tolower(trimws(opt$id_type)),
  symbol = "SYMBOL",
  gene_symbol = "SYMBOL",
  ensembl = "ENSEMBL",
  ensembl_gene_id = "ENSEMBL",
  entrez = "ENTREZID",
  entrezid = "ENTREZID",
  contract_stop(sprintf("unsupported_id_type: '%s'", opt$id_type))
)

if (is_human) {
  cat("[INFO] Loading human annotation database (org.Hs.eg.db)...\n")
  if (!requireNamespace("org.Hs.eg.db", quietly = TRUE)) {
    stop("[ERROR] R package 'org.Hs.eg.db' is required for human GO analysis.")
  }
  library(org.Hs.eg.db)

  safe_bitr <- function(ids, from_type, failure_reason) {
    tryCatch(
      bitr(ids, fromType = from_type, toType = "ENTREZID", OrgDb = org.Hs.eg.db),
      error = function(error) {
        contract_stop(sprintf("%s: annotation conversion failed: %s", failure_reason, conditionMessage(error)))
      }
    )
  }
  
  cat(sprintf("[INFO] Converting %s identifiers to ENTREZ IDs via bitr()...\n", from_type))
  id_map <- if (from_type == "ENTREZID") data.frame(ENTREZID = gene_symbols, stringsAsFactors = FALSE) else safe_bitr(gene_symbols, from_type, "unmapped_input")
  universe_map <- if (from_type == "ENTREZID") data.frame(ENTREZID = universe_symbols, stringsAsFactors = FALSE) else safe_bitr(universe_symbols, from_type, "universe_mapping_failed")
  entrez_ids <- unique(id_map$ENTREZID)
  universe_ids <- unique(universe_map$ENTREZID)
  cat(sprintf("[INFO] Successfully mapped %d / %d symbols to Entrez IDs.\n", length(entrez_ids), length(gene_symbols)))
  if (length(entrez_ids) == 0) {
    contract_stop("unmapped_input: zero input identifiers mapped to the declared species")
  }
  if (length(universe_ids) == 0 || !all(entrez_ids %in% universe_ids)) {
    contract_stop("universe_mapping_failed: detected-gene universe cannot explain all input identifiers")
  }
  
  if (!is.null(gene_fc_vec)) {
    mapping_keys <- as.character(id_map[[from_type]])
    fc_matched <- gene_fc_vec[mapping_keys]
    names(fc_matched) <- id_map$ENTREZID
    gene_fc_vec <- fc_matched[!is.na(names(fc_matched))]
  }
} else if (is_pae) {
  cat("[INFO] Pseudomonas aeruginosa PAO1 detected. Using declared identifiers for KEGG organism 'pae'.\n")
  entrez_ids <- gene_symbols
  universe_ids <- universe_symbols
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
      universe = universe_ids,
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
  cat("[WARN] Non-human organism specified. GO enrichment requires a dedicated OrgDb which is not loaded; skipping GO with explicit notice (no silent gap). Checking KEGG only.\n")
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
    universe = universe_ids,
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

enrichment_status <- if (nrow(go_df_all) > 0 || nrow(kegg_df) > 0) "success" else "negative"
enrichment_reason <- if (enrichment_status == "success") {
  "enrichment completed over the detected-gene universe"
} else {
  "no GO or KEGG term passed the declared thresholds; preserving a negative result"
}
cat(sprintf("[%s] Stage 05 Functional Enrichment completed: %s.\n", toupper(enrichment_status), enrichment_reason))

if (exists("write_stage_status") && nzchar(opt$manifest)) {
  write_stage_status(
    manifest,
    "bio-05-enrichment",
    enrichment_status,
    enrichment_reason,
    commandArgs(trailingOnly = FALSE),
    c(opt$input, opt$universe, opt$metadata),
    c(go_out_file, kegg_out_file),
    metadata_contract$sample_id,
    status_path = file.path(opt$outdir, "status", "bio-05-enrichment.json"),
    exit_code = 0
  )
}
