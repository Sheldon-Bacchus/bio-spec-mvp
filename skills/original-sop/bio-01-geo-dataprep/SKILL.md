---
name: bio-01-geo-dataprep
description: >-
  GEO 芯片数据下载与预处理。当用户需要从 GEO 数据库获取基因表达芯片数据（如 GSE10030）、
  完成探针→基因Symbol映射、缺失值 KNN 填充、重复基因取均值时，使用此技能。
---

# GEO 数据预处理

## 依赖声明

### MCP 服务
- `biomcp`（可选）— 用于验证 GSE/GPL 编号合法性、检索基因注释

### R 包
- `GEOquery`（可选：元数据检索步骤），`Biobase`, `impute`, `limma`

### 输入
- `{gse_id}_probe_exprs.txt` — 探针表达矩阵（首列探针ID + 样本列）
- `{gse_id}_platform.txt` — 平台注释（ID + Gene.Symbol）
- `--sample-con` / `--sample-treat` — 显式分组（逗号分隔样本ID；**推荐提供**）

### 输出
- `{gse_id}.normalize.txt` — 行=基因Symbol, 列=样本ID, 值=log2表达量
- `PD.csv` / `group.txt` — 样本分组信息
- `inferred_groups.csv`（仅推断路径）— 推断分组审计表

## 执行步骤

1. 通过 `biomcp` 或 GEOquery 获取 GSE 元数据，确认数据集编号有效（可选）
2. 运行 [geo_preprocess.R](./scripts/geo_preprocess.R)：
   - 读取原始探针表达矩阵
   - 探针 ID → 基因 Symbol 映射（多探针取均值 avereps）
   - KNN 缺失值填充（k=10, rowmax=0.5, colmax=0.8）
   - log2 检测与变换（必要时）
   - 输出经过清洗的表达矩阵
3. 生成分组文件：**优先使用 --sample-con/--sample-treat 显式分组**；
   样本名启发式仅在明确命中时使用（输出 inferred_groups.csv + WARN 供人工复核）；
   **无任何分组依据时报错退出（fail-closed，禁止"前一半/后一半"静默推断）**

## Gate 校验
- `{gse_id}.normalize.txt` 存在且行数 > 0
- 基因列无空值
- `PD.csv` 中的样本名与表达矩阵列名一一对应

## 版本说明
- 2026-09-03 (spec-007): 分组 fail-closed（G-02）；CLI 连字符参数修复（F-01: --gse-id 等生效）
