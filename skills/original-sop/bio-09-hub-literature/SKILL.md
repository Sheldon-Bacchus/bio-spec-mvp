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
- `final_hub_genes.txt` — **双算法真交集**（空交集→typed `negative`，**禁止并集/复制 fallback**）
- `hub_intersection_summary.txt` — Jaccard + 各集大小
- `literature_evidence_report.md` — 文献证据报告（人工确认）

## 执行步骤

1. 运行 [hub_gene_intersection.R](./scripts/hub_gene_intersection.R)：
   - 读取 `LASSO.gene.txt` 和 `rf_genes.txt`
   - `intersect()` 取交集；计算 Jaccard
   - **交集为空 → 写入空结果和 typed `negative` 状态**；不得改成并集或复制列表。是否继续由 orchestrator 的失败/阴性策略和人工审阅决定。
   - 输出 `final_hub_genes.txt`
2. 对每个 Hub 基因，调用 MCP 服务检索文献证据，生成报告

## Gate 校验
- `final_hub_genes.txt` 非空（至少 1 个基因，**真交集**非并集）
- 文献步骤未调用合格 MCP 或未完成人工核验时，报告状态为 `skipped`/`manual_review`，不生成 supporting-citation claim。

## 版本说明
- 2026-09-15 (spec-008): true-intersection typed negative；no union/copy fallback；literature evidence is explicitly skipped/manual-review when no eligible evidence call is made
