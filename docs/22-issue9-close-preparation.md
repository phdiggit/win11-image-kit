# Issue #9 Close Preparation

Status: ready-for-manual-closure-candidate

本页是 Issue #9 的人工收口候选说明。它不关闭 Issue，也不声称 main/workflow evidence 已完成；真实 main evidence 由 `docs/23-issue9-main-validation-evidence.md` 记录。

## Final Scope

- Manifest-driven Sysprep AppX readiness policy and schema.
- Fixture-safe AppX inventory seam.
- Readiness gate for blocking, manual, allowed, ignored, and query failure states.
- Structured JSON report and audit/report CLI.
- PR Fast CI guardrails for schema, fixture inventory, readiness, report, CLI, and mutation boundaries.
- Documentation for manual repair and evidence boundaries.

## Evidence Chain

- [docs/20-issue9-sysprep-appx-gate.md](20-issue9-sysprep-appx-gate.md)
- [docs/21-issue9-sysprep-appx-acceptance.md](21-issue9-sysprep-appx-acceptance.md)
- [docs/22-issue9-close-preparation.md](22-issue9-close-preparation.md)
- [docs/23-issue9-main-validation-evidence.md](23-issue9-main-validation-evidence.md)
- `tests/pester/SysprepAppxInventory.Tests.ps1`
- `tests/pester/SysprepAppxReadiness.Tests.ps1`
- `tests/pester/SysprepAppxReport.Tests.ps1`
- `tests/pester/Issue9SysprepAppxGate.Tests.ps1`
- `tests/pester/Issue9SysprepAppxAcceptance.Tests.ps1`
- `tests/pester/Issue9ClosePrep.Tests.ps1`
- `tests/pester/Issue9MainValidationEvidence.Tests.ps1`

## Validation Policy

PR Fast CI validates schema, fixture inventory, readiness rules, report fields, CLI fixture behavior, mutation guardrails, pending evidence semantics, and manual closure wording. PR Fast CI must not run Sysprep, AppX removal, DISM removal, or profile mutation. Main/workflow evidence belongs in docs/23; without real evidence, this page remains a candidate. Real VM/admin smoke is optional manual evidence, not an automated requirement.

## Manual Closure Checklist

- Manifest/schema still reject unknown and mutation-style fields.
- Inventory seam remains fixture-safe.
- Readiness gate fails on blocking findings and keeps manual findings visible.
- CLI writes only explicit reports.
- Active Issue #9 code contains no Sysprep, AppX removal, DISM removal, or profile mutation call.
- PR Fast CI includes all Issue #9 tests.
- Maintainer reviews docs/23 before any manual Issue state change.

## Optional Manual Validation Evidence

- Main/workflow validation: pending in docs/23.
- Real VM/admin smoke: not-run.
- Operator: not-provided.
- Date: not-provided.
- Result: not-run.

## Closure Note Draft

Issue #9 has an audit-only Sysprep AppX readiness gate, fixture-safe inventory seam, structured JSON report, CLI entrypoint, PR Fast CI guardrails, and manual evidence scaffold. Main/workflow evidence should be reviewed from docs/23 before the maintainer changes the Issue state.
