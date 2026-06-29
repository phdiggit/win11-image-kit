# Future True UX Archive Dry-Run Plan

Status: `future-true-ux-archive-dry-run-plan`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Purpose And Scope

This dry-run plan turns the archive policy and reference map into a concrete review plan for superseded Future True UX Restore stage documents. It proposes where archive candidates could move in a later PR, which references must be rewritten atomically, how validation should prove the move, and how rollback would work if a later archive PR fails review.

This PR is plan-only. It does not move, delete, rename, archive, or create archive copies of any file. It does not create `docs/archive/` or any child archive directory.

## Stop Lines

- No file moves are performed in this PR.
- No file deletions are performed in this PR.
- No archive directory is required or created in this PR.
- No workflow behavior changes are made in this PR.
- No Issue #19 closure is claimed by this PR.
- No Future True UX Restore true execution, true restore planning, or real evidence promotion is authorized by this PR.

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

## Proposed Archive Directory Structure

Proposed future structure only:

```text
docs/archive/future-true-ux-restore/
  01-mock-review/
  02-negative-review/
  03-approval-checklist/
  04-packet-preview/
  05-human-handoff/
  06-no-execution-audit/
```

This PR should not create that directory. A later move PR may create only the family directories it actually uses.

## Document Families

| Family | Proposed archive subdirectory | Documents | Move now |
|---|---|---|---|
| Mock review drill | `docs/archive/future-true-ux-restore/01-mock-review/` | `docs/80` through `docs/83` | no |
| Negative review drill | `docs/archive/future-true-ux-restore/02-negative-review/` | `docs/84` through `docs/87` | no |
| Approval checklist ergonomics | `docs/archive/future-true-ux-restore/03-approval-checklist/` | `docs/88` through `docs/91` | no |
| Integrated packet preview | `docs/archive/future-true-ux-restore/04-packet-preview/` | `docs/92` through `docs/96` | no |
| Human authorization handoff | `docs/archive/future-true-ux-restore/05-human-handoff/` | `docs/97` through `docs/101` | no |
| No-execution readiness audit | `docs/archive/future-true-ux-restore/06-no-execution-audit/` | `docs/102` through `docs/105` | no |

## Old Path To Proposed Archive Path Map

Every row is blocked from moving in this PR. The `Can move in this PR` column must remain `no`.

| Old path | Proposed archive path | Document family | Reference blockers | Can move in this PR | Required later PR actions |
|---|---|---|---|---|---|
| `docs/80-future-true-ux-restore-mock-review-packet-drill.md` | `docs/archive/future-true-ux-restore/01-mock-review/80-future-true-ux-restore-mock-review-packet-drill.md` | Mock review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | `docs/archive/future-true-ux-restore/01-mock-review/81-future-true-ux-restore-mock-maintainer-review-transcript.md` | Mock review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/82-future-true-ux-restore-mock-decision-ledger.md` | `docs/archive/future-true-ux-restore/01-mock-review/82-future-true-ux-restore-mock-decision-ledger.md` | Mock review drill | Quality Gates, Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/83-future-true-ux-restore-mock-drill-lessons.md` | `docs/archive/future-true-ux-restore/01-mock-review/83-future-true-ux-restore-mock-drill-lessons.md` | Mock review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/84-future-true-ux-restore-negative-review-drill-bundle.md` | `docs/archive/future-true-ux-restore/02-negative-review/84-future-true-ux-restore-negative-review-drill-bundle.md` | Negative review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/85-future-true-ux-restore-negative-review-transcript.md` | `docs/archive/future-true-ux-restore/02-negative-review/85-future-true-ux-restore-negative-review-transcript.md` | Negative review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/86-future-true-ux-restore-negative-decision-ledger.md` | `docs/archive/future-true-ux-restore/02-negative-review/86-future-true-ux-restore-negative-decision-ledger.md` | Negative review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/87-future-true-ux-restore-negative-drill-lessons.md` | `docs/archive/future-true-ux-restore/02-negative-review/87-future-true-ux-restore-negative-drill-lessons.md` | Negative review drill | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/89-future-true-ux-restore-review-packet-readability-guide.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/89-future-true-ux-restore-review-packet-readability-guide.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/90-future-true-ux-restore-manual-decision-form-template.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/90-future-true-ux-restore-manual-decision-form-template.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/91-future-true-ux-restore-approval-checklist-lessons.md` | `docs/archive/future-true-ux-restore/03-approval-checklist/91-future-true-ux-restore-approval-checklist-lessons.md` | Approval checklist ergonomics | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | `docs/archive/future-true-ux-restore/04-packet-preview/92-future-true-ux-restore-integrated-authorization-packet-preview.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/93-future-true-ux-restore-packet-preview-field-map.md` | `docs/archive/future-true-ux-restore/04-packet-preview/93-future-true-ux-restore-packet-preview-field-map.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | `docs/archive/future-true-ux-restore/04-packet-preview/94-future-true-ux-restore-packet-preview-reviewer-reading-order.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/95-future-true-ux-restore-packet-preview-blocker-index.md` | `docs/archive/future-true-ux-restore/04-packet-preview/95-future-true-ux-restore-packet-preview-blocker-index.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/96-future-true-ux-restore-packet-preview-lessons.md` | `docs/archive/future-true-ux-restore/04-packet-preview/96-future-true-ux-restore-packet-preview-lessons.md` | Integrated packet preview | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/97-future-true-ux-restore-human-authorization-handoff.md` | `docs/archive/future-true-ux-restore/05-human-handoff/97-future-true-ux-restore-human-authorization-handoff.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/98-future-true-ux-restore-human-handoff-artifact-index.md` | `docs/archive/future-true-ux-restore/05-human-handoff/98-future-true-ux-restore-human-handoff-artifact-index.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | `docs/archive/future-true-ux-restore/05-human-handoff/99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/100-future-true-ux-restore-human-handoff-review-boundary.md` | `docs/archive/future-true-ux-restore/05-human-handoff/100-future-true-ux-restore-human-handoff-review-boundary.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/101-future-true-ux-restore-human-handoff-lessons.md` | `docs/archive/future-true-ux-restore/05-human-handoff/101-future-true-ux-restore-human-handoff-lessons.md` | Human authorization handoff | Build Lock, Pester, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/103-future-true-ux-restore-state-name-separation-matrix.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/103-future-true-ux-restore-state-name-separation-matrix.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/104-future-true-ux-restore-artifact-chain-consistency-index.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/104-future-true-ux-restore-artifact-chain-consistency-index.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references | no | Move file and rewrite all reference classes atomically. |
| `docs/105-future-true-ux-restore-no-execution-stop-line.md` | `docs/archive/future-true-ux-restore/06-no-execution-audit/105-future-true-ux-restore-no-execution-stop-line.md` | No-execution readiness audit | Build Lock, Pester, scripts, manifest/schema references | no | Move file and rewrite all reference classes atomically. |

## Reference Rewrite Requirements

The actual archive PR must rewrite references in the same commit or PR that moves files. This dry-run PR does not rewrite these references unless they point to this new plan.

| Document family | References to rewrite in the later archive PR |
|---|---|
| Mock review drill | `manifests/quality-gates.json` for the mock decision ledger entrypoint if moved, `manifests/build-lock.json` paths and hashes, `tests/pester/*.Tests.ps1` literal path assertions, manifest/schema document lists, docs cross-links, and any README/AGENTS links discovered at move time. |
| Negative review drill | `manifests/build-lock.json` paths and hashes, `tests/pester/*.Tests.ps1` literal path assertions, manifest/schema document lists, docs cross-links, and any README/AGENTS links discovered at move time. |
| Approval checklist ergonomics | `manifests/build-lock.json` paths and hashes, `tests/pester/*.Tests.ps1` literal path assertions, manifest/schema document lists, docs cross-links, and any README/AGENTS links discovered at move time. |
| Integrated packet preview | `manifests/build-lock.json` paths and hashes, `tests/pester/*.Tests.ps1` literal path assertions, manifest/schema document lists, docs cross-links, and any README/AGENTS links discovered at move time. |
| Human authorization handoff | `manifests/build-lock.json` paths and hashes, `tests/pester/*.Tests.ps1` literal path assertions, manifest/schema document lists, docs cross-links, and any README/AGENTS links discovered at move time. |
| No-execution readiness audit | `manifests/build-lock.json` paths and hashes, `tests/pester/*.Tests.ps1` literal path assertions, `scripts/common/*.ps1` report helpers, `scripts/validate/*.ps1` validators, `scripts/config/*.ps1` show helpers if any become linked, manifest/schema document lists, docs cross-links, and any README/AGENTS links discovered at move time. |

Minimum reference classes to re-check immediately before any later move:

- README links.
- AGENTS links.
- `manifests/quality-gates.json` entrypoints.
- `manifests/build-lock.json` paths and hashes.
- `tests/pester/*.Tests.ps1` literal path assertions.
- `scripts/common/*.ps1` report helpers.
- `scripts/validate/*.ps1` validators.
- `scripts/config/*.ps1` show helpers.
- manifest/schema document lists.
- docs cross-links.

## Validation Plan For Later Move PR

1. Re-run reference discovery on the current branch before moving anything.
2. Move only one document family per PR unless the task card explicitly widens scope.
3. Update all references listed above in the same PR.
4. Confirm moved files keep historical status and do not become current restore instructions.
5. Run targeted Pester tests for the affected family.
6. Run Build Lock and Quality Gates validation after hashes and entrypoints are refreshed.
7. Run `git -c core.quotepath=false diff --name-status` and prove the only moves are the approved archive candidates.
8. Run `git -c core.quotepath=false diff --check`.

Suggested validation for this dry-run PR:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate\Test-ProjectConfig.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate\Test-QualityGates.ps1 -ReportPath .tmp\quality-gates-future-ux-archive-dryrun.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate\Test-BuildLock.ps1 -ReportPath .tmp\build-lock-future-ux-archive-dryrun.json
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Path tests\pester\FutureTrueUxArchiveDryRunPlan.Tests.ps1"
git -c core.quotepath=false diff --check
```

## Rollback Plan For Later Move PR

If a later archive move PR fails validation or review:

1. Revert the file moves and reference rewrites together.
2. Restore `manifests/build-lock.json` paths and hashes to the pre-move paths.
3. Restore Quality Gates entrypoints to their pre-move paths.
4. Restore Pester literal path assertions and report-helper defaults.
5. Re-run the same targeted Pester, Build Lock, Quality Gates, and diff checks.
6. Leave this dry-run plan unchanged unless the failure exposes a missing reference class.

## Canonical Files That Must Remain In Place

These files remain canonical and must not be moved by this dry-run PR:

- `docs/65-future-true-ux-restore-execution-split.md`
- `docs/106-future-true-ux-restore-final-stop-line-handoff.md`
- `docs/107-future-true-ux-restore-stop-line-decision-matrix.md`
- `docs/108-repo-documentation-script-governance-audit.md`
- `docs/109-future-true-ux-quality-gate-governance.md`
- `docs/110-future-true-ux-archive-policy-reference-map.md`
- `docs/111-future-true-ux-archive-dry-run-plan.md`

Also keep `docs/66` through `docs/79` active until a separate task proves the authorization intake and safety guardrail chain can be retargeted without weakening no-execution coverage.

## Recommended Next Task

Recommended next governance task: Future True UX Archive Move Batch 1 for mock review and negative review stage docs.

That later task should move only the lowest-risk historical stage families, update README, Build Lock, Quality Gates, Pester, report-helper, validator, manifest/schema, and docs references atomically where applicable, and keep all true execution semantics frozen.

Default starting batch: mock review drill only (`docs/80` through `docs/83`). Add negative review drill (`docs/84` through `docs/87`) only if the task card explicitly authorizes a wider first move batch.
