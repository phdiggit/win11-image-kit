# Issue #13 Ensure-State 收敛模型

## 目标

Issue #13 为 `software.json` 和 `services.json` 建立统一的 Ensure-State 收敛层，用来表达目标状态、承载 fixture/mock 当前状态、生成收敛计划，并输出可序列化的 JSON 报告。

这套能力当前只覆盖静态、fixture、report-only 路径：

- 不安装、卸载或升级软件。
- 不启动、停止、禁用或删除真实服务。
- 不访问网络。
- 不写注册表、profile 或 hive。
- 不执行真实镜像构建。

后续如果要把计划真正落到机器上，必须另开新的 task 或 issue，不在 Issue #13 的 PR Fast CI 中推进。

## Manifest 字段

`manifests/software.json` 顶层包含 `manifestVersion` 和 `software`。每个软件条目使用以下字段：

- `id`：稳定标识。
- `displayName`：报告展示名。
- `ensure`：目标状态，支持 `present`、`absent`、`latest`、`pinned`、`manual`。
- `source`：来源类型，支持 `winget`、`chocolatey`、`msi`、`powershell`、`manual`、`none`。
- `packageId`：包标识或逻辑标识。
- `version`：可选版本，`pinned` 场景建议显式给出。
- `scope`：作用域，支持 `machine`、`current-user`、`default-user`、`none`。
- `installMode`：执行模式，支持 `planned`、`manual`、`disabled`。
- `priority`：排序优先级。
- `tags`：可选标签。
- `notes`：中文说明。

`manifests/services.json` 顶层包含 `manifestVersion` 和 `services`。每个服务条目使用以下字段：

- `name`：服务名。
- `displayName`：报告展示名。
- `ensure`：目标状态，支持 `running`、`stopped`、`disabled`、`manual`、`absent`、`ignore`。
- `startupType`：目标启动类型，支持 `automatic`、`manual`、`disabled`、`unchanged`。
- `scope`：作用域，当前支持 `machine`、`none`。
- `changeMode`：执行模式，支持 `planned`、`manual`、`disabled`。
- `priority`：排序优先级。
- `reason`：变更原因。
- `notes`：中文说明。

## Plan 与 Report

Ensure-State 流程分成四层：

1. `Resolve-KitSoftwareState.ps1` / `Resolve-KitServiceState.ps1`
   - 只解析 manifest 项和 fixture/current 对象。
   - 未提供当前状态时返回 `unknown` 或 `manual`，不会伪装成成功。
2. `New-KitEnsureStatePlan.ps1`
   - 输出收敛计划，不执行动作。
   - 把 software/service 的 planned、manual、disabled 意图统一放进 `actions`。
3. `Test-KitEnsureState.ps1`
   - 把单项结果归一成 `passed`、`manual`、`failed`。
4. `New-KitEnsureStateReport.ps1`
   - 汇总总状态和 planned action 计数，输出稳定 JSON 报告。

状态含义：

- `passed`：目标状态和 fixture/current 状态一致。
- `manual`：存在漂移、未知当前状态、manual/disabled 模式或需要人工版本确认。
- `failed`：缺少关键字段或结果中存在明确错误。

## 运行方式

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-EnsureState.ps1 -ReportPath reports/ensure-state.json
```

这个入口会读取 `manifests/software.json` 和 `manifests/services.json`，生成 ensure-state plan/report，并把 JSON 显式写到 `-ReportPath`。

## 与 Capability Registry / Build Lock 的关系

- `manifests/capability-registry.json` 记录了 `ensure-state-convergence` capability，用于声明 Issue #13 的实现入口、测试和文档。
- `manifests/build-lock.json` 把 Ensure-State 的 manifest、schema、脚本、测试、文档和 CI 接线纳入可信输入或 watch 范围，避免静默漂移。

## PR Fast CI 边界

PR Fast CI 只做 static、fixture、report-only 验证：

- no install/uninstall/upgrade
- no service mutation
- no network
- no registry/profile/hive writes
- no real build

这保证 Issue #13 的 CI 证明是静态收敛能力的证据，而不是机器变更证据。
