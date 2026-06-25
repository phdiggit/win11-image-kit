# Issue #8 Defender 排除项最小权限策略

Defender exclusion 会直接减少扫描覆盖面，因此本项目只允许由 `manifests/defender-exclusions.json` 显式声明的排除项进入部署后流程。默认目标是解决 kit 管理目录和少数可信便携工具的误报或重复扫描问题，而不是降低 Windows Defender 的全局保护级别。

本文说明 Issue #8 的策略边界和执行语义；验收矩阵、CI 守卫和维护者手动关闭前检查清单见 [Issue #8 Defender Exclusion Acceptance](17-issue8-defender-exclusion-acceptance.md)。

## 支持类型

- `path`：只允许位于 kit 管理路径下的窄子目录，例如 `${WorkRoot}\cache`、`${DeployRoot}\reports`。
- `process`：只允许明确的可执行文件路径，例如 `${ToolRoot}\vscode-portable\Code.exe`。

首轮不支持 `extension`。扩展名排除太容易扩大扫描豁免面，schema 和 policy 都会拒绝。

## 必填字段

每个 `exclusions[]` 条目必须声明：

- `id`
- `type`
- `value`
- `scope`
- `reason`
- `required`
- `failurePolicy`

`required` 默认不应设为 `true`。只有明确会阻断部署流程的必要项，才应同时使用 `required=true` 和 `failurePolicy=fail`。

## 阻断范围

policy preflight 会阻断宽泛路径和通用进程，包括：

- 盘根，例如 `C:\`、`D:\`
- Windows、System32、Program Files、Users、用户 profile、Desktop、Downloads
- 通配符路径、相对路径逃逸、UNC share 根
- `powershell.exe`、`pwsh.exe`、`cmd.exe`、`msiexec.exe`、`setup.exe`、`python.exe`、`node.exe` 等通用进程
- `extension` 类型

符号链接或 reparse point 目标不明确时会进入人工处理，避免自动扩大信任边界。

## WhatIf 和报告

`scripts/postdeploy/Set-DefenderExclusions.ps1 -WhatIf` 只输出计划和 JSON 报告，不调用真实 `Add-MpPreference`。报告会记录每个条目的 `policyStatus`、`action`、`existsBefore`、`existsAfter`、`manualAction` 和 summary 计数。

PR Fast CI 只运行 schema、policy、seam 和 `-WhatIf`/mock 测试，不执行真实 Defender mutation。真实 VM/admin smoke 如需要，应另行在快照环境中手工执行并保存报告。
