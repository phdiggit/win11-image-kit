# Repo Documentation & Script Governance Audit

Status: `repo-governance-audit`

Issue reference: Roadmap Issue #19 governance task only. This document uses `Refs #19` semantics and does not close, fix, resolve, or otherwise auto-close Issue #19.

## Scope

This is a report-only inventory after the Future True UX Restore preparation chain reached its final stop-line. It classifies repository documents, validators, fixtures, quality gates, and Build Lock entries before any true UX restore planning chain begins.

This audit does not move, delete, archive, or rewrite the audited files. It does not modify `.github/workflows/ci.yml`. It does not authorize or perform registry, DISM, AppX, Defender, Junction, Service, Sysprep, installer, download, Start menu, taskbar, default-app, profile, image, WinPE, or other true execution work.

Frozen semantics for this governance task:

| Field | Required value |
|---|---|
| `authorizationApproved` | `false` |
| `executionApproved` | `false` |
| `executeReady` | `false` |
| `trueExecution` | `false` |
| `mutationCount` | `0` |

## Documentation Inventory

| Classification | Files | Governance decision |
|---|---|---|
| Canonical entry documents | `README.md`, `AGENTS.md`, `docs/codex-workflow.md`, `docs/codex-task-card-template.md`, `docs/00-*.md` through `docs/08-*.md` | Keep in place. These are project entry, operator workflow, and baseline runbook documents. Do not move without updating README, AGENTS, tests, and Build Lock together. |
| Active roadmap and governance anchors | `docs/archive/completed-roadmap/issue-12/32-issue12-build-lock.md`, `docs/archive/future-true-ux-restore/00-governance/65-future-true-ux-restore-execution-split.md`, `docs/archive/future-true-ux-restore/00-governance/106-future-true-ux-restore-final-stop-line-handoff.md`, `docs/archive/future-true-ux-restore/00-governance/107-future-true-ux-restore-stop-line-decision-matrix.md` | Keep active. These define current Build Lock governance, Future True UX safety boundary, and final stop-line semantics. |
| Archived completed-roadmap validation and gate documents | `docs/archive/completed-roadmap/issue-6/` through `docs/archive/completed-roadmap/issue-13/` | Keep only while current README, Quality Gates, Build Lock, Pester, or scripts still require them. Issue #14-#18 resident completed-roadmap files were deleted under #121 instead of kept as historical gate artifacts. |
| Superseded Future True UX Restore stage documents | `docs/archive/future-true-ux-restore/01-mock-review/` and `docs/archive/future-true-ux-restore/06-no-execution-audit/` | Deleted under Issue #121 after the end-to-end audit and final stop-line contracts were preserved by retained validator/report gates and `00-governance` stop-line documents. |
| Archived Future True UX stage families | Mock review and no-execution audit documents formerly in root `docs/80-*.md` through `docs/105-*.md` | Removed from the resident worktree; Git history carries the deleted stage details. Do not treat deleted archive content as a current true UX restore planning entrypoint. |
| Delete candidates | Preparation-only Future True UX stages | Mock review drill, mock decision ledger, negative review, approval checklist, packet preview, and human handoff were deleted by Issue #121 together with their gates, helpers, fixtures, docs, and Build Lock entries. Pester paths that remain in PR Fast were redirected to retained report-only guardrails or workflow-compatible prune checks instead of stale documents. |
| Must remain canonical in root | `README.md`, `AGENTS.md`, `docs/README.md`, `docs/codex-workflow.md`, `docs/codex-task-card-template.md`, `docs/00-*.md` through `docs/10-*.md`, `docs/vm-test-runbook.md` | These are root entrypoints, Chinese operator documents, workflow/template documents, or current runbook material. English roadmap, evidence, and Future True UX stage documents should stay under `docs/archive/` unless a later task explicitly promotes one back to root. |

## Script And Fixture Inventory

| Area | Classification | Files / patterns | Governance decision |
|---|---|---|---|
| `scripts/common/` core helpers | Canonical / active | `Resolve-KitPath.ps1`, `Resolve-KitEffectiveConfiguration.ps1`, `Get-KitBuildLock.ps1`, `Test-KitBuildLock.ps1`, `New-KitBuildLockReport.ps1`, `New-KitQualityGateReport.ps1`, `New-StepResult.ps1`, package, state, evidence, and UX report helpers | Keep active. These are shared runtime or report-only helpers used by current validators and tests. |
| `scripts/common/` Future True UX report builders | Report-only current guardrail | Retained `New-FutureTrueUxRestore*.ps1` helpers | Keep only while they protect current authorization, dry-run, no-execution, and final stop-line semantics. Preparation-only stage report builders were deleted by Issue #121. |
| `scripts/validate/` project gates | Canonical / active | `Test-ProjectConfig.ps1`, `Test-QualityGates.ps1`, `Test-BuildLock.ps1`, `Test-CapabilityRegistry.ps1`, `Test-EffectiveConfiguration.ps1`, `Test-EvidenceChain.ps1`, `Test-ControlledExecution.ps1`, `Test-UserExperienceRestore.ps1` | Keep active. These are current quality gate entrypoints. |
| `scripts/validate/` Future True UX validators | Report-only current guardrail | Retained `Test-FutureTrueUxRestore*.ps1` validators | Keep current gate entrypoints. The mock review drill validator remains only as a workflow-compatible prune check; preparation-only negative-review, approval-checklist, packet-preview, and human-handoff validators were deleted by Issue #121. |
| `scripts/config/` display helpers | Active operator previews | `Show-CustomizationScope.ps1`, `Show-EffectiveConfiguration.ps1`, `Show-ControlledExecutionPlan.ps1`, `Show-UserExperienceRestorePlan.ps1` | Keep active. These are safe preview/report entrypoints. |
| `scripts/config/` Future True UX previews | Pruned under #121 | `Show-FutureTrueUxRestore*.ps1` removed | Keep validator/report-only entrypoints instead of resident read-only show scripts. Future true restore planning must start a new high-risk chain. |
| `tests/pester/` issue acceptance and evidence tests | Active / historical guardrail | `Issue6*.Tests.ps1` through `Issue13*.Tests.ps1` where still present | Keep only while they guard current roadmap links, no auto-close wording, Build Lock references, or operator-facing documentation. Issue #14-#18 historical Pester files were deleted under #121. |
| `tests/pester/` Future True UX tests | Report-only historical guardrail | `FutureTrueUxRestore*.Tests.ps1` | Keep in place. They are the strongest current protection against accidental execute-ready, real-evidence, and auto-close drift. Candidate for grouped consolidation after the next governance task. |
| `tests/fixtures/` active fixtures | Active | `controlled-execution`, `evidence-chain`, `user-experience/handlers`, `user-experience/template-metadata`, `user-experience/verification` | Keep. These support current report-only validation. |
| `tests/fixtures/user-experience/future-true-restore/` | Report-only current guardrail | `authorization`, `current-user`, `default-user`, `offline-image`, `machine`, `review`, `no-execution-readiness-audit`, `final-stop-line-handoff` | Keep current fixture families. Mock-review and other preparation-only intermediate fixture families were deleted by Issue #121. |
| Dangerous / requires high-risk chain | Real mutation logic and real execution scopes | Any future registry, Defender, AppX, Junction, Service, Sysprep, DISM, installer, download, profile, Start menu, taskbar, default-app, image, or WinPE execution path | Out of scope. This audit does not approve or execute those paths. |

## Quality Gate And Build Lock Alignment

Observed alignment:

- Quality Gates contain current Future True UX gates as report-only guardrails; preparation-only intermediate gates were deleted by Issue #121.
- Build Lock contains retained Future True UX documents, manifests, schemas, report builders, validators, fixtures, and Pester tests for the current chain.
- README points users to the Issue #18 report-only stage, manual handoff, execution split, authorization intake, evidence model, and dry-run plan.
- Pester directly reads many Future True UX documents by path, including current root docs and archived stage docs.

Governance findings:

| Finding | Evidence | Recommendation |
|---|---|---|
| Gate placement is scattered by issue chronology rather than one governance section | Future True UX gates appear after Issue #18 gates, among controlled-execution gates, and near later Issue #15/#16 entries in `manifests/quality-gates.json` | Follow-up PR should group Future True UX gates or add a manifest-level grouping convention without changing CI behavior. |
| Gate naming style is mostly consistent but not uniform | Gate IDs mix `future-true-ux-restore-*`, `future-true-ux-*`, and scope-specific names | Follow-up should decide whether ID churn is worth it. If renamed, update Build Lock, Pester expectations, reports, and PR body notes together. |
| Historical stage gates are reduced | End-to-end audit and final stop-line remain required PR-fast gates; mock drill, mock decision ledger, negative drill, checklist ergonomics, packet preview, and human handoff were removed | Continue deletion-first cleanup only when final stop-line and no-execution coverage stay intact. |
| Build Lock points only to retained current docs by design | Retained `docs/archive/future-true-ux-restore/00-governance/**` docs are locked and tested | Keep only current archive paths in Build Lock. Deleted stage coverage should remain available through Git history, not resident files. |
| Tests protect retained current docs and deleted stage absence | `FutureTrueUxRestore*.Tests.ps1` and docs governance tests include explicit path assertions for current retained Future True UX documents and pruned stage absence | Keep tests aligned with the retained current surface. Any later archive restructuring must update tests in the same PR. |

## Boundary For Open Issues

This task does not edit or close GitHub issues. The following remain open unless the maintainer separately requests a dedicated task:

| Issue | Boundary |
|---|---|
| #8 | Defender exclusion hardening |
| #9 | Sysprep/AppX gate |
| #10 | Deployment contexts |
| #11 | Capability registry consistency |
| #12 | Build Lock / supply-chain hardening |
| #13 | Ensure-State convergence |
| #19 | Roadmap index |

## Intentionally Left Untouched

- `.github/workflows/ci.yml`
- Existing retained quality gate ordering and required flags
- Existing Build Lock safety policy
- Existing Future True UX manifests, schemas, validators, fixtures, and report builders
- Any true UX restore planning document promotion
- Any true execution or system mutation path

## Next Recommended Governance Task

Create a narrow follow-up PR for Future True UX validator consolidation. Inspect whether duplicate `New-FutureTrueUxRestore*.ps1`, `Test-FutureTrueUxRestore*.ps1`, and related Pester fixtures can be consolidated without weakening final stop-line, no-execution, no-auto-close, and evidence-boundary assertions.
