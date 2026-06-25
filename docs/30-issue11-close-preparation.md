# Issue #11 Close Preparation

Status: `ready-for-manual-closure-candidate`

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
[docs/31](31-issue11-main-validation-evidence.md). Until real evidence is added
there, that document remains `pending-main-validation`.

VM or administrator smoke validation is optional follow-up evidence. It is not
required for this static acceptance package and must stay explicit when run.

## Manual Closure Checklist

- Confirm PR Fast CI succeeded for the merged commit or a later validation run.
- Confirm [docs/31](31-issue11-main-validation-evidence.md) records a real
  `main` push or `workflow_dispatch` evidence source before treating main
  validation as complete.
- Confirm no real mutation was executed as part of PR validation.
- Confirm the issue is still suitable for manual closure by a maintainer.
- Use a manual closure note without GitHub automatic closing keywords when the
  maintainer wants a final comment first.

## Optional Evidence Pending

- Real `main` branch `Validate` workflow URL.
- Exact merged commit SHA.
- Optional workflow-dispatch rerun URL.
- Optional VM or administrator smoke notes.

## Closure Note Draft

Issue #11 has a capability registry, schema, consistency report, PR Fast CI
guardrails, acceptance note, close-prep note, and main-evidence scaffold. Main
validation evidence should be copied into docs/31 before a maintainer performs
manual closure.

