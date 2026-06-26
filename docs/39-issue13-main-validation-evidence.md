# Issue #13 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

- main push Windows CI / Full Validate after the close-preparation PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided real VM/admin smoke if explicitly performed

Pull request-only Fast CI is not a substitute for main validation evidence.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | `pending` |
| Main SHA | `pending` |
| Workflow run | `pending` |
| Result | `pending` |
| Notes | `pending` |

## Ensure-State Evidence

| Field | Value |
| --- | --- |
| Report status | `pending` |
| failedCount | `pending` |
| plannedActionCount | `pending` |

Ensure-State report `manual` with `failedCount=0` is acceptable review evidence, not execution evidence.

## Real VM/Admin Smoke

| Field | Value |
| --- | --- |
| Environment | `not-run` |
| Operator | `not-provided` |
| Date | `not-provided` |
| Scope | `not-provided` |
| Result | `not-run` |

Real VM/admin smoke is optional manual evidence. It is not required by PR Fast CI and must not be invented.

## Manual Closure Readiness

| Field | Value |
| --- | --- |
| Current readiness | `pending-main-validation` |
| Required next evidence | `main/workflow validation` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

This document can move to `ready-for-manual-closure` only when all of these are true:

- Trigger source is `main push` or `workflow_dispatch`.
- Main SHA is a 40-character Git SHA.
- Workflow run is a GitHub Actions URL.
- Result is `success`.
- Ensure-State report status is `passed` or `manual`.
- failedCount is `0`.
- Current readiness is `ready-for-manual-closure`.

## Copyable Manual Closure Comment Draft

Issue #13 evidence has been reviewed by the maintainer:

- Ensure-State implementation and acceptance guardrails are documented in docs/36 and docs/37.
- Manual closure checklist is documented in docs/38.
- Main/workflow evidence is recorded in docs/39 when this table is ready.
- PR Fast CI is static/fixture/report-only and is not used as a substitute for main/workflow validation.

The maintainer may perform final manual issue handling only after the evidence table above is ready.

## Related Documents

- [Ensure-State Runbook](36-issue13-ensure-state.md)
- [Acceptance Matrix](37-issue13-ensure-state-acceptance.md)
- [Close Preparation](38-issue13-close-preparation.md)
