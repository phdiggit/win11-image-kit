# Issue #11 Capability Registry

The capability registry is the repository ledger for manifest-driven features.
It records which manifest declares a capability, which schema validates it,
which scripts implement or check it, and which tests and docs prove the
capability is covered.

This document is the Issue #11 runbook and design note. Acceptance, close
preparation, and main validation evidence are tracked separately:

- [Issue #11 Capability Registry Acceptance](29-issue11-capability-registry-acceptance.md)
- [Issue #11 Close Preparation](30-issue11-close-preparation.md)
- [Issue #11 Main Validation Evidence](31-issue11-main-validation-evidence.md)

## Fields

- `id`: stable kebab-case capability identifier.
- `issue`: source issue such as `#11`.
- `status`: `planned`, `implemented`, `deprecated`, or `static-only`.
- `context`: execution context aligned with Issue #10, such as `machine`,
  `default-user`, `current-user`, `mixed`, or `none`.
- `mutationLevel`: declared mutation boundary, such as `audit-only`,
  `plan-only`, `filesystem-planned`, `registry-planned`,
  `security-policy-planned`, `profile-planned`, `real-mutation`, or `unknown`.
- `manifest` / `schema`: manifest and JSON Schema paths.
- `entrypoints`: scripts that implement or inspect the capability.
- `validateEntrypoints`: validation scripts for explicit checks or reports.
- `tests`: Pester coverage proving the capability contract.
- `docs`: human-facing documentation or acceptance evidence.
- `notes`: boundary notes, static-only explanations, or PR Fast CI constraints.

## Running

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-CapabilityRegistry.ps1 -ReportPath reports/capability-consistency.json
```

The command reads the registry and writes a structured report when an explicit
report path is provided. It does not call real business handlers, mutate the
system, access the network, or perform registry/profile/hive operations.

## Report Status

- `passed`: all registered capabilities have the required manifest/schema,
  implementation references, tests, docs, and known mutation boundaries.
- `manual`: at least one capability requires manual review, such as
  `mixed` context, `real-mutation`, or planned capability follow-up.
- `failed`: at least one required path, test, doc, issue format, status, or
  mutation boundary is invalid.

Warnings such as orphan manifests stay in the report so maintainers can decide
whether to add registry entries in later stages.

## New Capability Checklist

- Add or update the registry entry before declaring the capability
  `implemented`.
- Manifest exists, or the capability is explicitly `planned`.
- Schema exists, or static-only notes explain why no schema applies.
- Implementation entrypoint paths are real.
- Validation entrypoint paths are real when listed.
- Pester tests exist or are updated for the new capability.
- Docs exist or are updated for the new capability.
- `mutationLevel` is explicit and not `unknown` for implemented work.
- `context` is aligned with Issue #10.
- PR Fast CI uses static, fixture, mock, WhatIf, or report-only paths.

## PR Fast CI Boundary

Capability registry validation must not run real mutation. It must not execute
Sysprep, AppX removal, DISM removal, Defender mutation, Junction migration,
registry writes, Default User hive load/unload, or profile mutation.
