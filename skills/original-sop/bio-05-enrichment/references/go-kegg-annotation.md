# 基因功能富集与通路注释理论指南 (GO & KEGG Functional Enrichment Theory)

## 1. 基因功能富集分析的核心逻辑

在高通量转录组或芯片分析中，差异表达分析（DEG）或加权网络分析（WGCNA）往往会筛选出数十至数百个候选基因。单纯阅读基因名称无法系统阐明生物学机理。**功能富集分析 (Functional Enrichment Analysis)** 的核心目标是将孤立的基因列表投影到已知的生物学知识库中，从统计学上判定哪些生物学功能、代谢通路或细胞构件被显著激活或抑制。

---

## 2. 知识库架构：Gene Ontology 与 KEGG

### 2.1 基因本体论 (Gene Ontology, GO)
GO 是一个严格受控的生物信息学词汇体系，其数据结构为**有向无环图 (Directed Acyclic Graph, DAG)**。
- **True Path Rule (真路径原则)**: 如果一个基因被注释到底层的子节点 Term，则它必然同时继承该节点所有祖先父节点的注释属性。
- **三大独立子本体 (Sub-ontologies)**:
  1. **Biological Process (BP, 生物学过程)**: 由多个分子活动协调完成的较广阔的生物学目标（如 *biofilm formation*, *cell wall macromolecule catabolic process*, *chemotaxis*）；
  2. **Cellular Component (CC, 细胞组分)**: 基因产物执行功能所在的亚细胞结构或复合体（如 *bacterial outer membrane*, *flagellum*, *ribosome*）；
  3. **Molecular Function (MF, 分子功能)**: 单个基因产物在分子水平上表现出的生化催化或结合活性（如 *ATP binding*, *catalytic activity*, *transcription factor activity*）。

### 2.2 京都基因与基因组百科全书 (KEGG)
KEGG 是手工绘制的高层次分子相互作用网络数据库，涵盖以下主要分支：
- **Metabolism (代谢通路)**: 糖酵解、TCA 循环、脂多糖生物合成（生物膜主要组分）；
- **Cellular Processes (细胞过程)**: 细菌趋化性、生物膜形成调控回路（如 `pae02025: Biofilm formation - Pseudomonas aeruginosa`）；
- **Environmental Information Processing (环境信息处理)**: 双组份信号转导系统 (Two-component systems)、ABC 转运蛋白；
- **Human Diseases (人类疾病)**: 宿主免疫应答、致病菌感染机制。

---

## 3. 过表征分析 (ORA) 的超几何检验数学模型

过表征分析 (Over-Representation Analysis, ORA) 是判定某个通路在输入基因列表中是否富集的最经典统计模型。

### 3.1 抽样列联表与超几何分布
设全基因组背景（Gene Universe）包含 $N$ 个基因，其中属于特定通路 $T$ 的基因数为 $M$。用户输入的待检验基因集共有 $n$ 个，其中有 $k$ 个基因落入通路 $T$：

| 类别 | 属于通路 $T$ | 不属于通路 $T$ | 合计 |
| :--- | :--- | :--- | :--- |
| **输入基因集 (DEG)** | $k$ | $n - k$ | $n$ |
| **非输入基因集** | $M - k$ | $(N - M) - (n - k)$ | $N - n$ |
| **全基因组背景 (Universe)** | $M$ | $N - M$ | $N$ |

在零假设 $H_0$（输入基因是全基因组背景下的随机均匀无偏抽样）下，落入通路 $T$ 的基因数 $X$ 服从超几何分布。观测到至少 $k$ 个基因富集的单侧 $p$ 值为：
$$P(X \ge k) = \sum_{i=k}^{\min(n, M)} \frac{\binom{M}{i} \binom{N - M}{n - i}}{\binom{N}{n}}$$

### 3.2 背景基因集 (Universe) 的关键影响
- **常见误区**: 盲目使用全物种所有已知基因作为背景 $N$。
- **严谨规范**: 必须以**当前芯片平台（如 GPL84 实际检测到的所有探针对应基因）**作为背景基因集。若将芯片未检测的基因计入背景，会人为拉大分母，导致 $p$ 值虚假偏小。

---

## 4. 多重检验校正 (Benjamini-Hochberg)

由于在单次分析中需要同时对成千上万个 GO Term 或数百条 KEGG 通路执行超几何检验，必须对原始 $p$ 值进行假发现率（FDR / $q$-value）校正：
$$q_{(i)} = \min_{j \ge i} \left( \frac{m}{j} P_{(j)} \right) \le 0.05$$
本流水线 Stage 05 Gate 要求：**至少具备 1 个显著富集的 GO term 与 1 条显著富集的 KEGG 通路 ($q < 0.05$)**。

---

## 5. 跨物种注释考量：人 (Human) vs 假单胞菌 (Pseudomonas)

| 维度 | 人类 (*Homo sapiens*) | 铜绿假单胞菌 (*Pseudomonas aeruginosa* PAO1) |
| :--- | :--- | :--- |
| **KEGG 物种代码** | `hsa` | `pae` |
| **官方基因标识** | HGNC Symbol, Entrez ID, Ensembl ID | PA 编号 (如 `PA0001`), Locus Tag |
| **OrgDb 注释包** | 官方预编译成熟包 `org.Hs.eg.db` | 无内置 Bioconductor 官方包，通常依赖 AnnotationHub、`org.Pseudomonas.pao1.db` 或 KEGG 在线 API 直接通过 `organism="pae"` 查询 |
| **GO 注释来源** | NCBI / Gene Ontology Consortium | Pseudomonas.com (Pseudomonas Genome Database) 权威发布 |
| **ID 转换策略** | `clusterProfiler::bitr()` 实现 Symbol $\to$ ENTREZID | 芯片探针名直译为 PA 编号，直接作为 KEGG 的输入 gene list |
