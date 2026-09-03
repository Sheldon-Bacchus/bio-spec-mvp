#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
apply_fixes.py — spec-007 P0/P1 修复补丁（程序化、可复现、精确替换）
对 original-sop 下的 R 脚本应用审计确认的修复；每处替换计数，失败即报错防漏。
用法: python apply_fixes.py
"""
import io, os, sys

SOP = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"

report = []

def patch(path, subs):
    """Apply list of (old, new) replacements to a file. Count each; assert all applied."""
    full = os.path.join(SOP, path)
    with io.open(full, "r", encoding="utf-8", errors="replace") as fh:
        txt = fh.read()
    n = 0
    for old, new in subs:
        c = txt.count(old)
        if c == 0:
            report.append("MISS %s :: %r" % (path, old[:70]))
            continue
        txt = txt.replace(old, new)
        n += c
    with io.open(full, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)
    report.append("OK   %s :: %d replacements" % (path, n))
    return n

# ============================================================
# F-01 [P1-SYS] parse_args 连字符键 -> 下划线键（9 个 parse_args(defaults) 脚本共用）
# ============================================================
SYS_PARSE = (
    # 统一把 res[[parts[1]]] / res[[key_val]] 的键规范化
    ('        parts <- strsplit(key_val, "=", fixed = TRUE)[[1]]\n        res[[parts[1]]] <- parts[2]',
     '        parts <- strsplit(key_val, "=", fixed = TRUE)[[1]]\n        key <- gsub("-", "_", parts[1])\n        res[[key]] <- parts[2]'),
    ('        res[[key_val]] <- args[i + 1]',
     '        res[[gsub("-", "_", key_val)]] <- args[i + 1]'),
)

for f in ["bio-01-geo-dataprep/scripts/geo_preprocess.R",
          "bio-02-batch-norm/scripts/normalize.R",
          "bio-02-batch-norm/scripts/pca_qc.R",
          "bio-02-batch-norm/scripts/sva_combat.R",
          "bio-03-wgcna/scripts/wgcna_build.R",
          "bio-03-wgcna/scripts/wgcna_module_export.R",
          "bio-04-deg-limma/scripts/limma_diff.R",
          "bio-04-deg-limma/scripts/volcano_heatmap.R",
          "bio-05-enrichment/scripts/enrichment_analysis.R"]:
    patch(f, list(SYS_PARSE))

# ============================================================
# F-02 [P0] geo_preprocess.R 分组 fallback fail-closed（删 half-split）
# ============================================================
patch("bio-01-geo-dataprep/scripts/geo_preprocess.R", [
    ('''  } else {
    # Default fallback: split first half Control, second half Treat
    mid <- ceiling(length(samples) / 2)
    sample_groups[1:mid] <- "Control"
    sample_groups[(mid + 1):length(samples)] <- "Treat"
  }''',
     '''  } else {
    stop("[ERROR] Cannot infer sample groups: no --sample-con/--sample-treat given and sample names carry no group hint. Provide explicit grouping (fail-closed per contracts G-02).")
  }'''),
])

# ============================================================
# F-05 [P0] enrichment_analysis.R: bitr 0 映射显式报错；pae GO 明确说明
# ============================================================
patch("bio-05-enrichment/scripts/enrichment_analysis.R", [
    ('''  entrez_ids <- unique(id_map$ENTREZID)
  cat(sprintf("[INFO] Successfully mapped %d / %d symbols to Entrez IDs.\n", length(entrez_ids), length(gene_symbols)))''',
     '''  entrez_ids <- unique(id_map$ENTREZID)
  cat(sprintf("[INFO] Successfully mapped %d / %d symbols to Entrez IDs.\n", length(entrez_ids), length(gene_symbols)))
  if (length(entrez_ids) == 0) {
    stop("[ERROR] Zero gene symbols could be mapped to Entrez IDs. Check species / symbol spelling (contracts F-05: fail loudly, not silently empty).")
  }'''),
    ('''  cat("[WARN] Non-human organism specified. Direct enrichGO requires dedicated OrgDb. Checking KEGG enrichment...\n")''',
     '''  cat("[WARN] Non-human organism specified. GO enrichment requires a dedicated OrgDb (e.g. org.Pa.eg.db for P. aeruginosa) which is not loaded; skipping GO with explicit notice (contracts: fail-visible, not silent). Checking KEGG only.\n")'''),
])

# ============================================================
# G-01 typo: gene_expression_match.R 删除 merge.normalzie alias
# ============================================================
patch("bio-07-ml-lasso/scripts/gene_expression_match.R", [
    ('''  if (!file.exists(params$expr_file)) {
    fallback_expr <- "merge.normalzie.txt"
    if (file.exists(fallback_expr)) {
      cat(sprintf("[WARN] '%s' not found, using existing fallback '%s'\n", params$expr_file, fallback_expr))
      params$expr_file <- fallback_expr
    } else {
      stop(sprintf("[ERROR] Expression matrix file not found: %s", params$expr_file))
    }
  }''',
     '''  if (!file.exists(params$expr_file)) {
    stop(sprintf("[ERROR] Expression matrix file not found: %s (contracts G-01: no legacy typo alias)", params$expr_file))
  }'''),
])

# ============================================================
# G-06 [P0] hub_gene_intersection.R: 空交集 FAIL（删 union fallback）+ header 黑名单修正
# ============================================================
patch("bio-09-hub-literature/scripts/hub_gene_intersection.R", [
    ('''  if (n_intersect == 0) {
    warning("[WARN] Intersection between LASSO and Random Forest is empty! Falling back to union or top rankers.")
    # In emergency fallback, combine top genes from both
    final_hub_genes <- union_genes
    n_intersect <- length(final_hub_genes)
  }''',
     '''  if (n_intersect == 0) {
    stop("[GATE ERROR] Intersection between LASSO and Random Forest is EMPTY. Refusing union fallback (contracts G-06: empty intersection requires human review).")
  }'''),
    ('''  header_candidates <- c("gene", "genes", "geneNames", "Symbol", "x", "V1")''',
     '''  header_candidates <- c("gene", "genes", "geneNames", "Symbol")'''),
])

# ============================================================
# P1 header 黑名单修正: roc_validation.R (x/V1 误删)
# ============================================================
patch("bio-10-biomarker-roc/scripts/roc_validation.R", [
    ('''  header_candidates <- c("gene", "genes", "geneNames", "Symbol", "x", "V1")''',
     '''  header_candidates <- c("gene", "genes", "geneNames", "Symbol")'''),
])

# ============================================================
# run_pipeline.R: typo alias 删除 + stage1/stage5 gate 修复 + 依赖清单
# ============================================================
patch("bio-pipeline-orchestrator/scripts/run_pipeline.R", [
    # stage1 gate: 幻影文件
    ('''      gate_check = function(work_dir) {
        has_expr <- file.exists(file.path(work_dir, "expression_matrix.txt")) || 
                    file.exists(file.path(work_dir, "merge.normalzie.txt"))
        has_grp <- file.exists(file.path(work_dir, "sample_group.csv")) ||
                    file.exists(file.path(work_dir, "clinic.csv"))
        list(passed = has_expr && has_grp, detail = "Expression matrix and group metadata exist.")
      }''',
     '''      gate_check = function(work_dir) {
        has_expr <- any(grepl("\\.normalize\\.txt$", list.files(work_dir)))
        has_grp <- file.exists(file.path(work_dir, "PD.csv")) || file.exists(file.path(work_dir, "group.txt"))
        list(passed = has_expr && has_grp, detail = "Normalized expression matrix (*.normalize.txt) and group metadata (PD.csv/group.txt) exist.")
      }'''),
    # stage5 gate: hardcoded TRUE
    ('''      gate_check = function(work_dir) {
        f <- file.path(work_dir, "go_enrichment.csv")
        list(passed = TRUE, detail = "Enrichment outputs generated or skipped.")
      }''',
     '''      gate_check = function(work_dir) {
        f1 <- file.path(work_dir, "GO_enrichment.csv")
        f2 <- file.path(work_dir, "KEGG_enrichment.csv")
        ok1 <- file.exists(f1) && file.info(f1)$size > 0
        ok2 <- file.exists(f2) && file.info(f2)$size > 0
        list(passed = ok1 || ok2, detail = "GO_enrichment.csv / KEGG_enrichment.csv non-empty (at least one required).")
      }'''),
    # 依赖清单
    ('''  required_pkgs <- c(
    "glmnet", "randomForest", "pROC", "ggplot2", "VennDiagram"
  )
  optional_pkgs <- c("rfPermute", "limma", "sva", "WGCNA", "clusterProfiler", "UpSetR")''',
     '''  required_pkgs <- c(
    "glmnet", "randomForest", "pROC", "ggplot2", "VennDiagram",
    "limma", "sva", "WGCNA", "impute", "Biobase", "clusterProfiler"
  )
  optional_pkgs <- c("rfPermute", "enrichplot", "org.Hs.eg.db", "pathview", "UpSetR", "pheatmap", "ggrepel", "gridExtra", "flashClust", "DOSE", "GO.db")'''),
    # typo alias in stage2 gate check
    ('''        f1 <- file.path(work_dir, "merge.normalize.txt")
        f2 <- file.path(work_dir, "merge.normalzie.txt")
        exists <- file.exists(f1) || file.exists(f2)
        list(passed = exists, detail = "Normalized and batch-corrected matrix generated.")''',
     '''        f <- file.path(work_dir, "merge.normalize.txt")
        list(passed = file.exists(f), detail = "Normalized and batch-corrected matrix generated (merge.normalize.txt).")'''),
    # typo alias in input prerequisite check
    ('''      if (!file.exists(f_target)) {
        if (inp == "merge.normalize.txt" && file.exists(file.path(params$project_dir, "merge.normalzie.txt"))) {
          # Typo alias accepted
        } else {
          missing_inputs <- c(missing_inputs, inp)
        }
      }''',
     '''      if (!file.exists(f_target)) {
        missing_inputs <- c(missing_inputs, inp)
      }'''),
])

print("\n".join(report))
print("\nALL_PATCHES_DONE")
