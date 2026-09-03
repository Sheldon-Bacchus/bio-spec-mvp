# limma 差异分析原理与设计矩阵构建指南 (limma Linear Models & Design Matrix Guide)

## 1. limma 的统计学架构

`limma` (Linear Models for Microarray and RNA-seq Data) 是转录组差异表达分析的标杆工具。其核心优势在于将经典的**广义线性模型 (GLM)** 与**经验贝叶斯方差收缩 (Empirical Bayes Moderation)** 相结合，在小样本场景下展现出极高的统计功效与对虚假低方差基因的免疫力。

---

## 2. 线性模型与设计矩阵构建

差异分析的首要步骤是将实验设计形式化为线性模型：
$$E[Y_g] = X \alpha_g$$
其中 $Y_g$ 是基因 $g$ 在各样本中的表达量向量，$X$ 为设计矩阵 (Design Matrix)，$\alpha_g$ 为待估计的系数向量。

### 2.1 两种设计矩阵对比

#### 方案 A：无截距单元格均值模型 (Cell-Means Model, `~ 0 + Group`) —— **推荐标准**
```R
Group <- factor(c("Control", "Control", "Treat", "Treat"), levels = c("Control", "Treat"))
design <- model.matrix(~ 0 + Group)
colnames(design) <- c("Control", "Treat")
```
- **设计矩阵形态**:
  $$\begin{pmatrix} 1 & 0 \\ 1 & 0 \\ 0 & 1 \\ 0 & 1 \end{pmatrix}$$
- **系数含义**: 系数直接对应各组别的平均表达量 $\mu_{\text{Control}}$ 和 $\mu_{\text{Treat}}$。
- **差异检验**: 必须显式构建对比矩阵 (Contrast Matrix)：
  ```R
  contrast_matrix <- makeContrasts(Treat - Control, levels = design)
  fit_contrast <- contrasts.fit(fit, contrast_matrix)
  ```
- **优点**: 物理意义极为清晰，极易扩展到多组比较（如 $A - B$, $B - C$）或双因素交互实验。

#### 方案 B：带截距基准模型 (Reference-Level Model, `~ Group`)
```R
design <- model.matrix(~ Group)
```
- **系数含义**: 第 1 个系数（Intercept）代表基线组均值 $\mu_{\text{Control}}$；第 2 个系数直接代表组间差异 $\mu_{\text{Treat}} - \mu_{\text{Control}}$。
- **差异检验**: 可直接提取第 2 个系数 (`coef = 2`) 进行统计推断。
- **缺点**: 当存在 3 组以上或复杂的交叉对比时容易引起混淆。

### 2.2 包含批次协变量的设计矩阵
若数据经过批次校正后仍需消除残余协变量，可直接将批次作为固定效应纳入设计矩阵：
```R
design <- model.matrix(~ 0 + Group + Batch)
```

---

## 3. 经验贝叶斯方差平滑 (eBayes Moderation)

### 3.1 传统 Student's t 检验的缺陷
在微阵列芯片研究中，通常每个处理组仅有 3 至 6 个样本。如果对每个基因单独计算样本方差 $s_g^2$ 并执行 $t$ 检验：
- 某些基因纯属偶然原因，其样本方差极小（$s_g^2 \to 0$）；
- 导致即便表达差异很小，也能计算出极大的 $t$ 值，诱发海量的**伪差异基因 (False Positives)**。

### 3.2 limma 的先验收缩机制
limma 假定所有基因的真实残差方差 $\sigma_g^2$ 服从一个共同的共轭先验逆卡方分布：
$$\frac{1}{\sigma_g^2} \sim \frac{1}{d_0 s_0^2} \chi_{d_0}^2$$
其中 $s_0^2$ 为所有基因的全局平均先验方差，$d_0$ 为先验自由度。

通过 Bayes 定理，基因 $g$ 的后验残差方差被“收缩 (Squeezed)”为一个受调和的方差估计量 $\tilde{s}_g^2$：
$$\tilde{s}_g^2 = \frac{d_0 s_0^2 + d_g s_g^2}{d_0 + d_g}$$

在此基础上构建**适调 $t$ 统计量 (Moderated t-statistic)**：
$$\tilde{t}_{gj} = \frac{\hat{\beta}_{gj}}{\tilde{s}_g \sqrt{v_{gj}}}$$
- 当某个基因的样本方差 $s_g^2$ 极小时，$d_0 s_0^2$ 会将其拉高，防止产生虚假显著；
- 极大提升了统计检验的平稳性与可重复性。

---

## 4. 多重假设检验与 FDR 校正

在全基因组水平同时对数千甚至数万个基因进行假设检验时，假阳性概率会急剧累积。

### 4.1 FWER vs FDR
- **FWER (Family-Wise Error Rate, 如 Bonferroni 法)**: 控制“至少出现 1 个假阳性”的概率。惩罚极其严苛，在生物学探索中会导致严重的假阴性漏报。
- **FDR (False Discovery Rate, Benjamini-Hochberg 法)**: 控制“在所有宣称差异的基因中，假阳性所占的期望比例”。这是生信分析的行业法定标准。

### 4.2 Benjamini-Hochberg (BH) 算法原理
设检验了 $m$ 个基因，其原始 $p$ 值升序排列为 $P_{(1)} \le P_{(2)} \le \dots \le P_{(m)}$：
1. 寻找满足下式的最大序号 $k$：
   $$P_{(k)} \le \frac{k}{m} \cdot \alpha$$
2. 将所有 $i \le k$ 的基因判定为显著差异。
3. 对应的校正后值称为 **FDR (或 adj.P.Val)**：
   $$q_{(i)} = \min_{j \ge i} \left( \frac{m}{j} P_{(j)} \right)$$

### 4.3 显著基因联合判定 Gate
为了兼顾**统计学显著性**与**生物学幅度显著性**，本流水线执行严格的双重 Gate：
- 统计显著 Gate: $\text{adj.P.Val} < 0.05$ (控制假阳性率 $<5\%$)
- 效应幅度 Gate: $|\log_2 \text{FC}| \ge 1.0$ (表达变化倍数 $\ge 2$ 倍)
