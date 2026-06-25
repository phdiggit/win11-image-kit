# Issue #8 Defender Exclusion Acceptance

Status: accepted-pending-manual-closure

本页是 Issue #8 的验收收口层。策略说明见 [Issue #8 Defender Exclusion Policy](16-issue8-defender-exclusion-policy.md)；关闭准备见 [Issue #8 Close Preparation](18-issue8-close-preparation.md)，main/workflow evidence scaffold 见 [Issue #8 Main Validation Evidence](19-issue8-main-validation-evidence.md)。本页只记录验收矩阵、CI 边界和维护者手动关闭前检查清单，不声明真实 VM/admin smoke 已完成。

## Scope

- Manifest-driven Defender exclusions
- Minimal-privilege path/process policy
- Schema rejection for unsupported extension, wildcard, traversal, and broad shapes
- WhatIf plan-only behavior
- Query/mutation seam isolation
- Postdeploy report and summary consistency
- PR Fast CI guardrails

## Non-goals

- Extension exclusions
- Wildcard exclusions
- Broad system path exclusions
- Generic interpreter/process exclusions
- Disabling Defender protections
- Real Defender mutation in PR Fast CI
- Automated real VM/admin smoke

## Acceptance Matrix

| Area | Expected behavior | Evidence |
| --- | --- | --- |
| Manifest shape | uses `exclusions[]`, no old `paths/processes` shape | schema / Pester |
| Required metadata | `id/type/value/scope/reason/required/failurePolicy` | schema / Pester |
| Type allowlist | only `path` and `process` | schema / Pester |
| Extension rejection | `extension` type rejected | schema / policy test |
| Broad path blocking | drive roots, Windows, Program Files, Users, profile, Desktop, Downloads blocked | policy test |
| UNC root blocking | share root blocked | policy test |
| Wildcard/traversal blocking | wildcard and `..` blocked | policy test |
| Generic process blocking | `powershell/pwsh/cmd/msiexec/setup/python/node` blocked | policy test |
| Managed roots | allowed items must be under kit-managed roots | policy test |
| Reparse point | manual review, no automatic trust | policy test |
| WhatIf | no Defender query or mutation | state/postdeploy tests |
| Policy blocked | no mutation | state/postdeploy tests |
| Add/verify | mutation seam and verification seam used | state tests |
| Report | `policyStatus/action/existsBefore/existsAfter/summary` present | postdeploy tests |
| CI boundary | PR Fast CI uses mock/seam/WhatIf only | docs / CI list |

## PR Fast CI Boundary

PR Fast CI may run JSON parsing, project config validation, static analysis, and Pester tests that use schema, policy, seam, mock, and `-WhatIf` paths. It must not call real `Add-MpPreference`, `Remove-MpPreference`, or `Set-MpPreference` mutation against the runner's Defender state.

Real VM/admin smoke, if needed, is a separate manual validation in a snapshot-capable environment. Its report can be attached later by the maintainer, but this acceptance layer does not require or imply that smoke has already happened.

## Manual Checklist Before Maintainer Closes Issue #8

- Confirm `manifests/defender-exclusions.json` keeps `exclusions[]` as the only exclusion list and does not reintroduce `paths` or `processes`.
- Confirm every active exclusion has `scope` and `reason`, and any `required=true` item has a narrow failure reason.
- Confirm schema and policy still reject `extension`, wildcard, traversal, broad system paths, UNC share roots, and generic process exclusions.
- Confirm `Set-DefenderExclusions.ps1 -WhatIf` emits plan/report output only and does not query or mutate real Defender state.
- Confirm policy-blocked or manual-review results never call the mutation seam.
- Confirm report JSON contains `defenderSummary`, `defenderResults`, `defenderStateResults`, and stable result fields used by downstream summaries.
- Confirm PR Fast CI includes the Defender exclusion policy, state, postdeploy, and acceptance tests.
- Confirm no real Defender mutation, installer, service, registry, AppX, Sysprep, DISM, WinPE, disk, Junction, user-directory move, or NAS write was performed as part of PR Fast CI.
- If manual VM/admin smoke is performed, record the environment, command, report path, and any rollback action separately.
