# Future True UX Restore Current-user Dry-run Gate

Status: `current-user-dry-run-gate`

## Source

This gate follows [Future True UX Restore Authorization Intake](66-future-true-ux-restore-authorization-intake.md), [Future True UX Restore Evidence Model](67-future-true-ux-restore-evidence-model.md), and [Future True UX Restore Dry-run Execution Plan](68-future-true-ux-restore-dry-run-plan.md).

It does not change the Issue #18 ready report-only / handler-adapter state and does not close Issue #18.

## Purpose

This document defines the current-user scope dry-run gate for a future true UX restore task. The gate can produce dry-run planning output and blocked reasons. It cannot execute current-user restore.

## Current-user Scope Boundary

`current-user` means a specifically authorized current user identity represented by a redacted safe token. It does not mean Default User, machine policy, offline image state, or any generic profile path.

Current-user dry-run evidence must stay user-scoped. Default User template state cannot be presented as current-user evidence. Offline image state cannot be presented as current machine evidence. Machine policy state cannot be presented as current-user UX success.

## Required Authorization

A current-user dry-run request must include:

- redacted user identity;
- before evidence;
- dry-run command envelope;
- rollback or backup plan;
- after evidence placeholder;
- independent verification placeholder;
- failure propagation;
- review checkpoint.

Missing values keep the decision blocked.

## Dual Approval Gate

`AuthorizationApproved` and `ExecutionApproved` are separate gates. Both must be true in a future explicitly authorized task before any mutation can be considered.

For this stage:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`

Because both approvals are false, execution remains blocked. A complete dry-run request can only become `dry-run-ready`; it still cannot execute mutation.

## Evidence Collector Contract

The current-user evidence collector contract is drafted in [Current-user UX Restore Evidence Collector Contract](70-future-true-ux-restore-current-user-evidence-contract.md). Future real evidence must prove same-user before state, after state, and independent verification. Command exit code is not UX success evidence.

## Dry-run Plan Output

The dry-run plan output lists required evidence, missing fields, scope guard failures, dual approval state, and blocked reasons. It reports `trueExecution=false`, `mutationCount=0`, `commandExitCodeSufficient=false`, `userConfigurationConfirmed=false`, and `currentUserConfirmed=false`.

## Blocked Execution Conditions

Execution is blocked when:

- either approval gate is false;
- scope is not `current-user`;
- a request claims Default User, machine, or offline-image evidence as current-user evidence;
- private profile paths are not redacted;
- mutation is requested;
- command exit code, handler report, manual checklist, or dry-run report is used as after evidence;
- rollback, failure propagation, or review checkpoint is missing.

## Related Documents

- [Current-user UX Restore Evidence Collector Contract](70-future-true-ux-restore-current-user-evidence-contract.md)
- [Future True UX Restore Execute-gate Dual Approval](71-future-true-ux-restore-execute-gate-dual-approval.md)
- [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md)
