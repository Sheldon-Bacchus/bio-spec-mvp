# Contract Diff Report v2 (static, no R)

**Date**: 2026-09-03 | **Method**: regex file-name extraction (all 15 scripts) vs contracts.md SSOT, case-insensitive

## Summary

- total file-name references: 101
- canonical (or sprintf-pattern) matches: 97
- UNLISTED / suspicious: 4

## Per-script

### bio-01-geo-dataprep\scripts\geo_preprocess.R
- [CANON(sprintf): per-dataset normalized (sprintf %s.normalize.txt)] %s.normalize.txt
- [CANON: hardcoded default platform (review)] GPL84.txt
- [CANON: phenotype metadata (sample, group)] PD.csv
- [CANON: hardcoded default matrix (review)] biofilm.probeid.exprs.txt
- [CANON: legacy group file] group.txt

### bio-02-batch-norm\scripts\normalize.R
- [CANON(sprintf): per-dataset normalized (sprintf %s.normalize.txt)] %s.normalize.txt
- [CANON: hardcoded default matrix normalize.R (review)] biofilm.genesyb_mean.exprs.txt
- [CANON: control samples (legacy compat)] s1.txt
- [CANON: treat samples (legacy compat)] s2.txt

### bio-02-batch-norm\scripts\pca_qc.R
- [CANON: phenotype metadata (sample, group)] PD.csv
- [CANON: post-ComBat merged matrix] merge.normalize.txt
- [CANON: PCA QC] pca_qc.pdf

### bio-02-batch-norm\scripts\sva_combat.R
- [CANON: batch QC boxplot] boxplot_comparison.pdf
- [CANON: CSV twin of merged (legacy compat - confirm)] merge.normalize.csv
- [CANON: post-ComBat merged matrix] merge.normalize.txt
- [CANON: pre-ComBat merged matrix] merge.preNorm.txt

### bio-03-wgcna\scripts\wgcna_build.R
- [CANON: trait metadata] clinic.csv
- [CANON: post-ComBat merged matrix] merge.normalize.txt
- [CANON: WGCNA dendrogram] moduleDendrogram.pdf
- [CANON: module-trait heatmap] module_trait_heatmap.pdf
- [CANON: WGCNA soft threshold] softThreshold.pdf
- [CANON: WGCNA workspace] wgcna_net.RData

### bio-03-wgcna\scripts\wgcna_module_export.R
- [CANON(sprintf-ct): MM vs GS scatter (sprintf)] MM_vs_GS_%s.pdf
- [CANON: WGCNA gene list] candidate_hub_genes_wgcna.txt
- [CANON: gene-module info] geneInfo.csv
- [CANON: target module genes] module_genes.csv
- [CANON: WGCNA workspace] wgcna_net.RData

### bio-04-deg-limma\scripts\limma_diff.R
- [CANON: full limma table] all.txt
- [CANON: DEG gene list] candidate_hub_genes_deg.txt
- [CANON: significant DEGs] diff.txt
- [CANON: DEG expression] diffGeneExp.txt
- [CANON: DEG heatmap] heatmap.pdf
- [CANON: post-ComBat merged matrix] merge.normalize.txt
- [CANON: control samples (legacy compat)] s1.txt
- [CANON: treat samples (legacy compat)] s2.txt

### bio-04-deg-limma\scripts\volcano_heatmap.R
- [CANON: full limma table] all.txt
- [CANON: volcano] vol.pdf

### bio-05-enrichment\scripts\enrichment_analysis.R
- [CANON(sprintf-ct): GO per-ont barplot (sprintf)] GO_%s_barplot.pdf
- [CANON(sprintf-ct): GO per-ont dotplot (sprintf)] GO_%s_dotplot.pdf
- [CANON: GO enrichment] GO_enrichment.csv
- [CANON: KEGG barplot] KEGG_barplot.pdf
- [CANON: KEGG cnet] KEGG_cnetplot.pdf
- [CANON: KEGG dotplot] KEGG_dotplot.pdf
- [CANON: KEGG enrichment] KEGG_enrichment.csv
- [CANON: significant DEGs] diff.txt

### bio-06-gene-intersection\scripts\venn_intersection.R
- [CANON: S06 intersection] candidate_hub_genes.txt
- [CANON: significant DEGs] diff.txt
- [CANON: target module genes] module_genes.csv
- [CANON: Venn] venn_plot.pdf

### bio-07-ml-lasso\scripts\gene_expression_match.R
- [CANON: S06 intersection] candidate_hub_genes.txt
- [CANON: post-ComBat merged matrix] merge.normalize.txt
- [CANON: TYPO - must be removed] merge.normalzie.txt
- [CANON: S07 matched CSV] merged_data.csv
- [CANON: S07/08/10 matched expr] merged_file.txt
- [CANON: legacy alias (confirm)] molgene.csv

### bio-07-ml-lasso\scripts\lasso_regression.R
- [UNLISTED] , 
- [UNLISTED] , arg)) {
      params$input_file <- sub(
- [CANON: LASSO genes (lambda.min)] LASSO.gene.txt
- [CANON: LASSO CV] cvfit.pdf
- [CANON: LASSO path] lasso.pdf
- [CANON: LASSO coefs] lasso_coefficients.csv
- [CANON: S07/08/10 matched expr] merged_file.txt

### bio-08-ml-randomforest\scripts\random_forest_importance.R
- [UNLISTED] , 
- [UNLISTED] , arg)) {
      params$input_file <- sub(
- [CANON: S07/08/10 matched expr] merged_file.txt
- [CANON: RF significant] rf_genes.txt
- [CANON: RF plot] rf_importance.pdf
- [CANON: RF importance] richness.txt

### bio-09-hub-literature\scripts\hub_gene_intersection.R
- [CANON: LASSO genes (lambda.min)] LASSO.gene.txt
- [CANON: consensus hubs] final_hub_genes.txt
- [CANON: hub summary] hub_intersection_summary.txt
- [CANON: RF significant] rf_genes.txt

### bio-10-biomarker-roc\scripts\roc_validation.R
- [CANON: LASSO genes (lambda.min)] LASSO.gene.txt
- [CANON: AUC report] auc_report.csv
- [CANON: consensus hubs] final_hub_genes.txt
- [CANON: S07 matched CSV] merged_data.csv
- [CANON: S07/08/10 matched expr] merged_file.txt
- [CANON: combined ROC (OOF)] roc_combined.pdf
- [CANON: single ROC] roc_single_gene.pdf

### bio-pipeline-orchestrator\scripts\run_pipeline.R
- [CANON: LASSO genes (lambda.min)] LASSO.gene.txt
- [CANON: AUC report] auc_report.csv
- [CANON: S06 intersection] candidate_hub_genes.txt
- [CANON: trait metadata] clinic.csv
- [CANON: LASSO CV] cvfit.pdf
- [CANON: significant DEGs] diff.txt
- [CANON: GHOST (orchestrator stage1- nonexistent)] expression_matrix.txt
- [CANON: consensus hubs] final_hub_genes.txt
- [CANON: GO enrichment] go_enrichment.csv
- [CANON: LASSO path] lasso.pdf
- [CANON: post-ComBat merged matrix] merge.normalize.txt
- [CANON: TYPO - must be removed] merge.normalzie.txt
- [CANON: S07/08/10 matched expr] merged_file.txt
- [CANON: target module genes] module_genes.csv
- [CANON: gate report] pipeline_gate_report.csv
- [CANON: orchestrator log] pipeline_run.log
- [CANON: RF significant] rf_genes.txt
- [CANON: RF plot] rf_importance.pdf
- [CANON: RF importance] richness.txt
- [CANON: single ROC] roc_single_gene.pdf
- [CANON: GHOST (orchestrator stage1- nonexistent)] sample_group.csv
- [CANON: Venn] venn_plot.pdf

## UNLISTED only

- bio-07-ml-lasso\scripts\lasso_regression.R :: , 
- bio-07-ml-lasso\scripts\lasso_regression.R :: , arg)) {
      params$input_file <- sub(
- bio-08-ml-randomforest\scripts\random_forest_importance.R :: , 
- bio-08-ml-randomforest\scripts\random_forest_importance.R :: , arg)) {
      params$input_file <- sub(