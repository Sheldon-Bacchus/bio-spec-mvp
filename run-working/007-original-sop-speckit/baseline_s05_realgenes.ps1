# baseline_s05_realgenes.ps1 - S05 with REAL human gene symbols (240 real genes)
$ErrorActionPreference = "Continue"
$env:Path = "C:\Program Files\R\R-4.6.1\bin\x64;" + $env:Path
$R = "Rscript.exe"
$SOP = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\skills\original-sop"
$WORK = "E:\all-agent-workspace\codex-projects\bio-skills\bio-spec-kit\spec-mvp\tests\toydata\run_baseline"

# 生成真实基因符号的 diff.txt（模拟 DEG：选 200 个真实基因，50 个为"信号"）
$realGenes = @("TP53","EGFR","AKT1","MTOR","PIK3CA","PTEN","KRAS","BRAF","MYC","CCND1","CDK4","CDKN2A","RB1","MDM2","MDM4","ATM","ATR","CHEK1","CHEK2","BRCA1","BRCA2","ERBB2","ERBB3","MET","VEGFA","VEGFB","FLT1","KDR","PDGFRA","PDGFRB","FGFR1","FGFR2","FGFR3","IGF1","IGF1R","INSR","JAK1","JAK2","JAK3","STAT3","STAT5A","STAT5B","SRC","ABL1","BCR","RAF1","MAP2K1","MAP2K2","MAPK1","MAPK3","MAPK14","GSK3B","WNT1","CTNNB1","APC","AXIN1","DVL1","LRP6","NOTCH1","NOTCH2","HES1","DLL1","JAG1","SMO","GLI1","GLI2","PTCH1","SHH","TP73","TGFB1","SMAD2","SMAD3","SMAD4","TNF","IL6","IL1B","CXCL8","CCL2","IFNG","IL10","IL4","IL13","CSF2","CSF1","TNFSF11","TNFRSF11A","TNFRSF11B","BMP2","BMP4","RUNX2","SP7","COL1A1","VDR","CYP27B1","FGF23","PHEX","DMP1","SOST","LRP5","LRP4","DKK1","RANKL","TRAP","ACP5","CTSK","CA2","CAR2","MMP9","MMP2","TIMP1","TIMP2","SERPINE1","PLAU","PLAT","F2","F10","F7","F5","PROC","PROS1","THBD","PLG","HGF","HGFR","MET","CXCR4","SDF1","CCL21","CCR7","MMP13","COL10A1","SOX9","ACAN","COMP","MATN3","COL2A1","COL9A1","COL11A1","BGN","DCN","FMOD","LUM","PRELP","OGN","ASPN","CHAD","EPYC","HAPLN1","VCAN","VER","VERSICAN","NCAN","BCAN","ACAN","NEU1","HEXA","HEXB","GM2A","GM2B","ST3GAL5","B4GALNT1","ARSA","ARSB","GALNS","GUSB","IDUA","IDURONATE","NAGLU","HGSNAT","GNS","SGSH","SUMF1","SUMF2","HPSE","EXT1","EXT2","EXTL1","EXTL2","EXTL3","FGF1","FGF2","FGF7","FGF8","FGF9","FGF10","FGF18","FGFR4","FRS2","GRB2","SOS1","RASGRF1","RASGRP1","NF1","NF2","RASA1","SPRED1","SPRED2","DAB2IP","TSC1","TSC2","RHEB","RPTOR","RICTOR","PRKAA1","PRKAA2","PRKAB1","PRKAB2","STK11","LKB1","CAMKK2","AMPK","ULK1","ATG5","ATG7","ATG12","BECN1","SQSTM1","MAP1LC3A","MAP1LC3B","GABARAP","GABARAPL1","GABARAPL2","OPTN","NDP52","CALCOCO2","TAX1BP1","WDFY3","TANK","TBK1","IRF3","IRF7","MAVS","STING","TMEM173","CGAS","MB21D1","DDX41","RIGI","MDA5","IFIH1","LGP2","DHX58","TREX1","SAMHD1","APOBEC3G","BST2","MX1","MX2","OAS1","OAS2","OAS3","RNASEL","EIF2AK2","PKR","ISG15","USP18","STAT1","STAT2","IRF9","TYROBP","DAP12","TYROBP","FCER1G","ITAM","SYK","ZAP70","LAT","SLP76","VAV1","VAV2","VAV3","RHOA","RAC1","CDC42","WAS","WIPF1","ARPC2","ARPC3","ARPC4","ARPC5","ARPC1A","ARPC1B" )
$realGenes = $realGenes | Sort-Object -Unique
Write-Output "real genes count: $($realGenes.Count)"
# 写 diff.txt（id + logFC + adj.P.Val 列）
$rows = foreach ($i in 0..($realGenes.Count-1)) {
  $g = $realGenes[$i]
  $fc = if ($i -lt 50) { 1.5 } else { 0.1 }
  $q = if ($i -lt 50) { 1e-6 } else { 0.4 }
  "{0}`t{1}`t{2}`t{3}" -f $g, $fc, $q, $q
}
@("id`tlogFC`tP.Value`tadj.P.Val") + $rows | Set-Content "$WORK\diff_realgenes.txt" -Encoding UTF8
Write-Output "--- diff_realgenes head ---"
Get-Content "$WORK\diff_realgenes.txt" -TotalCount 6
Write-Output "=== S05 with real genes ==="
& Rscript.exe "$SOP\bio-05-enrichment\scripts\enrichment_analysis.R" "--input=$WORK\diff_realgenes.txt" "--species=human" "--outdir=$WORK" 2>&1 | Select-String -Pattern "INFO|WARN|Error|GO|KEGG|SUCCESS|ontology|ERROR" | Select-Object -Last 40
Write-Output "S05REAL_EXIT=$LASTEXITCODE"