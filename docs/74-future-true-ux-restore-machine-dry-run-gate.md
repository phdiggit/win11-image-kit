# Future True UX Restore Machine Dry-run Gate

Status: `machine-dry-run-gate`

## Source

This gate extends the future true UX restore dry-run model from docs/66-71. It does not change the Issue #18 ready report-only / handler-adapter state and does not close Issue #18.

## Purpose

This document defines the `machine` scope dry-run gate. The gate may describe future machine-wide policy or setting targets, rollback, admin or VM smoke boundary, and blocked reasons. It cannot write machine-wide state.

## Machine Scope Boundary

`machine` means a machine-wide policy or setting target. It does not mean current-user UX state, Default User template state, or offline-image state.

Machine evidence cannot be presented as current-user success. Current-user, Default User, and offline-image evidence cannot be substituted for machine evidence.

## Required Authorization

A machine dry-run request must include:

- machine identity;
- machine setting target;
- before evidence;
- dry-run command envelope;
- rollback plan;
- after evidence placeholder;
- independent verification placeholder;
- admin or VM smoke boundary;
- failure propagation;
- review checkpoint.

Missing values keep the decision blocked.

## Dual Approval Gate

`AuthorizationApproved` and `ExecutionApproved` remain separate. For this stage:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`

A complete machine request can only become `dry-run-ready`; it is not `execute-ready`.

## Blocked Execution Conditions

Execution is blocked when:

- either approval gate is false;
- scope is not `machine`;
- a request claims current-user, Default User, or offline-image evidence as machine evidence;
- registry, policy, service, Defender, Junction, Sysprep, install, uninstall, or network actions are requested;
- command exit code, handler report, manual checklist, or dry-run report is used as success evidence;
- rollback, admin or VM smoke boundary, failure propagation, or review checkpoint is missing.

## Related Documents

- [Future True UX Restore Current-user Dry-run Gate](69-future-true-ux-restore-current-user-dry-run-gate.md)
- [Future True UX Restore Execute-gate Dual Approval](71-future-true-ux-restore-execute-gate-dual-approval.md)
- [Future True UX Restore Scope Guard Matrix](75-future-true-ux-restore-scope-guard-matrix.md)
