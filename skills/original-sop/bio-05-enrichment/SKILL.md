---
name: bio-05-enrichment
description: >-
  差异基因功能富集分析。当用户需要对差异基因列表进行 GO (BP/CC/MF) 和
  KEGG 通路富集分析、生成气泡图/条形图/通路图时，使用此技能。
---

# 功能富集分析 (GO + KEGG)

## 依赖声明

### MCP 服务
- `biomcp`（可选）— `biomcp enrich <gene_list>` 快速 g:Profiler 富集；`biomcp pathway <id>` 通路查询

### R 包
- `clusterProfiler`, `enrichplot`, `ggplot2`, `org.Hs.eg.db`（人类）

### 输入
- 显著差异基因列表（Symbol 或 ENTREZID + logFC），如 `diff.txt`
- `--species` — human (hsa) / pae（铜绿假单胞菌）

### 输出
- `GO_enrichment.csv` — GO 三类富集结果
- `KEGG_enrichment.csv` — KEGG 通路富集结果
- `GO_{ont}_barplot.pdf` / `GO_{ont}_dotplot.pdf` / `KEGG_barplot.pdf` / `KEGG_dotplot.pdf`

## 执行步骤

1. 可选：通过 `biomcp enrich` 快速评估富集概况
2. 运行 [enrichment_analysis.R](./scripts/enrichment_analysis.R)：
   - Symbol → ENTREZID 转换（bitr）
   - `enrichGO()` 进行 GO 富集（BP/CC/MF）
   - `enrichKEGG()` 进行 KEGG 富集
   - 绘制条形图、网络图

## Gate 校验
- 至少 1 个 GO term 显著 (q < 0.05) 或明确记录空结果
- 至少 1 条 KEGG 通路显著 (q < 0.05)（在线依赖失败时明确 WARN 记录）
- **0 基因可映射 → 显式报错（不静默输出空表）**

## 物种说明（contracts F-05）
- human: 完整 GO + KEGG
- pae: 仅 KEGG（GO 需专用 OrgDb 如 org.Pa.eg.db，未加载时显式跳过说明，不静默）

## 版本说明
- 2026-09-03 (spec-007): bitr 0 映射 fail-loud；pae GO 显式说明；cnetplot 参数适配（enrichplot 新版弃用 colorEdge/circular）
