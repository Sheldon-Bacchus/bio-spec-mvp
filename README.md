# bio-spec-005-research-core

这是一个独立的 GitHub Spec Kit 项目：可以单独下载、单独打开 Codex，并从
根目录执行规格化流程。它不是大仓库中的某个具体研究项目，也不把某个
MultiQC、RNA-seq、通路或 WGCNA 课题预置成 generic workflow。

## 目录边界

目录名称直接表达所有权，不再用 `01/02/03` 把不同性质的内容伪装成一个
流水线：

```text
bio-spec-005-research-core/
├── .specify/                         # 官方 Spec Kit 项目运行时与 registry
├── .agents/skills/                   # Codex 发现入口与运行时 projection
├── specs/                            # 官方 feature 目录：spec.md/plan.md/tasks.md
├── control/                          # 通用、可重装的控制源
│   ├── preset/                       # research-control preset
│   ├── workflow/                     # research-control lifecycle
│   ├── command-registry.yml          # 六个 core + 三个 optional 导航映射
│   ├── command-map.md
│   └── README.md
├── skills/                           # Bio Skill 来源、参考稿、catalog、源归档
│   ├── adapters/                     # 5 个可调用 adapter
│   ├── reference-stack/              # 8 个 reference-only 组件
│   ├── runtime-projection/           # 5 个 Skill 的来源层 projection
│   ├── archives/                     # zip 与 SHA256 清单，仅是源归档
│   ├── skill-catalog.yml
│   ├── MANIFEST.md
│   └── README.md
├── extensions/                       # 可独立安装的 bio-multiqc、bio-review
├── examples/                         # 具体示例和 fixture
│   └── bio-multiqc/
│       ├── fixtures/
│       ├── requirements.txt
│       └── README.md
├── archive/                          # 历史内容，不是活动运行时
│   └── 005-work-package/
└── README.md
```

四条边界必须保持：

| 目录 | 负责什么 | 明确不负责什么 |
|---|---|---|
| `.specify/`、`.agents/`、`specs/` | 官方运行时、Codex 入口、feature 产物 | 不作为源包分类目录 |
| `control/` | 通用 preset、workflow、命令 registry/map | 不放具体项目、fixture、MultiQC 步骤 |
| `skills/`、`extensions/` | 能力来源和独立命令包 | 不自动组成固定科研流水线 |
| `examples/`、`archive/` | 具体示例、历史工作包和证据 | 不成为 generic workflow 的隐式输入 |

`review`、`score`、`repair`、压缩服务和数据实验没有被建成项目运行目录；
`skills/archives/` 中的 zip 只是可追溯的来源归档。现有 `bio-*` 命名空间
保持不变。

## 官方 Spec Kit 运行方式

根级 `.specify/`、`.agents/` 和 `specs/` 保持官方入口位置。新 feature 使用
官方文件名，不改成 `spec-xxx.md` 或 `plan-xxx.md`：

```text
specs/NNN-short-name/
├── spec.md
├── plan.md
├── tasks.md
└── checklists/
```

通用 `research-control` workflow 只负责控制生命周期：

```text
specify → plan → tasks → implement → converge
```

本项目的导航 map 另行标出六个 core 与三个 optional quality-control 命令，
但它不是官方固定九阶段 taxonomy。详见
[`control/command-map.md`](control/command-map.md) 和
[`control/command-registry.yml`](control/command-registry.yml)。

### 单独下载后的检查

在仓库根目录执行：

```powershell
specify check
specify integration status
specify preset list
specify preset resolve spec-template
specify workflow list
specify workflow resolve research-control
specify extension list
```

如果需要从源目录重新登记本地包：

```powershell
specify preset add --dev .\control\preset
specify workflow add --dev .\control\workflow\workflow.yml
specify extension add .\extensions\bio-multiqc --dev --force
specify extension add .\extensions\bio-review --dev --force
```

MultiQC 依赖只在明确运行该独立 Extension 的示例时安装：

```powershell
uv venv
uv pip install -r .\examples\bio-multiqc\requirements.txt
```

## 9 个导航 suite 与 Skills 的关系

控制层的稳定导航 ID 是：

```text
spec-01-constitution       # core
spec-02-specify            # core
plan-03-plan               # core
plan-04-tasks              # core
implement-05-implement     # core
review-06-converge         # core
review-07-clarify          # optional quality control
review-08-checklist        # optional quality control
review-09-analyze          # optional quality control
```

它们对应官方兼容的 `speckit-*` 入口。5 个 adapter 和 8 个 reference-only
组件只是 `skills/skill-catalog.yml` 的候选能力/参考资料：具体 feature 在
`plan.md` 中选择，在 `tasks.md` 中冻结绑定，不能因为它们存在于目录中就被
自动串接。

## 历史工作包

上一轮导入的工作包、评估运行、审查记录和契约证据保留在
[`archive/005-work-package/`](archive/005-work-package/)。它可以被审计和
比较，但不是新 feature 的默认路径，也不是当前 generic control 的源包。

新的规格化任务从根目录启动 Codex，并使用官方阶段入口：

```text
$speckit-constitution
$speckit-specify
$speckit-clarify        # 按需
$speckit-plan
$speckit-tasks
$speckit-analyze        # 按需
$speckit-checklist      # 按需
$speckit-implement
$speckit-converge
```

源目录的结构与运行时投影分开，下载后的项目仍然可以直接规格化运行；
具体科研项目、数据集和分析工具必须由各自 feature 的规格、计划和任务明确
绑定，不会由这个通用项目目录暗中决定。
