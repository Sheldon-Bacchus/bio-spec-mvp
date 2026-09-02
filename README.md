# bio-spec-005-research-core

skills-nextflow research-core 独立项目（2026-09-02 整理）

把 bio-spec-kit 仓库中的 specs/005-skills-nextflow-research-core 整理为一个**独立项目**：
不是大仓库里的一次 run，而是完整的项目文件树，包含规格工作包、13 个关联 Bio Skills、
以及相关的 preset / workflow / extension 源文件。

## 目录结构

| 目录 | 内容 |
|---|---|
| 01-spec-work-package/ | 005 工作包：spec/plan/tasks/analysis、contracts、evaluation（含 positive/negative run 证据）、review、inputs、mappings、checklists、review-chain.yml |
| 02-skills/ | 13 个 Bio Skills：adapters（5）、reference-stack（8）、runtime-projection（5，Codex 投影）、compressed（zip + SHA256SUMS） |
| 03-package-sources/ | preset / workflow / extensions 源文件（尚未安装；CLI 仍报告 No presets installed / No extensions installed） |

## 13 个 Skills 构成

5 个项目适配器：bulk-pa-luad、cross-branch-integration、multiqc、pathway-enrichment、wgcna-module-constraint

8 个参考组件：01-mds、02-deg、02-deg-results、03-de-visualization、03-volcano、04-pathway-enricher、04-pathway-workflow、05-kegg

规则：保留原始 SKILL.md / references / scripts / examples / tests；未翻译、未合并、未修改；不包含 reference-stack-zh-CN 中文镜像。

来源（原始文件均未改动）：specs/005-skills-nextflow-research-core、spec-mvp/skills、.agents/skills、presets/bio-research-mvp、workflows/bio-research-mvp、extensions/bio-multiqc、extensions/bio-review。
