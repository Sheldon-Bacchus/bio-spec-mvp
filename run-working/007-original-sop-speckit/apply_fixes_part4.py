# -*- coding: utf-8 -*-
"""apply_fixes_part4.py — ROC OOF 主块精确补丁"""
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

patch("bio-10-biomarker-roc/scripts/roc_validation.R", [
    # ---- OOF 主块 ----
    (r'''  # 2. Multivariable Logistic Regression Combined ROC
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
     r'''  # 2. Multivariable Logistic Regression Combined ROC (k-fold OUT-OF-FOLD; no in-sample AUC per contracts G-04)
  combined_roc <- NULL
  if (length(matched_hubs) >= 2) {
    cat("[INFO] Building multivariable logistic regression panel with k-fold OUT-OF-FOLD prediction...\n")
    sub_df <- expr_t[, matched_hubs, drop = FALSE]
    sub_df$disease <- ifelse(y == levels_y[2], 1, 0)
    
    # k-fold OOF probabilities (balanced; min 3 samples/fold; LOO fallback for tiny cohorts)
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
    # ---- gate 判定用 OOF ----
    (r'''  max_single_auc <- max(report_df$AUC[report_df$Type == "Single"], na.rm = TRUE)
  comb_auc_val <- if ("Combined" %in% report_df$Type) report_df$AUC[report_df$Type == "Combined"][1] else 0''',
     r'''  max_single_auc <- max(report_df$AUC[report_df$Type == "Single"], na.rm = TRUE)
  comb_auc_val <- if ("Combined(OOF)" %in% report_df$Type) report_df$AUC[report_df$Type == "Combined(OOF)"][1] else 0'''),
])

print("\n".join(report))
print("PART4_DONE")
