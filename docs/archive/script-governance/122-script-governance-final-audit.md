# Script Governance Final Audit / Stop-Line

Status: `script-governance-final-audit`

Issue: Refs #19

Date: 2026-06-30

## Boundary

This is the final broad script governance audit after the Build Lock normalization pass. It is report-only lifecycle governance. It does not introduce new feature behavior, does not change quality gate IDs or semantics, and does not authorize true UX restore. CI repair in this PR may remove `.github/workflows/ci.yml` PR Fast Pester references to files deleted by this same PR; it must not change workflow triggers, runner choice, quality gate semantics, or execution behavior.

Frozen execution state for this audit:

| Field | Required value |
|---|---|
| `authorizationApproved` | `false` |
| `executionApproved` | `false` |
| `executeReady` | `false` |
| `trueExecution` | `false` |
| `mutationCount` | `0` |

No registry, DISM, Sysprep, WinPE, AppX, Defender, service, Junction, package install, download, user profile, Start menu, taskbar, default-app, image servicing, VM, or true restore mutation is allowed by this record.

## Script Surface Inventory

| Area | Current state | Decision |
|---|---|---|
| `scripts/common/` | Stable / stop broad governance | Core helpers and Future True UX guard and validator primitives are reasonably consolidated. Keep existing shared helper families. Add new helpers only when a repeated pattern has at least two clear call sites and cannot be handled by an existing helper. |
| `scripts/validate/` | Stable / lifecycle monitoring only | Public quality gate validators are separate on purpose, while Future True UX validator plumbing is consolidated behind shared primitives. Keep current public entrypoints for gate stability. |
| `scripts/config/` | Stable / lifecycle monitoring only | Operator show/config scripts remain read-only previews. Future True UX presentation-only scripts were pruned under #121; public operator script names remain stable for users and tests. |
| `scripts/dev/` | Intentionally separate | Developer helpers are allowed only when they support a recurring workflow. `pr_body_tool.py` and run-artifact collection are recurring workflow helpers. One-time migration or normalization helpers must be deleted after use. |
| `tests/pester/` | Needs lifecycle monitoring only | The suite is large but useful: issue-history tests protect completed-roadmap contracts, and Future True UX tests protect no-execution and no-auto-close boundaries. No broad deletion in this task. |
| `tests/fixtures/` | Stable / intentionally separate | Controlled execution, evidence-chain, user-experience, and Future True UX fixtures encode separate positive and negative policy cases. Keep fixture families scoped to their validators. |
| `manifests/build-lock.json` | Stable with documented manual self-watch | Current policy keeps Build Lock normalized with no failed mismatches and accepts only `manifests/build-lock.json` as the manual self-watch item. Updates must be scoped to files touched by a PR unless a dedicated normalization task says otherwise. |
| `manifests/quality-gates.json` | Stable / deletion-first lifecycle | Retained Future True UX gates remain `pr-fast`, `pull_request`, `report-only`, `required=true`, and `blocking=true`. Preparation-only document gates may be removed only when retained gates preserve the same safety invariant and docs, tests, and Build Lock are updated together. |
| `docs/archive/` | Stable / lifecycle monitoring only | Archive records are complete enough to explain completed-roadmap, Future True UX, Build Lock, and script governance decisions. Add archive docs only for durable decisions or handoffs. |

## Ephemeral Script Deletion Audit

This audit applies the deletion-first rule for non-long-term scripts and script-like test surfaces. A file is long-term only if it is a public operator entrypoint, a quality gate entrypoint, a recurring developer workflow helper, or a durable Pester guardrail. A file is ephemeral if it exists only to complete one migration, one normalization pass, or one temporary governance batch.

| Area | Long-term entrypoints | Ephemeral / migration / governance-temporary review | Decision |
|---|---|---|---|
| `scripts/dev/` | `pr_body_tool.py` remains the recurring UTF-8 PR body workflow helper. `Collect-KitRunArtifacts.ps1` remains a recurring artifact collection helper for validation runs. | `update_build_lock_hashes.py` was created for the Task #121 Build Lock normalization pass and is not a recurring operator or CI entrypoint. Keeping it resident would make ordinary PRs more likely to absorb unrelated hash drift. | Delete `scripts/dev/update_build_lock_hashes.py` and remove its Build Lock entry. |
| `scripts/config/` | `Show-CustomizationScope.ps1`, `Show-EffectiveConfiguration.ps1`, `Show-ControlledExecutionPlan.ps1`, `Show-EvidenceChain.ps1`, and `Show-UserExperienceRestorePlan.ps1` remain public read-only preview entrypoints. | Future True UX show/config plans were pruned under #121 because validator reports now carry the durable report-only contract. Future one-shot display helpers should be replaced by docs or removed after the task. | Keep current operator previews; do not keep Future True UX presentation-only scripts resident. |
| `scripts/validate/` | `Test-ProjectConfig.ps1`, `Test-QualityGates.ps1`, `Test-BuildLock.ps1`, domain validators, and `Test-FutureTrueUxRestore*.ps1` remain quality gate or report contract entrypoints. | No standalone migration-only validator remains. Future temporary validators must either become a public gate with Build Lock coverage or be deleted when the migration ends. | Keep current validators; no deletion. |
| `tests/pester/` | Current Pester files remain durable guardrails for quality gates, Build Lock policy, completed-roadmap contracts, Future True UX no-execution policy, and this final audit. | Pester files are not runtime scripts. No unreferenced one-shot Pester file is identified after deleting the Task #121 helper assertions. Future migration-only tests must be retired with the temporary script they protect. | Keep current Pester guardrails; update tests to assert the deleted helper does not remain resident. |

Deletion performed by this PR update:

- `scripts/dev/update_build_lock_hashes.py`
- corresponding `manifests/build-lock.json` entry

No other ephemeral script is left resident in `scripts/dev/`, `scripts/config/`, or `scripts/validate/`.

## `scripts/validate/` Lifecycle Status

Current validator families:

| Family | Public quality gate entrypoints | Lifecycle status |
|---|---|---|
| Project/config/static validators | `Test-ProjectConfig.ps1`, `Test-QualityGates.ps1`, `Test-BuildLock.ps1` | Canonical PR-fast guardrails. Keep public. |
| Capability, context, effective configuration, ensure-state, evidence-chain, controlled execution, Sysprep, and UX validators | `Test-CapabilityRegistry.ps1`, `Test-ContextScope.ps1`, `Test-EffectiveConfiguration.ps1`, `Test-EnsureState.ps1`, `Test-EvidenceChain.ps1`, `Test-ControlledExecution.ps1`, `Test-SysprepReadiness.ps1`, `Test-UserExperienceRestore.ps1` | Domain validators are justified because each owns a separate manifest, report contract, or safety boundary. |
| Future True UX validators | `Test-FutureTrueUxRestore*.ps1` | Public gate entrypoints remain stable. Shared validator plumbing lives in `FutureTrueUxRestore.ValidatorPrimitives.ps1`; stage-specific checks stay readable in their entrypoint scripts. |

No duplicate or obsolete public validator entrypoint is identified for deletion. The public entrypoint count is justified by quality gate stability, report type stability, and separate safety domains.

Lifecycle rule for adding new validators:

- First check whether an existing validator can be parameterized safely.
- Prefer extending an existing helper family when the behavior is another check in the same safety domain.
- Add a new validator only for a new public gate, manifest family, report contract, or safety boundary.
- New validators must remain offline by default and must not perform system mutation.
- New public validators must be added to quality gate and Build Lock policy in the same task when they are gates.

Retirement criteria for old validators:

- The validator is no longer referenced by quality gates, docs, Build Lock, README, PR-fast tests, or operator workflow.
- Its safety checks are covered by an equal or stronger validator.
- The retirement PR documents the mapping from old checks to retained checks.
- Retiring the validator does not rename or demote quality gate IDs unless explicitly approved.

## `tests/pester/` Lifecycle Status

Current Future True UX governance tests are intentionally retained. They cover gate semantics, public validator entrypoints, no-execution fields, no auto-close wording, evidence-boundary wording, stage-specific negative fixtures, and dangerous-command scans.

Issue 11-18 and completed-roadmap tests are still intentionally retained because they protect historical acceptance records, Build Lock references, manual closure handoffs, report-only policy, and README or archive path stability. They are not duplicate merely because their issue stage is complete.

No obvious duplicate Pester file is safe to delete in this final audit. Later retirement candidates should be documented before deletion, especially if an issue-specific test becomes fully covered by a stronger current governance test.

Lifecycle rule for adding new Pester tests:

- Extend an existing governance test when the new assertion is another readable check in the same contract.
- Add a new Pester file only for a new durable safety boundary, manifest family, public entrypoint, or lifecycle handoff.
- Keep tests fixture-first, offline, and scoped to the current task.
- Do not add tests that only restate a broader existing assertion unless they protect a specific regression.

Retirement criteria for old stage-specific tests:

- The stage-specific document, script, or fixture is no longer a public gate or archive handoff.
- A stronger current test covers the same failure mode with equivalent or clearer evidence.
- Build Lock, quality gates, README links, and archive docs are updated in the same PR.
- The PR explains why the retirement does not weaken no-execution or report-only governance.

## Anti-Bloat Contract

Future tasks must follow this contract:

- No new script without checking the existing helper family first.
- No new validator if an existing validator can be parameterized safely.
- No new Pester file if an existing governance test can be extended readably.
- No new archive doc unless it records a durable decision or handoff.
- One-time migration, normalization, or governance helper scripts must be deleted before the stop-line unless they are promoted to a documented recurring workflow.
- Build Lock updates must be scoped except in dedicated normalization PRs.
- Quality gate changes must preserve IDs and report-only semantics unless explicitly approved.
- Future True UX true-execution work must remain outside the current report-only chain.
- Recurring developer helpers may stay in `scripts/dev/` only with documented usage boundaries and offline/local defaults.
- Report-only validators and retained show/config scripts must not call real mutation entrypoints.

## Stop-Line Decision

Script governance stop-line: reached

The current `scripts/common/` surface is reasonably consolidated. The `scripts/validate/` lifecycle is under control. The `scripts/config/` lifecycle is under control. Future True UX Restore script surfaces are stable. Build Lock and quality gate boundaries are stable. Pester tests are useful, scoped, and not currently duplicative enough to justify deletion. Docs/archive governance records are complete enough for the current handoff.

No further broad script consolidation is recommended. Future script changes should be narrow and task-driven.

Next recommended work: Issue #8-#13 Roadmap Re-entry Planning, or the next concrete non-governance roadmap package selected by the maintainer. If a future audit finds a specific blocker, open only a narrow follow-up for that blocker instead of another broad governance batch.

## Build Lock Discipline

This task may update `manifests/build-lock.json` only for files changed by this PR:

- `docs/archive/script-governance/122-script-governance-final-audit.md`;
- `tests/pester/ScriptGovernanceFinalAudit.Tests.ps1`;
- `docs/archive/build-lock/121-build-lock-normalization.md`;
- `tests/pester/BuildLockNormalization.Tests.ps1`;
- `.github/workflows/ci.yml` stale PR Fast Pester references to files deleted by this PR;
- `scripts/dev/update_build_lock_hashes.py` deletion;
- `manifests/build-lock.json` metadata for those entries.

Build Lock policy remains normalized with only the documented `manifests/build-lock.json` self-watch manual item. Any unrelated drift should be treated as external drift, checkout/network/CI behavior, or a future dedicated normalization issue, not absorbed here.

## Quality Gate Boundary

Every `future-true-ux*` gate remains:

| Field | Required value |
|---|---|
| `layer` | `pr-fast` |
| `trigger` | `pull_request` |
| `mode` | `report-only` |
| `required` | `true` |
| `blocking` | `true` |

Every retained gate entrypoint must continue to exist. No retained quality gate trigger, layer, mode, required flag, blocking flag, or report-only semantic changes are allowed by this audit.

## No True Execution

This final audit is documentation, Pester coverage, Build Lock metadata, deletion of the one-time Build Lock normalization helper, and CI repair for stale PR Fast Pester references to files deleted by this PR. It does not change workflow triggers, runner choice, quality gate semantics, or execution behavior. It does not perform or authorize any true UX restore or system mutation.
