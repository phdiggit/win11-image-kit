# Future True UX Quality Gate Governance

Status: `future-true-ux-quality-gate-governance`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Scope

This policy groups and names the current Future True UX Restore quality gates after the repository governance audit and the Issue #121 deletion-first prune. It keeps only the long-term report-only safety net while making `manifests/quality-gates.json` easier to read and audit.

This task does not authorize true UX restore, Issue #19 closure, workflow changes, or any real system mutation.

Frozen semantics:

| Field | Required value |
|---|---|
| `authorizationApproved` | `false` |
| `executionApproved` | `false` |
| `executeReady` | `false` |
| `trueExecution` | `false` |
| `mutationCount` | `0` |

## Canonical Gate Group

Canonical group name: `Future True UX Restore quality gates`.

Group membership is defined by quality gate IDs that start with `future-true-ux`. These gates are report-only PR-fast guardrails for future true UX restore preparation. They are not execution approval, real restore evidence, completion evidence, or Issue closure evidence.

All gates in this group must remain:

- `layer`: `pr-fast`
- `trigger`: `pull_request`
- `mode`: `report-only`
- `required`: `true`
- `blocking`: `true`

Any exception must be documented in this file before it is changed in `manifests/quality-gates.json`.

## Intended Gate Order

| Order | Gate ID | Role |
|---|---|---|
| 1 | `future-true-ux-restore-split` | Establishes the split between Issue #18 report-only readiness and any future true UX mutation chain. |
| 2 | `future-true-ux-restore-authorization` | Authorization intake and frozen execution flags. |
| 3 | `future-true-ux-restore-evidence-model` | Evidence boundary before any future mutation can be considered. |
| 4 | `future-true-ux-current-user-dry-run` | Current-user dry-run gate. |
| 5 | `future-true-ux-scope-dry-run` | Default-user, offline-image, and machine dry-run gates. |
| 6 | `future-true-ux-scope-guard-matrix` | Scope separation and evidence-substitution guard. |
| 7 | `future-true-ux-execute-gate` | Dual approval rule that keeps authorization and execution approval separate. |
| 8 | `future-true-ux-authorization-review` | Review workflow for authorization packets. |
| 9 | `future-true-ux-evidence-packet` | Evidence packet contract used by review and no-execution gates. |
| 10 | `future-true-ux-end-to-end-no-execution-readiness-audit` | End-to-end no-execution readiness audit. |
| 11 | `future-true-ux-final-stop-line-handoff` | Final stop-line handoff and fresh-runner-boundary guard. |

The recommended high-level order is authorization intake, dry-run gates, authorization review, end-to-end readiness audit, and final stop-line. The additional split, evidence model, scope guard, execute gate, and evidence packet gates are placed next to the phase they constrain. The former mock review drill, mock decision ledger, negative-review, approval-checklist, packet-preview, and human-handoff intermediate gates were removed by the Issue #121 prune because they were preparation-only stage gates, not long-term operator entrypoints.

## Naming Policy

New Future True UX Restore gate IDs should use:

```text
future-true-ux-<phase-or-scope>-<short-purpose>
```

Use lowercase ASCII, hyphen separators, and stable semantic names. Prefer `future-true-ux-restore-*` only for broad chain-level anchors that existed before this policy or truly describe the whole restore chain.

Existing historical IDs are intentionally kept stable in this task. They are referenced by Build Lock, Pester, reports, docs, and PR history. Do not rename an existing gate only for style.

## Demotion And Archive Policy

A gate can be demoted from required PR-fast coverage to manual/archive only when all of these are true:

1. A later canonical gate preserves the same safety invariant.
2. The demotion has an explicit governance document update.
3. Build Lock, Pester, README, and report builders are updated in the same PR if they reference the gate.
4. The PR proves that `execute-ready`, real restore evidence, Issue auto-close language, and true execution remain blocked.
5. The PR does not hide or remove final stop-line coverage.

Preparation-only stage gates must not be kept resident only for historical traceability. Future demotions should still update Build Lock, tests, and docs atomically, but they do not need to preserve an archive reference map when Git history already carries the deleted stage details.

## Blocked Language And Execution Boundary

Future True UX Restore quality gates must continue to block:

- `execute-ready` promotion without a separate high-risk chain;
- command exit code as real UX restore evidence;
- report-only fixtures as real restore evidence;
- Issue #18 or Issue #19 auto-close wording;
- registry, DISM, AppX, Defender, Junction, Service, Sysprep, installer, download, Start menu, taskbar, default-app, profile, image servicing, WinPE execution, or true UX restore execution.

This governance task is limited to docs, `manifests/quality-gates.json`, Build Lock refresh, and Pester/report-only validation.

## Next Governance Task

Recommended next task: continue Issue #121 with the next deletion-first surface, while preserving final stop-line and no-true-execution coverage.
