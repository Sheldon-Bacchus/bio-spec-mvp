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
- 表达谱（含 discovery 与 validation partition 的 canonical metadata）
- Hub 基因列表（`final_hub_genes.txt`）
- `--metadata` / `--manifest` / `--source-revision` — canonical metadata、run manifest、源版本（必传）

### 输出
- `roc_single_gene.pdf` — 单基因 ROC 曲线
- `roc_combined.pdf` — 多基因联合 ROC 曲线（只用 independent validation score）
- `auc_report.csv` — AUC 值与置信区间（含 validation boundary/type）

## 执行步骤

1. 运行 [roc_validation.R](./scripts/roc_validation.R)：
   - 读取表达矩阵与 canonical metadata
   - 对每个 Hub 基因：`roc(response, predictor)` + `auc()` + 单基因 ROC
   - 对所有 Hub 基因：只在 discovery 拟合并锁定特征，在 independent validation 上打分；禁止 same-data AUC。分区缺失或重叠时标记 exploratory/negative。
   - 汇总 AUC 报表（基因名、AUC、CI、灵敏、特异度）

## Gate 校验
- 独立 validation AUC 达到预设阈值；缺失或重叠 validation 不得作为独立性能结论

## 版本说明
- 2026-09-15 (spec-008): discovery/validation boundary enforced；same-data metrics are exploratory; provenance/status recorded
