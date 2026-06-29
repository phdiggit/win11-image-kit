# Issue #9 Sysprep AppX Acceptance Matrix

Status: accepted-ready-for-manual-closure

本页记录 Issue #9 的验收范围、安全边界和维护者关闭前检查项。Close preparation and main validation evidence are recorded in docs/22 and docs/23. 这里的证据覆盖 audit、gate、report、静态守卫和 main/workflow validation；不代表已经完成真实 VM/admin smoke。

## Scope

- Sysprep AppX policy manifest and schema.
- AppX inventory seam for provisioned packages and all-users packages.
- Readiness gate for blocking, manual, allowed, and ignored findings.
- Query failure handling.
- Structured JSON report contract.
- Audit/report CLI with fixture inventory support.
- PR Fast CI guardrails for fixture/mock/audit paths.

## Non-goals

- Running Sysprep.
- Removing AppX packages.
- DISM removal.
- Mutating user profiles or the AppX repository.
- Automated real VM/admin smoke.
- AppX remediation workflow.

## Acceptance Matrix

| Area | Expected evidence |
|---|---|
| Manifest/schema | `manifests/sysprep-appx-gate.json` and `schemas/sysprep-appx-gate.schema.json` exist; schema rejects unknown and mutation-style fields. |
| Inventory seam | `Get-KitAppxInventory.ps1` normalizes provisioned and all-users package fixtures. |
| Query failure | structured query errors can block when policy requires fail behavior. |
| User-only AppX | user-installed-not-provisioned findings become blocking or manual according to `failurePolicy`. |
| Provisioned mismatch | provisioned-installed mismatch findings become blocking or manual according to `failurePolicy`. |
| Family policy | allow, manual, framework, resource, and non-removable families remain visible in report findings. |
| Report fields | report keeps `reportType`, `policyPath`, `mode`, `failurePolicy`, `status`, `exitCode`, `summary`, `findings`, `queryErrors`, `recommendedActions`, and `whatIf`. |
| CLI fixture path | `Test-SysprepReadiness.ps1` can read fixture inventory and write a temp JSON report. |
| Safety scan | active Issue #9 code does not call sysprep, AppX removal, DISM removal, or profile mutation. |
| CI boundary | PR Fast CI runs fixture/mock/audit Pester tests and does not require admin rights. |

## CI Boundary

PR Fast CI validates schema, fixture inventory, readiness rules, report shape, CLI fixture behavior, and mutation guardrails. It must not run Sysprep, remove AppX packages, run DISM removal, mutate profiles, or depend on a real machine AppX state.

## Manual Checklist

- Confirm `docs/archive/completed-roadmap/issue-9/20-issue9-sysprep-appx-gate.md` describes the audit-only gate and manual repair boundary.
- Confirm this acceptance matrix remains aligned with the current manifest, schema, scripts, and Pester tests.
- Confirm PR Fast CI includes all Issue #9 tests.
- Confirm `docs/archive/completed-roadmap/issue-9/23-issue9-main-validation-evidence.md` is updated only after real main/workflow evidence exists.
- Confirm any real VM/admin smoke evidence is maintainer-provided and clearly marked.

Related entry: [Issue #9 Sysprep AppX 前置门禁](20-issue9-sysprep-appx-gate.md).
