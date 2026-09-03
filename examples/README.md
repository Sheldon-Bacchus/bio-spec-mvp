# Concrete examples

`examples/` 只保存具体领域的 fixture、示例说明和可选依赖。它们用于对独立
Extension 做 bounded smoke/contract 检查，不属于通用 `research-control`
preset/workflow，也不会被自动加入任何 Spec Kit lifecycle。

当前示例：[`bio-multiqc/`](bio-multiqc/)，包括 MultiQC fixture 和仅在明确
运行该示例时需要的依赖文件。
