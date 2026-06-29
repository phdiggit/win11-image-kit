# Documentation Index

Status: `canonical-docs-index`

This index separates current operator entrypoints from historical archive material. Use it before adding new documents or starting any Future True UX Restore planning chain.

## Current Operator Entrypoints

- Project overview and top-level roadmap links: [`../README.md`](../README.md)
- Codex workflow and PR lifecycle: [`codex-workflow.md`](codex-workflow.md)
- WinPE capture and restore operator notes: [`03-WinPE捕获与还原.md`](03-WinPE捕获与还原.md)
- Build Lock policy and trusted input checks: [`32-issue12-build-lock.md`](32-issue12-build-lock.md)
- Quality Gates policy: [`40-issue14-quality-gates.md`](40-issue14-quality-gates.md)
- Evidence Chain policy: [`48-issue16-evidence-chain-report.md`](48-issue16-evidence-chain-report.md)
- Controlled Execution intake and dry-run boundary: [`52-issue17-controlled-execution-intake.md`](52-issue17-controlled-execution-intake.md)
- Issue #18 report-only UX restore intake: [`58-issue18-user-experience-restore-intake.md`](58-issue18-user-experience-restore-intake.md)

## Governance And Quality Gate Policy

- Future True UX Restore split: [`65-future-true-ux-restore-execution-split.md`](65-future-true-ux-restore-execution-split.md)
- Future True UX authorization intake: [`66-future-true-ux-restore-authorization-intake.md`](66-future-true-ux-restore-authorization-intake.md)
- Future True UX evidence model: [`67-future-true-ux-restore-evidence-model.md`](67-future-true-ux-restore-evidence-model.md)
- Future True UX dry-run plan and safety guardrails: [`68-future-true-ux-restore-dry-run-plan.md`](68-future-true-ux-restore-dry-run-plan.md) through [`79-future-true-ux-restore-authorization-state-machine.md`](79-future-true-ux-restore-authorization-state-machine.md)
- Final stop-line handoff: [`106-future-true-ux-restore-final-stop-line-handoff.md`](106-future-true-ux-restore-final-stop-line-handoff.md)
- Stop-line decision matrix: [`107-future-true-ux-restore-stop-line-decision-matrix.md`](107-future-true-ux-restore-stop-line-decision-matrix.md)
- Repository governance audit: [`108-repo-documentation-script-governance-audit.md`](108-repo-documentation-script-governance-audit.md)
- Future True UX quality gate governance: [`109-future-true-ux-quality-gate-governance.md`](109-future-true-ux-quality-gate-governance.md)
- Archive policy and reference map: [`110-future-true-ux-archive-policy-reference-map.md`](110-future-true-ux-archive-policy-reference-map.md)
- Archive dry-run plan and implementation record: [`111-future-true-ux-archive-dry-run-plan.md`](111-future-true-ux-archive-dry-run-plan.md)

## Historical Archive

Superseded Future True UX Restore stage documents live under [`archive/future-true-ux-restore/`](archive/future-true-ux-restore/):

- `01-mock-review/`: mock review drill packet, transcript, decision ledger, and lessons.
- `02-negative-review/`: negative review drill bundle, transcript, decision ledger, and lessons.
- `03-approval-checklist/`: maintainer approval checklist ergonomics and related templates.
- `04-packet-preview/`: integrated authorization packet preview and reviewer reading material.
- `05-human-handoff/`: human authorization handoff packet and artifact index.
- `06-no-execution-audit/`: end-to-end no-execution readiness audit supporting docs.

Completed roadmap close-prep and main-validation evidence documents for Issues #14-#18 remain in the root for now because several are still Quality Gates entrypoints. Move them only in a separate task that updates those gate entrypoints, Build Lock entries, Pester assertions, and README links atomically.

## Before Future True UX Restore Planning

Start from [`106-future-true-ux-restore-final-stop-line-handoff.md`](106-future-true-ux-restore-final-stop-line-handoff.md) and [`107-future-true-ux-restore-stop-line-decision-matrix.md`](107-future-true-ux-restore-stop-line-decision-matrix.md). Historical archive documents are reference material only; they do not authorize true execution, real evidence promotion, Issue #19 closure, registry writes, AppX changes, Defender changes, Start menu changes, taskbar changes, Sysprep, DISM, WinPE execution, service changes, image servicing, downloads, installs, or VM mutation.
