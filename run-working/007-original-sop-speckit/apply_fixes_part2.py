# -*- coding: utf-8 -*-
"""
apply_fixes_part2.py — spec-007 ML trio P0 修复 (LASSO / RF / ROC)
追加到 apply_fixes.py 后统一运行；精确替换 + 计数。
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
    report.append("OK   %s :: %d replacements" % (path, n))
    return n

# ============================================================
# S07 LASSO P0: 分层 foldid + 双 lambda 列表 + group fail-closed
# ============================================================
patch("bio-07-ml-lasso/scripts/lasso_regression.R", [
    # 1. group file 必传（fail-closed）——移除样本名解析 fallback 分支
    ('''  if (!is.null(params$group_file) && file.exists(params$group_file)) {
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
     '''  if (is.null(params$group_file) || !file.exists(params$group_file)) {
    stop("[GATE ERROR] --group file is REQUIRED for LASSO (contracts G-03 fail-closed: explicit metadata only, no sample-name parsing). Provide sample group metadata CSV.")
  }
  cat(sprintf("[INFO] Extracting sample labels from metadata: %s\n", params$group_file))
  group_df <- read.csv(params$group_file, stringsAsFactors = FALSE, check.names = FALSE)
  sample_col <- if ("sample" %in% colnames(group_df)) "sample" else colnames(group_df)[1]
  label_col <- if ("group" %in% colnames(group_df)) "group" else colnames(group_df)[2]
  
  label_map <- setNames(as.character(group_df[[label_col]]), as.character(group_df[[sample_col]]))
  y_raw <- label_map[sample_names]
  
  unmatched <- sum(is.na(y_raw))
  if (unmatched > 0) {
    stop(sprintf("[GATE ERROR] %d samples did not match the group file (contracts G-03: fail-closed on label mismatch). Check sample names / batch prefixes.", unmatched))
  }'''),
    # 2. 分层 foldid + foldid 传给 cv.glmnet
    ('''  # 2. Cross-validation to find optimal lambda
  cat(sprintf("[INFO] Performing %d-fold cross-validation with deviance metric...\n", actual_nfolds))
  cvfit <- cv.glmnet(
    x, y, 
    family = params$family, 
    alpha = params$alpha, 
    type.measure = "deviance", 
    nfolds = actual_nfolds
  )''',
     '''  # 2. Cross-validation to find optimal lambda (stratified foldid, reproducible)
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
    # 3. lambda.1se 列表导出
    ('''  # Export gene list
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
     '''  # Export gene list (lambda.min)
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
    # 4. top-5 凑数 fallback -> 不允许静默（改为 stop）
    ('''  # If lambda.min yielded no genes, fallback to lambda.1se or top 3 coefficients
  if (length(selected_genes) == 0) {
    warning("[WARN] No non-zero coefficients at lambda.min. Selecting top features with largest absolute paths.")
    all_coefs_dense <- as.matrix(coef(fit, s = min(fit$lambda)))
    all_coefs_dense <- all_coefs_dense[rownames(all_coefs_dense) != "(Intercept)", , drop = FALSE]
    sorted_idx <- order(abs(all_coefs_dense[, 1]), decreasing = TRUE)
    top_n <- min(5, nrow(all_coefs_dense))
    selected_genes <- rownames(all_coefs_dense)[sorted_idx[1:top_n]]
    selected_coefs <- all_coefs_dense[sorted_idx[1:top_n], 1]
  }''',
     '''  # lambda.min 无基因时禁止静默凑数（contracts G-04: report, do not fabricate）
  if (length(selected_genes) == 0) {
    stop("[GATE ERROR] LASSO selected NO genes at lambda.min. Check feature matrix / separability. Refusing top-N fabrication (contracts G-04).")
  }'''),
])

# ============================================================
# S08 RF P0: 删假 p=0.02 + rownames 对齐校验
# ============================================================
patch("bio-08-ml-randomforest/scripts/random_forest_importance.R", [
    # 1. 删伪造 p=0.02
    ('''    } else {
      # Compute empirical p-value if column not explicitly present
      richness_data$p_value <- 0.02
    }''',
     '''    } else {
      stop("[GATE ERROR] rfPermute result lacks MeanDecreaseGini.pval and no valid empirical p-value source is available. Refusing fabricated p-values (contracts G-04).")
    }'''),
    # 2. 手动置换循环 rownames 对齐校验
    ('''    for (p_idx in seq_len(ncol(perm_gini))) {
      perm_data <- data_df
      perm_data$disease <- sample(perm_data$disease)
      m_perm <- randomForest::randomForest(disease ~ ., data = perm_data, ntree = 200, importance = FALSE)
      perm_imp <- randomForest::importance(m_perm, type = 2)
      perm_gini[, p_idx] <- perm_imp[, 1]
    }''',
     '''    for (p_idx in seq_len(ncol(perm_gini))) {
      perm_data <- data_df
      perm_data$disease <- sample(perm_data$disease)
      m_perm <- randomForest::randomForest(disease ~ ., data = perm_data, ntree = 200, importance = FALSE)
      perm_imp <- randomForest::importance(m_perm, type = 2)
      stopifnot("Permutation rownames must align with observed importance" = identical(rownames(perm_imp), rownames(imp_raw)))
      perm_gini[, p_idx] <- perm_imp[, 1]
    }'''),
])

# ============================================================
# S10 ROC P0: 联合模型改 k-fold OOF AUC + header 黑名单已修 + 报告 OOF 标记
# ============================================================
patch("bio-10-biomarker-roc/scripts/roc_validation.R", [
    # 1. 联合模型: in-sample glm -> k-fold OOF
    ('''  # 2. Multivariable Logistic Regression Combined ROC
  combined_roc <- NULL
  if (length(matched_hubs) >= 2) {
    cat("[INFO] Building multivariable logistic regression model for combined biomarker panel...\n")
    sub_df <- expr_t[, matched_hubs, drop = FALSE]
    sub_df$disease <- ifelse(y == levels_y[2], 1, 0)
    
    # Fit binomial GLM
    glm_fit <- tryCatch({
      glm(disease ~ ., data = sub_df, family = binomial(link = "logit"))
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(glm_fit)) {
      prob_pred <- predict(glm_fit, type = "response")
      combined_roc <- tryCatch({
        pROC::roc(response = sub_df$disease, predictor = prob_pred, quiet = TRUE, ci = TRUE)
      }, error = function(e) {
        NULL
      })''',
     '''  # 2. Multivariable Logistic Regression Combined ROC (k-fold OUT-OF-FOLD; contracts G-04: no in-sample AUC)
  combined_roc <- NULL
  if (length(matched_hubs) >= 2) {
    cat("[INFO] Building multivariable logistic regression panel with k-fold OUT-OF-FOLD prediction (no in-sample AUC)...\n")
    sub_df <- expr_t[, matched_hubs, drop = FALSE]
    sub_df$disease <- ifelse(y == levels_y[2], 1, 0)
    
    # k-fold OOF probabilities (balanced folds; min 3 samples/fold)
    n_oof <- nrow(sub_df)
    k_fold <- if (n_oof >= 12) 5 else if (n_oof >= 6) 3 else 2
    set.seed(12345)
    foldid <- integer(n_oof)
    for (lv in unique(sub_df$disease)) {
      idx <- which(sub_df$disease == lv)
      kk <- min(k_fold, length(idx))
      foldid[idx] <- sample(rep(seq_len(kk), length.out = length(idx)))
    }
    oof_prob <- rep(NA_real_, n_oof)
    for (k_idx in seq_len(k_fold)) {
      tr <- which(foldid != k_idx)
      te <- which(foldid == k_idx)
      if (length(unique(sub_df$disease[tr])) < 2 || length(te) < 1) next
      glm_k <- tryCatch(
        glm(disease ~ ., data = sub_df, subset = tr, family = binomial(link = "logit")),
        error = function(e) NULL
      )
      if (!is.null(glm_k)) {
        oof_prob[te] <- predict(glm_k, newdata = sub_df[te, , drop = FALSE], type = "response")
      }
    }
    
    if (all(!is.na(oof_prob)) && length(unique(oof_prob)) > 1) {
      combined_roc <- tryCatch({
        pROC::roc(response = sub_df$disease, predictor = oof_prob, quiet = TRUE, ci = TRUE)
      }, error = function(e) {
        NULL
      })'''),
    # 2b. Combined record: Type 标记 OOF
    ('''        auc_records[[length(auc_records) + 1]] <- data.frame(
          Gene = paste("Combined_Panel (", length(matched_hubs), " genes)", sep = ""),
          Type = "Combined",
          AUC = round(comb_auc, 4),''',
     '''        auc_records[[length(auc_records) + 1]] <- data.frame(
          Gene = paste("Combined_Panel (", length(matched_hubs), " genes)", sep = ""),
          Type = "Combined(OOF)",
          AUC = round(comb_auc, 4),'''),
    # 2c. Gate 判定用 OOF 标记
    ('''  max_single_auc <- max(report_df$AUC[report_df$Type == "Single"], na.rm = TRUE)
  comb_auc_val <- if ("Combined" %in% report_df$Type) report_df$AUC[report_df$Type == "Combined"][1] else 0''',
     '''  max_single_auc <- max(report_df$AUC[report_df$Type == "Single"], na.rm = TRUE)
  comb_auc_val <- if ("Combined(OOF)" %in% report_df$Type) report_df$AUC[report_df$Type == "Combined(OOF)"][1] else 0'''),
])

print("\n".join(report))
print("\nPART2_DONE")
