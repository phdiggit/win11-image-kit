# Future True UX Archive Dry-Run Plan

Status: `future-true-ux-archive-dry-run-plan`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Purpose And Current State

This document started as the dry-run plan for archiving superseded Future True UX Restore stage documents. The docs governance implementation has now applied that plan for `docs/80` through `docs/105`: the files were moved into `docs/archive/future-true-ux-restore/` and the references were updated atomically.

This remains a governance and archive-maintenance record. It does not authorize true UX restore planning, true execution, real evidence promotion, workflow changes, or Issue #19 closure.

## Stop Lines

- Future True UX stage documents `docs/80` through `docs/105` are no longer root docs.
- The archived files remain historical reference material only.
- No file deletion is authorized by this document.
- No workflow behavior change is authorized by this document.
- No Issue #19 closure is claimed by this document.
- No Future True UX Restore true execution, true restore planning, or real evidence promotion is authorized by this document.

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

## Archive Directory Structure

Current Future True UX archive structure:

```text
docs/archive/future-true-ux-restore/
  01-mock-review/
  02-negative-review/
  03-approval-checklist/
  04-packet-preview/
  05-human-handoff/
  06-no-execution-audit/
```

## Document Families

| Family | Archive subdirectory | Former root documents | Current state |
|---|---|---|---|
| Mock review drill | `docs/archive/future-true-ux-restore/01-mock-review/` | `docs/80` through `docs/83` | archived |
| Negative review drill | `docs/archive/future-true-ux-restore/02-negative-review/` | `docs/84` through `docs/87` | archived |
| Approval checklist ergonomics | `docs/archive/future-true-ux-restore/03-approval-checklist/` | `docs/88` through `docs/91` | archived |
| Integrated packet preview | `docs/archive/future-true-ux-restore/04-packet-preview/` | `docs/92` through `docs/96` | archived |
| Human authorization handoff | `docs/archive/future-true-ux-restore/05-human-handoff/` | `docs/97` through `docs/101` | archived |
| No-execution readiness audit | `docs/archive/future-true-ux-restore/06-no-execution-audit/` | `docs/102` through `docs/105` | archived |

## Implemented Old Path To Archive Path Map

| Old root path | Current archive path | Document family | Reference classes updated |
|---|---|---|---|
| `docs/80-future-true-ux-restore-mock-review-packet-drill.md` | `docs/archive/future-true-ux-restore/01-mock-review/80-future-true-ux-restore-mock-review-packet-drill.md` | Mock review drill | Build Lock, Pester, manifest/schema references |
| `docs/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | `docs/archive/future-true-ux-restore/01-mock-review/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | Mock review drill | Build Lock, Pester, manifest/schema references |
| `docs/82-future-true-ux-restore-mock-decision-ledger.md` | `docs/archive/future-true-ux-restore/01-mock-review/82-future-true-ux-restore-mock-decision-ledger.md` | Mock review drill | Quality Gates, Build Lock, Pester, manifest/schema references |
| `docs/83-future-true-ux-restore-mock-drill-lessons.md` | `docs/archive/future-true-ux-restore/01-mock-review/83-future-true-ux-restore-mock-drill-lessons.md` | Mock review drill | Build Lock, Pester, manifest/schema references |
| `docs/84-future-true-ux-restore-negative-review-drill-bundle.md` | `docs/archive/future-true-ux-restore/02-negative-review/84-future-true-ux-restore-negative-review-drill-bundle.md` | Negative review drill | Build Lock, Pester, manifest/schema references |
| `docs/85-future-true-ux-restore-negative-review-transcript.md` | `docs/archive/future-true-ux-restore/02-negative-review/85-future-true-ux-restore-negative-review-transcript.md` | Negative review drill | Build Lock, Pester, manifest/schema references |
| `docs/86-future-true-ux-restore-negative-decision-ledger.md` | `docs/archive/future-true-ux-restore/02-negative-review/86-future-true-ux-restore-negative-decision-ledger.md` | Negative review drill | Build Lock, Pester, manifest/schema references |
| `docs/87-future-true-ux-restore-negative-drill-lessons.md` | `docs/archive/future-true-ux-restore/02-negative-review/87-future-true-ux-restore-negative-drill-lessons.md` | Negative review drill | Build Lock, Pester, manifest/schema references |
| `docs/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references |
| `docs/89-future-true-ux-restore-review-packet-readability-guide.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/89-future-true-ux-restore-review-packet-readability-guide.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references |
| `docs/90-future-true-ux-restore-manual-decision-form-template.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/90-future-true-ux-restore-manual-decision-form-template.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references |
| `docs/91-future-true-ux-restore-approval-checklist-lessons.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/91-future-true-ux-restore-approval-checklist-lessons.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references |
| `docs/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | `docs/archive/future-true-ux-restore/04-packet-preview/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references |
| `docs/93-future-true-ux-restore-packet-preview-field-map.md` | `docs/archive/future-true-ux-restore/04-packet-preview/93-future-true-ux-restore-packet-preview-field-map.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references |
| `docs/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | `docs/archive/future-true-ux-restore/04-packet-preview/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references |
| `docs/95-future-true-ux-restore-packet-preview-blocker-index.md` | `docs/archive/future-true-ux-restore/04-packet-preview/95-future-true-ux-restore-packet-preview-blocker-index.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references |
| `docs/96-future-true-ux-restore-packet-preview-lessons.md` | `docs/archive/future-true-ux-restore/04-packet-preview/96-future-true-ux-restore-packet-preview-lessons.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references |
| `docs/97-future-true-ux-restore-human-authorization-handoff.md` | `docs/archive/future-true-ux-restore/05-human-handoff/97-future-true-ux-restore-human-authorization-handoff.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references |
| `docs/98-future-true-ux-restore-human-handoff-artifact-index.md` | `docs/archive/future-true-ux-restore/05-human-handoff/98-future-true-ux-restore-human-handoff-artifact-index.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references |
| `docs/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | `docs/archive/future-true-ux-restore/05-human-handoff/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references |
| `docs/100-future-true-ux-restore-human-handoff-review-boundary.md` | `docs/archive/future-true-ux-restore/05-human-handoff/100-future-true-ux-restore-human-handoff-review-boundary.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references |
| `docs/101-future-true-ux-restore-human-handoff-lessons.md` | `docs/archive/future-true-ux-restore/05-human-handoff/101-future-true-ux-restore-human-handoff-lessons.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references |
| `docs/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references |
| `docs/103-future-true-ux-restore-state-name-separation-matrix.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/103-future-true-ux-restore-state-name-separation-matrix.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references |
| `docs/104-future-true-ux-restore-artifact-chain-consistency-index.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/104-future-true-ux-restore-artifact-chain-consistency-index.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references |
| `docs/105-future-true-ux-restore-no-execution-stop-line.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/105-future-true-ux-restore-no-execution-stop-line.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references |

## Future Reference Rewrite Requirements

If any archived family is moved again, rewrite references in the same PR:

- README links.
- AGENTS links.
- `docs/README.md`.
- `manifests/quality-gates.json` entrypoints.
- `manifests/build-lock.json` paths and hashes.
- `tests/pester/*.Tests.ps1` literal path assertions.
- `scripts/common/*.ps1` report helpers.
- `scripts/validate/*.ps1` validators.
- `scripts/config/*.ps1` show helpers.
- manifest/schema document lists.
- docs cross-links.

## Validation Plan For Archive Maintenance

1. Re-run reference discovery on the current branch before moving anything.
2. Update all references listed above in the same PR.
3. Confirm archived files remain historical and do not become current restore instructions.
4. Run targeted Pester tests for the affected family.
5. Run Build Lock and Quality Gates validation after hashes and entrypoints are refreshed.
6. Run `git -c core.quotepath=false diff --name-status` and prove the only moves are the approved archive candidates.
7. Run `git -c core.quotepath=false diff --check`.

## Canonical Files That Must Remain In Place

These files remain canonical and must not be moved by archive-maintenance work:

- `docs/archive/future-true-ux-restore/00-governance/65-future-true-ux-restore-execution-split.md`
- `docs/archive/future-true-ux-restore/00-governance/106-future-true-ux-restore-final-stop-line-handoff.md`
- `docs/archive/future-true-ux-restore/00-governance/107-future-true-ux-restore-stop-line-decision-matrix.md`
- `docs/archive/future-true-ux-restore/00-governance/108-repo-documentation-script-governance-audit.md`
- `docs/archive/future-true-ux-restore/00-governance/109-future-true-ux-quality-gate-governance.md`
- `docs/archive/future-true-ux-restore/00-governance/110-future-true-ux-archive-policy-reference-map.md`
- `docs/archive/future-true-ux-restore/00-governance/111-future-true-ux-archive-dry-run-plan.md`

Also keep `docs/66` through `docs/79` active until a separate task proves the authorization intake and safety guardrail chain can be retargeted without weakening no-execution coverage.

## Recommended Next Task

Recommended next governance task: Future True UX Validator Consolidation Audit.

That task should inspect whether the many `New-FutureTrueUxRestore*.ps1`, `Test-FutureTrueUxRestore*.ps1`, and related Pester fixtures can be consolidated without weakening final stop-line, no-execution, evidence-boundary, and no-auto-close protections.
