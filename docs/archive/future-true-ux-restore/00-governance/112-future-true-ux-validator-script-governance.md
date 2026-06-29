# Future True UX Validator Script Governance

Status: `future-true-ux-validator-script-governance`
Issue: Refs #19
Date: 2026-06-29

## Boundary

This audit keeps Future True UX Restore in report-only governance. It does not authorize true execution, evidence promotion, Issue auto-close, execute-ready state drift, workflow changes, or quality gate demotion.

The root `docs/` directory remains reserved for Chinese primary documents, current entrypoints, and `docs/README.md`. This governance record is archived under `docs/archive/future-true-ux-restore/00-governance/` with the other current Future True UX governance documents.

## Frozen Execution State

| Field | Required value |
|---|---|
| `authorizationApproved` | `false` |
| `executionApproved` | `false` |
| `executeReady` | `false` |
| `trueExecution` | `false` |
| `mutationCount` | `0` |

The shared helper `scripts/common/FutureTrueUxRestore.Guards.ps1` centralizes only report-time guard values and matching helpers:

| Helper | Purpose | Mutation boundary |
|---|---|---|
| `Get-FutureTrueUxRestoreFrozenFlagNames` | Returns frozen boolean flag names used by review reports. | No mutation. |
| `New-FutureTrueUxRestoreFrozenExecutionState` | Returns the canonical false/zero execution state object. | No mutation. |
| `Test-FutureTrueUxRestoreTruthy` | Normalizes truthy fixture values for negative review guard checks. | No mutation. |
| `Get-FutureTrueUxRestoreDangerousVocabularyPattern` | Provides the blocked high-risk vocabulary regex for report-only review scanning. | No mutation. |

## Reference Map

| Gate ID | Current entrypoint | Mode | Consolidation note |
|---|---|---|---|
| `future-true-ux-restore-split` | `docs/archive/future-true-ux-restore/00-governance/65-future-true-ux-restore-execution-split.md` | `report-only` | Document-only gate. |
| `future-true-ux-restore-authorization` | `scripts/validate/Test-FutureTrueUxRestoreAuthorization.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-restore-evidence-model` | `docs/archive/future-true-ux-restore/00-governance/67-future-true-ux-restore-evidence-model.md` | `report-only` | Document-only gate. |
| `future-true-ux-current-user-dry-run` | `scripts/validate/Test-FutureTrueUxRestoreCurrentUserDryRun.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-scope-dry-run` | `scripts/validate/Test-FutureTrueUxRestoreScopeDryRun.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-scope-guard-matrix` | `docs/archive/future-true-ux-restore/00-governance/75-future-true-ux-restore-scope-guard-matrix.md` | `report-only` | Document-only gate. |
| `future-true-ux-execute-gate` | `docs/archive/future-true-ux-restore/00-governance/71-future-true-ux-restore-execute-gate-dual-approval.md` | `report-only` | Document-only gate; no execute-ready promotion. |
| `future-true-ux-authorization-review` | `scripts/validate/Test-FutureTrueUxRestoreAuthorizationReview.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-evidence-packet` | `docs/archive/future-true-ux-restore/00-governance/78-future-true-ux-restore-evidence-packet-contract.md` | `report-only` | Document-only gate. |
| `future-true-ux-mock-review-drill` | `scripts/validate/Test-FutureTrueUxRestoreMockReviewDrill.ps1` | `report-only` | Uses shared frozen execution state helper. |
| `future-true-ux-mock-decision-ledger` | `docs/archive/future-true-ux-restore/01-mock-review/82-future-true-ux-restore-mock-decision-ledger.md` | `report-only` | Document-only gate. |
| `future-true-ux-negative-review-drill` | `scripts/validate/Test-FutureTrueUxRestoreNegativeReviewDrill.ps1` | `report-only` | Uses shared truthy and high-risk vocabulary helpers. |
| `future-true-ux-approval-checklist-ergonomics` | `scripts/validate/Test-FutureTrueUxRestoreApprovalChecklistErgonomics.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-integrated-packet-preview` | `scripts/validate/Test-FutureTrueUxRestoreIntegratedPacketPreview.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-human-authorization-handoff` | `scripts/validate/Test-FutureTrueUxRestoreHumanAuthorizationHandoff.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-end-to-end-no-execution-readiness-audit` | `scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-final-stop-line-handoff` | `scripts/validate/Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1` | `report-only` | Final stop-line remains protected. |

## Findings

The script surface has deliberate duplication around frozen execution flags and blocked execution vocabulary. A small helper extraction is safe because it only returns static values or regex text, and because the quality gate manifest still points at the existing validators and documents.

No validate entrypoint was renamed or consolidated. The new helper is used by mock review and negative review reports only, where the repeated values were already local report-only guard data.

## Guardrails

The Pester coverage in `tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1` guards:

- every Future True UX gate remains `report-only`, `pr-fast`, `pull_request`, required, and blocking;
- every Future True UX gate entrypoint still exists;
- validator entrypoints do not contain direct dangerous action commands;
- the governance record contains `Refs #19` without close keywords;
- frozen execution flags remain false/zero;
- Build Lock tracks this governance document, helper, changed report helpers, and the governance test.

## Next Recommended Task

The next task should audit whether the remaining repeated frozen-flag checks in packet preview, handoff, final stop-line, and no-execution audit reports can call the shared helper without changing any report schema or quality gate entrypoint.
