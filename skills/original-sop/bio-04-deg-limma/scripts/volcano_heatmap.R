#!/usr/bin/env Rscript
# ==============================================================================

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)
# Pipeline Stage: bio-04-deg-limma
# Script: volcano_heatmap.R
# Description: Generates publication-quality volcano plots using ggplot2 and ggrepel:
#              distinguishes significantly upregulated, downregulated, and non-significant genes,
#              labels top candidate genes, and exports to vol.pdf.
# Reproducibility: set.seed(12345)
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(ggrepel)
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
  metadata = "",
  manifest = "",
  source_revision = "",
  logfc = "1.0",
  fdr = "0.05",
  top_n = "10",                              # Number of top genes to label per direction
  outdir = ".",
  output = "vol.pdf"
)

opt <- parse_args(defaults)
opt$logfc <- as.numeric(opt$logfc)
opt$fdr <- as.numeric(opt$fdr)
opt$top_n <- as.integer(opt$top_n)

if (!nzchar(opt$input) || !nzchar(opt$metadata) || !nzchar(opt$manifest)) {
  contract_stop("--input, --metadata, and --manifest are required for the volcano substep")
}
opt$input <- assert_explicit_path(opt$input, "differential result table", must_exist = TRUE)
opt$metadata <- assert_explicit_path(opt$metadata, "sample metadata", must_exist = TRUE)
opt$manifest <- assert_explicit_path(opt$manifest, "manifest", must_exist = TRUE)
manifest <- validate_manifest_context(
  opt$manifest,
  source_revision = if (nzchar(opt$source_revision)) opt$source_revision else NULL,
  metadata_path = opt$metadata
)
metadata_contract <- read_metadata_contract(opt$metadata)

if (!dir.exists(opt$outdir)) {
  dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)
}

cat("[INFO] Starting Volcano Plot Generation\n")
cat(sprintf("[INFO] Input file: %s\n", opt$input))
cat(sprintf("[INFO] Thresholds: |logFC| >= %.2f, FDR < %.4f\n", opt$logfc, opt$fdr))

# ------------------------------------------------------------------------------
# Step 1: Read Differential Analysis Results
# ------------------------------------------------------------------------------
if (!file.exists(opt$input)) {
  stop(sprintf("[ERROR] Differential results file not found: %s", opt$input))
}

rt <- read.table(opt$input, header = TRUE, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)

# Resolve gene ID column
gene_col <- if ("id" %in% colnames(rt)) "id" else {
  sym_cands <- grep("symbol|gene|id", colnames(rt), ignore.case = TRUE, value = TRUE)
  if (length(sym_cands) > 0) sym_cands[1] else colnames(rt)[1]
}
rt$Gene <- as.character(rt[[gene_col]])

# ------------------------------------------------------------------------------
# Step 2: Classify Regulation Status
# ------------------------------------------------------------------------------
rt$Status <- "Not"
up_idx <- (rt$adj.P.Val < opt$fdr) & (rt$logFC >= opt$logfc)
down_idx <- (rt$adj.P.Val < opt$fdr) & (rt$logFC <= -opt$logfc)

rt$Status[up_idx] <- "Up"
rt$Status[down_idx] <- "Down"
rt$Status <- factor(rt$Status, levels = c("Up", "Down", "Not"))

up_count <- sum(up_idx)
down_count <- sum(down_idx)
cat(sprintf("[INFO] Classification: %d Upregulated, %d Downregulated, %d Not Significant\n",
            up_count, down_count, nrow(rt) - up_count - down_count))

# Transform p-values for y-axis
rt$negLog10P <- -log10(rt$adj.P.Val)
# Replace Inf or extreme values with a finite maximum
max_finite <- max(rt$negLog10P[is.finite(rt$negLog10P)], na.rm = TRUE)
rt$negLog10P[!is.finite(rt$negLog10P)] <- max_finite + 2

# ------------------------------------------------------------------------------
# Step 3: Identify Top Genes for Labeling
# ------------------------------------------------------------------------------
top_up_genes <- rt %>%
  filter(Status == "Up") %>%
  arrange(adj.P.Val, desc(abs(logFC))) %>%
  head(opt$top_n)

top_down_genes <- rt %>%
  filter(Status == "Down") %>%
  arrange(adj.P.Val, desc(abs(logFC))) %>%
  head(opt$top_n)

labeled_genes <- rbind(top_up_genes, top_down_genes)

# ------------------------------------------------------------------------------
# Step 4: Build Volcano Plot with ggplot2
# ------------------------------------------------------------------------------
y_cutoff <- -log10(opt$fdr)

color_palette <- c(
  "Up" = "#DC0000",       # Red
  "Down" = "#3C5488",     # Blue
  "Not" = "#999999"       # Grey
)

p <- ggplot(rt, aes(x = logFC, y = negLog10P)) +
  geom_point(aes(color = Status), alpha = 0.65, size = 1.6) +
  scale_color_manual(
    values = color_palette,
    labels = c(
      sprintf("Up (%d)", up_count),
      sprintf("Down (%d)", down_count),
      "Not Significant"
    )
  ) +
  geom_vline(xintercept = c(-opt$logfc, opt$logfc), linetype = "dashed", color = "darkgrey", linewidth = 0.6) +
  geom_hline(yintercept = y_cutoff, linetype = "dashed", color = "darkgrey", linewidth = 0.6) +
  labs(
    title = "Differential Expression Volcano Plot",
    subtitle = sprintf("Thresholds: |log2FC| >= %.1f, FDR < %.2f", opt$logfc, opt$fdr),
    x = expression(Log[2]~Fold~Change),
    y = expression(-Log[10]~(Adjusted~italic(P)-value)),
    color = "Regulation"
  ) +
  theme_bw(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "dimgray"),
    legend.position = "right",
    legend.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

# Add repelled text labels for top genes
if (nrow(labeled_genes) > 0) {
  p <- p + geom_label_repel(
    data = labeled_genes,
    aes(label = Gene),
    size = 2.8,
    box.padding = 0.35,
    point.padding = 0.25,
    segment.color = "grey50",
    segment.size = 0.4,
    max.overlaps = 25,
    show.legend = FALSE
  )
}

# ------------------------------------------------------------------------------
# Step 5: Export to PDF
# ------------------------------------------------------------------------------
out_pdf_path <- file.path(opt$outdir, opt$output)
cat(sprintf("[INFO] Exporting volcano plot to %s\n", out_pdf_path))
pdf(out_pdf_path, width = 7.5, height = 6.5)
print(p)
dev.off()

cat(sprintf("[SUCCESS] Volcano plot generation completed: %s\n", out_pdf_path))

write_stage_status(
  manifest,
  "bio-04-deg-limma-volcano",
  "success",
  "volcano diagnostic rendered from the declared differential result table",
  commandArgs(trailingOnly = FALSE),
  c(opt$input, opt$metadata),
  out_pdf_path,
  metadata_contract$sample_id,
  status_path = file.path(opt$outdir, "status", "bio-04-deg-limma-volcano.json"),
  exit_code = 0
)
