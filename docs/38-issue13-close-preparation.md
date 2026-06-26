# Issue #13 Close Preparation

Status: `ready-for-manual-closure-candidate`

## Final Scope

Issue #13 establishes a plan/report-only Ensure-State convergence layer for software and services. The shipped scope is manifest/schema validation, fixture/current-state resolution, convergence plan generation, result mapping, JSON report generation, explicit validate entrypoint, capability registry wiring, Build Lock coverage, PR Fast CI guardrails, and documentation.

This close-preparation note is a candidate for maintainer manual issue handling. It does not claim main/workflow validation success and does not claim real VM/admin smoke validation while docs/39 remains pending.

## Evidence Chain

- docs/36-issue13-ensure-state.md
- docs/37-issue13-ensure-state-acceptance.md
- docs/38-issue13-close-preparation.md
- docs/39-issue13-main-validation-evidence.md
- tests/pester/EnsureStateSchema.Tests.ps1
- tests/pester/EnsureStatePlan.Tests.ps1
- tests/pester/EnsureStateReport.Tests.ps1
- tests/pester/EnsureStateValidation.Tests.ps1
- tests/pester/Issue13EnsureState.Tests.ps1
- tests/pester/Issue13EnsureStateAcceptance.Tests.ps1
- tests/pester/Issue13ClosePrep.Tests.ps1
- tests/pester/Issue13MainValidationEvidence.Tests.ps1

## Validation Policy

- PR Fast CI validates schema, resolver, plan, report, validate entrypoint, acceptance guardrails, close-preparation guardrails, and main-evidence guardrails.
- PR Fast CI must not run real install/uninstall/upgrade, service mutation, network access, signing, registry/profile/hive mutation, or image build.
- Main/workflow evidence is recorded in docs/39; without real evidence, this document remains only a candidate.
- Real VM/admin smoke is optional manual evidence, not a PR Fast CI requirement.

## Manual Closure Checklist

- schemas reject unknown fields.
- resolver uses fixture/current objects only.
- plan creates actions but does not execute them.
- report preserves plannedActions.
- validate entrypoint writes explicit report only when requested.
- manual status exits 0; failed exits 1.
- capability registry contains the Issue #13 entry.
- Build Lock covers Issue #13 inputs and reports `failedCount=0`.
- docs/39 remains pending until real main/workflow evidence exists.
- Issue #13 is handled manually by the maintainer after evidence review.

## Optional Manual Validation Evidence

| Evidence | Status | Notes |
| --- | --- | --- |
| main/workflow validation | pending | Record in docs/39 after the close-preparation PR is merged and main/workflow evidence exists. |
| real VM/admin smoke | not-run | Optional manual evidence; not required by PR-safe validation. |

## Closure Note Draft

Manual review candidate for Issue #13:

- Ensure-State manifest/schema, resolver, plan, result mapping, report, CLI, registry wiring, Build Lock coverage, Pester guardrails, and docs are in place.
- PR Fast CI covers static, fixture, and report-only paths.
- Real software install/uninstall/upgrade, service mutation, network access, signing, registry/profile/hive mutation, and image build remain outside this scope.
- Main/workflow evidence should be recorded in docs/39 before maintainer final manual issue handling.

## Related Documents

- [Ensure-State Runbook](36-issue13-ensure-state.md)
- [Acceptance Matrix](37-issue13-ensure-state-acceptance.md)
- [Main Validation Evidence](39-issue13-main-validation-evidence.md)
