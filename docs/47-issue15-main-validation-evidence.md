# Issue #15 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

- main push Windows CI / Full Validate after close-prep PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual smoke only if explicitly performed

Pull request-only Fast CI is not a substitute.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | `pending` |
| Main SHA | `pending` |
| Workflow run | `pending` |
| Full Validate job | `pending` |
| Result | `pending` |
| Notes | `pending` |

## Effective Configuration Evidence

| Field | Value |
| --- | --- |
| Report status | `pending` |
| failedCount | `pending` |
| stackCount | `pending` |
| local override included | `false` |
| CLI override fixture | `pending` |

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

Do not mark this document ready until real main push or `workflow_dispatch` evidence is recorded. PR Fast CI, local Pester, or local report-only validation can support review, but they do not replace main/workflow evidence.

## Related Documents

- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Issue #15 Acceptance](45-issue15-layered-configuration-acceptance.md)
- [Issue #15 Close Preparation](46-issue15-close-preparation.md)
