# skills - Bio Skill 来源组件（2026-09-03）

- adapters/            5 个项目适配器（原始结构：SKILL.md + references）
- reference-stack/     8 个参考组件 + 栈文档（analysis-order.md、README.md）
- original-sop/        11 个新合并的 SOP 来源组件，暂不进入当前 catalog/runtime
- skill-catalog.yml    计划阶段候选索引；不编排执行顺序
- runtime-projection/  5 个 Codex 运行时投影（对应 .agents/skills）
- archives/            源归档：4 个 zip + SHA256SUMS.txt + README
- MANIFEST.md          来源与清单

校验和见 archives/SHA256SUMS.txt。

本目录包含 5 个已编目可调用 adapter、8 个已编目参考组件，以及独立的 11 个
SOP 来源组件。`original-sop/` 只表示来源层归档；其中的
`bio-pipeline-orchestrator` 不会因为存在于目录中就接管
`research-control`，也不会自动调度其它 Skill。
