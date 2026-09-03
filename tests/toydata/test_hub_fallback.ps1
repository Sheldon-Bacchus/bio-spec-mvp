# test hub empty-intersection fallback: write non-overlapping LASSO/RF lists
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_baseline"
"geneA1`ngeneA2`ngeneA3" | Set-Content "$WORK\lasso_empty_test.txt" -Encoding UTF8
"geneB1`ngeneB2`ngeneB3" | Set-Content "$WORK\rf_empty_test.txt" -Encoding UTF8
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
Write-Output "=== hub with empty intersection ==="
& Rscript.exe "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop\bio-09-hub-literature\scripts\hub_gene_intersection.R" "--lasso=$WORK\lasso_empty_test.txt" "--rf=$WORK\rf_empty_test.txt" "--output-dir=$WORK\hub_fallback_test" 2>&1 | Select-Object -Last 30
Write-Output "HUB_EMPTY_EXIT=$LASTEXITCODE"
Write-Output "--- final_hub_genes.txt (should be union if fallback fired) ---"
if (Test-Path "$WORK\hub_fallback_test\final_hub_genes.txt") { Get-Content "$WORK\hub_fallback_test\final_hub_genes.txt" } else { "no output" }