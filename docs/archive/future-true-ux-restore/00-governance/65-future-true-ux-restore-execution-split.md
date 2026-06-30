# Future True UX Restore Execution Split

Status: `future-split`

## Why This Is Split from Issue #18

Issue #18 reached manual closure readiness for the current report-only / handler-adapter stage. True UX restore execution is split out because it can mutate registry, profile, Default User hive, default app associations, Start menu, taskbar, offline image, AppX, Defender, Junction, service, or Sysprep state.

The current Issue #18 ready state must not be expanded into true mutation without a new authorized task.

## Explicit Authorization Required

Future true UX restore execution must start from explicit human authorization. The authorization must name:

- target scope: `current-user`, `default-user`, `offline-image`, or `machine`;
- allowed mutation type;
- target machine, VM, or image;
- expected rollback or backup path;
- evidence collection requirements;
- stop conditions and failure propagation.

## Required Evidence Model

Any future true UX restore task must collect evidence that is stronger than command exit code. Required evidence includes:

- before state;
- exact command or tool invocation;
- exit code;
- after state;
- independent verification;
- user-scoped verification for current-user claims;
- machine or image identity;
- failure propagation into reports and CI or manual gate output.

Command exit code alone is not UX success evidence.

## Execution Scope Options

- `current-user`: may verify or mutate only the active user context named by the task.
- `default-user`: may plan or mutate Default User profile only when explicitly authorized.
- `offline-image`: may target mounted image state only when the image path, mount point, and rollback strategy are explicit.
- `machine`: may target machine-wide policy only when the mutation type and rollback are explicit.

Scopes must not be collapsed. Default User state is not current-user state, and an offline image is not the current machine.

## Safety Gates Before Mutation

Before any mutation, a future task must define:

- admin or VM smoke environment;
- rollback or backup strategy;
- dry-run or WhatIf preview;
- mutation allowlist;
- forbidden action list;
- log and report destinations;
- evidence redaction expectations;
- maintainer review point before broad reuse.

## Disallowed Until Authorized

The following remain forbidden until a future task explicitly authorizes them:

- registry writes;
- profile writes;
- Default User hive changes;
- current-user default app mutation;
- default app association import;
- Start menu import or export as evidence;
- taskbar mutation;
- DISM default app import;
- AppX query or mutation as success evidence;
- Defender mutation;
- Junction or service mutation;
- Sysprep mutation;
- private local artifact commits;
- network package lookup or download.

## Candidate Future Tasks

- Authorize current-user default app verification with before/after evidence.
- Authorize Default User Start menu template apply in a disposable VM.
- Authorize taskbar checklist conversion into a real execution model.
- Authorize offline-image UX restore validation with mount, rollback, and independent verification.

## Related Documents

- [Future True UX Restore Authorization Intake](66-future-true-ux-restore-authorization-intake.md)
- [Future True UX Restore Evidence Model](67-future-true-ux-restore-evidence-model.md)
- [Future True UX Restore Dry-run Plan](68-future-true-ux-restore-dry-run-plan.md)
- [Future True UX Restore Final Stop-Line Handoff](106-future-true-ux-restore-final-stop-line-handoff.md)
- [Future True UX Restore Stop-Line Decision Matrix](107-future-true-ux-restore-stop-line-decision-matrix.md)
