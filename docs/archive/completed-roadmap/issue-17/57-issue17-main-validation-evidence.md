# Issue #17 Main Validation Evidence

Status: `ready-for-manual-closure`

## Evidence Sources

- main push Windows CI / Full Validate after the close-prep candidate PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual lifecycle evidence only if explicitly performed in a later controlled task

Pull request-only Fast CI is not a substitute. Native command simulation is not a substitute for real lifecycle evidence.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | `main push` |
| Main SHA | `b9dd20762886fa8a5e431393cf186f1cea1a4ccc` |
| Workflow run | `https://github.com/phdiggit/win11-image-kit/actions/runs/28278167308` |
| Full Validate job | `https://github.com/phdiggit/win11-image-kit/actions/runs/28278167308/job/83788796920` |
| Result | `success` |
| Notes | `post-PR #89 Full Validate completed successfully; checkout log fetched b9dd20762886fa8a5e431393cf186f1cea1a4ccc, checked out refs/remotes/origin/main, and printed b9dd20762886fa8a5e431393cf186f1cea1a4ccc; local git log -1 confirmed b9dd20762886fa8a5e431393cf186f1cea1a4ccc` |

## Controlled Execution Report Evidence

| Field | Value |
|---|---|
| Report status | `passed` |
| failedCount | `0` |
| blockedCount | `0` |
| authorizationFailureCount | `0` |
| executeRequestBlockedCount | `0` |
| simulatedFailureCount | `0` |
| dependencyBlockedCount | `0` |
| diskIdentityMismatchCount | `0` |
| confirmationTokenFailureCount | `0` |
| wimValidationFailureCount | `0` |
| winrePlanFailureCount | `0` |
| nativeCommandFailureCount | `0` |
| trueExecution | `false` |
| whatIf | `true` |
| executedActionCount | `0` |

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
| Current readiness | `ready-for-manual-closure` |
| Required next evidence | `maintainer manual review` |
| PR Fast CI substitute allowed | `false` |
| Simulation substitute allowed | `false` |

## Ready-State Rules

This document is promoted because a real post-PR #89 `main` push Full Validate job completed successfully and the checkout SHA matches the local `main` SHA. Pull request-only Fast CI is still not a substitute. Native command simulation is still not real lifecycle evidence.

## Same-SHA Local Report Evidence

The Controlled Execution Report Evidence table uses `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-ControlledExecution.ps1 -ReportPath "$env:TEMP\controlled-execution-issue17-main-b9dd207.json"` run locally at the same main SHA after verifying the post-PR #89 Full Validate job completed successfully. This is same-SHA local report evidence, not a GitHub artifact.

## Related Documents

- [Issue #17 Controlled Execution Acceptance](53-issue17-controlled-execution-acceptance.md)
- [Issue #17 Controlled Execution Safety Hardening](54-issue17-controlled-execution-safety-hardening.md)
- [Issue #17 Controlled Execution Authorization and Simulation](55-issue17-controlled-execution-authorization.md)
- [Issue #17 Close Preparation](56-issue17-close-preparation.md)
