# Issue #17 Controlled Execution Acceptance

Status: `in-acceptance`

## Acceptance Matrix

| Area | Baseline expectation | Status |
|---|---|---|
| Intake | Issue #17 and Roadmap #19 source are recorded in `docs/52`. | `in-acceptance` |
| Scope | This stage is intake plus dry-run / report-only baseline only. | `in-acceptance` |
| Closure | No close-prep, main-evidence, or completion summary is generated. | `in-acceptance` |
| PR semantics | PR body must use `Refs #17`, not auto-close keywords. | `in-acceptance` |

## Dry-run / WhatIf Coverage

- `manifests/controlled-execution.json` defaults to `dry-run`.
- The baseline manifest keeps `allowTrueExecution=false`.
- `scripts/config/Show-ControlledExecutionPlan.ps1` prints a plan only.
- `scripts/validate/Test-ControlledExecution.ps1` generates report-only evidence and does not invoke action entrypoints.
- The generated report keeps `whatIf=true` and `trueExecution=false`.

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

The execution plan report is a future evidence-chain producer placeholder. Current mode is only `report-only` / fixture. This stage does not claim real lifecycle evidence, main evidence, or manual closure readiness for Issue #17.

## Safety Boundaries

This acceptance scaffold confirms:

- no real build, capture, deploy, WinPE build, or boot media creation
- no DISM, Sysprep, AppX, Defender, Junction, Service, disk, partition, BCD, WinRE, registry, profile, or hive mutation
- no software install, uninstall, upgrade, package lookup, network download, or `Install-Module`
- no local private artifact or `manifests/paths.local.json` in Build Lock
- no Issue #6-#16 close-prep, main-evidence, or completion summary edits
- no automatic Issue #17 closure

## Remaining Work

- Design the future explicit WinPE authorization flow.
- Extend the fixture adapters into a fuller execution-set matrix.
- Add real execution authorization only in a later, explicitly approved stage.
- Produce close-prep and main-evidence documents only after a later task explicitly reaches that stage.

## Related Documents

- [Issue #17 Controlled Execution Intake](52-issue17-controlled-execution-intake.md)
- [Issue #17 Controlled Execution Safety Hardening](54-issue17-controlled-execution-safety-hardening.md)
- [Issue #16 Evidence Chain Acceptance](49-issue16-evidence-chain-acceptance.md)
