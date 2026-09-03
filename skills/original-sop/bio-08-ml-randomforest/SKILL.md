---
name: bio-08-ml-randomforest
description: >-
  随机森林变量重要性分析。当用户需要通过随机森林和置换检验评估候选基因
  的分类重要性（MeanDecreaseGini）、筛选显著特征基因时，使用此技能。
---

# 随机森林特征重要性分析

## 依赖声明

### R 包
- `randomForest`, `ggplot2`, `RColorBrewer`；`rfPermute`（可选，缺失时用内置置换检验）

### 输入
- 候选基因表达矩阵（`merged_file.txt`）
- `--group` — 分组 metadata CSV（sample, group 列；**必传**）

### 输出
- `richness.txt` — 变量重要性得分表（含**真实**置换检验 p 值）
- `rf_importance.pdf` — MeanDecreaseGini 排序图
- `rf_genes.txt` — 显著特征基因列表（p < 0.05）

## 执行步骤

1. 运行 [random_forest_importance.R](./scripts/random_forest_importance.R)：
   - `set.seed(12345)`；分组来自 --group（fail-closed）
   - rfPermute 或内置置换检验（nrep=299, cores 可配）
   - 每个置换核对 rownames 对齐（防错位）
   - 提取 `importance()` 得分矩阵 + 真实 p 值
   - 筛选 p < 0.05 的基因输出到 `rf_genes.txt`

## Gate 校验
- 至少 1 个基因的置换检验 p < 0.05；`rf_genes.txt` 非空
- **禁止伪造 p 值**（如固定 0.02）；无有效 p 值来源时报错退出（G-04）

## 版本说明
- 2026-09-03 (spec-007): 删假 p=0.02（F-08 收窄确认）；置换 rownames 对齐校验；group fail-closed
