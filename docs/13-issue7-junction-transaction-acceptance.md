# Issue #7 Junction Transaction Acceptance

Status: accepted-pending-manual-closure

Close preparation: [Issue #7 Close Preparation](14-issue7-close-preparation.md)

## Scope

- Preflight safety checks.
- Copy-first transaction execution.
- countAndSize verification.
- Backup rename and retention.
- mklink exit code capture.
- Final Junction target verification.
- Rollback and manual recovery evidence.
- WhatIf plan-only behavior.

## Non-goals

- Real VM or admin smoke automation.
- Real user-directory migration in CI.
- NAS write validation.
- no-clobber merge support.
- Hash verification mode.

## Transaction Flow

1. preflight
2. copy
3. verify countAndSize
4. backup rename
5. mklink
6. final verify
7. retention

## Failure Safety

- Copy failure: source is not renamed and no Junction is created.
- countAndSize failure: source is not renamed and no Junction is created.
- Backup rename failure: no Junction is created.
- mklink failure: backup is preserved and rollback is attempted when the source path is absent.
- Final verify failure: backup is preserved and `manualRecoveryHint` explains recovery.
- Backup delete failure: Junction has already been verified, but backup cleanup needs manual handling.

## Acceptance Matrix

| Area | Expected behavior | Evidence |
| --- | --- | --- |
| Direct move removed | `/MOVE` is not used in the active Junction migration path | `Issue7JunctionAcceptance.Tests.ps1` static guard |
| Preflight path cycle | same path and parent-child paths are blocked | `JunctionTransactionPreflight.Tests.ps1` |
| Source correct Junction | unchanged and no mutation | `JunctionTransactionPreflight.Tests.ps1` / `JunctionTransactionExecution.Tests.ps1` |
| Source wrong Junction | blocking failure | `JunctionTransactionPreflight.Tests.ps1` |
| Target reparse point | blocking failure before mutation | `Issue7JunctionAcceptance.Tests.ps1` |
| Target conflict fail | blocking failure | `JunctionTransactionPreflight.Tests.ps1` |
| Space insufficient | blocking failure | `JunctionTransactionPreflight.Tests.ps1` |
| Copy failure | no source rename and no mklink | `JunctionTransactionExecution.Tests.ps1` |
| countAndSize mismatch | no source rename and no mklink | `JunctionTransactionExecution.Tests.ps1` |
| Backup rename failure | no mklink | `JunctionTransactionExecution.Tests.ps1` |
| mklink failure | backup preserved / rollback attempted / manual hint | `Issue7JunctionAcceptance.Tests.ps1` |
| Final verify failure | backup preserved / manual hint / flat errors | `Issue7JunctionAcceptance.Tests.ps1` |
| backupRetention keep | backup retained by default | `JunctionTransactionExecution.Tests.ps1` |
| backupRetention delete | delete only after final verify | `JunctionTransactionExecution.Tests.ps1` |
| WhatIf | no mutation and plan only | `Issue7JunctionAcceptance.Tests.ps1` |
| Report model | transaction fields are present in JSON report data | `Issue7JunctionAcceptance.Tests.ps1` |

## CI Boundary

PR Fast CI must keep the Issue #7 acceptance test in the Windows PowerShell Pester list. CI does not create real Junctions because that would require administrator privileges and would mutate runner filesystem state. Real VM/admin smoke should be handled manually or in a follow-up task with explicit approval.

## Maintainer Checklist Before Manual Issue #7 Closure

- Confirm active Junction migration code does not call `robocopy /MOVE`.
- Confirm PR Fast CI includes and passes the Junction preflight, transaction execution, state verification, and Issue #7 acceptance Pester files.
- Confirm `onTargetConflict` remains `fail` only until no-clobber merge is designed and tested.
- Confirm `verificationMode` remains `countAndSize` only until hash verification is designed and tested.
- Confirm reports include transaction stage, backup path, rollback fields, and manual recovery hints.
- Confirm no real user-directory migration, NAS write, installer, service, Defender, registry, AppX, Sysprep, DISM, WinPE, or diskpart operation was executed by CI.
