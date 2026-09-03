---
name: bio-10-biomarker-roc
description: >-
  诊断标志物 ROC 曲线验证。当用户需要评估筛选出的 Hub 基因作为诊断标志物
  的效能、绘制 ROC 曲线并计算 AUC 值时，使用此技能。
---

# ROC 曲线验证

## 依赖声明

### MCP 服务
- 无

### R 包
- `pROC`, `ggplot2`

### 输入
- 验证集/训练集表达谱（包含 Hub 基因的表达量）
- Hub 基因列表（`final_hub_genes.txt`）
- 真实分组标签

### 输出
- `roc_single_gene.pdf` — 单基因 ROC 曲线
- `roc_combined.pdf` — 多基因联合 ROC 曲线
- `auc_report.csv` — AUC 值与置信区间

## 执行步骤

1. 运行 [roc_validation.R](./scripts/roc_validation.R)：
   - 读取表达矩阵与分组标签
   - 对每个 Hub 基因：
     - `roc(response, predictor)` 计算 ROC
     - `auc()` 计算 AUC 值和 95% 置信区间
     - 绘制单基因 ROC 曲线
   - 对所有 Hub 基因：
     - 使用 logistic 回归构建联合模型
     - 计算联合 ROC 与 AUC
   - 汇总 AUC 报表（基因名、AUC、CI_lower、CI_upper、灵敏度、特异度）

## Gate 校验
- 单基因 AUC > 0.7 或联合 AUC > 0.8
- 图形文件非空

## 参考
- PPT Slide 10: "诊断标志物的验证 ROC 分析"
- 微生信网站 ROC 工具: https://www.bioinformatics.com.cn/
