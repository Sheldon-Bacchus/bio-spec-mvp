---
name: bio-02-batch-norm
description: >-
  多数据集归一化与批次效应校正。当用户合并多个 GEO 芯片数据集、
  需要 ComBat/SVA 去除批次效应、并通过 PCA 与箱线图验证效果时，使用此技能。
---

# 归一化与去批次效应

## 依赖声明

### R 包
- `limma` (avereps), `sva` (ComBat), `ggplot2`, `gridExtra`

### 输入
- 多个 `{gse_id}.normalize.txt` 文件（`--input-files` 逗号分隔或 `--indir` 模式匹配）
- `--pd` — PD.csv 分组信息（sample + group；**用于保护生物学变量**）
- 批次标识（各数据集即批次）

### 输出
- `merge.normalize.txt` — 去批次后合并矩阵
- `merge.preNorm.txt` — 去批次前合并矩阵（对照）
- `boxplot_comparison.pdf` — 批次效应前后箱线图
- `pca_qc.pdf` — PCA 质控图

## 执行步骤

1. 运行 [sva_combat.R](./scripts/sva_combat.R)：
   - 读取所有数据集，提取交集基因（<50 时 fail-closed 报错）
   - 合并并记录批次编号（列名加批次前缀 `TAG_`）
   - 输出 `merge.preNorm.txt`（去批次前）
   - `ComBat(allTab, batchType, mod)` 去除批次效应（mod 保护生物学变量；缺失时显式 WARN 记录）
   - 输出 `merge.normalize.txt` + 前后对比箱线图
2. 运行 [pca_qc.R](./scripts/pca_qc.R)：按分组和批次双面板 PCA

## Gate 校验
- `merge.normalize.txt` 存在且行数 > 0；交集基因 ≥ 50
- 批次 ≥ 2；PCA 图非空
- 注意事项：批次与分组完全混杂时 ComBat 会明确报错（设计问题，需改实验设计）

## 版本说明
- 2026-09-03 (spec-007): CLI 连字符参数修复（--input-files/--pd 生效）
