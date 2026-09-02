# Skills 清单与来源（2026-09-02）

| 类型 | Skill | 来源 | SKILL.md |
|---|---|---|---|
| adapter | bulk-pa-luad | spec-mvp/skills/bulk-pa-luad | OK |
| adapter | cross-branch-integration | spec-mvp/skills/cross-branch-integration | OK |
| adapter | multiqc | spec-mvp/skills/multiqc | OK |
| adapter | pathway-enrichment | spec-mvp/skills/pathway-enrichment | OK |
| adapter | wgcna-module-constraint | spec-mvp/skills/wgcna-module-constraint | OK |
| reference | 01-mds | spec-mvp/skills/reference-stack/01-mds | OK |
| reference | 02-deg | spec-mvp/skills/reference-stack/02-deg | OK |
| reference | 02-deg-results | spec-mvp/skills/reference-stack/02-deg-results | OK |
| reference | 03-de-visualization | spec-mvp/skills/reference-stack/03-de-visualization | OK |
| reference | 03-volcano | spec-mvp/skills/reference-stack/03-volcano | OK |
| reference | 04-pathway-enricher | spec-mvp/skills/reference-stack/04-pathway-enricher | OK |
| reference | 04-pathway-workflow | spec-mvp/skills/reference-stack/04-pathway-workflow | OK |
| reference | 05-kegg | spec-mvp/skills/reference-stack/05-kegg | OK |
| runtime-projection | bulk-pa-luad | .agents/skills/bulk-pa-luad | OK |
| runtime-projection | cross-branch-integration | .agents/skills/cross-branch-integration | OK |
| runtime-projection | multiqc | .agents/skills/multiqc | OK |
| runtime-projection | pathway-enrichment | .agents/skills/pathway-enrichment | OK |
| runtime-projection | wgcna-module-constraint | .agents/skills/wgcna-module-constraint | OK |

压缩归档哈希：compressed/SHA256SUMS.txt

## 独立项目运行时入口

本目录是 13 个 Bio Skill 的审计/来源层。单独下载后，Codex 和 Spec Kit 实际
使用的根级入口是：

- `.specify/`：官方脚本、模板、Constitution、已安装 preset、extension 和
  workflow registry；
- `.agents/skills/`：官方 9 个核心阶段、`speckit-taskstoissues`、Bio 扩展
  命令和 5 个当前项目适配器。

因此，`runtime-projection` 和根级 `.agents/skills` 的副本不计为新的逻辑
Skill；参考组件也不会自动进入当前 MVP workflow。
