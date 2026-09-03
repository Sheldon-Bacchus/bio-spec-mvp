---
name: bio-02-batch-norm
description: >-
  多数据集归一化与批次效应校正。当用户合并多个 GEO 芯片数据集、
  需要 ComBat/SVA 去除批次效应、并通过 PCA 与箱线图验证效果时，使用此技能。
---

# 归一化与去批次效应

## 依赖声明

### MCP 服务
- 无

### R 包
- `limma` (avereps), `sva` (ComBat), `oligo`, `ggplot2`, `tidyverse`

### 输入
- 多个 `{gse_id}.normalize.txt` 文件
- 批次标识（各文件对应哪个批次）
- `PD.csv` — 分组信息（sample + group）

### 输出
- `merge.normalize.txt` — 去批次后合并矩阵
- `merge.preNorm.txt` — 去批次前合并矩阵（对照）
- `boxplot_comparison.pdf` — 批次效应前后箱线图
- `pca_qc.pdf` — PCA 质控图

## 执行步骤

1. 运行 [sva_combat.R](./scripts/sva_combat.R)：
   - 读取所有数据集，提取交集基因
   - 合并并记录批次编号
   - 输出 `merge.preNorm.txt`（去批次前）
   - 使用 `ComBat(allTab, batchType)` 去除批次效应
   - 输出 `merge.normalize.txt`
   - 绘制前后对比箱线图
2. 运行 [pca_qc.R](./scripts/pca_qc.R)：
   - 读取 `merge.normalize.txt` 和 `PD.csv`
   - 按生物学分组绘制 PCA（同组应聚集）
   - 按批次绘制 PCA（各批次应混合）

## Gate 校验
- `merge.normalize.txt` 存在且行数 > 0
- 箱线图中位线基本对齐（视觉检查）
- PCA 图中同组样本聚集、批次混合

## 参考原始脚本
- [geoGene02.normalize.R](../../raw_code/geoGene02.normalize.R)
- [geoGene03.sva.R](../../raw_code/geoGene03.sva.R)
- [geoGene04.PCA.R](../../raw_code/geoGene04.PCA.R)
