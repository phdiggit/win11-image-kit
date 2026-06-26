# Issue #16 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

- main push Windows CI / Full Validate after close-prep PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual lifecycle evidence only if explicitly performed

Pull request-only Fast CI is not a substitute.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | `pending` |
| Main SHA | `pending` |
| Workflow run | `pending` |
| Full Validate job | `pending` |
| Result | `pending` |
| Notes | `pending` |

## Evidence Chain Report Evidence

| Field | Value |
|---|---|
| Report status | `pending` |
| failedCount | `pending` |
| blockedCount | `pending` |
| runId | `pending` |
| artifactCount | `pending` |
| producerCount | `pending` |
| normalizedCount | `pending` |
| missingRequiredCount | `pending` |
| reportTypeMismatchCount | `pending` |
| disallowedManualCount | `pending` |
| disallowedNotCapturedCount | `pending` |
| manualCount | `pending` |
| notCapturedCount | `pending` |
| trueExecution | `false` |
| localPrivateIncluded | `false` |
| networkUsed | `false` |
| mutationUsed | `false` |

## Real Lifecycle Evidence

| Field | Value |
|---|---|
| Real build | `not-run` |
| Capture | `not-run` |
| Deploy | `not-run` |
| Admin/VM smoke | `not-provided` |
| Real WIM SHA256 | `not-captured` |
| DISM image info | `not-captured` |

## Manual Closure Readiness

| Field | Value |
|---|---|
| Current readiness | `pending-main-validation` |
| Required next evidence | `main/workflow validation` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

This document may be promoted only after real `main` or `workflow_dispatch` evidence exists. Do not fill these fields from pull request-only Fast CI, local fixture reports, or inferred success.

## Related Documents

- [Issue #16 Evidence Chain Report](48-issue16-evidence-chain-report.md)
- [Issue #16 Evidence Chain Acceptance](49-issue16-evidence-chain-acceptance.md)
- [Issue #16 Close Preparation](50-issue16-close-preparation.md)
