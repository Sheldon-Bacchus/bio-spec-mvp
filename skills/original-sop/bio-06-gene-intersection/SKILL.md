---
name: bio-06-gene-intersection
description: >-
  多基因集交集运算与韦恩图绘制。当用户需要将 WGCNA 模块基因与差异表达基因取交集、
  筛选候选 Hub 基因时，使用此技能。
---

# 基因集交集与韦恩图

## 依赖声明

### R 包
- `VennDiagram`, `grid`；`UpSetR`（3+ 组时可选）

### 输入
- `module_genes.csv`（或 `candidate_hub_genes_wgcna.txt`）— WGCNA 模块基因集
- `diff.txt`（或 `candidate_hub_genes_deg.txt`）— DEG 信号基因集

### 输出
- `candidate_hub_genes.txt` — 交集候选基因列表
- `venn_plot.pdf` — 韦恩图

## 执行步骤

1. 运行 [venn_intersection.R](./scripts/venn_intersection.R)：读取两基因集 → `intersect()` → VennDiagram → 输出交集

## Gate 校验
- 交集基因数量 ≥ 2（否则 WARN + 人工确认）；`candidate_hub_genes.txt` 非空

## 备注
- 3+ 组基因集建议用 UpSetR

## 版本说明
- 2026-09-03 (spec-007): 依赖一致化（grid 补记）
