# Future True UX Restore Execute-gate Dual Approval

Status: `execute-gate-draft`

## Purpose

This model separates authorization approval from execution approval for future true UX restore tasks.

## Two Different Approvals

`AuthorizationApproved=true` means authorization material is complete and has passed review. It does not mean execution can run.

`ExecutionApproved=true` must be explicitly granted by a maintainer in a future task that is allowed to execute the named scope.

## Current Stage

This stage only establishes the model. It approves no execution.

The current manifest, fixtures, tests, and reports must keep:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`

## Execute Gate

Without both approvals true, any mutation is blocked. This includes current-user default app, Start menu, taskbar, profile, registry, Default User, machine, offline image, AppX, Defender, Junction, service, Sysprep, image servicing, install, uninstall, upgrade, and network download actions.

## Scope Inheritance

The same dual approval rule applies to:

- `current-user`
- `default-user`
- `offline-image`
- `machine`

Every scope keeps its manifest section at `AuthorizationApproved=false` and `ExecutionApproved=false` in this stage.

## Dry-run-ready Is Not Execute-ready

A request with all required scope dry-run fields can become `dry-run-ready`. That state only means the dry-run contract is complete enough to review. It still reports `trueExecution=false` and `mutationCount=0`.

## Related Documents

- [Future True UX Restore Current-user Dry-run Gate](69-future-true-ux-restore-current-user-dry-run-gate.md)
- [Current-user UX Restore Evidence Collector Contract](70-future-true-ux-restore-current-user-evidence-contract.md)
- [Future True UX Restore Scope Guard Matrix](75-future-true-ux-restore-scope-guard-matrix.md)
- [Future True UX Restore Authorization Intake](66-future-true-ux-restore-authorization-intake.md)
