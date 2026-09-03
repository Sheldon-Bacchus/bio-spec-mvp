# Generic control sources

这里仅保留可重新安装的通用 preset、workflow、命令注册表和命令 map。它们与
根级 `.specify` 中的已安装运行时副本分开。六个 core 与三个 optional quality
control 命令的项目导航见
[`command-registry.yml`](command-registry.yml) 和
[`command-map.md`](command-map.md)。

MultiQC、Bio Skill 和具体项目 fixture 不属于 `control/`。它们分别位于根级
`extensions/`、`skills/` 和 `examples/`，不能成为 generic preset/workflow 的
固定输入或步骤。

当前控制源包：

- `preset/`：通用 `research-control` preset；
- `workflow/`：通用 `research-control` 控制生命周期；
- `command-registry.yml`：本项目的六个 core + 三个 optional 导航映射；
- `command-map.md`：面向人的同一份命令说明。

运行时状态可检查：

```powershell
specify preset list
specify workflow list
specify extension list
```

如果修改了这些源包，使用官方 CLI 的本地安装命令重新注册，再检查 registry：

```powershell
specify preset add --dev .\control\preset
specify workflow add --dev .\control\workflow\workflow.yml
specify extension add .\extensions\bio-multiqc --dev --force
specify extension add .\extensions\bio-review --dev --force
```

仅修改源文件不会自动改变已安装运行时。修改 command registry 只改变规范命名
和映射，不会生成第二份 `speckit-*` Skill，也不会改变官方 CLI 入口。
