# Issue #8 Main Validation Evidence

Status: ready-for-manual-closure

## Scope

This document records final validation evidence for Issue #8 after the Defender exclusion policy, acceptance guardrails, and close-preparation documents were added.

## Evidence Sources

Authoritative evidence may come from:

- main push Windows CI / Full Validate after the close-preparation PR is merged.
- `workflow_dispatch` Windows CI / Full Validate manually triggered by the maintainer.
- Maintainer-provided real VM/admin smoke evidence, if explicitly performed.

PR Fast CI is not a substitute for main validation evidence.

## Current Evidence

Main / workflow validation:
- Trigger source: main push
- Main SHA: 19117fb2a73a4b56bc951ea63686bcfc1bf6c48b
- Workflow run: https://github.com/phdiggit/win11-image-kit/actions/runs/28157096525
- Result: success
- Notes: Windows CI / Full Validate succeeded on the main push after PR #54 was merged. PR Fast CI is not a substitute for this evidence.

Real VM/admin smoke:
- Environment: not-run
- Operator: not-provided
- Date: not-provided
- Scope: not-provided
- Result: not-run
- Notes: Optional. Not required for ordinary PR Fast CI.

## Evidence Chain

- `docs/16-issue8-defender-exclusion-policy.md`
- `docs/17-issue8-defender-exclusion-acceptance.md`
- `docs/18-issue8-close-preparation.md`
- `docs/19-issue8-main-validation-evidence.md`
- `tests/pester/DefenderExclusionPolicy.Tests.ps1`
- `tests/pester/DefenderExclusionState.Tests.ps1`
- `tests/pester/DefenderExclusionPostDeploy.Tests.ps1`
- `tests/pester/Issue8DefenderAcceptance.Tests.ps1`
- `tests/pester/Issue8ClosePrep.Tests.ps1`
- `tests/pester/Issue8MainValidationEvidence.Tests.ps1`

## Manual Closure Readiness

Current readiness: ready-for-manual-closure

Maintainer may manually close Issue #8 only after the evidence fields are reviewed and accepted.

## Copyable Manual Closure Comment Draft

Issue #8 has completed its implementation and acceptance chain for Defender exclusion minimal-privilege governance.

Evidence:
- Policy: `docs/16-issue8-defender-exclusion-policy.md`
- Acceptance matrix: `docs/17-issue8-defender-exclusion-acceptance.md`
- Close preparation: `docs/18-issue8-close-preparation.md`
- Main validation evidence: `docs/19-issue8-main-validation-evidence.md`

Validation status:
- Main / workflow validation: success
- Real VM/admin smoke: optional / not-run unless separately provided

Remaining optional work such as real VM/admin smoke or future extension/override support should be tracked separately if needed.
