# baseline_part4.ps1 - S06 to S10
$ErrorActionPreference = "Continue"
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$R = "Rscript.exe"
$SOP = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_baseline"
$OUT = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\specs\007-original-sop-speckit"
$log = "$OUT\baseline-run.log"

function Invoke-R {
  param($id, $script, $argsStr)
  Write-Host ""
  Write-Host "===== $id ====="
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = (Get-Command $R).Source
  $psi.Arguments = "`"$script`" $argsStr"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.WorkingDirectory = $WORK
  $p = [System.Diagnostics.Process]::Start($psi)
  $o = $p.StandardOutput.ReadToEnd()
  $e = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  $exit = $p.ExitCode
  $tail = ($o + $e).Trim()
  if ($tail.Length -gt 3500) { $tail = $tail.Substring($tail.Length - 3500) }
  "[$id] exit=$exit" | Add-Content $log
  $tail -split "`r?`n" | Select-Object -Last 35 | ForEach-Object { "  | $_" } | Add-Content $log
  Write-Host "[$id] exit=$exit"
  return $exit
}

# S06 venn intersection (WGCNA module_genes.csv + limma diff.txt)
Invoke-R "S06-VENN" "$SOP\bio-06-gene-intersection\scripts\venn_intersection.R" "--wgcna=$WORK\module_genes.csv --deg=$WORK\diff.txt --output-dir=$WORK"

# S07-prep gene_expression_match (merge.normalize.txt + candidate_hub_genes.txt)
Invoke-R "S07-PREP" "$SOP\bio-07-ml-lasso\scripts\gene_expression_match.R" "--expr=$WORK\merge.normalize.txt --genes=$WORK\candidate_hub_genes.txt --output-dir=$WORK"

# S07 lasso
Invoke-R "S07-LASSO" "$SOP\bio-07-ml-lasso\scripts\lasso_regression.R" "--input=$WORK\merged_file.txt --group=$WORK\PD.csv --output-dir=$WORK"

# S08 rf
Invoke-R "S08-RF" "$SOP\bio-08-ml-randomforest\scripts\random_forest_importance.R" "--input=$WORK\merged_file.txt --group=$WORK\PD.csv --output-dir=$WORK"

# S09 hub intersection
Invoke-R "S09-HUB" "$SOP\bio-09-hub-literature\scripts\hub_gene_intersection.R" "--lasso=$WORK\LASSO.gene.txt --rf=$WORK\rf_genes.txt --output-dir=$WORK"

# S10 roc
Invoke-R "S10-ROC" "$SOP\bio-10-biomarker-roc\scripts\roc_validation.R" "--expr=$WORK\merged_file.txt --hub=$WORK\final_hub_genes.txt --group=$WORK\PD.csv --output-dir=$WORK"

"=== BASELINE_PASS4_END ===" | Add-Content $log
Write-Output "--- key outputs ---"
Get-ChildItem $WORK | Where-Object { $_.Name -match "LASSO|rf_|richness|final_hub|candidate|auc|roc|venn|merged" } | ForEach-Object { "{0}`t{1}" -f $_.Name, $_.Length }
Write-Host "DONE-PASS4"