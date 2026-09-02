# Package sources

这里保留当前项目可重新安装的 preset、workflow 和 extension 源文件。它们与
根级 `.specify` 中的已安装运行时副本分开。官方九个阶段的规范命名见
[`suite-registry.yml`](suite-registry.yml) 和根级 [`suites/README.md`](../suites/README.md)。

当前这些源包仍包含早期的 MultiQC vertical-slice 示例；该示例是具体项目/域
套件，不是官方九阶段的一部分，后续应从通用 Bio workflow 中解耦。

当前源包：

- `preset/`：`bio-research-mvp`；
- `workflow/`：当前项目 `bio-research-mvp`；
- `extensions/`：当前 workflow 需要的 `bio-multiqc`、`bio-review`。

运行时状态可检查：

```powershell
specify preset list
specify workflow list
specify extension list
```

如果修改了这些源包，使用官方 CLI 的本地安装命令重新注册，再检查 registry：

```powershell
specify preset add --dev .\03-package-sources\preset
specify workflow add .\03-package-sources\workflow\workflow.yml --dev
specify extension add .\03-package-sources\extensions\bio-multiqc --dev --force
specify extension add .\03-package-sources\extensions\bio-review --dev --force
```

仅修改源文件不会自动改变已安装运行时。修改 suite registry 只改变规范命名
和映射，不会生成第二份 `speckit-*` Skill，也不会改变官方 CLI 入口。
