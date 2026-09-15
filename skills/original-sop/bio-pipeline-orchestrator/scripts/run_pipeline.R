#!/usr/bin/env Rscript
# ============================================================================
# run_pipeline.R - Contract-first original-sop orchestrator
#
# Every stage receives explicit run-scoped paths, canonical metadata, and the
# immutable run manifest. A child failure or a failed content gate is recorded
# and propagated; --force never turns a failed gate into success.
# ============================================================================

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)) else getwd()
contract_helper <- Sys.getenv("BIO_PIPELINE_CONTRACT_HELPER", "")
if (!nzchar(contract_helper)) contract_helper <- file.path(script_dir, "contract_helpers.R")
if (!file.exists(contract_helper)) stop("[CONTRACT ERROR] contract_helpers.R not found", call. = FALSE)
source(contract_helper)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    project_dir = "",
    skills_dir = dirname(dirname(script_dir)),
    matrix = "",
    metadata = "",
    platform = "",
    control_group = "control",
    treat_group = "case",
    source_revision = "",
    run_id = "",
    manifest = "",
    start_stage = 1L,
    end_stage = 10L,
    dry_run = FALSE,
    force = FALSE,
    log_file = "pipeline_run.log",
    gate_report = "pipeline_gate_report.csv",
    report_json = "run-report.json"
  )
  for (arg in args) {
    if (grepl("^--project-dir=", arg)) params$project_dir <- sub("^--project-dir=", "", arg)
    else if (grepl("^--skills-dir=", arg)) params$skills_dir <- sub("^--skills-dir=", "", arg)
    else if (grepl("^--matrix=", arg)) params$matrix <- sub("^--matrix=", "", arg)
    else if (grepl("^--metadata=", arg)) params$metadata <- sub("^--metadata=", "", arg)
    else if (grepl("^--platform=", arg)) params$platform <- sub("^--platform=", "", arg)
    else if (grepl("^--control-group=", arg)) params$control_group <- sub("^--control-group=", "", arg)
    else if (grepl("^--treat-group=", arg)) params$treat_group <- sub("^--treat-group=", "", arg)
    else if (grepl("^--source-revision=", arg)) params$source_revision <- sub("^--source-revision=", "", arg)
    else if (grepl("^--run-id=", arg)) params$run_id <- sub("^--run-id=", "", arg)
    else if (grepl("^--manifest=", arg)) params$manifest <- sub("^--manifest=", "", arg)
    else if (grepl("^--start-stage=", arg)) params$start_stage <- as.integer(sub("^--start-stage=", "", arg))
    else if (grepl("^--end-stage=", arg)) params$end_stage <- as.integer(sub("^--end-stage=", "", arg))
    else if (arg == "--dry-run") params$dry_run <- TRUE
    else if (arg == "--force") params$force <- TRUE
    else if (grepl("^--log=", arg)) params$log_file <- sub("^--log=", "", arg)
    else if (grepl("^--report=", arg)) params$gate_report <- sub("^--report=", "", arg)
    else if (grepl("^--report-json=", arg)) params$report_json <- sub("^--report-json=", "", arg)
    else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript run_pipeline.R --project-dir=<run-dir> --matrix=<matrix> --metadata=<metadata> --source-revision=<commit> --run-id=<id>\n")
      cat("Required: explicit matrix, canonical metadata, source revision, and run ID.\n")
      cat("Optional: --platform=<annotation>, --start-stage=<int>, --end-stage=<int>, --dry-run.\n")
      quit(status = 0)
    }
  }
  params
}

log_msg <- function(level, message, log_path) {
  line <- sprintf("[%s] [%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), level, message)
  cat(line, "\n")
  cat(line, "\n", file = log_path, append = TRUE)
}

path_arg <- function(key, value) sprintf("--%s=%s", key, value)

stage_definitions <- function(params, metadata) {
  root <- normalizePath(params$skills_dir, winslash = "/", mustWork = TRUE)
  project <- params$project_dir
  manifest <- params$manifest
  matrix <- params$matrix
  metadata_path <- params$metadata
  norm <- file.path(project, sprintf("%s.normalize.txt", params$run_id))
  pd <- file.path(project, "PD.csv")
  prenorm <- file.path(project, "merge.preNorm.txt")
  corrected <- file.path(project, "merge.normalize.txt")
  pca <- file.path(project, "pca_qc.pdf")
  rdata <- file.path(project, "wgcna_net.RData")
  soft_threshold <- file.path(project, "softThreshold.pdf")
  module_dendrogram <- file.path(project, "moduleDendrogram.pdf")
  module_trait_heatmap <- file.path(project, "module_trait_heatmap.pdf")
  module_genes <- file.path(project, "module_genes.csv")
  diff <- file.path(project, "diff.txt")
  all_diff <- file.path(project, "all.txt")
  deg_list <- file.path(project, "candidate_hub_genes_deg.txt")
  heatmap <- file.path(project, "heatmap.pdf")
  volcano <- file.path(project, "vol.pdf")
  intersection <- file.path(project, "candidate_hub_genes.txt")
  lasso <- file.path(project, "LASSO.gene.txt")
  rf <- file.path(project, "rf_genes.txt")
  final_hub <- file.path(project, "final_hub_genes.txt")
  literature_report <- file.path(project, "literature_evidence_report.md")
  auc <- file.path(project, "auc_report.csv")
  roc_combined <- file.path(project, "roc_combined.pdf")
  stage <- function(number, id, scripts, inputs, outputs, args) {
    list(stage_num = number, id = id, scripts = scripts, inputs = inputs,
         outputs = outputs, args = args)
  }
  species <- as.character(metadata$species[[1]])
  id_type <- as.character(metadata$id_type[[1]])
  stage1_inputs <- c(matrix, metadata_path)
  if (nzchar(params$platform)) stage1_inputs <- c(stage1_inputs, params$platform)
  list(
    stage(1L, "bio-01-geo-dataprep",
          file.path(root, "bio-01-geo-dataprep", "scripts", "geo_preprocess.R"),
           stage1_inputs, c(norm, pd),
          list(c(path_arg("matrix", matrix), path_arg("metadata", metadata_path),
                 path_arg("manifest", manifest), path_arg("gse-id", params$run_id),
                 if (nzchar(params$platform)) path_arg("platform", params$platform) else character(),
                 path_arg("outdir", project), path_arg("source-revision", params$source_revision)))),
     stage(2L, "bio-02-batch-norm",
           c(file.path(root, "bio-02-batch-norm", "scripts", "sva_combat.R"),
             file.path(root, "bio-02-batch-norm", "scripts", "pca_qc.R")),
           c(norm, metadata_path), c(prenorm, corrected, file.path(project, "boxplot_comparison.pdf"), pca),
           list(c(path_arg("input-files", norm), path_arg("metadata", metadata_path),
                  path_arg("manifest", manifest), path_arg("outdir", project),
                  path_arg("source-revision", params$source_revision)),
                c(path_arg("input", corrected), path_arg("metadata", metadata_path),
                  path_arg("manifest", manifest), path_arg("outdir", project),
                  path_arg("source-revision", params$source_revision)))),
    stage(3L, "bio-03-wgcna",
          c(file.path(root, "bio-03-wgcna", "scripts", "wgcna_build.R"),
            file.path(root, "bio-03-wgcna", "scripts", "wgcna_module_export.R")),
           c(corrected, metadata_path), c(rdata, soft_threshold, module_dendrogram, module_trait_heatmap,
                                          module_genes, file.path(project, "geneInfo.csv"),
                                          file.path(project, "candidate_hub_genes_wgcna.txt")),
           list(c(path_arg("input", corrected), path_arg("metadata", metadata_path),
                  path_arg("manifest", manifest), path_arg("outdir", project),
                  path_arg("source-revision", params$source_revision)),
                c(path_arg("rdata", rdata), path_arg("metadata", metadata_path),
                 path_arg("manifest", manifest), path_arg("outdir", project),
                 path_arg("source-revision", params$source_revision), path_arg("trait", "group")))),
     stage(4L, "bio-04-deg-limma",
           c(file.path(root, "bio-04-deg-limma", "scripts", "limma_diff.R"),
             file.path(root, "bio-04-deg-limma", "scripts", "volcano_heatmap.R")),
           c(corrected, metadata_path), c(all_diff, diff, deg_list, heatmap, volcano),
           list(c(path_arg("input", corrected), path_arg("metadata", metadata_path),
                  path_arg("manifest", manifest), path_arg("outdir", project),
                  path_arg("source-revision", params$source_revision),
                  path_arg("control-group", params$control_group), path_arg("treat-group", params$treat_group)),
                c(path_arg("input", all_diff), path_arg("metadata", metadata_path),
                  path_arg("manifest", manifest), path_arg("outdir", project),
                  path_arg("source-revision", params$source_revision)))),
    stage(5L, "bio-05-enrichment",
          file.path(root, "bio-05-enrichment", "scripts", "enrichment_analysis.R"),
          c(diff, all_diff, metadata_path), c(file.path(project, "GO_enrichment.csv"), file.path(project, "KEGG_enrichment.csv")),
          list(c(path_arg("input", diff), path_arg("universe", all_diff), path_arg("species", species),
                 path_arg("id-type", id_type), path_arg("metadata", metadata_path), path_arg("manifest", manifest),
                 path_arg("outdir", project), path_arg("source-revision", params$source_revision)))),
    stage(6L, "bio-06-gene-intersection",
          file.path(root, "bio-06-gene-intersection", "scripts", "venn_intersection.R"),
          c(module_genes, deg_list), c(intersection, file.path(project, "venn_plot.pdf")),
          list(c(path_arg("wgcna", module_genes), path_arg("deg", deg_list), path_arg("manifest", manifest),
                 path_arg("output-dir", project), path_arg("source-revision", params$source_revision)))),
    stage(7L, "bio-07-ml-lasso",
          file.path(root, "bio-07-ml-lasso", "scripts", "lasso_regression.R"),
          c(corrected, metadata_path), c(lasso, file.path(project, "lasso_coefficients.csv")),
          list(c(path_arg("input", corrected), path_arg("metadata", metadata_path), path_arg("manifest", manifest),
                 path_arg("output-dir", project), path_arg("source-revision", params$source_revision)))),
    stage(8L, "bio-08-ml-randomforest",
          file.path(root, "bio-08-ml-randomforest", "scripts", "random_forest_importance.R"),
          c(corrected, metadata_path), c(rf, file.path(project, "richness.txt")),
          list(c(path_arg("input", corrected), path_arg("metadata", metadata_path), path_arg("manifest", manifest),
                 path_arg("output-dir", project), path_arg("source-revision", params$source_revision)))),
     stage(9L, "bio-09-hub-literature",
           c(file.path(root, "bio-09-hub-literature", "scripts", "hub_gene_intersection.R"),
             file.path(root, "bio-09-hub-literature", "scripts", "literature_review.R")),
           c(lasso, rf), c(final_hub, file.path(project, "hub_intersection_summary.txt"), literature_report),
           list(c(path_arg("lasso", lasso), path_arg("rf", rf), path_arg("manifest", manifest),
                  path_arg("output-dir", project), path_arg("source-revision", params$source_revision)),
                c(path_arg("hub", final_hub), path_arg("metadata", metadata_path), path_arg("manifest", manifest),
                  path_arg("output-dir", project), path_arg("source-revision", params$source_revision)))),
    stage(10L, "bio-10-biomarker-roc",
          file.path(root, "bio-10-biomarker-roc", "scripts", "roc_validation.R"),
           c(corrected, final_hub, metadata_path), c(auc, file.path(project, "roc_single_gene.pdf"), roc_combined),
          list(c(path_arg("expr", corrected), path_arg("hub", final_hub), path_arg("metadata", metadata_path),
                 path_arg("manifest", manifest), path_arg("output-dir", project),
                 path_arg("source-revision", params$source_revision))))
  )
}

content_gate <- function(stage, output_paths, project_dir) {
  missing <- output_paths[!file.exists(output_paths)]
  if (length(missing) > 0) return(list(status = "failure", reason = sprintf("missing declared outputs: %s", paste(basename(missing), collapse = ", "))))
  count_lines <- function(path) {
    if (!file.exists(path)) return(0L)
    lines <- readLines(path, warn = FALSE)
    sum(nzchar(trimws(lines)))
  }
  status <- "success"
  reason <- "declared outputs exist and content gate passed"
  if (stage$stage_num == 4L && count_lines(file.path(project_dir, "diff.txt")) <= 1L) {
    status <- "negative"; reason <- "no significant DEG passed the declared threshold"
  } else if (stage$stage_num == 5L && all(count_lines(output_paths) <= 1L)) {
    status <- "negative"; reason <- "no enrichment term passed the declared threshold"
  } else if (stage$stage_num == 6L && count_lines(file.path(project_dir, "candidate_hub_genes.txt")) == 0L) {
    status <- "negative"; reason <- "WGCNA/DEG intersection is empty; no union fallback"
  } else if (stage$stage_num == 7L && count_lines(file.path(project_dir, "LASSO.gene.txt")) == 0L) {
    status <- "negative"; reason <- "LASSO selected no genes; no top-N fallback"
  } else if (stage$stage_num == 8L && count_lines(file.path(project_dir, "rf_genes.txt")) == 0L) {
    status <- "negative"; reason <- "RF selected no significant genes; no top-N fallback"
  } else if (stage$stage_num == 9L && count_lines(file.path(project_dir, "final_hub_genes.txt")) == 0L) {
    status <- "negative"; reason <- "consensus hub intersection is empty; no union/copy fallback"
  } else if (stage$stage_num == 9L && file.exists(file.path(project_dir, "literature_evidence_report.md")) &&
             any(grepl("^status:\\s*skipped$", readLines(file.path(project_dir, "literature_evidence_report.md"), warn = FALSE)))) {
    status <- "manual_review"; reason <- "hub intersection computed, but literature evidence remains skipped pending an eligible evidence call/review"
  } else if (stage$stage_num == 10L) {
    auc_table <- tryCatch(read.csv(file.path(project_dir, "auc_report.csv"), stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(auc_table) || nrow(auc_table) == 0L) {
      status <- "negative"; reason <- "no valid independent-validation AUC was computed"
    } else {
      max_auc <- max(auc_table$AUC, na.rm = TRUE)
      if (!is.finite(max_auc) || max_auc < 0.70) {
        status <- "negative"; reason <- sprintf("independent-validation AUC did not meet threshold (max=%.3f)", max_auc)
      }
    }
  }
  list(status = status, reason = reason)
}

run_child <- function(script, args, log_path) {
  stdout_path <- tempfile("original-sop-stdout-")
  stderr_path <- tempfile("original-sop-stderr-")
  command_text <- paste(c("Rscript", shQuote(script), vapply(args, shQuote, character(1))), collapse = " ")
  system_args <- c(shQuote(script), vapply(args, shQuote, character(1)))
  code <- tryCatch(system2("Rscript", args = system_args, stdout = stdout_path, stderr = stderr_path), error = function(e) {
    writeLines(conditionMessage(e), stderr_path)
    127L
  })
  child_output <- c(if (file.exists(stdout_path)) readLines(stdout_path, warn = FALSE) else character(),
                    if (file.exists(stderr_path)) readLines(stderr_path, warn = FALSE) else character())
  if (length(child_output) > 0) cat(paste(child_output, collapse = "\n"), "\n", file = log_path, append = TRUE)
  unlink(c(stdout_path, stderr_path))
  list(code = as.integer(code), command = command_text, output = child_output)
}

main <- function() {
  params <- parse_args()
  if (!nzchar(params$project_dir) || !nzchar(params$matrix) || !nzchar(params$metadata) ||
      !nzchar(params$source_revision) || !nzchar(params$run_id)) {
    contract_stop("--project-dir, --matrix, --metadata, --source-revision, and --run-id are required")
  }
  if (!grepl("^[A-Za-z0-9._-]+$", params$run_id)) contract_stop("run-id contains unsupported characters")
  params$project_dir <- normalizePath(params$project_dir, winslash = "/", mustWork = FALSE)
  params$skills_dir <- normalizePath(params$skills_dir, winslash = "/", mustWork = TRUE)
  dir.create(params$project_dir, recursive = TRUE, showWarnings = FALSE)
  params$matrix <- assert_explicit_path(params$matrix, "expression matrix", must_exist = TRUE)
  params$metadata <- assert_explicit_path(params$metadata, "sample metadata", must_exist = TRUE)
  if (nzchar(params$platform)) params$platform <- assert_explicit_path(params$platform, "platform annotation", must_exist = TRUE)
  params$source_revision <- assert_scalar_text(params$source_revision, "source revision")
  params$control_group <- assert_scalar_text(params$control_group, "control group")
  params$treat_group <- assert_scalar_text(params$treat_group, "treat group")
  params$manifest <- if (nzchar(params$manifest)) normalizePath(params$manifest, winslash = "/", mustWork = FALSE) else file.path(params$project_dir, "run-manifest.json")
  if (file.exists(params$manifest)) contract_stop(sprintf("stale manifest already exists; use a new run directory: %s", params$manifest))
  metadata <- read_metadata_contract(params$metadata)
  matrix_values <- read_expression_matrix_contract(params$matrix, metadata)
  stages <- stage_definitions(params, metadata)
  output_candidates <- unique(unlist(lapply(stages, `[[`, "outputs")))
  existing_outputs <- output_candidates[file.exists(output_candidates)]
  if (length(existing_outputs) > 0) contract_stop(sprintf("stale output(s) already exist in run directory: %s", paste(basename(existing_outputs), collapse = ", ")))

  manifest <- list(
    run_id = params$run_id,
    source_revision = params$source_revision,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
     parameters = list(start_stage = params$start_stage, end_stage = params$end_stage, dry_run = params$dry_run,
                       control_group = params$control_group, treat_group = params$treat_group,
                       r_version = R.version.string, rscript = Sys.which("Rscript")),
    inputs = {
      input_records <- list(
      list(logical_name = "expression_matrix", path = params$matrix, sha256 = sha256_file(params$matrix),
           schema_version = "1.0.0", sample_ids = as.character(colnames(matrix_values))),
      list(logical_name = "sample_metadata", path = params$metadata, sha256 = sha256_file(params$metadata),
           schema_version = "1.0.0", sample_ids = as.character(metadata$sample_id))
      )
      if (nzchar(params$platform)) {
        input_records[[length(input_records) + 1L]] <- list(
          logical_name = "platform_annotation", path = params$platform, sha256 = sha256_file(params$platform),
          schema_version = "1.0.0", sample_ids = character()
        )
      }
      input_records
    },
    stages = lapply(stages, function(st) list(stage_id = st$id, order = st$stage_num, status = "skipped",
                                               reason = "not yet executed", inputs = as.character(st$inputs),
                                               outputs = as.character(st$outputs))),
    manual_changes = list()
  )
  attr(manifest, "input_sha256") <- vapply(manifest$inputs, function(item) item$sha256, character(1))
  dir.create(file.path(params$project_dir, "status"), recursive = TRUE, showWarnings = FALSE)
  write_json_contract(manifest, params$manifest)
  log_path <- file.path(params$project_dir, params$log_file)
  log_msg("INFO", sprintf("run_id=%s source_revision=%s", params$run_id, params$source_revision), log_path)
  if (isTRUE(params$force)) log_msg("WARN", "--force is accepted for compatibility but cannot bypass a failed contract gate", log_path)
  statuses <- list()
  halted <- FALSE
  for (st in stages) {
    if (st$stage_num < params$start_stage || st$stage_num > params$end_stage) next
    if (halted) {
      reason <- "skipped after an upstream failure/negative gate"
      record <- write_stage_status(manifest, st$id, "skipped", reason, character(), st$inputs, st$outputs,
                                   metadata$sample_id, status_path = file.path(params$project_dir, "status", paste0(st$id, ".json")), exit_code = 0)
      update_manifest_stage(params$manifest, st$id, "skipped", reason, st$inputs, st$outputs)
      statuses[[st$id]] <- record
      next
    }
    log_msg("STAGE", sprintf("begin %02d %s", st$stage_num, st$id), log_path)
    if (any(grepl("[{}]", c(st$inputs, st$outputs), perl = TRUE))) contract_stop(sprintf("placeholder in stage %s path", st$id))
    missing_scripts <- st$scripts[!file.exists(st$scripts)]
    if (length(missing_scripts) > 0) {
      status <- "failure"; reason <- sprintf("missing declared stage script(s): %s", paste(basename(missing_scripts), collapse = ", "))
      halted <- TRUE
      code <- 1L; command <- character()
    } else if (params$dry_run) {
      status <- "skipped"; reason <- "dry-run: execution intentionally not performed"
      code <- 0L; command <- character()
    } else if (length(st$inputs[!file.exists(st$inputs)]) > 0) {
      missing_inputs <- st$inputs[!file.exists(st$inputs)]
      status <- "failure"; reason <- sprintf("missing stage input(s): %s", paste(basename(missing_inputs), collapse = ", "))
      halted <- TRUE
      code <- 1L; command <- character()
    } else {
      script_results <- list(); code <- 0L; command <- character()
      for (idx in seq_along(st$scripts)) {
        if (!file.exists(st$scripts[[idx]])) {
          code <- 1L; reason <- sprintf("missing declared stage script: %s", st$scripts[[idx]]); break
        }
        result <- run_child(st$scripts[[idx]], st$args[[idx]], log_path)
        script_results[[idx]] <- result
        command <- c(command, result$command)
        if (result$code != 0L) {
          code <- result$code
          contract_lines <- grep("\\[CONTRACT ERROR\\]", result$output, value = TRUE)
          detail <- if (length(contract_lines) > 0) paste0("; ", tail(contract_lines, 1L)) else ""
          reason <- sprintf("child command exited %d: %s%s", result$code, basename(st$scripts[[idx]]), detail)
          break
        }
      }
      if (code == 0L) {
        gate <- content_gate(st, st$outputs, params$project_dir)
        status <- gate$status; reason <- gate$reason
        if (status == "failure") code <- 1L
      } else {
        status <- "failure"
      }
      if (status %in% c("failure", "negative")) halted <- TRUE
    }
    if (status == "failure") halted <- TRUE
    record <- write_stage_status(manifest, st$id, status, reason, command, st$inputs, st$outputs,
                                 metadata$sample_id, status_path = file.path(params$project_dir, "status", paste0(st$id, ".json")), exit_code = code)
    update_manifest_stage(params$manifest, st$id, status, reason, st$inputs, st$outputs)
    statuses[[st$id]] <- record
    log_msg(if (status == "success") "SUCCESS" else if (status == "negative") "NEGATIVE" else if (status == "skipped") "SKIP" else "ERROR",
            sprintf("stage %02d status=%s reason=%s", st$stage_num, status, reason), log_path)
  }
  status_values <- vapply(statuses, function(x) x$status, character(1))
  aggregate <- if ("failure" %in% status_values) list(overall_status = "failure", overall_success = FALSE, exit_code = 1L)
               else if ("manual_review" %in% status_values) list(overall_status = "manual_review", overall_success = FALSE, exit_code = 0L)
               else if ("skipped" %in% status_values) list(overall_status = "skipped", overall_success = FALSE, exit_code = 0L)
               else if ("negative" %in% status_values) list(overall_status = "negative", overall_success = FALSE, exit_code = 0L)
               else list(overall_status = "success", overall_success = TRUE, exit_code = 0L)
  output_records <- list()
  for (st in stages) {
    for (path in st$outputs[file.exists(st$outputs)]) {
      output_records[[length(output_records) + 1L]] <- list(
        path = path, sha256 = sha256_file(path), producer_stage = st$id
      )
    }
  }
  report <- list(run_id = params$run_id, source_revision = params$source_revision,
                 overall_status = aggregate$overall_status, overall_success = aggregate$overall_success,
                 exit_code = aggregate$exit_code, stages = unname(statuses), outputs = output_records,
                 manual_changes = manifest$manual_changes, external_blockers = list())
  write_json_contract(report, file.path(params$project_dir, params$report_json))
  gate_rows <- lapply(statuses, function(x) data.frame(
    Stage = x$stage_id, Status = x$status, Reason = x$reason, ExitCode = x$exit_code,
    stringsAsFactors = FALSE
  ))
  if (length(gate_rows) > 0) write.csv(do.call(rbind, gate_rows), file.path(params$project_dir, params$gate_report), row.names = FALSE)
  log_msg(if (aggregate$overall_success) "SUCCESS" else "STOP", sprintf("overall_status=%s exit_code=%d", aggregate$overall_status, aggregate$exit_code), log_path)
  quit(status = aggregate$exit_code)
}

if (!interactive()) {
  tryCatch(main(), error = function(error) {
    cat(sprintf("[ERROR] %s\n", conditionMessage(error)))
    quit(status = 1)
  })
}
