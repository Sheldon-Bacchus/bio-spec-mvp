# Contracts: Original SOP 统一 I/O 契约表 (007)

**Status**: SPEC_DESIGN_FROZEN (2026-09-03, user confirmed)
本表是 S01–S10 及编排器的**唯一**文件名/列名/阈值事实源。脚本、SKILL.md、编排器、verifier 一律引用此表。
修复要点已内联标注（typo 修正、fail-closed 分组、科学 gate、禁伪造）。

## 0. 全局修复项（适用于所有阶段）

| 项 | 原状 | 修复后 |
|---|---|---|
| G-01 | 文件名 typo `merge.normalzie.txt` 被当 alias 制度化 | 删除该 alias；全链统一 `merge.normalize.txt` |
| G-02 | 分组解析依赖样本名正则 + "前一半 Control/后一半 Treat" fallback | 显式 metadata 驱动；推断仅作 WARN 降级 + 输出推断表 `inferred_groups.csv` 供人工确认 |
| G-03 | 分组标签从样本名 parse（`gsub(.*)_(.*)`+剥尾数字） | 一律 `--group-file`（PD.csv 格式: sample,group）驱动；缺失即报错 |
| G-04 | gate 多为"文件存在/行数" | 升级为科学指标校验 + 写入 `pipeline_run_report.json` |
| G-05 | 随机种子 12345 各处复用 | 保留，但 `pipeline_run_report.json` 记录每阶段实际 seed 与参数 |
| G-06 | hub 空交集静默 fallback 到并集 | FAIL + 人工介入（FR-004） |
| G-07 | `candidate_hub_genes_deg.txt`/wgcna txt 等辅助产物未进契约 | 全部列入契约表 |

## 1. S01 geo-dataprep

| 方向 | 文件 | Schema / 说明 |
|---|---|---|
| IN | `{gse_id}_probe_exprs.txt` | 原始探针矩阵: 首列探针ID + 样本列 |
| IN | `{gse_id}_platform.txt` | 平台注释: ID + Gene.Symbol（可缺失→已注释为符号矩阵） |
| IN | `--sample-con/--sample-treat` | 可选显式分组（逗号分隔样本ID） |
| OUT | `{gse_id}.normalize.txt` | 行=Symbol, 列=样本, 值=log2；无 NA（KNN 填充后） |
| OUT | `PD.csv` / `group.txt` | sample,group 列；**推断时输出 `inferred_groups.csv` 并 WARN** |
| GATE | 科学校验 | 基因数>0；无 NA；log2 检测记录 99th 分位；`nrow(PD)==ncol(expr)` 仍保留但不再作为唯一 gate；禁用"前一半/后一半" |
| FIX | P0 | 分组 fallback 改 fail-closed；删除恒真 gate 依赖 | 

## 2. S02 batch-norm

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `*.normalize.txt` ×N | 每数据集一个（`--input-files` 或 pattern） |
| IN | `PD.csv` | 保护生物学变量（ComBat `mod`）；缺失→WARN 降级记录 |
| OUT | `merge.preNorm.txt` | 去批次前合并矩阵（交集基因） |
| OUT | `merge.normalize.txt` | ComBat 后 |
| OUT | `boxplot_comparison.pdf` | 前后对比 |
| OUT | `pca_qc.pdf` | 双面板（分组分离 + 批次混合） |
| GATE | 科学校验 | 交集基因数 ≥ 50 否则 stop；preNorm/norm 文件存在；PCA 图非空；批次≥2 |
| FIX | P0 | 交集过小 fail-closed（已有）；mod 缺失时输出明确 WARN 记录 |

## 3. S03 wgcna

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `merge.normalize.txt` | 去批次后；top MAD 5000 基因 |
| IN | `clinic.csv` | sample + 表型列（数值/二元/多level因子 → dummy） |
| OUT | `softThreshold.pdf` | 软阈值诊断 |
| OUT | `moduleDendrogram.pdf` | 聚类树 |
| OUT | `module_trait_heatmap.pdf` | 模块-表型相关热图 |
| OUT | `geneInfo.csv` | 全基因模块归属/MM/GS |
| OUT | `module_genes.csv` | 目标模块基因 + is_hub 标记 |
| OUT | `candidate_hub_genes_wgcna.txt` | 模块基因符号列表（供 S06） |
| OUT | `wgcna_net.RData` | 工作区（供 export 脚本） |
| GATE | 科学校验 | 软阈值 R² ≥ 0.85（记录实际值，未达则 WARN+记录）；目标模块-表型 p<0.05（记录）；module_genes 非空 |
| FIX | P2 | goodSamplesGenes 过滤后维度对齐校验；MM 改基于 TOM 的 kME（signedKME）或显著标注 cor-based；`TOMType` 暴露参数（默认 signed，microarray 若输入说明 unsigned 可覆盖） |

## 4. S04 deg-limma

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `merge.normalize.txt` | 表达矩阵 |
| IN | `PD.csv`（或兼容 `s1/s2.txt`） | 分组；PD.csv 优先 |
| OUT | `all.txt` | id + logFC + P.Value + adj.P.Val |
| OUT | `diff.txt` | |logFC|≥1 & adj.P<0.05 |
| OUT | `diffGeneExp.txt` | 显著基因表达 |
| OUT | `heatmap.pdf` / `vol.pdf` | 可视化 |
| OUT | `candidate_hub_genes_deg.txt` | 显著基因符号列表（供 S06） |
| GATE | 科学校验 | 显著 DEG>0；all.txt 含 logFC/adj.P.Val；图形非空 |
| FIX | P0 | 分组解析 fail-closed（禁样本名 regex fallback 静默） |

## 5. S05 enrichment

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `diff.txt` | 显著基因（Symbol + 可选 logFC） |
| IN | `--species` | human (hsa) / pae |
| OUT | `GO_enrichment.csv` | BP/CC/MF 合并；Ontology 列 |
| OUT | `KEGG_enrichment.csv` | 通路 |
| OUT | `GO_{ont}_barplot.pdf` `GO_{ont}_dotplot.pdf` `KEGG_barplot.pdf` `KEGG_dotplot.pdf` | 可视化（cnetplot 可选） |
| GATE | 科学校验 | GO ≥1 term q<0.05 或明确记录空结果；KEGG 同（在线依赖失败→明确 WARN 降级记录） |
| FIX | P0 | pae 的 GO 无法执行时**明确报错**（org.Pa.eg.db 不可用则说明），禁止静默跳过；KEGG 在线失败 WARN 记录；修正 SKILL.md 指向 geo_preprocess 的错误 reference |

## 6. S06 gene-intersection

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `module_genes.csv` 或 `candidate_hub_genes_wgcna.txt` | WGCNA 基因集 |
| IN | `diff.txt` 或 `candidate_hub_genes_deg.txt` | DEG 基因集 |
| OUT | `candidate_hub_genes.txt` | 交集（单列无头） |
| OUT | `venn_plot.pdf` | 韦恩图 |
| GATE | 科学校验 | 交集 ≥2，否则 WARN + 人工确认（<2 不自动 HALT 但强制人工 review） |
| FIX | P2 | 列名自动识别黑名单（`x`/V1 误删）修正 |

## 7. S07 ml-lasso

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `merged_file.txt` | `gene_expression_match` 产出（行=基因, 列=样本；首列 geneNames） |
| IN | `PD.csv` | 分组（`--group-file`） |
| PREP | `gene_expression_match.R` | `merge.normalize.txt` + `candidate_hub_genes.txt` → `merged_file.txt` + `merged_data.csv` |
| OUT | `LASSO.gene.txt` | lambda.min 非零系数基因 |
| OUT | `lasso_coefficients.csv` | 基因/系数表（含 lambda.1se 列表 `LASSO.gene.1se.txt`） |
| OUT | `lasso.pdf` / `cvfit.pdf` | 路径图/CV 曲线 |
| GATE | 科学校验 | LASSO.gene.txt≥1；**显式分层 foldid**（strata=y）；类别数<2 或 min_class_size<3 -> stop |
| FIX | P0 | stratified CV + 显式 foldid；双 lambda 列表导出；禁止"top 5 凑数" fallback 静默（改 WARN+记录） |

## 8. S08 ml-randomforest

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `merged_file.txt` | 同上 |
| IN | `PD.csv` | 分组 |
| OUT | `richness.txt` | 重要性表 + **真实置换 p 值** |
| OUT | `rf_genes.txt` | p<0.05（或明确记录 top-N fallback 及原因） |
| OUT | `rf_importance.pdf` | 排序图 |
| GATE | 科学校验 | ≥1 基因真实 p<0.05；**禁止伪造 p=0.02**；rfPermute 失败→显式置换检验（rownames 对齐校验）或报错 |
| FIX | P0 | 删假 p fallback；参数 `--nrep/--cores` 与 SKILL.md 一致（默认 nrep=299, cores 可由参数给） |

## 9. S09 hub-literature

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `LASSO.gene.txt` | LASSO 列表 |
| IN | `rf_genes.txt` | RF 列表 |
| OUT | `final_hub_genes.txt` | **交集**（禁并集 fallback） |
| OUT | `hub_intersection_summary.txt` | Jaccard + 各集大小 |
| OUT | `literature_evidence_report.md` | MCP 辅助文献证据（biomcp/scite，人工确认） |
| GATE | 科学校验 | final_hub≥1；**空交集→FAIL + 人工介入**（FR-004） |
| FIX | P2 | 删静默 union fallback |

## 10. S10 biomarker-roc

| 方向 | 文件 | Schema |
|---|---|---|
| IN | `merged_file.txt`（或独立验证集矩阵） | 表达 |
| IN | `final_hub_genes.txt` | hub 列表 |
| IN | `PD.csv` | 分组 |
| OUT | `roc_single_gene.pdf` | 单基因 ROC |
| OUT | `roc_combined.pdf` | 联合 ROC（**OOF**） |
| OUT | `auc_report.csv` | 基因/AUC/CI/灵敏/特异/阈值；**含 OOF 标记列** |
| GATE | 科学校验 | 单基因 OOF AUC≥0.7 或联合 OOF AUC≥0.8；**禁 in-sample 联合 AUC** |
| FIX | P0 | 联合模型改 k-fold OOF 预测概率；单基因 bootstrap CI；hub 列表 header 黑名单（x/V1 误删）修正 |

## 11. Orchestrator（bio-pipeline-orchestrator）

| 方向 | 文件 | Schema |
|---|---|---|
| CMD | `run_pipeline.R --project-dir --start-stage --end-stage --dry-run --force` | 参数化起止阶段 |
| IN | 各阶段契约输入 | 按契约表 |
| OUT | `pipeline_run.log` | 执行日志 |
| OUT | `pipeline_gate_report.csv` | gate 记录 |
| OUT | `pipeline_run_report.json` | **科学指标汇总（新增）** |
| GATE | 科学校验 | 每阶段调用真实 gate；修复 stage1（查 `{gse}.normalize.txt`+PD.csv）与 stage5（查 GO/KEGG csv 非空）硬编码 passed=TRUE；依赖清单按真实依赖（limma/sva/WGCNA/clusterProfiler/glmnet/randomForest/pROC 全部 required） |
| FIX | P1 | 编排器给每 stage 传**契约表参数**（--input/--matrix/--group-file 等），不只 --output-dir |

## 12. 注册目标

| 产物 | 位置 | 状态流转 |
|---|---|---|
| skill-catalog.yml 条目 ×11 | `spec-mvp/skills/skill-catalog.yml` | source-only → staged-adapter（审查+契约后）→ executable-mvp（toy-data 通过后） |
| .agents/skills 注册 | `.agents/skills/<id>/SKILL.md` | 通过验收的核心 stages 注册 |
| 官方 workflow | `workflows/bio-full-pipeline/workflow.yml` | command/shell/gate steps（specify workflow add --dev） |
