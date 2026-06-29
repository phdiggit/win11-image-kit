# Future True UX Restore Unified Authorization Request

Status: `authorization-request-draft`

Refs #18

## Purpose

This document defines a unified authorization request shape for future true UX restore review. It covers `current-user`, `default-user`, `offline-image`, and `machine` scopes, but it does not approve execution.

## One Scope Per Request

Each request must name exactly one target scope:

- `current-user`
- `default-user`
- `offline-image`
- `machine`

A request that mixes scopes, omits scope, or claims evidence from another scope remains blocked.

## Required Fields

An authorization request must include:

- scope;
- target identity;
- requested mutation type;
- dry-run command envelope;
- rollback or backup plan;
- evidence packet;
- failure propagation;
- review checkpoint;
- explicit statement that execution is not approved.

## Evidence Packet

The evidence packet is defined in [Future True UX Restore Evidence Packet Contract](78-future-true-ux-restore-evidence-packet-contract.md). It is review material only. It cannot prove UX has been restored and cannot replace real after evidence.

## Blocked Conditions

The request remains blocked when:

- any required field is missing;
- scope and evidence packet scope do not match;
- private paths are not redacted;
- command exit code, handler report, manual checklist, or dry-run report is used as success evidence;
- authorization or execution approval is requested;
- execute-ready is requested;
- auto-close keywords are present.

## Frozen Execution State

This stage always reports:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`
- `ExecuteReady=false`
- `trueExecution=false`
- `mutationCount=0`

## Related Documents

- [Future True UX Restore Maintainer Review Checkpoint](77-future-true-ux-restore-maintainer-review-checkpoint.md)
- [Future True UX Restore Evidence Packet Contract](78-future-true-ux-restore-evidence-packet-contract.md)
- [Future True UX Restore Authorization State Machine](79-future-true-ux-restore-authorization-state-machine.md)
