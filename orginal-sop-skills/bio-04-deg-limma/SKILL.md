---
name: bio-04-deg-limma
description: >-
  基于 limma 的差异表达基因分析。当用户需要在两组条件间筛选差异表达基因、
  绘制火山图与聚类热图时，使用此技能。
---

# 差异表达分析 (limma)

## 依赖声明

### MCP 服务
- 无

### R 包
- `limma`, `pheatmap`, `dplyr`, `ggplot2`, `ggrepel`

### 输入
- 表达矩阵（`merge.normalize.txt` 或指定文件）
- `s1.txt` — 对照组样本名列表
- `s2.txt` — 实验组样本名列表

### 输出
- `all.txt` — 全量差异结果（logFC + P.Value + adj.P.Val）
- `diff.txt` — 显著差异基因（|logFC| > 1 且 adj.P.Val < 0.05）
- `diffGeneExp.txt` — 差异基因表达量
- `heatmap.pdf` — 差异基因聚类热图
- `vol.pdf` — 火山图

## 执行步骤

1. 运行 [limma_diff.R](./scripts/limma_diff.R)：
   - 读取表达矩阵，重复基因取均值（`avereps`）
   - 过滤低表达基因（`rowMeans > 0`）
   - 构建设计矩阵 `~0+factor(Type)`
   - `lmFit` → `contrasts.fit` → `eBayes` → `topTable`
   - 按阈值筛选显著基因
   - 绘制热图（取 top 50 上下调基因）
2. 运行 [volcano_heatmap.R](./scripts/volcano_heatmap.R)：
   - 读取 `all.txt`
   - ggplot2 火山图，标注显著基因名

## Gate 校验
- 差异基因数量 > 0
- `all.txt` 包含 logFC 和 adj.P.Val 列
- 图形文件非空

## 可配置参数
- `logFCfilter` — logFC 过滤阈值（默认 1）
- `adj.P.Val.Filter` — FDR 阈值（默认 0.05）
- `geneNum` — 热图显示基因数（默认 50）

## 参考原始脚本
- [geoGene05.diff.R](../../raw_code/geoGene05.diff.R)
- [geoGene06.vol.R](../../raw_code/geoGene06.vol.R)
