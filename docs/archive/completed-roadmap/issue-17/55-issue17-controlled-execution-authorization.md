# Issue #17 Controlled Execution Authorization and Simulation

Status: `accepted-ready-for-manual-closure`

## Scope

This stage extends the Issue #17 controlled execution baseline with explicit authorization, dependency-aware execution-set planning, simulated native command results, and a WinPE plan entrypoint.

It remains dry-run / WhatIf / report-only / fixture / simulation / plan-only. No real lifecycle action is performed.

## Authorization Contract

`schemas/controlled-execution-authorization.schema.json` and `scripts/common/Test-KitControlledExecutionAuthorization.ps1` define the current authorization contract.

The checked-in baseline requires:

- `allowTrueExecution=false`
- `trueExecutionAllowed=false`
- matched disk identity
- matched confirmation token
- matched WIM validation
- non-empty `sourceRunId`
- non-stale `sourceRunId`

`-Execute` may appear in a future contract or parser, but this implementation must reject true execution. A matched confirmation token is not sufficient to allow true execution.

## Execution Set Matrix

`manifests/controlled-execution.json` now links the controlled execution stages:

| Stage | Current input | Current behavior |
|---|---|---|
| `preflight` | Project config and authorization fixtures | Plan only |
| `disk-identity` | Disk identity fixture | Plan only |
| `confirmation-token` | Confirmation token fixture | Plan only |
| `wim-validation` | WIM metadata fixture | Plan only |
| `partition-plan` | Native simulation fixture | Plan only |
| `apply-plan` | Native simulation fixture | Plan only |
| `boot-plan` | Native simulation fixture | Plan only |
| `winre-plan` | WinRE fixture | Plan only |
| `native-command-simulation` | Native simulation fixture | Simulated result only |
| `final-report` | Controlled execution report fixture | Report only |

Every action keeps `executed=false`. The runner never invokes action entrypoints.

## WinPE Plan Entrypoint

`scripts/winpe/New-WinPEControlledExecutionPlan.ps1` parses the future WinPE restore parameters and emits JSON.

Supported current-stage parameters include:

- `-WhatIf`
- `-PlanOnly`
- `-TargetDiskNumber`
- `-ExpectedDiskSerial`
- `-ExpectedDiskSize`
- `-ImageSha256`
- `-ImageIndex`
- `-ImageArchitecture`
- `-ConfirmationToken`
- `-SourceRunId`
- `-Execute`

Default behavior is plan-only. If `-Execute` is passed, the report is blocked with the message that true execution is not implemented or enabled in the current Issue #17 stage.

The entrypoint does not query disks, read WIM files, run native commands, or mutate state.

## Simulated Native Command Runner

`scripts/common/Invoke-KitNativeCommandSimulation.ps1` reads fixture JSON and returns a simulated result envelope.

The future native commands for disk layout, image apply, boot setup, and recovery setup may appear only as planned strings or fixture content. They are not executed.

The simulation contract reports:

- simulated command count
- simulated failure count
- simulated stdout/stderr strings
- `simulated=true`
- `executed=false`

## Stage Dependency / Fail-Fast Semantics

Manifest actions can declare `dependsOn`.

If an upstream action is `blocked` or `failed`, downstream actions become `blocked` with reason `blocked by dependency`. Unknown dependencies fail validation. This makes preflight, identity, token, image, partition, apply, boot, recovery, simulation, and final report ordering explicit without executing any step.

## Report Additions

`schemas/controlled-execution-report.schema.json` now includes:

- `authorization`
- `stageResults`
- `simulation`

Summary counts now include authorization failures, execute-request blocks, simulated command failures, downstream blocks, and dependency blocks. Reports retain `whatIf=true` and `trueExecution=false`.

## CI / Quality Gates / Build Lock

PR Fast CI continues to run `scripts/validate/Test-ControlledExecution.ps1` and includes authorization, execution-set, native simulation, WinPE plan, close-prep candidate, and pending main-evidence Pester coverage.

Quality Gates include the new controlled-execution sub-gates. Build Lock covers the touched docs, schemas, scripts, fixtures, tests, workflow, Quality Gates, and README. It does not include `manifests/paths.local.json`, real disk reports, real WIM artifacts, real WinPE logs, or private machine paths.

PR Fast CI is not main/workflow lifecycle evidence. Native command simulation is not real lifecycle evidence. Post-PR #89 main push Full Validate evidence is recorded in `docs/57` for the current planning/simulation stage only.

## Non-goals

- No real disk query.
- No real image read or hash calculation.
- No disk layout, image apply, BCD, or recovery mutation.
- No native command execution.
- No registry, profile, hive, service, AppX, Defender, Junction, Sysprep, install, network, signing, build, capture, deploy, WinPE media, or boot action.
- No automatic Issue #17 closure.
- No Issue #17 completion summary.
- No Issue #6-#16 closure document edits.

## Remaining Work

- Decide the later human authorization and review model for any real execution stage.
- Define how true execution evidence would be collected after separate approval.
- Keep real execution behind a later controlled task with separate human authorization.

## Related Documents

- [Issue #17 Controlled Execution Intake](52-issue17-controlled-execution-intake.md)
- [Issue #17 Controlled Execution Acceptance](53-issue17-controlled-execution-acceptance.md)
- [Issue #17 Controlled Execution Safety Hardening](54-issue17-controlled-execution-safety-hardening.md)
- [Issue #17 Close Preparation](56-issue17-close-preparation.md)
- [Issue #17 Main Validation Evidence](57-issue17-main-validation-evidence.md)
- [WinPE Capture and Restore](03-WinPE捕获与还原.md)
