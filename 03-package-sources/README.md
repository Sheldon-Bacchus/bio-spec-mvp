# Package sources

这里保留当前项目可重新安装的 preset、workflow 和 extension 源文件。它们与
根级 `.specify` 中的已安装运行时副本分开。六个 core 与三个 optional quality
control 命令的项目导航见
[`suite-registry.yml`](suite-registry.yml) 和根级 [`suites/README.md`](../suites/README.md)。

MultiQC vertical-slice 是具体项目/域示例，不是控制命令的一部分；它只通过
独立 Extension 保留，不能成为 generic preset/workflow 的固定输入或步骤。

当前源包：

- `preset/`：通用 `research-control`；
- `workflow/`：通用 `research-control` 控制生命周期；
- `extensions/`：可独立安装的 `bio-multiqc`、`bio-review`，不是通用 workflow 的必需项。

运行时状态可检查：

```powershell
specify preset list
specify workflow list
specify extension list
```

如果修改了这些源包，使用官方 CLI 的本地安装命令重新注册，再检查 registry：

```powershell
specify preset add --dev .\03-package-sources\preset
specify workflow add --dev .\03-package-sources\workflow\workflow.yml
specify extension add .\03-package-sources\extensions\bio-multiqc --dev --force
specify extension add .\03-package-sources\extensions\bio-review --dev --force
```

仅修改源文件不会自动改变已安装运行时。修改 suite registry 只改变规范命名
和映射，不会生成第二份 `speckit-*` Skill，也不会改变官方 CLI 入口。
