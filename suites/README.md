# Spec Kit core suite IDs

这里定义 Spec Kit 官方九个核心阶段的项目级规范 ID。它们是稳定的命名和
路由标识，不是另一份可执行 Skill 副本。

| 规范 suite ID | 官方阶段 | 官方命令 | Codex 兼容入口 | 主要职责 |
|---|---|---|---|---|
| `spec-01-constitution` | `constitution` | `speckit.constitution` | `$speckit-constitution` | 建立或更新项目原则与边界 |
| `spec-02-specify` | `specify` | `speckit.specify` | `$speckit-specify` | 形成用户目标、需求和验收标准 |
| `spec-03-clarify` | `clarify` | `speckit.clarify` | `$speckit-clarify` | 暴露并解决高影响歧义 |
| `plan-04-plan` | `plan` | `speckit.plan` | `$speckit-plan` | 形成技术与实现计划 |
| `plan-05-tasks` | `tasks` | `speckit.tasks` | `$speckit-tasks` | 把计划拆成可追踪任务 |
| `review-06-analyze` | `analyze` | `speckit.analyze` | `$speckit-analyze` | 只读检查 spec/plan/tasks 的一致性 |
| `review-07-checklist` | `checklist` | `speckit.checklist` | `$speckit-checklist` | 生成或审阅质量检查清单 |
| `implement-08-implement` | `implement` | `speckit.implement` | `$speckit-implement` | 按任务执行实现并留下验证证据 |
| `review-09-converge` | `converge` | `speckit.converge` | `$speckit-converge` | 用原始规格回验实现并收敛剩余任务 |

## 命名规则

- `spec-*` 表示需求和边界定义阶段；
- `plan-*` 表示设计和任务分解阶段；
- `review-*` 表示一致性、质量或收敛审查阶段；
- `implement-*` 表示按任务执行实现的阶段；
- 两位序号固定官方生命周期顺序；末段固定使用官方阶段名。

## 与官方运行时的关系

官方 Codex 集成仍使用 `speckit-<stage>` 目录和入口，因为那是 Spec Kit
生成的兼容名称。规范 suite ID 只用于项目目录、preset/workflow 路由、映射
表和文档中的精确标识；不得把两个名称空间混成重复的 Skill。

具体 feature 的产物仍保持官方目录约定：

```text
specs/NNN-short-name/
├── spec.md
├── plan.md
├── tasks.md
└── checklists/
```

不能把这些官方产物随意改成同级的 `spec-xxx.md`、`plan-xxx.md`，否则会破坏
官方脚本对 feature 目录和文件名的解析。`spec-xxx`、`plan-xxx` 命名用于
suite ID；`spec.md`、`plan.md` 命名用于 feature artifact。

MultiQC、bulk RNA-seq、pathway 或 WGCNA 都不是这九个核心 suite；它们属于
可被具体项目在 `plan.md` 中选择的 Bio domain suite。
