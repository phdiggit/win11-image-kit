# Issue #9 Sysprep AppX 前置门禁

Sysprep 前需要确认 AppX 状态，因为某些包如果只安装在用户侧、但没有 provisioned 到系统镜像，或者 provisioned 与 all-users 安装状态不一致，可能在 generalize 阶段触发失败。这个门禁只做审计、阻断判断和报告，不自动删除 AppX，也不修改真实用户 profile。

## 运行方式

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-SysprepReadiness.ps1 -WhatIf -ReportPath reports/sysprep-appx-readiness.json
```

默认读取 `manifests/sysprep-appx-gate.json`，查询 provisioned AppX 与 all-users AppX，生成 `sysprep-appx-readiness` JSON 报告。PR Fast CI 使用 fixture/Pester 覆盖，不依赖真实机器 AppX 状态，也不要求管理员权限。

## 报告状态

- `failed`：存在 blocking findings，例如 user-installed but not provisioned、provisioned/installed mismatch，或 AppX 查询失败且 policy 要求阻断。
- `manual`：policy 明确要求人工复核，或 `failurePolicy=manual` 将阻断项降为人工处理。
- `passed`：没有阻断或人工 findings。
- `skipped`：policy 明确跳过相关阻断。

## 处理边界

发现 blocking findings 后，先读取 JSON report 中的 `findings`、`queryErrors` 和 `recommendedActions`。真实修复应在 VM snapshot 环境中人工处理并复核；不要在 PR Fast CI 中修复真实系统，不要运行 Sysprep，不要执行 `Remove-AppxPackage`、`Remove-AppxProvisionedPackage` 或 DISM remove。

后续如果需要真实 VM/admin smoke 或具体修复 runbook，应作为单独任务处理。

## 收口与证据链

- [Issue #9 验收矩阵](21-issue9-sysprep-appx-acceptance.md)
- [Issue #9 关闭准备](22-issue9-close-preparation.md)
- [Issue #9 main 验证证据](23-issue9-main-validation-evidence.md)
