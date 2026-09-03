# -*- coding: utf-8 -*-
"""apply_fixes_part7.py — WGCNA 单线程化（规避 Windows socket 崩溃）"""
import io, os
SOP = r"E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
path = "bio-03-wgcna/scripts/wgcna_build.R"
full = os.path.join(SOP, path)
with io.open(full, "r", encoding="utf-8", errors="replace") as fh:
    txt = fh.read()

old = r'''tryCatch({
  enableWGCNAThreads()
}, error = function(e) {
  cat("[INFO] Multithreading not enabled, running single-threaded.\n")
})'''
new = r'''tryCatch({
  disableWGCNAThreads()
}, error = function(e) {
  cat("[INFO] WGCNA threads already disabled.\n")
})'''
c = txt.count(old)
print("wgcna_enable->disable count:", c)
if c > 0:
    txt = txt.replace(old, new)
    with io.open(full, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)

# 同时给 wgcna_module_export.R 也禁用（load RData 后可能触发）
path2 = "bio-03-wgcna/scripts/wgcna_module_export.R"
full2 = os.path.join(SOP, path2)
with io.open(full2, "r", encoding="utf-8", errors="replace") as fh:
    txt2 = fh.read()
if "disableWGCNAThreads" not in txt2:
    txt2 = txt2.replace(
        'set.seed(12345)',
        'set.seed(12345)\ntryCatch({ disableWGCNAThreads() }, error = function(e) NULL)',
        1
    )
    with io.open(full2, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt2)
    print("module_export: disableWGCNAThreads added")
else:
    print("module_export: already has it")
print("PART7_DONE")
