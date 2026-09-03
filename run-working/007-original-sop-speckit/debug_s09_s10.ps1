$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$base = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_fixed"

Write-Output "=== S09 rerun ==="
& Rscript.exe "$base\bio-09-hub-literature\scripts\hub_gene_intersection.R" "--lasso=$WORK\LASSO.gene.txt" "--rf=$WORK\rf_genes.txt" "--output-dir=$WORK" 2>&1 | Select-Object -Last 20
Write-Output "S09_EXIT=$LASTEXITCODE"

Write-Output "=== LASSO.gene vs rf_genes ==="
Write-Output "LASSO: $((Get-Content $WORK\LASSO.gene.txt) -join ", ")"
Write-Output "RF: $((Get-Content $WORK\rf_genes.txt) -join ", ")"

Write-Output "=== S10 rerun (OOF log check) ==="
& Rscript.exe "$base\bio-10-biomarker-roc\scripts\roc_validation.R" "--expr=$WORK\merged_file.txt" "--hub=$WORK\final_hub_genes.txt" "--group=$WORK\PD_merged.csv" "--output-dir=$WORK" 2>&1 | Select-String -Pattern "OUT-OF-FOLD|Building multivariable|AUC" | Select-Object -First 8
Write-Output "S10_EXIT=$LASTEXITCODE"