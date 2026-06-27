# Future True UX Restore Authorization State Machine

Status: `authorization-state-machine`

Refs #18

## States

The review workflow recognizes these states:

- `blocked`
- `dry-run-ready`
- `authorization-review-ready`
- `authorization-rejected`
- `execute-ready-future-only`

## Current Stage

This stage can produce `blocked`, `needs-more-evidence`, `authorization-review-ready`, or `rejected` review decisions. It cannot produce `execute-ready`.

## Future-only Execute-ready

`execute-ready-future-only` is a named future state. Reaching it requires a later task that explicitly changes the schema, tests, approval contract, and maintainer authorization. This PR does not do that.

## State Requirements

| State | Meaning | Execution |
|---|---|---|
| `blocked` | request is incomplete or unsafe | no |
| `dry-run-ready` | dry-run scope packet is structurally complete | no |
| `authorization-review-ready` | packet is complete enough for maintainer review | no |
| `authorization-rejected` | packet should not proceed | no |
| `execute-ready-future-only` | future authorized execution state | not reachable now |

## Frozen Flags

All current-stage reports keep:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`
- `ExecuteReady=false`
- `trueExecution=false`
- `mutationCount=0`
- `userConfigurationConfirmed=false`

## Related Documents

- [Future True UX Restore Unified Authorization Request](76-future-true-ux-restore-unified-authorization-request.md)
- [Future True UX Restore Maintainer Review Checkpoint](77-future-true-ux-restore-maintainer-review-checkpoint.md)
- [Future True UX Restore Evidence Packet Contract](78-future-true-ux-restore-evidence-packet-contract.md)
