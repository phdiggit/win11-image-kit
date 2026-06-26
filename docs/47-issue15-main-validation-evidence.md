# Issue #15 Main Validation Evidence

Status: `ready-for-manual-closure`

## Evidence Sources

- main push Windows CI / Full Validate after close-prep PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual smoke only if explicitly performed

Pull request-only Fast CI is not a substitute.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | `main push` |
| Main SHA | `a659a0413ed9ace210ed992284ce6470458b212f` |
| Workflow run | `https://github.com/phdiggit/win11-image-kit/actions/runs/28238425157` |
| Full Validate job | `https://github.com/phdiggit/win11-image-kit/actions/runs/28238425157/job/83658845119` |
| Result | `success` |
| Notes | `PR #77 merged at 2026-06-26T12:36:20Z; the post-merge main push Full Validate job completed successfully. The checkout log fetched a659a0413ed9ace210ed992284ce6470458b212f and git log -1 returned the same SHA.` |

## Effective Configuration Evidence

| Field | Value |
| --- | --- |
| Report status | `manual` |
| failedCount | `0` |
| stackCount | `not-captured` |
| local override included | `false` |
| CLI override fixture | `passed` |
| Consumer integration | `passed` |
| Build Lock | `passed` |
| Quality Gates | `passed` |

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

This document is ready because real main push evidence has been recorded. PR Fast CI, local Pester, or local report-only validation can support review, but they do not replace main/workflow evidence.

## Related Documents

- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Issue #15 Acceptance](45-issue15-layered-configuration-acceptance.md)
- [Issue #15 Close Preparation](46-issue15-close-preparation.md)
