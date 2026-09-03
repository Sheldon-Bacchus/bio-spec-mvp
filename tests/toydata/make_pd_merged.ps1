$FIX = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata"
$WORK = "$FIX\run_baseline"
# 用 fixture 原始 PD.csv（10 样本），别用被 S01 覆盖的 work 内 PD.csv
$pd = Import-Csv "$FIX\PD.csv"
Write-Output "fixture PD rows: $($pd.Count)"
$rows = foreach ($r in $pd) {
  $prefix = if ($r.sample -match "_(1|2|3)$") { "GSEA" } else { "GSEB" }
  [PSCustomObject]@{ sample = ($prefix + "_" + $r.sample); group = $r.group }
}
$rows | Export-Csv "$WORK\PD_merged.csv" -NoTypeInformation -Encoding UTF8
Write-Output "--- PD_merged ---"
Get-Content "$WORK\PD_merged.csv"