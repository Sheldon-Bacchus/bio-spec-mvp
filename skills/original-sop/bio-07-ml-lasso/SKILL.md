---
name: bio-07-ml-lasso
description: >-
  LASSO 惩罚回归特征筛选。当用户需要从候选基因中通过 L1 正则化筛选
  最优特征子集、绘制回归系数路径图和交叉验证曲线时，使用此技能。
---

# LASSO 回归特征筛选

## 依赖声明

### R 包
- `glmnet`

### 输入
- `merged_file.txt` — 候选基因表达矩阵（行=基因, 列=样本）
- `--group` — 分组 metadata CSV（sample, group 列；**必传，fail-closed**）

### 输出
- `LASSO.gene.txt` — lambda.min 非零系数基因
- `LASSO.gene.1se.txt` — lambda.1se 非零系数基因（双 lambda 报告）
- `lasso_coefficients.csv` — 基因/系数表
- `lasso.pdf` / `cvfit.pdf` — 路径图/CV 曲线

## 前置步骤

如果候选基因的表达量尚未从全基因表达矩阵中提取，先运行 [gene_expression_match.R](./scripts/gene_expression_match.R)：
- 读取 `merge.normalize.txt` 和 `candidate_hub_genes.txt`（或 `molgene.csv`）
- 通过 merge 匹配提取候选基因的表达量
- 输出 `merged_file.txt`

## 执行步骤

1. 运行 [lasso_regression.R](./scripts/lasso_regression.R)：
   - `set.seed(12345)`；分层 foldid（每类内划分，可复现）
   - `glmnet(x, y, family="binomial", alpha=1)` 构建模型
   - `cv.glmnet(..., foldid=分层foldid)` 交叉验证
   - 提取 `lambda.min` 和 `lambda.1se` 非零系数基因（双列表）
   - 输出 `LASSO.gene.txt` + `LASSO.gene.1se.txt`
2. **分组标签必须来自 --group 文件**；缺失或样本不匹配 → 报错退出（禁止样本名正则推断）

## Gate 校验
- `LASSO.gene.txt` 非空（至少 1 个基因）；lambda.min 空时**报错拒绝凑数**（G-04）

## 版本说明
- 2026-09-03 (spec-007): 分层 foldid（F-02）；双 lambda 列表；group fail-closed（G-03）；删 top-N 凑数 fallback
