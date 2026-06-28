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
| Active roadmap and governance anchors | `docs/32-issue12-build-lock.md`, `docs/40-issue14-quality-gates.md`, `docs/48-issue16-evidence-chain-report.md`, `docs/52-issue17-controlled-execution-intake.md`, `docs/58-issue18-user-experience-restore-intake.md`, `docs/64-issue18-manual-closure-handoff.md`, `docs/65-future-true-ux-restore-execution-split.md`, `docs/106-future-true-ux-restore-final-stop-line-handoff.md`, `docs/107-future-true-ux-restore-stop-line-decision-matrix.md` | Keep active. These define current governance, safety boundary, manual handoff, and final stop-line semantics. |
| Active validation and gate documents | `docs/09-*.md` through `docs/64-*.md` for Issues #6-#18, plus `docs/66-*.md` through `docs/79-*.md` where referenced by current quality gates or validators | Keep in place while corresponding Pester tests, quality gates, or Build Lock entries reference them. They are still part of the validation graph even when a roadmap issue has already been manually closed. |
| Superseded Future True UX Restore stage documents | `docs/80-*.md` through `docs/105-*.md` | Treat as superseded stage evidence, not canonical planning instructions. They should remain available until a follow-up governance PR either archives them with updated references or proves no gate/test/Build Lock dependency remains. |
| Archive candidates | Future True UX drill transcripts, decision ledgers, lessons, packet-preview maps, blocker indexes, and handoff placeholder documents in `docs/81-*.md` through `docs/105-*.md` | Candidate only. Many are directly referenced by Pester and Build Lock. Do not move in this task. A follow-up should create an explicit archive plan and update references atomically. |
| Delete candidates | None identified as safe for immediate deletion | No deletion in this audit. Current references are dense enough that deletion-first cleanup would be risky without a dedicated reference-removal PR. |
| Must not move in this task | `README.md`, `AGENTS.md`, `docs/codex-workflow.md`, `docs/32-issue12-build-lock.md`, `docs/40-issue14-quality-gates.md`, `docs/58-*.md` through `docs/64-*.md`, `docs/65-*.md` through `docs/107-*.md` | These are referenced by README, Quality Gates, Build Lock, Pester, validator report builders, or Future True UX handoff manifests. |

## Script And Fixture Inventory

| Area | Classification | Files / patterns | Governance decision |
|---|---|---|---|
| `scripts/common/` core helpers | Canonical / active | `Resolve-KitPath.ps1`, `Resolve-KitEffectiveConfiguration.ps1`, `Get-KitBuildLock.ps1`, `Test-KitBuildLock.ps1`, `New-KitBuildLockReport.ps1`, `New-KitQualityGateReport.ps1`, `New-StepResult.ps1`, package, state, evidence, and UX report helpers | Keep active. These are shared runtime or report-only helpers used by current validators and tests. |
| `scripts/common/` Future True UX report builders | Report-only historical guardrail | `New-FutureTrueUxRestore*.ps1` | Keep for now. They protect no-execution, no-auto-close, review-packet, and final stop-line semantics. Candidate for consolidation after references are mapped by stage. |
| `scripts/validate/` project gates | Canonical / active | `Test-ProjectConfig.ps1`, `Test-QualityGates.ps1`, `Test-BuildLock.ps1`, `Test-CapabilityRegistry.ps1`, `Test-EffectiveConfiguration.ps1`, `Test-EvidenceChain.ps1`, `Test-ControlledExecution.ps1`, `Test-UserExperienceRestore.ps1` | Keep active. These are current quality gate entrypoints. |
| `scripts/validate/` Future True UX validators | Report-only historical guardrail | `Test-FutureTrueUxRestore*.ps1` | Keep until a follow-up governance chain decides which historical stage gates should become archived/manual instead of required PR-fast gates. |
| `scripts/config/` display helpers | Active operator previews | `Show-CustomizationScope.ps1`, `Show-EffectiveConfiguration.ps1`, `Show-ControlledExecutionPlan.ps1`, `Show-UserExperienceRestorePlan.ps1` | Keep active. These are safe preview/report entrypoints. |
| `scripts/config/` Future True UX previews | Candidate for consolidation | `Show-FutureTrueUxRestore*.ps1` | Keep as report-only previews for now. Consolidation candidate because several plan displays differ mostly by stage vocabulary. |
| `tests/pester/` issue acceptance and evidence tests | Active / historical guardrail | `Issue6*.Tests.ps1` through `Issue18*.Tests.ps1` | Keep while they guard roadmap history, no auto-close wording, Build Lock references, and README links. Older issue tests may become archive candidates only after a policy decision. |
| `tests/pester/` Future True UX tests | Report-only historical guardrail | `FutureTrueUxRestore*.Tests.ps1` | Keep in place. They are the strongest current protection against accidental execute-ready, real-evidence, and auto-close drift. Candidate for grouped consolidation after the next governance task. |
| `tests/fixtures/` active fixtures | Active | `controlled-execution`, `evidence-chain`, `user-experience/handlers`, `user-experience/template-metadata`, `user-experience/verification` | Keep. These support current report-only validation. |
| `tests/fixtures/user-experience/future-true-restore/` | Report-only historical guardrail | `authorization`, `current-user`, `default-user`, `offline-image`, `machine`, `review`, `mock-review`, `negative-review`, `approval-checklist`, `packet-preview`, `human-authorization-handoff`, `no-execution-readiness-audit`, `final-stop-line-handoff` | Keep. They are non-mutating guardrails and should not be collapsed until validator consolidation happens. |
| Dangerous / requires high-risk chain | Real mutation logic and real execution scopes | Any future registry, Defender, AppX, Junction, Service, Sysprep, DISM, installer, download, profile, Start menu, taskbar, default-app, image, or WinPE execution path | Out of scope. This audit does not approve or execute those paths. |

## Quality Gate And Build Lock Alignment

Observed alignment:

- Quality Gates contain 69 gates. Seventeen are Future True UX gates, all currently required and report-only.
- Build Lock contains Future True UX documents, manifests, schemas, report builders, validators, fixtures, and Pester tests for the full preparation chain.
- README points users to the Issue #18 report-only stage, manual handoff, execution split, authorization intake, evidence model, and dry-run plan.
- Pester directly reads many Future True UX documents by path, especially `docs/65-*.md` through `docs/107-*.md`.

Governance findings:

| Finding | Evidence | Recommendation |
|---|---|---|
| Gate placement is scattered by issue chronology rather than one governance section | Future True UX gates appear after Issue #18 gates, among controlled-execution gates, and near later Issue #15/#16 entries in `manifests/quality-gates.json` | Follow-up PR should group Future True UX gates or add a manifest-level grouping convention without changing CI behavior. |
| Gate naming style is mostly consistent but not uniform | Gate IDs mix `future-true-ux-restore-*`, `future-true-ux-*`, and scope-specific names | Follow-up should decide whether ID churn is worth it. If renamed, update Build Lock, Pester expectations, reports, and PR body notes together. |
| Historical stage gates are still required | Mock drill, negative drill, checklist ergonomics, packet preview, human handoff, end-to-end audit, and final stop-line are required PR-fast gates | Keep for now. These protect safety boundaries, but a future governance task may demote some to manual/archive after preserving the final stop-line guard. |
| Build Lock points to superseded stage docs by design | `docs/80-*.md` through `docs/105-*.md` are locked and tested | Do not remove from Build Lock in this task. First create an archive policy and then update paths/hashes/tests in one PR. |
| Tests protect historical stage docs | `FutureTrueUxRestore*.Tests.ps1` includes explicit path assertions for most Future True UX documents | Keep tests until references are consolidated. Any archive move must update tests in the same PR. |

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
- Existing quality gate ordering and required flags
- Existing Build Lock entries and hashes
- Existing Future True UX manifests, schemas, validators, fixtures, and report builders
- Any docs archive, move, rename, or delete operation
- Any true execution or system mutation path

## Next Recommended Governance Task

Create a narrow follow-up PR that chooses one of these paths:

1. Group Future True UX quality gates in `manifests/quality-gates.json` without changing required/report-only semantics.
2. Add an archive policy for superseded Future True UX stage documents, then move only documents whose README, Build Lock, validator, and Pester references are updated in the same PR.
3. Consolidate duplicate Future True UX report-only validators after proving the final stop-line, no-execution, no-auto-close, and evidence-boundary assertions remain covered.

Recommended order: start with quality gate grouping and naming policy, then archive planning, then validator consolidation. That keeps the safety net intact while reducing visual clutter.
