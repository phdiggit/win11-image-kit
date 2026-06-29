# Future True UX Restore Evidence Model

Status: `evidence-model-draft`

## Evidence Layers

Future true UX restore execution needs four evidence layers:

1. Before evidence proving the target state before mutation.
2. Execution evidence proving the authorized command envelope was the one used.
3. After evidence proving the target state after mutation.
4. Independent verification proving the UX claim with a signal separate from the command exit code.

This stage only defines the model. It does not collect real user state and does not execute true UX restore.

## Required Before Evidence

Before evidence must identify the scope, target identity, expected before state, and rollback or backup checkpoint. Missing before evidence blocks authorization.

## Required Execution Evidence

Execution evidence must include the allowed command envelope, invocation boundary, operator or automation context, failure propagation policy, and reviewer checkpoint. The command must be authorized before use. A command exit code alone is never sufficient.

## Required After Evidence

After evidence must be target-scoped and comparable to the before evidence. It must not be inferred from a dry-run plan, handler report, manual checklist, or unrelated machine state.

## Independent Verification

Independent verification must confirm the target UX state using a separate, scope-aware method. The verification must show that the observed state belongs to the intended current user, Default User template, offline image, or machine target.

## Scope-specific Verification

### current-user

Required evidence:

- user identity, SID, or safe redacted identity;
- before state for that user;
- command or tool invocation envelope;
- after state for that user;
- independent verification for the same user;
- proof that the current-user claim is user-scoped;
- no exit-code-only success.

### default-user

Required evidence:

- template source;
- Default User target;
- backup or rollback;
- before and after template or hive state;
- proof that Default User evidence does not equal current-user state.

### offline-image

Required evidence:

- image identity;
- mount path and image index;
- before and after image state;
- rollback or unmount strategy;
- proof that the offline image is not the current machine.

### machine

Required evidence:

- machine identity;
- policy or machine-wide setting target;
- before and after state;
- rollback;
- admin or VM smoke boundary.

## Failure Evidence

Failures must preserve enough evidence for review: missing field, blocked reason, scope, target identity if safe to record, expected evidence paths, and failure propagation. Unsafe private paths must be redacted.

## Report Fields

The report contract for this intake requires:

- `reportType`
- `mode`
- `decision`
- `missingAuthorizationFields`
- `blockedReasons`
- `scope`
- `mutationAllowFlags`
- `evidenceRequirements`
- `trueExecution=false`
- `mutationCount=0`
- `commandExitCodeSufficient=false`
- `userConfigurationConfirmed=false`

## Forbidden Evidence Substitutes

The following are not real UX success evidence:

- command exit code alone;
- handler report;
- dry-run plan;
- report-only output;
- manual checklist;
- Default User state presented as current-user state;
- offline image state presented as current machine state;
- real AppX or registry query used as success evidence in this intake stage.

## Related Documents

- [Future True UX Restore Authorization Intake](66-future-true-ux-restore-authorization-intake.md)
- [Future True UX Restore Dry-run Execution Plan](68-future-true-ux-restore-dry-run-plan.md)
- [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md)
