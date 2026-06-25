# Issue #7 Close Preparation

Status: ready-for-manual-closure-candidate

## Final Scope

- Preflight safety checks.
- Copy-first transaction flow.
- countAndSize copy verification.
- Source backup rename before Junction creation.
- mklink exit-code capture.
- Final Junction target verification.
- backupRetention keep/delete semantics.
- rollback / manualRecoveryHint evidence.
- WhatIf plan-only behavior.
- Acceptance guardrails and CI wiring.

## Evidence Chain

- [Issue #7 Junction Transaction Acceptance](13-issue7-junction-transaction-acceptance.md)
- [Issue #7 Main Validation Evidence](15-issue7-main-validation-evidence.md)
- `tests/pester/JunctionTransactionPreflight.Tests.ps1`
- `tests/pester/JunctionTransactionExecution.Tests.ps1`
- `tests/pester/JunctionStateVerification.Tests.ps1`
- `tests/pester/Issue7JunctionAcceptance.Tests.ps1`
- `tests/pester/Issue7ClosePrep.Tests.ps1`
- `tests/pester/Issue7MainValidationEvidence.Tests.ps1`

## Validation Policy

PR Fast CI validates the non-mutating guardrails and Pester acceptance tests. It does not run real user-directory migration, NAS writes, or admin-only Junction mutation.

Real VM/admin smoke evidence is optional manual evidence. It is not a normal PR blocking requirement and should be recorded separately when maintainers decide it is needed.

Main/workflow validation evidence is recorded in [Issue #7 Main Validation Evidence](15-issue7-main-validation-evidence.md). Until real main push or workflow_dispatch evidence is available there, this document stays a manual closure candidate rather than a final ready state.

## Manual Closure Checklist

- Active Junction migration path does not use `robocopy /MOVE`.
- Schema remains conservative:
  - `onTargetConflict=fail`
  - `backupRetention=keep/delete`, default `keep`
  - `verificationMode=countAndSize`
- WhatIf produces plan-only report output.
- Failure paths preserve source or backup and report recovery guidance.
- PR Fast CI passes.
- Issue #7 is closed manually by a maintainer after evidence review.
- If maintainers require real VM/admin smoke, record that separately before manual closure.

## Optional Manual Validation Evidence

Main / workflow evidence:
- Trigger source: pending
- Main SHA: pending
- Workflow run: pending
- Result: pending
- Notes: pending

Real VM/admin smoke evidence:
- Environment: not-run
- Operator: pending
- Date: pending
- Scope: pending
- Result: pending

## Closure Note Draft

Issue #7 has reached manual closure readiness after the Junction migration path was converted to a copy-first, preflight-gated, reportable transaction flow with acceptance guardrails.

Evidence:
- Acceptance matrix: `docs/13-issue7-junction-transaction-acceptance.md`
- Close preparation: `docs/14-issue7-close-preparation.md`
- Main validation evidence: `docs/15-issue7-main-validation-evidence.md`
- PR Fast CI covers preflight, transaction execution, state verification, Issue #7 acceptance, and close-prep tests.

Remaining optional work such as real VM/admin smoke, hash verification, or no-clobber merge should be tracked separately if needed.
