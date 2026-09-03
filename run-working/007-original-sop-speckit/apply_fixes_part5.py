# -*- coding: utf-8 -*-
"""apply_fixes_part5.py — run_pipeline stage-1 I/O contract 修正"""
import io, os
SOP = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
report = []
def patch(path, subs):
    full = os.path.join(SOP, path)
    with io.open(full, "r", encoding="utf-8", errors="replace") as fh:
        txt = fh.read()
    n = 0
    for old, new in subs:
        c = txt.count(old)
        if c == 0:
            report.append("MISS %s :: %r" % (path, old[:80]))
            continue
        txt = txt.replace(old, new)
        n += c
    with io.open(full, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)
    report.append("OK   %s :: %d" % (path, n))

patch("bio-pipeline-orchestrator/scripts/run_pipeline.R", [
    (r'''      inputs = c(),
      outputs = c("expression_matrix.txt", "sample_group.csv"),''',
     r'''      inputs = c(),
      outputs = c("{gse_id}.normalize.txt", "PD.csv"),'''),
    (r'''      inputs = c("expression_matrix.txt"),
      outputs = c("merge.normalize.txt"),''',
     r'''      inputs = c("{gse_id}.normalize.txt"),
      outputs = c("merge.normalize.txt"),'''),
])
print("\n".join(report))
print("PART5_DONE")
