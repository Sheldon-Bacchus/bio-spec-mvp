---
name: bio-05-enrichment
description: >-
  差异基因功能富集分析。当用户需要对差异基因列表进行 GO (BP/CC/MF) 和
  KEGG 通路富集分析、生成气泡图/条形图/通路图时，使用此技能。
---

# 功能富集分析 (GO + KEGG)

## 依赖声明

### MCP 服务
- `biomcp` — `biomcp enrich <gene_list>` 快速 g:Profiler 富集；`biomcp pathway <id>` 通路查询

### R 包
- `clusterProfiler`, `pathview`, `org.Hs.eg.db`（或对应物种的注释包）

### 输入
- 显著差异基因列表（Symbol 或 ENTREZID + logFC）

### 输出
- `GO_enrichment.csv` — GO 三类富集结果
- `KEGG_enrichment.csv` — KEGG 通路富集结果
- `GO_barplot.pdf` / `KEGG_barplot.pdf` — 富集可视化
- `KEGG_cnetplot.pdf` — 基因-通路网络图

## 执行步骤

1. 可选：通过 `biomcp enrich` 快速评估富集概况
2. 运行 [enrichment_analysis.R](./scripts/enrichment_analysis.R)：
   - Symbol → ENTREZID 转换
   - `enrichGO()` 进行 GO 富集（BP/CC/MF）
   - `enrichKEGG()` 进行 KEGG 富集
   - 绘制条形图、网络图
   - `pathview()` 绘制通路图

## Gate 校验
- 至少 1 个 GO term 显著 (q < 0.05)
- 至少 1 条 KEGG 通路显著 (q < 0.05)

## 参考原始脚本
- [geoGene01.数据预处理最终版.R](../bio-01-geo-dataprep/scripts/geo_preprocess.R) （KEGG 部分）
