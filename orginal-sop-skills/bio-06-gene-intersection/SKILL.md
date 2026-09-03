---
name: bio-06-gene-intersection
description: >-
  多基因集交集运算与韦恩图绘制。当用户需要将 WGCNA 模块基因与差异表达基因取交集、
  筛选候选 Hub 基因时，使用此技能。
---

# 基因集交集与韦恩图

## 依赖声明

### MCP 服务
- 无

### R 包
- `VennDiagram`, `UpSetR`

### 输入
- `module_genes.csv` — WGCNA 目标模块基因集
- `diff.txt` — DEG 显著差异基因集

### 输出
- `candidate_hub_genes.txt` — 交集候选基因列表
- `venn_plot.pdf` — 韦恩图

## 执行步骤

1. 运行 [venn_intersection.R](./scripts/venn_intersection.R)：
   - 读取两个基因列表
   - 使用 `intersect()` 取交集
   - 使用 VennDiagram 包绘制韦恩图
   - 输出交集基因列表

## Gate 校验
- 交集基因数量 ≥ 2
- `candidate_hub_genes.txt` 非空

## 备注
- 也可使用在线工具: https://bioinformatics.psb.ugent.be/webtools/Venn/
- 如有 3+ 组基因集，建议用 UpSetR 替代韦恩图

## 参考
- PPT Slide 6 逻辑
