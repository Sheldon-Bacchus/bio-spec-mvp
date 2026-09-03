# WGCNA 参数调优与网络分析指南 (WGCNA Parameter Guide & Network Theory)

## 1. 加权基因共表达网络 (WGCNA) 理论核心

加权基因共表达网络分析 (Weighted Gene Co-expression Network Analysis, WGCNA) 是一种将基因表达数据转化为无尺度生物网络的系统生物学方法。与传统差异表达分析（仅关注单基因表达量高低）不同，WGCNA 聚焦于基因间的协同共调控网络，能够有效识别生物学功能模块和处于调控中枢的 Hub 基因。

---

## 2. 核心数学模型与算法步骤

```
[表达矩阵 (Top MAD 基因)]
         ↓
[计算相关性矩阵 (Pearson / Biweight Midcorrelation)]
         ↓
[无尺度网络软阈值化 (Power β 使得 R² > 0.85)]
         ↓
[拓扑重叠矩阵 (TOM) 与相异度计算 (dissTOM = 1 - TOM)]
         ↓
[动态树剪切识别模块 (Dynamic Tree Cut, minModuleSize=30)]
         ↓
[相似模块合并 (mergeCutHeight = 0.25, 相关性 > 0.75)]
         ↓
[模块特征向量 (ME) 与临床表型关联分析]
         ↓
[Hub 基因提取 (|MM| > 0.8 且 |GS| > 0.2)]
```

### 2.1 无尺度拓扑 (Scale-Free Topology) 与软阈值选择
真实生物网络普遍符合**无尺度特性**：大部分节点只有极少的连接度，而少数关键节点（Hub 节点）具有极高的连接度。其节点度分布服从幂律分布：
$$P(k) \sim k^{-\gamma}$$

在 WGCNA 中，两两基因之间的加权邻接度 (Adjacency) 通过幂函数进行软阈值化：
$$a_{ij} = |cor(x_i, x_j)|^\beta \quad (\text{无向网络 unsigned})$$
- 软阈值 $\beta$ 的选取原则：
  - 在保持平均连接度 (Mean Connectivity) 不过度衰减的前提下，选取使无尺度拟合指数（Signed $R^2$）达到并稳定在 **0.85** 以上的最小整数 $\beta$。
  - 若样本量较小导致 $R^2$ 难以达到 0.85，可放宽至 0.80，但必须确认平均连接度平滑下降。

### 2.2 拓扑重叠矩阵 (Topological Overlap Matrix, TOM)
单纯的两两相关系数无法区分“直接调控”与“间接影响”。TOM 综合衡量了基因 $i$ 和基因 $j$ 之间直接连接强度以及它们共享近邻基因的程度：
$$TOM_{ij} = \frac{l_{ij} + a_{ij}}{\min(k_i, k_j) + 1 - a_{ij}}$$
其中：
- $l_{ij} = \sum_u a_{iu} a_{uj}$ 表示两个基因共享的一级邻居加权强度之和；
- $k_i = \sum_u a_{iu}$ 表示基因 $i$ 的全网连接度。
相异度矩阵定义为：$dissTOM = 1 - TOM$。

### 2.3 动态剪切与模块合并参数
- `maxBlockSize = 6000`: 单内存块最大基因数。若机器内存充足且基因数 $\le 6000$，单块计算可避免分块截断误差。
- `minModuleSize = 30`: 定义一个独立功能模块所需的最小基因数目，防止产生碎片化微小模块。
- `mergeCutHeight = 0.25`: 树剪切后合并相似模块的距离阈值。对应于两个模块的特征向量相关系数 $r \ge 1 - 0.25 = 0.75$ 时自动合并。

---

## 3. 模块特征向量与表型关联 (Module-Trait Association)

### 3.1 模块特征向量 (Module Eigengene, ME)
每个共表达模块由其标准化表达矩阵的第一主成分向量 $ME$ 代表：
$$ME_q = \text{PC1 of Module } q$$
它解释了该模块内所有基因表达变异的最大比例，将高维模块降维为一个一维指标。

### 3.2 模块-表型相关性热图解读
- 计算每个 $ME$ 与表型向量（如铜绿假单胞菌 `biofilm` = 1, `planktonic` = 0）的 Pearson 相关系数及 Student $t$ 检验 $p$ 值：
  $$t = \frac{r \sqrt{n - 2}}{\sqrt{1 - r^2}}$$
- 质控 Gate 要求：选定为下游研究的目标模块，其与表型的相关性检验 $p < 0.05$。

---

## 4. Hub 基因的筛选体系 (MM & GS)

在选定关键模块后，通过两个互补维度筛选处于网络调控核心的 Hub 基因：

| 指标 | 全称与公式 | 生物学含义 | 常用质控截断值 |
| :--- | :--- | :--- | :--- |
| **MM** | **Module Membership**<br>$MM_i = |cor(x_i, ME)|$ | 基因在模块内的中心地位（与模块特征向量的相关性），MM 越接近 1 说明处于模块中心 | $|MM| \ge 0.80$ |
| **GS** | **Gene Significance**<br>$GS_i = |cor(x_i, Trait)|$ | 基因表达量与生物学表型直接关联的紧密程度 | $|GS| \ge 0.20$ (或 $>0.50$) |
| **$k_{within}$** | **Intramodular Connectivity** | 基因在该模块内部与其他基因的加权邻接度总和 | Top 10% 基因 |

### 4.1 散点图对角线模式验证
在 `MM vs GS` 散点图中：
- 若散点呈现良好的正相关线性分布（点集中在右上方），说明**该模块中与模块主调控最紧密的基因，恰恰也是对表型贡献最显著的基因**。这强有力地证明了该共表达模块具备高度的生物学特异性。
