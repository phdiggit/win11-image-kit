# Future True UX Validator Script Governance

Status: `future-true-ux-validator-script-governance`
Issue: Refs #19
Date: 2026-06-30

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
| `Get-FutureTrueUxRestoreIssueAutoClosePattern` | Provides the Issue auto-close wording regex for report/request scans. | No mutation. |
| `Get-FutureTrueUxRestoreStatePromotionPattern` | Provides the separated-state promotion regex for no-execution audit scans. | No mutation. |
| `Get-FutureTrueUxRestoreEvidencePromotionPattern` | Provides the current no-execution-audit review-material-to-real-evidence promotion regex. | No mutation. |
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
| `future-true-ux-end-to-end-no-execution-readiness-audit` | `scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1` | `report-only` | Existing validator remains the gate entrypoint. |
| `future-true-ux-final-stop-line-handoff` | `scripts/validate/Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1` | `report-only` | Final stop-line remains protected. |

Issue #121 deleted the former mock-decision-ledger, negative-review, approval-checklist, integrated-packet-preview, and human-authorization-handoff gates and entrypoints. They were preparation-only stage artifacts, not long-term operator entrypoints.

## Batch 2 Consolidation

Batch 2 originally moved repeated report-only guard logic into the shared helper. After the Issue #121 prune, only the report helpers that still support current long-term gates remain resident:

- `scripts/common/New-FutureTrueUxRestoreAuthorizationReport.ps1` dot-sources the guard helper for downstream report helpers.
- `scripts/common/New-FutureTrueUxRestoreAuthorizationReviewReport.ps1` now uses shared scope, frozen-state, and Issue auto-close helpers.
- `scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1` now uses shared frozen-state drift, document text, status marker, Issue auto-close, state-promotion, evidence-promotion, and dangerous-command helpers.
- `scripts/common/New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1` now uses shared frozen-state drift, document text, status marker, Issue auto-close, and dangerous-command helpers.

The negative-review, approval-checklist, integrated-packet-preview, and human-authorization-handoff report helpers were deleted under Issue #121 with their validators, fixtures, gates, and Build Lock entries. Their dedicated truthy, dangerous-vocabulary, and review-state-drift guard helpers were also removed because they no longer had current callers.

`tests/pester/FutureTrueUxPesterHelpers.ps1` adds Pester-only assertions for governance document boundaries, Future True UX gate semantics, dangerous command scans, and Build Lock path checks. Existing governance tests call this helper instead of repeating the same frozen-state and gate checks.

## Batch 3 Consolidation

Batch 3 keeps the public validator entrypoints in place and moves repeated entrypoint plumbing into `scripts/common/FutureTrueUxRestore.ValidatorPrimitives.ps1`. The helper centralizes:

- repository root resolution from a validator script root;
- validator state, failure accumulation, check output, and passed/failed status mapping;
- repo-relative UTF-8 JSON reads through the existing `Resolve-FutureTrueUxRestoreRepoPath` helper;
- `-ReportPath` directory creation, UTF-8 JSON write, success output, and exit-code mapping.

The consolidation now covers the seven Future True UX Restore validate entrypoints that remain long-term:

- `scripts/validate/Test-FutureTrueUxRestoreAuthorization.ps1`;
- `scripts/validate/Test-FutureTrueUxRestoreCurrentUserDryRun.ps1`;
- `scripts/validate/Test-FutureTrueUxRestoreScopeDryRun.ps1`;
- `scripts/validate/Test-FutureTrueUxRestoreAuthorizationReview.ps1`;
- `scripts/validate/Test-FutureTrueUxRestoreMockReviewDrill.ps1`;
- `scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1`;
- `scripts/validate/Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1`.

No retained validator CLI parameter was renamed or removed. `ManifestPath`, `ReportPath`, and the existing fixture/baseline parameters remain on their original retained scripts. Deleted preparation-only validators no longer keep resident CLI compatibility.

`tests/pester/FutureTrueUxValidatorEntrypointConsolidation.Tests.ps1` locks the seven retained gate-to-entrypoint mappings, checks the shared primitive functions, verifies validate entrypoints do not keep inline report-write commands, smoke-runs representative validators into caller-provided `.tmp` reports, and keeps the consolidation surface tracked by Build Lock.

## Batch 4 Presentation Prune

Issue #121 pruned the Future True UX Restore presentation-only surface. The five `scripts/config/Show-FutureTrueUxRestore*Plan.ps1` entrypoints, `scripts/common/FutureTrueUxRestore.PresentationPrimitives.ps1`, and `tests/pester/FutureTrueUxPresentationGovernance.Tests.ps1` no longer remain resident.

The durable contract now lives in the retained validator/report entrypoints. No report JSON field name, quality gate ID, quality gate entrypoint, quality gate trigger, or report-only semantics changed.

## Batch 5 Archive And Doc-only Gate Prune

Issue #121 pruned the resident Future True UX Restore archive stage docs under `docs/archive/future-true-ux-restore/01-mock-review/` and `docs/archive/future-true-ux-restore/06-no-execution-audit/`. The retained current stop-line references are `00-governance/106-future-true-ux-restore-final-stop-line-handoff.md` and `00-governance/107-future-true-ux-restore-stop-line-decision-matrix.md`.

The `future-true-ux-mock-decision-ledger` document-only gate was removed with its archived document. Pester paths that remain in PR Fast now assert the deleted archive surface stays absent while the executable mock review report helper still emits blocked, false/zero execution state. The executable report-only mock review drill, end-to-end no-execution readiness audit, and final stop-line handoff gates remain in place.

## Script Surface Inventory

| Family | Current classification | Notes |
|---|---|---|
| `scripts/common/FutureTrueUxRestore.Guards.ps1` | Already consolidated. | Frozen execution state, scope names, dangerous vocabulary, Issue auto-close, review-state drift, evidence-promotion, document text, and status-marker helpers live here. |
| `scripts/common/FutureTrueUxRestore.ValidatorPrimitives.ps1` | Already consolidated. | Validator repo root, JSON read, check/failure state, report write, and exit mapping are shared by validate entrypoints. |
| `scripts/common/New-FutureTrueUxRestore*Report.ps1` | Current report helpers only. | Long-term authorization, dry-run, mock-review, no-execution, and final stop-line helpers remain. Preparation-only intermediate helpers were deleted under Issue #121. |
| `scripts/validate/Test-FutureTrueUxRestore*.ps1` | Already consolidated at entrypoint layer. | Seven public validate entrypoints remain separate for gate stability and use validator primitives. |
| `scripts/config/Show-FutureTrueUxRestore*.ps1` | Pruned under #121. | Future True UX display-only scripts are not long-term operator entrypoints. Use validator reports for report-only state. |
| `tests/pester/FutureTrueUx*.Tests.ps1` | Shared assertions with readable gate tests. | `FutureTrueUxPesterHelpers.ps1` holds common governance, validator entrypoint, dangerous-command, and Build Lock assertions. Document-only stage tests were redirected away from deleted docs when their archived documents were pruned. |
| `tests/fixtures/user-experience/future-true-restore/` | Current fixture families only. | Negative-review, approval-checklist, packet-preview, and human-authorization-handoff fixture families were deleted under Issue #121. |

## Findings

The script surface had deliberate duplication around frozen execution flags, supported scope names, Issue auto-close scans, state-promotion scans, evidence-promotion scans, document status checks, and blocked execution vocabulary. A helper extraction is safe because it only returns static values, text checks, or regex text, and because the quality gate manifest still points at the existing validators and documents.

No retained validate entrypoint was renamed or merged. Batch 3 consolidates only shared validator entrypoint plumbing, while Batch 4 removes read-only Future True UX presentation scripts instead of keeping one-shot show/config entrypoints resident. Issue #121 removed preparation-only intermediate Future True UX gates, validators, helpers, fixtures, archived documents, and Build Lock entries; no retained quality gate trigger, layer, required/blocking setting, or report-only mode changed. No retained report schema field was removed or renamed.

The intentionally unconsolidated surface remains:

- validator entrypoints under `scripts/validate/`;
- retained operator preview entrypoints under `scripts/config/`;
- quality gate IDs and gate ordering in `manifests/quality-gates.json`;
- report JSON field names consumed by existing Pester and validators;
- GitHub workflow wiring;
- true execution paths, including restore, registry, AppX, Defender, service, WinPE, Sysprep, installer, image, or VM actions.

## Guardrails

The Pester coverage in `tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1` and `tests/pester/FutureTrueUxValidatorEntrypointConsolidation.Tests.ps1` guards:

- every Future True UX gate remains `report-only`, `pr-fast`, `pull_request`, required, and blocking;
- every Future True UX gate entrypoint still exists;
- validator entrypoints do not contain direct dangerous action commands;
- the governance record contains `Refs #19` without close keywords;
- frozen execution flags remain false/zero;
- the seven retained validate entrypoints keep their public gate mappings and parameter names;
- representative validators write JSON only to caller-provided `.tmp` report paths;
- Build Lock tracks this governance document, helper, changed report helpers, changed validate entrypoints, and the governance tests.

## Next Recommended Task

Script governance now appears stable enough to stop broad consolidation work. The next task should be a dedicated Build Lock normalization / line-ending drift repair PR that explains existing unrelated hash drift and does not mix in new Future True UX script behavior.
