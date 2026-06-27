# Future True UX Restore Offline-image Dry-run Gate

Status: `offline-image-dry-run-gate`

## Source

This gate extends the future true UX restore dry-run model from docs/66-71. It does not change the Issue #18 ready report-only / handler-adapter state and does not close Issue #18.

## Purpose

This document defines the `offline-image` scope dry-run gate. The gate may describe a future mounted image identity, image index, mount-path placeholder, unmount or rollback plan, and blocked reasons. It cannot mount, unmount, service, or mutate an offline image.

## Offline-image Scope Boundary

`offline-image` means an explicitly identified offline Windows image target. It does not mean the current machine, current user, or Default User template in the live OS.

Offline-image evidence cannot be presented as current machine success. Current-user, Default User, and machine evidence cannot be substituted for offline-image evidence.

## Required Authorization

An offline-image dry-run request must include:

- image identity;
- image index;
- mount path placeholder;
- before evidence;
- dry-run command envelope;
- rollback or unmount plan;
- after evidence placeholder;
- independent verification placeholder;
- failure propagation;
- review checkpoint.

Missing values keep the decision blocked.

## Dual Approval Gate

`AuthorizationApproved` and `ExecutionApproved` remain separate. For this stage:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`

A complete offline-image request can only become `dry-run-ready`; it is not `execute-ready`.

## Blocked Execution Conditions

Execution is blocked when:

- either approval gate is false;
- scope is not `offline-image`;
- a request claims current machine, current-user, or Default User evidence as offline-image evidence;
- a private mount path or local private artifact path is not redacted;
- mount, unmount, image servicing, or default app import is requested;
- command exit code, handler report, manual checklist, or dry-run report is used as success evidence;
- rollback or unmount plan, failure propagation, or review checkpoint is missing.

## Related Documents

- [Future True UX Restore Current-user Dry-run Gate](69-future-true-ux-restore-current-user-dry-run-gate.md)
- [Future True UX Restore Execute-gate Dual Approval](71-future-true-ux-restore-execute-gate-dual-approval.md)
- [Future True UX Restore Scope Guard Matrix](75-future-true-ux-restore-scope-guard-matrix.md)
