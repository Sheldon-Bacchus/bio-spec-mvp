# Research control command map

这里定义本项目的六个 core 与三个 optional quality-control 命令的导航 ID。
这是项目级分类和路由标识，不是另一份可执行 Skill 副本，也不是 Spec Kit
官方规定的固定九阶段 taxonomy。

| 规范 suite ID | 角色 | 官方阶段 | 官方命令 | Codex 兼容入口 | 主要职责 |
|---|---|---|---|---|---|
| `spec-01-constitution` | core | `constitution` | `speckit.constitution` | `$speckit-constitution` | 建立或更新项目原则与边界 |
| `spec-02-specify` | core | `specify` | `speckit.specify` | `$speckit-specify` | 形成用户目标、需求和验收标准 |
| `plan-03-plan` | core | `plan` | `speckit.plan` | `$speckit-plan` | 形成技术与能力选择计划 |
| `plan-04-tasks` | core | `tasks` | `speckit.tasks` | `$speckit-tasks` | 把计划拆成可追踪、可执行任务 |
| `implement-05-implement` | core | `implement` | `speckit.implement` | `$speckit-implement` | 按任务执行实现并留下验证证据 |
| `review-06-converge` | core | `converge` | `speckit.converge` | `$speckit-converge` | 用原始规格回验实现并收敛剩余任务 |
| `review-07-clarify` | optional_quality_control | `clarify` | `speckit.clarify` | `$speckit-clarify` | 需要时暴露并解决高影响歧义 |
| `review-08-checklist` | optional_quality_control | `checklist` | `speckit.checklist` | `$speckit-checklist` | 需要时生成或审阅质量检查清单 |
| `review-09-analyze` | optional_quality_control | `analyze` | `speckit.analyze` | `$speckit-analyze` | 需要时只读检查 spec/plan/tasks 一致性 |

## 命名规则

- `spec-*` 表示治理、需求和边界定义；`plan-*` 表示设计和任务分解；
- `implement-*` 表示按任务执行实现；`review-*` 表示可选质量控制或收敛；
- 序号是本项目导航顺序，不宣称官方固定执行顺序；末段固定使用官方阶段名。
- core 为六项：`constitution`、`specify`、`plan`、`tasks`、`implement`、
  `converge`；optional quality control 为三项：`clarify`、`checklist`、
  `analyze`。

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

MultiQC、bulk RNA-seq、pathway 或 WGCNA 都不是这六加三控制命令；它们属于
可由具体 feature 在 `plan.md` 中选择的 domain Skill/Extension。压缩、总审阅、
评分、修复和数据实验也不属于这个项目控制命令 map。
