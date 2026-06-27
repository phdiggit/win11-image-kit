# Issue #17 Controlled Execution Safety Hardening

Status: `accepted-pending-main-validation`

## Scope

This stage extends the Issue #17 dry-run baseline with fixture-only safety models for future WinPE controlled execution. It remains dry-run / WhatIf / report-only / fixture / plan-only.

No real disk, image, boot, recovery, registry, profile, hive, service, network, install, build, capture, deploy, or WinPE media action is performed.

## Disk Identity Model

`tests/fixtures/controlled-execution/disk-identity/matched.json` models a single target disk candidate with disk number, serial, size, model, bus type, partition style, and partition summary.

`scripts/common/ConvertTo-KitDiskIdentityPlan.ps1` compares fixture target values with expected values and returns `blocked` when disk number, serial, size, bus type, required expected values, or candidate count do not match.

The script does not query real disks.

## Confirmation Token Contract

`tests/fixtures/controlled-execution/confirmation-token/matched.json` requires the token to contain the target disk number or target disk serial.

`scripts/common/Test-KitConfirmationToken.ps1` blocks generic tokens such as `YES`, `CONFIRM`, and `I AGREE`, and blocks tokens that do not identify the target disk.

## WIM Hash / Image Metadata Plan

`tests/fixtures/controlled-execution/wim-image/matched.json` models `fixture://install.wim`, expected and actual SHA256, image index, architecture, edition, and source run ID.

`scripts/common/ConvertTo-KitWimImagePlan.ps1` blocks hash mismatch, index mismatch, architecture mismatch, missing source run ID, and non-fixture image paths. It does not read real image files or calculate large-file hashes.

## Windows RE Plan

`tests/fixtures/controlled-execution/winre-plan/planned.json` models EFI, Windows, and Recovery logical volumes without relying on fixed drive order.

The Recovery plan requires:

- GPT type `de94bba4-06d1-4d40-a16a-bfd50179d6ac`
- GPT attributes `0x8000000000000001`
- logical `winre.wim` path
- planned recovery commands as strings only

`scripts/common/ConvertTo-KitWinREPlan.ps1` validates the fixture model and does not execute recovery tooling or mutate WinRE state.

## Native Command Result Envelope

`tests/fixtures/controlled-execution/native-command/planned.json` records future native command envelopes with:

- `commandName`
- `plannedCommand`
- `expectedExitCodes`
- `actualExitCode=not-run`
- `stdout=not-captured`
- `stderr=not-captured`
- `status=planned`

`scripts/common/New-KitNativeCommandPlan.ps1` blocks any fixture that looks captured or executed.

## Controlled Execution Report Additions

`scripts/common/New-KitControlledExecutionReport.ps1` now includes:

- `inputs.diskIdentity`
- `inputs.confirmationToken`
- `inputs.wimMetadata`
- `inputs.winrePlan`
- `inputs.nativeCommandPlan`
- `inputs.authorization`
- `authorization`
- `stageResults`
- `simulation`

The report summary now includes:

- `diskIdentityMismatchCount`
- `confirmationTokenFailureCount`
- `wimValidationFailureCount`
- `winrePlanFailureCount`
- `nativeCommandFailureCount`
- `authorizationFailureCount`
- `executeRequestBlockedCount`
- `simulatedCommandCount`
- `simulatedFailureCount`
- `downstreamBlockedCount`
- `dependencyBlockedCount`

`scripts/validate/Test-ControlledExecution.ps1` exits 1 if any count is greater than zero.

## CI / Quality Gates / Build Lock

PR Fast CI keeps running controlled execution validation and includes the safety hardening Pester files. It is not main/workflow evidence and is not real lifecycle evidence.

Quality Gates add fixture-only gates for disk identity, confirmation token, WIM planning, WinRE planning, and native command envelopes.

Build Lock covers this document, schemas, scripts, fixtures, tests, CI, Quality Gates, and README links. It does not include `manifests/paths.local.json`, real WIM files, local disk reports, WinPE logs, or private machine paths.

## Non-goals

- No real disk query or disk mutation.
- No real image hash calculation on local/private files.
- No real build, capture, deploy, WinPE build, or boot media creation.
- No real boot/recovery tooling execution.
- No registry, profile, hive, service, AppX, Defender, Junction, install, network, or signing action.
- Issue #17 close-prep is candidate-only in `docs/56`; main evidence remains pending in `docs/57`.
- No Issue #17 completion summary.
- No automatic Issue #17 closure.
- No Issue #6-#16 close-prep, main-evidence, or completion summary edits.

## Remaining Work

- Expand the execution-set matrix only with more fixture or plan-only stages.
- Design the later human authorization flow for any real execution stage.
- Keep true execution behind a later manual safety gate.
- Backfill main/workflow validation evidence only in a later task.
- Keep true execution behind a separate controlled task with explicit human authorization.

## Related Documents

- [Issue #17 Controlled Execution Intake](52-issue17-controlled-execution-intake.md)
- [Issue #17 Controlled Execution Acceptance](53-issue17-controlled-execution-acceptance.md)
- [Issue #17 Controlled Execution Authorization and Simulation](55-issue17-controlled-execution-authorization.md)
- [Issue #17 Close Preparation](56-issue17-close-preparation.md)
- [Issue #17 Main Validation Evidence](57-issue17-main-validation-evidence.md)
