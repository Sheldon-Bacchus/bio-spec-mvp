#!/usr/bin/env Rscript
# Shared run, metadata, status, and provenance contracts for original-sop stages.

contract_stop <- function(reason) {
  stop(sprintf("[CONTRACT ERROR] %s", reason), call. = FALSE)
}

assert_explicit_path <- function(path, label, must_exist = TRUE) {
  if (length(path) != 1 || is.null(path) || is.na(path) || !nzchar(trimws(path))) {
    contract_stop(sprintf("%s is required and must be a non-empty path", label))
  }
  if (grepl("[{}]", path, perl = TRUE)) {
    contract_stop(sprintf("%s contains an unresolved literal placeholder: %s", label, path))
  }
  if (must_exist && !file.exists(path)) {
    contract_stop(sprintf("%s does not exist: %s", label, path))
  }
  normalizePath(path, winslash = "/", mustWork = must_exist)
}

assert_scalar_text <- function(value, label) {
  if (length(value) != 1 || is.null(value) || is.na(value) || !nzchar(trimws(as.character(value)))) {
    contract_stop(sprintf("%s must be a non-empty scalar", label))
  }
  as.character(value)
}

read_json_contract <- function(path) {
  assert_explicit_path(path, "manifest", must_exist = TRUE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    contract_stop("R package 'jsonlite' is required for machine-readable contracts")
  }
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

write_json_contract <- function(value, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    contract_stop("R package 'jsonlite' is required for machine-readable contracts")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

sha256_file <- function(path) {
  assert_explicit_path(path, "input", must_exist = TRUE)
  if (!requireNamespace("digest", quietly = TRUE)) {
    contract_stop("R package 'digest' is required for SHA-256 provenance")
  }
  toupper(digest::digest(file = path, algo = "sha256", serialize = FALSE))
}

assert_sha256 <- function(value, label) {
  if (length(value) != 1 || is.na(value) || !grepl("^[A-Fa-f0-9]{64}$", value)) {
    contract_stop(sprintf("%s must be a 64-character SHA-256 value", label))
  }
  toupper(value)
}

read_metadata_contract <- function(path, matrix_sample_ids = NULL, expected_species = NULL) {
  path <- assert_explicit_path(path, "sample metadata", must_exist = TRUE)
  metadata <- if (grepl("\\.csv$", path, ignore.case = TRUE)) {
    read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    read.table(path, header = TRUE, sep = "\t", stringsAsFactors = FALSE,
               check.names = FALSE, quote = "", comment.char = "")
  }
  required <- c("sample_id", "group", "species", "id_type", "batch", "partition")
  missing <- setdiff(required, colnames(metadata))
  if (length(missing) > 0) {
    contract_stop(sprintf("metadata missing required columns: %s", paste(missing, collapse = ", ")))
  }
  metadata <- metadata[, required, drop = FALSE]
  for (column in required) {
    values <- trimws(as.character(metadata[[column]]))
    if (any(is.na(values) | !nzchar(values))) {
      contract_stop(sprintf("metadata column '%s' contains missing/empty values", column))
    }
    metadata[[column]] <- values
  }
  if (anyDuplicated(metadata$sample_id) > 0) {
    contract_stop("duplicate_sample_id: sample_id values must be unique")
  }
  if (!is.null(matrix_sample_ids)) {
    matrix_sample_ids <- as.character(matrix_sample_ids)
    if (!identical(matrix_sample_ids, metadata$sample_id)) {
      contract_stop("sample_order_mismatch: metadata sample_id order must equal matrix columns")
    }
  }
  if (!is.null(expected_species)) {
    expected_species <- as.character(expected_species)
    unknown <- setdiff(unique(metadata$species), expected_species)
    if (length(unknown) > 0) {
      contract_stop(sprintf("unknown_species: %s", paste(unknown, collapse = ", ")))
    }
  }
  if (!all(metadata$partition %in% c("discovery", "validation"))) {
    contract_stop("invalid_partition: partition must be discovery or validation")
  }
  if (!setequal(unique(metadata$partition), c("discovery", "validation"))) {
    contract_stop("partition_set: both discovery and validation partitions are required")
  }
  if (length(unique(metadata$group)) < 2) {
    contract_stop("group_classes: at least two groups are required")
  }
  if (length(unique(metadata$species)) != 1) {
    contract_stop("species_consistency: metadata must describe exactly one species")
  }
  if (length(unique(metadata$id_type)) != 1) {
    contract_stop("id_type_consistency: metadata must use exactly one identifier type")
  }
  metadata
}

read_expression_matrix_contract <- function(path, metadata = NULL) {
  path <- assert_explicit_path(path, "expression matrix", must_exist = TRUE)
  first_line <- readLines(path, n = 1, warn = FALSE)
  if (length(first_line) == 0 || !nzchar(first_line[[1]])) {
    contract_stop("matrix_header_missing: expression matrix must have a header")
  }
  separator <- if (grepl(",", first_line[[1]], fixed = TRUE)) "," else "\t"
  matrix_df <- if (separator == ",") {
    read.csv(path, header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    read.table(path, header = TRUE, sep = separator, quote = "", fill = TRUE,
               check.names = FALSE, stringsAsFactors = FALSE, comment.char = "")
  }
  if (ncol(matrix_df) < 3) {
    contract_stop("matrix_columns: matrix must contain an ID column and at least two samples")
  }
  gene_ids <- trimws(as.character(matrix_df[[1]]))
  if (any(is.na(gene_ids) | !nzchar(gene_ids))) {
    contract_stop("matrix_gene_ids: gene/probe IDs cannot be empty")
  }
  if (anyDuplicated(gene_ids) > 0) {
    contract_stop("matrix_gene_ids: gene/probe IDs must be unique before aggregation")
  }
  sample_ids <- colnames(matrix_df)[-1]
  if (any(is.na(sample_ids) | !nzchar(sample_ids)) || anyDuplicated(sample_ids) > 0) {
    contract_stop("matrix_sample_ids: sample columns must be non-empty and unique")
  }
  if (!is.null(metadata)) {
    if (!identical(as.character(sample_ids), as.character(metadata$sample_id))) {
      contract_stop("sample_order_mismatch: matrix columns and metadata sample_id differ")
    }
  }
  values <- suppressWarnings(as.matrix(matrix_df[, -1, drop = FALSE]))
  mode(values) <- "numeric"
  if (any(!is.finite(values))) {
    contract_stop("matrix_values: expression matrix contains non-finite values")
  }
  rownames(values) <- gene_ids
  values
}

manifest_input_sha256 <- function(manifest) {
  if (is.null(manifest$inputs) || length(manifest$inputs) == 0) {
    contract_stop("manifest.inputs must contain at least one input")
  }
  hashes <- vapply(manifest$inputs, function(item) assert_sha256(item$sha256, "manifest input sha256"), character(1))
  hashes
}

validate_manifest_context <- function(manifest_path, run_id = NULL, source_revision = NULL,
                                      metadata_path = NULL, input_paths = NULL) {
  manifest_path <- assert_explicit_path(manifest_path, "manifest", must_exist = TRUE)
  manifest <- read_json_contract(manifest_path)
  required <- c("run_id", "source_revision", "created_at", "parameters", "inputs", "stages", "manual_changes")
  missing <- required[!vapply(required, function(name) !is.null(manifest[[name]]), logical(1))]
  if (length(missing) > 0) {
    contract_stop(sprintf("manifest missing fields: %s", paste(missing, collapse = ", ")))
  }
  assert_scalar_text(manifest$run_id, "manifest run_id")
  assert_scalar_text(manifest$source_revision, "manifest source_revision")
  if (!is.null(run_id) && !identical(as.character(run_id), as.character(manifest$run_id))) {
    contract_stop("run_id_mismatch")
  }
  if (!is.null(source_revision) && !identical(as.character(source_revision), as.character(manifest$source_revision))) {
    contract_stop("source_revision_mismatch")
  }
  manifest_hashes <- manifest_input_sha256(manifest)
  if (!is.null(metadata_path)) {
    metadata_path <- assert_explicit_path(metadata_path, "sample metadata", must_exist = TRUE)
    metadata_hash <- sha256_file(metadata_path)
    declared_paths <- vapply(manifest$inputs, function(item) as.character(item$path), character(1))
    declared_hashes <- vapply(manifest$inputs, function(item) as.character(item$sha256), character(1))
    path_match <- declared_paths %in% c(metadata_path, basename(metadata_path))
    if (!any(path_match) || !metadata_hash %in% toupper(declared_hashes[path_match])) {
      contract_stop("metadata_provenance_mismatch")
    }
  }
  if (!is.null(input_paths)) {
    for (input_path in input_paths) {
      input_path <- assert_explicit_path(input_path, "stage input", must_exist = TRUE)
      matching_input <- which(vapply(manifest$inputs, function(item) {
        declared <- normalizePath(as.character(item$path), winslash = "/", mustWork = FALSE)
        identical(declared, input_path) || identical(basename(declared), basename(input_path))
      }, logical(1)))
      if (length(matching_input) > 0) {
        actual_hash <- sha256_file(input_path)
        declared_hash <- assert_sha256(manifest$inputs[[matching_input[[1]]]]$sha256, "manifest input sha256")
        if (!identical(actual_hash, declared_hash)) {
          contract_stop(sprintf("input_fingerprint_mismatch: %s", basename(input_path)))
        }
      }
    }
  }
  attr(manifest, "manifest_path") <- manifest_path
  attr(manifest, "input_sha256") <- manifest_hashes
  manifest
}

stage_status_record <- function(manifest, stage_id, status, reason, command,
                                input_paths, output_paths, sample_ids = character(),
                                exit_code = 0, source_revision = manifest$source_revision,
                                input_sha256 = attr(manifest, "input_sha256")) {
  if (is.null(input_sha256) || length(input_sha256) == 0) {
    input_sha256 <- manifest_input_sha256(manifest)
  }
  allowed <- c("success", "negative", "manual_review", "skipped", "failure")
  if (!status %in% allowed) {
    contract_stop(sprintf("invalid stage status: %s", status))
  }
  if (length(reason) != 1 || !nzchar(trimws(reason))) {
    contract_stop("stage status reason is required")
  }
  list(
    run_id = as.character(manifest$run_id),
    stage_id = as.character(stage_id),
    status = as.character(status),
    reason = as.character(reason),
    command = as.character(command),
    exit_code = as.integer(exit_code),
    inputs = as.character(input_paths),
    outputs = as.character(output_paths),
    sample_coverage = list(
      expected = as.integer(length(sample_ids)),
      observed = as.integer(length(sample_ids)),
      missing = character(),
      unexpected = character()
    ),
    provenance = list(
      source_revision = as.character(source_revision),
      input_sha256 = as.character(input_sha256)
    )
  )
}

write_stage_status <- function(manifest, stage_id, status, reason, command,
                               input_paths, output_paths, sample_ids = character(),
                               status_path, exit_code = 0,
                               source_revision = manifest$source_revision,
                               input_sha256 = attr(manifest, "input_sha256")) {
  record <- stage_status_record(
    manifest = manifest,
    stage_id = stage_id,
    status = status,
    reason = reason,
    command = command,
    input_paths = input_paths,
    output_paths = output_paths,
    sample_ids = sample_ids,
    exit_code = exit_code,
    source_revision = source_revision,
    input_sha256 = input_sha256
  )
  write_json_contract(record, status_path)
  invisible(record)
}

update_manifest_stage <- function(manifest_path, stage_id, status, reason,
                                  input_paths, output_paths) {
  manifest <- read_json_contract(manifest_path)
  if (is.null(manifest$stages) || length(manifest$stages) == 0) {
    contract_stop("manifest.stages must contain declared stages")
  }
  matched <- FALSE
  for (idx in seq_along(manifest$stages)) {
    if (identical(as.character(manifest$stages[[idx]]$stage_id), as.character(stage_id))) {
      manifest$stages[[idx]]$status <- as.character(status)
      manifest$stages[[idx]]$reason <- as.character(reason)
      manifest$stages[[idx]]$inputs <- as.character(input_paths)
      manifest$stages[[idx]]$outputs <- as.character(output_paths)
      existing_outputs <- output_paths[file.exists(output_paths)]
      if (length(existing_outputs) > 0) {
        manifest$stages[[idx]]$output_sha256 <- setNames(vapply(existing_outputs, sha256_file, character(1)), existing_outputs)
      } else {
        manifest$stages[[idx]]$output_sha256 <- NULL
      }
      matched <- TRUE
    }
  }
  if (!matched) {
    contract_stop(sprintf("stage %s is not declared in the manifest", stage_id))
  }
  write_json_contract(manifest, manifest_path)
  invisible(manifest)
}
