# Future True UX Quality Gate Governance

Status: `future-true-ux-quality-gate-governance`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Scope

This policy groups and names the Future True UX Restore quality gates after the repository governance audit. It keeps the current safety net intact while making `manifests/quality-gates.json` easier to read and audit.

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
| 9 | `future-true-ux-evidence-packet` | Evidence packet contract used by review and drill gates. |
| 10 | `future-true-ux-mock-review-drill` | Positive mock review drill. |
| 11 | `future-true-ux-mock-decision-ledger` | Mock decision record; kept beside the mock review drill. |
| 12 | `future-true-ux-negative-review-drill` | Negative review drill for blocked or unsafe packet states. |
| 13 | `future-true-ux-approval-checklist-ergonomics` | Maintainer approval checklist readability and decision safety. |
| 14 | `future-true-ux-integrated-packet-preview` | Integrated packet preview consistency and blocker visibility. |
| 15 | `future-true-ux-human-authorization-handoff` | Human authorization handoff packet safety. |
| 16 | `future-true-ux-end-to-end-no-execution-readiness-audit` | End-to-end no-execution readiness audit. |
| 17 | `future-true-ux-final-stop-line-handoff` | Final stop-line handoff and fresh-runner-boundary guard. |

The recommended high-level order is authorization intake, dry-run gates, authorization review, mock drill, negative drill, approval checklist, packet preview, human handoff, end-to-end readiness audit, and final stop-line. The additional split, evidence model, scope guard, execute gate, evidence packet, and mock decision gates are placed next to the phase they constrain.

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

Historical drill, packet-preview, handoff, and audit gates remain required until an archive policy and reference map prove they are safe to demote.

## Blocked Language And Execution Boundary

Future True UX Restore quality gates must continue to block:

- `execute-ready` promotion without a separate high-risk chain;
- command exit code as real UX restore evidence;
- report-only fixtures as real restore evidence;
- Issue #18 or Issue #19 auto-close wording;
- registry, DISM, AppX, Defender, Junction, Service, Sysprep, installer, download, Start menu, taskbar, default-app, profile, image servicing, WinPE execution, or true UX restore execution.

This governance task is limited to docs, `manifests/quality-gates.json`, Build Lock refresh, and Pester/report-only validation.

## Next Governance Task

Recommended next task: Future True UX Archive Policy & Reference Map.

That task should map superseded stage documents and references before any archive move. It should not move files until README, Build Lock, Pester, Quality Gates, and report-builder references are ready to update atomically.
