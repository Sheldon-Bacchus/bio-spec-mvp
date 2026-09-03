$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$base = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_baseline"

Write-Output "=== TEST 1: hyphen flag --gse-id now works ==="
$out1 = & Rscript.exe "$base\bio-01-geo-dataprep\scripts\geo_preprocess.R" "--matrix=$WORK\GSETOY_probe_exprs.txt" "--platform=$WORK\GSETOY_platform.txt" "--gse-id=GSETOY2" "--outdir=$WORK" 2>&1
$out1 | Select-String -Pattern "Starting GEO Preprocessing for|GSETOY2.normalize" | Select-Object -First 3
Write-Output "GSEID_EXIT=$LASTEXITCODE"
Write-Output "--- GSETOY2.normalize.txt exists? ---"
Test-Path "$WORK\GSETOY2.normalize.txt"

Write-Output "=== TEST 2: LASSO without --group fails closed ==="
$out2 = & Rscript.exe "$base\bio-07-ml-lasso\scripts\lasso_regression.R" "--input=$WORK\merged_file.txt" "--output-dir=$WORK" 2>&1
$out2 | Select-String -Pattern "GATE ERROR|REQUIRED|required" | Select-Object -First 3
Write-Output "LASSO_NOGROUP_EXIT=$LASTEXITCODE"

Write-Output "=== TEST 3: hub empty intersection fails closed ==="
"geneA1`ngeneA2" | Set-Content "$WORK\lasso_empty2.txt" -Encoding UTF8
"geneB1`ngeneB2" | Set-Content "$WORK\rf_empty2.txt" -Encoding UTF8
$out3 = & Rscript.exe "$base\bio-09-hub-literature\scripts\hub_gene_intersection.R" "--lasso=$WORK\lasso_empty2.txt" "--rf=$WORK\rf_empty2.txt" "--output-dir=$WORK\hub_fail_test" 2>&1
$out3 | Select-String -Pattern "GATE ERROR|EMPTY|Refusing" | Select-Object -First 3
Write-Output "HUB_EMPTY_EXIT=$LASTEXITCODE"