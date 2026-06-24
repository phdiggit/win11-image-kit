# Issue #6 主分支最终验证证据记录

本文是关闭 Issue #6 前的最终 validation evidence 记录表。它只记录证据、占位字段和人工判断，不代表 Issue #6 已经关闭；阶段 PR body 继续使用 `Refs #6`，并且本 PR 不自动关闭 #6。

PR body uses `Refs #6`; this PR does not automatically close #6.

## 目的

- 把 #6 收口前需要复核的本地验证、PR Fast CI、main push / workflow_dispatch Full Validate 和人工关闭评论固化为仓库内记录。
- 给维护者保留可复制、可追踪、可人工补全的证据字段。
- 明确当前状态是 `pending-main-full-validate`，直到 main 上 Full Validate 证据被人工填入并复核通过。

## 验证范围

本记录覆盖 #6 当前收口范围：

- `StepResult` 与 `stepSummary` 的 required / optional 阻断语义。
- `package`、`service`、`junction`、`defender`、`appx`、`userExperience` 子域的报告或状态验收语义。
- 顶层 `childReportSummary` 对 missing report、parse failed、required failure、`hasBlockingFailure` 和建议 `exitCode` 的汇总。
- PR Fast CI 与 main / workflow_dispatch Full Validate 的分工。

本记录不覆盖真实 installer、真实 package testCommand、服务变更、Defender/AppX 修改、Junction 创建/删除/迁移、注册表修改、默认应用修改、Explorer/Start/Terminal 用户配置修改、Sysprep、DISM、diskpart、WinPE 生成、NAS 写入或自动重启。

## 本地验证结果

最终关闭 #6 前应能复核以下本地验证命令。若某次收口 PR 只运行了其中一部分，应在 PR body 和最终报告中如实说明。

```powershell
Get-ChildItem -Path tests -Recurse -Filter *.ps1 | ForEach-Object {
  [scriptblock]::Create((Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8)) | Out-Null
}

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-ProjectConfig.ps1

Invoke-Pester -Path tests/pester/Issue6AcceptanceAudit.Tests.ps1
Invoke-Pester -Path tests/pester/Issue6ClosePrep.Tests.ps1
Invoke-Pester -Path tests/pester/DryRunAcceptanceBaseline.Tests.ps1
Invoke-Pester -Path tests/pester/ReportBlockingSummary.Tests.ps1
Invoke-Pester -Path tests/pester/PackageReportLinks.Tests.ps1
Invoke-Pester -Path tests/pester/OrchestratorStepResults.Tests.ps1
Invoke-Pester -Path tests/pester/UserExperienceStateVerification.Tests.ps1
Invoke-Pester -Path tests/pester/DefenderAppxStateVerification.Tests.ps1
Invoke-Pester -Path tests/pester/JunctionStateVerification.Tests.ps1
Invoke-Pester -Path tests/pester/ServiceStateVerification.Tests.ps1
```

本次证据记录 PR 的本地验证结果：

- PowerShell parse: passed on 2026-06-25.
- Project config validation: passed on 2026-06-25.
- Issue6MainValidationEvidence.Tests.ps1: passed on 2026-06-25.
- Related Issue #6 regression Pester: Issue6ClosePrep, Issue6AcceptanceAudit, DryRunAcceptanceBaseline, ReportBlockingSummary, PackageReportLinks, OrchestratorStepResults, UserExperienceStateVerification, DefenderAppxStateVerification, JunctionStateVerification, and ServiceStateVerification passed on 2026-06-25.
- Notes: no real installer, package testCommand, service mutation, Defender/AppX mutation, Junction mutation, registry mutation, Sysprep, DISM, diskpart, WinPE generation, NAS write, or reboot was executed.

## PR Fast CI 证据

- Final PR:
- Head SHA:
- Workflow run:
- Validate result:
- Full Validate on PR: skipped by design; `.github/workflows/ci.yml` keeps Full Validate behind `github.event_name != 'pull_request'`.
- Evidence captured by:

PR Fast CI 只覆盖快速阻断项和目标 Pester。它必须包含 `Issue6AcceptanceAudit.Tests.ps1`、`Issue6ClosePrep.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1`、`ReportBlockingSummary.Tests.ps1`、`PackageReportLinks.Tests.ps1`、`OrchestratorStepResults.Tests.ps1` 和 `Issue6MainValidationEvidence.Tests.ps1`，但不得把完整 `tests/pester` 套件恢复到 PR Fast CI。

## main / workflow_dispatch Full Validate 证据

- Trigger source: main push / workflow_dispatch
- Main SHA:
- Workflow run:
- Full Validate result:
- Evidence captured by:
- Notes:

Full Validate 是人工关闭 #6 前的最终证据来源。若 Codex 或维护者无法访问 GitHub Actions 的 main run，应保留以上占位字段，不得编造 workflow run、SHA 或结果。

## 顶层报告验收证据

关闭 #6 前应确认：

- build 与 postdeploy 顶层报告包含 `StepResult`、`stepSummary` 和 `childReportSummary`。
- `childReportSummary.hasBlockingFailure` 没有隐藏 required failure、missing report 或 parse failed child report。
- 顶层 JSON / Markdown 报告能让维护者看到 `failedRequired`、`failedOptional`、`hasBlockingFailure` 和 `exitCode`。
- `package`、`service`、`junction`、`defender`、`appx`、`userExperience` 的验收文档和 Pester 覆盖已复核。

## 人工关闭 gate

- [ ] 最新 #6 相关阶段 PR 已合并到 `main`。
- [ ] 最终阶段 PR body 使用 `Refs #6`，并明确阶段 PR 不自动关闭 #6。
- [ ] PR Fast CI 在最终 PR head 上成功。
- [ ] `main push` 后的 Full Validate 成功，或人工 `workflow_dispatch` 的 Full Validate 成功。
- [ ] 顶层 `childReportSummary` 不隐藏 required failure、missing report 或 parse failed child report。
- [ ] `exitCode` 证据确认 required failure 不会被报告为成功。
- [ ] 没有 open blocking follow-up PR。

## 可复制关闭评论最终版

```markdown
Issue #6 final validation evidence:

- [ ] Latest #6-related PRs merged to main.
- [ ] PR Fast CI passed on the final PR.
- [ ] Full Validate passed on main push or workflow_dispatch.
- [ ] StepResult, package, service, junction, defender, appx, userExperience, and childReportSummary acceptance docs reviewed.
- [ ] Top-level childReportSummary does not hide any required failure, missing report, or parse failed child report.
- [ ] exitCode evidence confirms required failures are not reported as success.
- [ ] No blocking follow-up PR remains open.

Conclusion: ready for manual closure after every box above is checked.
```

## 当前判断

- Status: pending-main-full-validate
- Recommended next action: merge this PR, wait for main Full Validate or trigger workflow_dispatch, then manually close #6 if all checks pass.

## 非阻断后续事项

- AppX 子报告如需接入 postdeploy 主链路，应另开小任务，并继续禁止真实 AppX mutation 进入普通验证。
- 真实 VM/admin smoke、真实 installer、真实 package testCommand 和真实系统状态变更不属于本收口 PR。
- 若维护者希望把 main Full Validate run id 直接填回本文，可在 Full Validate 成功后通过后续文档 PR 补录证据。
