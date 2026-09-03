#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
contract-diff.py — Static contract audit v2 (case-insensitive canonical match)
Extract file names from original-sop R scripts and compare vs contracts.md SSOT.
"""
import os, re

SOP = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
OUT = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\specs\007-original-sop-speckit"

# canonical filenames (SSOT from contracts.md); keys lowercase for ci-match
CANON = {
    "gs.normalize.txt": "per-dataset normalized (sprintf %s.normalize.txt)",
    "pd.csv": "phenotype metadata (sample, group)",
    "group.txt": "legacy group file",
    "merge.prenorm.txt": "pre-ComBat merged matrix",
    "merge.normalize.txt": "post-ComBat merged matrix",
    "merge.normalize.csv": "CSV twin of merged (legacy compat - confirm)",
    "boxplot_comparison.pdf": "batch QC boxplot",
    "pca_qc.pdf": "PCA QC",
    "clinic.csv": "trait metadata",
    "softthreshold.pdf": "WGCNA soft threshold",
    "moduledendrogram.pdf": "WGCNA dendrogram",
    "module_trait_heatmap.pdf": "module-trait heatmap",
    "geneinfo.csv": "gene-module info",
    "module_genes.csv": "target module genes",
    "candidate_hub_genes_wgcna.txt": "WGCNA gene list",
    "wgcna_net.rdata": "WGCNA workspace",
    "all.txt": "full limma table",
    "diff.txt": "significant DEGs",
    "diffgeneexp.txt": "DEG expression",
    "heatmap.pdf": "DEG heatmap",
    "vol.pdf": "volcano",
    "candidate_hub_genes_deg.txt": "DEG gene list",
    "go_enrichment.csv": "GO enrichment",
    "kegg_enrichment.csv": "KEGG enrichment",
    "candidate_hub_genes.txt": "S06 intersection",
    "venn_plot.pdf": "Venn",
    "merged_file.txt": "S07/08/10 matched expr",
    "merged_data.csv": "S07 matched CSV",
    "lasso.gene.txt": "LASSO genes (lambda.min)",
    "lasso.gene.1se.txt": "LASSO genes (lambda.1se)",
    "lasso_coefficients.csv": "LASSO coefs",
    "lasso.pdf": "LASSO path",
    "cvfit.pdf": "LASSO CV",
    "richness.txt": "RF importance",
    "rf_genes.txt": "RF significant",
    "rf_importance.pdf": "RF plot",
    "final_hub_genes.txt": "consensus hubs",
    "hub_intersection_summary.txt": "hub summary",
    "literature_evidence_report.md": "literature report",
    "roc_single_gene.pdf": "single ROC",
    "roc_combined.pdf": "combined ROC (OOF)",
    "auc_report.csv": "AUC report",
    "pipeline_run.log": "orchestrator log",
    "pipeline_gate_report.csv": "gate report",
    "pipeline_run_report.json": "sci metrics",
    "inferred_groups.csv": "inference audit",
    "go_barplot.pdf": "GO per-ont barplot (sprintf)",
    "go_dotplot.pdf": "GO per-ont dotplot (sprintf)",
    "kegg_barplot.pdf": "KEGG barplot",
    "kegg_dotplot.pdf": "KEGG dotplot",
    "kegg_cnetplot.pdf": "KEGG cnet",
    "mm_vs_gs_.pdf": "MM vs GS scatter (sprintf)",
    "merged.pdf": "sprintf merged",
    "expression_matrix.txt": "GHOST (orchestrator stage1- nonexistent)",
    "sample_group.csv": "GHOST (orchestrator stage1- nonexistent)",
    "molgene.csv": "legacy alias (confirm)",
    "s1.txt": "control samples (legacy compat)",
    "s2.txt": "treat samples (legacy compat)",
    "merge.normalzie.txt": "TYPO - must be removed",
    "gpl84.txt": "hardcoded default platform (review)",
    "biofilm.probeid.exprs.txt": "hardcoded default matrix (review)",
    "biofilm.genesyb_mean.exprs.txt": "hardcoded default matrix normalize.R (review)",
}

FILE_RE = re.compile(r'["\']([A-Za-z0-9_.\-]+\.(txt|csv|pdf|rdata|RData|json|md|log))["\']')
ASSN_RE = re.compile(r'\b(output|input|out_\w+|file|params\$[a-z_]+)\s*=\s*["\']([^"\']+)["\']')

def walk():
    for root, dirs, files in os.walk(SOP):
        for f in files:
            if f.endswith(".R"):
                yield os.path.join(root, f)

rows = []
for fpath in walk():
    rel = os.path.relpath(fpath, SOP)
    with open(fpath, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    fnames = set()
    for m in FILE_RE.finditer(src):
        fnames.add(m.group(1))
    for m in ASSN_RE.finditer(src):
        fnames.add(m.group(2))
    for m in re.finditer(r'sprintf\(["\']([^"\']*\.(?:txt|csv|pdf|rdata))["\']', src):
        fnames.add(m.group(1))
    for fn in sorted(fnames):
        fnl = fn.lower().strip()
        if fnl in CANON:
            status = "CANON: " + CANON[fnl]
        elif fnl.endswith(".normalize.txt"):
            status = "CANON(sprintf): " + CANON["gs.normalize.txt"]
        elif fnl.startswith("go_") and fnl.endswith("_barplot.pdf"):
            status = "CANON(sprintf-ct): " + CANON["go_barplot.pdf"]
        elif fnl.startswith("go_") and fnl.endswith("_dotplot.pdf"):
            status = "CANON(sprintf-ct): " + CANON["go_dotplot.pdf"]
        elif fnl.startswith("mm_vs_gs_") and fnl.endswith(".pdf"):
            status = "CANON(sprintf-ct): " + CANON["mm_vs_gs_.pdf"]
        else:
            status = "UNLISTED"
        rows.append((rel, fn, status))

byfile = {}
for rel, fn, st in rows:
    byfile.setdefault(rel, []).append((fn, st))

lines = ["# Contract Diff Report v2 (static, no R)", "",
         "**Date**: 2026-09-03 | **Method**: regex file-name extraction (all 15 scripts) vs contracts.md SSOT, case-insensitive",
         "", "## Summary", ""]
unlisted = [r for r in rows if r[2] == "UNLISTED"]
lines.append("- total file-name references: %d" % len(rows))
lines.append("- canonical (or sprintf-pattern) matches: %d" % (len(rows) - len(unlisted)))
lines.append("- UNLISTED / suspicious: %d" % len(unlisted))
lines.append("")
lines.append("## Per-script")
lines.append("")
for rel in sorted(byfile):
    lines.append("### %s" % rel)
    for fn, st in byfile[rel]:
        lines.append("- [%s] %s" % (st, fn))
    lines.append("")
lines.append("## UNLISTED only")
lines.append("")
for rel, fn, st in sorted(unlisted):
    lines.append("- %s :: %s" % (rel, fn))

report = "\n".join(lines)
with open(os.path.join(OUT, "contract-diff-report.md"), "w", encoding="utf-8") as fh:
    fh.write(report)
print(report)
