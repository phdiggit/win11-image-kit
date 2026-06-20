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
5. 在金镜像 VM 中执行 `scripts/build`
6. Sysprep 前执行 `scripts/presysprep/Invoke-PreSysprepCheck.ps1`
7. 在 WinPE 中执行 `scripts/winpe`
8. 新机进入桌面后执行 `scripts/postdeploy/Invoke-PostDeploy.ps1`
9. 执行 `scripts/tests/Test-PostDeploy.ps1` 验证
10. 遇到封装/还原异常时，记录到 [已知问题与决策](docs/06-已知问题与决策.md)

常规配置验证：

```powershell
scripts/validate/Test-ProjectConfig.ps1
```

## 安全约定

- 不提交授权文件、账号令牌、私钥、商业软件安装包。
- 不把大型镜像、压缩包、日志提交到 Git。
- 任何会清盘、Sysprep、删除服务的脚本都必须显式确认。
- 自动化目录尽量使用英文、数字、短横线，避免 WinPE/cmd/SMB/日志编码问题。
