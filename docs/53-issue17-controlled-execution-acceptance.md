# Issue #17 Controlled Execution Acceptance

Status: `accepted-pending-main-validation`

## Acceptance Matrix

| Area | Baseline expectation | Status |
|---|---|---|
| Intake | Issue #17 and Roadmap #19 source are recorded in `docs/52`. | `accepted-pending-main-validation` |
| Scope | This stage is intake plus dry-run / report-only baseline only. | `accepted-pending-main-validation` |
| Authorization | Explicit authorization and simulation are planned only; `-Execute` is blocked. | `accepted-pending-main-validation` |
| Closure candidate | `docs/56` records manual closure candidate scope only. | `ready-for-manual-closure-candidate` |
| Main evidence | `docs/57` is a pending scaffold and does not use PR Fast CI or simulation as a substitute. | `pending-main-validation` |
| PR semantics | PR body must use `Refs #17`, not auto-close keywords. | `accepted-pending-main-validation` |

## Dry-run / WhatIf Coverage

- `manifests/controlled-execution.json` defaults to `dry-run`.
- The baseline manifest keeps `allowTrueExecution=false`.
- `scripts/config/Show-ControlledExecutionPlan.ps1` prints a plan only.
- `scripts/validate/Test-ControlledExecution.ps1` generates report-only evidence and does not invoke action entrypoints.
- The generated report keeps `whatIf=true` and `trueExecution=false`.
- `scripts/winpe/New-WinPEControlledExecutionPlan.ps1` parses future WinPE parameters but returns a blocked report for `-Execute`.

## Preflight Coverage

The first manifest includes report-only preflight placeholders for:

- project configuration
- quality gates
- build lock
- evidence chain readiness
- WinPE controlled execution intake review

These checks are declared as planned inputs only. The runner does not call their entrypoints.

## Report Contract

The report contract records:

- planned actions
- blocked actions
- failed actions
- admin, WinPE, reboot, network, and mutation counts
- risk level and evidence producer metadata
- disabled safety flags for disk, registry, network download, service, profile, and hive mutation

`failedCount > 0` or `blockedActionCount > 0` makes the validator exit 1. Failure fixtures exercise those paths separately from the checked-in baseline.

## Evidence Chain Linkage

The execution plan report is a future evidence-chain producer placeholder. Current mode is only `report-only` / fixture. This stage does not claim real lifecycle evidence or main/workflow evidence for Issue #17. Manual closure review is candidate-only until main/workflow validation evidence is recorded.

## Safety Boundaries

This acceptance scaffold confirms:

- no real build, capture, deploy, WinPE build, or boot media creation
- no DISM, Sysprep, AppX, Defender, Junction, Service, disk, partition, BCD, WinRE, registry, profile, or hive mutation
- no software install, uninstall, upgrade, package lookup, network download, or `Install-Module`
- no local private artifact or `manifests/paths.local.json` in Build Lock
- no Issue #6-#16 close-prep, main-evidence, or completion summary edits
- no automatic Issue #17 closure
- no PR Fast CI substitution for main/workflow evidence
- no simulation substitution for real lifecycle evidence

## Remaining Work

- Design the future explicit WinPE authorization flow.
- Extend the fixture adapters into a fuller execution-set matrix.
- Add real execution authorization only in a later, explicitly approved stage.
- Backfill post-PR main/workflow validation evidence in a later task.
- Promote manual closure readiness only after that evidence exists and is reviewed.

## Related Documents

- [Issue #17 Controlled Execution Intake](52-issue17-controlled-execution-intake.md)
- [Issue #17 Controlled Execution Safety Hardening](54-issue17-controlled-execution-safety-hardening.md)
- [Issue #17 Controlled Execution Authorization and Simulation](55-issue17-controlled-execution-authorization.md)
- [Issue #17 Close Preparation](56-issue17-close-preparation.md)
- [Issue #17 Main Validation Evidence](57-issue17-main-validation-evidence.md)
- [Issue #16 Evidence Chain Acceptance](49-issue16-evidence-chain-acceptance.md)
