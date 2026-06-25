# Issue #10 Close Preparation

Status: ready-for-manual-closure-candidate

This page is a maintainer review checklist. It prepares the Issue #10 evidence
chain, but the issue remains a manual maintainer action until the evidence is
reviewed.

## Final Scope

- Machine/default-user/current-user context split.
- Manifest and schema guardrails.
- Resolver and safety validation.
- Plan/report output and validation CLI.
- Acceptance, close-preparation, and main-validation evidence scaffolds.
- PR Fast CI coverage for the Issue #10 guardrails.

## Evidence Chain

- [docs/24 context scope split](24-issue10-context-scope-split.md)
- [docs/25 acceptance matrix](25-issue10-context-scope-acceptance.md)
- [docs/26 close preparation](26-issue10-close-preparation.md)
- [docs/27 main validation evidence](27-issue10-main-validation-evidence.md)
- `tests/pester/ContextScopeSchema.Tests.ps1`
- `tests/pester/ContextScopeResolver.Tests.ps1`
- `tests/pester/ContextScopeSafety.Tests.ps1`
- `tests/pester/ContextScopeReport.Tests.ps1`
- `tests/pester/Issue10ContextScope.Tests.ps1`
- `tests/pester/Issue10ContextScopeAcceptance.Tests.ps1`
- `tests/pester/Issue10ClosePrep.Tests.ps1`
- `tests/pester/Issue10MainValidationEvidence.Tests.ps1`

## Validation Policy

- PR Fast CI validates schema, resolver, safety, plan/report, CLI report,
  acceptance, close-preparation, and main-evidence guardrails.
- PR Fast CI must not run `reg load`, `reg unload`, real HKCU/HKLM writes, or
  profile mutation.
- Main/workflow evidence is recorded in [docs/27](27-issue10-main-validation-evidence.md).
  Without real evidence, this page remains a candidate.
- Real VM/admin smoke validation is optional manual evidence.

## Manual Closure Checklist

- Schema still rejects unknown fields.
- Resolver blocks ambiguous and unknown contexts.
- Safety validator blocks HKCU/HKLM/default-user/profile mix-ups.
- `Test-ContextScope.ps1` writes only an explicit report path.
- PR Fast CI includes every Issue #10 test listed in this page.
- [docs/27](27-issue10-main-validation-evidence.md) remains pending until real
  evidence is available.
- Maintainer performs issue closure manually after evidence review.

## Optional Manual Validation Evidence

| Evidence | Status |
| --- | --- |
| main push Windows CI / Full Validate | pending |
| workflow_dispatch Windows CI / Full Validate | pending |
| real VM/admin smoke | not-run |

## Closure Note Draft

Issue #10 context-scope work has a manifest/schema contract, resolver and safety
guardrails, plan/report output, PR Fast CI coverage, an acceptance matrix, and a
pending main-validation evidence scaffold. Real registry writes, Default User
hive load/unload, and profile mutation are outside the PR-safe validation path.
