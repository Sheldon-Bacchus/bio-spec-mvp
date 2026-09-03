# Original SOP Source Skills（spec-007 修复版）

本目录保留远端并入的 11 个原版生信 SOP 组件的 **修复版**（2026-09-03 spec-007 契约修复 + toy-data 验证通过）。

## 修复摘要（P0/P1）

| Skill | 修复内容 |
|---|---|
| `bio-01-geo-dataprep` | 分组 fail-closed（G-02，禁 half-split 静默推断）；CLI 连字符参数修复（F-01） |
| `bio-02-batch-norm` | CLI 连字符参数修复（--input-files/--pd 生效） |
| `bio-03-wgcna` | WGCNA 单线程化（Windows socket 崩溃规避）；CLI 参数修复 |
| `bio-04-deg-limma` | CLI 参数修复；分组推断降级审计（inferred_groups.csv） |
| `bio-05-enrichment` | bitr 0 映射 fail-loud；pae GO 显式说明；enrichplot 参数适配 |
| `bio-06-gene-intersection` | 依赖一致化 |
| `bio-07-ml-lasso` | 分层 foldid（F-02）；双 lambda 列表；group fail-closed（G-03）；删 top-N 凑数 |
| `bio-08-ml-randomforest` | 删假 p=0.02（G-04）；置换 rownames 对齐；group fail-closed |
| `bio-09-hub-literature` | 删并集 fallback（G-06 空交集人工评审）；header 黑名单修正 |
| `bio-10-biomarker-roc` | 联合模型 k-fold OOF（G-04，禁 in-sample AUC）；Type 标记 Combined(OOF) |
| `bio-pipeline-orchestrator` | Stage1/5 gate 修复；依赖清单修正；删 typo alias；I/O 契约化 |

## 验证状态

- **R 语法检查**: 16/16 脚本通过
- **toy-data 全链复跑**（S01→S10）: 通过（S09 空交集按契约触发人工评审路径，记录后放行）
- **fail-closed 实测**: LASSO 无 --group → GATE ERROR；hub 空交集 → GATE ERROR；连字符 flag 生效

## 原版归档

原版 v0 备份: `E:\all-agent-workspace\codex-projects\bio-skills\_archive\original-sop-v0-20260903`（仓库外，非提交物）

## 契约与基准

- 统一 I/O 契约: `run-working/007-original-sop-speckit/contracts.md`
- 审查报告: `run-working/007-original-sop-speckit/audit-report.md`
- 基线报告: `run-working/007-original-sop-speckit/toydata-baseline-report.md`
