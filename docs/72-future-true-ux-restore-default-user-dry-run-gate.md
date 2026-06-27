# Future True UX Restore Default-user Dry-run Gate

Status: `default-user-dry-run-gate`

## Source

This gate extends the future true UX restore dry-run model from docs/66-71. It does not change the Issue #18 ready report-only / handler-adapter state and does not close Issue #18.

## Purpose

This document defines the `default-user` scope dry-run gate. The gate may describe a future Default User template/profile target, required evidence, rollback, and blocked reasons. It cannot load, write, or unload a Default User hive.

## Default-user Scope Boundary

`default-user` means the Default User template/profile target used for future new profiles. It does not mean the current user, an offline image, or machine-wide policy state.

Default User evidence cannot be presented as current-user success. Current-user, machine, and offline-image evidence cannot be substituted for Default User evidence.

## Required Authorization

A default-user dry-run request must include:

- template source;
- Default User target identity;
- before evidence;
- dry-run command envelope;
- rollback or backup plan;
- after evidence placeholder;
- independent verification placeholder;
- failure propagation;
- review checkpoint.

Missing values keep the decision blocked.

## Dual Approval Gate

`AuthorizationApproved` and `ExecutionApproved` remain separate. For this stage:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`

A complete default-user request can only become `dry-run-ready`; it is not `execute-ready`.

## Blocked Execution Conditions

Execution is blocked when:

- either approval gate is false;
- scope is not `default-user`;
- a request claims current-user, machine, or offline-image evidence as Default User evidence;
- a private profile path is not redacted;
- hive load, hive write, profile write, default app write, Start menu write, or taskbar write is requested;
- command exit code, handler report, manual checklist, or dry-run report is used as success evidence;
- rollback, failure propagation, or review checkpoint is missing.

## Related Documents

- [Future True UX Restore Current-user Dry-run Gate](69-future-true-ux-restore-current-user-dry-run-gate.md)
- [Future True UX Restore Execute-gate Dual Approval](71-future-true-ux-restore-execute-gate-dual-approval.md)
- [Future True UX Restore Scope Guard Matrix](75-future-true-ux-restore-scope-guard-matrix.md)
