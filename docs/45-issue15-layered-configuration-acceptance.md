# Issue #15 Layered Configuration Acceptance

Status: `in-acceptance`

## Scope

本阶段在 #75 分层配置基线之上推进验收硬化，但仍不关闭 Issue #15。范围包括：默认 / profile / hardware / local-private / CLI explicit 的优先级、有效配置来源报告、local missing / malformed 行为、token 与旧路径安全、CI / Quality Gates / Build Lock 接入。

## Acceptance Matrix

| Area | Status | Evidence |
|---|---|---|
| Layer priority | `covered` | `EffectiveConfigurationReport.Tests.ps1`, `EffectiveConfigurationCliOverride.Tests.ps1`, `EffectiveConfigurationLocalOverride.Tests.ps1` |
| Merge policy | `covered` | `EffectiveConfigurationMergePolicy.Tests.ps1` |
| Local private override | `covered` | `EffectiveConfigurationLocalOverride.Tests.ps1`, `.gitignore`, `manifests/paths.local.example.json` |
| CLI explicit override | `covered` | `-PathOverrideJson`, `sourceLayer = cli-explicit` |
| Token / path safety | `covered` | `EffectiveConfigurationTokenSafety.Tests.ps1`, `Test-EffectiveConfiguration.ps1` |
| Report contract | `covered` | `pathSources.key/value/redactedValue/sourceLayer`, `failedCount` |
| Close readiness | `not-started` | Close-prep and main evidence are intentionally out of scope. |

## Evidence Chain

Evidence remains local and PR Fast CI only. PR Fast CI runs static JSON / PowerShell parse, project config validation, quality gates validation, effective configuration validation for all stacks, and curated Pester tests. Full Validate remains limited to `main` push / `workflow_dispatch`.

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

## Non-goals

- No true build.
- No install / uninstall / upgrade.
- No service, Defender, AppX, Junction, Sysprep, DISM, registry, profile, or hive mutation.
- No network package lookup or download.
- No close-preparation, main-validation-evidence, or completion summary.

## Remaining Work

- Decide whether more manifests should consume effective configuration directly.
- Decide whether CLI explicit should support non-path sections after more use.
- Prepare close-prep only in a later task after maintainers accept the current evidence.

## Related Documents

- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Quality Gates](40-issue14-quality-gates.md)
- [Build Lock](32-issue12-build-lock.md)
