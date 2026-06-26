# Issue #15 分层配置机制

Status: `in-progress`

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
- `docs/40-issue14-quality-gates.md`、`.github/workflows/ci.yml`、`manifests/build-lock.json` 和 `manifests/quality-gates.json` 是本阶段质量门禁接线点。

## Proposed Implementation Layers

1. Repo default: `manifests/paths.json`，保留当前默认路径意图。
2. Profile: `profiles/default.json` 与 `profiles/release.json`，用确定性深度合并覆盖默认值。
3. Hardware: `hardware/air15.json`，表达硬件差异覆盖。
4. Local private: `manifests/paths.local.json`，仅在显式 `-IncludeLocal` 时参与，且必须保持未跟踪。
5. CLI explicit: 本阶段只在文档中保留优先级位置，后续任务再接入具体命令行覆盖。

合并策略固定为 object deep-merge、array replace、scalar replace、null remove。首批报告会输出每个有效 path 的最终值和来源层。

## Safety Boundaries

- Runner / validator 是 static、fixture、report-only。
- 只读取 repo 内声明的 JSON、schema、docs、scripts、tests 和 workflow。
- 不执行真实 build、install、service mutation、network download、signing、registry/profile/hive 写入。
- 有效配置验证会拒绝未解析 token 和已知旧 NAS 路径模式。
- 本机私有覆盖文件不进入 Build Lock，不进入报告样例，不应被 Git 跟踪。

## Validation Plan

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-ProjectConfig.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-EffectiveConfiguration.ps1 -ReportPath "$env:TEMP\effective-config-issue15-baseline.json"`
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
- [x] 新增 `docs/44-issue15-layered-configuration.md`，状态为 `in-progress`。
- [x] 新增配置层 manifest/schema 和可解析覆盖示例。
- [x] 新增只读有效配置展示和验证入口。
- [x] 新增 Pester guardrails 覆盖文档、schema、报告、CI、Build Lock、Quality Gates 和安全边界。
- [x] 本机覆盖文件加入 `.gitignore`。
- [ ] 后续任务继续接入更多 manifest 与 CLI explicit override。

## Related Documents

- [Roadmap Issue #19](https://github.com/phdiggit/win11-image-kit/issues/19)
- [Issue #15](https://github.com/phdiggit/win11-image-kit/issues/15)
- [定制范围与配置入口](07-定制范围与配置入口.md)
- [Quality Gates](40-issue14-quality-gates.md)
- [Build Lock](32-issue12-build-lock.md)
