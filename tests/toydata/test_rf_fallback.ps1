$SOP = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_baseline"
$src = Get-Content "$SOP\bio-08-ml-randomforest\scripts\random_forest_importance.R" -Raw
# 强制 has_rfPermute = FALSE（模拟 rfPermute 不可用）
$src = $src -replace "has_rfPermute <- suppressWarnings\(requireNamespace\("rfPermute", quietly = TRUE\)\)", "has_rfPermute <- FALSE"
# 同时把 p_value 伪造行后面加打印标记，便于确认走了哪条路
$src | Set-Content "$WORK\random_forest_importance_NOFALLBACK.R" -Encoding UTF8
Write-Output "--- modified script head (has_rfPermute area) ---"
Select-String -Path "$WORK\random_forest_importance_NOFALLBACK.R" -Pattern "has_rfPermute" | ForEach-Object { $_.Line.Trim() }
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
Write-Output "=== run forced-fallback RF ==="
& Rscript.exe "$WORK\random_forest_importance_NOFALLBACK.R" "--input=$WORK\merged_file.txt" "--group=$WORK\PD_merged.csv" "--output-dir=$WORK" 2>&1 | Select-Object -Last 25
Write-Output "RF_FALLBACK_EXIT=$LASTEXITCODE"
Write-Output "--- richness fallback p-values check (any 0.02?) ---"
if (Test-Path "$WORK\richness.txt") {
  $bad = Select-String -Path "$WORK\richness.txt" -Pattern "0\t0\.02|0\.02$" | Select-Object -First 5
  $bad
  "count of p=0.02 rows: $((Select-String -Path $WORK\richness.txt -Pattern "0\.02").Count)"
}