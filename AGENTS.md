# AGENTS.md

本仓库是个人 Windows 11 金镜像与新机部署工具箱。协作目标是维护一套可重复、可测试、可回滚、定制范围可调整的 Windows 11 基础设施，让镜像还原到新机后只剩尽量少的手工操作。

## 执行优先级

1. 用户本轮明确要求。
2. 本 `AGENTS.md`。
3. `README.md`、`docs/`、`manifests/`、`schemas/` 中与当前任务直接相关的项目约定。
4. 其他默认工具习惯。

如果规则冲突，优先满足更高层规则。只读分析任务保持只读；实现任务在范围清楚后直接做完必要步骤。任务卡或 Issue 已经给出的分支名、范围、验收标准和禁止事项，不要重复询问。

## 任务启动协议

1. 读取根 `AGENTS.md` 和当前 Issue 或任务卡。
2. 检查默认分支、工作区状态、任务范围、禁止范围和验收标准。
3. 按任务路由读取最小必要文件集；发现新依赖时再增量读取。
4. 先盘点调用方、现有行为和相关约定，再实施最小改动。
5. 先运行定向验证，再运行适用的全量或轻量验证。
6. 核对 changed files、禁止范围和工作区状态。
7. 需要交付 PR 时，提交、推送；验证完成后创建非 Draft PR 并保持 ready for review，验证未完成时创建 Draft 或停止并报告，不伪装为 ready。
8. 最终报告只写计划、事实、修改摘要、命令结果和未解决问题；不要输出私有思维过程。

详细生命周期、PR body 清单和最终报告字段见 [Codex 工作流](docs/codex-workflow.md)。

## 最小读取路由

| 任务类型 | 优先读取 |
|---|---|
| 纯文档任务 | 根 `AGENTS.md`、当前 Issue/任务卡、目标文档、与目标文档直接关联的索引文件 |
| Manifest/Schema | 根 `AGENTS.md`、当前 Issue、对应 manifest、对应 schema、validator、直接使用该配置的脚本 |
| 构建任务 | 根 `AGENTS.md`、当前 Issue、scope/paths manifest、build 入口、相关 handler、直接使用的 common 文件 |
| 部署后任务 | 根 `AGENTS.md`、当前 Issue、scope/paths manifest、postdeploy 入口、目标 handler、对应测试 |
| Sysprep/AppX | 根 `AGENTS.md`、当前 Issue、Sysprep 文档、presysprep 入口、AppX/服务 manifest、目标脚本和测试 |
| WinPE | 根 `AGENTS.md`、当前 Issue、WinPE 文档、目标 WinPE 脚本、计划或模拟测试 |
| 测试/CI | 根 `AGENTS.md`、当前 Issue、当前验证入口、目标测试、CI 配置、被测试的最小实现集合 |
| GitHub/PR | 根 `AGENTS.md`、当前 Issue 或 PR、changed files；不默认通读业务文档 |

上下文纪律：

1. 已读取且未变化的文件不重复读取。
2. 优先使用 `rg`、路径过滤、函数定位、章节定位和行区间。
3. 不默认打印完整大文件、完整 manifest、完整日志、完整 diff 或完整 Issue。
4. 只引用和当前结论直接相关的片段。
5. 验证失败时保留复现命令和关键错误，不把完整日志复制进回复。
6. 动态事实从事实源读取，不长期写入根规则。
7. 除非任务明确提供路径或授权，不读取仓库外的用户目录、全局 Codex memory、VSCode 用户配置、浏览器数据或其它项目文件；附件文件和用户粘贴内容视为任务输入。

## 架构原则

1. 选择权放在 manifest，执行逻辑放在脚本。
2. `manifests/customization-scope.json` 是总定制入口，控制系统项、AppX、Defender、火绒、软件、服务和 Junction 等模块。
3. `manifests/paths.json` 是 NAS、安装包、镜像、部署、临时工作区、工具根目录和数据根目录的单一来源。
4. 脚本和 manifest 中需要路径时，优先使用 `${PackageRoot}`、`${ToolRoot}`、`${DataRoot}` 等变量，并通过 `scripts/common/Resolve-KitPath.ps1` 解析。
5. 不要把工具目录、数据目录、NAS 共享等环境路径继续硬编码到新代码中；当前值以 manifest 和实际工作区为准。
6. Git 保存代码、文档、manifest、schema 和轻量说明；NAS 保存安装包、压缩包、WIM/ISO、导出的软件配置、部署日志和报告。
7. 不提交授权文件、账号令牌、私钥、商业软件安装包、破解或绕授权工具。

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

## 危险操作边界

代码变更授权和真实执行授权必须分开判断。

当前 Issue/任务卡明确要求修改危险脚本时，可以编辑源码、写 Mock 测试、运行语法检查、静态检查、`-WhatIf`、临时目录测试和模拟输出测试。不要仅因目标脚本涉及注册表、Defender、服务、AppX、Junction 或 Sysprep 就重复请求代码编辑授权。

以下真实动作仍必须获得用户单独、明确许可，或默认只提供 `-WhatIf`、plan、dry-run 或示例命令：

1. 安装或卸载软件。
2. 启动、停止、删除或注册服务。
3. 修改注册表或 Defender 策略。
4. 卸载或 provision AppX。
5. 移动真实用户目录，创建或删除真实 Junction。
6. 执行 Sysprep、generalize 或其它不可逆系统状态变更。
7. 清盘、分区、格式化或 `diskpart clean`。
8. 捕获或应用真实系统镜像。
9. 对 NAS 进行大规模复制、移动或删除。
10. 删除工作区外文件。

普通验证不得执行真实安装、删除、分区、Sysprep、移动用户目录、修改 Defender、修改注册表、修改 AppX 或服务变更。

## Shell、编码与路径

1. 用户可见文档、脚本注释、日志默认使用中文。
2. schema 字段名、manifest 键名、函数名、参数名、路径变量名保持英文。
3. PowerShell 5.1 遇到中文输出时容易受编码影响；涉及中文日志或注释的 `.ps1` 文件优先保持 UTF-8 BOM。
4. PowerShell 输出中文时，必要时先设置：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
```

5. 自动化目录尽量使用英文、数字、短横线，避免 WinPE、cmd、SMB 和日志编码问题。
6. 当前 shell 能可靠执行时保持当前 shell；`git`、`gh`、`rg`、Python 等优先使用 PATH 中的命令。
7. 需要 PowerShell 专属能力时使用 PowerShell，例如 `.ps1`、Windows 权限、注册表、Defender、AppX、服务管理和 PowerShell 对象管道。
8. Git Bash 只是可选工具；只有在路径实际存在时，才把本机固定 Bash 路径作为 fallback。
9. 避免 PowerShell 与 Bash 多层嵌套引号。多关键词搜索优先用一次 `rg -n "A|B|C" <paths>` 或等价单条简单命令完成。
10. 在 Windows PowerShell 5.1 中不要使用 `&&` 或 `||` 串联命令；需要连续步骤时拆成单条命令，或使用原生 PowerShell 控制流。
11. 中文 PR body、评论正文或其它需要交给 `gh --body-file` 的文本，必须先写入明确的 UTF-8 文件，再用 `--body-file <file>` 读取。
12. 处理中文路径、`git status`、changed files、diff 范围核对时，优先使用 `git -c core.quotepath=false status --short` 和 `git -c core.quotepath=false diff --name-only`。

## 改动方法

1. 修改前先看 `git status --short`，不要覆盖用户已有改动。
2. 先用 `rg` 精确定位旧路径、旧常量、目标函数或目标章节，再小步修改。
3. 新增系统项、应用项、服务、Junction、Defender 排除项时，优先改 manifest 和 schema，再改执行脚本。
4. 大脚本治理要分阶段：先抽公共路径/配置读取，再做编排，再补具体动作。
5. 危险脚本优先实现 `SupportsShouldProcess`、`-WhatIf`、确认提示和清晰日志。
6. 不要为了一个功能顺手重写无关文档、批量格式化全仓库或清理历史文件。

## 验证选择

验证遵循先便宜后昂贵、先定向后全量、先静态后运行。危险 handler 只做 Mock、`-WhatIf` 或临时目录测试；没有代码变化时，不重复运行同一个重型失败命令。

常用入口按任务相关性选择：

```powershell
scripts/validate/Test-ProjectConfig.ps1
scripts/config/Show-CustomizationScope.ps1
scripts/tests/Test-PostDeploy.ps1
```

完整分级验证矩阵、失败分类、停止条件和最小重跑策略见 [Codex 工作流](docs/codex-workflow.md)。

## GitHub、Commit 与 PR

1. 涉及 GitHub 远端读写时，优先使用当前已认证且调用最少的接口；`gh` CLI、GitHub connector 或其它已认证接口都可以，但不要对同一目标重复写入。
2. 退回 connector 时，在最终说明或 PR 说明里写清楚原因。
3. 默认基于仓库默认分支创建 `codex/<short-task>` 分支。
4. 一个任务卡对应一个分支和一个 PR。
5. Commit 必须是原子的，不机械拆分无意义 commit。
6. PR 标题简洁，正文包含 `Closes #<issue>`。
7. 提交前用 `git -c core.quotepath=false diff --name-only` 和 `git ls-files --others --exclude-standard` 核对未提交、未跟踪文件。
8. 提交后才用 `git -c core.quotepath=false diff --name-only origin/<base>...HEAD` 核对 PR 相对基线的 changed files。
9. 创建或更新 PR 后，必须读回标题、正文、base/head 和 Draft 状态；中文正文不得出现编码损坏。
10. 验证完成时创建非 Draft PR，并保持 ready for review；验证未完成时创建 Draft 或停止并报告，不得伪装为 ready。

## 回报结果

完成后说明：

1. 改了哪些文件。
2. 是否触及危险操作；如果没有，明确说没有执行。
3. 运行了哪些验证命令及结果。
4. 工作区中是否存在与本次无关的既有改动。
5. 如创建 PR，说明 base/head、Draft/ready 状态和链接。
