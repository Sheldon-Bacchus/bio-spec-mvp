# Random Forest Variable Importance & Permutation Testing Guide

## 1. Principles of Random Forest in High-Dimensional Bioinformatics

Random Forest (Breiman, 2001) is a non-parametric ensemble learning method constructed from decorrelated decision trees. It is particularly well-suited for gene expression data characterized by complex non-linear epistatic interactions and high multicollinearity.

Each tree $b \in \{1, \dots, B\}$ is trained on an independent bootstrap sample of the cohort ($N$ samples with replacement, leaving approximately $36.8\%$ Out-of-Bag [OOB] samples). At every split node, a random subset of $m_{\text{try}} \approx \sqrt{p}$ features is evaluated to identify the splitting variable that minimizes class impurity.

```
       Training Dataset (N samples, P genes)
                   │
    ┌──────────────┼──────────────┐  (Bootstrap Sampling)
    ▼              ▼              ▼
 Tree 1         Tree 2         Tree B  (B = 500 trees)
 (mtry genes)   (mtry genes)   (mtry genes)
    │              │              │
    └──────────────┬──────────────┘
                   ▼
       Ensemble Majority Vote / Impurity Metric
```

---

## 2. Variable Importance Metrics: Gini Impurity vs. Permutation Accuracy

### 2.1 Mean Decrease Gini (Node Impurity)
The Gini impurity $I_G(t)$ of node $t$ containing class proportions $p_1, \dots, p_C$ is:
$$I_G(t) = 1 - \sum_{c=1}^C p_c^2$$

The Gini importance of gene $X_j$ is the total weighted reduction in impurity accumulated across all trees:
$$\text{MeanDecreaseGini}(X_j) = \frac{1}{B} \sum_{b=1}^B \sum_{t \in T_b : v(t) = X_j} \Delta I_G(t)$$
Where $\Delta I_G(t) = N_t I_G(t) - N_{t_L} I_G(t_L) - N_{t_R} I_G(t_R)$.

- **Advantage**: Fast to compute; captures how consistently a gene partitions phenotypes cleanly.
- **Critical Limitation (Strobl Bias)**: Standard Gini importance exhibits systemic bias toward continuous variables with wide dynamic ranges or high variance, even if they have zero true biological relationship with the phenotype.

### 2.2 Mean Decrease Accuracy (MDA / Permutation Importance)
1. Predict OOB sample labels using the trained tree, recording baseline classification accuracy.
2. Randomly permute the values of gene $X_j$ across OOB samples, breaking its association with the disease phenotype while preserving marginal distribution.
3. Re-predict OOB samples; the drop in accuracy reflects variable importance:
$$\text{MDA}(X_j) = \frac{1}{B} \sum_{b=1}^B \left[ \text{Acc}_{\text{OOB}}(b) - \text{Acc}_{\text{OOB}}^{\pi_j}(b) \right]$$

---

## 3. The Permutation Significance Test (`rfPermute`)

To overcome the Strobl bias in small clinical cohorts, `rfPermute` (Archer, 2016; Altmann et al., 2010) generates an empirical null distribution for feature importance:

1. **Null Generation**: The true phenotype vector $\mathbf{y}$ is permuted $K$ times ($K = 299$ to $1000$).
2. **Forest Re-training**: For each permutation $k \in \{1, \dots, K\}$, an entire random forest of $B=500$ trees is trained on $(\mathbf{X}, \mathbf{y}^{(k)})$, generating null importances $I_j^{(k)}$.
3. **Empirical $p$-value Calculation**:
   $$P(X_j) = \frac{1 + \sum_{k=1}^K \mathbb{I}\left(I_j^{(k)} \ge I_j^{\text{observed}}\right)}{K + 1}$$

### Significance Stratification
- $P < 0.001$: `***` (Highly robust disease driver)
- $P < 0.01$: `**` (Strong candidate biomarker)
- $P < 0.05$: `*` (Significant candidate)
- $P \ge 0.05$: Filtered out as background noise

---

## 4. Preventing Overfitting in Small Sample Cohorts ($N < 50$)

| Risk Factor | Mechanism | Pipeline Countermeasure |
|---|---|---|
| **High $P/N$ Ratio** | Tree branches memorize individual outlier samples | Candidate gene pre-filtering via WGCNA $\cap$ DEG ($P \le 300$); $B = 500$ ensemble averaging. |
| **Class Imbalance** | Trees heavily favor the majority class | Use stratified bootstrap sampling or adjust class weights (`classwt`). |
| **Multicollinearity** | Trees split across multiple correlated genes in the same pathway, diluting individual importance | Set $m_{\text{try}} = \sqrt{p}$ to force competing correlated genes into different trees. |
| **Random Variability** | Different seeds yield slightly different rankings | Fix global seed (`set.seed(12345)`) across all bootstrap and permutation runs. |
