---
name: bio-09-hub-literature
description: >-
  Hub 基因确定与科学文献证据挖掘。当用户需要取 LASSO 与随机森林双算法交集
  确定最终关键基因、并通过 Scite 等学术数据库检索文献支撑其生物学意义时，
  使用此技能。
---

# Hub 基因确定与文献挖掘

## 依赖声明

### MCP 服务
- `scite-mcp`（可选）— 检索 Hub 基因的 Smart Citations
- `biomcp`（可选）— `biomcp gene <symbol>` 查询基因功能

### 输入
- `LASSO.gene.txt` — LASSO 筛选基因列表
- `rf_genes.txt` — 随机森林筛选基因列表

### 输出
- `final_hub_genes.txt` — **双算法交集**（空交集→报错+人工评审，**禁止并集 fallback**）
- `hub_intersection_summary.txt` — Jaccard + 各集大小
- `literature_evidence_report.md` — 文献证据报告（人工确认）

## 执行步骤

1. 运行 [hub_gene_intersection.R](./scripts/hub_gene_intersection.R)：
   - 读取 `LASSO.gene.txt` 和 `rf_genes.txt`
   - `intersect()` 取交集；计算 Jaccard
   - **交集为空 → GATE ERROR 报错退出，强制人工评审**（G-06；评审决定记录后手动放行）
   - 输出 `final_hub_genes.txt`
2. 对每个 Hub 基因，调用 MCP 服务检索文献证据，生成报告

## Gate 校验
- `final_hub_genes.txt` 非空（至少 1 个基因，**真交集**非并集）
- 至少 1 个基因有 ≥ 3 篇 supporting citations（文献步骤）

## 版本说明
- 2026-09-03 (spec-007): 删并集 fallback（F-04）；header 黑名单修正（x/V1 不再误删）
