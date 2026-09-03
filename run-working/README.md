# run-working

Agent 本地运行工作区（run-working）：存放 agent 在为仓库完善 skills 的过程中
产生的临时工作产物（审计、基线、补丁、验证日志等）。**不包含需要长期维护的
正式 spec**——正式 feature 契约仍由仓库根目录的 Spec Kit 结构管理。

当前内容：

- `007-original-sop-speckit/` — original-sop 11 个 skills 的完善工作区：
  - 契约表 `contracts.md`、审查报告 `audit-report.md`、plan/tasks
  - toy-data 基线报告 `toydata-baseline-report.md`
  - 修复补丁脚本 `apply_fixes*.py`、语法检查 `syntax_check_all.R`、
    修复验证 `verify_fixes.ps1`、全链复跑日志 `fixed-run*.log`

> 说明：此处为本机 agent 运行产生的临时工作区，git mv 自原 `specs/` 目录
> （001/002 等本地跑的项目已移除，不上传公开仓库）。
