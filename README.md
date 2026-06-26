# win11-image-kit

个人 Windows 11 金镜像与新机部署工具箱。

最终目标是定制 Windows 系统镜像，让镜像还原到新机后只需要做最少的手工操作。目标不是做一次性的系统镜像，而是维护一套可重复、可测试、可回滚、定制范围可随时调整的 Windows 11 基础设施：

- 在 VMware Win11 虚拟机中构建金镜像
- 用 Sysprep + DISM 捕获通用镜像
- 通过 WinPE 将镜像还原到新机器
- 用部署后脚本恢复个性化系统配置、开发环境和服务
- 通过 manifest 交互式调整系统项、应用项、AppX 清理、Defender/火绒策略和工作目录
- 让新机还原后的人工操作尽量只剩账号登录、授权激活和硬件相关确认

## 分层原则

| 层级 | 放在哪里 | 例子 |
|---|---|---|
| 镜像内固化 | 金镜像 VM | Windows 更新、VC++、字体、C:\tools、开发工具主体、系统级 PATH、右键菜单 |
| 部署后自动恢复 | scripts/postdeploy | D 盘重定向、服务注册、Terminal/VSCode 配置、默认应用、开始菜单 |
| 人工确认 | checklist | 微信/QQ/网盘登录、Tailscale 认证、JetBrains/Navicat/IDM 激活 |

## 仓库结构

```text
docs/                 流程文档和规划
manifests/            软件、服务、目录重定向等声明式配置
scripts/              构建、封装前检查、WinPE、部署后恢复、测试脚本
configs/              可版本化的软件/系统配置模板
packages/             仅放说明和校验和，不提交大型安装包
logs/                 仅保留 .gitkeep，本地日志不提交
```

## 快速入口

1. 阅读 [NAS 目录规划](docs/00-NAS目录规划.md)
2. 阅读 [定制范围与配置入口](docs/07-定制范围与配置入口.md)
3. 先改 `manifests/paths.json` 和 `manifests/customization-scope.json`
4. 执行 `scripts/config/Show-CustomizationScope.ps1` 检查当前定制范围
5. 在金镜像 VM 中执行 `scripts/build/Invoke-GoldenImageBuild.ps1`
6. Sysprep 前执行 `scripts/presysprep/Invoke-PreSysprepCheck.ps1`
7. 在 WinPE 中执行 `scripts/winpe`
8. 新机进入桌面后执行 `scripts/postdeploy/Invoke-PostDeploy.ps1`
9. 执行 `scripts/tests/Test-PostDeploy.ps1` 验证
10. VM 内反复测试时，先阅读 [VM 测试 Runbook](docs/vm-test-runbook.md)，并用 `scripts/dev/Collect-KitRunArtifacts.ps1` 打包日志和报告
11. 遇到封装/还原异常时，记录到 [已知问题与决策](docs/06-已知问题与决策.md)
12. Issue #6 已由维护者人工关闭；收口范围和证据链见 [Issue #6 Completion Summary](docs/12-issue6-completion-summary.md)
13. Issue #7 Junction 事务迁移收口验收见 [Issue #7 Junction Transaction Acceptance](docs/13-issue7-junction-transaction-acceptance.md)
14. Issue #7 Junction 事务迁移人工关闭准备见 [Issue #7 Close Preparation](docs/14-issue7-close-preparation.md)
15. Issue #7 main 验证证据见 [Issue #7 Main Validation Evidence](docs/15-issue7-main-validation-evidence.md)
16. Defender 排除项最小权限策略见 [Issue #8 Defender Exclusion Policy](docs/16-issue8-defender-exclusion-policy.md)
17. Issue #8 Defender 排除项验收矩阵与关闭前检查清单见 [Issue #8 Defender Exclusion Acceptance](docs/17-issue8-defender-exclusion-acceptance.md)
18. Issue #8 Defender 排除项关闭准备与 main 验证证据见 [Issue #8 Close Preparation](docs/18-issue8-close-preparation.md) 和 [Issue #8 Main Validation Evidence](docs/19-issue8-main-validation-evidence.md)
19. Issue #9 Sysprep AppX 前置门禁、验收与关闭准备见 [Gate](docs/20-issue9-sysprep-appx-gate.md)、[Acceptance](docs/21-issue9-sysprep-appx-acceptance.md)、[Close Preparation](docs/22-issue9-close-preparation.md) 和 [Main Validation Evidence](docs/23-issue9-main-validation-evidence.md)
20. Issue #10 machine/default-user/current-user 上下文拆分见 [Context Scope Split](docs/24-issue10-context-scope-split.md)
21. Issue #10 Context Scope 验收、人工关闭准备与 main 验证证据见 [Acceptance](docs/25-issue10-context-scope-acceptance.md)、[Close Preparation](docs/26-issue10-close-preparation.md) 和 [Main Validation Evidence](docs/27-issue10-main-validation-evidence.md)
22. Issue #11 manifest capability registry 与实现一致性校验见 [Capability Registry](docs/28-issue11-capability-registry.md)，验收、关闭准备和 main 验证证据见 [Acceptance](docs/29-issue11-capability-registry-acceptance.md)、[Close Preparation](docs/30-issue11-close-preparation.md)、[Main Validation Evidence](docs/31-issue11-main-validation-evidence.md)
23. Issue #12 immutable build lock 与供应链输入一致性校验见 [Build Lock](docs/32-issue12-build-lock.md)
24. Issue #12 Immutable Build Lock 能力、验收与关闭准备见 [Acceptance](docs/33-issue12-build-lock-acceptance.md)、[Close Preparation](docs/34-issue12-close-preparation.md)、[Main Validation Evidence](docs/35-issue12-main-validation-evidence.md)
25. Issue #13 software/service Ensure-State 收敛模型与静态验证见 [Ensure-State](docs/36-issue13-ensure-state.md)

常规配置验证：

```powershell
scripts/validate/Test-ProjectConfig.ps1
scripts/tests/Test-PostDeploy.ps1 -SkipCommandTests -SkipServiceStatus
```

按需归档日志和轻量报告时：

```powershell
scripts/build/Invoke-GoldenImageBuild.ps1 `
  -LogPath .\logs\golden-image-build.log `
  -ReportPath .\logs\golden-image-build.md

scripts/postdeploy/Invoke-PostDeploy.ps1 `
  -LogPath .\logs\postdeploy.log `
  -SummaryReportPath .\logs\postdeploy-summary.md

scripts/validate/Test-ProjectConfig.ps1 `
  -LogPath .\logs\project-config.log `
  -ReportPath .\logs\project-config.md
```

如需统一归档到 `${DeployRoot}`，可在 `manifests/customization-scope.json` 的 `reporting` 段按模块启用；默认关闭，因此普通验证不会强制写 NAS。

## 本地验证 / CI 等价命令

首次运行 Pester 或 PSScriptAnalyzer 时，先在当前用户范围安装模块：

```powershell
Install-Module Pester -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
```

本地执行与 CI 对应的轻量验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-ProjectConfig.ps1
Invoke-ScriptAnalyzer -Path scripts -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path tests/pester
```

这些命令只做 JSON/PowerShell 解析、项目配置校验、静态检查和 Pester 单元测试；不会安装软件、修改服务、注册表、Defender、AppX、Junction、Sysprep、分区、WinPE 或写入 NAS。

## Codex/Agent 协作

- 仓库协作规则见 [AGENTS.md](AGENTS.md)。
- 详细本地任务流程、验证矩阵、失败分类和 PR 清单见 [Codex 工作流](docs/codex-workflow.md)。
- 编写后续任务卡时使用 [Codex 任务卡模板](docs/codex-task-card-template.md)。
- Roadmap 入口为 GitHub Issue #19；当前任务卡以对应 Issue 或用户提供的任务卡为准。

## 安全约定

- 不提交授权文件、账号令牌、私钥、商业软件安装包。
- 不把大型镜像、压缩包、日志提交到 Git。
- 任何会清盘、Sysprep、删除服务的脚本都必须显式确认。
- 自动化目录尽量使用英文、数字、短横线，避免 WinPE/cmd/SMB/日志编码问题。
