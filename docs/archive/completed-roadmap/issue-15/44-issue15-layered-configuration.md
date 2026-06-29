# Issue #15 分层配置机制

Status: `accepted-ready-for-manual-closure`

## Source

- GitHub Issue #15: `[P1] 增加 Profile、本机路径和硬件覆盖的分层配置机制`
- Roadmap Issue #19: P1 列表中登记 #15，推荐在 #11 能力注册、#12 Build Lock 之后推进配置分层。
- 当前前提：PR #74 已合并到 `main`；Issue #14 的 quality-gates acceptance、close preparation 和 main validation evidence 均已达到 ready 文档状态。

## Scope

- 建立可解释、可验证的配置分层，让仓库默认值、profile、硬件差异、本机私有覆盖和显式参数有清晰优先级。
- 首批实现只覆盖 `paths` 的有效配置合并和来源报告，保留现有 `manifests/paths.json` 单文件使用方式。
- 新增 `manifests/config-layers.json` 作为层级声明，新增 `profiles/default.json`、`profiles/release.json` 和 `hardware/air15.json` 作为可测试覆盖层。
- 新增 `Show-EffectiveConfiguration.ps1` 与 `Test-EffectiveConfiguration.ps1`，只读取本地 repo 文件并输出报告。
- `manifests/paths.local.json` 被登记为可选本机私有覆盖，并加入 `.gitignore`，不应被 Git 跟踪。
- Phase 2 hardening 增加 `-AllStacks`、`-PathOverrideJson`、local missing / malformed 检查、token / cycle / forbidden path 失败路径，以及 docs/45 acceptance scaffold。

## Non-goals

- 不一次性重写全部 manifest，也不要求现有调用方立即切换到分层配置。
- 不执行真实 Windows image build、部署、安装、服务变更、Junction 迁移、Defender/AppX/Sysprep/DISM 操作。
- 不访问网络、不下载依赖、不调用 signing service。
- 不写 registry、profile 或 hive。
- 不新增 Issue #15 close-preparation、main-validation-evidence 或 completion summary。

## Current Repository Touchpoints

- `manifests/paths.json` 仍是当前兼容默认层。
- `manifests/customization-scope.json` 仍通过 `pathsManifest` 指向单文件路径配置。
- `scripts/common/Resolve-KitPath.ps1` 提供 token 解析能力，本阶段复用它解析有效 `paths`。
- `scripts/config/Show-CustomizationScope.ps1` 是现有配置展示入口，本阶段新增并行的有效配置展示入口。
- `scripts/validate/Test-ProjectConfig.ps1` 是静态项目配置校验入口，本阶段接入 `config-layers.json` schema 校验。
- `docs/archive/completed-roadmap/issue-14/40-issue14-quality-gates.md`、`.github/workflows/ci.yml`、`manifests/build-lock.json` 和 `manifests/quality-gates.json` 是本阶段质量门禁接线点。

## Consumer Integration

Issue #15 now keeps two compatible consumer paths:

- Default compatibility path: existing callers continue to read `manifests/paths.json` through `pathsManifest`.
- Opt-in effective configuration path: `Show-CustomizationScope.ps1 -UseEffectiveConfiguration` resolves a stack from `manifests/config-layers.json` and prints the effective paths plus source layers.

The opt-in consumer entrypoint supports:

- `-StackName`
- `-IncludeLocal`
- `-PathOverrideJson`

`manifests/customization-scope.json` declares `configLayersManifest` and `defaultStack`, while preserving `pathsManifest` for older build, post-deploy, and validation callers. This is migration-compatible and report-only; it does not require all callers to switch to layered configuration in this stage.

## Proposed Implementation Layers

1. Repo default: `manifests/paths.json`，保留当前默认路径意图。
2. Profile: `profiles/default.json` 与 `profiles/release.json`，用确定性深度合并覆盖默认值。
3. Hardware: `hardware/air15.json`，表达硬件差异覆盖。
4. Local private: `manifests/paths.local.json`，仅在显式 `-IncludeLocal` 时参与，且必须保持未跟踪。
5. CLI explicit: `-PathOverride` / `-PathOverrideJson` 提供路径覆盖入口，来源层显示为 `cli-explicit`。

合并策略固定为 object deep-merge、array replace、scalar replace、null remove。首批报告会输出每个有效 path 的最终值和来源层。

Phase 2 后优先级固定为：

```text
repo-default < profile < hardware < local-private < cli-explicit
```

## Safety Boundaries

- Runner / validator 是 static、fixture、report-only。
- 只读取 repo 内声明的 JSON、schema、docs、scripts、tests 和 workflow。
- 不执行真实 build、install、service mutation、network download、signing、registry/profile/hive 写入。
- 有效配置验证会拒绝未解析 token 和已知旧 NAS 路径模式。
- 本机私有覆盖文件不进入 Build Lock，不进入报告样例，不应被 Git 跟踪。
- CI 不启用 `-IncludeLocal`，不上传 local override artifact；需要本地查看私有值时可使用 `-RedactLocalValues` 输出 `redactedValue`。

## Validation Plan

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-ProjectConfig.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/config/Show-CustomizationScope.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/config/Show-CustomizationScope.ps1 -UseEffectiveConfiguration -StackName release`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-EffectiveConfiguration.ps1 -ReportPath "$env:TEMP\effective-config-issue15-baseline.json"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-EffectiveConfiguration.ps1 -AllStacks -ReportPath "$env:TEMP\effective-config-issue15-all.json"`
- `powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\scripts\validate\Test-EffectiveConfiguration.ps1 -StackName air15 -PathOverride @{ ToolRoot = 'D:\tools'; DataRoot = 'D:\data' }"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/config/Show-EffectiveConfiguration.ps1 -StackName release -ReportPath "$env:TEMP\effective-config-release.json"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-QualityGates.ps1 -ReportPath "$env:TEMP\quality-gates-issue15-baseline.json"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-BuildLock.ps1 -ReportPath "$env:TEMP\build-lock-issue15-baseline.json"`
- `Invoke-Pester -Path tests/pester/Issue15*.Tests.ps1`
- `Invoke-Pester -Path tests/pester/EffectiveConfiguration*.Tests.ps1`
- `git diff --check`

## Build Lock / Quality Gates

- Build Lock 覆盖新增 manifest、schema、scripts、tests、docs、workflow、README 和 `.gitignore`。
- Quality Gates 新增 `effective-configuration` gate，模式为 `report-only`，`failedCount=0` 才可接受。
- PR Fast CI 加入 Issue #15 Pester 和有效配置验证入口。
- Full Validate 仍只在 `main` push / `workflow_dispatch` 运行。

## Acceptance Checklist

- [x] 读取并引用真实 Issue #15 与 Roadmap #19 范围。
- [x] 新增 `docs/archive/completed-roadmap/issue-15/44-issue15-layered-configuration.md`，状态为 `in-progress`。
- [x] 新增配置层 manifest/schema 和可解析覆盖示例。
- [x] 新增只读有效配置展示和验证入口。
- [x] 新增 Pester guardrails 覆盖文档、schema、报告、CI、Build Lock、Quality Gates 和安全边界。
- [x] 本机覆盖文件加入 `.gitignore`。
- [x] Phase 2 增加 CLI explicit path override、all stacks validation、local override 行为和 token/path safety 测试。
- [x] Phase 3 增加 Show-CustomizationScope opt-in consumer integration、close-prep candidate 和 main evidence backfill。
- [ ] 后续任务继续接入更多 manifest。

## Related Documents

Issue #15 main/workflow validation evidence has been backfilled in [Issue #15 Main Validation Evidence](47-issue15-main-validation-evidence.md). Maintainer manual closure remains separate from this document status.

- [Roadmap Issue #19](https://github.com/phdiggit/win11-image-kit/issues/19)
- [Issue #15](https://github.com/phdiggit/win11-image-kit/issues/15)
- [定制范围与配置入口](07-定制范围与配置入口.md)
- [Quality Gates](40-issue14-quality-gates.md)
- [Build Lock](32-issue12-build-lock.md)
- [Issue #15 Acceptance](45-issue15-layered-configuration-acceptance.md)
- [Issue #15 Close Preparation](46-issue15-close-preparation.md)
- [Issue #15 Main Validation Evidence](47-issue15-main-validation-evidence.md)
