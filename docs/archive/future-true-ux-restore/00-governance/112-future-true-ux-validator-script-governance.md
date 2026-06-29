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
| `Get-FutureTrueUxRestoreSupportedScopes` | Returns the allowed report-only scope names used by review packet validators. | No mutation. |
| `Get-FutureTrueUxRestoreGuardValue` | Reads an optional property with a caller-supplied default. | No mutation. |
| `Get-FutureTrueUxRestoreFrozenStateDrift` | Returns the frozen flag and mutation-count fields that drifted from false/zero. | No mutation. |
| `Get-FutureTrueUxRestoreFrozenStateMessages` | Returns blocking-reason text for frozen flag or mutation-count drift. | No mutation. |
| `Test-FutureTrueUxRestoreTruthy` | Normalizes truthy fixture values for negative review guard checks. | No mutation. |
| `Get-FutureTrueUxRestoreDangerousVocabularyPattern` | Provides the blocked high-risk vocabulary regex for report-only review scanning. | No mutation. |
| `Get-FutureTrueUxRestoreIssueAutoClosePattern` | Provides the Issue auto-close wording regex for report/request scans. | No mutation. |
| `Get-FutureTrueUxRestoreReviewStateDriftPattern` | Provides the review-state drift regex for packet, checklist, and handoff scans. | No mutation. |
| `Get-FutureTrueUxRestoreStatePromotionPattern` | Provides the separated-state promotion regex for no-execution audit scans. | No mutation. |
| `Get-FutureTrueUxRestoreEvidencePromotionPattern` | Provides scoped review-material-to-real-evidence promotion regexes while preserving stage-specific wording. | No mutation. |
| `Get-FutureTrueUxRestoreDangerousCommandPatterns` | Provides direct dangerous command regexes for validator self-scans. | No mutation. |
| `Get-FutureTrueUxRestoreDocumentText` | Reads an existing document as UTF-8 text, or returns empty text for missing paths. | No mutation. |
| `Test-FutureTrueUxRestoreStatusMarker` | Checks a document status marker. | No mutation. |

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

## Batch 2 Consolidation

Batch 2 keeps the same validator entrypoints and moves repeated report-only guard logic into the shared helper. The consolidation covers seven report helpers:

- `scripts/common/New-FutureTrueUxRestoreAuthorizationReport.ps1` dot-sources the guard helper for downstream report helpers.
- `scripts/common/New-FutureTrueUxRestoreAuthorizationReviewReport.ps1` now uses shared scope, frozen-state, and Issue auto-close helpers.
- `scripts/common/New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport.ps1` now uses shared scope, frozen-state, review-state drift, and evidence-promotion helpers.
- `scripts/common/New-FutureTrueUxRestoreIntegratedPacketPreviewReport.ps1` now uses shared scope, frozen-state, review-state drift, and evidence-promotion helpers.
- `scripts/common/New-FutureTrueUxRestoreHumanAuthorizationHandoffReport.ps1` now uses shared scope, frozen-state, review-state drift, and evidence-promotion helpers.
- `scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1` now uses shared frozen-state drift, document text, status marker, Issue auto-close, state-promotion, evidence-promotion, and dangerous-command helpers.
- `scripts/common/New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1` now uses shared frozen-state drift, document text, status marker, Issue auto-close, and dangerous-command helpers.

`tests/pester/FutureTrueUxPesterHelpers.ps1` adds Pester-only assertions for governance document boundaries, Future True UX gate semantics, dangerous command scans, and Build Lock path checks. Existing governance tests call this helper instead of repeating the same frozen-state and gate checks.

## Findings

The script surface had deliberate duplication around frozen execution flags, supported scope names, Issue auto-close scans, state-promotion scans, evidence-promotion scans, document status checks, and blocked execution vocabulary. A helper extraction is safe because it only returns static values, text checks, or regex text, and because the quality gate manifest still points at the existing validators and documents.

No validate entrypoint was renamed or consolidated. No quality gate ID, trigger, layer, required/blocking setting, or report-only mode was changed. No report schema field was removed or renamed.

The intentionally unconsolidated surface remains:

- validator entrypoints under `scripts/validate/`;
- quality gate IDs and gate ordering in `manifests/quality-gates.json`;
- report JSON field names consumed by existing Pester and validators;
- GitHub workflow wiring;
- true execution paths, including restore, registry, AppX, Defender, service, WinPE, Sysprep, installer, image, or VM actions.

## Guardrails

The Pester coverage in `tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1` guards:

- every Future True UX gate remains `report-only`, `pr-fast`, `pull_request`, required, and blocking;
- every Future True UX gate entrypoint still exists;
- validator entrypoints do not contain direct dangerous action commands;
- the governance record contains `Refs #19` without close keywords;
- frozen execution flags remain false/zero;
- Build Lock tracks this governance document, helper, changed report helpers, and the governance test.

## Next Recommended Task

The next task should audit whether the Future True UX validator entrypoints can share a small invocation wrapper for manifest loading and report-path emission without changing any report schema, gate entrypoint, or report-only boundary.
