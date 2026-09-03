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
- **`scite-mcp`**（核心）— 检索 Hub 基因在目标领域的 Smart Citations，区分 supporting/mentioning/contrasting 引用类型，生成文献证据链
- **`biomcp`**（辅助）— `biomcp gene <symbol>` 查询基因功能；`biomcp article search <query>` 补充 PubMed 文献

### R 包
- 无特殊包（基础 `intersect()` 集合运算）

### 输入
- `LASSO.gene.txt` — LASSO 筛选基因列表
- `rf_genes.txt` — 随机森林筛选基因列表

### 输出
- `final_hub_genes.txt` — 双算法交集最终 Hub 基因
- `literature_evidence_report.md` — 文献证据报告

## 执行步骤

1. 运行 [hub_gene_intersection.R](./scripts/hub_gene_intersection.R)：
   - 读取 `LASSO.gene.txt` 和 `rf_genes.txt`
   - `intersect()` 取交集
   - 输出 `final_hub_genes.txt`

2. 对每个 Hub 基因，调用 MCP 服务：
   - `biomcp gene <symbol>` — 获取基因基本功能描述
   - `scite-mcp` — 检索该基因在目标领域（如 biofilm + Pseudomonas）的文献：
     - 统计 supporting / mentioning / contrasting 引用数量
     - 提取关键支持性文献的标题、作者、年份、DOI
   - `biomcp article search "<gene> <phenotype>"` — 补充 PubMed 检索

3. 生成 `literature_evidence_report.md`：
   - 每个 Hub 基因一个章节
   - 包含：基因功能摘要、文献证据链（支持/对立）、研究意义判断

## Gate 校验
- `final_hub_genes.txt` 非空（至少 1 个基因）
- 至少 1 个基因有 ≥ 3 篇 supporting citations

## 参考
- PPT Slide 9: "查文献，确定关键基因是否具有研究意义"
