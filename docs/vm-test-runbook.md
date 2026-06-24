# VM 测试 Runbook

本文用于在 Windows 11 VM 中反复运行 validation、build WhatIf、postdeploy WhatIf 和少量经确认的管理员验证时，保留可复盘的日志与报告。它只建立阶段零基线，不定义完整证据链 schema，也不处理 WIM 捕获闭环。

## 1. 适用范围

适用于仓库内脚本的 VM 试跑、失败复盘和日志提交审查：

- `scripts/validate/Test-ProjectConfig.ps1`
- `scripts/build/Invoke-GoldenImageBuild.ps1 -WhatIf`
- `scripts/postdeploy/Invoke-PostDeploy.ps1 -WhatIf`
- 仅在 VM 快照内执行、且本轮明确允许的真实管理员验证

不要在宿主机直接运行会修改系统状态的脚本。真实安装、服务、注册表、Defender、AppX、Junction、Sysprep、DISM、分区和镜像操作必须另行确认。

## 2. 测试前准备

1. 确认当前分支、commit 和工作区状态。
2. 确认 `manifests/paths.json` 和 `manifests/customization-scope.json` 是本轮要测的 profile。
3. 在 VM 中创建快照，并记录快照名称。
4. 确认本轮允许的真实动作；未写入允许列表的动作一律使用 `-WhatIf` 或跳过。
5. 为本次测试创建独立 Run ID 和输出目录。

## 3. VM 快照命名规范

建议用可排序、可关联的名称：

```text
win11-kit-<branch>-<short-commit>-<purpose>-<yyyyMMdd-HHmm>
```

示例：

```text
win11-kit-codex-vm-test-logging-a1b2c3d-postdeploy-whatif-20260624-1430
```

快照备注至少记录分支、commit、manifest profile、测试阶段和是否允许真实管理员动作。

## 4. Run ID 与目录约定

每次 VM 测试使用一个独立 Run ID。建议在仓库根目录中执行：

```powershell
$RunId = Get-Date -Format "yyyyMMdd-HHmmss"
$RunRoot = "C:\Win11ImageKitRuns\$RunId"
New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
New-Item -ItemType Directory -Path "$RunRoot\logs","$RunRoot\reports" -Force | Out-Null
Start-Transcript -Path "$RunRoot\logs\powershell-transcript-$RunId.txt" -Force
```

`C:\Win11ImageKitRuns\<RunId>` 是 VM 内临时测试产物目录，不进入 Git。它不默认写 NAS，NAS 不可用时仍可本地复盘。仓库 `logs/` 目录只保留 `.gitkeep`，不要把 VM 日志复制进去提交。

## 5. 推荐日志 / 报告目录

建议目录结构：

```text
C:\Win11ImageKitRuns\<RunId>\
  logs\
  reports\
  eventlogs\
```

`logs` 放 PowerShell transcript 和脚本日志，`reports` 放 Markdown/JSON/CSV/XML 轻量报告，`eventlogs` 只在明确需要时导出 Application/System 事件日志。

## 6. Validation 测试步骤

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate\Test-ProjectConfig.ps1 `
  -LogPath "$RunRoot\logs\validation.log" `
  -ReportPath "$RunRoot\reports\validation.md"
```

validation 默认不强制访问安装包或 NAS。只有显式传入 `-CheckPackageFiles` 时才会检查安装介质可达性。

## 7. Golden Image Build 测试步骤

优先跑 WhatIf 预演：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\Invoke-GoldenImageBuild.ps1 `
  -WhatIf `
  -LogPath "$RunRoot\logs\golden-build-whatif.log" `
  -ReportPath "$RunRoot\reports\golden-build-whatif.md"
```

真实 build 可能安装软件、写系统配置或准备中间件，只能在 VM 快照内且得到明确许可后执行。执行前记录快照名称、分支、commit、profile 和允许的真实动作。

## 8. PostDeploy 测试步骤

优先跑 WhatIf 预演：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\postdeploy\Invoke-PostDeploy.ps1 `
  -WhatIf `
  -LogPath "$RunRoot\logs\postdeploy-whatif.log" `
  -SummaryReportPath "$RunRoot\reports\postdeploy-summary-whatif.md" `
  -ReportPath "$RunRoot\reports\postdeploy-installer-whatif.json" `
  -UserExperienceReportPath "$RunRoot\reports\postdeploy-user-experience-whatif.json"
```

真实 postdeploy 可能修改 Defender、服务、Junction、用户配置和软件状态。只能在 VM + 快照环境中执行；失败后先保存日志，再回滚快照。

## 9. WhatIf 预演与真实管理员验证区别

`-WhatIf` 只用于确认脚本将要执行的动作、日志路径和报告生成行为。它不证明真实安装、服务注册或系统修改一定成功。

真实管理员验证必须满足：

- 只在 VM 快照环境中执行。
- 执行前记录快照名、分支、commit、profile 和命令。
- 明确本轮允许的真实动作。
- 不在宿主机执行危险脚本。
- 失败后先保存 `$RunRoot`，再回滚快照。

## 10. 失败后如何捞日志

正常完成时：

```powershell
Stop-Transcript
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dev\Collect-KitRunArtifacts.ps1 `
  -RunRoot $RunRoot `
  -DestinationPath "$RunRoot\kit-run-artifacts-$RunId.zip" `
  -Force
```

脚本中途失败时：

```powershell
Stop-Transcript
Get-Content "$RunRoot\logs\powershell-transcript-$RunId.txt" -Tail 50
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dev\Collect-KitRunArtifacts.ps1 `
  -RunRoot $RunRoot `
  -DestinationPath "$RunRoot\kit-run-artifacts-$RunId.zip" `
  -Force
```

VM 卡死或需要回滚时，优先从共享文件夹或挂载虚拟磁盘取出 `$RunRoot`。如果无法取出，记录最后屏幕错误、快照名、执行命令和发生阶段。

## 11. 可选：导出 Windows Event Log

默认不要导出 Windows Event Log。需要排查系统服务、安装器或重启问题时，可在打包前显式启用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dev\Collect-KitRunArtifacts.ps1 `
  -RunRoot $RunRoot `
  -IncludeWindowsEventLogs `
  -Force
```

该选项只导出 Application 和 System 到 `$RunRoot\eventlogs`。事件日志可能包含机器名、服务名、路径和部分环境信息，提交审查前先确认内容可分享。

## 12. 日志脱敏与禁止收集内容

禁止收集或提交：

```text
*.wim
*.esd
*.iso
*.vhd
*.vhdx
*.zip 中包含安装包或镜像的大包
*.exe
*.msi
*.lic
*.key
*.pfx
*.pem
*.ppk
secrets/**
真实账号令牌
网络凭据
浏览器数据
个人文档
商业软件安装包
破解或绕授权工具
```

如需证明安装包存在，只记录路径摘要、文件名、大小、SHA256、是否可访问和错误信息，不收集安装包本体。

## 13. 提交给 ChatGPT / Codex 审查时需要提供什么

提供以下信息即可：

- Run ID、快照名、分支、commit 和 manifest profile。
- 执行过的命令，标明 WhatIf 或真实管理员验证。
- `Collect-KitRunArtifacts.ps1` 生成的 zip。
- 失败命令的最后 50 行关键输出。
- 本轮允许的真实动作列表。

不要粘贴完整大型日志；先提供摘要和归档包清单，再按需要补充片段。

## 14. 常见问题

如果没有生成日志文件，先确认命令是否显式传入 `-LogPath`，或 manifest 中对应 `reporting.*.enabled` 是否开启。

如果报告路径写入失败，优先使用 `$RunRoot\reports` 这样的 VM 本地目录，不要把首次排障绑定到 NAS。

如果 zip 中没有某个文件，检查扩展名是否在默认允许列表 `.log`、`.json`、`.md`、`.txt`、`.csv`、`.xml` 内，或是否位于 `logs`、`reports`、RunRoot 根目录轻量文件中。

如果 zip 中不应出现的文件被列入，请停止提交，把 `artifact-manifest.json` 中的相对路径和原因贴给 Codex 修正规则。
