# Issue #11 Main Validation Evidence

Status: `ready-for-manual-closure`

This scaffold records evidence after Issue #11 changes are validated from
`main` or from an explicit `workflow_dispatch` run. PR Fast CI is useful
pre-merge evidence, but it is not a substitute for this record.

## Evidence Sources

Accepted evidence sources:

- `push` workflow on `main`
- `workflow_dispatch` workflow targeting `main`

Not accepted as completion evidence:

- Pull request-only Fast CI
- Local-only Pester runs
- Screenshots without commit SHA and workflow URL

## Current Evidence

| Field | Value |
|---|---|
| Status | `success` |
| Main commit SHA | `06f5634fcbb637f64a16de58dd5692b34b4318ae` |
| Workflow trigger | `main push` |
| Workflow URL | https://github.com/phdiggit/win11-image-kit/actions/runs/28187906453 |
| Validate result | `success` |
| Evidence recorded by | codex |
| Evidence recorded at | 2026-06-25T17:24:13Z |

## Recorded Evidence

Trigger source: main push
Main SHA: 06f5634fcbb637f64a16de58dd5692b34b4318ae
Workflow run: https://github.com/phdiggit/win11-image-kit/actions/runs/28187906453
Result: success
Notes: Windows CI / Full Validate succeeded on the main push after PR #63 was
merged. PR Fast CI is not a substitute for this evidence.

## Real VM/Admin Smoke

Status: `not-run`

Real VM or administrator smoke validation is optional and must be recorded
explicitly if performed. It must not be implied from PR Fast CI, local tests, or
static report-only checks.

## Evidence Chain

- Runbook and design note: [docs/28](28-issue11-capability-registry.md)
- Acceptance note: [docs/29](29-issue11-capability-registry-acceptance.md)
- Close preparation: [docs/30](30-issue11-close-preparation.md)
- Main validation evidence: [docs/31](31-issue11-main-validation-evidence.md)

## Manual Closure Readiness

Status: `ready-for-manual-closure`

Manual closure readiness is ready because this file records a real accepted
evidence source with a 40-character commit SHA, workflow URL, and successful
Full Validate result.

## Closure Comment Draft

Issue #11 main validation evidence is recorded in docs/31. The accepted
evidence is the main push Windows CI / Full Validate run above. PR Fast CI is
not a substitute for this evidence, and real VM or administrator smoke remains
optional and not-run unless maintainers record separate evidence. A maintainer
can use this record to decide whether to close the issue manually.

