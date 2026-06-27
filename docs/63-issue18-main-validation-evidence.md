# Issue #18 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

This scaffold is reserved for post-PR main/workflow validation evidence. PR Fast CI output, fixture runs, report-only plans, handler reports, command exit codes, and manual checklist rows are not substitutes for main/workflow evidence or real UX restore evidence.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | pending |
| Main SHA | pending |
| Workflow run | pending |
| Full Validate job | pending |
| Result | pending |
| Notes | pending post-PR main/workflow evidence |

## Blocked Evidence Attempt

The post-PR #95 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28284104911` targeted `bcda2cfd9598b6f445a186e03bc3a849506c9a92`, but `Full Validate` completed with conclusion `failure`. The job `https://github.com/phdiggit/win11-image-kit/actions/runs/28284104911/job/83804976569` failed in `Run Pester tests with PowerShell 7` after the 30-minute step timeout. The failure was caused by the PowerShell 7 Pester run recursing through non-data object adapter properties while scanning user-experience template metadata for private paths. This failed run is recorded only as blocked evidence and is not used as ready evidence.

Blocked reason: post-PR #95 main Full Validate completed with conclusion `failure`, and the failed run is not eligible as ready evidence.

## Previous Blocked Evidence Attempt

The post-PR #94 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28281913558` targeted `c634998b4d050601f72183f3114d463639518b9b`, but `Full Validate` completed with conclusion `failure`. The job `https://github.com/phdiggit/win11-image-kit/actions/runs/28281913558/job/83799151961` failed in `Run Pester tests with PowerShell 7`. This earlier failed run remains recorded as historical blocked evidence only and is not used as ready evidence.

## UX Restore Report Evidence

| Field | Value |
|---|---|
| Report status | pending |
| failedCount | pending |
| blockedCount | pending |
| unsupportedCapabilityCount | pending |
| scopeMismatchCount | pending |
| templateMetadataFailureCount | pending |
| verificationFailureCount | pending |
| requestedApplyBlockedCount | pending |
| handlerExecutionCount | pending |
| trueExecution | false |
| whatIf | true |

## Handler Report Evidence

Handler report evidence remains pending for main/workflow validation. A local or PR Fast handler report can validate report shape and safety boundaries, but it is not real UX restore evidence and not main/workflow evidence.

## Real UX Restore Evidence

| Evidence | State |
|---|---|
| Registry write | not-run |
| Profile write | not-run |
| Default user hive write | not-run |
| Current user default-app mutation | not-run |
| Default app import | not-run |
| Start menu import | not-run |
| Taskbar mutation | not-run |
| AppX query/mutation as evidence | not-run |
| Real user configuration verification | not-provided |
| Admin/VM smoke | not-provided |

## Manual Closure Readiness

| Field | Value |
|---|---|
| Current readiness | pending-main-validation |
| Required next evidence | main/workflow validation |
| PR Fast CI substitute allowed | false |
| Fixture substitute allowed | false |
| Handler report substitute allowed | false |
| Manual checklist substitute allowed | false |

## Ready-State Rules

- Do not promote this document to ready until post-PR main/workflow validation evidence exists.
- Do not use PR Fast CI as main/workflow evidence.
- Do not use fixtures as real UX restore evidence.
- Do not use handler reports as real UX restore evidence.
- Do not use manual checklist rows as success evidence.
- Do not add an Issue #18 completion summary in this stage.
- Do not automatically close Issue #18.

## Related Documents

- [Issue #18 User Experience Restore Intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 User Experience Restore Acceptance](59-issue18-user-experience-restore-acceptance.md)
- [Issue #18 User Experience Capability Matrix](60-issue18-user-experience-capability-matrix.md)
- [Issue #18 Restore Handler Integration](61-issue18-restore-handler-integration.md)
- [Issue #18 Close Preparation](62-issue18-close-preparation.md)
