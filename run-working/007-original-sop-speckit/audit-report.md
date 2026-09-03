# Audit Report: Original SOP 逐项审查 (007)

**Date**: 2026-09-03 | **Status**: COMPLETE (T001/T002) | **Spec**: [spec.md](spec.md) | **Contracts**: [contracts.md](contracts.md)
**范围**: `spec-mvp/skills/original-sop/` — 11 SKILL.md + 15 R scripts。

## 审查方法（四条线）

1. **契约线**: SKILL.md 声明 input/output ≈ 脚本实际 read/write 文件名 diff。
2. **工程线**: CLI 参数化、日志、gate 是否真实拦截（橡皮图章检测）。
3. **方法学线**: limma/WGCNA/LASSO/RF/ROC/富集 vs 文献标准做法。
4. **文档线**: SKILL.md 依赖声明/参考链接/参数与实际实现一致性。

---

## 一、总分矩阵（1-5 分；5=合格）

| Stage | 契约完整性 | 可复现性 | 方法学正确性 | 文档一致性 | 总评 |
|---|---|---|---|---|---|
| S01 geo-dataprep | 3 | 4 | 3 | 3 | P1 需修 |
| S02 batch-norm | 3 | 4 | 3 | 4 | P1 需修 |
| S03 wgcna | 4 | 4 | 3 | 3 | P2 需修 |
| S04 deg-limma | 3 | 4 | 3 | 3 | P1 需修 |
| S05 enrichment | 2 | 3 | 2 | 2 | **P0 需修** |
| S06 gene-intersection | 3 | 4 | 3 | 3 | P2 需修 |
| S07 ml-lasso | 3 | 3 | **1** | 3 | **P0 需修** |
| S08 ml-randomforest | 2 | 3 | **1** | 2 | **P0 需修** |
| S09 hub-literature | 3 | 4 | 2 | 3 | P2 需修 |
| S10 biomarker-roc | 3 | 3 | **1** | 3 | **P0 需修** |
| Orchestrator | 2 | 2 | 2 | 2 | P1 需修 |

**结论**: 工程外壳（参数化/日志/seed/gate 框架）整体合格；方法学硬伤集中在 ML 三件套（S07/S08/S10）+ 富集（S05）。

---

## 二、全局问题（G-01~G-07，见 contracts.md）

| ID | 问题 | 证据位置（文件: 行） |
|---|---|---|
| G-01 | 文件名 typo `merge.normalzie.txt` 被制度化 | run_pipeline.R: L139,L154,L304; gene_expression_match.R: L62,L64 |
| G-02 | 分组推断靠"前一半 Control/后一半 Treat"静默 fallback | geo_preprocess.R: L216-217 (名称启发式), L223-225 (half-split) |
| G-03 | 分组标签从样本名 regex 硬解析 | lasso_regression.R: L101-110; random_forest_importance.R: L116-121; roc_validation.R: L139-144; pca_qc.R: L116; limma_diff.R: L122-123 |
| G-04 | gate 多为文件存在/行数，科学指标未拦截 | 全编排器 gate_check 只查存在; run_pipeline.R: L192 (passed=TRUE 硬编码) |
| G-05 | seed 12345 全链复用 | 15/15 scripts（enrichment L9/L18, roc L17-18, venn L21, lasso L15-16, rf L22, wgcna L8/L23, geo L9/L20 等） |
| G-06 | hub 空交集静默 fallback 到并集 | hub_gene_intersection.R: L99-101 |
| G-07 | 辅助产物未进契约表 | candidate_hub_genes_wgcna/deg.txt 等（contracts.md 已列） |

---

## 三、逐 Stage 问题清单（P0/P1/P2）

### S01 geo-dataprep (`geo_preprocess.R`)
- **[P0]** 分组推断 fallback 静默"前一半 Control 后一半 Treat"（L223-225）+ 名称启发式（L216-217）→ 无显式分组时产错标签不报警。
- **[P1]** 默认输入 `biofilm.probeid.exprs.txt`/`GPL84.txt`（L35-36）不是编排器会传的文件；defaults 与真实调用脱节。
- **[P1]** 恒真 gate：`nrow(group_df) == ncol(gene_exprs)`（L241）两者同源必等。
- **[P2]** KNN 填充后无"填充比例"记录；log2 检测分支（L160-170）状态未写入 report。
- **OK**: avereps 多探针→基因取均值（L127）、缺失 >20% 过滤（L144-147）、log2 检测启发式、stopifnot 框架。

### S02 batch-norm (`sva_combat.R`, `normalize.R`, `pca_qc.R`)
- **[P0]** 样本前缀剥离 `sub("^[^_]+_", ...)`（PD matching）多级数据集名易错；PD 缺失时 `mod=NULL` 静默降级（L180）→ 生物学变量未保护（对比 contracts G-03）。
- **[P1]** 基因交集 <50 直接 stop（L103）—— 多平台合并真实情景可能过严/过松无参。
- **[P2]** `normalize.R` 与 `sva_combat.R` 职责重叠（各自主张 log2+quantile vs ComBat）；`run_pipeline` 只调 sva_combat 不管 normalize.R → 归一化入口不明确。
- **OK**: ComBat 带 mod 保护；boxplot 前后对比；pca_qc 双面板（分组分离+批次混合）。

### S03 wgcna (`wgcna_build.R`, `wgcna_module_export.R`)
- **[P2]** `TOMType="unsigned"`（L227）默认丢方向；应参数化并默认 signed（microarray 可 unsigned 覆盖）。
- **[P2]** `goodSamplesGenes(t(raw_mat))`（L99-101）后按 gsg$goodGenes/goodSamples 重新索引原始矩阵——顺序经推导正确，但过滤前后维度无显式断言（与 G-04 联动）。
- **[P2]** 软阈值未达 R² 0.85 的 fallback 链：0.80 通过 → 最高 R²（L180-189）→ 实际值未写入 run report。
- **[P2]** MM/GS 用 `cor(datExpr, MEs)`（module_export L59-64）而非 TOM 基 kME —— 结果含义弱于标准；应 `signedKME` 或显著标注。
- **OK**: pickSoftThreshold、blockwiseModules 参数齐全、module-trait 热图 + p 值、RData 工作区保存。

### S04 deg-limma (`limma_diff.R`, `volcano_heatmap.R`)
- **[P0]** 分组 Method C 样本名推断 fallback（L122-123）静默；PD.csv 优先级够但 fallback 不 fail-closed。
- **[P1]** s1/s2.txt 与 PD.csv 双入口逻辑重复（L93-118），契约应只留 PD.csv 为主 + s1/s2 兼容。
- **[P2]** 热图 top50 上下调取法（`tail` 顺序依赖 logFC 排序）OK；`volcano_heatmap` 依赖 `all.txt` 列名硬编码（adj.P.Val/logFC）。
- **OK**: design `~0+Group` + makeContrasts 正确；eBayes/topTable FDR；候选 DEG 导出（L214-217）。

### S05 enrichment (`enrichment_analysis.R`)
- **[P0]** `species=pae` 时 GO 分支直接跳过（L178 `[WARN] Non-human...`），但 SKILL.md 声明支持 GO+KEGG → 静默缺能力。
- **[P0]** KEGG 在线依赖（enrichKEGG）失败 tryCatch 返回 NULL（L127-136）→ 空 csv 无明确降级记录。
- **[P1]** SKILL.md 参考脚本错误指向 `../bio-01-geo-dataprep/scripts/geo_preprocess.R`（KEGG 部分）—— geo_preprocess 无 KEGG。
- **[P1]** `fc_matched <- gene_fc_vec[id_map$SYMBOL]`（L99）SYMBOL 重复时错位。
- **OK**: BP/CC/MF 三 ont 循环、setReadable、barplot/dotplot/cnetplot。

### S06 gene-intersection (`venn_intersection.R`)
- **[P2]** header 黑名单候选列名（L151 附近 read_gene_list）无 `x`/`V1` 排除——与 S09/S10 黑名单一致性问题；基因名 `x` 被误删风险（S10 已处理）。
- **[P2]** gate "<2 则 WARN 不 halt"（L151）：按 contracts 要求 <2 强制人工 review。
- **OK**: 自动探测分隔符、列名自动识别、VennDiagram + grid.draw。

### S07 ml-lasso (`lasso_regression.R`, `gene_expression_match.R`)
- **[P0]** 分组从样本名 regex parse（L101-110）+ 剥尾数字 → 标签可能全错且不报错（G-03 核心命案）。
- **[P0]** `cv.glmnet` 无显式 `foldid` → 不可复现 fold 划分；无分层（strata）→ 类别不平衡折内无正类。
- **[P0]** lambda.min 空时 fallback 到"top 5 系数"（L188-191）→ 凑数基因未标记。
- **[P1]** `gene_expression_match.R` 依赖 `merge.normalzie` typo fallback（L62-64）。
- **OK**: alpha=1 显式、family=binomial、非有限值中位数填充、min_class_size 调整 nfolds（合理兜底）。

### S08 ml-randomforest (`random_forest_importance.R`)
- **[P0]** **伪造 p 值**: rfPermute 无 `MeanDecreaseGini.pval` 时硬编码 `richness_data$p_value <- 0.02`（L185）→ 假显著基因列表。这是数据造假级别缺陷。
- **[P0]** 手工置换循环（L204-215）`perm_gini[i,] >= actual_gini[i]` 未校验 rownames 对齐 → 静默错位风险。
- **[P1]** SKILL.md 说 `num.cores=2`，脚本默认 `num_cores=1`（L28）→ 文档不一致。
- **[P2]** rfPermute 不可用时自定义置换（ntree=200, min(100,nrep)）参数未进 report。
- **OK**: make.names 列名处理 + 映射回原符号（L78-84）、重要性排序 + 显著性标注、top-N fallback 有 WARN。

### S09 hub-literature (`hub_gene_intersection.R`)
- **[P0/G-06]** 空交集静默 fallback 到 `union_genes`（L99-101）→ "双算法共识"失效，产出膨胀 hub 列表。
- **[P1]** header 黑名单（L55-56）`c("gene","genes","geneNames","Symbol","x","V1")` 误删合法基因名 `x`。
- **OK**: Jaccard/union/lasso_only/rf_only 指标齐全；summary 文件结构化。

### S10 biomarker-roc (`roc_validation.R`)
- **[P0]** **in-sample 联合模型**: `glm(disease ~ ., ...)` + 同批样本 `predict(type="response")` 算 AUC（L223-229）→ 联合 AUC 虚高，Gate（≥0.8）橡皮图章。
- **[P0]** 单基因 AUC 用 `roc(..., ci=TRUE)` OK，但无 bootstrap 替代；`auc.ci` 依赖 pROC 默认（DeLong 在校正样本上 OK）。
- **[P1]** header 黑名单误删（L101-102）如上。
- **[P2]** 阈值 `auc_gate_single=0.70, combined=0.80` 硬编码 OK 但未写入 report。
- **OK**: 单基因+联合双路径、Youden cutoff、报告 csv、图形配色规范。

### Orchestrator (`run_pipeline.R`)
- **[P1/G-01]** typo alias `merge.normalzie` 三处（L139,L154,L304）。
- **[P1]** Stage1 gate 检查幻影文件 `expression_matrix.txt`/`sample_group.csv`（L136-150）→ 永远 FAIL（或撞 typo alias 假通过）。
- **[P1]** Stage5 gate 硬编码 `list(passed=TRUE)`（L192）→ 假通过。
- **[P1]** 依赖清单把 limma/sva/WGCNA/clusterProfiler 放 optional（L98-121）→ 环境检查漏强依赖。
- **[P1]** 只传 `--output-dir`（L250-268），不传各 stage 契约参数（--matrix/--input/--group-file）→ 默认值错乱。
- **OK**: 起止阶段参数、dry-run、--force、gate report CSV、日志分级。

---

## 四、强项（重写时保留）

1. 参数解析统一（--key=value / --key value）15/15 脚本。
2. 日志分级 [INFO/ERROR/SUCCESS/WARN/GATE] + 退出码。
3. set.seed 全链 + `if (!interactive()) main()` 规范。
4. tryCatch 降级框架（有害 fallback 需按 P0 处理，有益 fallback 保留）。
5. 图形配色/布局规范（blueWhiteRed、coord_flip、显著性标注）。
6. SKILL.md frontmatter（name/description）标准——可被 agent 发现。

---

## 五、与 contracts.md FIX 映射

| contracts.md FIX | 对应本报告问题 |
|---|---|
| G-01 | 二-1 / orchestrator P1 |
| G-02, G-03 | S01 P0 / S02 P0 / S04 P0 / S07 P0 / S08 P0 / S10 P0 |
| G-04 | S03 P2 / orchestrator P1（passed=TRUE） |
| G-06 | S09 P0 |
| S05 P0 ×2 | enrichment 报错路径 + KEGG 降级 |
| S07 P0 ×3 | 分层 foldid / 假 fallback / 标签 |
| S08 P0 ×2 | 假 p=0.02 / rownames 对齐 |
| S10 P0 | OOF 联合 AUC |

## 附: Benchmark 基线（Phase 2 toy-data 原版演练预计会发现）
- S01: 分组推断错误（half-split 生效）→ `PD.csv` 与矩阵列不匹配。
- S07: 样本名 parse 若 fixture 名含 control/treat 则"碰巧"对 → 需构造混淆名验证 fail-closed。
- S08: rfPermute 不可用路径产出 p=0.02 假显著。
- S10: 联合 in-sample AUC 虚高（≈1.0），OOF 修复后回落。
