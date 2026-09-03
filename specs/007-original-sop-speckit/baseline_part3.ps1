# baseline_full.ps1 PART3 - S03 WGCNA, S04 limma, S05 enrichment
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

# S03 WGCNA build
Invoke-R "S03-WGCNA" "$SOP\bio-03-wgcna\scripts\wgcna_build.R" "--input=$WORK\merge.normalize.txt --clinic=$WORK\clinic.csv --outdir=$WORK"
# S03b module export (trait=score)
Invoke-R "S03b-EXPORT" "$SOP\bio-03-wgcna\scripts\wgcna_module_export.R" "--rdata=$WORK\wgcna_net.RData --trait=score --outdir=$WORK"
# S04 limma DEG
Invoke-R "S04-LIMMA" "$SOP\bio-04-deg-limma\scripts\limma_diff.R" "--input=$WORK\merge.normalize.txt --pd=$WORK\PD.csv --outdir=$WORK"
# S04b volcano
Invoke-R "S04b-VOL" "$SOP\bio-04-deg-limma\scripts\volcano_heatmap.R" "--input=$WORK\all.txt --outdir=$WORK"
# S05 enrichment (human)
Invoke-R "S05-ENR" "$SOP\bio-05-enrichment\scripts\enrichment_analysis.R" "--input=$WORK\diff.txt --species=human --outdir=$WORK"

"=== BASELINE_PASS3_END ===" | Add-Content $log
Write-Output "--- work files ---"
Get-ChildItem $WORK | ForEach-Object { "{0}`t{1}" -f $_.Name, $_.Length }
Write-Host "DONE-PASS3"