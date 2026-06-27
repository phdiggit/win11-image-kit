# Issue #18 Close Preparation

Status: `ready-for-manual-closure`

## Final Scope Candidate

This document records manual closure readiness for the current report-only / handler-adapter stage. Issue #18 can be evaluated for maintainer manual closure of this stage, but it must not be automatically closed by this PR.

The candidate scope covers version-aware and scope-aware UX restore planning, template metadata validation, handler adapters, manual checklist generation, false-success guardrails, and report-only safety boundaries.

## Accepted Report-only / Fixture / Handler Capabilities

- `Restore-UserExperience.ps1` emits a `restore-user-experience` report by default.
- Baseline report output keeps `whatIf=true`, `trueExecution=false`, and `handlerExecutionCount=0`.
- Default app, Start menu, and taskbar handlers keep `executed=false`.
- Missing capabilities, unsupported scopes, requested apply, profile writes, registry writes, and false current-user claims are blocked.
- Template metadata for `configs/default-apps` and `configs/start-menu` is generic and does not include private user paths.
- Manual checklist items keep `commandExitCodeSufficient=false` and `userConfigurationConfirmed=false`.

## Explicit Non-goals

- No automatic Issue #18 closure.
- No Issue #18 completion summary.
- Ready is limited to current report-only / handler-adapter manual closure readiness.
- Real UX restore execution remains future authorized work.
- No registry write.
- No profile write.
- No default user hive write.
- No current user default-app mutation.
- No default app import.
- No Start menu import.
- No taskbar mutation.
- No AppX query or mutation as success evidence.
- No Defender, Junction, Service, Sysprep, install, uninstall, upgrade, or network download mutation.

## Validation Policy

PR Fast CI is not main/workflow evidence. Fixture validation is not real UX restore evidence. Report-only plans and handler reports are not real UX restore evidence. Manual checklist rows are not success evidence.

The current acceptance can only prove that planning, blocking, schema validation, and report structure are working. It does not prove that a real user's configuration changed.

## Manual Closure Checklist

- Confirm docs/59, docs/60, and docs/61 are `accepted-ready-for-manual-closure`.
- Confirm this document is `ready-for-manual-closure`.
- Confirm docs/63 is `ready-for-manual-closure`.
- Confirm no Issue #18 completion summary exists.
- Confirm `Restore-UserExperience.ps1 -Apply` and `-Execute` remain blocked.
- Confirm baseline mutation counters remain zero.
- Confirm future true UX restore work is split into a separate authorized task.

## True UX Restore Split

Future true UX restore execution must be opened as a separate controlled task. That task must require explicit human authorization and a real evidence model before writing registry, profile, default app, Start menu, taskbar, default user hive, or offline image state.

## Template Metadata / Config Policy

Checked-in metadata may describe reference templates and target capabilities. It must not include private local profile paths, SIDs, NAS artifacts, registry exports, real Start menu files, real taskbar exports, or real default app import artifacts.

## Local Private / Build Lock Policy

`manifests/paths.local.json` remains excluded from Git and Build Lock. Build Lock may cover scaffold docs, schemas, scripts, fixtures, metadata descriptors, tests, README, CI, and Quality Gates, but must not lock local private artifacts.

## Closure Note Draft

Issue #18 has completed the report-only UX restore planning, version capability, scope semantics, template metadata, handler adapter, manual checklist, false-success guardrail, and post-PR #96 main/workflow validation evidence requirements for this stage. Real UX restore execution remains separate future authorized work.

Refs #18

## Related Documents

- [Issue #18 User Experience Restore Intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 User Experience Restore Acceptance](59-issue18-user-experience-restore-acceptance.md)
- [Issue #18 User Experience Capability Matrix](60-issue18-user-experience-capability-matrix.md)
- [Issue #18 Restore Handler Integration](61-issue18-restore-handler-integration.md)
- [Issue #18 Main Validation Evidence](63-issue18-main-validation-evidence.md)
