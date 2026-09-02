# Package sources

这里保留当前项目可重新安装的 preset、workflow 和 extension 源文件。它们与
根级 `.specify` 中的已安装运行时副本分开：

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

仅修改源文件不会自动改变已安装运行时。
