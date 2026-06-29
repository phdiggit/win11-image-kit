# Issue #12 Main Validation Evidence

Status: `ready-for-manual-closure`

## Evidence Sources

- main push Windows CI / Full Validate after the close-preparation PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided real VM/admin smoke if explicitly performed

Pull request-only Fast CI is not a substitute for main validation evidence.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | `main push` |
| Main SHA | `65c5c98d4c47dade576503952a9c68a9ccd456ef` |
| Workflow run | https://github.com/phdiggit/win11-image-kit/actions/runs/28195790448 |
| Full Validate job | https://github.com/phdiggit/win11-image-kit/actions/runs/28195790448/job/83522088038 |
| Result | `success` |
| Build Lock report | `manual`, `failedCount=0` |
| Notes | Windows CI / Full Validate succeeded on the main push after PR #66 was merged. PR Fast CI is not a substitute for this evidence. |

## Real VM/Admin Smoke

| Field | Value |
| --- | --- |
| Environment | `not-run` |
| Operator | `not-provided` |
| Date | `not-provided` |
| Scope | `not-provided` |
| Result | `not-run` |

Real VM/admin smoke is optional manual evidence. It is not required by PR Fast CI and must not be invented.

## Evidence Chain

- docs/archive/completed-roadmap/issue-12/32-issue12-build-lock.md
- docs/archive/completed-roadmap/issue-12/33-issue12-build-lock-acceptance.md
- docs/archive/completed-roadmap/issue-12/34-issue12-close-preparation.md
- docs/archive/completed-roadmap/issue-12/35-issue12-main-validation-evidence.md
- tests/pester/Issue12MainValidationEvidence.Tests.ps1
- Windows CI `Validate` on pull requests for static/fixture/report guardrails
- Windows CI `Full Validate` from main push or workflow_dispatch for main evidence

## Manual Closure Readiness

| Field | Value |
| --- | --- |
| Current readiness | `ready-for-manual-closure` |
| Required next evidence | `none` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

This document can move to `ready-for-manual-closure` only when all of these are true:

- Trigger source is `main push` or `workflow_dispatch`.
- Main SHA is a 40-character Git SHA.
- Workflow run is a GitHub Actions URL.
- Full Validate job is a GitHub Actions job URL.
- Result is `success`.
- Build Lock report is `passed` or `manual`, with `failedCount=0`.
- Current readiness is `ready-for-manual-closure`.

## Copyable Manual Closure Comment Draft

Issue #12 evidence has been reviewed by the maintainer:

- Build Lock implementation and acceptance guardrails are documented in docs/32 and docs/33.
- Manual closure checklist is documented in docs/34.
- Main/workflow evidence is recorded in docs/35.
- PR Fast CI is static/fixture/report-only and is not used as a substitute for main/workflow validation.

The maintainer may now perform final manual issue handling if the evidence table above is ready.
