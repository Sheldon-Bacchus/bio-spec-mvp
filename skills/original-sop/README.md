# Original SOP Source Skills（spec-008 contract-hardening worktree）

本目录保留远端并入的 11 个原版生信 SOP 组件。本 worktree 在固定基线 `5f897bbcd16e64b2d93203964c7f35f29030d3f0` 上执行了 2026-09-15 的 contract-first source-only 修复；改动尚未提交，也不代表 runtime registration 或临床验证。

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
| `bio-09-hub-literature` | 真交集；空交集保留为 typed `negative`，禁止并集/复制 fallback；增加文学步骤 skipped 报告 |
| `bio-10-biomarker-roc` | discovery 锁定特征、只在独立 validation 分区打分；重叠或缺失验证时不冒充独立 AUC |
| `bio-pipeline-orchestrator` | 显式 run manifest、路径/metadata 传播、子步骤执行、内容/provenance gate、stale-artifact 拒绝和非零失败传播 |

## 验证状态（2026-09-15）

- **R AST**: 18/18 脚本通过，R 4.6.1
- **fresh E2E**: S01–S04 success；S05 对 synthetic `g001`-style human symbols 以 `unmapped_input` fail-closed；S06–S10 skipped；整体 exit `1`
- **package contract tests**: 34 passed；external smoke 61/62（唯一 warning 为 helper-only orchestrator entry）
- **fail-closed 实测**: 缺失 matrix exit `1`；dry-run 十阶段 skipped 且 `overall_success=false`；未生成正向科学或临床结论

## 原版归档

原版 v0 备份: `E:\all-agent-workspace\codex-projects\bio-skills\_archive\original-sop-v0-20260903`（仓库外，非提交物）

## 契约与基准

- 统一 I/O 与状态契约: `E:\all-agent-workspace\bio-skills-speckit\bio-spec-kit\run-working\008-original-sop-audit-speckit\specs\001-audit-original-sop\contracts\`
- 验证记录: `E:\all-agent-workspace\bio-skills-speckit\bio-spec-kit\run-working\008-original-sop-audit-speckit\specs\001-audit-original-sop\validation-record.md`
- fresh E2E 证据: `E:\all-agent-workspace\bio-skills-speckit\bio-spec-kit\run-working\008-original-sop-audit-speckit\specs\001-audit-original-sop\external-evidence\fresh-e2e-run.md`
