# test_rf_fallback.R - Force the rfPermute-unavailable path to test fake p=0.02
$tmp <- tempfile()
# 用 withr 风格临时禁用 rfPermute: 直接改脚本逻辑难，改为模拟"rfPermute 装不上"的场景：
# 办法：设置 .libPaths 隐藏 rfPermute，或直接在脚本里 requireNamespace 前屏蔽。
# 简便法：复制脚本,注释掉 has_rfPermute 检测，强制走 randomForest 手动置换分支
cat("see test_rf_fallback.ps1 for the forced-fallback test")