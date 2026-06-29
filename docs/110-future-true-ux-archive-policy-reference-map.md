# Future True UX Archive Policy & Reference Map

Status: `future-true-ux-archive-policy-reference-map`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Purpose And Scope

This map records the current post-move location and reference classes for archived Future True UX Restore stage documents. It follows the repository governance audit, the Future True UX quality gate governance policy, and the archive dry-run plan.

The docs governance implementation moved the superseded stage documents from root `docs/80` through `docs/105` into `docs/archive/future-true-ux-restore/`. This document does not demote gates, rename gate IDs, change workflow behavior, delete files, or authorize true UX restore planning.

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

Every future archive restructuring proposal must check these reference classes before moving or renaming a file:

| Reference class | Source to check | Required archive action |
|---|---|---|
| README reference | `README.md` | Update links and wording in the same PR. |
| AGENTS reference | `AGENTS.md` and nested `AGENTS.md` files if any | Update rules only when the moved document remains policy-relevant. |
| Docs index | `docs/README.md` | Keep canonical and archive entrypoints accurate. |
| Quality Gates entrypoint | `manifests/quality-gates.json` | Update entrypoint and keep report-only safety semantics. |
| Build Lock entry | `manifests/build-lock.json` | Update path and hash in the same PR. |
| Pester explicit path assertion | `tests/pester/*.Tests.ps1` | Update literal path expectations and safety assertions in the same PR. |
| Script/report-builder reference | `scripts/common/*.ps1`, `scripts/validate/*.ps1`, `scripts/config/*.ps1` | Update report builders, default referenced documents, and validation output. |
| Validator default path | `scripts/validate/*.ps1` parameters or embedded report helper defaults | Update only when report output remains identical except paths. |
| Manifest/schema reference | `manifests/*.json`, `schemas/*.json` | Update manifest document lists and schema-linked fixtures. |
| Docs cross-link | `docs/*.md` | Update source and target links atomically. |

## Classification Of Future True UX Docs

| Category | Documents | Move policy |
|---|---|---|
| Canonical active | `docs/64-issue18-manual-closure-handoff.md`, `docs/65-future-true-ux-restore-execution-split.md`, `docs/66-future-true-ux-restore-authorization-intake.md`, `docs/67-future-true-ux-restore-evidence-model.md`, `docs/68-future-true-ux-restore-dry-run-plan.md`, `docs/106-future-true-ux-restore-final-stop-line-handoff.md`, `docs/107-future-true-ux-restore-stop-line-decision-matrix.md`, `docs/108-repo-documentation-script-governance-audit.md`, `docs/109-future-true-ux-quality-gate-governance.md`, `docs/110-future-true-ux-archive-policy-reference-map.md`, `docs/111-future-true-ux-archive-dry-run-plan.md` | Must stay in root. These are README-linked entrypoints, current governance anchors, final stop-line controls, or archive governance records. |
| Active safety guardrail | `docs/69-future-true-ux-restore-current-user-dry-run-gate.md` through `docs/79-future-true-ux-restore-authorization-state-machine.md` | Keep active until later gates and tests preserve the same no-execution and evidence-boundary checks. |
| Archived historical stage evidence | `docs/archive/future-true-ux-restore/01-mock-review/` through `docs/archive/future-true-ux-restore/06-no-execution-audit/` | Historical reference only. These documents remain locked and tested but are no longer root planning entrypoints. |
| Delete candidates | None | No deletion is safe in this governance task. Deletion would require a later PR proving the reference was removed and the safety invariant is preserved. |

## Archived Stage Reference Map

Legend: yes means the class currently references the archived file. no means this map did not find that class reference during this task. Future restructuring should preserve the same reference classes unless a separate governance task explicitly demotes them.

| Archived path | Former root path | Family | Quality Gates | Build Lock | Pester | Scripts | Manifest/schema | Future restructuring action |
|---|---|---|---|---|---|---|---|---|
| `docs/archive/future-true-ux-restore/01-mock-review/80-future-true-ux-restore-mock-review-packet-drill.md` | `docs/80-future-true-ux-restore-mock-review-packet-drill.md` | Mock review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/01-mock-review/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | `docs/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | Mock review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/01-mock-review/82-future-true-ux-restore-mock-decision-ledger.md` | `docs/82-future-true-ux-restore-mock-decision-ledger.md` | Mock review | yes | yes | yes | no | yes | Update Quality Gates, Build Lock, Pester, and manifests atomically if moved again. |
| `docs/archive/future-true-ux-restore/01-mock-review/83-future-true-ux-restore-mock-drill-lessons.md` | `docs/83-future-true-ux-restore-mock-drill-lessons.md` | Mock review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/02-negative-review/84-future-true-ux-restore-negative-review-drill-bundle.md` | `docs/84-future-true-ux-restore-negative-review-drill-bundle.md` | Negative review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/02-negative-review/85-future-true-ux-restore-negative-review-transcript.md` | `docs/85-future-true-ux-restore-negative-review-transcript.md` | Negative review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/02-negative-review/86-future-true-ux-restore-negative-decision-ledger.md` | `docs/86-future-true-ux-restore-negative-decision-ledger.md` | Negative review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/02-negative-review/87-future-true-ux-restore-negative-drill-lessons.md` | `docs/87-future-true-ux-restore-negative-drill-lessons.md` | Negative review | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/03-approval-checklist/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | `docs/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | Approval checklist | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/03-approval-checklist/89-future-true-ux-restore-review-packet-readability-guide.md` | `docs/89-future-true-ux-restore-review-packet-readability-guide.md` | Approval checklist | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/03-approval-checklist/90-future-true-ux-restore-manual-decision-form-template.md` | `docs/90-future-true-ux-restore-manual-decision-form-template.md` | Approval checklist | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/03-approval-checklist/91-future-true-ux-restore-approval-checklist-lessons.md` | `docs/91-future-true-ux-restore-approval-checklist-lessons.md` | Approval checklist | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/04-packet-preview/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | `docs/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | Packet preview | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/04-packet-preview/93-future-true-ux-restore-packet-preview-field-map.md` | `docs/93-future-true-ux-restore-packet-preview-field-map.md` | Packet preview | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/04-packet-preview/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | `docs/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | Packet preview | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/04-packet-preview/95-future-true-ux-restore-packet-preview-blocker-index.md` | `docs/95-future-true-ux-restore-packet-preview-blocker-index.md` | Packet preview | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/04-packet-preview/96-future-true-ux-restore-packet-preview-lessons.md` | `docs/96-future-true-ux-restore-packet-preview-lessons.md` | Packet preview | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/05-human-handoff/97-future-true-ux-restore-human-authorization-handoff.md` | `docs/97-future-true-ux-restore-human-authorization-handoff.md` | Human handoff | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/05-human-handoff/98-future-true-ux-restore-human-handoff-artifact-index.md` | `docs/98-future-true-ux-restore-human-handoff-artifact-index.md` | Human handoff | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/05-human-handoff/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | `docs/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | Human handoff | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/05-human-handoff/100-future-true-ux-restore-human-handoff-review-boundary.md` | `docs/100-future-true-ux-restore-human-handoff-review-boundary.md` | Human handoff | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/05-human-handoff/101-future-true-ux-restore-human-handoff-lessons.md` | `docs/101-future-true-ux-restore-human-handoff-lessons.md` | Human handoff | no | yes | yes | no | yes | Update all references atomically if moved again. |
| `docs/archive/future-true-ux-restore/06-no-execution-audit/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | `docs/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | No-execution audit | no | yes | yes | yes | yes | Update report helper, Build Lock, Pester, and manifests atomically if moved again. |
| `docs/archive/future-true-ux-restore/06-no-execution-audit/103-future-true-ux-restore-state-name-separation-matrix.md` | `docs/103-future-true-ux-restore-state-name-separation-matrix.md` | No-execution audit | no | yes | yes | yes | yes | Update report helper, Build Lock, Pester, and manifests atomically if moved again. |
| `docs/archive/future-true-ux-restore/06-no-execution-audit/104-future-true-ux-restore-artifact-chain-consistency-index.md` | `docs/104-future-true-ux-restore-artifact-chain-consistency-index.md` | No-execution audit | no | yes | yes | yes | yes | Update report helper, Build Lock, Pester, and manifests atomically if moved again. |
| `docs/archive/future-true-ux-restore/06-no-execution-audit/105-future-true-ux-restore-no-execution-stop-line.md` | `docs/105-future-true-ux-restore-no-execution-stop-line.md` | No-execution audit | no | yes | yes | yes | yes | Update report helper, Build Lock, Pester, and manifests atomically if moved again. |

## Quality Gate Coverage

The archive map intentionally covers all current Future True UX quality gates from `docs/109-future-true-ux-quality-gate-governance.md`:

| Gate ID | Current archive-policy coverage |
|---|---|
| `future-true-ux-restore-split` | Canonical active; keep in root. |
| `future-true-ux-restore-authorization` | Canonical or active safety guardrail; keep referenced docs and validators active. |
| `future-true-ux-restore-evidence-model` | Canonical active; keep in root. |
| `future-true-ux-current-user-dry-run` | Active safety guardrail; keep in root. |
| `future-true-ux-scope-dry-run` | Active safety guardrail; keep in root. |
| `future-true-ux-scope-guard-matrix` | Active safety guardrail; keep in root. |
| `future-true-ux-execute-gate` | Active safety guardrail; keep in root. |
| `future-true-ux-authorization-review` | Active safety guardrail; keep in root. |
| `future-true-ux-evidence-packet` | Active safety guardrail; keep in root. |
| `future-true-ux-mock-review-drill` | Historical stage evidence; archived and still report-only. |
| `future-true-ux-mock-decision-ledger` | Historical stage evidence; archived entrypoint and still report-only. |
| `future-true-ux-negative-review-drill` | Historical stage evidence; archived and still report-only. |
| `future-true-ux-approval-checklist-ergonomics` | Historical stage evidence; archived and still report-only. |
| `future-true-ux-integrated-packet-preview` | Historical stage evidence; archived and still report-only. |
| `future-true-ux-human-authorization-handoff` | Historical stage evidence; archived and still report-only. |
| `future-true-ux-end-to-end-no-execution-readiness-audit` | Historical stage evidence plus script references; archived and still report-only. |
| `future-true-ux-final-stop-line-handoff` | Canonical active; keep in root. |

All Future True UX gates remain `layer=pr-fast`, `trigger=pull_request`, `mode=report-only`, `required=true`, and `blocking=true` unless a separate governance task explicitly authorizes demotion.

## Current Archive Maintenance Procedure

1. Re-run reference discovery on the current branch before moving, renaming, deleting, or demoting any archived document.
2. Update README, docs index, docs cross-links, Quality Gates, Build Lock, Pester tests, report builders, validators, and manifests in the same PR when applicable.
3. Prove no gate changes from report-only, required, blocking, and pull-request semantics unless a separate governance task explicitly authorizes demotion.
4. Prove no `execute-ready`, true execution, real restore evidence, or Issue auto-close wording was introduced.
5. Run docs governance archive tests, Future True UX Pester coverage, Quality Gates validation, Build Lock validation, and `git -c core.quotepath=false diff --check`.

## Files That Must Remain Canonical

Do not move these root files without a separate governance task and atomic reference update:

- Quality Gate entrypoint docs: `docs/64`, `docs/65`, `docs/67`, `docs/71`, `docs/75`, `docs/78`.
- README-linked docs: `docs/64`, `docs/65`, `docs/66`, `docs/67`, `docs/68`.
- Final stop-line docs: `docs/106`, `docs/107`.
- Governance docs: `docs/README.md`, `docs/108`, `docs/109`, `docs/110`, and `docs/111`.

## Next Governance Task

Recommended next task: Future True UX Validator Consolidation Audit.

That task should inspect whether the many `New-FutureTrueUxRestore*.ps1`, `Test-FutureTrueUxRestore*.ps1`, and related Pester fixtures can be consolidated without weakening final stop-line, no-execution, evidence-boundary, and no-auto-close protections.
