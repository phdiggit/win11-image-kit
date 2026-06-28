# Future True UX Restore Negative Decision Ledger

Status: `negative-decision-ledger`

The negative decision ledger is a small, deterministic review trail for each fixture. It records:

- `negative-case-received`
- one `negative-reason-recorded` entry for each reason code
- `execution-blocked`

Every ledger entry keeps `executeReady` as `false`. The ledger can be attached to a PR as review evidence, but it cannot become execution evidence and cannot replace a maintainer approval.

The ledger is intentionally local and fixture-based. It does not query GitHub checks, modify Issue #18 state, or record a closure-ready summary.
