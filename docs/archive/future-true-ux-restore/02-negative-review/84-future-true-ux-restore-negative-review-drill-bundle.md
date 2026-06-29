# Future True UX Restore Negative Review Drill Bundle

Status: `negative-review-drill`

This bundle is a fixture-only and report-only review drill for future true UX restore work. It proves that unsafe or incomplete review packets remain blocked before any real restore path can be discussed.

It does not perform UX restore, does not install software, does not download content, does not touch registry or profile state, and does not authorize execution.

## Covered negative cases

| Case | Required result |
|---|---|
| Missing maintainer approval | `needs-rework` with `missing-maintainer-approval` |
| Ambiguous or expanded scope | `blocked` with `scope-ambiguous-or-expanded` |
| Exit code treated as success evidence | `needs-rework` with `exit-code-not-ux-evidence` |
| Dry-run, handler, or manual report treated as success | `needs-rework` with `report-only-not-real-evidence` |
| Mock packet treated as real restore evidence | `blocked` with `mock-only-not-real-evidence` |
| Stale or inconsistent packet metadata | `blocked` with `stale-or-inconsistent-packet` |
| Missing rollback or restore explanation | `needs-rework` with `missing-rollback-plan` |
| High-risk mutation vocabulary in report-only review | `blocked` with `high-risk-mutation-intent` |

## Evidence boundary

The validator only reads local manifest and fixture JSON. Its output is a report artifact for review. The report keeps:

- `authorizationApproved`: `false`
- `executionApproved`: `false`
- `executeReady`: `false`
- `trueExecution`: `false`
- `mutationCount`: `0`

This is not an Issue #18 completion summary and is not true UX restore evidence. It is a guardrail bundle for future maintainer review.

## Validation

Use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate\Test-FutureTrueUxRestoreNegativeReviewDrill.ps1
```

The command writes no real system state. Optional `-ReportPath` writes a UTF-8 JSON report for PR review.
