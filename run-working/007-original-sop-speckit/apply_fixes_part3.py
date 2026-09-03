# -*- coding: utf-8 -*-
"""
apply_fixes_part3.py — 用 raw-string 精确重打所有 MISS 补丁
"""
import io, os

SOP = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
report = []

def patch(path, subs):
    full = os.path.join(SOP, path)
    with io.open(full, "r", encoding="utf-8", errors="replace") as fh:
        txt = fh.read()
    n = 0
    for old, new in subs:
        c = txt.count(old)
        if c == 0:
            report.append("MISS %s :: %r" % (path, old[:80]))
            continue
        txt = txt.replace(old, new)
        n += c
    with io.open(full, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)
    report.append("OK   %s :: %d" % (path, n))

# ---- enrichment bitr fail-loud ----
patch("bio-05-enrichment/scripts/enrichment_analysis.R", [
    (r'''  entrez_ids <- unique(id_map$ENTREZID)
  cat(sprintf("[INFO] Successfully mapped %d / %d symbols to Entrez IDs.\n", length(entrez_ids), length(gene_symbols)))''',
     r'''  entrez_ids <- unique(id_map$ENTREZID)
  cat(sprintf("[INFO] Successfully mapped %d / %d symbols to Entrez IDs.\n", length(entrez_ids), length(gene_symbols)))
  if (length(entrez_ids) == 0) {
    stop("[ERROR] Zero gene symbols mapped to Entrez IDs. Check species / symbol spelling (fail loudly, not silently empty).")
  }'''),
    (r'''  cat("[WARN] Non-human organism specified. Direct enrichGO requires dedicated OrgDb. Checking KEGG enrichment...\n")''',
     r'''  cat("[WARN] Non-human organism specified. GO enrichment requires a dedicated OrgDb which is not loaded; skipping GO with explicit notice (no silent gap). Checking KEGG only.\n")'''),
])

# ---- gene_expression_match typo removal ----
patch("bio-07-ml-lasso/scripts/gene_expression_match.R", [
    (r'''  # Handle fallback names for common variations (e.g. merge.normalzie.txt typo in legacy code)
  if (!file.exists(params$expr_file)) {
    fallback_expr <- "merge.normalzie.txt"
    if (file.exists(fallback_expr)) {
      cat(sprintf("[WARN] '%s' not found, using existing fallback '%s'\n", params$expr_file, fallback_expr))
      params$expr_file <- fallback_expr
    } else {
      stop(sprintf("[ERROR] Expression matrix file not found: %s", params$expr_file))
    }
  }''',
     r'''  if (!file.exists(params$expr_file)) {
    stop(sprintf("[ERROR] Expression matrix file not found: %s (contracts G-01: no legacy typo alias)", params$expr_file))
  }'''),
])

# ---- lasso: group fail-closed ----
patch("bio-07-ml-lasso/scripts/lasso_regression.R", [
    (r'''  if (!is.null(params$group_file) && file.exists(params$group_file)) {
    cat(sprintf("[INFO] Extracting sample labels from metadata: %s\n", params$group_file))
    group_df <- read.csv(params$group_file, stringsAsFactors = FALSE, check.names = FALSE)
    sample_col <- if ("sample" %in% colnames(group_df)) "sample" else colnames(group_df)[1]
    label_col <- if ("group" %in% colnames(group_df)) "group" else colnames(group_df)[2]
    
    label_map <- setNames(as.character(group_df[[label_col]]), as.character(group_df[[sample_col]]))
    y_raw <- label_map[sample_names]
    
    if (any(is.na(y_raw))) {
      warning("[WARN] Some samples not matched in group file, falling back to sample name parsing.")
      y_raw <- gsub("(.*)\\_(.*)", "\\2", sample_names)
    }
  } else {
    # Extract phenotype from sample name suffix (e.g., GSE10030_biofilm1 -> biofilm, GSM123_Control -> Control)
    cat("[INFO] Parsing group labels directly from sample names.\n")
    y_raw <- gsub("(.*)\\_(.*)", "\\2", sample_names)
    # If regex did not split anything, try dot or hyphen
    if (all(y_raw == sample_names)) {
      y_raw <- gsub("(.*)[\\.\\-](.*)", "\\2", sample_names)
    }
  }''',
     r'''  if (is.null(params$group_file) || !file.exists(params$group_file)) {
    stop("[GATE ERROR] --group file is REQUIRED for LASSO (contracts G-03 fail-closed: explicit metadata only). Provide sample group metadata CSV.")
  }
  cat(sprintf("[INFO] Extracting sample labels from metadata: %s\n", params$group_file))
  group_df <- read.csv(params$group_file, stringsAsFactors = FALSE, check.names = FALSE)
  sample_col <- if ("sample" %in% colnames(group_df)) "sample" else colnames(group_df)[1]
  label_col <- if ("group" %in% colnames(group_df)) "group" else colnames(group_df)[2]
  
  label_map <- setNames(as.character(group_df[[label_col]]), as.character(group_df[[sample_col]]))
  y_raw <- label_map[sample_names]
  
  unmatched <- sum(is.na(y_raw))
  if (unmatched > 0) {
    stop(sprintf("[GATE ERROR] %d samples did not match the group file (fail-closed on label mismatch). Check sample names / batch prefixes.", unmatched))
  }'''),
])

# ---- lasso: stratified foldid ----
patch("bio-07-ml-lasso/scripts/lasso_regression.R", [
    (r'''  # 2. Cross-validation to find optimal lambda
  cat(sprintf("[INFO] Performing %d-fold cross-validation with deviance metric...\n", actual_nfolds))
  cvfit <- cv.glmnet(
    x, y, 
    family = params$family, 
    alpha = params$alpha, 
    type.measure = "deviance", 
    nfolds = actual_nfolds
  )''',
     r'''  # 2. Cross-validation to find optimal lambda (stratified foldid, reproducible)
  cat(sprintf("[INFO] Performing %d-fold stratified cross-validation with deviance metric...\n", actual_nfolds))
  set.seed(12345)
  foldid <- integer(nrow(x))
  for (lv in levels(y)) {
    idx <- which(y == lv)
    k <- min(actual_nfolds, length(idx))
    folds <- sample(rep(seq_len(k), length.out = length(idx)))
    foldid[idx] <- folds
  }
  cvfit <- cv.glmnet(
    x, y, 
    family = params$family, 
    alpha = params$alpha, 
    type.measure = "deviance", 
    nfolds = actual_nfolds,
    foldid = foldid
  )'''),
])

# ---- lasso: lambda.1se export ----
patch("bio-07-ml-lasso/scripts/lasso_regression.R", [
    (r'''  # Export gene list
  out_gene_path <- file.path(params$output_dir, params$output_gene_file)
  write.table(
    selected_genes, 
    file = out_gene_path, 
    sep = "\t", 
    quote = FALSE, 
    row.names = FALSE, 
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved LASSO selected genes to: %s\n", out_gene_path))''',
     r'''  # Export gene list (lambda.min)
  out_gene_path <- file.path(params$output_dir, params$output_gene_file)
  write.table(
    selected_genes, 
    file = out_gene_path, 
    sep = "\t", 
    quote = FALSE, 
    row.names = FALSE, 
    col.names = FALSE
  )
  cat(sprintf("[SUCCESS] Saved LASSO selected genes (lambda.min) to: %s\n", out_gene_path))

  # Export lambda.1se gene list (contracts: dual-lambda reporting)
  coef_1se <- coef(fit, s = cvfit$lambda.1se)
  genes_1se <- rownames(coef_1se)[as.numeric(coef_1se) != 0]
  genes_1se <- genes_1se[genes_1se != "(Intercept)"]
  out_1se_path <- file.path(params$output_dir, "LASSO.gene.1se.txt")
  write.table(genes_1se, file = out_1se_path, sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  cat(sprintf("[SUCCESS] Saved LASSO selected genes (lambda.1se, n=%d) to: %s\n", length(genes_1se), out_1se_path))'''),
])

# ---- lasso: no top-N fabrication ----
patch("bio-07-ml-lasso/scripts/lasso_regression.R", [
    (r'''  # If lambda.min yielded no genes, fallback to lambda.1se or top 3 coefficients
  if (length(selected_genes) == 0) {
    warning("[WARN] No non-zero coefficients at lambda.min. Selecting top features with largest absolute paths.")
    all_coefs_dense <- as.matrix(coef(fit, s = min(fit$lambda)))
    all_coefs_dense <- all_coefs_dense[rownames(all_coefs_dense) != "(Intercept)", , drop = FALSE]
    sorted_idx <- order(abs(all_coefs_dense[, 1]), decreasing = TRUE)
    top_n <- min(5, nrow(all_coefs_dense))
    selected_genes <- rownames(all_coefs_dense)[sorted_idx[1:top_n]]
    selected_coefs <- all_coefs_dense[sorted_idx[1:top_n], 1]
  }''',
     r'''  # lambda.min 无基因时禁止静默凑数 (contracts G-04: report, do not fabricate)
  if (length(selected_genes) == 0) {
    stop("[GATE ERROR] LASSO selected NO genes at lambda.min. Refusing top-N fabrication (contracts G-04). Check feature matrix / separability.")
  }'''),
])

print("\n".join(report))
print("PART3_DONE")
