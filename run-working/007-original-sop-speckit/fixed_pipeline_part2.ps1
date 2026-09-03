# fixed_part2.ps1 — 修复版续跑 S03→S10
$ErrorActionPreference = "Continue"
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$R = "Rscript.exe"
$SOP = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_fixed"
$OUT = "E:\all-agent-workspace\codex-projects\bio-skills\specs-007-fixed"

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
  "[$id] exit=$exit" | Add-Content "$OUT\fixed-run2.log"
  Write-Host "[$id] exit=$exit"
  return $exit
}

Invoke-R "S03" "$SOP\bio-03-wgcna\scripts\wgcna_build.R" "--input=$WORK\merge.normalize.txt --clinic=$WORK\clinic.csv --outdir=$WORK"
Invoke-R "S03b" "$SOP\bio-03-wgcna\scripts\wgcna_module_export.R" "--rdata=$WORK\wgcna_net.RData --trait=score --outdir=$WORK"
Invoke-R "S04" "$SOP\bio-04-deg-limma\scripts\limma_diff.R" "--input=$WORK\merge.normalize.txt --pd=$WORK\PD.csv --outdir=$WORK"
Invoke-R "S04b" "$SOP\bio-04-deg-limma\scripts\volcano_heatmap.R" "--input=$WORK\all.txt --outdir=$WORK"
Invoke-R "S06" "$SOP\bio-06-gene-intersection\scripts\venn_intersection.R" "--wgcna=$WORK\module_genes.csv --deg=$WORK\diff.txt --output-dir=$WORK"
Invoke-R "S07-PREP" "$SOP\bio-07-ml-lasso\scripts\gene_expression_match.R" "--expr=$WORK\merge.normalize.txt --genes=$WORK\candidate_hub_genes.txt --output-dir=$WORK"
Invoke-R "S07" "$SOP\bio-07-ml-lasso\scripts\lasso_regression.R" "--input=$WORK\merged_file.txt --group=$WORK\PD_merged.csv --output-dir=$WORK"
Invoke-R "S08" "$SOP\bio-08-ml-randomforest\scripts\random_forest_importance.R" "--input=$WORK\merged_file.txt --group=$WORK\PD_merged.csv --output-dir=$WORK"
Invoke-R "S09" "$SOP\bio-09-hub-literature\scripts\hub_gene_intersection.R" "--lasso=$WORK\LASSO.gene.txt --rf=$WORK\rf_genes.txt --output-dir=$WORK"
Invoke-R "S10" "$SOP\bio-10-biomarker-roc\scripts\roc_validation.R" "--expr=$WORK\merged_file.txt --hub=$WORK\final_hub_genes.txt --group=$WORK\PD_merged.csv --output-dir=$WORK"

Write-Output "=== key outputs ==="
Get-ChildItem $WORK | Where-Object { $_.Name -match "LASSO|rf_|richness|final_hub|auc|roc_|venn|candidate" } | ForEach-Object { "{0}`t{1}" -f $_.Name, $_.Length }
Write-Output "=== AUC report ==="
if (Test-Path "$WORK\auc_report.csv") { Get-Content "$WORK\auc_report.csv" }
Write-Output "DONE-FIXED-2"