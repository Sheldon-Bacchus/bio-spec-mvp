---
name: bio-01-geo-dataprep
description: >-
  GEO 芯片数据下载与预处理。当用户需要从 GEO 数据库获取基因表达芯片数据（如 GSE10030）、
  完成探针→基因Symbol映射、缺失值 KNN 填充、重复基因取均值时，使用此技能。
---

# GEO 数据预处理

## 依赖声明

### MCP 服务
- `biomcp` — 用于验证 GSE/GPL 编号合法性、检索基因注释

### R 包
- `GEOquery`, `Biobase`, `impute`, `limma`

### 输入
- GSE 编号字符串（如 `GSE10030`）
- GPL 平台 ID（如 `GPL84`）

### 输出
- `{gse_id}.normalize.txt` — 行=基因Symbol, 列=样本ID, 值=log2表达量
- `group.txt` — 样本分组信息

## 执行步骤

1. 通过 `biomcp gene search <symbol>` 或 GEOquery 获取 GSE 元数据，确认数据集编号有效
2. 运行 [geo_preprocess.R](./scripts/geo_preprocess.R)：
   - 读取原始探针表达矩阵
   - 探针 ID → 基因 Symbol 映射（多探针取均值）
   - KNN 缺失值填充（k=10, rowmax=0.5, colmax=0.8）
   - 输出经过清洗的表达矩阵
3. 根据芯片信息生成分组文件 `group.txt`

## Gate 校验
- `{gse_id}.normalize.txt` 存在且行数 > 0
- 基因列无空值
- `group.txt` 中的样本名与表达矩阵列名一一对应

## 参考原始脚本
- [geoGene01.数据预处理最终版.R](./scripts/geo_preprocess.R)
