---
name: bio-pipeline-orchestrator
description: >-
  生信分析全流程主控编排。当用户需要从头到尾运行完整的芯片数据分析流水线、
  或从任意中间阶段断点续跑时，使用此技能。负责检查环境依赖、
  按 DAG 顺序调度各阶段 Skill、执行 Stage-Gate 验收。
---

# 生信分析全流程编排器

> **spec-008 状态**: 11 个 original-sop 组件在固定基线之上完成 source-only contract hardening（2026-09-15）。
> 外部 worktree 尚未提交或注册；toy E2E 会对不可映射 synthetic IDs fail-closed。

## 依赖声明

### 工具
- `R` 4.x + `Rscript`；modules 全部为本地 R 脚本
- `specify` CLI（可选，Spec-Kit 工作流）

### 调度的子技能
- `bio-01-geo-dataprep` → `bio-02-batch-norm` → `bio-03-wgcna` (+ `bio-04-deg-limma`) → `bio-05-enrichment` → `bio-06-gene-intersection` → `bio-07-ml-lasso` (+ `bio-08-ml-randomforest`) → `bio-09-hub-literature` → `bio-10-biomarker-roc`

## 执行流程

```
Rscript run_pipeline.R --project-dir=<work> --matrix=<matrix> --metadata=<metadata> \
  --source-revision=<commit-or-marker> --run-id=<run-id>
# 可选：--platform=<annotation> --start-stage=<n> --end-stage=<n> --dry-run --force --log=<file> --report=<file>
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

## Gate 校验机制（spec-008 contract hardening）

- 每次运行先创建 manifest，校验显式 matrix/metadata、样本顺序、输入 SHA-256、source revision 和 run ID。
- 每个子步骤接收显式 run-scoped 路径、metadata 和 manifest；缺脚本、子进程非零、输出缺失或内容失败都会记录 `failure` 并停止。
- `success`、`negative`、`manual_review`、`skipped`、`failure` 是不同状态；阴性结果不得以 top-N、union 或复制列表替换。
- S05 对未知物种、ID 类型不匹配、检测 universe 不一致或无法映射的输入 fail-closed；S09 文献步骤在未调用证据服务时写 `skipped`。

## 版本说明
- 2026-09-15 (spec-008): explicit manifest/metadata/path contracts；typed stage statuses；stale-artifact and failure propagation；S01–S10 substep wiring；source-only/unregistered boundary
