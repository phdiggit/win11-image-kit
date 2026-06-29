# Current-user UX Restore Evidence Collector Contract

Status: `evidence-contract-draft`

## Required Identity

Current-user evidence must use a redacted user identity or safe token. This repository must not store a real SID, real profile path, account name, or other private identity.

## Before Evidence

Before evidence must describe the intended current-user state before a future authorized task changes anything. It must be scoped to the same redacted user identity used by the request.

## Dry-run Command Envelope

The dry-run command envelope names the future command shape without executing it. The envelope is planning metadata, not execution evidence and not success evidence.

## After Evidence Placeholder

This stage only records an after-evidence placeholder. Future real after evidence must be collected by a separately authorized task and must prove the same current-user target.

## Independent Verification Placeholder

This stage only records an independent-verification placeholder. Future real independent verification must be stronger than command exit code and must be separate from the command that performs the mutation.

## Rollback / Backup

A future current-user execution task must define rollback or backup before execution. Missing rollback keeps the request blocked.

## Privacy and Redaction

Private paths must be redacted. Do not commit:

- real SID values;
- real profile paths;
- registry exports;
- real default app import/export artifacts;
- real Start menu or taskbar artifacts;
- local private evidence files.

## Failure Propagation

The request must state how failures propagate. Missing or ambiguous failure propagation keeps the decision blocked.

## Forbidden Substitutes

The following are not current-user after evidence:

- command exit code;
- handler report;
- manual checklist;
- dry-run report;
- Default User state;
- machine policy state;
- offline-image state.

## Related Documents

- [Future True UX Restore Current-user Dry-run Gate](69-future-true-ux-restore-current-user-dry-run-gate.md)
- [Future True UX Restore Evidence Model](67-future-true-ux-restore-evidence-model.md)
- [Future True UX Restore Execute-gate Dual Approval](71-future-true-ux-restore-execute-gate-dual-approval.md)
