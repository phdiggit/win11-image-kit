# Issue #15 Layered Configuration Acceptance

Status: `accepted-ready-for-manual-closure`

## Scope

本阶段在 #75 分层配置基线和 #76 验收硬化之上完成功能验收，并推进到等待 main/workflow evidence 的状态；仍不关闭 Issue #15。范围包括：默认 / profile / hardware / local-private / CLI explicit 的优先级、有效配置来源报告、local missing / malformed 行为、token 与旧路径安全、CI / Quality Gates / Build Lock 接入，以及 Show-CustomizationScope 的 opt-in consumer integration。

## Acceptance Matrix

| Area | Status | Evidence |
|---|---|---|
| Layer priority | `covered` | `EffectiveConfigurationReport.Tests.ps1`, `EffectiveConfigurationCliOverride.Tests.ps1`, `EffectiveConfigurationLocalOverride.Tests.ps1` |
| Merge policy | `covered` | `EffectiveConfigurationMergePolicy.Tests.ps1` |
| Local private override | `covered` | `EffectiveConfigurationLocalOverride.Tests.ps1`, `.gitignore`, `manifests/paths.local.example.json` |
| CLI explicit override | `covered` | `-PathOverrideJson`, `sourceLayer = cli-explicit` |
| Token / path safety | `covered` | `EffectiveConfigurationTokenSafety.Tests.ps1`, `Test-EffectiveConfiguration.ps1` |
| Report contract | `covered` | `pathSources.key/value/redactedValue/sourceLayer`, `failedCount` |
| Consumer integration | `covered` | `Show-CustomizationScope.ps1 -UseEffectiveConfiguration`, `CustomizationScopeEffectiveConfiguration.Tests.ps1` |
| Close readiness | `ready` | `docs/archive/completed-roadmap/issue-15/46-issue15-close-preparation.md` is ready for manual closure only. |
| Main evidence | `ready` | `docs/archive/completed-roadmap/issue-15/47-issue15-main-validation-evidence.md` records post-PR #77 main push Full Validate success; PR Fast CI is not a substitute. |

## Evidence Chain

Evidence now includes the post-PR #77 `main` push Windows CI Full Validate run recorded in `docs/archive/completed-roadmap/issue-15/47-issue15-main-validation-evidence.md`. PR Fast CI runs static JSON / PowerShell parse, project config validation, quality gates validation, effective configuration validation for all stacks, and curated Pester tests. Full Validate remains limited to `main` push / `workflow_dispatch`.

Functional acceptance is complete and main/workflow evidence has been backfilled. This document does not mean Issue #15 is closed; maintainer manual closure remains separate.

## Layer Priority

Priority is deterministic:

```text
repo-default < profile < hardware < local-private < cli-explicit
```

`cli-explicit` is represented by `-PathOverride` or `-PathOverrideJson` and appears in `pathSources.sourceLayer`.

## Merge Policy

- object: `deep-merge`
- array: `replace`
- scalar: `replace`
- null: `remove`

The resolver applies the same merge function to repo, profile, hardware, local, and CLI layers.

## Local Private Override Policy

- Real local override path: `manifests/paths.local.json`
- The real file is ignored by Git and must not be added to Build Lock required entries.
- `manifests/paths.local.example.json` is a safe tracked template and does not contain private NAS, account, token, or machine-specific values.
- `-IncludeLocal` with a missing local file records a warning and keeps `failedCount=0`.
- Malformed local override JSON fails validation.

## CLI Explicit Override Policy

`-PathOverride` accepts a PowerShell hashtable and `-PathOverrideJson` accepts a JSON object of path overrides. They are intended for local command-line use and CI fixture validation. They do not write files and do not mutate system state.

## Token / Path Safety

Validation fails when final effective paths still contain unresolved tokens. This covers unknown tokens and circular token graphs. Validation also fails for forbidden legacy NAS path patterns declared in `manifests/config-layers.json`.

## Report Contract

Effective configuration reports include:

- `reportType = effective-configuration`
- `stackName`
- `appliedLayers`
- `pathSources[]` with `key`, `value`, `redactedValue`, and `sourceLayer`
- `warnings`
- `safety`

CI does not use `-IncludeLocal` and does not upload local override artifacts. `Show-EffectiveConfiguration.ps1 -RedactLocalValues` can hide local-private values in display/report fields by using `redactedValue`.

## CI / Quality Gates / Build Lock

- PR Fast CI runs `Test-EffectiveConfiguration.ps1 -AllStacks`.
- PR Fast CI also runs a CLI override fixture for `air15`.
- Quality Gates keep `effective-configuration` as `report-only`.
- Build Lock covers tracked Issue #15 docs, manifests, schemas, scripts, tests, workflow, README, `.gitignore`, and the local example.

## Consumer Integration

`Show-CustomizationScope.ps1` keeps the existing `pathsManifest` default behavior. `-UseEffectiveConfiguration` is an opt-in migration entrypoint that shows the selected effective stack and source layers before printing the effective path map.

Supported opt-in parameters:

- `-StackName`
- `-IncludeLocal`
- `-PathOverrideJson`

`manifests/customization-scope.json` declares `configLayersManifest` and `defaultStack`, while retaining `pathsManifest` for current consumers.

## Non-goals

- No true build.
- No install / uninstall / upgrade.
- No service, Defender, AppX, Junction, Sysprep, DISM, registry, profile, or hive mutation.
- No network package lookup or download.
- No automatic final closure.
- No completion summary.
- No real VM/admin smoke claim unless explicitly performed later.

## Remaining Work

- Maintainer manually closes Issue #15 after reviewing the ready evidence.
- Decide whether more manifests should consume effective configuration directly.
- Decide whether CLI explicit should support non-path sections after more use.

## Related Documents

- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Issue #15 Close Preparation](46-issue15-close-preparation.md)
- [Issue #15 Main Validation Evidence](47-issue15-main-validation-evidence.md)
- [Quality Gates](40-issue14-quality-gates.md)
- [Build Lock](32-issue12-build-lock.md)
