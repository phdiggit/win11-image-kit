# Issue #14 Main Validation Evidence

Status: `ready-for-manual-closure`

## Evidence Sources

- main push Windows CI / Full Validate after the close-preparation PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual smoke only if explicitly performed

Pull request-only Fast CI is not a substitute for main validation evidence. Full Validate being skipped on pull requests is expected and is not a failure.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | `main push` |
| Main SHA | `3d1c70b9f221ce1fa9cf010c8b6bbe652c69e0ef` |
| Workflow run | https://github.com/phdiggit/win11-image-kit/actions/runs/28232035996 |
| Full Validate job | https://github.com/phdiggit/win11-image-kit/actions/runs/28232035996/job/83637867155 |
| Result | `success` |
| Notes | Post-PR #73 main push Windows CI / Full Validate completed successfully. |

## Quality Gate Evidence

| Field | Value |
| --- | --- |
| Report status | `manual` |
| failedCount | `0` |
| manualCount | `1` |
| gateCount | `10` |

Quality-gates report evidence uses `Test-QualityGates.ps1 -ReportPath "$env:TEMP\quality-gates-issue14-ready.json"` run locally at the same main SHA, after verifying the main push Full Validate job completed successfully. This is same-SHA local report evidence, not a GitHub artifact.

## Real VM/Admin Smoke

| Field | Value |
| --- | --- |
| Environment | `not-run` |
| Operator | `not-provided` |
| Date | `not-provided` |
| Scope | `not-provided` |
| Result | `not-run` |

## Manual Closure Readiness

| Field | Value |
| --- | --- |
| Current readiness | `ready-for-manual-closure` |
| Required next evidence | `none` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

This document is ready because the main push Full Validate evidence above has been recorded and verified.

Ready state requires:

- Trigger source is `main push` or `workflow_dispatch`
- Main SHA is a 40-character Git SHA
- Workflow run is a GitHub Actions URL
- Full Validate job is a GitHub Actions job URL
- Result is `success`
- Quality-gates report status is `passed` or `manual`
- failedCount is `0`
- PR Fast CI substitute allowed remains `false`
- Current readiness is `ready-for-manual-closure`

## Copyable Manual Closure Comment Draft

Issue #14 is ready for manual closure. The quality-gates manifest/schema, report-only runner, PR Fast CI / Full Validate split, Pester/PSScriptAnalyzer policy, and Build Lock coverage are documented and guarded. Main push Full Validate succeeded at the evidence links above. Real VM/admin smoke remains optional and was not run for this evidence record.

## Related Documents

- [Quality Gates](40-issue14-quality-gates.md)
- [Acceptance](41-issue14-quality-gates-acceptance.md)
- [Close Preparation](42-issue14-close-preparation.md)
