# Issue #17 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

- main push Windows CI / Full Validate after the close-prep candidate PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual lifecycle evidence only if explicitly performed in a later controlled task

Pull request-only Fast CI is not a substitute. Native command simulation is not a substitute for real lifecycle evidence.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | `pending` |
| Main SHA | `pending` |
| Workflow run | `pending` |
| Full Validate job | `pending` |
| Result | `pending` |
| Notes | `pending post-PR main/workflow evidence` |

## Controlled Execution Report Evidence

| Field | Value |
|---|---|
| Report status | `pending` |
| failedCount | `pending` |
| blockedCount | `pending` |
| authorizationFailureCount | `pending` |
| executeRequestBlockedCount | `pending` |
| simulatedFailureCount | `pending` |
| dependencyBlockedCount | `pending` |
| trueExecution | `false` |
| whatIf | `true` |

## Real Lifecycle Evidence

| Field | Value |
|---|---|
| Real disk query | `not-run` |
| Disk mutation | `not-run` |
| DISM apply/capture | `not-run` |
| bcdboot | `not-run` |
| reagentc | `not-run` |
| WinRE mutation | `not-run` |
| Real WIM SHA256 | `not-captured` |
| Admin/VM smoke | `not-provided` |

## Manual Closure Readiness

| Field | Value |
|---|---|
| Current readiness | `pending-main-validation` |
| Required next evidence | `main/workflow validation` |
| PR Fast CI substitute allowed | `false` |
| Simulation substitute allowed | `false` |

## Pending-State Rules

This document must remain pending until a later task records real main push or workflow_dispatch Full Validate evidence. Local report output, PR Fast CI, fixture results, and simulated native command results may support review, but they do not promote this page to ready evidence.

## Related Documents

- [Issue #17 Controlled Execution Acceptance](53-issue17-controlled-execution-acceptance.md)
- [Issue #17 Controlled Execution Safety Hardening](54-issue17-controlled-execution-safety-hardening.md)
- [Issue #17 Controlled Execution Authorization and Simulation](55-issue17-controlled-execution-authorization.md)
- [Issue #17 Close Preparation](56-issue17-close-preparation.md)
