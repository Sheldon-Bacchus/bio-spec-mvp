#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-03-wgcna
# Script: wgcna_module_export.R
# Description: Calculates Module Membership (MM) and Gene Significance (GS),
#              generates MM vs GS scatterplot diagnostics, and exports
#              geneInfo.csv, module_genes.csv, and candidate hub gene lists.
# Reproducibility: set.seed(12345)
tryCatch({ disableWGCNAThreads() }, error = function(e) NULL)
# ==============================================================================

suppressPackageStartupMessages({
  library(WGCNA)
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
        key <- gsub("-", "_", parts[1])
        res[[key]] <- parts[2]
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
  rdata = "wgcna_net.RData",
  module = "auto",                           # "auto" or specific color e.g. "brown"
  trait = "",                                # Trait column name (e.g. "biofilm" or first column)
  mm_cutoff = "0.80",
  gs_cutoff = "0.20",
  outdir = "."
)

opt <- parse_args(defaults)
opt$mm_cutoff <- as.numeric(opt$mm_cutoff)
opt$gs_cutoff <- as.numeric(opt$gs_cutoff)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting WGCNA Module Analysis & Hub Gene Export\n")
cat(sprintf("[INFO] Loading workspace: %s\n", opt$rdata))

if (!file.exists(opt$rdata)) {
  stop(sprintf("[ERROR] RData file not found: %s", opt$rdata))
}

load(opt$rdata)

nSamples <- nrow(datExpr)
nGenes <- ncol(datExpr)

# ------------------------------------------------------------------------------
# Step 1: Resolve Target Trait Vector
# ------------------------------------------------------------------------------
if (nchar(opt$trait) > 0 && opt$trait %in% colnames(trait_df)) {
  target_trait_name <- opt$trait
} else {
  # Look for 'biofilm' or 'treat' or take first trait column
  cands <- grep("biofilm|treat|case", colnames(trait_df), ignore.case = TRUE, value = TRUE)
  target_trait_name <- if (length(cands) > 0) cands[1] else colnames(trait_df)[1]
}

cat(sprintf("[INFO] Target clinical trait: '%s'\n", target_trait_name))
target_trait_vec <- as.data.frame(trait_df[, target_trait_name, drop = FALSE])
colnames(target_trait_vec) <- target_trait_name

# ------------------------------------------------------------------------------
# Step 2: Compute Module Membership (MM) and Gene Significance (GS)
# ------------------------------------------------------------------------------
cat("[INFO] Computing Gene Module Membership (MM) across all modules...\n")
modNames <- substring(names(MEs), 3) # Strip "ME" prefix

geneModuleMembership <- as.data.frame(cor(datExpr, MEs, use = "p"))
MMPvalue <- as.data.frame(corPvalueStudent(as.matrix(geneModuleMembership), nSamples))

names(geneModuleMembership) <- paste0("MM.", modNames)
names(MMPvalue) <- paste0("p.MM.", modNames)

cat("[INFO] Computing Gene Significance (GS) for target trait...\n")
geneTraitSignificance <- as.data.frame(cor(datExpr, target_trait_vec, use = "p"))
GSPvalue <- as.data.frame(corPvalueStudent(as.matrix(geneTraitSignificance), nSamples))

names(geneTraitSignificance) <- paste0("GS.", target_trait_name)
names(GSPvalue) <- paste0("p.GS.", target_trait_name)

# ------------------------------------------------------------------------------
# Step 3: Automatically Select or Validate Target Module
# ------------------------------------------------------------------------------
if (opt$module == "auto") {
  # Determine module with strongest absolute correlation to target trait (excluding grey)
  me_cor <- cor(MEs, target_trait_vec, use = "p")
  valid_mods <- rownames(me_cor)[!grepl("grey", rownames(me_cor), ignore.case = TRUE)]
  best_me <- valid_mods[which.max(abs(me_cor[valid_mods, 1]))]
  target_module <- substring(best_me, 3)
  cat(sprintf("[INFO] Automatically identified top-correlated module: '%s' (cor = %.3f)\n",
              target_module, me_cor[best_me, 1]))
} else {
  target_module <- opt$module
  cat(sprintf("[INFO] User-specified target module: '%s'\n", target_module))
}

if (!target_module %in% modNames) {
  stop(sprintf("[ERROR] Specified module '%s' not found in detected modules: %s",
               target_module, paste(modNames, collapse = ", ")))
}

# ------------------------------------------------------------------------------
# Step 4: Generate MM vs GS Diagnostic Scatterplot
# ------------------------------------------------------------------------------
mod_col_idx <- match(paste0("MM.", target_module), names(geneModuleMembership))
in_module <- (moduleColors == target_module)

scatter_pdf_path <- file.path(opt$outdir, sprintf("MM_vs_GS_%s.pdf", target_module))
cat(sprintf("[INFO] Generating MM vs GS scatterplot to %s\n", scatter_pdf_path))

pdf(scatter_pdf_path, width = 7, height = 7)
par(mfrow = c(1, 1), mar = c(5, 5, 4, 2))
verboseScatterplot(
  abs(geneModuleMembership[in_module, mod_col_idx]),
  abs(geneTraitSignificance[in_module, 1]),
  xlab = paste("Module Membership (MM) in", target_module, "module"),
  ylab = paste("Gene Significance (GS) for", target_trait_name),
  main = paste("Module membership vs. gene significance\n", target_module, "module"),
  cex.main = 1.2, cex.lab = 1.1, cex.axis = 1.0,
  col = target_module, pch = 20
)
abline(v = opt$mm_cutoff, col = "darkgrey", lty = 2)
abline(h = opt$gs_cutoff, col = "darkgrey", lty = 2)
dev.off()

# ------------------------------------------------------------------------------
# Step 5: Export Global Gene Information Table (geneInfo.csv)
# ------------------------------------------------------------------------------
cat("[INFO] Assembling global geneInfo table...\n")
geneInfo0 <- data.frame(
  GeneSymbol = colnames(datExpr),
  moduleColor = moduleColors,
  geneTraitSignificance,
  GSPvalue,
  stringsAsFactors = FALSE
)

# Order modules by significance for trait
modOrder <- order(-abs(cor(MEs, target_trait_vec, use = "p")))

for (mod in seq_along(modOrder)) {
  m_idx <- modOrder[mod]
  old_names <- names(geneInfo0)
  geneInfo0 <- data.frame(
    geneInfo0,
    geneModuleMembership[, m_idx],
    MMPvalue[, m_idx],
    stringsAsFactors = FALSE
  )
  names(geneInfo0) <- c(old_names, names(geneModuleMembership)[m_idx], names(MMPvalue)[m_idx])
}

# Order genes by module color and target trait GS
gene_order <- order(geneInfo0$moduleColor, -abs(geneInfo0[[paste0("GS.", target_trait_name)]]))
geneInfo <- geneInfo0[gene_order, ]

gene_info_path <- file.path(opt$outdir, "geneInfo.csv")
cat(sprintf("[INFO] Exporting geneInfo table to %s\n", gene_info_path))
write.csv(geneInfo, file = gene_info_path, row.names = FALSE, quote = FALSE)

# ------------------------------------------------------------------------------
# Step 6: Export Module Genes & Candidate Hub Genes (module_genes.csv)
# ------------------------------------------------------------------------------
module_genes_df <- geneInfo[geneInfo$moduleColor == target_module, ]

# Annotate candidate hub genes meeting MM and GS criteria
mm_col <- paste0("MM.", target_module)
gs_col <- paste0("GS.", target_trait_name)

module_genes_df$is_hub <- (abs(module_genes_df[[mm_col]]) >= opt$mm_cutoff) &
                          (abs(module_genes_df[[gs_col]]) >= opt$gs_cutoff)

mod_genes_path <- file.path(opt$outdir, "module_genes.csv")
cat(sprintf("[INFO] Exporting %d genes for module '%s' to %s\n",
            nrow(module_genes_df), target_module, mod_genes_path))
write.csv(module_genes_df, file = mod_genes_path, row.names = FALSE, quote = FALSE)

# Export simple gene symbol list for Stage 06 intersection (Data contract)
hub_genes_path <- file.path(opt$outdir, "candidate_hub_genes_wgcna.txt")
write.table(module_genes_df$GeneSymbol, file = hub_genes_path,
            quote = FALSE, row.names = FALSE, col.names = FALSE)

cat(sprintf("[SUCCESS] Stage 03 Module Export complete. Found %d total genes, %d meeting hub criteria (|MM|>=%.2f, |GS|>=%.2f).\n",
            nrow(module_genes_df), sum(module_genes_df$is_hub), opt$mm_cutoff, opt$gs_cutoff))
