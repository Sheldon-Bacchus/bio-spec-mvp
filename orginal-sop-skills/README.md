# orginal-sop-skills - 11 个原版生信 SOP 技能集

本目录包含从完整生信 SOP 课件（PPT）与原始 R 脚本重构提取的 11 个原子技能，覆盖从 GEO 数据预处理到 ROC 诊断验证的全生命周期。

每个技能严格遵循 \SKILL.md + scripts/ + references/\ 纯粹架构，符合 Antigravity / Spec-Kit 规范：
- 零硬编码 \setwd()\ 路径，支持 CLI 命令行传参 (\--key=value\)
- 随机种子显式固定 (\set.seed(12345)\)，保证可复现性
- 全部 16 个 R 脚本均通过 R 4.6.1 编译器 100% 语法验证

## 技能清单

| 技能名称 | 阶段职能 | 核心脚本 | 对应 MCP / 工具 |
| :--- | :--- | :--- | :--- |
| \io-01-geo-dataprep\ | 1. GEO 数据下载、探针映射与 KNN 缺失值填充 | \geo_preprocess.R\ | \iomcp\, R (GEOquery, impute, limma) |
| \io-02-batch-norm\ | 2. 数据归一化、ComBat 去批次与双视角 PCA 质控 | ormalize.R\, \sva_combat.R\, \pca_qc.R\ | R (sva, limma, oligo, ggplot2) |
| \io-03-wgcna\ | 3. WGCNA 共表达网络、软阈值选择与核心模块提取 | \wgcna_build.R\, \wgcna_module_export.R\ | R (WGCNA, flashClust) |
| \io-04-deg-limma\ | 4. limma 差异表达分析、聚类热图与火山图 | \limma_diff.R\, \olcano_heatmap.R\ | R (limma, pheatmap, ggplot2) |
| \io-05-enrichment\ | 5. 差异基因 GO (BP/CC/MF) 与 KEGG 通路富集 | \enrichment_analysis.R\ | \iomcp\, R (clusterProfiler, pathview) |
| \io-06-gene-intersection\ | 6. WGCNA 关键模块基因 ∩ DEG 韦恩图交集 | \enn_intersection.R\ | R (VennDiagram, UpSetR) |
| \io-07-ml-lasso\ | 7. 候选基因表达矩阵提取与 LASSO 交叉验证筛选 | \gene_expression_match.R\, \lasso_regression.R\ | R (glmnet) |
| \io-08-ml-randomforest\ | 8. 随机森林置换检验与 MeanDecreaseGini 变量重要性排序 | andom_forest_importance.R\ | R (randomForest, rfPermute, ggplot2) |
| \io-09-hub-literature\ | 9. 双算法交集 Hub 基因确定与 Scite 文献证据挖掘 | \hub_gene_intersection.R\ | **\scite-mcp\** (Smart Citations), \iomcp\ |
| \io-10-biomarker-roc\ | 10. 单基因及多基因联合逻辑回归 ROC 诊断性能与 AUC 评估 | oc_validation.R\ | R (pROC, ggplot2) |
| \io-pipeline-orchestrator\ | 全流程主控编排器（拓扑依赖 DAG、断点续跑、门禁报告） | un_pipeline.R\ | R, Spec-Kit CLI |
