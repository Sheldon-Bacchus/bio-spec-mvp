# Implementation Plan: Original SOP Speckit 化 (007)

**Branch**: `007-original-sop-speckit` | **Date**: 2026-09-03
**Spec**: [spec.md](spec.md) | **Contracts**: [contracts.md](contracts.md)

## Architecture

```text
specs/007-original-sop-speckit/{spec,plan,tasks,contracts,benchmark-spec}.md
           → read by Agent during Spec Kit workflow
spec-mvp/skills/original-sop/<stage>/            (source layer, 原件保留)
           → 审查 + P0-P2 修复后 → staged-adapter
spec-mvp/skills/skill-catalog.yml                (注册 ×11)
.agents/skills/<id>/SKILL.md                     (通过验收的核心 stages)
workflows/bio-full-pipeline/workflow.yml         (官方 gate/shell 编排)
spec-mvp/tests/toydata/                          (2组×5样本×200基因 fixture)
pipeline_run_report.json                         (科学指标汇总)
```

三层职责沿用仓库惯例：
- **Spec Core**（specs/007/*）: 黑盒行为、契约、验收（本包）。
- **Source/Skill Core**（spec-mvp/skills/original-sop + 注册）: 触发条件、契约引用、参数预设。
- **Execution Core**（脚本 + toy-data + gate/verifier）: 真实计算、科学 gate、run 报告。

## Technical decisions

1. **执行顺序按用户确认的 A→C→B**:
   - A: 审查报告（per-script 问题清单 + 打分矩阵）落盘 `specs/007/audit-report.md`（Tasks Phase 1）。
   - C: toy-data 全链演练（先用**原版脚本**跑，产出"哪些阶段真会出错"的实测证据；再对修复后脚本复跑，验证 P0/P1 修复有效）。两轮都产出 `pipeline_run_report.json` 对比。
   - B: P0 first（4 组脚本: 分组驱动/LASSO/RF/ROC + enrichment 报错路径），P1（契约表落地/编排器/geo fallback/filename typo），P2（hub 空交集/TOM kME/gate 升级）。
2. **契约表为唯一事实源**: 所有脚本读写文件名、SKILL.md 声明、编排器调用参数、verifier 断言均从 contracts.md 派生；修复 `merge.normalzie` typo 不保留 alias。
3. **分组 fail-closed**: `--group-file`（PD.csv）优先；样本名推断仅 WARN 降级 + `inferred_groups.csv`；"前一半/后一半"直接删除。
4. **科学指标写入 run 报告**: 每阶段把关键指标（R²、p、AUC(OOF)、lambda、交集数、置换 p）追加到 `pipeline_run_report.json`；gate 判定只依据该 JSON，不依赖"文件存在"。
5. **RF/ROC 修复策略**: rfPermute 失败→显式置换检验（nrep=299, rownames 校验）或报错；联合 ROC 用 5-fold OOF（样本<10 时说明并报错或 leave-one-out）。
6. **不引入新依赖**: 仅 R 包（已有声明）+ Python stdlib verifier（沿用 multiqc 惯例）。

## Files and responsibilities

| Area | Files | Responsibility |
|---|---|---|
| Spec Core | `specs/007-original-sop-speckit/*` | 契约、验收、审查报告、benchmark |
| Source Core | `spec-mvp/skills/original-sop/*` | 原件 + P0-P2 修复（重写脚本与 SKILL.md） |
| Registration | `skill-catalog.yml` / `.agents/skills/` / `workflows/bio-full-pipeline/` | staged-adapter → executable-mvp |
| Test/Fixture | `spec-mvp/tests/toydata/` + verifier 脚本 | 确定性输入与全链断言 |
| Run artifacts | `pipeline_run.log`, `pipeline_gate_report.csv`, `pipeline_run_report.json` | 执行证据（人工可复核） |

## Verification strategy

1. Phase 1 (A): 审查报告 → 用户确认问题清单。
2. Phase 2 (C): toy-data 原版全链演练 → 记录失败点（实测证据）→ 用户确认。
3. Phase 3 (B): P0/P1/P2 修复 → toy-data 复跑 → 断言（limma 找回 ≥90% 信号基因；LASSO ≥50%；RF 真实 p 显著基因 ≥50%；联合 OOF AUC ≥0.85；S01-S10 全部 gate 通过）。
4. Phase 4: 注册（catalog ×11 + .agents 核心 stages + workflow）→ `specify workflow list` 可见 → 用户验收。
