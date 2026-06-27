# Future True UX Restore Dry-run Execution Plan

Status: `dry-run-plan`

## Purpose

This plan describes what a future true UX restore execution task would need before execution. It is dry-run only and does not mutate system, user, offline image, AppX, registry, profile, Default User hive, default app, Start menu, taskbar, Defender, Junction, service, or Sysprep state.

## Plan Inputs

The dry-run plan reads the future authorization manifest and optional fixture authorization request. It reports required fields, missing fields, blocked reasons, mutation allow flags, and scope-specific evidence requirements.

## Default Decision

The baseline decision is `blocked`. All mutation flags default to false, `trueExecution=false`, `mutationCount=0`, `commandExitCodeSufficient=false`, and `userConfigurationConfirmed=false`.

## Scope Gates

Each scope must pass its own gate before a later task can request execution:

- `current-user`: requires redacted user identity, before/after evidence, and independent user-scoped verification.
- `default-user`: requires template identity, backup/rollback, before/after template or hive state, and proof it is not current-user evidence.
- `offline-image`: requires image identity, image index, mount path, rollback/unmount strategy, and proof it is not current machine evidence.
- `machine`: requires machine identity, policy or machine target, before/after state, rollback, and admin or VM smoke boundary.

## Blocked Reasons

The plan must list blocked reasons when authorization is incomplete. Expected blocked reasons include missing authorization fields, requested mutation while allow flags are false, exit-code-only success claims, private path evidence, scope mismatch, missing rollback, and missing reviewer checkpoint.

## No Mutation

The dry-run plan does not:

- write registry/profile/default apps/Start menu/taskbar state;
- load or edit Default User hive;
- call DISM/AppX;
- query real installed AppX as success evidence;
- run StartLayout import/export as evidence;
- install, uninstall, upgrade, or download dependencies;
- produce an Issue #18 completion summary;
- close Issue #18.

## Output

`scripts/config/Show-FutureTrueUxRestoreAuthorizationPlan.ps1` prints a human-readable plan and serializes the authorization report. The output is evidence of authorization intake only. It is not real UX restore evidence and does not authorize execution.

## Related Documents

- [Future True UX Restore Authorization Intake](66-future-true-ux-restore-authorization-intake.md)
- [Future True UX Restore Evidence Model](67-future-true-ux-restore-evidence-model.md)
- [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md)
