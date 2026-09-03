---
name: bio-03-wgcna
description: >-
  WGCNA 加权基因共表达网络分析。当用户需要从表达矩阵中识别共表达模块、
  选择软阈值、绘制模块-表型相关性热图、提取感兴趣模块基因列表时，使用此技能。
---

# WGCNA 共表达网络分析

## 依赖声明

### R 包
- `WGCNA`（单线程模式，Windows 稳定性）

### 输入
- `merge.normalize.txt` — 去批次后表达矩阵（取 top MAD 基因）
- `clinic.csv` — 样本表型信息（sample + 表型列）

### 输出
- `softThreshold.pdf` — 软阈值选择图
- `moduleDendrogram.pdf` — 模块聚类树
- `module_trait_heatmap.pdf` — 模块-表型相关性热图
- `geneInfo.csv` — 全基因模块归属与显著性信息
- `module_genes.csv` — 目标模块基因列表
- `wgcna_net.RData` — 工作区（供 module_export）

## 执行步骤

1. 运行 [wgcna_build.R](./scripts/wgcna_build.R)：
   - 读取表达矩阵，取 top MAD 基因（默认 5000）
   - `pickSoftThreshold()` 计算最佳软阈值（R² 记录，未达 0.85 时 WARN+记录）
   - `blockwiseModules()` 构建网络
   - 模块-表型相关性热图与 p 值
   - `disableWGCNAThreads()` 单线程执行（规避 Windows socket 崩溃）
2. 运行 [wgcna_module_export.R](./scripts/wgcna_module_export.R)：
   - 指定/自动选择目标模块与 trait
   - 计算 MM 与 GS，导出 `geneInfo.csv` / `module_genes.csv`

## Gate 校验
- 软阈值 R² 记录（≥0.85 或明确 WARN）；目标模块-表型 p < 0.05 记录
- `module_genes.csv` 非空

## 版本说明
- 2026-09-03 (spec-007): WGCNA 单线程化（Windows 稳定性）；CLI 连字符参数修复
