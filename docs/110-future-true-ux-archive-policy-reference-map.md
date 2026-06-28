# Future True UX Archive Policy & Reference Map

Status: `future-true-ux-archive-policy-reference-map`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Purpose And Scope

This map records how Future True UX Restore documents and validators are referenced before any archive move is attempted. It follows the repository governance audit and the Future True UX quality gate governance policy.

This is a map-first task. It does not move files into `docs/archive/`, delete files, demote gates, rename gate IDs, change workflow behavior, or authorize true UX restore planning.

## No True Execution Boundary

Frozen semantics:

| Field | Required value |
|---|---|
| `authorizationApproved` | `false` |
| `executionApproved` | `false` |
| `executeReady` | `false` |
| `trueExecution` | `false` |
| `mutationCount` | `0` |

This task does not authorize UX restore, VM mutation, image servicing, package install, download, network call, registry edit, AppX change, Defender change, Start menu change, taskbar change, default app change, Sysprep, DISM, WinPE execution, service change, or Issue #19 closure.

## Reference Classes

Every future archive proposal must check these reference classes before moving a file:

| Reference class | Source to check | Required archive action |
|---|---|---|
| README reference | `README.md` | Update links and wording in the same PR. |
| AGENTS reference | `AGENTS.md` and nested `AGENTS.md` files if any | Update rules only when the moved document remains policy-relevant. |
| Quality Gates entrypoint | `manifests/quality-gates.json` | Update entrypoint and keep report-only safety semantics. |
| Build Lock entry | `manifests/build-lock.json` | Update path and hash in the same PR. |
| Pester explicit path assertion | `tests/pester/*.Tests.ps1` | Update literal path expectations and safety assertions in the same PR. |
| Script/report-builder reference | `scripts/common/*.ps1`, `scripts/validate/*.ps1`, `scripts/config/*.ps1` | Update report builders, default referenced documents, and validation output. |
| Validator default path | `scripts/validate/*.ps1` parameters or embedded report helper defaults | Update only when report output remains identical except paths. |
| Manifest/schema reference | `manifests/*.json`, `schemas/*.json` | Update manifest document lists and schema-linked fixtures. |
| Docs cross-link | `docs/*.md` | Update source and target links atomically. |

## Classification Of Docs 64-109

| Category | Documents | Move policy |
|---|---|---|
| Canonical active | `docs/64-issue18-manual-closure-handoff.md`, `docs/65-future-true-ux-restore-execution-split.md`, `docs/66-future-true-ux-restore-authorization-intake.md`, `docs/67-future-true-ux-restore-evidence-model.md`, `docs/68-future-true-ux-restore-dry-run-plan.md`, `docs/106-future-true-ux-restore-final-stop-line-handoff.md`, `docs/107-future-true-ux-restore-stop-line-decision-matrix.md`, `docs/108-repo-documentation-script-governance-audit.md`, `docs/109-future-true-ux-quality-gate-governance.md` | Must stay in place. These are README-linked entrypoints, current governance anchors, or final stop-line controls. |
| Active safety guardrail | `docs/69-future-true-ux-restore-current-user-dry-run-gate.md`, `docs/70-future-true-ux-restore-current-user-evidence-contract.md`, `docs/71-future-true-ux-restore-execute-gate-dual-approval.md`, `docs/72-future-true-ux-restore-default-user-dry-run-gate.md`, `docs/73-future-true-ux-restore-offline-image-dry-run-gate.md`, `docs/74-future-true-ux-restore-machine-dry-run-gate.md`, `docs/75-future-true-ux-restore-scope-guard-matrix.md`, `docs/76-future-true-ux-restore-unified-authorization-request.md`, `docs/77-future-true-ux-restore-maintainer-review-checkpoint.md`, `docs/78-future-true-ux-restore-evidence-packet-contract.md`, `docs/79-future-true-ux-restore-authorization-state-machine.md` | Keep active until later gates and tests preserve the same no-execution and evidence-boundary checks. |
| Historical stage evidence / archive candidate | `docs/80-future-true-ux-restore-mock-review-packet-drill.md` through `docs/105-future-true-ux-restore-no-execution-stop-line.md` | Candidate only. Do not move yet. These files are still referenced by Build Lock, Pester, manifests, and in some cases report-builder logic. |
| Must not move until references are updated | Every file in `docs/64` through `docs/109` | No move in this task. A later archive PR must update all reference classes atomically. |
| Delete candidates | None | No deletion is safe in this task. Deletion would require a later PR proving the reference was removed and the safety invariant is preserved. |

## Archive Candidate Reference Map

Legend: yes means the class currently references the file. no means this map did not find that class reference during this task. Can move now is intentionally no for every row.

| Archive candidate | README | AGENTS | Quality Gates | Build Lock | Pester | Scripts | Manifest/schema | Docs cross-link | Can move now |
|---|---|---|---|---|---|---|---|---|---|
| `docs/80-future-true-ux-restore-mock-review-packet-drill.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/82-future-true-ux-restore-mock-decision-ledger.md` | no | no | yes | yes | yes | no | yes | no | no |
| `docs/83-future-true-ux-restore-mock-drill-lessons.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/84-future-true-ux-restore-negative-review-drill-bundle.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/85-future-true-ux-restore-negative-review-transcript.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/86-future-true-ux-restore-negative-decision-ledger.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/87-future-true-ux-restore-negative-drill-lessons.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/89-future-true-ux-restore-review-packet-readability-guide.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/90-future-true-ux-restore-manual-decision-form-template.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/91-future-true-ux-restore-approval-checklist-lessons.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/93-future-true-ux-restore-packet-preview-field-map.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/95-future-true-ux-restore-packet-preview-blocker-index.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/96-future-true-ux-restore-packet-preview-lessons.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/97-future-true-ux-restore-human-authorization-handoff.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/98-future-true-ux-restore-human-handoff-artifact-index.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/100-future-true-ux-restore-human-handoff-review-boundary.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/101-future-true-ux-restore-human-handoff-lessons.md` | no | no | no | yes | yes | no | yes | no | no |
| `docs/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | no | no | no | yes | yes | yes | yes | no | no |
| `docs/103-future-true-ux-restore-state-name-separation-matrix.md` | no | no | no | yes | yes | yes | yes | no | no |
| `docs/104-future-true-ux-restore-artifact-chain-consistency-index.md` | no | no | no | yes | yes | yes | yes | no | no |
| `docs/105-future-true-ux-restore-no-execution-stop-line.md` | no | no | no | yes | yes | yes | yes | no | no |

## Quality Gate Coverage

The archive map intentionally covers all current Future True UX quality gates from `docs/109-future-true-ux-quality-gate-governance.md`:

| Gate ID | Current archive-policy coverage |
|---|---|
| `future-true-ux-restore-split` | Canonical active; do not move. |
| `future-true-ux-restore-authorization` | Canonical or active safety guardrail; do not move referenced docs or validators. |
| `future-true-ux-restore-evidence-model` | Canonical active; do not move. |
| `future-true-ux-current-user-dry-run` | Active safety guardrail; do not move. |
| `future-true-ux-scope-dry-run` | Active safety guardrail; do not move. |
| `future-true-ux-scope-guard-matrix` | Active safety guardrail; do not move. |
| `future-true-ux-execute-gate` | Active safety guardrail; do not move. |
| `future-true-ux-authorization-review` | Active safety guardrail; do not move. |
| `future-true-ux-evidence-packet` | Active safety guardrail; do not move. |
| `future-true-ux-mock-review-drill` | Historical stage evidence; archive candidate only after references are updated. |
| `future-true-ux-mock-decision-ledger` | Historical stage evidence; archive candidate only after references are updated. |
| `future-true-ux-negative-review-drill` | Historical stage evidence; archive candidate only after references are updated. |
| `future-true-ux-approval-checklist-ergonomics` | Historical stage evidence; archive candidate only after references are updated. |
| `future-true-ux-integrated-packet-preview` | Historical stage evidence; archive candidate only after references are updated. |
| `future-true-ux-human-authorization-handoff` | Historical stage evidence; archive candidate only after references are updated. |
| `future-true-ux-end-to-end-no-execution-readiness-audit` | Historical stage evidence plus script references; archive candidate only after references are updated. |
| `future-true-ux-final-stop-line-handoff` | Canonical active; do not move. |

## Recommended Atomic Archive Procedure

1. Start from this reference map and re-run reference discovery on the current branch.
2. Pick one narrow document family, such as mock review, negative review, packet preview, human handoff, or no-execution audit supporting docs.
3. Prepare a dry-run move plan that lists old paths, proposed archive paths, and every reference class that must change.
4. Update README, docs cross-links, Quality Gates, Build Lock, Pester tests, report builders, validators, and manifests in the same PR when applicable.
5. Prove no gate changes from report-only, required, blocking, and pull-request semantics unless a separate governance task explicitly authorizes demotion.
6. Prove no `execute-ready`, true execution, real restore evidence, or Issue auto-close wording was introduced.
7. Only after the dry-run plan is accepted should a separate task card authorize actual file moves.

## Files That Must Not Move Yet

Do not move any file in `docs/64` through `docs/109` until a later PR updates all affected reference classes. In particular:

- Quality Gate entrypoint docs: `docs/64`, `docs/65`, `docs/67`, `docs/71`, `docs/75`, `docs/78`, `docs/82`.
- README-linked docs: `docs/64`, `docs/65`, `docs/66`, `docs/67`, `docs/68`.
- Script-referenced stop-line and no-execution docs: `docs/102`, `docs/103`, `docs/104`, `docs/105`, `docs/106`, `docs/107`.
- Governance docs: `docs/108`, `docs/109`, and this document once it is added to Build Lock.

## Next Governance Task

Recommended next task: Future True UX Archive Dry-Run Plan.

That task should propose the exact archive directory structure and a dry-run move plan. It should still avoid moving files unless the task card explicitly authorizes the move and the reference map proves the move is safe.
