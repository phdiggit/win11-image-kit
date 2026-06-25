# Issue #11 Main Validation Evidence

Status: `pending-main-validation`

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
| Status | `pending` |
| Main commit SHA | `pending` |
| Workflow trigger | `pending` |
| Workflow URL | `pending` |
| Validate result | `pending` |
| Evidence recorded by | `pending` |
| Evidence recorded at | `pending` |

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

Status: `pending`

Manual closure readiness becomes `ready` only after this file records a real
accepted evidence source with a 40-character commit SHA, workflow URL, and
successful `Validate` result.

## Closure Comment Draft

Issue #11 main validation evidence is pending in docs/31. After a successful
main or workflow-dispatch validation run is recorded, a maintainer can use that
evidence to decide whether to close the issue manually.

