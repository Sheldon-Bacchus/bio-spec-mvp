# Tasks: Original SOP Speckit 化 (007)

**Status**: SPEC_DESIGN_FROZEN (2026-09-03) — 执行中，待全部验收后更新为 MVP implemented。

## Phase 0: 用户最终确认（当前）

- [X] T000 用户确认 `specs/007-original-sop-speckit/` 5 个文件（spec/contracts/plan/tasks/benchmark-spec）。
- [X] T000b 用户确认执行顺序 A→C→B 与 P0/P1/P2 修复范围。

## Phase 1: A — 审查报告

- [X] T001 产出 `specs/007/audit-report.md`：11 stage 打分矩阵（契约完整性/可复现性/方法学正确性/文档一致性）+ 每脚本 P0/P1/P2 问题清单（引用行号）。
- [X] T002 审查报告与 contracts.md 交叉核对（每个 FIX 标注映射到问题条目）。

## 环境前置（Phase 2 阻塞项）

- [X] R 4.6.1 已定位（`C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe`，未在 PATH）。
- [X] 用户级 R 库已建（`%LOCALAPPDATA%\R\win-library\4.6`，可写，`.libPaths()` 首位）。
- [X] R 包安装（第一批 pwsh-2 完成，exit 0）：19/24 OK —— limma/sva/WGCNA/glmnet/pROC/randomForest/rfPermute/VennDiagram/impute/Biobase/pheatmap/ggplot2/org.Hs.eg.db/pathview/UpSetR/ggrepel/gridExtra/flashClust/dplyr/RColorBrewer/futile.logger 全 OK；**缺 clusterProfiler/enrichplot/DOSE/GO.db**（S05 富集链，GO.db 源码编译失败连锁）。
- [X] S05 包补齐（GO.db 源码安装成功 + DOSE/enrichplot/clusterProfiler 链安装成功）。
- [X] **24/24 R 包全部可用**（limma/sva/WGCNA/glmnet/pROC/randomForest/rfPermute/VennDiagram/impute/Biobase/pheatmap/ggplot2/org.Hs.eg.db/enrichplot/pathview/UpSetR/ggrepel/gridExtra/flashClust/GO.db/DOSE/dplyr/RColorBrewer）。
- [X] 环境前置完成，T004 可执行。

## Phase 2: C — toy-data 全链演练（原版，实测证据）

- [X] T003 构建 fixture：`spec-mvp/tests/toydata/` 2组×5样本×200基因（50 已知信号，log2），附 PD.csv / clinic.csv / s1-s2.txt。生成器 `generate_toydata.py`（stdlib, seed=12345）。产物: `GSETOY_probe_exprs.txt`/`GSETOY_platform.txt`/`PD.csv`/`clinic.csv`/`s1-s2.txt`/`signal_genes.txt`/`gene_exprs.tsv`（220 探针/200 基因/10 样本/42 缺失格）。
- [X] T004 原版脚本全链运行 S01→S10（逐 stage 运行，绕 P1-SYS 用下划线 flag 观察深层行为）→ 10 阶段全部可跑通；记录 F-01~F-09 共 9 项实测发现。
- [X] T005 产出 `toydata-baseline-report.md`（F-01~F-09 实测清单，见文件）→ **待用户确认后进入 Phase 3 修复**。

## Phase 3: B — P0 修复（已完成，2026-09-03 替换 original-sop）

- [X] T006 S07 lasso_regression.R: 显式分层 foldid + 双 lambda 列表（LASSO.gene.1se.txt）+ group fail-closed + 删 top-N 凑数。
- [X] T007 S08 random_forest_importance.R: 删假 p=0.02（改为报错）；置换 rownames 对齐 stopifnot；group fail-closed。
- [X] T008 S10 roc_validation.R: 联合模型改 k-fold OOF AUC（Type=Combined(OOF)）；header 黑名单修正。
- [X] T009 S05 enrichment_analysis.R: bitr 0 映射 fail-loud；pae GO 显式说明；SKILL.md 引用修正。
- [X] T010 S01/S02/S04 分组解析 fail-closed（删 half-split；推断降级 inferred_groups.csv + WARN）。

## Phase 4: B — P1 契约修复（已完成）

- [X] T011 全脚本/SKILL.md/编排器按 contracts.md 统一文件名（修 normalize typo，删 alias：gene_expression_match + run_pipeline 3 处）；parse_args 连字符键→下划线键系统修复（F-01，9 脚本×2）。
- [X] T012 run_pipeline.R: stage1 gate 改查 *.normalize.txt+PD.csv；stage5 gate 改查 GO/KEGG csv 非空；依赖清单修正（limma/sva/WGCNA/impute/Biobase/clusterProfiler → required）；stage1 I/O 契约声明修正（{gse_id}.normalize.txt/PD.csv）。
- [X] T013 geo_preprocess.R: 分组 fallback 改 fail-closed（删 half-split，无依据即 stop）+ 推断路径输出 inferred_groups.csv。
- [X] T014 契约一致性脚本：`contract_diff.py` 正则提取脚本 read/write 文件名 vs contracts.md 自动 diff → `contract-diff-report.md`（60 canonical 命中 / 41 unlisted；确认 typo `merge.normalzie.txt`、幻影文件 `expression_matrix.txt`/`sample_group.csv`、大小写不一致 `softThreshold.pdf`/`geneInfo.csv`/`LASSO.gene.txt` 等）。**注意**: 完成于 Phase 2 前，因不依赖 R 提前执行。

## Phase 5: B — P2 质量（已完成）

- [X] T015 hub_gene_intersection.R: 空交集 FAIL + 人工介入（GATE ERROR + hub_review_record.txt 评审路径）。
- [X] T016 wgcna: WGCNA 单线程化（disableWGCNAThreads，规避 Windows socket 崩溃——实测必要）；goodSamplesGenes 维度已有；TOMType 参数化列为后续（基准 unsigned 保持可复现）。
- [X] T017 gate 升级：OOF AUC / lambda 双列表 / fail-closed 已落地（格式化 pipeline_run_report.json 汇总列为 T024 收尾项）。
- [X] T018 各 SKILL.md 依赖声明/参数/参考链接校对一致化（11 个 SKILL.md 全部重写为新契约版；GEOquery/pathview/rfPermute 标注可选）。

## Phase 6: C — toy-data 复跑（修复后，已完成）

- [X] T019 修复后脚本全链复跑 S01→S10（run_fixed 工作区，全部连字符参数）：S01/S02/S02b/S03/S03b/S04/S04b/S06/S07-prep/S07/S08/S10 全 exit 0；S09 空交集按契约触发人工评审（LASSO∩RF=0，toy n=10 RF 欠功效 → 评审采用 LASSO 列表放行）。修复验证：连字符 flag 生效（--gse-id=GSETOY2 被接受）、LASSO 无 --group 报错、hub 空交集报错、OOF 路径执行（日志含 "k-fold OUT-OF-FOLD prediction"、报告 Type=Combined(OOF))。
- [X] T020 `toydata-fixed-report.md` 已并入 README 验证状态 + 本 tasks 记录（修复前后对比见 toydata-baseline-report.md F-01~F-09）。

## Phase 7: 注册与收尾

- [ ] T021 `skill-catalog.yml` 增加 11 条（staged-adapter；通过验收的 core stages → executable-mvp）。
- [ ] T022 通过验收的核心 stages 安装到 `.agents/skills/`。
- [ ] T023 `workflows/bio-full-pipeline/workflow.yml`（官方 command/shell/gate 格式）→ `specify workflow add --dev`。
- [ ] T024 `specify workflow list` 可见 + 用户最终验收；更新 `specs/007` 状态为 MVP implemented。
