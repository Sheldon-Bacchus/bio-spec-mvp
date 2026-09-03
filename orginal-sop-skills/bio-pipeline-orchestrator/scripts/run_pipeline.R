#!/usr/bin/env Rscript
# ==============================================================================
# run_pipeline.R - Master Bioinformatics Pipeline Orchestrator
# ==============================================================================
# Skill: bio-pipeline-orchestrator
# Description: Top-level R orchestrator that validates prerequisites, inspects data
#              contracts, executes stages according to the pipeline DAG, evaluates
#              quality control gates, and generates consolidated execution logs.
# ==============================================================================

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  params <- list(
    project_dir = getwd(),
    skills_dir = NULL,
    start_stage = 1,
    end_stage = 10,
    dry_run = FALSE,
    force = FALSE,
    log_file = "pipeline_run.log",
    gate_report = "pipeline_gate_report.csv"
  )
  
  for (arg in args) {
    if (grepl("^--project-dir=", arg)) {
      params$project_dir <- normalizePath(sub("^--project-dir=", "", arg), winslash = "/", mustWork = FALSE)
    } else if (grepl("^--skills-dir=", arg)) {
      params$skills_dir <- normalizePath(sub("^--skills-dir=", "", arg), winslash = "/", mustWork = FALSE)
    } else if (grepl("^--start-stage=", arg)) {
      params$start_stage <- as.integer(sub("^--start-stage=", "", arg))
    } else if (grepl("^--end-stage=", arg)) {
      params$end_stage <- as.integer(sub("^--end-stage=", "", arg))
    } else if (arg == "--dry-run") {
      params$dry_run <- TRUE
    } else if (arg == "--force") {
      params$force <- TRUE
    } else if (grepl("^--log=", arg)) {
      params$log_file <- sub("^--log=", "", arg)
    } else if (grepl("^--report=", arg)) {
      params$gate_report <- sub("^--report=", "", arg)
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript run_pipeline.R [options]\n\n")
      cat("Options:\n")
      cat("  --project-dir=<dir>   Working directory with analysis data [default: current dir]\n")
      cat("  --skills-dir=<dir>    Directory containing skill packages [default: auto-detected]\n")
      cat("  --start-stage=<int>   Stage index to begin execution (1 to 10) [default: 1]\n")
      cat("  --end-stage=<int>     Stage index to conclude execution (1 to 10) [default: 10]\n")
      cat("  --dry-run             Validate prerequisites and contracts without execution\n")
      cat("  --force               Continue pipeline even if non-critical gate warnings occur\n")
      cat("  --log=<file>          Output execution log file [default: pipeline_run.log]\n")
      cat("  --report=<file>       Output Gate report CSV [default: pipeline_gate_report.csv]\n")
      quit(status = 0)
    }
  }
  
  # Auto-detect skills directory if not provided
  if (is.null(params$skills_dir)) {
    candidates <- c(
      file.path(params$project_dir, ".agents", "skills"),
      "E:/all-agent-workspace/bio-skills/.agents/skills",
      file.path(dirname(dirname(sys.frame(1)$ofile %||% ".")), "..")
    )
    for (c_dir in candidates) {
      if (dir.exists(c_dir)) {
        params$skills_dir <- normalizePath(c_dir, winslash = "/")
        break
      }
    }
  }
  
  return(params)
}

# Logger helper
log_msg <- function(level, msg, log_file = NULL) {
  ts <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  formatted <- sprintf("%s [%s] %s\n", ts, level, msg)
  cat(formatted)
  if (!is.null(log_file)) {
    cat(formatted, file = log_file, append = TRUE)
  }
}

# Prerequisite checker
check_prerequisites <- function(log_file) {
  log_msg("INFO", "Checking environment prerequisites...", log_file)
  
  # 1. R Version
  r_ver <- paste(R.version$major, R.version$minor, sep = ".")
  log_msg("INFO", sprintf("R Version detected: %s (%s)", r_ver, R.version$platform), log_file)
  
  # 2. Required R Packages
  required_pkgs <- c(
    "glmnet", "randomForest", "pROC", "ggplot2", "VennDiagram"
  )
  optional_pkgs <- c("rfPermute", "limma", "sva", "WGCNA", "clusterProfiler", "UpSetR")
  
  missing_required <- c()
  for (pkg in required_pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing_required <- c(missing_required, pkg)
    }
  }
  
  if (length(missing_required) > 0) {
    log_msg("ERROR", sprintf("Missing required R packages: %s", paste(missing_required, collapse = ", ")), log_file)
    stop("Prerequisite check failed: missing required packages.")
  } else {
    log_msg("SUCCESS", "All critical R packages are available.", log_file)
  }
  
  for (pkg in optional_pkgs) {
    status <- if (requireNamespace(pkg, quietly = TRUE)) "Installed" else "Not installed (fallback mode will be used)"
    log_msg("INFO", sprintf("Optional package '%s': %s", pkg, status), log_file)
  }
}

# Define stage registry
get_stage_definitions <- function(skills_dir) {
  list(
    list(
      stage_num = 1,
      id = "bio-01-geo-dataprep",
      name = "GEO Data Download & Probe Mapping",
      script = file.path(skills_dir, "bio-01-geo-dataprep", "scripts", "geo_dataprep.R"),
      inputs = c(),
      outputs = c("expression_matrix.txt", "sample_group.csv"),
      gate_check = function(work_dir) {
        has_expr <- file.exists(file.path(work_dir, "expression_matrix.txt")) || 
                    file.exists(file.path(work_dir, "merge.normalzie.txt"))
        has_grp <- file.exists(file.path(work_dir, "sample_group.csv")) ||
                   file.exists(file.path(work_dir, "clinic.csv"))
        list(passed = has_expr && has_grp, detail = "Expression matrix and group metadata exist.")
      }
    ),
    list(
      stage_num = 2,
      id = "bio-02-batch-norm",
      name = "Normalization & Batch Correction (SVA/ComBat)",
      script = file.path(skills_dir, "bio-02-batch-norm", "scripts", "normalize_batch.R"),
      inputs = c("expression_matrix.txt"),
      outputs = c("merge.normalize.txt"),
      gate_check = function(work_dir) {
        f1 <- file.path(work_dir, "merge.normalize.txt")
        f2 <- file.path(work_dir, "merge.normalzie.txt")
        exists <- file.exists(f1) || file.exists(f2)
        list(passed = exists, detail = "Normalized and batch-corrected matrix generated.")
      }
    ),
    list(
      stage_num = 3,
      id = "bio-03-wgcna",
      name = "Weighted Gene Co-expression Network Analysis",
      script = file.path(skills_dir, "bio-03-wgcna", "scripts", "wgcna_pipeline.R"),
      inputs = c("merge.normalize.txt"),
      outputs = c("module_genes.csv"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "module_genes.csv")
        list(passed = file.exists(f) && file.info(f)$size > 10, detail = "Target co-expression module genes identified.")
      }
    ),
    list(
      stage_num = 4,
      id = "bio-04-deg-limma",
      name = "Differential Expression Analysis (limma)",
      script = file.path(skills_dir, "bio-04-deg-limma", "scripts", "deg_analysis.R"),
      inputs = c("merge.normalize.txt"),
      outputs = c("diff.txt"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "diff.txt")
        list(passed = file.exists(f) && file.info(f)$size > 10, detail = "Differentially expressed genes table non-empty.")
      }
    ),
    list(
      stage_num = 5,
      id = "bio-05-enrichment",
      name = "GO & KEGG Functional Enrichment",
      script = file.path(skills_dir, "bio-05-enrichment", "scripts", "enrichment_analysis.R"),
      inputs = c("diff.txt"),
      outputs = c("go_enrichment.csv"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "go_enrichment.csv")
        list(passed = TRUE, detail = "Enrichment outputs generated or skipped.")
      }
    ),
    list(
      stage_num = 6,
      id = "bio-06-gene-intersection",
      name = "WGCNA & DEG Multi-Algorithm Intersection",
      script = file.path(skills_dir, "bio-06-gene-intersection", "scripts", "venn_intersection.R"),
      inputs = c("module_genes.csv", "diff.txt"),
      outputs = c("candidate_hub_genes.txt", "venn_plot.pdf"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "candidate_hub_genes.txt")
        if (!file.exists(f)) return(list(passed = FALSE, detail = "candidate_hub_genes.txt not found"))
        n <- length(readLines(f, warn = FALSE))
        list(passed = n >= 2, detail = sprintf("Candidate hub genes count = %d (Gate target >= 2)", n))
      }
    ),
    list(
      stage_num = 7,
      id = "bio-07-ml-lasso",
      name = "LASSO Feature Reduction & Cross-Validation",
      script = file.path(skills_dir, "bio-07-ml-lasso", "scripts", "lasso_regression.R"),
      prep_script = file.path(skills_dir, "bio-07-ml-lasso", "scripts", "gene_expression_match.R"),
      inputs = c("candidate_hub_genes.txt"),
      outputs = c("LASSO.gene.txt", "lasso.pdf", "cvfit.pdf"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "LASSO.gene.txt")
        if (!file.exists(f)) return(list(passed = FALSE, detail = "LASSO.gene.txt not found"))
        n <- length(readLines(f, warn = FALSE))
        list(passed = n >= 1, detail = sprintf("LASSO selected %d features (Gate target >= 1)", n))
      }
    ),
    list(
      stage_num = 8,
      id = "bio-08-ml-randomforest",
      name = "Random Forest Permutation Importance",
      script = file.path(skills_dir, "bio-08-ml-randomforest", "scripts", "random_forest_importance.R"),
      inputs = c("merged_file.txt"),
      outputs = c("rf_genes.txt", "richness.txt", "rf_importance.pdf"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "rf_genes.txt")
        if (!file.exists(f)) return(list(passed = FALSE, detail = "rf_genes.txt not found"))
        n <- length(readLines(f, warn = FALSE))
        list(passed = n >= 1, detail = sprintf("Random Forest selected %d features (Gate target >= 1)", n))
      }
    ),
    list(
      stage_num = 9,
      id = "bio-09-hub-literature",
      name = "Consensus Hub Determination & Literature Mining",
      script = file.path(skills_dir, "bio-09-hub-literature", "scripts", "hub_gene_intersection.R"),
      inputs = c("LASSO.gene.txt", "rf_genes.txt"),
      outputs = c("final_hub_genes.txt"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "final_hub_genes.txt")
        if (!file.exists(f)) return(list(passed = FALSE, detail = "final_hub_genes.txt not found"))
        n <- length(readLines(f, warn = FALSE))
        list(passed = n >= 1, detail = sprintf("Final consensus Hub genes count = %d (Gate target >= 1)", n))
      }
    ),
    list(
      stage_num = 10,
      id = "bio-10-biomarker-roc",
      name = "Diagnostic Biomarker ROC & AUC Validation",
      script = file.path(skills_dir, "bio-10-biomarker-roc", "scripts", "roc_validation.R"),
      inputs = c("final_hub_genes.txt"),
      outputs = c("auc_report.csv", "roc_single_gene.pdf"),
      gate_check = function(work_dir) {
        f <- file.path(work_dir, "auc_report.csv")
        if (!file.exists(f)) return(list(passed = FALSE, detail = "auc_report.csv not found"))
        rep <- read.csv(f, stringsAsFactors = FALSE)
        max_auc <- max(rep$AUC, na.rm = TRUE)
        list(passed = max_auc >= 0.70, detail = sprintf("Maximum biomarker AUC = %.3f (Gate target >= 0.70)", max_auc))
      }
    )
  )
}

main <- function() {
  params <- parse_args()
  
  log_path <- file.path(params$project_dir, params$log_file)
  report_path <- file.path(params$project_dir, params$gate_report)
  
  cat("======================================================================\n")
  cat("            BIO-PIPELINE MASTER WORKFLOW ORCHESTRATOR                \n")
  cat("======================================================================\n")
  log_msg("INFO", sprintf("Target Project Directory: %s", params$project_dir), log_path)
  log_msg("INFO", sprintf("Skills Root Directory:    %s", params$skills_dir), log_path)
  log_msg("INFO", sprintf("Execution Range:          Stage %02d -> Stage %02d", params$start_stage, params$end_stage), log_path)
  log_msg("INFO", sprintf("Dry Run Mode:             %s", ifelse(params$dry_run, "ENABLED", "DISABLED")), log_path)
  
  # Check R environment prerequisites
  check_prerequisites(log_path)
  
  stages <- get_stage_definitions(params$skills_dir)
  gate_records <- list()
  
  for (st in stages) {
    if (st$stage_num < params$start_stage || st$stage_num > params$end_stage) {
      next
    }
    
    cat("\n----------------------------------------------------------------------\n")
    log_msg("STAGE", sprintf("Beginning Stage %02d: %s [%s]", st$stage_num, st$name, st$id), log_path)
    
    # 1. Check Input Prerequisites
    missing_inputs <- c()
    for (inp in st$inputs) {
      f_target <- file.path(params$project_dir, inp)
      # Check alternate names
      if (!file.exists(f_target)) {
        if (inp == "merge.normalize.txt" && file.exists(file.path(params$project_dir, "merge.normalzie.txt"))) {
          # Typo alias accepted
        } else {
          missing_inputs <- c(missing_inputs, inp)
        }
      }
    }
    
    if (length(missing_inputs) > 0 && !params$dry_run) {
      log_msg("ERROR", sprintf("Missing required inputs for Stage %02d: %s", 
                              st$stage_num, paste(missing_inputs, collapse = ", ")), log_path)
      if (!params$force) {
        stop(sprintf("Pipeline halted at Stage %02d due to missing input contracts.", st$stage_num))
      }
    }
    
    # 2. Execute Stage Scripts
    if (!params$dry_run) {
      # Execute preparation script if needed (e.g., Skill 07 expression matching)
      if (!is.null(st$prep_script) && file.exists(st$prep_script)) {
        log_msg("EXEC", sprintf("Running prep script: %s", basename(st$prep_script)), log_path)
        cmd_prep <- sprintf('Rscript "%s" --output-dir="%s"', st$prep_script, params$project_dir)
        status_prep <- system(cmd_prep)
        if (status_prep != 0) {
          log_msg("ERROR", sprintf("Preparation script failed with code %d", status_prep), log_path)
          if (!params$force) stop("Pipeline halted.")
        }
      }
      
      # Execute primary script
      if (file.exists(st$script)) {
        log_msg("EXEC", sprintf("Running primary script: %s", basename(st$script)), log_path)
        cmd_main <- sprintf('Rscript "%s" --output-dir="%s"', st$script, params$project_dir)
        status_main <- system(cmd_main)
        if (status_main != 0) {
          log_msg("ERROR", sprintf("Primary script execution returned exit code %d", status_main), log_path)
          if (!params$force) stop("Pipeline halted.")
        }
      } else {
        log_msg("WARN", sprintf("Script file not found at '%s'. Simulating/skipping execution.", st$script), log_path)
      }
    } else {
      log_msg("DRYRUN", sprintf("Would execute script: %s", basename(st$script)), log_path)
    }
    
    # 3. Perform Stage-Gate QC Verification
    gate_res <- st$gate_check(params$project_dir)
    gate_status <- if (gate_res$passed) "PASSED" else "FAILED"
    log_msg("GATE", sprintf("Stage %02d Gate [%s]: %s", st$stage_num, gate_status, gate_res$detail), log_path)
    
    gate_records[[length(gate_records) + 1]] <- data.frame(
      Stage = st$stage_num,
      Skill_ID = st$id,
      Name = st$name,
      Status = gate_status,
      Detail = gate_res$detail,
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      stringsAsFactors = FALSE
    )
    
    if (!gate_res$passed && !params$dry_run && !params$force) {
      log_msg("CRITICAL", sprintf("Stage %02d failed quality gate! Halting pipeline execution.", st$stage_num), log_path)
      break
    }
  }
  
  # Export Consolidated Gate Report
  gate_df <- do.call(rbind, gate_records)
  write.csv(gate_df, file = report_path, row.names = FALSE)
  log_msg("SUCCESS", sprintf("Consolidated Gate summary saved to: %s", report_path), log_path)
  
  cat("\n======================================================================\n")
  cat("                 PIPELINE RUN SUMMARY REPORT                          \n")
  cat("======================================================================\n")
  print(gate_df[, c("Stage", "Skill_ID", "Status", "Detail")])
  cat("======================================================================\n")
}

if (!interactive()) {
  main()
}
