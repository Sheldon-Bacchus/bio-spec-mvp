---
name: bio-pipeline-orchestrator
description: >-
  生信分析全流程主控编排。当用户需要从头到尾运行完整的芯片数据分析流水线、
  或从任意中间阶段断点续跑时，使用此技能。负责检查环境依赖、
  按 DAG 顺序调度各阶段 Skill、执行 Stage-Gate 验收。
---

# 生信分析全流程编排器

> **spec-007 状态**: 11 个 original-sop 组件已完成契约修复（P0/P1，2026-09-03），
> 通过 toy-data 全链验证。编排器 gate 已从"文件存在"升级为契约化校验。

## 依赖声明

### 工具
- `R` 4.x + `Rscript`；modules 全部为本地 R 脚本
- `specify` CLI（可选，Spec-Kit 工作流）

### 调度的子技能
- `bio-01-geo-dataprep` → `bio-02-batch-norm` → `bio-03-wgcna` (+ `bio-04-deg-limma`) → `bio-05-enrichment` → `bio-06-gene-intersection` → `bio-07-ml-lasso` (+ `bio-08-ml-randomforest`) → `bio-09-hub-literature` → `bio-10-biomarker-roc`

## 执行流程

```
Rscript run_pipeline.R --project-dir <work> --start-stage 1 --end-stage 10
# 支持 --dry-run / --force / --log / --report
```

## DAG 依赖关系

```
S01 → S02 → S03 ┐
             └→ S04 → S05
                  │
             S03+S04 → S06 → S07 ┐
                              └→ S08 ┐
                            S07+S08 → S09 → S10
```

- S03 与 S04 可并行（均依赖 S02）；S07 与 S08 可并行（均依赖 S06）

## 环境检查清单

1. R 环境可用（`Rscript --version`）
2. 所需 R 包已安装：limma/sva/WGCNA/impute/Biobase/clusterProfiler/glmnet/randomForest/pROC/VennDiagram/ggplot2（required）
3. 原始数据已就绪（探针矩阵 + platform + 分组 metadata）

## Gate 校验机制（spec-007 修复）

- **Stage 1 gate**: 任一 `*.normalize.txt` + PD.csv/group.txt 存在（不再查幻影文件）
- **Stage 5 gate**: GO/KEGG enrichment csv 非空（不再硬编码 passed=TRUE）
- 未通过 Gate 则停止并报告

## 版本说明
- 2026-09-03 (spec-007): Stage1/5 gate 修复；依赖清单修正（limma/sva/WGCNA 进 required）；删 typo alias；I/O 契约化
