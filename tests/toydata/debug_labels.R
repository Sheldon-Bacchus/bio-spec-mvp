# debug_labels.R
WORK <- "E:/all-agent-workspace/codex-projects/bio-skills/bio-spec-kit/spec-mvp/tests/toydata/run_baseline"
pd <- read.csv(file.path(WORK, "PD_merged.csv"), stringsAsFactors = FALSE, check.names = FALSE)
cat("--- pd head ---\n")
print(head(pd))
cat("colnames:", paste(colnames(pd), collapse="|"), "\n")
cat("has sample:", "sample" %in% colnames(pd), " has group:", "group" %in% colnames(pd), "\n")
rt <- read.table(file.path(WORK, "merged_file.txt"), header = TRUE, sep = "\t", check.names = FALSE, row.names = 1)
rt <- t(rt)
cat("--- rownames ---\n")
print(rownames(rt))
label_map <- setNames(as.character(pd[["group"]]), as.character(pd[["sample"]]))
y_raw <- label_map[rownames(rt)]
cat("--- y_raw ---\n")
print(y_raw)
y_clean <- gsub("[0-9]+$", "", y_raw)
cat("--- y_clean table ---\n")
print(table(y_clean))