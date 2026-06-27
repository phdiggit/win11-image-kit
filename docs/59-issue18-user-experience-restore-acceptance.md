# Issue #18 User Experience Restore Acceptance

Status: `accepted-ready-for-manual-closure`

## Acceptance Matrix

| Area | Current result | Status |
|---|---|---|
| Intake | Real Issue #18 and Roadmap #19 source are recorded in docs/58. | `accepted-ready-for-manual-closure` |
| Scope | This stage is intake plus report-only / fixture baseline. | `accepted-ready-for-manual-closure` |
| Manifest/schema | UX restore manifest and closed schemas define plan-only behavior. | `accepted-ready-for-manual-closure` |
| Validator | Baseline report passes; failure fixtures block or fail. | `accepted-ready-for-manual-closure` |
| Safety | Registry, profile, default app, Start menu, taskbar, network and true execution flags remain false. | `accepted-ready-for-manual-closure` |
| CI/QG/Build Lock | Quality Gates and Build Lock include Issue #18 artifacts; post-PR #96 main/workflow Full Validate succeeded. | `accepted-ready-for-manual-closure` |
| Capability matrix | Version capability, template metadata, scope semantics, and verification plan are fixture-backed and report-only. | `accepted-ready-for-manual-closure` |

## Version-Aware Coverage

The fixture baseline records Windows 11 `24H2` and `23H2` contexts with explicit build numbers. Unsupported versions and missing build numbers are treated as report failures, not ignored warnings.

## Default Apps Coverage

Default app fixtures cover extension and protocol association plans with sample ProgId values. Unknown ProgId or mutation requests are blocked in the report. This does not run DISM import, does not generate a real import artifact, and does not claim default apps changed.

## Start Menu / Taskbar Coverage

Start menu fixtures cover pinned app planning with sample AppUserModelId placeholders and version-specific target data. Taskbar fixture support is report-only; registry write requests are blocked. This does not write layout files, import layout, or claim the current user's layout changed.

## Report Contract

The report confirms that planning can be generated and validated. It does not serve as main/workflow evidence and it is not real user experience restore evidence.

PR Fast CI is not main/workflow evidence. Fixture/report-only validation is not real UX restore evidence. The current stage confirms only that the plan and validation report can be generated; it does not confirm that user configuration has taken effect.

## Safety Boundaries

- no registry write
- no profile write
- no default app association import
- no Start menu or taskbar mutation
- no DISM/AppX/Defender/Junction/Service/Sysprep mutation
- no network download
- no install/uninstall/upgrade
- no local private artifact

## Main Validation Boundary

This acceptance state is ready for maintainer manual closure review of the current report-only / handler-adapter stage based on docs/63 post-PR #96 main/workflow success evidence. PR Fast CI is not main/workflow evidence, fixture/report-only validation is not real UX restore evidence, handler reports are not real UX restore evidence, and manual checklist rows are not success evidence.

Manual closure handoff is recorded in [Issue #18 Manual Closure Handoff](64-issue18-manual-closure-handoff.md). Future true UX restore execution remains split into [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md).

## Remaining Work

- Expand default-app association matrix beyond sample extensions and protocols.
- Expand Start menu and taskbar version compatibility coverage.
- Add deeper default-user/current-user/offline-image simulation.
- Backfill post-PR main/workflow validation evidence in a later task.
- Split future true UX restore execution into an explicitly authorized task with a real evidence model.

## Related Documents

- [Issue #18 User Experience Restore Intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 User Experience Capability Matrix](60-issue18-user-experience-capability-matrix.md)
- [Issue #18 Restore Handler Integration](61-issue18-restore-handler-integration.md)
- [Issue #18 Close Preparation](62-issue18-close-preparation.md)
- [Issue #18 Main Validation Evidence](63-issue18-main-validation-evidence.md)
- [Issue #18 Manual Closure Handoff](64-issue18-manual-closure-handoff.md)
- [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md)
