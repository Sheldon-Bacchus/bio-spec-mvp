# Runtime specs

这是 Spec Kit 生成新 feature 的标准目录。运行 `$speckit-specify` 后，新规格
会按 `specs/NNN-short-name/` 创建，并由 `.specify/feature.json` 在当前机器
上记录活动 feature。

`01-spec-work-package/` 是随项目提供的既有 005 工作包和审查证据；它保留
工作包原结构，不自动伪装成一个新生成的 `specs/NNN-*` feature。需要继续
处理它时，请按根目录 README 显式设置 `SPECIFY_FEATURE_DIRECTORY`。
