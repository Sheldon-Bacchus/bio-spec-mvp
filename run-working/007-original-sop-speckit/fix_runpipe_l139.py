# -*- coding: utf-8 -*-
import io, os
path = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop\bio-pipeline-orchestrator\scripts\run_pipeline.R"
with io.open(path, "r", encoding="utf-8", errors="replace") as fh:
    lines = fh.readlines()
target = "has_expr <- any(grepl("
newline = '        has_expr <- any(grepl("[.]normalize[.]txt$", list.files(work_dir)))\n'
changed = 0
for i, ln in enumerate(lines):
    if target in ln and "normalize" in ln and "list.files" in ln:
        print("OLD:", repr(ln))
        lines[i] = newline
        changed += 1
print("changed lines:", changed)
with io.open(path, "w", encoding="utf-8", newline="") as fh:
    fh.writelines(lines)
print("DONE")
