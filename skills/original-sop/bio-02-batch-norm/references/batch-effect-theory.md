# 批次效应去除理论与 ComBat/SVA 算法模型 (Batch Effect Theory & ComBat/SVA Mathematics)

## 1. 批次效应的生物学与技术成因

在基于高通量芯片（Microarray）或 RNA 测序（RNA-seq）的生命科学实验中，**批次效应 (Batch Effects)** 指的是与感兴趣的生物学变量无关的技术性系统变异。常见诱因包括：
- **时间与环境差异**: 不同日期、不同实验人员、实验室温湿度波动；
- **平台与试剂批次**: 芯片加工批号（Lot number）、反转录酶/荧光标记染料活性差异；
- **样本处理技术差异**: RNA 提取方法、扩增反应循环数、臭氧浓度对 Cy5 染料的淬灭等。

如果不加以校正，批次效应会掩盖微弱的真实生物学差异（假阴性），或者诱发大量的虚假相关基因（假阳性）。

---

## 2. ComBat 算法的数学模型与经验贝叶斯框架

ComBat（Johnson et al., *Biostatistics*, 2007）是目前公认最稳健的批次效应消除算法。其核心是建立在**位置-尺度 (Location and Scale, L/S)** 模型之上的**经验贝叶斯 (Empirical Bayes, EB)** 收缩估计。

### 2.1 位置-尺度 (L/S) 模型公式
对于批次 $i$ ($i = 1, \dots, B$)、样本 $j$ ($j = 1, \dots, n_i$) 中的基因 $g$ ($g = 1, \dots, G$)，其标准化表达量 $Y_{ijg}$ 表达为：
$$Y_{ijg} = \alpha_g + X_{ij}\beta_g + \gamma_{ig} + \delta_{ig} \epsilon_{ijg}$$

其中：
- $\alpha_g$: 基因 $g$ 的总体基线表达水平；
- $X_{ij}$: 样本 $j$ 对应的生物学表型协变量设计矩阵（如 `biofilm` vs `planktonic`）；
- $\beta_g$: 生物学表型效应系数向量（必须受模型保护，不可被当作批次消除）；
- $\gamma_{ig}$: 批次 $i$ 对基因 $g$ 引起的**加性偏移 (Additive batch effect / Location parameter)**；
- $\delta_{ig}$: 批次 $i$ 对基因 $g$ 引起的**乘性离散缩放 (Multiplicative batch effect / Scale parameter)**；
- $\epsilon_{ijg} \sim N(0, \sigma_g^2)$: 随机误差项。

### 2.2 为什么需要经验贝叶斯 (Empirical Bayes)？
在实际研究中，每个批次的样本量往往很小（例如 $n_i = 3 \sim 6$）。若采用普通的线性回归（OLS）单独估计每个基因的 $\gamma_{ig}$ 和 $\delta_{ig}$，估计方差极大，极易导致极端异常值。

经验贝叶斯框架假设所有基因的批次参数来自于一个共同的先验分布：
$$\gamma_{ig} \sim N(\gamma_i, \tau_i^2)$$
$$\delta_{ig}^2 \sim \text{Inverse-Gamma}(\lambda_i, \theta_i)$$

通过在所有基因之间共享信息（Information Borrowing），利用条件后验均值将每个基因的批次参数向批次全局均值**收缩 (Shrinkage)**：
$$\gamma_{ig}^* = \frac{n_i \tau_i^2 \hat{\gamma}_{ig} + \sigma_g^2 \gamma_i}{n_i \tau_i^2 + \sigma_g^2}$$
从而在大样本和小样本极端值之间取得最佳权衡，显著提升了去批次后的信噪比。

### 2.3 矫正后表达值的计算
去批次后的最终标准化表达值 $Y_{ijg}^*$ 通过减去估计的加性效应并除以估计的乘性效应得到：
$$Y_{ijg}^* = \frac{Y_{ijg} - \hat{\alpha}_g - X_{ij}\hat{\beta}_g - \gamma_{ig}^*}{\delta_{ig}^*} + \hat{\alpha}_g + X_{ij}\hat{\beta}_g$$

---

## 3. 替代变量分析 (Surrogate Variable Analysis, SVA)

当批次来源未知（例如未记录芯片批号或混杂着未知细胞亚群、隐性污染）时，无法直接应用 ComBat。此时采用 **SVA** 算法：
1. 拟合只包含主要生物学变量的基线模型：$Y = X\beta + R$；
2. 计算残差矩阵 $R$；
3. 对残差矩阵进行奇异值分解 (Singular Value Decomposition, SVD)；
4. 识别显著的特征向量并构建一组连续型的**替代变量 (Surrogate Variables, SVs)**；
5. 将这些 SVs 作为协变量纳入 downstream 差异表达线性模型中。

---

## 4. PCA 与箱线图质控标准 (QC Gates)

经过 ComBat 校正后，必须进行严格的质控判定，只有通过 Stage 02 Gate 才能进入下游 WGCNA 或差异分析。

```
[原始多数据集] 
      ↓
[ComBat 校正] 
      ↓
[Gate 检验] 
   ├─ 1. 箱线图：各样本中位线是否水平对齐？
   ├─ 2. PCA 分组图：生物学表型（Biofilm vs Plank）是否完全分离？
   └─ 3. PCA 批次图：不同来源批次（GSE10030 vs GSE15629）是否均匀交织？
```

### 4.1 箱线图质控标准
- **未校正前**: 各数据集整体强度中位数参差不齐，箱体跨度明显不同；
- **校正合格标准**: 所有样本的中位线（50%分位数）基本水平对齐，四分位距 (IQR) 趋于一致。

### 4.2 PCA 空间质控标准
- **生物学分离度 (Biological Separation)**: 
  - 在以 PC1/PC2 为坐标的投影空间中，不同生物学状态（如 Biofilm 与 Planktonic）的置信椭圆或散点簇应当清晰可分，且群间距离大于群内方差。
- **批次混合度 (Batch Mixing)**:
  - 在同一生物学组内，来自不同数据来源（GSE 批次）的样本必须均匀混杂在一起，不能出现按 GSE 编号孤立成岛的现象。
  - 若 PCA 显示 PC1 或 PC2 依然与批次标签强相关，说明存在批次与生物学变量完全共线性（Confounding），需检查实验设计。
