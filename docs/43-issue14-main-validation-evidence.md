# Issue #14 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

- main push Windows CI / Full Validate after the close-preparation PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual smoke only if explicitly performed

Pull request-only Fast CI is not a substitute for main validation evidence. Full Validate being skipped on pull requests is expected and is not a failure.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | `pending` |
| Main SHA | `pending` |
| Workflow run | `pending` |
| Full Validate job | `pending` |
| Result | `pending` |
| Notes | `pending` |

## Quality Gate Evidence

| Field | Value |
| --- | --- |
| Report status | `pending` |
| failedCount | `pending` |
| manualCount | `pending` |
| gateCount | `pending` |

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
| Current readiness | `pending-main-validation` |
| Required next evidence | `main/workflow validation` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

Only a later evidence backfill task may promote this document out of `pending-main-validation`.

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

Pending. Do not use a final closure comment until main/workflow validation evidence has been recorded.

## Related Documents

- [Quality Gates](40-issue14-quality-gates.md)
- [Acceptance](41-issue14-quality-gates-acceptance.md)
- [Close Preparation](42-issue14-close-preparation.md)
