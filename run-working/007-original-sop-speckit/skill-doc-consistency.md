# SKILL.md ↔ 脚本一致性审计 (T018 prep)

**Date**: 2026-09-03 | **方法**: SKILL.md 依赖声明段 vs 脚本实际 library() 调用（Select-String 提取）

## 依赖声明差异

| Stage | SKILL.md 声明 | 脚本实际 library() | 差异 |
|---|---|---|---|
| S01 geo-dataprep | GEOquery, Biobase, impute, limma | limma, impute, Biobase | **GEOquery 声明但脚本未用**（SKILL.md 步骤说"通过 biomcp 或 GEOquery 获取元数据"——脚本只读本地矩阵文件；GEOquery 是软依赖，应标注 optional 或删） |
| S02 batch-norm | limma, sva, oligo, ggplot2, tidyverse | limma, sva, ggplot2, gridExtra | **oligo、tidyverse 声明但未用**；gridExtra 用了但未声明 |
| S03 wgcna | WGCNA, flashClust | WGCNA（×2 脚本） | flashClust 未显式加载（WGCNA 内置依赖，可删或标注） |
| S04 deg-limma | limma, pheatmap, dplyr, ggplot2, ggrepel | limma, pheatmap（limma_diff）; dplyr, ggplot2, ggrepel（volcano） | 一致（两脚本拆分） |
| S05 enrichment | clusterProfiler, pathview, org.Hs.eg.db | clusterProfiler, enrichplot, ggplot2 | **pathview 声明但脚本未调用**（SKILL.md 步骤 2 说 "pathview() 绘制通路图"，脚本无 pathview 调用）；org.Hs.eg.db 条件加载 OK；enrichplot 未声明但用了 |
| S06 gene-intersection | VennDiagram, UpSetR | VennDiagram, grid | UpSetR 仅备注提及（3+ 组时建议），未实际加载——OK（optional） |
| S07 ml-lasso | glmnet | glmnet | 一致（gene_expression_match 无包依赖，OK） |
| S08 ml-randomforest | randomForest, rfPermute, ggplot2, RColorBrewer, tidyverse | randomForest, ggplot2, RColorBrewer（rfPermute requireNamespace optional） | tidyverse 声明未用；rfPermute 标记 optional 与 SKILL.md 一致（脚本有 fallback，但 P0 修复后应明确） |
| S09 hub-literature | 无 | 无 | 一致 |
| S10 biomarker-roc | pROC, ggplot2 | pROC, ggplot2 | 一致 |
| Orchestrator | （环境检查需 limma, sva, WGCNA, glmnet, randomForest, pROC 等） | required_pkgs=c(glmnet, randomForest, pROC, ggplot2, VennDiagram); optional=c(rfPermute, limma, sva, WGCNA, clusterProfiler, UpSetR) | **limma/sva/WGCNA/clusterProfiler 放 optional 但编排的 S02/S03/S05 强依赖 → 依赖清单错误**（P1） |

## 参数声明差异

| Stage | SKILL.md 声称 | 脚本实际 | 差异 |
|---|---|---|---|
| S08 | "num.cores=2" | 默认 `num_cores=1`（L28） | 不一致（P1） |
| S07 | "nfolds=10" | 默认 nfolds=10 + min_class_size 自动调 | 一致（合理兜底） |
| S10 | "AUC > 0.7 或联合 > 0.8" | auc_gate_single=0.70, auc_gate_combined=0.80 | 一致 |
| S03 | "默认 5515 个 top MAD 基因" | 默认 n_genes=5000（L58 附近 defaults） | **不一致**（SKILL.md 5515 vs 脚本 5000）|

## 参考链接差异

| Stage | SKILL.md 参考 | 实际 | 差异 |
|---|---|---|---|
| S05 | "geoGene01.数据预处理最终版.R（KEGG 部分）" 指向 `../bio-01-geo-dataprep/scripts/geo_preprocess.R` | geo_preprocess 无 KEGG 代码 | **引用错误**（P1） |
| S04 | 参考 geoGene05.diff.R / geoGene06.vol.R | limma_diff.R / volcano_heatmap.R 对应 | 一致（对映重命名） |

## 修复建议（进 T018）

1. S01: SKILL.md 删 GEOquery 或标注 optional（脚本不依赖）。
2. S02: SKILL.md 删 oligo/tidyverse，补 gridExtra。
3. S05: SKILL.md 删 pathview 或脚本补 pathview() 实现（建议删——cnetplot 已覆盖）；补 enrichplot。
4. S08: SKILL.md 删 tidyverse；明确 rfPermute optional + 真实置换 fallback。
5. S03: SKILL.md "5515" → "5000"（或脚本默认改 5515，按 PPT 原始值——建议脚本对齐 5515 以保 PPT 复现）。
6. Orchestrator: 依赖清单修正——limma/sva/WGCNA/clusterProfiler 进 required。
7. S05 SKILL.md 参考链接修正为 enrichment_analysis.R 自身。
