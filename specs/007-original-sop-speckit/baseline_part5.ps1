# baseline_part5.ps1 - S07-S10 rerun with PD_merged.csv (prefixed names)
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

# S07 lasso with PD_merged
Invoke-R "S07-LASSOv2" "$SOP\bio-07-ml-lasso\scripts\lasso_regression.R" "--input=$WORK\merged_file.txt --group=$WORK\PD_merged.csv --output-dir=$WORK"

# S08 rf with PD_merged
Invoke-R "S08-RFv2" "$SOP\bio-08-ml-randomforest\scripts\random_forest_importance.R" "--input=$WORK\merged_file.txt --group=$WORK\PD_merged.csv --output-dir=$WORK"

# S09 hub
Invoke-R "S09-HUBv2" "$SOP\bio-09-hub-literature\scripts\hub_gene_intersection.R" "--lasso=$WORK\LASSO.gene.txt --rf=$WORK\rf_genes.txt --output-dir=$WORK"

# S10 roc
Invoke-R "S10-ROCv2" "$SOP\bio-10-biomarker-roc\scripts\roc_validation.R" "--expr=$WORK\merged_file.txt --hub=$WORK\final_hub_genes.txt --group=$WORK\PD_merged.csv --output-dir=$WORK"

"=== BASELINE_PASS5_END ===" | Add-Content $log
Write-Output "--- key ML outputs ---"
Get-ChildItem $WORK | Where-Object { $_.Name -match "LASSO.gene|rf_genes|richness|final_hub|auc_report|roc_" } | ForEach-Object { "{0}`t{1}" -f $_.Name, $_.Length }
Write-Host "DONE-PASS5"