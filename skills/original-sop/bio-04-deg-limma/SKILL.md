---
name: bio-04-deg-limma
description: >-
  基于 limma 的差异表达基因分析。当用户需要在两组条件间筛选差异表达基因、
  绘制火山图与聚类热图时，使用此技能。
---

# 差异表达分析 (limma)

## 依赖声明

### R 包
- `limma`, `pheatmap`, `dplyr`, `ggplot2`, `ggrepel`

### 输入
- 表达矩阵（`merge.normalize.txt` 或指定文件）
- `--pd` — 分组文件 PD.csv（sample + group；推荐）
- 兼容 `--s1` / `--s2` — control/treat 样本名列表

### 输出
- `all.txt` — 全量差异结果（logFC + P.Value + adj.P.Val）
- `diff.txt` — 显著差异基因（|logFC| > 1 且 adj.P.Val < 0.05）
- `diffGeneExp.txt` / `heatmap.pdf` / `vol.pdf`
- `candidate_hub_genes_deg.txt` — 显著基因列表（供 S06 交集）

## 执行步骤

1. 运行 [limma_diff.R](./scripts/limma_diff.R)：
   - 读取表达矩阵，`avereps` 重复基因取均值
   - `~0+Group` design → `lmFit` → `contrasts.fit` → `eBayes` → `topTable`
   - 按阈值筛选显著基因；绘制热图与火山图
2. 运行 [volcano_heatmap.R](./scripts/volcano_heatmap.R)：`all.txt` → ggplot2 火山图

## Gate 校验
- 差异基因数量 > 0；`all.txt` 含 logFC 和 adj.P.Val 列
- 分组解析：PD.csv 优先；**样本名推断仅作 WARN 降级 + inferred_groups.csv**（禁止静默半劈）

## 版本说明
- 2026-09-03 (spec-007): CLI 连字符参数修复；分组推断降级审计
