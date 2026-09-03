# Verification-only tests

本目录是独立的验证层，不是 `.specify/` 运行时、`control/` 通用控制源、
`skills/` 可调用 catalog，或任何具体科研项目目录。它只验证被明确保留在
`skills/original-sop/` 的来源组件；来源组件仍然不会因此自动注册为 Skill 或
workflow。

- `smoke_test.py`：检查 11 个来源组件的 `SKILL.md + references/ + scripts/`
  结构、R AST 可解析性和缺失输入的负向门禁。
- `e2e_test.py`：在临时目录中对 source-only orchestrator 做 dry-run；不会把
  日志、报告或运行产物写回仓库。
- `e2e_workspace/`：测试 fixture 和已保留的历史验证证据，不是 generic
  workflow 的默认输入。

运行前可通过 `RSCRIPT` 指定 Rscript 路径；测试脚本默认先从 `PATH` 查找。
