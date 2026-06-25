# Issue #11 Capability Registry Acceptance

Status: `accepted-ready-for-manual-closure`

This acceptance note records the static and report-only evidence required before
Issue #11 can be considered ready for manual closure. It extends the runbook and
design note in [Issue #11 Capability Registry](28-issue11-capability-registry.md).
Close preparation and main validation evidence are recorded in docs/30 and
docs/31.

## Scope

- Keep the capability registry as the source ledger for manifest-driven
  repository capabilities.
- Validate registry shape through JSON Schema.
- Validate registry references to manifests, schemas, scripts, tests, and docs.
- Produce a structured consistency report without running real business
  handlers.
- Keep PR Fast CI limited to static, fixture, mock, WhatIf, and report-only
  checks.

## Non-goals

- Do not execute Sysprep, AppX removal, DISM removal, Defender mutation,
  Junction migration, registry writes, hive load/unload, profile mutation, or
  service changes.
- Do not replace main-branch or workflow-dispatch evidence with PR Fast CI.
- Do not use this document as an automatic issue-closing comment.
- Do not change Issue #6 through Issue #10 close documents.

## Acceptance Matrix

| Area | Evidence | Expected state |
|---|---|---|
| Schema contract | `schemas/capability-registry.schema.json` | Root and capability objects reject unknown fields and require the documented fields. |
| Registry content | `manifests/capability-registry.json` | Registered capabilities include manifest, schema, validation, tests, docs, context, and mutation boundary notes. |
| Loader | `scripts/common/Get-KitCapabilityRegistry.ps1` | Loads and validates registry data from explicit paths. |
| Consistency check | `scripts/common/Test-KitCapabilityConsistency.ps1` | Reports missing references, invalid issue labels, unknown mutation levels, and manual-review boundaries. |
| Report | `scripts/common/New-KitCapabilityConsistencyReport.ps1` | Emits `capability-consistency` summary, capability rows, orphan manifests, and WhatIf state. |
| CLI | `scripts/validate/Test-CapabilityRegistry.ps1` | Supports explicit report output and stays report-only. |
| CI | `.github/workflows/ci.yml` | Runs schema, consistency, report, Issue #11 runbook, acceptance, close-prep, and main-evidence guardrails in PR Fast CI. |
| Documentation | `docs/28-issue11-capability-registry.md`, this note, `docs/30-issue11-close-preparation.md`, `docs/31-issue11-main-validation-evidence.md` | Describes operating rules, acceptance state, close preparation, and pending main evidence. |

## Extension Checklist

Before declaring a new capability `implemented`:

- Add or update the registry entry.
- Add or update the manifest and schema references, unless notes explain a
  static-only exception.
- Add or update validation or report paths when the capability has a checker.
- Add or update focused Pester coverage.
- Add or update human-facing documentation or evidence notes.
- Confirm `context` and `mutationLevel` are explicit.
- Confirm PR Fast CI evidence remains static, fixture, mock, WhatIf, or
  report-only.

## Evidence Links

- Runbook and design note: [docs/28](28-issue11-capability-registry.md)
- Acceptance note: [docs/29](29-issue11-capability-registry-acceptance.md)
- Close preparation: [docs/30](30-issue11-close-preparation.md)
- Main validation evidence scaffold: [docs/31](31-issue11-main-validation-evidence.md)

