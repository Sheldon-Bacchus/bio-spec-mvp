$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_fixed"
Copy-Item "$WORK\LASSO.gene.txt" "$WORK\final_hub_genes.txt" -Force
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
Write-Output "=== S10 with reviewed hub set ==="
& Rscript.exe "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop\bio-10-biomarker-roc\scripts\roc_validation.R" "--expr=$WORK\merged_file.txt" "--hub=$WORK\final_hub_genes.txt" "--group=$WORK\PD_merged.csv" "--output-dir=$WORK" 2>&1 | Select-String -Pattern "OUT-OF-FOLD|multivariable|AUC|ERROR|SUCCESS" | Select-Object -First 10
Write-Output "S10_EXIT=$LASTEXITCODE"
Write-Output "=== AUC report ==="
Get-Content "$WORK\auc_report.csv"