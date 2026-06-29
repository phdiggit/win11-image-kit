# Future True UX Restore Scope Guard Matrix

Status: `scope-guard-matrix`

## Purpose

This matrix keeps future true UX restore dry-run evidence separated across four scopes:

- `current-user`
- `default-user`
- `offline-image`
- `machine`

It does not authorize execution and does not close Issue #18.

## Scope Boundaries

| Scope | Valid target | Invalid substitutions |
|---|---|---|
| `current-user` | redacted current user identity | Default User, machine, offline-image |
| `default-user` | Default User template/profile target | current-user, machine, offline-image |
| `offline-image` | explicitly identified offline Windows image | current machine, current-user, Default User |
| `machine` | machine-wide policy or setting target | current-user UX state, Default User, offline-image |

## Always Blocked Substitutes

The following cannot prove real UX restore success:

- command exit code only;
- handler report;
- manual checklist;
- dry-run report;
- cross-scope evidence;
- private local path or network artifact path;
- unreviewed fallback to another scope.

## Approval and Execution State

All scope dry-run reports must keep:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`
- `trueExecution=false`
- `mutationCount=0`
- `commandExitCodeSufficient=false`
- `userConfigurationConfirmed=false`

Each scope has its own confirmed flag, and every flag remains false in this stage.

## Fallback Policy

Fallback across scopes is blocked. A future execution task must name exactly one scope and prove evidence for that same scope. Dry-run readiness never means another scope has been restored.

## Related Documents

- [Future True UX Restore Current-user Dry-run Gate](69-future-true-ux-restore-current-user-dry-run-gate.md)
- [Future True UX Restore Default-user Dry-run Gate](72-future-true-ux-restore-default-user-dry-run-gate.md)
- [Future True UX Restore Offline-image Dry-run Gate](73-future-true-ux-restore-offline-image-dry-run-gate.md)
- [Future True UX Restore Machine Dry-run Gate](74-future-true-ux-restore-machine-dry-run-gate.md)
