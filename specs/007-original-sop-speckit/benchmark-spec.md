# Benchmark Specification: Original SOP 全链 Toy-Data 验证 (007)

**Status**: SPEC_DESIGN_FROZEN (2026-09-03, user confirmed)
**Target Feature**: `specs/007-original-sop-speckit`
**Framework Alignment**: 仓库 002 vertical-slice 验收惯例（确定性 fixture + 断言 + verdict JSON）

---

## 一、组件边界

1. **`fixture-spec`** — toy-data：确定性生成，禁止下载真实数据。
2. **`pipeline-oracle`** — 已知注入信号：50 个信号基因的差异方向/幅度为"标准答案"（oracle）。
3. **`verifier-spec`** — 每阶段基于产物（outcome）的自动断言，输出 pass/fail + 指标值。
4. **`report-spec`** — `pipeline_run_report.json` 统一 schema：阶段、指标名、值、阈值、判定、seed、参数、时间戳。

---

## 二、Fixture 设计（`spec-mvp/tests/toydata/`）

### 数据生成（脚本生成，可复现，seed=12345）

- **样本**: 2 组 × 5 样本 = 10 样本（control_1..5, treat_1..5）。
- **基因**: 200 个（g001..g200）。
  - 150 个噪声基因：N(0, 0.4) 随机，两组无差异。
  - 50 个信号基因：treat 组均值 +1.5（log2 尺度），SD 0.4 → 真实差异方向已知。
- **尺度**: log2 表达量（避免 S01 log2 检测分支干扰，但保留数值范围正常）。
- **探针层**（供 S01 用）: 200 探针 p001..p200 映射到 g001..g200（1:1，避免 avereps 影响），另加 20 个"无注释"探针（映射 ---）用于验证 S01 过滤。
- **缺失值**: 随机 2% 缺失（验证 KNN impute 路径）。

### Metadata

| 文件 | 内容 |
|---|---|
| `PD.csv` | sample, group（control/treat 显式，**非样本名推断**） |
| `clinic.csv` | sample, group + 数值表型 `score`（与 group 部分相关, 供 S03 trait 用） |
| `s1.txt` / `s2.txt` | control / treat 样本名（兼容旧接口） |
| `{gse}_platform.txt` | ID, Gene.Symbol 映射表 |
| `{gse}_probe_exprs.txt` | 探针×样本原始矩阵 |

### 已知信号（Oracle）

- DEG: g001..g050 全部显著上调（logFC≈1.5, FDR<0.05）；g051..g200 不显著。
- LASSO/RF 理想恢复: 显著 DEG ∩ 高 MAD 中的信号基因应被选中（允许噪声混入 ≤20%）。
- 联合 ROC oracle: 理论 AUC ≥ 0.97（信号强），OOF 联合 AUC 验收阈值 ≥ 0.85。

---

## 三、Phase 2 基线与 Phase 6 验收断言（Verifier）

| Phase | 阶段 | 断言（gate 必须真实拦截） |
|---|---|---|
| Baseline (原版) | S01–S10 | 记录**真实失败/静默错误点**（如：分组推断静默错标；RF 假 p=0.02 产出"显著"基因；联合 in-sample AUC 虚高）；不要求通过 |
| Fixed (修复后) | S01 | `{gse}.normalize.txt` 无 NA；PD.csv 组标签与 fixture 一致（样本名含 control/treat 前缀也应从 PD.csv 读取而非正则） |
| Fixed | S02 | 交集基因 ≥150；preNorm/norm 文件存在；PCA pdf 非空 |
| Fixed | S03 | 软阈值 R² 记录（≥0.85 或明确 WARN）；module_genes.csv 非空 |
| Fixed | S04 | 找回信号基因 ≥45/50（90%）；diff.txt 无噪声基因误标 ≥10 个的失控 |
| Fixed | S05 | GO/KEGG 输出存在（human 分支；pae 分支验证"明确报错"路径） |
| Fixed | S06 | candidate_hub_genes.txt = WGCNA∩DEG；≥2 |
| Fixed | S07 | LASSO 命中信号基因 ≥25/50（50%）；lambda.min 与 1se 双列表记录；类别平衡报错路径验证 |
| Fixed | S08 | rf_genes 中信号基因占比 ≥50% 且 p 值来自真实置换（无 0.02 假值）；rfPermute 缺失时显式置换路径成功 |
| Fixed | S09 | final_hub_genes = LASSO∩RF（非并集）；空交集人工介入路径验证（构造空交集用例） |
| Fixed | S10 | 单基因 OOF AUC 与联合 OOF AUC 记录；联合 AUC ≥0.85（OOF，非 in-sample）；report 含 OOF 标记 |

### 附加断言

- A1: `--group-file` 缺失时 S01/S02/S04/S07/S08/S10 任一执行 → 非零退出（fail-closed）。
- A2: `pipeline_run_report.json` 含全部阶段指标 + seed/参数 + 判定。
- A3: 修复后脚本在 `--dry-run` 下不产生任何输出文件（编排器验证）。

---

## 四、验收产物

| 产物 | 内容 |
|---|---|
| `toydata-baseline-report.md` | 原版实测失败清单（Phase 2, 用户确认） |
| `toydata-fixed-report.md` | 修复前后对比 + 断言结果（Phase 6, 用户验收） |
| `pipeline_run_report.json` | 机器可读指标（每阶段） |
| `pipeline_gate_report.csv` | gate 记录（兼容编排器） |

## 五、禁止项（Forbidden）

- 禁止用真实 GEO 数据跑验收（网络/不可复现）。
- 禁止 verifier 断言"文件存在"作为唯一条件（必须是科学指标）。
- 禁止修复后在 baseline 失败点上"跳过"或放宽断言来凑通过（修复必须真修）。
