# Issue #14 Quality Gates

Status: `in-progress`

## Scope

Issue #14 建立仓库质量门禁总线，把当前分散的 JSON/schema 校验、Pester 测试清单、PSScriptAnalyzer baseline、CI fast/full 分层和 Build Lock 证据约束统一记录下来。

本阶段覆盖：

- schema / JSON 静态校验入口和约束。
- Pester inventory 与 PR Fast CI / Full Validate 的测试分层。
- PSScriptAnalyzer 可用时报告、不可用时 warning/manual 的策略。
- CI workflow policy guardrails，防止 PR Fast CI 越界执行真实 build、mutation、network 或 registry/profile/hive 写入。
- Build Lock 对 Issue #14 文档、测试和 workflow 输入的覆盖。

## Non-goals

- 不执行真实 Windows image build。
- 不执行 DISM、Sysprep、AppX、Defender、Junction 或 service 真实 mutation。
- 不执行真实软件 install/uninstall/upgrade。
- 不执行真实 service start/stop/disable/delete。
- 不执行 network package lookup、download 或 signing service。
- 不写 registry/profile/hive。
- 不伪造 admin/VM smoke 或 main/workflow evidence。
- 不关闭任何 GitHub Issue。

## Quality Gate Inventory

| Layer | Trigger | Allowed | Forbidden |
| --- | --- | --- | --- |
| PR Fast CI | `pull_request` | JSON parse, PowerShell parse, project config validation, PSScriptAnalyzer baseline, fast Pester inventory | real mutation, network, signing, registry/profile/hive writes, real build |
| Full Validate | `main` push / `workflow_dispatch` | broader static checks, full Pester inventory, PowerShell 7 parity checks | real mutation, real build, network download, signing |
| Manual Evidence | maintainer-provided evidence | admin/VM smoke or real-world proof when explicitly performed | PR-authored fake evidence |
| Future True Execution | separate task/issue | real installer/service/build work with explicit approval and rollback | mixing real execution into Issue #14 |

## PR Fast CI

The PR gate is the `Validate` job in `.github/workflows/ci.yml`.

It runs only when `github.event_name == 'pull_request'`. It may parse JSON and PowerShell files, run `Test-ProjectConfig.ps1`, run PSScriptAnalyzer when available, and run the curated fast Pester list.

It must not run real build, real software installation, service mutation, network download, signing, registry/profile/hive writes, Sysprep/AppX/DISM/Defender/Junction mutation, or admin/VM smoke.

`Full Validate` being skipped on pull requests is expected and must not be treated as a PR failure.

## Full Validate

The heavier validation job is `Full Validate`.

It runs only when `github.event_name != 'pull_request'`, which currently means `main` push and `workflow_dispatch`. It runs the full Pester directory in Windows PowerShell and PowerShell 7 parity checks where available.

Full Validate is main/workflow evidence for validation health, but it still remains static/test/report oriented. It does not authorize real build or mutation.

## Schema / JSON Policy

- CI parses every `*.json` file under `manifests/` and `schemas/`.
- `scripts/validate/Test-ProjectConfig.ps1` remains the repository-level schema/config validation entrypoint.
- Schema guardrails should prefer closed objects, required fields, and explicit enums when the schema represents a manifest contract.
- Validation must not download external schema resources or call network services.

## Pester Inventory Policy

- PR Fast CI uses an explicit `$fastPesterPaths` list so branch protection remains predictable.
- Important issue guardrail tests must be intentionally listed in PR Fast CI when they are meant to protect PRs.
- Full Validate runs `tests/pester` as the broader inventory on `main` push and `workflow_dispatch`.
- Adding new Pester files requires updating CI wiring, documentation, and Build Lock when they are part of trusted validation.
- Local Pester 3 and GitHub Actions Pester 5 can differ; tests should use repo helpers and Pester-version-neutral patterns.

## PSScriptAnalyzer Policy

- PSScriptAnalyzer uses `PSScriptAnalyzerSettings.psd1`.
- CI reports available Pester and PSScriptAnalyzer modules before running checks.
- When `Invoke-ScriptAnalyzer` is unavailable, CI emits a warning and does not pretend that analyzer diagnostics were executed.
- Current baseline is non-blocking for analyzer diagnostics: diagnostics are printed as warnings, while missing module is also warning/manual.
- This issue does not add online module installation or network dependency installation.

## Build Lock Coverage

Build Lock is the trusted-input ledger for selected documents, tests, validate entrypoints, scripts, manifests, schemas, and workflow files.

Issue #14 adds this runbook and the Issue #14 Pester guardrails to Build Lock. CI workflow and README hashes are synchronized intentionally when they change.

`manual / failedCount=0` remains a review signal for watched-but-untracked files, not a failed validation.

## Quality Gate Manifest

`manifests/quality-gates.json` is the declarative inventory for Issue #14 gates. It lists each gate id, display name, layer, trigger, mode, blocking policy, entrypoint, evidence type, and notes.

`schemas/quality-gates.schema.json` keeps that inventory closed with explicit required fields and enums. It is parsed locally by Windows PowerShell and is validated through `Test-ProjectConfig.ps1`; it does not rely on external schema downloads.

## Quality Gate Runner

`scripts/validate/Test-QualityGates.ps1` is the report-only runner for this inventory. It reads the manifest, checks local entrypoints and selected workflow safety constraints, and returns a structured report.

The runner is not a build system and not a real execution engine. It does not run Pester, install analyzer modules, download packages, mutate services, write registry/profile/hive data, or build images.

## Quality Gate Report Contract

`scripts/common/New-KitQualityGateReport.ps1` produces the stable report object:

- `reportType`
- `status`
- `summary`
- `gates`
- `safety`

`manual / failedCount=0` is a review signal and exits 0. Any failed gate sets `failedCount > 0`, marks the report `failed`, and the validate entrypoint exits 1.

## Acceptance Scaffold Link

Issue #14 acceptance tracking starts in [Quality Gates Acceptance](41-issue14-quality-gates-acceptance.md). That document is intentionally `in-acceptance`; it is not close-preparation or main-validation evidence.

## Safety Boundaries

Issue #14 is a quality-gates and validation-orchestration issue. It is not a true execution issue.

Real build, real install/service work, admin/VM smoke, and machine remediation must be split into a separate task or issue with explicit approval, rollback, dry-run, allowlist, and evidence requirements.

PR Fast CI is not main/workflow evidence. Main/workflow evidence must come from `main` push or `workflow_dispatch`.

## Acceptance Checklist

- docs/40 exists and records the quality gate inventory.
- PR Fast CI / Full Validate split is documented and protected by Pester.
- Pester inventory guardrails ensure important Issue tests and Issue #14 tests are wired into CI.
- PSScriptAnalyzer policy matches workflow behavior and does not install dependencies online.
- Schema / JSON validation remains static and local.
- Build Lock covers Issue #14 docs/tests and changed workflow/README inputs.
- No real build, mutation, network download, signing, registry/profile/hive write, or fake smoke evidence is introduced.

## Related Documents

- [Build Lock](32-issue12-build-lock.md)
- [Issue #13 Ensure-State](36-issue13-ensure-state.md)
- [Codex Workflow](codex-workflow.md)
