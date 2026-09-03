# GLMNET Parameter Tuning & L1 Regularization Guide

## 1. Mathematical Foundation of L1 Regularization (LASSO)

In logistic regression for binary disease classification ($y_i \in \{0, 1\}$), the standard log-likelihood objective becomes severely ill-posed when the feature space is high-dimensional ($p \gg n$ or high collinearity between co-expressed genes).

The Least Absolute Shrinkage and Selection Operator (LASSO) introduces an $L_1$ penalty on the coefficient vector $\boldsymbol{\beta}$:

$$
\min_{(\beta_0, \boldsymbol{\beta}) \in \mathbb{R}^{p+1}} \left\{ -\frac{1}{N} \sum_{i=1}^N \left[ y_i (\beta_0 + \mathbf{x}_i^T \boldsymbol{\beta}) - \log\left(1 + e^{\beta_0 + \mathbf{x}_i^T \boldsymbol{\beta}}\right) \right] + \lambda \sum_{j=1}^p |\beta_j| \right\}
$$

Where:
- $\lambda \ge 0$ is the regularization tuning parameter.
- The penalty $\sum_{j=1}^p |\beta_j|$ creates singular non-differentiable corners at coordinate axes where $\beta_j = 0$.
- Geometrically, the diamond-shaped $L_1$ constraint contour intersects the smooth elliptical contours of the negative log-likelihood precisely at the axes, driving redundant or collinear predictor coefficients to exact zeros (automatic feature selection).

---

## 2. Choosing Optimal Hyperparameter: `lambda.min` vs. `lambda.1se`

`cv.glmnet()` runs $K$-fold cross-validation (typically $K = 10$) across a decreasing grid of $\lambda$ values and tracks cross-validated deviance:

```
Deviance
   ▲
   │        ●   ●   ●   ●                     ●
   │      ●               ●                 ●
   │    ●                   ●             ●
   │  ●                       ●         ●
   │ ●                         ●       ●
   │                             ●   ●
   │                               ● ─── Error threshold (min + 1 SE)
   │                               | 
   │                               ▼
   │                            [lambda.min]
   │                       [lambda.1se]
   └──────────────────────────────────────────────► log(lambda)
         Sparse Model <───────────────────── Dense Model
```

### 2.1 `lambda.min`
- **Definition**: The value of $\lambda$ that achieves the minimum mean cross-validated deviance:
  $$\lambda_{\min} = \arg\min_{\lambda} \overline{\text{Deviance}}(\lambda)$$
- **Pros**: Yields optimal in-distribution classification accuracy and minimum generalization error.
- **Cons**: Tends to retain slightly more correlated variables; may be slightly sensitive to sample fluctuations in small $N$ datasets.
- **Recommended Usage**: Primary diagnostic biomarker discovery in this pipeline where candidate genes are already pre-filtered by WGCNA and limma.

### 2.2 `lambda.1se` (Breiman's One-Standard-Error Rule)
- **Definition**: The largest $\lambda$ (most heavily regularized and sparsest model) whose cross-validation error falls within 1 standard error of the minimum:
  $$\text{Deviance}(\lambda_{1\text{se}}) \le \overline{\text{Deviance}}(\lambda_{\min}) + \text{SE}(\lambda_{\min})$$
- **Pros**: Maximum parsimony (Occam's razor). Minimizes risk of overfitting and delivers the most compact possible diagnostic gene panel.
- **Cons**: May eliminate biologically vital secondary regulators in complex diseases.

---

## 3. Deviance Loss Metric in Small-Sample High-Dimensional Bio-Data

When running `cv.glmnet()`, the `type.measure` argument governs validation scoring:

| `type.measure` | Formula / Mechanism | Recommended Scenario |
|---|---|---|
| `"deviance"` (Default) | Binomial likelihood deviance: $-2 \sum \left[ y_i \log \hat{p}_i + (1 - y_i) \log(1 - \hat{p}_i) \right]$ | **Default for bio-pipeline**: Sensitive to predicted class probabilities rather than hard thresholds; smooth gradient for optimization. |
| `"class"` | Misclassification error rate: $\frac{1}{N} \sum \mathbb{I}(y_i \ne \hat{y}_i)$ | Useful for balanced large cohorts, but discontinuous in small cohorts ($N < 40$). |
| `"auc"` | Area under the ROC curve | High clinical relevance, but computationally noisier on small validation folds. |

---

## 4. Practical Implementation Rules

1. **Stratification**: Cross-validation folds must be stratified across phenotype classes to prevent folds with 0 positive cases. `cv.glmnet` handles stratification automatically when `family = "binomial"`.
2. **Standardization**: Feature standardization (`standardize = TRUE`, default in glmnet) ensures that genes with large absolute expression scales do not dominate the $L_1$ penalty.
3. **Collinearity Handling**: If groups of candidate genes have correlation $r > 0.9$, LASSO selects one arbitrary gene from the group and zeros the rest. To retain all members of a correlated pathway, an Elastic Net penalty ($\alpha \in [0.5, 0.9]$) can be substituted:
   $$P_{\alpha}(\boldsymbol{\beta}) = (1 - \alpha)\frac{1}{2}\|\boldsymbol{\beta}\|_2^2 + \alpha \|\boldsymbol{\beta}\|_1$$
4. **Reproducibility**: Always enforce `set.seed(12345)` immediately before `cv.glmnet()` to ensure exact replication of CV fold allocations.
