# baseline_full.ps1 - Phase 2 baseline S01-S10 (underscore-flag bypass for P1-SYS, documented)
$ErrorActionPreference = "Continue"
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$R = "Rscript.exe"
$SOP = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$FIX = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata"
$WORK = "$FIX\run_baseline"
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
  if ($tail.Length -gt 3000) { $tail = $tail.Substring($tail.Length - 3000) }
  "[$id] exit=$exit" | Add-Content $log
  $tail -split "`r?`n" | Select-Object -Last 30 | ForEach-Object { "  | $_" } | Add-Content $log
  Write-Host "[$id] exit=$exit"
  return $exit
}

"=== BASELINE RUN $(Get-Date -Format s) ===" | Set-Content $log

# clean work dir
if (Test-Path $WORK) { Remove-Item $WORK -Recurse -Force }
New-Item -ItemType Directory -Force -Path $WORK | Out-Null
Copy-Item "$FIX\GSEA_probe_exprs.txt" $WORK
Copy-Item "$FIX\GSEB_probe_exprs.txt" $WORK
Copy-Item "$FIX\GSETOY_platform.txt" $WORK
Copy-Item "$FIX\PD.csv" $WORK
Copy-Item "$FIX\PD_batch.csv" $WORK
Copy-Item "$FIX\clinic.csv" $WORK
Copy-Item "$FIX\s1.txt" $WORK
Copy-Item "$FIX\s2.txt" $WORK
Copy-Item "$FIX\signal_genes.txt" $WORK

# S01 on GSEA and GSEB (underscore flag --gse_id)
Invoke-R "S01-GSEA" "$SOP\bio-01-geo-dataprep\scripts\geo_preprocess.R" "--matrix=$WORK\GSEA_probe_exprs.txt --platform=$WORK\GSETOY_platform.txt --gse_id=GSEA --outdir=$WORK"
Invoke-R "S01-GSEB" "$SOP\bio-01-geo-dataprep\scripts\geo_preprocess.R" "--matrix=$WORK\GSEB_probe_exprs.txt --platform=$WORK\GSETOY_platform.txt --gse_id=GSEB --outdir=$WORK"

# S02 ComBat (underscore --input_files)
Invoke-R "S02" "$SOP\bio-02-batch-norm\scripts\sva_combat.R" "--input_files=$WORK\GSEA.normalize.txt,$WORK\GSEB.normalize.txt --pd=$WORK\PD.csv --outdir=$WORK"

# S02b PCA QC
Invoke-R "S02b-PCA" "$SOP\bio-02-batch-norm\scripts\pca_qc.R" "--input=$WORK\merge.normalize.txt --pd=$WORK\PD_batch.csv --outdir=$WORK"

"=== BASELINE_PASS2_END ===" | Add-Content $log
Write-Host "DONE-PASS2"