# Issue #18 User Experience Capability Matrix

Status: `in-acceptance`

## Scope

This document records the Issue #18 capability matrix and scope semantics for version-aware default app, Start menu, taskbar, app visibility, and verification planning. The current stage is still fixture/report-only and plan-only.

No real user experience mutation is executed in this stage.

## Windows Version Capability Matrix

| Windows version | Build range | Scope | Feature | Support status | Verification mode |
|---|---:|---|---|---|---|
| Windows 11 24H2 | 26100-26199 | default-user | default-apps | planned-supported | future-real-verification |
| Windows 11 24H2 | 26100-26199 | current-user | start-menu | manual-or-future | manual-checklist |
| Windows 11 23H2 | 22631-22699 | offline-image | default-apps | planned-supported | future-real-verification |
| Future build | 27000+ | any | default-apps/start-menu/taskbar | blocked until reviewed | manual-checklist |
| Unsupported build | any unlisted build | any | any UX restore | blocked | manual-checklist |

The matrix is a planning input only. `mutationAllowed` remains `false` for every entry.

## User Scope Semantics

- `default-user` is not `current-user`.
- `offline-image` is not the current running machine.
- `machine` scope is not proof that a specific user's profile has changed.
- Writing Default Profile does not modify the current user.
- Importing default app associations does not prove every current or future user received those associations.
- The current stage outputs plans and reports only; it does not claim user settings are effective.

## Template Metadata Contract

Default app and Start menu templates must carry metadata beside the template:

- source Windows edition, display version, build number, and architecture
- export timestamp
- target scope
- template type
- source run ID when available
- target app logical names
- ProgId or AppUserModelId placeholders
- required app and known capability flags

Missing source build, unsupported source version, target scope mismatch, template type mismatch, required app missing, unknown ProgId, local private paths, and mutation requests are report failures.

## Default App Association Capabilities

Default app planning may describe extension and protocol associations for `default-user`, `current-user`, or `offline-image` scope. It must not run DISM import, write registry, generate execution-ready XML, or claim the associations are effective.

Missing target app capability and unknown ProgId are blocked and counted as missing capability failures.

## Start Menu / Taskbar Capabilities

Start menu and taskbar planning may describe pins, ordering, layout format, AppUserModelId placeholders, target scope, and target Windows version. It must not import layouts, export local layouts as evidence, write profile files, write taskbar registry state, or claim the current user's layout changed.

## Target App / ProgId Capability Checks

The current checker is fixture-backed. It records app presence, package identity placeholders, known capability flags, required flags, and unknown ProgId markers without querying AppX, registry, Start Apps, or installed packages on the current machine.

## Verification Evidence Model

Verification evidence is split into:

- `planned`: report-only planning evidence
- `fixture`: fixture validation evidence
- `manual-checklist`: human review evidence to collect later
- `future-real-verification`: a future authorized run must provide real proof

Command exit code is not enough UX evidence. PR Fast CI is not main/workflow evidence. A report-only plan is not real UX restore evidence. `commandExitCodeSufficient` and `userConfigurationConfirmed` must stay `false` in this stage.

## Unsupported / Manual Checklist

Unsupported or future-only matrix rows should produce a clear manual checklist instead of mutating the system. Manual checks can include template regeneration instructions, app installation prerequisites, target scope selection, and future evidence requirements.

## CI / Quality Gates / Build Lock

PR Fast CI runs the Issue #18 UX restore validator and the UserExperience Pester subset. Quality Gates include capability matrix, template metadata, scope semantics, verification plan, and this document. Build Lock tracks the docs, manifest, schemas, helper scripts, fixtures, tests, workflow, README, and Quality Gates inputs.

## Non-goals

- no registry write
- no profile write
- no default app import
- no Start menu or taskbar mutation
- no AppX query or mutation
- no DISM import
- no network download
- no install/uninstall/upgrade
- no Issue #18 close-prep, main-evidence, or completion summary
- no automatic Issue #18 closure

## Remaining Work

- Expand default-user/current-user/offline-image simulation.
- Add fixture-only restore handler adapters.
- Convert manual checklist rows into future authorized evidence collection.
- Prepare an Issue #18 close-prep candidate only in a later task.

## Related Documents

- [Issue #18 User Experience Restore Intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 User Experience Restore Acceptance](59-issue18-user-experience-restore-acceptance.md)
- [Issue #18 Restore Handler Integration](61-issue18-restore-handler-integration.md)
