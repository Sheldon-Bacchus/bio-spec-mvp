# Original SOP source Skills

本目录保留远端并入的 11 个原版生信 SOP 来源组件。每个组件遵循
`SKILL.md + references/ + scripts/` 的来源结构，供后续逐项审查、补齐输入
/输出契约和 verifier；它们当前不是 generic `research-control` 的固定步骤，
也没有自动注册到当前 `skill-catalog.yml` 或 `.agents/skills/`。

## 来源组件清单

| Skill | 主要职责 | 当前来源状态 |
|---|---|---|
| `bio-01-geo-dataprep` | GEO 数据下载与预处理 | source-only |
| `bio-02-batch-norm` | 归一化、ComBat/SVA 与 PCA QC | source-only |
| `bio-03-wgcna` | WGCNA 共表达网络与模块提取 | source-only |
| `bio-04-deg-limma` | limma 差异表达与图形输出 | source-only |
| `bio-05-enrichment` | GO/KEGG 富集 | source-only |
| `bio-06-gene-intersection` | 基因集交集与候选 Hub 集合 | source-only |
| `bio-07-ml-lasso` | LASSO 特征筛选 | source-only |
| `bio-08-ml-randomforest` | 随机森林重要性分析 | source-only |
| `bio-09-hub-literature` | Hub 基因与文献证据挖掘 | source-only |
| `bio-10-biomarker-roc` | ROC/AUC 诊断验证 | source-only |
| `bio-pipeline-orchestrator` | SOP 级 DAG 编排来源 | source-only |

## 目录边界

这里是 Skill 来源层，不是运行目录。`bio-pipeline-orchestrator` 的存在不等于
本项目批准了一条固定的全流程，也不替代某个 feature 的 `spec.md`、`plan.md`
和 `tasks.md`。只有在完成逐项 contract、依赖/权限检查、runtime projection
和可复核测试后，具体 feature 才可以选择其中的能力。

原始脚本、引用材料和 Skill 名称均保留；本次目录重构只修正了它们的归属位置
和本 README 的边界说明，没有把它们接入 generic workflow。
