# bio-spec-005-research-core

这是一个真正独立的 Spec Kit 项目，拥有自己的 Git 根目录和远程仓库。它
不是 `bio-spec-kit` 大仓库中的一次运行目录，而是可以单独下载、单独打开
Codex、单独执行规格化流程的项目。

## 根目录已经包含的运行时

```text
bio-spec-005-research-core/
├── .specify/                       # Spec Kit 官方项目运行时
│   ├── integrations/               # Codex 集成清单
│   ├── memory/                     # 项目 Constitution
│   ├── scripts/powershell/         # Windows PowerShell 脚本
│   ├── templates/                  # Spec/Plan/Tasks 等官方模板
│   ├── presets/research-control/   # 已安装的通用 preset
│   ├── extensions/                 # 独立安装的领域扩展
│   └── workflows/                  # 官方 speckit + research-control
├── .agents/skills/                 # Codex 实际发现的 Skill 入口
│   ├── speckit-*                   # 官方兼容入口；规范 ID 见 suites/
│   ├── speckit-bio-*               # Bio 扩展命令入口
│   └── 5 个项目适配器             # bulk / integration / MultiQC / pathway / WGCNA
├── specs/                          # 新建 feature 的标准目录
├── tests/fixtures/multiqc/         # bio-multiqc Extension 的独立 domain fixture
├── 01-spec-work-package/           # 005 工作包与审查证据
├── 02-skills/                      # 13 个 Bio Skill 分类、投影和压缩包
└── 03-package-sources/             # preset/workflow/extension 源包
```

这里的关键修正是：`03-package-sources` 不再是“只有源文件、运行时没有安装”的
状态；当前项目的可执行副本已经登记在 `.specify` 中。`02-skills` 仍保留为
审计和来源层，根级 `.agents/skills` 才是 Codex 的发现入口。

## 官方 Spec Kit 组件

根级运行时由官方 `specify init --here --integration codex --script ps` 生成，
包括：

- `.specify/`：脚本、模板、Constitution、Codex 集成清单、preset、extension
  和 workflow registry；
- `.agents/skills/`：9 个核心阶段 Skill，以及官方
  `speckit-taskstoissues` 辅助 Skill；
- 当前项目的 Bio 命令入口和运行时注册状态。

本项目的控制命令 map 分为六个 core 和三个 optional quality-control 命令。
这是项目导航分类，不是 Spec Kit 的官方固定九阶段 taxonomy。官方兼容名仍
由每个 `speckit-*` 入口提供；`taskstoissues` 是辅助命令，不在这个 map 中。

### 六个 core + 三个 optional 的规范 suite ID

为了让 `spec`、`plan`、`review`、`implement` 等层级和官方阶段名称都可见，
项目增加了规范 ID：

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

完整映射在 [`suites/README.md`](suites/README.md) 和
[`03-package-sources/suite-registry.yml`](03-package-sources/suite-registry.yml)。
这里的规范 ID 不取代官方 `speckit-*` Codex 入口，也不把 feature 产物改成
`spec-xxx.md` 或 `plan-xxx.md`；官方 feature 目录仍使用 `spec.md`、`plan.md`
和 `tasks.md`。Bio 的 MultiQC、bulk、pathway、WGCNA 等属于 plan 中按能力
选择的 domain Skill/Extension，不属于控制命令 map。

官方的项目边界不是把 Spec Kit CLI 源码整份复制进每个项目。项目保存初始化
后的运行时文件；`specify-cli` 仍在机器上单独安装，Python、Codex 和 MultiQC
也属于外部运行环境。官方说明见：

- <https://github.com/github/spec-kit/blob/main/docs/reference/core.md>
- <https://github.com/github/spec-kit/blob/main/docs/installation.md>

独立目录中的 PowerShell `common.ps1` 还有一项已登记的 Windows 兼容修正：
验证 `python3` 是否真的可执行，在 WindowsApps 占位别名失效时回退到可用的
Python 3；其 hash 已同步到 `speckit.manifest.json`。

## 当前项目安装状态

当前运行时已安装并可检查：

- preset：通用 `research-control`；
- workflow：官方 `speckit`、通用 `research-control`；
- extension：可独立使用的 `bio-multiqc`、`bio-review`；
- Bio 逻辑 Skill：5 个项目适配器 + 8 个参考组件，共 13 个；Codex
  `runtime-projection` 是 5 个适配器的宿主副本，不重复计数。

通用 `research-control` workflow 只运行 Spec Kit 控制生命周期：

```text
specify → plan → tasks → implement → converge
```

`constitution` 是项目初始化命令；`clarify`、`checklist`、`analyze` 是按需
插入的 optional quality-control 命令。参考组件不会被 workflow 自动串接；
它们保留在 `02-skills/reference-stack` 中，作为规划时按需读取的参考稿。

## 单独下载后的用法

### 1. 安装官方 CLI（每台机器一次）

按官方安装文档安装并固定一个 release/tag：

```powershell
uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git@<SPEC_KIT_TAG>"
```

将 `<SPEC_KIT_TAG>` 换成实际使用的官方版本，不要用未固定的版本作为可复现
环境。

### 2. 验证项目运行时

在本仓库根目录执行：

```powershell
specify check
specify integration status
specify preset resolve spec-template
specify extension list
specify workflow list
```

这些命令应显示 Codex 集成、`research-control` preset、两个独立 extension
和两个 workflow。MultiQC 依赖仅在你明确使用 `bio-multiqc` Extension 时安装：

```powershell
uv venv
uv pip install -r requirements.txt
```

### 3. 执行规格化流程

从本仓库根目录启动 Codex，使用：

```text
$speckit-constitution
$speckit-specify
$speckit-clarify        # 可选
$speckit-plan
$speckit-tasks
$speckit-analyze        # 可选
$speckit-checklist      # 可选
$speckit-implement
$speckit-converge
```

通用 workflow 也可以直接运行；它只处理控制层，不接收具体项目或工具参数：

```powershell
specify workflow run research-control `
  -i "spec=Describe a bounded research capability and its evidence boundary"
```

具体 Skill/Extension 由计划发现并由 tasks 冻结；生成控制文件不等于科学结论
或发布批准。领域执行和独立审阅设施不由这个 generic workflow 自动调用。

### 4. 继续已有 005 工作包

`01-spec-work-package` 是已经导入的工作包，不是新建 feature 的默认目录。
如果要对它继续执行 Spec Kit 后续阶段，在当前 PowerShell 会话显式设置：

```powershell
$env:SPECIFY_FEATURE_DIRECTORY = (Resolve-Path .\01-spec-work-package).Path
& .\.specify\scripts\powershell\check-prerequisites.ps1 -Json -PathsOnly
```

新 feature 仍按官方约定创建在 `specs/NNN-short-name/`；`.specify/feature.json`
是机器本地的活动 feature 指针，不应提交用户绝对路径。

## 文件边界

- `01-spec-work-package/`：规格、计划、任务、契约、评估和 review 证据；
- `02-skills/`：5 个项目适配器、8 个参考组件、5 个 runtime projection 和
  压缩归档；
- `03-package-sources/`：可重新安装的通用 preset/workflow 与独立 Extension 源包；
- 根级 `.specify/`、`.agents/skills/`、`specs/`、`tests/`：实际运行入口。

这几个层级分开，避免把“参考稿”“逻辑 Skill”“Spec Kit 阶段”和“可执行
workflow”误认为同一种东西。
