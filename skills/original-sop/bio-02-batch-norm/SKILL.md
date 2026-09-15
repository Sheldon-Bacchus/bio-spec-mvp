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
- 显式 `--input-files` 表达矩阵路径（当前 orchestrator 传入本次 S01 的规范化矩阵）
- `--metadata` — canonical sample metadata CSV/TSV（sample_id、group、batch、partition；**必传**）
- `--manifest` / `--source-revision` — 当前运行 provenance（**必传**）

### 输出
- `merge.normalize.txt` — 去批次后合并矩阵
- `merge.preNorm.txt` — 去批次前合并矩阵（对照）
- `boxplot_comparison.pdf` — 批次效应前后箱线图
- `pca_qc.pdf` — PCA 质控图

## 执行步骤

1. 运行 [sva_combat.R](./scripts/sva_combat.R)：
   - 读取显式输入，按 canonical metadata 校验样本顺序和批次（<50 个共同基因或 batch 不可识别时 fail-closed）
   - 合并并保留 metadata 中的 canonical sample IDs，不从文件名推断批次或分组
   - 输出 `merge.preNorm.txt`（去批次前）
   - `ComBat(allTab, batchType, mod)` 去除批次效应（mod 保护生物学变量；缺失时显式 WARN 记录）
   - 输出 `merge.normalize.txt` + 前后对比箱线图
2. 运行 [pca_qc.R](./scripts/pca_qc.R)：按分组和批次双面板 PCA

## Gate 校验
- `merge.normalize.txt` 存在且行数 > 0；交集基因 ≥ 50
- 批次 ≥ 2；PCA 图非空
- 注意事项：批次与分组完全混杂时 ComBat 会明确报错（设计问题，需改实验设计）

## 版本说明
- 2026-09-15 (spec-008): canonical metadata/manifest inputs；no current-directory or filename batch/group inference；status/provenance artifacts
