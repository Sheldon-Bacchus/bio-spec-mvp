# make_rf_nofallback.R - create RF script copy with rfPermute forced unavailable
src_file <- "E:/all-agent-workspace/codex-projects/bio-skills/bio-spec-kit/spec-mvp/skills/original-sop/bio-08-ml-randomforest/scripts/random_forest_importance.R"
dst_file <- "E:/all-agent-workspace/codex-projects/bio-skills/bio-spec-kit/spec-mvp/tests/toydata/run_baseline/random_forest_NOFALLBACK.R"
src <- readLines(src_file, warn = FALSE)
idx <- grep("has_rfPermute <-", src)
cat("line to replace:", idx, "\n")
src[idx] <- "has_rfPermute <- FALSE   # forced unavailable for baseline test"
writeLines(src, dst_file)
cat("written:", dst_file, "\n")