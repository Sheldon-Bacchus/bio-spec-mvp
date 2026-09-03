#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_toydata.py v2 — crossed-batch fixture (fixes ComBat confounding).
Batch1 = GSEA: control_1..3 + treat_1..3 ; Batch2 = GSEB: control_4..5 + treat_4..5
Each dataset separately goes through S01 -> produces its own .normalize.txt,
then S02 merges both (batch = dataset), ComBat mod=group is NOT confounded.
Same stats: 200 genes (50 signal), 2% missing, log2, seed 12345.
"""
import os, random

random.seed(12345)
OUT = os.path.dirname(os.path.abspath(__file__))

SAMPLES = {
    "GSEA": ["control_1", "control_2", "control_3", "treat_1", "treat_2", "treat_3"],
    "GSEB": ["control_4", "control_5", "treat_4", "treat_5"],
}
ALL_SAMPLES = SAMPLES["GSEA"] + SAMPLES["GSEB"]
SIGNAL = ["g%03d" % i for i in range(1, 51)]
NOISE = ["g%03d" % i for i in range(51, 201)]
GENES = SIGNAL + NOISE
PROBES = ["p%03d" % i for i in range(1, 221)]
PROBE2GENE = dict((PROBES[i], GENES[i]) for i in range(200))
for p in PROBES[200:]:
    PROBE2GENE[p] = "---"

def rn():
    return random.gauss(0.0, 1.0)

# gene-level values per sample
gene_val = {}
for g in GENES:
    for s in ALL_SAMPLES:
        mu = 1.5 if (g in SIGNAL and s.startswith("treat")) else 0.0
        gene_val[(g, s)] = mu + 0.4 * rn()

# probe-level per dataset (values identical to gene-level; probe rows = PER DATASET sample set)
for ds in ("GSEA", "GSEB"):
    cols = SAMPLES[ds]
    cells = {}
    for p in PROBES:
        g = PROBE2GENE[p]
        cells[p] = [gene_val[(g, s)] if g != "---" else 0.4*rn() for s in cols]
    # 2% missing per dataset
    allcells = [(p, i) for p in PROBES for i in range(len(cols))]
    random.shuffle(allcells)
    for (p, ci) in allcells[:int(len(allcells)*0.02)]:
        cells[p][ci] = "NA"
    with open(os.path.join(OUT, ds + "_probe_exprs.txt"), "w") as fh:
        fh.write("ProbeID\t" + "\t".join(cols) + "\n")
        for p in PROBES:
            fh.write(p + "\t" + "\t".join(str(v) for v in cells[p]) + "\n")

# platform shared
with open(os.path.join(OUT, "GSETOY_platform.txt"), "w") as fh:
    fh.write("ID\tGene.Symbol\n")
    for p in PROBES:
        fh.write("%s\t%s\n" % (p, PROBE2GENE[p]))

# PD.csv
with open(os.path.join(OUT, "PD.csv"), "w") as fh:
    fh.write("sample,group\n")
    for s in ALL_SAMPLES:
        fh.write("%s,%s\n" % (s, "control" if s.startswith("control") else "treat"))

# PD_batch.csv (add batch col for pca_qc)
with open(os.path.join(OUT, "PD_batch.csv"), "w") as fh:
    fh.write("sample,group,batch\n")
    for ds, cols in SAMPLES.items():
        for s in cols:
            g = "control" if s.startswith("control") else "treat"
            fh.write("%s,%s,%s\n" % (s, g, ds))

# clinic.csv
with open(os.path.join(OUT, "clinic.csv"), "w") as fh:
    fh.write("sample,group,score\n")
    for s in ALL_SAMPLES:
        treat = s.startswith("treat")
        score = 2.5 + (1.5 if treat else 0.0) + 0.5 * rn()
        fh.write("%s,%s,%.4f\n" % (s, "treat" if treat else "control", score))

# s1/s2
with open(os.path.join(OUT, "s1.txt"), "w") as fh:
    fh.write("\n".join(s for s in ALL_SAMPLES if s.startswith("control")) + "\n")
with open(os.path.join(OUT, "s2.txt"), "w") as fh:
    fh.write("\n".join(s for s in ALL_SAMPLES if s.startswith("treat")) + "\n")

with open(os.path.join(OUT, "signal_genes.txt"), "w") as fh:
    fh.write("\n".join(SIGNAL) + "\n")

# gene-level matrix (post-S01 shape, all samples)
with open(os.path.join(OUT, "gene_exprs.tsv"), "w") as fh:
    fh.write("Symbol\t" + "\t".join(ALL_SAMPLES) + "\n")
    for g in GENES:
        fh.write(g + "\t" + "\t".join("%.4f" % gene_val[(g, s)] for s in ALL_SAMPLES) + "\n")

print("FIXTURE_V2_OK samples=%d (GSEA:6 GSEB:4) genes=%d" % (len(ALL_SAMPLES), len(GENES)))
