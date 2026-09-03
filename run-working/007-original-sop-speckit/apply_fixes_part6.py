# -*- coding: utf-8 -*-
"""apply_fixes_part6.py — run_pipeline gate regex 转义修正"""
import io, os
SOP = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
path = "bio-pipeline-orchestrator/scripts/run_pipeline.R"
full = os.path.join(SOP, path)
with io.open(full, "r", encoding="utf-8", errors="replace") as fh:
    txt = fh.read()

old = r'has_expr <- any(grepl("\\.normalize\\.txt$", list.files(work_dir)))'
new = r'has_expr <- any(grepl("[.]normalize[.]txt$", list.files(work_dir)))'
c = txt.count(old)
print("count:", c)
if c > 0:
    txt = txt.replace(old, new)
    with io.open(full, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)

# 验证修复
with io.open(full, "r", encoding="utf-8") as fh:
    t2 = fh.read()
print("fixed present:", "[.]normalize[.]txt$" in t2)
print("PART6_DONE")
