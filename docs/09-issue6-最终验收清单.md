# Issue #6 最终验收清单

本文是 #6 “统一步骤结果模型与失败策略，消除构建和部署假成功”的最终收口审计清单。它用于帮助人工判断是否可以关闭 #6；阶段性 PR 仍统一使用 `Refs #6`，本清单本身不自动关闭 #6。

## 审计矩阵

| 领域 | 当前覆盖 | 测试/验收锚点 | 收口结论 |
|---|---|---|---|
| StepResult | `New-KitStepResult` 定义 `changed`、`unchanged`、`skipped`、`manual`、`whatif`、`failed`；`whatif` 固定 `changed = false`；`manual` 和 `skipped` 不伪装为成功。 | `New-StepResult.Tests.ps1`、`OrchestratorStepResults.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| required / optional failure | `stepSummary` 和 `childReportSummary` 分别汇总 `failedRequiredCount` / `failedOptionalCount` 与 `failedRequired` / `failedOptional`；required failure、missing report、parse failed 会让 `hasBlockingFailure = true`、`exitCode = 1`；optional failure 默认不阻断。 | `New-StepResult.Tests.ps1`、`ReportBlockingSummary.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| package | archive / installer 都输出 `packageResults` 和 `packageSummary`；hash mismatch、installer exit code、`rebootRequired`、`failurePolicy`、`testCommand` 都进入结果模型；顶层 build/postdeploy 只链接 compact `packageReports`。 | `SoftwarePackageResults.Tests.ps1`、`SoftwarePackageTestCommand.Tests.ps1`、`SoftwareFailurePolicyRuntime.Tests.ps1`、`PackageReportLinks.Tests.ps1` | 已覆盖。 |
| service | 服务状态验证记录 `expectedState`、`expectedStartType`、`required`、`failurePolicy`；missing、mismatch、query exception 不伪装成功；`WhatIf` 只记录未查询状态。 | `ServiceStateVerification.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| junction | Junction 状态验证区分 missing、not-junction、target mismatch；支持 required / optional / `failurePolicy`；`WhatIf` 不创建、删除或迁移，也不伪装成功。 | `JunctionStateVerification.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| defender | Defender 状态验证区分 mismatch、setting missing、query failed、not run；missing setting 不会把 `$null` 误判为 `$false`；`WhatIf` 不查询、不修改真实 Defender。 | `DefenderAppxStateVerification.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| appx | AppX 状态验证覆盖 expected present/absent、query failed、failure policy 和 `WhatIf`；AppX 保持独立审计入口，不在本阶段改 presysprep 或真实 AppX mutation。 | `DefenderAppxStateVerification.Tests.ps1` | 独立验证已覆盖；顶层 postdeploy `byType.appx` 可保持空计数，后续如需接入主链路应另开任务。 |
| userExperience | legacy report status 与 `stateChecks.expectedValue` 对齐；`restored`、skipped、missing、whatif 语义清楚；输出 `userExperienceResults` / `userExperienceSummary`，顶层 postdeploy 链接 compact `userExperienceReports`。 | `UserExperienceStateVerification.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| top-level report | build 与 postdeploy 顶层报告都有 `stepSummary` 和 `childReportSummary`；child references 不内嵌完整 `*Results`；Markdown 报告输出子报告总数、缺失、required/optional failure、阻断和建议 `exitCode`。 | `PackageReportLinks.Tests.ps1`、`ReportBlockingSummary.Tests.ps1`、`DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| dry-run acceptance | build/postdeploy `-WhatIf` 使用临时 manifest/report fixture 验证，不执行真实 installer、服务、Junction、Defender、AppX、用户配置、Sysprep、DISM、WinPE 或 NAS 写入。 | `DryRunAcceptanceBaseline.Tests.ps1` | 已覆盖。 |
| CI / workflow | PR Fast CI 只跑快速阻断项和目标 Pester；`Full Validate` 保留在 `main` push / `workflow_dispatch`；`PR_READY` 表示本地必要验证完成、ready PR 创建后不默认等待 Full Validate。 | `.github/workflows/ci.yml`、`docs/codex-workflow.md`、`docs/codex-task-card-template.md` | 已覆盖。 |

## 人工关闭 #6 前检查

本节是人工关闭前的 manual closure gate。

- 最新阶段 PR 已合并到 `main`。
- 阶段 PR body 使用 `Refs #6`，没有使用 `Fixes #6`、`Closes #6` 或 `Resolves #6`。
- PR Fast CI 在最新 head 上成功。
- `main` push 后的 `Full Validate` 成功，或人工触发 `workflow_dispatch` 的 `Full Validate` 成功。
- 本文没有未完成的 #6 阻断项。
- build 和 postdeploy 顶层 `childReportSummary` 不隐藏 required failure、missing report 或 parse failed。
- Markdown 报告能让人工直接看到 `failedRequired`、`failedOptional`、`hasBlockingFailure` 和 `exitCode`。

## 非 #6 范围 / 后续优化

- AppX 状态验证当前由独立入口和 Pester 覆盖；postdeploy 顶层 `childReportSummary.byType.appx` 暂可为空。若要把 AppX 子报告接入 postdeploy 主链路，应另开小任务，并继续禁止真实 AppX mutation 进入普通验证。
- 真实 VM/admin smoke、真实 installer、真实服务注册、真实 Junction 迁移、真实 Defender/AppX 修改、Sysprep、DISM、diskpart、WinPE 生成和 NAS 写入都不属于本收口 PR。
- `Full Validate` 是关闭 #6 前的人工核验条件，不由阶段 PR 自动替代。

## 建议结论

本地审计未发现新的 #6 阻断缺口。建议在本 PR 合并、PR Fast CI 成功、`main` 上 Full Validate 成功后，进入人工关闭 #6 / final validation；在这些条件满足前不要关闭 #6。
