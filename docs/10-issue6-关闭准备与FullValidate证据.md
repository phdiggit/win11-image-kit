# Issue #6 关闭准备与 Full Validate 证据

## 目的

本文固化人工关闭 Issue #6 前的最后证据采集流程。它不是新的功能验收范围，也不代表 #6 已经关闭；阶段 PR 不自动关闭 #6，阶段 PR body 继续使用 `Refs #6`。

关闭 #6 前必须能从 `main push` 或人工 `workflow_dispatch` 的 `Full Validate` 中取得最终证据。`PR_READY` 模式下，阶段 PR 只默认等待本地必要验证和 PR Fast CI，不默认等待 Full Validate。

## 当前已完成范围

Issue #6 的当前收口范围已经在 `docs/08-结果模型与报告验收.md` 和 `docs/09-issue6-最终验收清单.md` 中记录，核心包括：

- `StepResult` 状态模型和 `stepSummary` 阻断语义。
- `package`、`service`、`junction`、`defender`、`appx`、`userExperience` 等子域状态和报告语义。
- 顶层 `childReportSummary` 对 required / optional 子报告失败、缺失、解析失败的统一汇总。
- `hasBlockingFailure` 和 `exitCode` 在顶层 JSON / Markdown 报告中的人工可读证据。
- PR Fast CI 覆盖快速阻断项，Full Validate 保留为关闭前最终证据来源。

## 必须收集的证据

人工关闭 #6 前至少收集并核对：

- 最新 #6 相关阶段 PR 已合并到 `main`。
- 最终阶段 PR 的 PR Fast CI 成功。
- `main push` 后的 Full Validate 成功，或人工触发 `workflow_dispatch` 的 Full Validate 成功。
- build / postdeploy 顶层报告包含 `StepResult`、`stepSummary` 和 `childReportSummary`。
- `childReportSummary.hasBlockingFailure` 没有隐藏 required failure、missing report 或 parse failed。
- 顶层报告和 Markdown 汇总能看到 required / optional failure、`hasBlockingFailure` 和 `exitCode`。
- `docs/09-issue6-最终验收清单.md` 没有未完成阻断项。
- 没有 open blocking follow-up PR。

## Full Validate 触发方式

Full Validate 是人工关闭前的必要证据来源，触发方式只有：

- 合并到 `main` 后由 `main push` 自动触发。
- 在 GitHub Actions 页面人工触发 `workflow_dispatch`。

PR 上的 `pull_request` 事件只运行 PR Fast CI。PR Fast CI 用于快速发现 parse、配置、lint 和核心 Pester 回归；Full Validate 在 `pull_request` 下保持 skipped / 等价跳过行为，不由阶段 PR 自动等待。

## 人工关闭前 gate

关闭 #6 前逐项确认：

- [ ] 最新相关 PR 已合并到 `main`。
- [ ] 阶段 PR body 使用 `Refs #6`。
- [ ] PR body 未使用 GitHub 自动关闭关键词。
- [ ] PR Fast CI 成功。
- [ ] `main push` 后 Full Validate 成功，或人工 `workflow_dispatch` Full Validate 成功。
- [ ] `docs/09-issue6-最终验收清单.md` 没有未完成阻断项。
- [ ] 顶层 `childReportSummary.hasBlockingFailure` 没隐藏 required failure。
- [ ] 顶层报告能展示 `exitCode`，并且 required failure 不会被当成成功。
- [ ] 没有 open blocking follow-up PR。

关闭准备文档必须明确禁止阶段 PR 使用以下 GitHub 自动关闭关键词：

- `Fixes #6`
- `Closes #6`
- `Resolves #6`

## 可复制关闭评论草案

```markdown
Issue #6 final validation evidence:

- [ ] Latest #6-related PRs are merged to main.
- [ ] PR Fast CI passed on the final PR.
- [ ] Full Validate passed on main push or workflow_dispatch.
- [ ] StepResult, package, service, junction, defender, appx, userExperience, and childReportSummary acceptance docs reviewed.
- [ ] childReportSummary.hasBlockingFailure does not hide any required failure.
- [ ] exitCode evidence confirms required failures are not reported as success.
- [ ] No blocking follow-up PR remains open.

Conclusion: ready for manual closure after all boxes are checked.
```

## 不属于 #6 的后续事项

- 真实 VM/admin smoke。
- 真实 installer 或 package testCommand 执行。
- 真实服务注册、启动、停止或删除。
- 真实 Junction 创建、删除或迁移。
- 真实 Defender / AppX 修改。
- 真实注册表、默认应用、Explorer、Start、Terminal 用户配置修改。
- Sysprep、DISM apply/capture、WinPE 生成、diskpart、NAS 写入或自动重启。

这些事项如需验证，应另开任务，并继续把真实系统变更和普通 PR Fast CI 隔离。
