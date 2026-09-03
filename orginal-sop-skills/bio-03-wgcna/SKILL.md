---
name: bio-03-wgcna
description: >-
  WGCNA 加权基因共表达网络分析。当用户需要从表达矩阵中识别共表达模块、
  选择软阈值、绘制模块-表型相关性热图、提取感兴趣模块基因列表时，使用此技能。
---

# WGCNA 共表达网络分析

## 依赖声明

### MCP 服务
- 无

### R 包
- `WGCNA`, `flashClust`

### 输入
- `merge.normalize.txt` — 去批次后表达矩阵（取 top MAD 基因）
- `clinic.csv` — 样本表型信息（sample + 表型列）

### 输出
- `softThreshold.pdf` — 软阈值选择图
- `moduleDendrogram.pdf` — 模块聚类树
- `module_trait_heatmap.pdf` — 模块-表型相关性热图
- `geneInfo.csv` — 全基因模块归属与显著性信息
- `module_genes.csv` — 目标模块基因列表

## 执行步骤

1. 运行 [wgcna_build.R](./scripts/wgcna_build.R)：
   - 读取表达矩阵，取 top MAD 基因（默认 5515 个）
   - 转置矩阵（WGCNA 针对基因聚类）
   - `pickSoftThreshold()` 计算最佳软阈值
   - `blockwiseModules()` 构建网络（`maxBlockSize=6000`, `minModuleSize=30`, `mergeCutHeight=0.25`）
   - 绘制模块聚类树与颜色标注
   - 计算模块特征向量 (MEs) 与表型相关性热图
2. 运行 [wgcna_module_export.R](./scripts/wgcna_module_export.R)：
   - 指定感兴趣模块（如 `moduleColor = "brown"`）
   - 计算 Module Membership (MM) 与 Gene Significance (GS)
   - 绘制 MM vs GS 散点图
   - 导出 `geneInfo.csv` 和 `module_genes.csv`

## Gate 校验
- 软阈值 R² > 0.85
- 目标模块与表型相关性 p < 0.05
- `module_genes.csv` 非空

## 关键参数
- `set.seed(12345)` 固定随机种子
- `power = sft$powerEstimate` 自动优选软阈值

## 参考原始脚本
- [wgcna2019-1.R](../../raw_code/wgcna/wgcna2019-1.R)
- [wgcna2019-02.R](../../raw_code/wgcna/wgcna2019-02.R)
