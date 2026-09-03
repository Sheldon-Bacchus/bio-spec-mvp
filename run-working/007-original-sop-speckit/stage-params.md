# Stage → CLI 参数映射表 (T012 prep)

**Date**: 2026-09-03 | **用途**: run_pipeline.R 重写时按此表传参（当前只传 --output-dir，导致默认值错乱）
**依据**: 各脚本 parse_args/defaults + contracts.md SSOT

| Stage | 脚本 | 现有参数（defaults） | 契约要求（修复后传参） |
|---|---|---|---|
| S01 | geo_preprocess.R | `--matrix`, `--platform`, `--probe-col`, `--symbol-col`, `--gse-id`, `--outdir`, `--k/--rowmax/--colmax`, `--sample-con/--sample-treat` | `--matrix={gse}_probe_exprs.txt --platform={gse}_platform.txt --gse-id=GSETOY --outdir=...`；**分组必传** `--sample-con/--sample-treat` 或接受 PD.csv（新增） |
| S02 | sva_combat.R | `--indir`, `--pattern`, `--input-files`, `--pd`, `--outdir`, `--out-prenorm/--out-norm/--out-boxplot` | `--input-files=GSE1.normalize.txt,GSE2.normalize.txt --pd=PD.csv --outdir=...`（fix: 应显式 list，不用 pattern 猜测） |
| S02b | pca_qc.R | `--input`, `--pd`, `--group-col/--batch-col`, `--outdir`, `--output` | `--input=merge.normalize.txt --pd=PD.csv`（PD 需含 batch 列，扩展） |
| S03 | wgcna_build.R | `--input`, `--clinic`, `--n-genes`, `--r2-cutoff`, `--max-block-size`, `--min-module-size`, `--merge-cut-height`, `--outdir` | `--input=merge.normalize.txt --clinic=clinic.csv` + 新增 `--tom-type`（P2） |
| S03b | wgcna_module_export.R | `--rdata`, `--module`, `--trait`, `--mm-cutoff`, `--gs-cutoff`, `--outdir` | `--rdata=wgcna_net.RData --trait=score`（trait 必须显式） |
| S04 | limma_diff.R | `--input`, `--pd`, `--s1/--s2`, `--logfc`, `--fdr`, `--top-heatmap`, `--outdir` | `--input=merge.normalize.txt --pd=PD.csv`（PD.csv 优先；s1/s2 兼容） |
| S04b | volcano_heatmap.R | `--input`, `--logfc`, `--fdr`, `--top-n`, `--outdir`, `--output` | `--input=all.txt` |
| S05 | enrichment_analysis.R | `--input`, `--species`, `--org-db`, `--p-cutoff`, `--q-cutoff`, `--show-category`, `--outdir` | `--input=diff.txt --species=human`（pae → GO 报错路径验证） |
| S06 | venn_intersection.R | `--wgcna`, `--deg`, `--output-dir`, `--output-genes`, `--output-plot`, `--wgcna-col/--deg-col` | `--wgcna=module_genes.csv --deg=diff.txt` |
| S07-pre | gene_expression_match.R | `--expr`, `--genes`, `--output-dir`, `--out-txt/--out-csv`, `--gene-col` | `--expr=merge.normalize.txt --genes=candidate_hub_genes.txt`（fix typo fallback） |
| S07 | lasso_regression.R | `--input`, `--group`, `--output-dir`, `--output-genes`, `--nfolds` | `--input=merged_file.txt --group=PD.csv`（**group 必传**，fail-closed） |
| S08 | random_forest_importance.R | `--input`, `--group`, `--output-dir`, `--output-richness/--output-genes/--output-plot`, `--ntree/--nrep/--cores/--p-cutoff` | `--input=merged_file.txt --group=PD.csv`（group 必传；nrep=299 对齐 SKILL.md） |
| S09 | hub_gene_intersection.R | `--lasso`, `--rf`, `--output-dir`, `--output-hub` | `--lasso=LASSO.gene.txt --rf=rf_genes.txt` |
| S10 | roc_validation.R | `--expr`, `--hub`, `--group`, `--output-dir`, `--single-pdf/--combined-pdf/--report` | `--expr=merged_file.txt --hub=final_hub_genes.txt --group=PD.csv`（group 必传） |
| ORCH | run_pipeline.R | `--project-dir`, `--skills-dir`, `--start-stage/--end-stage`, `--dry-run`, `--force`, `--log/--report` | 每 stage 按上表传参；新增 `pipeline_run_report.json` 收集 |

## 修复后编排器调用形状（草案）

```text
Rscript geo_preprocess.R --matrix=GSETOY_probe_exprs.txt --platform=GSETOY_platform.txt --gse-id=GSETOY --outdir=<work> --sample-con=... --sample-treat=...
Rscript sva_combat.R --input-files=<list> --pd=PD.csv --outdir=<work>
Rscript pca_qc.R --input=merge.normalize.txt --pd=PD.csv --outdir=<work>
Rscript wgcna_build.R --input=merge.normalize.txt --clinic=clinic.csv --outdir=<work>
Rscript wgcna_module_export.R --rdata=wgcna_net.RData --trait=score --outdir=<work>
Rscript limma_diff.R --input=merge.normalize.txt --pd=PD.csv --outdir=<work>
Rscript volcano_heatmap.R --input=all.txt --outdir=<work>
Rscript enrichment_analysis.R --input=diff.txt --species=human --outdir=<work>   # pae 验证报错路径
Rscript venn_intersection.R --wgcna=module_genes.csv --deg=diff.txt --outdir=<work>
Rscript gene_expression_match.R --expr=merge.normalize.txt --genes=candidate_hub_genes.txt --outdir=<work>
Rscript lasso_regression.R --input=merged_file.txt --group=PD.csv --outdir=<work>
Rscript random_forest_importance.R --input=merged_file.txt --group=PD.csv --outdir=<work>
Rscript hub_gene_intersection.R --lasso=LASSO.gene.txt --rf=rf_genes.txt --outdir=<work>
Rscript roc_validation.R --expr=merged_file.txt --hub=final_hub_genes.txt --group=PD.csv --outdir=<work>
```

## 分组 fail-closed 设计（G-03）

- S01/S04/S07/S08/S10 的 `--group-file`（或 --pd/--group）**: 必传**；缺失 → 报错退出。
- S01 的 `--sample-con/--sample-treat` 若传入 → 生成 PD.csv；否则要求已有 PD.csv。
- 推断路径（名称 regex / half-split）**删除**；如确需推断 → `inferred_groups.csv` + WARN + 继续（仅 S01 允许，且 gate 检查该文件必存在）。
