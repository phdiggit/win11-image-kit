# AGENTS.md

本仓库是个人 Windows 11 金镜像与新机部署工具箱。协作目标是维护一套可重复、可测试、可回滚、定制范围可调整的 Windows 11 基础设施，让镜像还原到新机后只剩尽量少的手工操作。

## 执行优先级

1. 用户本轮明确要求。
2. 本 `AGENTS.md`。
3. `README.md`、`docs/`、`manifests/`、`schemas/` 中的项目约定。
4. 其他默认工具习惯。

如果规则冲突，优先满足更高层规则。只读分析任务保持只读；实现任务在范围清楚后直接做完必要步骤。

## GitHub 操作

1. 涉及 GitHub 远端读写时，默认优先使用已认证的 `gh` CLI，例如读取 Issue/PR、读取评论、查看 checks、创建或更新 PR、回复评论、merge、close issue。
2. 只有在 `gh` 不可用、未认证、权限不足或明确无法完成目标动作时，才退回 GitHub connector；退回前先判断是不是只需要重新认证或刷新权限。
3. GitHub 写操作按“先判断、后执行”：先用最少必要读取确认目标，再执行一次写操作。不要为同一目标反复调用不同接口，也不要混用 PR 更新接口和 issue 更新接口。
4. 如果退回 connector，在最终说明或 PR 说明里写清楚原因。

## 快速定位

开始前优先读这些文件，按任务相关性取最小集合：

```text
README.md
docs/07-定制范围与配置入口.md
docs/06-已知问题与决策.md
manifests/customization-scope.json
manifests/paths.json
scripts/config/Show-CustomizationScope.ps1
```

常用入口：

```powershell
scripts/config/Show-CustomizationScope.ps1
scripts/build/Invoke-GoldenImageBuild.ps1
scripts/presysprep/Invoke-PreSysprepCheck.ps1
scripts/postdeploy/Invoke-PostDeploy.ps1
scripts/tests/Test-PostDeploy.ps1
```

## 架构原则

1. 选择权放在 manifest，执行逻辑放在脚本。
2. `manifests/customization-scope.json` 是总定制入口，控制系统项、AppX、Defender、火绒、软件、服务和 Junction 等模块。
3. `manifests/paths.json` 是 NAS、安装包、镜像、部署、临时工作区、工具根目录和数据根目录的单一来源。
4. 脚本和 manifest 中需要路径时，优先使用 `${PackageRoot}`、`${ToolRoot}`、`${DataRoot}` 等变量，并通过 `scripts/common/Resolve-KitPath.ps1` 解析。
5. 不要把 `C:\tools`、`D:\Data`、NAS 共享等路径继续硬编码到新脚本中。
6. 当前真实项目根优先是 `\\192.168.1.37\backups\win11-image-kit`。早期的 `\\192.168.1.37\images`、`\\192.168.1.37\backups\packages` 等旧路径不要作为新代码来源。

## 目录职责

```text
docs/       流程文档、决策、排障说明
manifests/  用户可调整的声明式配置
schemas/    manifest 结构约束
scripts/    构建、封装前检查、WinPE、部署后恢复、测试脚本
configs/    可进入 Git 的配置模板说明
packages/   只放说明和校验信息，不放大型安装包
logs/       只保留 .gitkeep，本地日志不提交
```

NAS 保存大型资产：安装包、压缩包、WIM/ISO、导出的软件配置、部署日志和报告。Git 保存代码、文档、manifest、schema 和轻量说明。

## 安全边界

这些操作必须显式确认，或默认只提供 `-WhatIf` / dry-run / 示例命令：

1. 清盘、分区、格式化、`diskpart clean`。
2. Sysprep、generalize、不可逆系统状态变更。
3. 删除服务、卸载 AppX、移动用户目录、创建 Junction。
4. 修改 Defender 策略、添加大范围排除项。
5. 写入 NAS 大量文件、复制镜像、删除旧资产。

默认不提交也不读取无关敏感内容：

```text
*.wim
*.esd
*.iso
*.vmdk
*.vhd
*.vhdx
*.zip
*.7z
*.rar
*.exe
*.msi
logs/*
secrets/
*.key
*.lic
*.pfx
*.pem
*.ppk
.codex/
```

不要提交授权文件、账号令牌、私钥、商业软件安装包、破解或绕授权工具。

## Shell、编码与路径

1. 用户可见文档、脚本注释、日志默认使用中文。
2. schema 字段名、manifest 键名、函数名、参数名、路径变量名保持英文。
3. PowerShell 5.1 遇到中文输出时容易受编码影响；涉及中文日志或注释的 `.ps1` 文件优先保持 UTF-8 BOM。
4. PowerShell 输出中文时，必要时先设置：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
```

5. 自动化目录尽量使用英文、数字、短横线，避免 WinPE、cmd、SMB 和日志编码问题。
6. Windows 工作区中，仓库内常规命令默认优先使用 Git Bash（`D:\Git\bin\bash.exe`），尤其是 `git`、`gh`、`rg`、`python`、`pytest`、命令串联、重定向和管道操作。
7. 需要 PowerShell 专属能力时使用 PowerShell，例如 `.ps1`、Windows 权限、注册表、Defender、AppX、服务管理和 PowerShell 对象管道。
8. 如果当前已经在 PowerShell 或 Git Bash，并且等价命令简单可靠，就保持当前 shell，不要为了切 shell 绕路。
9. PowerShell + Git Bash 混合环境里不要写复杂嵌套引号命令。多关键词搜索优先用一次 `rg -n "A|B|C" <paths>` 或等价单条简单命令完成。
10. 处理中文路径、`git status`、changed files、diff 范围核对时，优先使用 `git -c core.quotepath=false status --short` 和 `git -c core.quotepath=false diff --name-only`。

## 改动方法

1. 修改前先看 `git status --short`，不要覆盖用户已有改动。
2. 先用 `rg` 精确定位旧路径、旧常量、目标函数，再小步修改。
3. 新增系统项、应用项、服务、Junction、Defender 排除项时，优先改 manifest 和 schema，再改执行脚本。
4. 大脚本治理要分阶段：先抽公共路径/配置读取，再做编排，再补具体动作。
5. 危险脚本优先实现 `SupportsShouldProcess`、`-WhatIf`、确认提示和清晰日志。
6. 不要为了一个功能顺手重写无关文档、批量格式化全仓库或清理历史文件。

## 验证

纯文档改动通常只需检查内容和 `git diff`。涉及 manifest、schema 或脚本时，优先运行对应的轻量验证：

```powershell
scripts/validate/Test-ProjectConfig.ps1

Get-ChildItem -Path manifests,schemas -Recurse -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
}

Get-ChildItem -Path scripts -Recurse -Filter *.ps1 | ForEach-Object {
    [scriptblock]::Create((Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8)) | Out-Null
}

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/config/Show-CustomizationScope.ps1
```

涉及部署后恢复时，再按风险运行相关测试或 `-WhatIf`：

```powershell
scripts/presysprep/Clear-AppxForSysprep.ps1 -WhatIf
scripts/presysprep/Stop-ImageUnsafeServices.ps1 -WhatIf
scripts/tests/Test-PostDeploy.ps1
```

不要在普通验证中执行会真实安装、删除、分区、Sysprep、移动用户目录或修改 Defender 的命令。

## 回报结果

完成后说明：

1. 改了哪些文件。
2. 是否触及危险操作；如果没有，明确说没有执行。
3. 运行了哪些验证命令及结果。
4. 工作区中是否存在与本次无关的既有改动。
