# Future True UX Restore Artifact Chain Consistency Index

Status: `artifact-chain-consistency-index`

This index records the artifacts the no-execution audit checks for alignment.

## Configuration

- `manifests/future-true-ux-restore-authorization.json`
- `schemas/future-true-ux-restore-authorization.schema.json`
- `manifests/quality-gates.json`
- `manifests/build-lock.json`

## Report-Only Validators

- `scripts/validate/Test-FutureTrueUxRestoreAuthorization.ps1`
- `scripts/validate/Test-FutureTrueUxRestoreCurrentUserDryRun.ps1`
- `scripts/validate/Test-FutureTrueUxRestoreScopeDryRun.ps1`
- `scripts/validate/Test-FutureTrueUxRestoreAuthorizationReview.ps1`
- `scripts/validate/Test-FutureTrueUxRestoreMockReviewDrill.ps1`
- `scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1`

## Review Documents

Docs 66-83 and 102-107 are the retained Future True UX Restore preparation and stop-line artifacts. Docs 84-101 and their intermediate stage validators were removed by Issue #121 because they were preparation-only review material, not long-term entrypoints.

## Consistency Rule

If a layer is present in the manifest, the audit expects its gate, docs, fixtures, and Pester coverage to stay report-only. If a layer starts producing execution approval, real mutation evidence, or closure-prep material for Issue #18, the audit must block.
