---
name: bio-08-ml-randomforest
description: >-
  随机森林变量重要性分析。当用户需要通过随机森林和置换检验评估候选基因
  的分类重要性（MeanDecreaseGini）、筛选显著特征基因时，使用此技能。
---

# 随机森林特征重要性分析

## 依赖声明

### MCP 服务
- 无

### R 包
- `randomForest`, `rfPermute`, `ggplot2`, `RColorBrewer`, `tidyverse`

### 输入
- 候选基因表达矩阵（包含 `disease` 分类列）

### 输出
- `richness.txt` — 变量重要性得分表（含置换检验 p 值）
- `rf_importance.pdf` — MeanDecreaseGini 排序图
- `rf_genes.txt` — 显著特征基因列表（p < 0.05）

## 执行步骤

1. 运行 [random_forest_importance.R](./scripts/random_forest_importance.R)：
   - `set.seed(12345)`
   - `rfPermute(disease ~ ., data=data, ntree=500, nrep=299, num.cores=2)` 并行置换随机森林
   - 提取 `importance()` 得分矩阵
   - 添加显著性标记（*** p<0.001, ** p<0.01, * p<0.05）
   - ggplot2 绘制 MeanDecreaseGini 排序图（水平翻转）
   - 筛选 p < 0.05 的基因输出到 `rf_genes.txt`

## Gate 校验
- 至少 1 个基因的置换检验 p < 0.05
- `rf_genes.txt` 非空

## 参考原始脚本
- [geoGene09.randomforest_p.R（修改版）.R](./scripts/random_forest_importance.R)
