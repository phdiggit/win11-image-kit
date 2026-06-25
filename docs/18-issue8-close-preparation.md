# Issue #8 Close Preparation

Status: ready-for-manual-closure-candidate

## Final Scope

- Manifest-driven Defender exclusions.
- Minimal-privilege policy for path/process exclusions.
- Schema rejection for unsupported extension, wildcard, traversal, and broad shapes.
- WhatIf plan-only behavior.
- Query/mutation seam isolation.
- Postdeploy report and summary consistency.
- PR Fast CI guardrails.
- Acceptance matrix and evidence chain.

## Evidence Chain

- [Issue #8 Defender Exclusion Policy](16-issue8-defender-exclusion-policy.md)
- [Issue #8 Defender Exclusion Acceptance](17-issue8-defender-exclusion-acceptance.md)
- [Issue #8 Close Preparation](18-issue8-close-preparation.md)
- [Issue #8 Main Validation Evidence](19-issue8-main-validation-evidence.md)
- `tests/pester/DefenderExclusionPolicy.Tests.ps1`
- `tests/pester/DefenderExclusionState.Tests.ps1`
- `tests/pester/DefenderExclusionPostDeploy.Tests.ps1`
- `tests/pester/Issue8DefenderAcceptance.Tests.ps1`
- `tests/pester/Issue8ClosePrep.Tests.ps1`
- `tests/pester/Issue8MainValidationEvidence.Tests.ps1`

## Validation Policy

PR Fast CI validates schema, policy, seam, report, and WhatIf guardrails. It must not perform real Defender mutation.

Main/workflow validation evidence is recorded in [Issue #8 Main Validation Evidence](19-issue8-main-validation-evidence.md). Until real main push or workflow_dispatch evidence is available there, this document stays a manual closure candidate rather than a final ready state.

Real VM/admin smoke evidence is optional manual evidence. It is not a normal PR blocking requirement and should be recorded separately when maintainers decide it is needed.

## Manual Closure Checklist

- Active Defender exclusion manifest still uses `exclusions[]`, not old `paths/processes`.
- Schema supports only `path` and `process`, and rejects `extension`.
- Policy still blocks drive roots, Windows/System32, Program Files, Users/profile, Desktop/Downloads, UNC share roots, wildcard/traversal paths, and generic processes.
- `Set-DefenderExclusions.ps1 -WhatIf` does not query or mutate real Defender state.
- Policy blocked/manual review items do not call the mutation seam.
- Reports contain `policyStatus`, `action`, `existsBefore`, `existsAfter`, and summary fields.
- PR Fast CI includes policy, state, postdeploy, acceptance, close prep, and main validation evidence tests.
- Issue #8 is closed manually by a maintainer after evidence review.
- If maintainers require real VM/admin smoke, record environment, command, report path, and rollback notes separately.

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
- Notes: optional

## Closure Note Draft

Issue #8 has reached manual closure candidate state after Defender exclusions were converted to a manifest-driven, minimal-privilege, reportable policy flow with acceptance guardrails.

Evidence:
- Policy: `docs/16-issue8-defender-exclusion-policy.md`
- Acceptance matrix: `docs/17-issue8-defender-exclusion-acceptance.md`
- Close preparation: `docs/18-issue8-close-preparation.md`
- Main validation evidence: `docs/19-issue8-main-validation-evidence.md`

Remaining optional work such as real VM/admin smoke or future extension/override support should be tracked separately if needed.
