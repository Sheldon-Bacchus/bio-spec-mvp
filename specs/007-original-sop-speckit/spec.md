# Feature Specification: Original SOP Speckit 化 — 契约修复与可验证执行

**Feature Branch**: `007-original-sop-speckit`
**Created**: 2026-09-03
**Status**: SPEC_DESIGN_FROZEN (2026-09-03, user confirmed)
**Source**: `spec-mvp/skills/original-sop/` (11 source-only components, Gemini-generated)

## 背景 (Background)

`skills/original-sop/` 保留 11 个原版生信 SOP 组件（S01–S10 + orchestrator）。经逐脚本审查确认：**工程外壳合格（CLI 参数化/日志/seed/gate 框架），但领域方法学与数据契约存在硬伤**，ML 阶段（LASSO/RF/ROC）问题最严重。当前全部为 `source-only`，未注册到 `skill-catalog.yml` 或 `.agents/skills/`。

本 feature 的目标：把 original-sop 从"来源层"提升为 **staged-adapter（契约修复完成）→ executable-mvp（toy-data 全链验证通过）**，全程按 Spec Kit 生命周期执行（spec → plan → tasks → 审查报告 → toy-data 演练 → 重写 → 注册 → 验收）。

## User Story 1: 修复后的流水线能跑通且结论可信 (Priority: P0)

As 研究者, I want 从原始 GEO 探针矩阵到 ROC 验证的 10 阶段流水线在 toy-data 上真实跑通, so that 每个阶段的输出契约（文件schema）和科学 gate（非橡皮图章）都经过实测验收, 而不是依赖生成式 Markdown 声明。

### Acceptance Scenarios

1. **Given** toy-data fixture（2 组 × 5 样本 × 200 基因，其中 50 个已知信号基因，log2 尺度，附 PD.csv 显式分组）, **when** 按 DAG 顺序执行 S01→S10, **then** 每阶段退出码 0，输出文件符合 `contracts.md` 定义，且科学 gate 通过（详见 benchmark-spec.md）。
2. **Given** 同一 fixture 但 `--group-file` 缺失或分组文件不匹配, **when** 执行 S01/S02/S04/S07/S08/S10, **then** 显式报错（fail-closed），**绝不**静默使用样本名正则推断或"前一半/后一半"fallback。
3. **Given** 修复后的 LASSO/RF/ROC 阶段, **when** 执行, **then** 产出 `pipeline_run_report.json`，含 lambda.min/1se 双列表、置换 p 值（真实检验，非伪造 0.02）、OOF AUC（非 in-sample AUC）。

## User Story 2: 方法学修复落地 (Priority: P0)

As 统计严谨性负责人, I want 已知的四类方法学硬伤被消除, so that 下游结论不会被系统性偏差污染。

### Acceptance Scenarios

1. **Given** RF 置换检验, **when** `rfPermute` 不可用或失败, **then** 走显式置换检验且 rownames 对齐校验，或直接报错退出；**禁止**写入伪造 p 值。
2. **Given** 联合 ROC, **when** 计算联合模型 AUC, **then** 必须使用 k-fold out-of-fold 预测概率（报告标注 `OOF`），禁止 in-sample AUC。
3. **Given** LASSO CV, **when** 执行 `cv.glmnet`, **then** 使用显式分层 `foldid` 且类别不平衡/样本过少时报错而非硬跑。
4. **Given** enrichment 阶段, **when** `species=pae`, **then** GO 无法执行时明确报错说明（而非静默跳过），KEGG 在线依赖失败时明确 WARN 降级记录。

## Functional Requirements

- **FR-001**: 统一 I/O 契约表（`contracts.md`）必须成为 S01–S10 唯一文件名/列名/阈值事实源；修正 `merge.normalzie.txt` 拼写 typo，编排器与脚本一律引用契约表文件名。
- **FR-002**: 所有分组/批次/表型标签必须来自显式 metadata 文件（`PD.csv`/specified `--group-file`）；样本名正则推断仅允许作为"WARN + 输出推断表供人工确认"的降级路径。
- **FR-003**: 每阶段 gate 必须包含科学指标校验（S03 软阈值 R²、S05 富集 q<0.05、S06 交集数、S07 lambda 双列表、S08 真实置换 p、S10 OOF AUC），并写入 `pipeline_run_report.json`。
- **FR-004**: `hub_gene_intersection` 空交集必须 FAIL + 人工介入，禁止静默 fallback 到并集。
- **FR-005**: 修复后的 11 个 skill 注册进 `skill-catalog.yml`（status: staged-adapter → executable-mvp），其中通过 toy-data 的核心 stages 安装到 `.agents/skills/`。
- **FR-006**: 提供官方格式 `workflows/bio-full-pipeline/workflow.yml`（`command/shell/gate` steps），作为编排器脚本的 Spec Kit 顶层入口。
- **FR-007**: 全程不引入 MCP/Nextflow 依赖；R 脚本仅依赖声明过的 R 包。

## Key Entities

- **Spec artifact**: 本 spec.md、contracts.md、plan.md、tasks.md、benchmark-spec.md。
- **Source layer**: `spec-mvp/skills/original-sop/`（保留原件，重写输出到同目录或 `spec-mvp/skills/bio-full-pipeline/`）。
- **Runtime layer**: `.agents/skills/` 注册 + `skill-catalog.yml` + `workflows/bio-full-pipeline/workflow.yml`。
- **Verification artifact**: toy-data fixture、`pipeline_run_report.json`、per-stage gate 记录、审查报告。

## Out of Scope

真实 GEO 数据下载、生物学结论解读、多代理编排、MCP 服务依赖、Nextflow/工作流引擎替换、非 R 语言重写。
