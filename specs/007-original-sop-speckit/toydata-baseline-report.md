# Toy-Data Baseline Report — 原版脚本实测 (007 Phase 2)

**Date**: 2026-09-03 | **Status**: COMPLETE (T003/T004/T005)
**Fixture**: `spec-mvp/tests/toydata/` v2（交叉批次：GSEA=6 样本[control_1..3, treat_1..3]、GSEB=4 样本[control_4..5, treat_4..5]；200 基因含 50 信号；2% 缺失；log2；seed=12345）
**运行**: `baseline_full.ps1 / baseline_part3/4/5.ps1`（逐 stage 原版脚本；见 `baseline-run.log`）
**方法备注**: 使用了 `--gse_id`/`--input_files` 等下划线变体绕过 P1-SYS（见下），以观察更深层行为；所有绕过均已记录。

---

## 一、逐 Stage 实测结果

| Stage | 退出 | 结果 | 说明 |
|---|---|---|---|
| S01 geo-dataprep | 0 | ✅ PASS | 220 探针→200 基因；KNN 填充 42 缺失；log2 检测正确保留；输出 GSE10030.normalize.txt |
| S02 sva_combat | 0 | ✅ PASS（fixture 修正后） | 200 交集基因；ComBat 带 mod 保护 group；输出 preNorm/norm + boxplot |
| S02b pca_qc | 0 | ✅ PASS | 双面板 PDF 生成 |
| S03 wgcna_build | 0 | ✅ PASS | 软阈值选择、blockwiseModules、模块树/热图 PDF |
| S03b wgcna_module_export | 0 | ✅ PASS | geneInfo.csv / module_genes.csv（57 基因，含全部 44 DEG） |
| S04 limma_diff | 0 | ✅ PASS | all.txt / diff.txt（44 显著 DEG）；**含全部 50 信号基因？→ 44/50 找回（88%）** |
| S04b volcano | 0 | ✅ PASS | vol.pdf |
| S05 enrichment | 0（真实基因） | ✅ PASS（fixture 边界） | 合成符号 bitr 硬报错（见 F-05）；真实基因 253/258 映射 → GO 2502 / KEGG 171 |
| S06 venn | 0 | ✅ PASS | WGCNA(57) ∩ DEG(44) = 44 交集 → candidate_hub_genes.txt |
| S07-prep match | 0 | ✅ PASS | 43/43 candidate 匹配 → merged_file.txt |
| S07 lasso | 0（标签修复后） | ✅ PASS | LASSO.gene.txt = 8 基因，**8/8 真信号** |
| S08 rf | 0 | ✅ PASS | rf_genes.txt = 1 基因（g039，真信号）；rfPermute 正常路径 |
| S09 hub | 0 | ✅ PASS（正常路径） | final_hub = 9（LASSO 8 ∪ RF 1，全部真信号） |
| S10 roc | 0 | ✅ PASS（但结果不可信） | **全部 AUC = 1.0（含联合面板）— in-sample 假象** |

---

## 二、实测发现的 P0/P1 问题（带证据）

### F-01 [P1-SYS 系统性] parse_args 连字符键 vs 下划线默认键不匹配
- **证据**: `--gse-id=GSETOY` 被忽略 → 输出仍为 `GSE10030.normalize.txt`；`--input-files=A,B` 被忽略 → "Found 0 dataset files"。
- **范围**: 所有含连字符的多词 flag（--gse-id/--input-files/--sample-con/--probe-col/--symbol-col/--out-prenorm/--out-norm/--out-boxplot 等）全部静默失效。单词 flag（--matrix/--platform/--outdir）正常。
- **根因**: `parse_args` 写 `res[["gse-id"]]`（连字符），脚本读 `opt$gse_id`（下划线）。

### F-02 [P0] 批次前缀污染破坏 ML 标签解析
- **证据**: sva_combat 合并后列名 = `GSEA_control_1`（`paste0(tag,"_",colnames)`），PD.csv 样本名为裸 `control_1`；**LASSO/RF/ROC 无前缀剥离**（wgcna/pca_qc 有 `sub("^[^_]+_",...)`）→ label_map 全 NA → "Expected at least 2 distinct classes" 崩溃。
- **影响**: 多数据集真实场景 ML 段必挂。

### F-03 [P0] S10 ROC 全 AUC=1.0（in-sample 联合模型实锤）
- **证据**: 单基因 + Combined_Panel 全部 AUC=1.0, CI=1-1, sens/spec=1。logistic 回归在训练集拟合 + 同批预测 → 完美分离是过拟合假象。
- **影响**: 联合 AUC Gate（≥0.8）永远通过，无诊断意义。

### F-04 [P0] hub 空交集静默 fallback 到并集
- **证据**: 构造 Jaccard=0 输入 → 输出 6 基因并集作 "final_hub_genes.txt"，exit 0，"STAGE COMPLETE"。无 FAIL、无人工介入。
- **影响**: 双算法共识名存实亡。

### F-05 [P1] S05 bitr 硬报错（无映射降级）
- **证据**: 合成符号输入 → `Error in .testForValidKeys: None of the keys entered are valid keys for 'SYMBOL'`，脚本整体崩溃。真实基因则正常。
- **影响**: 用户基因列表若有错拼/物种不符，无法友好降级（应 WARN + 跳过不可映射基因 + 记录映射率）。

### F-06 [P1] S01 共享 PD.csv 被后运行数据集覆盖
- **证据**: 多数据集同目录处理时，后一个 S01 的 PD.csv 输出覆盖前一个（work 内 PD.csv 从 10 样本缩为 4 样本）。
- **影响**: 编排器多数据集场景 metadata 丢失。

### F-07 [P2] enrichplot 版本 API 断裂
- **证据**: `cnetplot failed: unused arguments (colorEdge = TRUE, circular = FALSE)` — enrichplot 新版本弃用这两参数。
- **影响**: S05 cnetplot 图缺失（其余富集正常）。

### F-08 [P2] 审计修正 — RF 假 p=0.02 路径范围收窄
- **证据**: 强制 `has_rfPermute=FALSE` 后，手动 100 次置换给出**真实经验 p 值**（0.0099~0.88），无伪造 0.02。伪造行只在"rfPermute 可用但其输出缺 .pval 列"窄路径触发（现代版本休眠，仍是地雷，需删）。

### F-09 [观察] DEG 找回率 88%
- S04 找回 44/50（88%）信号基因，满足基准 ≥90% 略差（toy n=10 小样本方差）；修复后复跑再验证（T019 阈值 90% 可能需按小样本调整）。

---

## 三、与 benchmark-spec 断言对照

| 断言 | 结果 |
|---|---|
| A1 分组文件缺失 fail-closed | ⚠️ **未验证充分**: S07 有 fallback 到样本名解析（会静默错标）；修复后才真正 fail-closed |
| 信号恢复 | LASSO 8/8、RF 1/1（通过） |
| 联合 OOF AUC ≥0.85 | ❌ 不可测（原版 in-sample AUC=1.0 无意义）；修复后测 |
| S05 GO/KEGG 非空 | ✅（真实基因）2502/171 |
| --dry-run 无输出 | 未测（Phase 6） |

---

## 四、结论

1. **原版 10 阶段在 toy-data 上"能跑通"但结论不可信**：ML 段在批次前缀下必崩（F-02），修复标签后 LASSO/RF 信号恢复良好，但 ROC 的 in-sample 假象（F-03）和 hub 并集 fallback（F-04) 会让最终 hub/ROC 结论失真。
2. **P1-SYS（F-01）是全链最广的工程 bug**：连字符 flag 全静默失效，orchestrator 的传参方式（只传 --output-dir + 各脚本默认值）实际上能跑通纯属侥幸（默认值恰好对上 toy 场景）。
3. **修复优先级实证确认**: P0 的 F-02/F-03/F-04 + P1 的 F-01 是必须修的；F-05/F-06 是真实场景也会踩的坑；F-07/F-08 是质量项。

## 五、产物

- 运行日志: `specs/007/baseline-run.log`
- 脚本: `baseline_full.ps1 / baseline_part3.ps1 / baseline_part4.ps1 / baseline_part5.ps1`
- toy 数据: `spec-mvp/tests/toydata/`（v2 交叉批次）
- 测试脚本: `test_rf_fallback.ps1/.R`, `test_hub_fallback.ps1`, `make_pd_merged.ps1`, `debug_labels.R`
