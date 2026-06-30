# Future True UX Restore Authorization Intake

Status: `authorization-intake`

## Source

This intake follows [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md). Issue #18 remains scoped to the ready report-only / handler-adapter stage. This document does not complete, close, or expand Issue #18 into real mutation.

## Purpose

The purpose is to define the authorization contract that must exist before any future true UX restore execution task can mutate registry, profile, Default User hive, default app associations, Start menu, taskbar, offline image, AppX, Defender, Junction, service, or Sysprep state.

This stage is still authorization intake only. It produces documents, schemas, fixtures, dry-run plans, and reports. It does not execute true UX restore.

## Authorization Contract

A future execution request must be explicit and human-authorized. The request is blocked unless it includes every required field:

- `scope`
- `targetIdentity`
- `mutationType`
- `expectedBeforeState`
- `allowedCommand`
- `rollbackPlan`
- `beforeEvidence`
- `afterEvidence`
- `independentVerification`
- `failurePropagation`
- `reviewCheckpoint`

The authorization must name the exact scope and target identity. It must also name the mutation type, the allowed command envelope, the expected before state, the evidence path, the rollback or backup path, the failure propagation rule, and the reviewer checkpoint. Missing, ambiguous, or fixture-only values keep the decision blocked.

## Scope Matrix

| Scope | Required target | Required safety gate |
|---|---|---|
| `current-user` | Redacted user identity or SID for the active target user | Must prove the claim is user-scoped and not Default User or machine state |
| `default-user` | Default User template source and target profile/hive identity | Must prove this is not current-user state and has backup/rollback |
| `offline-image` | Image identity, image index, and mount path | Must prove the offline image is not the current machine and has unmount/rollback |
| `machine` | Machine identity and policy or machine-wide setting target | Must define admin or VM smoke boundary and rollback |

## Mutation Allowlist

Default decision is deny. The authorization manifest keeps all mutation flags false:

- registry mutation: false
- profile mutation: false
- Default User hive mutation: false
- default app mutation: false
- Start menu mutation: false
- taskbar mutation: false
- DISM mutation: false
- AppX mutation: false
- network download: false

This intake is not itself an execution authorization. A later task must explicitly change the relevant contract, tests, and review evidence before any mutation can run.

## Evidence Requirements

Every future execution scope must provide before evidence, execution evidence, after evidence, and independent verification. Command exit code is not UX success evidence. Handler report, dry-run report, plan output, and manual checklist are not real UX evidence.

Evidence must be scoped to the target. A current-user claim must be verified against the target user. A Default User claim must be verified against the template or hive target and must not be represented as current-user success. An offline-image claim must identify the image and prove it is not the current machine.

## Rollback / Backup Requirements

Every future authorization request must include rollback or backup instructions before execution is considered. The rollback plan must name the restore point, backup file, exported setting, unmount strategy, or equivalent reversible checkpoint. If rollback cannot be expressed, the request remains blocked.

## Stop Conditions

The decision remains blocked when:

- any required authorization field is missing;
- any mutation allow flag is true in this intake stage;
- the request uses command exit code as the only success signal;
- the request uses handler report, dry-run report, or manual checklist as real UX evidence;
- private local paths are unredacted;
- scope and target identity do not match;
- rollback, failure propagation, or reviewer checkpoint is missing.

## Dry-run First Policy

Future work must start from a dry-run plan. The plan may list required commands and expected evidence, but it must not write registry/profile/default apps/Start menu/taskbar state, call DISM/AppX, query real installed AppX as success evidence, or install/download dependencies.

## Default Deny Policy

All true mutation is denied by default. The safe baseline decision is `blocked`, with `trueExecution=false`, `mutationCount=0`, `commandExitCodeSufficient=false`, and `userConfigurationConfirmed=false`.

## Related Documents

- [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md)
- [Future True UX Restore Evidence Model](67-future-true-ux-restore-evidence-model.md)
- [Future True UX Restore Dry-run Execution Plan](68-future-true-ux-restore-dry-run-plan.md)
- [Future True UX Restore Final Stop-Line Handoff](106-future-true-ux-restore-final-stop-line-handoff.md)
