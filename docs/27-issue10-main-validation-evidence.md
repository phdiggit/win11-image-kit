# Issue #10 Main Validation Evidence

Status: ready-for-manual-closure

This scaffold records post-merge evidence for Issue #10. It starts pending by
design because PR Fast CI is not a substitute for main/workflow evidence.

## Evidence Sources

- main push Windows CI / Full Validate after the close-preparation PR is merged.
- `workflow_dispatch` Windows CI / Full Validate.
- Maintainer-provided real VM/admin smoke validation, if explicitly performed.

## Current Evidence

| Field | Value |
| --- | --- |
| Trigger source | main push |
| Main SHA | `6cabd08b4e80644736ddd7bde5f7c23f2b604c27` |
| Workflow run | https://github.com/phdiggit/win11-image-kit/actions/runs/28183799819 |
| Result | success |
| Notes | Windows CI / Full Validate succeeded on the main push after PR #60 was merged. PR Fast CI is not a substitute for this evidence. |

## Real VM/Admin Smoke

| Field | Value |
| --- | --- |
| Environment | not-run |
| Operator | not-provided |
| Date | not-provided |
| Scope | not-provided |
| Result | not-run |

## Evidence Chain

- [docs/24 context scope split](24-issue10-context-scope-split.md)
- [docs/25 acceptance matrix](25-issue10-context-scope-acceptance.md)
- [docs/26 close preparation](26-issue10-close-preparation.md)
- `tests/pester/Issue10MainValidationEvidence.Tests.ps1`

## Manual Closure Readiness

Current readiness: ready-for-manual-closure

Readiness can move to `ready-for-manual-closure` only after real main push or
`workflow_dispatch` success evidence is recorded with a 40-character SHA, an
Actions workflow URL, `Result: success`, and matching readiness text.

## Copyable Manual Closure Comment Draft

Issue #10 has PR-safe context-scope acceptance coverage and a pending main
validation evidence scaffold. Main/workflow validation evidence is now recorded
as success from the main push after PR #60 was merged. PR Fast CI is not a
substitute for main/workflow validation evidence, and real VM/admin smoke remains
optional / not-run unless maintainers provide separate evidence.
