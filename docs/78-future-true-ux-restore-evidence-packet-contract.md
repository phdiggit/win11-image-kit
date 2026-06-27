# Future True UX Restore Evidence Packet Contract

Status: `evidence-packet-draft`

Refs #18

## Purpose

An evidence packet groups the review material needed before a future true UX restore request can be considered for authorization review. The packet is not execution evidence and is not proof that UX has been restored.

## Required Packet Fields

Each packet must include:

- before evidence;
- dry-run command envelope;
- rollback or backup plan;
- after evidence placeholder;
- independent verification placeholder;
- scope guard assertion;
- privacy and redaction statement;
- failure propagation;
- reviewer checklist.

## Scope Guard Assertion

The packet must assert the same scope as the authorization request. Cross-scope evidence remains blocked. Default User evidence is not current-user evidence, offline-image evidence is not current machine evidence, and machine evidence is not current-user success.

## Privacy and Redaction

The packet must not include:

- real profile paths;
- real SID values;
- registry exports;
- real Start menu or taskbar artifacts;
- offline image mount artifacts;
- local private evidence files;
- installers or network package artifacts.

## Forbidden Substitutes

The following cannot be used as success evidence:

- command exit code;
- handler report;
- manual checklist;
- dry-run report;
- review-ready packet.

## Frozen Execution State

Every packet report in this stage keeps:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`
- `ExecuteReady=false`
- `trueExecution=false`
- `mutationCount=0`
- `userConfigurationConfirmed=false`

## Related Documents

- [Future True UX Restore Unified Authorization Request](76-future-true-ux-restore-unified-authorization-request.md)
- [Future True UX Restore Maintainer Review Checkpoint](77-future-true-ux-restore-maintainer-review-checkpoint.md)
- [Future True UX Restore Authorization State Machine](79-future-true-ux-restore-authorization-state-machine.md)
