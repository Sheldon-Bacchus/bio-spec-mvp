---
name: bio-10-biomarker-roc
description: >-
  诊断标志物 ROC 曲线验证。当用户需要评估筛选出的 Hub 基因作为诊断标志物
  的效能、绘制 ROC 曲线并计算 AUC 值时，使用此技能。
---

# ROC 曲线验证

## 依赖声明

### R 包
- `pROC`, `ggplot2`

### 输入
- 验证集/训练集表达谱（`merged_file.txt` 或独立验证矩阵）
- Hub 基因列表（`final_hub_genes.txt`）
- `--group` — 真实分组标签（必传）

### 输出
- `roc_single_gene.pdf` — 单基因 ROC 曲线
- `roc_combined.pdf` — 多基因联合 ROC 曲线（**OOF**）
- `auc_report.csv` — AUC 值与置信区间（含 Type 标记 `Combined(OOF)`）

## 执行步骤

1. 运行 [roc_validation.R](./scripts/roc_validation.R)：
   - 读取表达矩阵与分组标签
   - 对每个 Hub 基因：`roc(response, predictor)` + `auc()` + 单基因 ROC
   - 对所有 Hub 基因：**k-fold 分层 Out-Of-Fold 预测概率**构建联合模型 → 联合 OOF ROC/AUC
     （禁止 in-sample 拟合+同批评估；报告标注 Combined(OOF)）
   - 汇总 AUC 报表（基因名、AUC、CI、灵敏、特异度）

## Gate 校验
- 单基因 AUC > 0.7 或联合 **OOF** AUC > 0.8（in-sample AUC 不参与判定）

## 版本说明
- 2026-09-03 (spec-007): 联合模型改 k-fold OOF（F-03）；Type 标记 Combined(OOF)；header 黑名单修正
