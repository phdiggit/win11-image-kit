# Issue #18 User Experience Restore Acceptance

Status: `in-acceptance`

## Acceptance Matrix

| Area | Current result | Status |
|---|---|---|
| Intake | Real Issue #18 and Roadmap #19 source are recorded in docs/58. | `in-acceptance` |
| Scope | This stage is intake plus report-only / fixture baseline. | `in-acceptance` |
| Manifest/schema | UX restore manifest and closed schemas define plan-only behavior. | `in-acceptance` |
| Validator | Baseline report passes; failure fixtures block or fail. | `in-acceptance` |
| Safety | Registry, profile, default app, Start menu, taskbar, network and true execution flags remain false. | `in-acceptance` |
| CI/QG/Build Lock | PR Fast CI, Quality Gates and Build Lock include Issue #18 artifacts. | `in-acceptance` |
| Capability matrix | Version capability, template metadata, scope semantics, and verification plan are fixture-backed and report-only. | `in-acceptance` |

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

## Remaining Work

- Expand default-app association matrix beyond sample extensions and protocols.
- Expand Start menu and taskbar version compatibility coverage.
- Add deeper default-user/current-user/offline-image simulation.
- Prepare a later Issue #18 close-prep candidate only after maintainers request that stage.

## Related Documents

- [Issue #18 User Experience Restore Intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 User Experience Capability Matrix](60-issue18-user-experience-capability-matrix.md)
