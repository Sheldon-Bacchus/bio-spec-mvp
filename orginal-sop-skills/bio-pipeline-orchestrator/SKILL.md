---
name: bio-pipeline-orchestrator
description: >-
  生信分析全流程主控编排。当用户需要从头到尾运行完整的芯片数据分析流水线、
  或从任意中间阶段断点续跑时，使用此技能。负责检查环境依赖、
  按 DAG 顺序调度各阶段 Skill、执行 Stage-Gate 验收。
---

# 生信分析全流程编排器

## 依赖声明

### MCP 服务
- `serena` — 代码符号级重构辅助（可选使用）

### 工具
- `specify` CLI — Spec-Kit 工作流管理（`specify workflow run/status`）
- `repomix` — 代码资产全景打包（全流程完成后）

### 调度的子技能
- `bio-01-geo-dataprep` → `bio-02-batch-norm` → `bio-03-wgcna` (+ `bio-04-deg-limma`) → `bio-05-enrichment` → `bio-06-gene-intersection` → `bio-07-ml-lasso` (+ `bio-08-ml-randomforest`) → `bio-09-hub-literature` → `bio-10-biomarker-roc`

## 执行流程

### 全流程运行
```
specify workflow run bio-full-pipeline
```

### 断点续跑
```
specify workflow resume bio-full-pipeline
```

### 状态查询
```
specify workflow status bio-full-pipeline
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

- S03 与 S04 可并行（均依赖 S02）
- S07 与 S08 可并行（均依赖 S06）

## 环境检查清单

在启动全流程前，验证：
1. R 环境可用（`Rscript --version`）
2. 所需 R 包已安装（limma, sva, WGCNA, glmnet, randomForest, pROC 等）
3. MCP 服务可达（scite-mcp, biomcp, serena）
4. 原始数据已就绪（GSE 数据集已下载）

## Gate 校验机制

每个 Stage 完成后，执行 Gate 校验：
- 检查输出文件是否存在且非空
- 检查数据格式是否符合 Constitution 中的数据契约
- 未通过 Gate 则停止并报告错误

## 全流程完成后

```bash
npx repomix --output repomix-output.md
```
打包全景上下文资产。

## 参考
- [pipeline-dag.md](./references/pipeline-dag.md)
- [.specify/workflows/bio-full-pipeline.yaml](../../.specify/workflows/bio-full-pipeline.yaml)
