---
name: bio-07-ml-lasso
description: >-
  LASSO 惩罚回归特征筛选。当用户需要从候选基因中通过 L1 正则化筛选
  最优特征子集、绘制回归系数路径图和交叉验证曲线时，使用此技能。
---

# LASSO 回归特征筛选

## 依赖声明

### MCP 服务
- 无

### R 包
- `glmnet`

### 输入
- `merged_file.txt` — 候选基因表达矩阵（行=基因, 列=样本）
- 二分类标签（从样本名解析或外部提供）

### 输出
- `lasso.pdf` — LASSO 回归系数路径图
- `cvfit.pdf` — 交叉验证曲线图
- `LASSO.gene.txt` — 筛选出的特征基因列表

## 前置步骤

如果候选基因的表达量尚未从全基因表达矩阵中提取，先运行 [gene_expression_match.R](./scripts/gene_expression_match.R)：
- 读取 `merge.normalize.txt` 和 `candidate_hub_genes.txt`（或 `molgene.csv`）
- 通过 merge 匹配提取候选基因的表达量
- 输出 `merged_file.txt`

## 执行步骤

1. 运行 [lasso_regression.R](./scripts/lasso_regression.R)：
   - `set.seed(12345)`
   - 读取 `merged_file.txt`，转置为样本×基因矩阵
   - 从样本名解析分组标签（如 `GSE10030_biofilm1` → `biofilm`）
   - `glmnet(x, y, family="binomial", alpha=1)` 构建模型
   - 绘制系数路径图
   - `cv.glmnet(..., nfolds=10)` 交叉验证
   - 绘制交叉验证曲线
   - 提取 `lambda.min` 对应的非零系数基因
   - 输出 `LASSO.gene.txt`

## Gate 校验
- `LASSO.gene.txt` 非空（至少 1 个基因）

## 参考原始脚本
- [geoGene07.基因名与表达量匹配.R](../../raw_code/geoGene07.基因名与表达量匹配.R)
- [geoGene08.lasso.R](../../raw_code/geoGene08.lasso.R)
