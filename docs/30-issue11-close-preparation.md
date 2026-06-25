# Issue #11 Close Preparation

Status: `ready-for-manual-closure`

This note prepares the manual close package for Issue #11 after PR validation.
It does not close the issue, post a GitHub comment, or replace required
main-branch evidence.

## Final Scope

- Capability registry manifest and JSON Schema.
- Registry loader, consistency checker, structured report helper, and validation
  CLI.
- PR Fast CI guardrails for schema, loader, consistency, report, runbook,
  acceptance, close preparation, and main-evidence scaffold.
- Documentation chain for runbook, acceptance, close preparation, and pending
  main validation evidence.

## Evidence Chain

Documents:

- [docs/28-issue11-capability-registry.md](28-issue11-capability-registry.md)
- [docs/29-issue11-capability-registry-acceptance.md](29-issue11-capability-registry-acceptance.md)
- [docs/30-issue11-close-preparation.md](30-issue11-close-preparation.md)
- [docs/31-issue11-main-validation-evidence.md](31-issue11-main-validation-evidence.md)

Tests:

- `tests/pester/CapabilityRegistrySchema.Tests.ps1`
- `tests/pester/CapabilityRegistryConsistency.Tests.ps1`
- `tests/pester/CapabilityRegistryReport.Tests.ps1`
- `tests/pester/Issue11CapabilityRegistry.Tests.ps1`
- `tests/pester/Issue11CapabilityRegistryAcceptance.Tests.ps1`
- `tests/pester/Issue11ClosePrep.Tests.ps1`
- `tests/pester/Issue11MainValidationEvidence.Tests.ps1`

## Validation Policy

PR Fast CI validates only static, fixture, mock, WhatIf, and report-only paths.
It must not call real business handlers or perform real system mutation.

The required main-branch or workflow-dispatch evidence is tracked in
[docs/31](31-issue11-main-validation-evidence.md). Main/workflow validation success evidence is recorded in docs/31.
Real VM/admin smoke remains optional manual evidence and is not required for
this ready state unless maintainers decide otherwise.

VM or administrator smoke validation is optional follow-up evidence. It is not
required for this static acceptance package and must stay explicit when run.

## Manual Closure Checklist

- Confirm [docs/31](31-issue11-main-validation-evidence.md) records the real
  `main` push evidence source before treating main validation as complete.
- Confirm no real mutation was executed as part of PR validation.
- Confirm the issue is still suitable for manual closure by a maintainer.
- Use a manual closure note without GitHub automatic closing keywords when the
  maintainer wants a final comment first.

## Recorded Evidence

| Evidence | Status |
|---|---|
| main push Windows CI / Full Validate | success |
| workflow_dispatch Windows CI / Full Validate | not-run |
| real VM/admin smoke | not-run |

Trigger source: main push
Main SHA: 06f5634fcbb637f64a16de58dd5692b34b4318ae
Workflow run: https://github.com/phdiggit/win11-image-kit/actions/runs/28187906453
Result: success
Notes: Windows CI / Full Validate succeeded on the main push after PR #63 was
merged. Real VM/admin smoke remains optional and not-run.

## Closure Note Draft

Issue #11 has a capability registry, schema, consistency report, PR Fast CI
guardrails, acceptance note, close-prep note, and recorded main validation
evidence. A maintainer can use docs/31 to decide whether to perform manual
closure.

