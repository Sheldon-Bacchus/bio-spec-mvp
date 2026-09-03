#!/usr/bin/env Rscript
# ==============================================================================
# Pipeline Stage: bio-03-wgcna
# Script: wgcna_build.R
# Description: Parameterized WGCNA network construction: top MAD gene filtering,
#              soft-thresholding power selection (R^2 > 0.85), blockwise module detection,
#              dendrogram visualization, and module-trait relationship heatmap.
# Reproducibility: set.seed(12345)
# ==============================================================================

suppressPackageStartupMessages({
  library(WGCNA)
})

# Allow WGCNA multithreading if supported
options(stringsAsFactors = FALSE)
tryCatch({
  enableWGCNAThreads()
}, error = function(e) {
  cat("[INFO] Multithreading not enabled, running single-threaded.\n")
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
  input = "merge.normalize.txt",
  clinic = "clinic.csv",
  n_genes = "5000",
  r2_cutoff = "0.85",
  max_block_size = "6000",
  min_module_size = "30",
  merge_cut_height = "0.25",
  outdir = "."
)

opt <- parse_args(defaults)
opt$n_genes <- as.integer(opt$n_genes)
opt$r2_cutoff <- as.numeric(opt$r2_cutoff)
opt$max_block_size <- as.integer(opt$max_block_size)
opt$min_module_size <- as.integer(opt$min_module_size)
opt$merge_cut_height <- as.numeric(opt$merge_cut_height)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting WGCNA Network Construction\n")
cat(sprintf("[INFO] Input matrix: %s\n", opt$input))
cat(sprintf("[INFO] Trait file: %s\n", opt$clinic))

# ------------------------------------------------------------------------------
# Step 1: Read Expression Matrix & Top MAD Gene Selection
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) {
  stop(sprintf("[ERROR] Input matrix not found: %s", opt$input))
}

# Support both tab-delimited TXT and CSV
exp_df <- if (grepl("\\.csv$", opt$input, ignore.case = TRUE)) {
  read.csv(opt$input, header = TRUE, row.names = 1, check.names = FALSE)
} else {
  read.table(opt$input, header = TRUE, sep = "\t", row.names = 1, check.names = FALSE, quote = "")
}

raw_mat <- as.matrix(exp_df)
mode(raw_mat) <- "numeric"
cat(sprintf("[INFO] Loaded expression matrix: %d genes across %d samples\n", nrow(raw_mat), ncol(raw_mat)))

# Check for genes with zero variance or all NAs
gsg <- goodSamplesGenes(t(raw_mat), verbose = 3)
if (!gsg$allOK) {
  cat("[WARN] Removing outlier samples/genes detected by goodSamplesGenes...\n")
  raw_mat <- raw_mat[gsg$goodGenes, gsg$goodSamples]
}

# Filter top MAD (Median Absolute Deviation) genes
n_select <- min(opt$n_genes, nrow(raw_mat))
cat(sprintf("[INFO] Selecting top %d genes ranked by MAD...\n", n_select))
mad_values <- apply(raw_mat, 1, mad, na.rm = TRUE)
top_idx <- order(mad_values, decreasing = TRUE)[1:n_select]
filtered_mat <- raw_mat[top_idx, ]

# Transpose matrix for WGCNA (rows = samples, columns = genes)
datExpr <- t(filtered_mat)
cat(sprintf("[INFO] Transposed WGCNA matrix: %d samples, %d genes\n", nrow(datExpr), ncol(datExpr)))

# ------------------------------------------------------------------------------
# Step 2: Read Phenotype Metadata (clinic.csv) & Align Samples
# ------------------------------------------------------------------------------
if (!file.exists(opt$clinic)) {
  stop(sprintf("[ERROR] Trait metadata file not found: %s", opt$clinic))
}

datTraits_raw <- read.csv(opt$clinic, header = TRUE, stringsAsFactors = FALSE)
sample_col <- if ("sample" %in% colnames(datTraits_raw)) "sample" else colnames(datTraits_raw)[1]

# Align sample names
sample_names <- rownames(datExpr)
trait_match <- match(sample_names, datTraits_raw[[sample_col]])

if (any(is.na(trait_match))) {
  # Try matching without prefix
  stripped <- sub("^[^_]+_", "", sample_names)
  trait_match <- match(stripped, datTraits_raw[[sample_col]])
}

if (all(is.na(trait_match))) {
  stop("[ERROR] Sample names in datExpr and clinic.csv do not match at all.")
}

datTraits <- datTraits_raw[trait_match, , drop = FALSE]
rownames(datTraits) <- sample_names

# Construct design / numerical trait matrix
trait_cols <- setdiff(colnames(datTraits), sample_col)
numeric_traits <- list()

for (col_name in trait_cols) {
  val <- datTraits[[col_name]]
  if (is.numeric(val)) {
    numeric_traits[[col_name]] <- val
  } else {
    # Convert binary/factor column to dummy 0/1
    fac <- as.factor(val)
    if (length(levels(fac)) == 2) {
      numeric_traits[[col_name]] <- as.numeric(fac) - 1
    } else {
      # Multi-level factor: expand to model matrix
      mm <- model.matrix(~ 0 + fac)
      colnames(mm) <- levels(fac)
      for (lvl in colnames(mm)) {
        numeric_traits[[paste0(col_name, "_", lvl)]] <- mm[, lvl]
      }
    }
  }
}
trait_df <- as.data.frame(numeric_traits)
rownames(trait_df) <- sample_names

# ------------------------------------------------------------------------------
# Step 3: Soft-Thresholding Power Selection (pickSoftThreshold)
# ------------------------------------------------------------------------------
cat("[INFO] Calculating scale-free topology fit across power range...\n")
powers <- c(1:10, seq(from = 12, to = 20, by = 2))
sft <- pickSoftThreshold(datExpr, powerVector = powers, verbose = 5)

# Automatic power determination
selected_power <- sft$powerEstimate

if (is.na(selected_power)) {
  cat(sprintf("[WARN] pickSoftThreshold did not hit R^2 > %.2f cutoff automatically.\n", opt$r2_cutoff))
  # Search for lowest power achieving R^2 > 0.80, or fallback to highest R^2
  r2_values <- -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2]
  idx_pass <- which(r2_values >= 0.80)
  if (length(idx_pass) > 0) {
    selected_power <- powers[min(idx_pass)]
    cat(sprintf("[INFO] Selected power %d achieving R^2 >= 0.80.\n", selected_power))
  } else {
    selected_power <- powers[which.max(r2_values)]
    cat(sprintf("[WARN] Fallback: Selected power %d with maximum R^2 = %.2f.\n", selected_power, max(r2_values)))
  }
} else {
  cat(sprintf("[INFO] Automatically selected optimal soft-thresholding power: %d\n", selected_power))
}

# Plot Soft Threshold Diagnostics
soft_pdf_path <- file.path(opt$outdir, "softThreshold.pdf")
cat(sprintf("[INFO] Exporting soft-thresholding curves to %s\n", soft_pdf_path))
pdf(soft_pdf_path, width = 10, height = 5)
par(mfrow = c(1, 2))
cex1 <- 0.9

# Scale independence plot
plot(sft$fitIndices[, 1], -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2],
     xlab = "Soft Threshold (power)", ylab = "Scale Free Topology Model Fit, signed R^2",
     type = "n", main = "Scale Independence")
text(sft$fitIndices[, 1], -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2],
     labels = powers, cex = cex1, col = "red")
abline(h = opt$r2_cutoff, col = "red", lty = 2)

# Mean connectivity plot
plot(sft$fitIndices[, 1], sft$fitIndices[, 5],
     xlab = "Soft Threshold (power)", ylab = "Mean Connectivity",
     type = "n", main = "Mean Connectivity")
text(sft$fitIndices[, 1], sft$fitIndices[, 5], labels = powers, cex = cex1, col = "red")
dev.off()

# ------------------------------------------------------------------------------
# Step 4: Network Construction & Module Detection (blockwiseModules)
# ------------------------------------------------------------------------------
cat(sprintf("[INFO] Building network via blockwiseModules (power=%d, minModuleSize=%d, mergeCutHeight=%.2f)...\n",
            selected_power, opt$min_module_size, opt$merge_cut_height))

net <- blockwiseModules(
  datExpr,
  power = selected_power,
  maxBlockSize = opt$max_block_size,
  TOMType = "unsigned",
  minModuleSize = opt$min_module_size,
  reassignThreshold = 0,
  mergeCutHeight = opt$merge_cut_height,
  numericLabels = TRUE,
  pamRespectsDendro = FALSE,
  saveTOMs = FALSE,
  verbose = 3
)

cat("[INFO] Identified module distribution (numeric):\n")
print(table(net$colors))

# Convert numeric labels to module colors
moduleColors <- labels2colors(net$colors)
cat("[INFO] Identified module distribution (colors):\n")
print(table(moduleColors))

# Export Module Dendrogram
dendro_pdf_path <- file.path(opt$outdir, "moduleDendrogram.pdf")
cat(sprintf("[INFO] Exporting module dendrogram to %s\n", dendro_pdf_path))
pdf(dendro_pdf_path, width = 10, height = 6)
plotDendroAndColors(
  net$dendrograms[[1]],
  moduleColors[net$blockGenes[[1]]],
  "Module colors",
  dendroLabels = FALSE,
  hang = 0.03,
  addGuide = TRUE,
  guideHang = 0.05,
  main = "Cluster Dendrogram and Co-expression Modules"
)
dev.off()

# ------------------------------------------------------------------------------
# Step 5: Module-Trait Relationships & Heatmap
# ------------------------------------------------------------------------------
cat("[INFO] Calculating Module Eigengenes (MEs) and trait correlations...\n")
MEs0 <- moduleEigengenes(datExpr, moduleColors)$eigengenes
MEs <- orderMEs(MEs0)

# Correlate MEs with phenotypic traits
nSamples <- nrow(datExpr)
moduleTraitCor <- cor(MEs, trait_df, use = "p")
moduleTraitPvalue <- corPvalueStudent(moduleTraitCor, nSamples)

# Format label text matrix
textMatrix <- paste0(signif(moduleTraitCor, 2), "\n(p=", signif(moduleTraitPvalue, 1), ")")
dim(textMatrix) <- dim(moduleTraitCor)

heatmap_pdf_path <- file.path(opt$outdir, "module_trait_heatmap.pdf")
cat(sprintf("[INFO] Exporting module-trait correlation heatmap to %s\n", heatmap_pdf_path))

pdf(heatmap_pdf_path, width = max(7, ncol(trait_df) * 2), height = max(7, ncol(MEs) * 0.5))
par(mar = c(6, 9, 3, 3))
labeledHeatmap(
  Matrix = moduleTraitCor,
  xLabels = colnames(trait_df),
  yLabels = names(MEs),
  ySymbols = names(MEs),
  colorLabels = FALSE,
  colors = blueWhiteRed(50),
  textMatrix = textMatrix,
  setStdMargins = FALSE,
  cex.text = 0.65,
  zlim = c(-1, 1),
  main = "Module-Trait Relationships"
)
dev.off()

# ------------------------------------------------------------------------------
# Step 6: Save Environment for Downstream Module Export
# ------------------------------------------------------------------------------
rdata_path <- file.path(opt$outdir, "wgcna_net.RData")
cat(sprintf("[INFO] Saving WGCNA workspace to %s\n", rdata_path))
save(datExpr, datTraits, trait_df, net, MEs, moduleColors, sft, selected_power,
     file = rdata_path)

cat("[SUCCESS] Stage 03 WGCNA network construction completed successfully.\n")
