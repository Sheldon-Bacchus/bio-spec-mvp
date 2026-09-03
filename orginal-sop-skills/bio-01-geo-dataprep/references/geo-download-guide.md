# GEO 数据下载与预处理指南 (GEO Download & Preprocessing Guide)

## 1. GEO 数据架构与核心对象

NCBI Gene Expression Omnibus (GEO) 是全球最大的公共功能基因组学数据库。理解其数据组织层级是进行可靠生物信息学分析的基础：

| 实体前缀 | 名称 | 描述 | 关键数据结构 |
| :--- | :--- | :--- | :--- |
| **GSE** | Series (研究序列) | 一组相关样本的集合，包含完整的实验设计与元数据 | `ExpressionSet` / `GEOList` |
| **GSM** | Sample (样本) | 单个杂交芯片或测序样本的技术/生物学重复 | `pData` (表型数据), Raw intensities |
| **GPL** | Platform (芯片平台) | 探针设计、序列信息及基因注释清单 | `fData` (特征注释表) |
| **GDS** | Dataset (整理数据集) | NCBI 官方人工整理、归一化后的表达集 | 表格化数据 (较少用于最新分析) |

---

## 2. 案例研究：GSE10030 与 GPL84 芯片平台

### 2.1 生物学背景
- **研究编号**: GSE10030
- **生物体**: *Pseudomonas aeruginosa* (铜绿假单胞菌 PAO1)
- **研究主题**: 铜绿假单胞菌在生物膜 (Biofilm) 状态与浮游 (Planktonic) 状态下的转录组差异。生物膜是导致细菌耐药性、慢性感染（如囊性纤维化肺部感染）和医疗器械污染的核心表型。
- **样本构成**: 对照组（浮游细菌，3个生物学重复）与实验组（生物膜成熟细菌，3个生物学重复），通常在研究中与其他批次（如合并 GSE15629 等）组合分析。

### 2.2 平台特征 (GPL84)
- **平台名称**: [Affymetrix GeneChip P. aeruginosa Genome Array](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GPL84)
- **设计规格**: 包含 5,900 个探针组 (Probe sets)，覆盖 PAO1 全部 5,570 个预测开放阅读框 (ORFs)、199 个基因间区域以及 117 个其他假单胞菌菌株基因。
- **探针命名规范**: 以 `PA0001_at`, `PA0002_at` 或基因间区域编号命名，其标识直接对应铜绿假单胞菌官方 PA 基因编号 (Pseudomonas Genome Database)。

---

## 3. GEOquery 程序化检索与数据提取

使用 Bioconductor 核心包 `GEOquery` 可以直接在 R 环境中无缝下载并构建表达集：

```R
library(GEOquery)
library(Biobase)

# 1. 下载并加载 Series 矩阵
gse_id <- "GSE10030"
gse <- getGEO(gse_id, GSEMatrix = TRUE, AnnotGPL = TRUE, destdir = "./raw_geo")

# 2. 提取 ExpressionSet
eset <- gse[[1]]

# 3. 获取表型元数据 (PhenoData)
pheno_data <- pData(eset)
# 查看样本分组特征
sample_titles <- pheno_data$title
sample_characteristics <- pheno_data$characteristics_ch1

# 4. 获取探针特征注释 (FeatureData)
feature_data <- fData(eset)

# 5. 获取原始表达量矩阵
expr_mat <- exprs(eset)
```

---

## 4. 探针到基因 Symbol 的映射策略

在芯片数据分析中，探针 (Probe ID) 与基因 (Gene Symbol) 之间通常存在复杂的多对多映射关系：

### 4.1 映射关系分类及处理规则
1. **一对一 (One-to-One)**: 一个探针精确对应一个基因，直接保留。
2. **多对一 (Many-to-One)**: 多个探针检测同一个基因。
   - **处理方法**: 
     - **均值法 (`limma::avereps`)**: 对属于同一基因的所有探针表达量取算术平均值。这是保留全局转录信号稳健性的黄金标准。
     - **最大值法 (Max Mean/IQR)**: 选取方差或信号均值最大的探针作为代表。
     - **本流水线标准**: 严格采用 `limma::avereps` 进行均值坍缩，保证可复现性。
3. **一对多 (One-to-Many)**: 一个探针跨越多个同源基因（如 `PA1234 /// PA1235`），特异性较差，通常取主要注释或直接剔除以避免跨基因信号污染。
4. **无注释 (Unannotated)**: 探针未匹配到有效基因 Symbol，直接过滤。

---

## 5. 缺失值 KNN 填充原理与参数依据

### 5.1 缺失值产生原因
- 芯片杂交表面划痕、气泡或灰尘导致特定区域荧光信号丢失；
- 低信号探针经过背景扣除后出现负值或被设为 NA；
- 平台数据格式转换中的非数值字符。

### 5.2 KNN 填充数学原理
基于 $k$-最近邻 (k-Nearest Neighbors) 的缺失值填补算法 (`impute::impute.knn`) 在基因空间工作：
设基因 $g$ 在样本 $j$ 上的表达量 $y_{gj}$ 缺失：
1. 计算基因 $g$ 与数据集中其他所有具有完整观测值的基因 $g'$ 之间的欧几里得距离 (Euclidean Distance)：
   $$d(g, g') = \sqrt{ \frac{1}{|S_{g \cap g'}|} \sum_{k \in S_{g \cap g'}} (y_{gk} - y_{g'k})^2 }$$
   其中 $S_{g \cap g'}$ 表示在两个基因中均未缺失的样本集合。
2. 选取出距离基因 $g$ 最近的 $k$ 个伴随基因 $g_1, g_2, \dots, g_k$。
3. 计算加权平均填补值：
   $$\hat{y}_{gj} = \sum_{m=1}^{k} w_m \cdot y_{g_m j} \quad \text{其中 } w_m = \frac{1/d(g, g_m)}{\sum_{l=1}^{k} 1/d(g, g_l)}$$

### 5.3 质控阈值设定标准 (QC Gates)
- `k = 10`: 经验证明在芯片样本规模下，10 个近邻能有效平滑局部扰动并避免过拟合。
- `rowmax = 0.5`: 单个基因在所有样本中缺失率超过 50% 时，其全局表达模式不可信，直接剔除。
- `colmax = 0.8`: 单个样本中基因缺失率超过 80% 时，表明该芯片杂交失败，应废弃整个样本。
- `rng.seed = 12345`: 固定随机数发生器种子，满足宪法中关于可复现性的严格要求。

---

## 6. 数据输出契约规范

经过 Stage 01 处理后的产物必须满足以下格式契约：

1. **`{gse_id}.normalize.txt`**:
   - 行名/第一列: `Symbol` (唯一的基因标识符，如 `PA0001`)
   - 列名: 样本唯一编号 (如 `GSM253901`, `GSM253902`)
   - 数值单元格: `log2` 尺度表达量（浮点数），以 Tab (`\t`) 分隔。
2. **`group.txt` / `PD.csv`**:
   - 包含列 `sample` 与 `group`，且样本列表必须与矩阵列名严格双向一一对应。
