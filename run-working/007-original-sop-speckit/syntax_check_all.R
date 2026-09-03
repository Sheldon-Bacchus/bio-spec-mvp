# syntax_check_all.R
base_dir <- "E:/all-agent-workspace/codex-projects/bio-skills/bio-spec-kit/spec-mvp/skills/original-sop"
files <- list.files(base_dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
failures <- 0
for (f in files) {
  res <- tryCatch({ invisible(parse(file = f)); "OK" }, error = function(e) paste("FAIL:", conditionMessage(e)))
  if (res != "OK") { failures <- failures + 1 }
  cat(sprintf("%-60s %s\n", sub(base_dir, ".", f, fixed = TRUE), res))
}
cat(sprintf("\nTOTAL=%d FAILURES=%d\n", length(files), failures))