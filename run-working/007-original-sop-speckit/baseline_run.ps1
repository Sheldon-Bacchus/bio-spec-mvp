# baseline_run.ps1 - Phase 2 baseline: run original scripts per stage, capture exit codes
$ErrorActionPreference = "Continue"
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$R = "Rscript.exe"
$SOP = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_baseline"
$OUT = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\specs\007-original-sop-speckit"
New-Item -ItemType Directory -Force -Path $WORK | Out-Null
$log = Join-Path $OUT "baseline-run.log"

function Run-Stage {
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
  if ($tail.Length -gt 2000) { $tail = $tail.Substring($tail.Length - 2000) }
  "[$id] exit=$exit" | Add-Content $log
  $tail -split "`r?`n" | Select-Object -Last 20 | ForEach-Object { "  | $_" } | Add-Content $log
  Write-Host "[$id] exit=$exit"
  return $exit
}

"=== BASELINE RUN $(Get-Date -Format s) ===" | Set-Content $log

# S01
Run-Stage "S01" "$SOP\bio-01-geo-dataprep\scripts\geo_preprocess.R" "--matrix=$WORK\GSETOY_probe_exprs.txt --platform=$WORK\GSETOY_platform.txt --gse-id=GSETOY --outdir=$WORK"

"=== BASELINE_PASS1_END ===" | Add-Content $log
Write-Host "DONE"