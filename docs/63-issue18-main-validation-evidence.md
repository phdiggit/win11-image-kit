# Issue #18 Main Validation Evidence

Status: `ready-for-manual-closure`

## Evidence Sources

This scaffold is reserved for post-PR main/workflow validation evidence. PR Fast CI output, fixture runs, report-only plans, handler reports, command exit codes, and manual checklist rows are not substitutes for main/workflow evidence or real UX restore evidence.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | main push |
| Main SHA | eac9e5b7e68498480fec803a46466c13936ad399 |
| Workflow run | https://github.com/phdiggit/win11-image-kit/actions/runs/28285895794 |
| Full Validate job | https://github.com/phdiggit/win11-image-kit/actions/runs/28285895794/job/83809686636 |
| Result | success |
| Notes | post-PR #96 Full Validate completed successfully; local `git log -1 --format=%H` confirmed `eac9e5b7e68498480fec803a46466c13936ad399` |

## Previous Blocked Evidence Attempts

The post-PR #95 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28284104911` targeted `bcda2cfd9598b6f445a186e03bc3a849506c9a92`, but `Full Validate` completed with conclusion `failure`. The job `https://github.com/phdiggit/win11-image-kit/actions/runs/28284104911/job/83804976569` failed in `Run Pester tests with PowerShell 7` after the 30-minute step timeout. The failure was caused by the PowerShell 7 Pester run recursing through non-data object adapter properties while scanning user-experience template metadata for private paths. This failed run is recorded only as blocked evidence and is not used as ready evidence.

The post-PR #94 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28281913558` targeted `c634998b4d050601f72183f3114d463639518b9b`, but `Full Validate` completed with conclusion `failure`. The job `https://github.com/phdiggit/win11-image-kit/actions/runs/28281913558/job/83799151961` failed in `Run Pester tests with PowerShell 7`. This earlier failed run remains recorded as historical blocked evidence only and is not used as ready evidence.

These earlier failed runs remain recorded as historical blocked evidence only. They are superseded for readiness by the post-PR #96 main/workflow Full Validate success evidence above.

## UX Restore Report Evidence

| Field | Value |
|---|---|
| Evidence source | same-SHA local report evidence on `eac9e5b7e68498480fec803a46466c13936ad399` |
| Report status | passed |
| failedCount | 0 |
| blockedCount | 0 |
| unsupportedCapabilityCount | 0 |
| scopeMismatchCount | 0 |
| templateMetadataFailureCount | 0 |
| verificationFailureCount | 0 |
| requestedApplyBlockedCount | 0 |
| handlerExecutionCount | 0 |
| registryWriteCount | 0 |
| profileWriteCount | 0 |
| defaultAppMutationCount | 0 |
| startMenuMutationCount | 0 |
| taskbarMutationCount | 0 |
| trueExecution | false |
| whatIf | true |

## Handler Report Evidence

| Field | Value |
|---|---|
| Evidence source | same-SHA local `Restore-UserExperience.ps1 -WhatIf` report on `eac9e5b7e68498480fec803a46466c13936ad399` |
| Restore-UserExperience report status | planned |
| handlerExecutionCount | 0 |
| plannedHandlerCount | 2 |
| blockedHandlerCount | 0 |
| failedHandlerCount | 0 |
| manualChecklistCount | 3 |
| requestedApplyBlockedCount | 0 |
| trueExecution | false |
| whatIf | true |

Handler report validates report shape and safety boundaries only; it is not real UX restore evidence.

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
| Current readiness | ready-for-manual-closure |
| Required next evidence | satisfied by post-PR #96 main/workflow Full Validate success |
| PR Fast CI substitute allowed | false |
| Fixture substitute allowed | false |
| Handler report substitute allowed | false |
| Manual checklist substitute allowed | false |

## Ready-State Rules

- This ready state is limited to the current report-only / handler-adapter stage.
- Do not use PR Fast CI as main/workflow evidence.
- Do not use fixtures as real UX restore evidence.
- Do not use handler reports as real UX restore evidence.
- Do not use manual checklist rows as success evidence.
- Do not treat this as real registry, profile, default app, Start menu, taskbar, default user hive, or offline image mutation evidence.
- Do not add an Issue #18 completion summary in this stage.
- Do not automatically close Issue #18.

## Related Documents

- [Issue #18 User Experience Restore Intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 User Experience Restore Acceptance](59-issue18-user-experience-restore-acceptance.md)
- [Issue #18 User Experience Capability Matrix](60-issue18-user-experience-capability-matrix.md)
- [Issue #18 Restore Handler Integration](61-issue18-restore-handler-integration.md)
- [Issue #18 Close Preparation](62-issue18-close-preparation.md)
