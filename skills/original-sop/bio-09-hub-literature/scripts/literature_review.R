#!/usr/bin/env Rscript
# Contract-only literature evidence step for the original-sop pipeline.
# It records an explicit skipped state when no eligible evidence call has been
# authorized or exposed; it never fabricates supporting citations.

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(dirname(dirname(script_dir)), "bio-pipeline-orchestrator", "scripts", "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

parse_args <- function(defaults) {
  args <- commandArgs(trailingOnly = TRUE)
  result <- defaults
  for (arg in args) {
    if (grepl("^--", arg) && grepl("=", arg, fixed = TRUE)) {
      parts <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1]]
      result[[gsub("-", "_", parts[[1]])]] <- sub("^[^=]*=", "", sub("^--", "", arg))
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript literature_review.R --hub=<path> --metadata=<path> --manifest=<path> --output-dir=<dir>\n")
      quit(status = 0)
    }
  }
  result
}

params <- parse_args(list(
  hub = "",
  metadata = "",
  manifest = "",
  source_revision = "",
  output_dir = ".",
  output = "literature_evidence_report.md"
))

if (!nzchar(params$hub) || !nzchar(params$metadata) || !nzchar(params$manifest)) {
  contract_stop("--hub, --metadata, and --manifest are required for the literature evidence step")
}
params$hub <- assert_explicit_path(params$hub, "hub gene list", must_exist = TRUE)
params$metadata <- assert_explicit_path(params$metadata, "sample metadata", must_exist = TRUE)
params$manifest <- assert_explicit_path(params$manifest, "manifest", must_exist = TRUE)
manifest <- validate_manifest_context(
  params$manifest,
  source_revision = if (nzchar(params$source_revision)) params$source_revision else NULL,
  metadata_path = params$metadata
)
metadata_contract <- read_metadata_contract(params$metadata)
if (!dir.exists(params$output_dir)) dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)

hub_lines <- readLines(params$hub, warn = FALSE)
hub_genes <- unique(trimws(gsub("[\"']", "", hub_lines)))
hub_genes <- hub_genes[!is.na(hub_genes) & nzchar(hub_genes)]
report_path <- file.path(params$output_dir, params$output)
reason <- if (length(hub_genes) == 0) {
  "no hub genes were available; literature review was not applicable"
} else {
  "no eligible literature MCP call was made in this contract-only run; human review remains pending"
}
report_lines <- c(
  "# Literature Evidence Report",
  sprintf("run_id: %s", manifest$run_id),
  sprintf("source_revision: %s", manifest$source_revision),
  "status: skipped",
  sprintf("reason: %s", reason),
  sprintf("hub_gene_count: %d", length(hub_genes)),
  "source_ids: none",
  "manual_review: pending",
  "",
  "No supporting citation or biomedical interpretation claim is made by this artifact."
)
writeLines(report_lines, report_path)
write_stage_status(
  manifest,
  "bio-09-literature-review",
  "skipped",
  reason,
  commandArgs(trailingOnly = FALSE),
  c(params$hub, params$metadata),
  report_path,
  metadata_contract$sample_id,
  status_path = file.path(params$output_dir, "status", "bio-09-literature-review.json"),
  exit_code = 0
)
cat(sprintf("[SKIPPED] Literature evidence report recorded at %s.\n", report_path))
