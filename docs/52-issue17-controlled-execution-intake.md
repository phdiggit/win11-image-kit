# Issue #17 Controlled Execution Intake

Status: `in-progress`

## Source

- GitHub Issue: https://github.com/phdiggit/win11-image-kit/issues/17
- Title: `[P1] 为 WinPE 增加受控执行模式、磁盘身份校验和 Windows RE 配置`
- State at intake: `OPEN`

Issue #17 requests a future WinPE controlled execution mode that keeps plan-only behavior by default, then later allows explicitly enabled execution with disk identity checks, WIM SHA256 verification, native command exit-code capture, Windows RE setup, and report output.

## Roadmap Link

- Roadmap: https://github.com/phdiggit/win11-image-kit/issues/19
- Roadmap title: `[Roadmap] Windows 11 镜像工具箱可靠性与可重复性优化总览`
- Roadmap entry: `#17 为 WinPE 增加受控执行模式、磁盘身份校验和 Windows RE 配置`
- Roadmap ordering note: Issue #17 is listed late in P1, after evidence-chain work, with the warning that default plan mode must always remain.

## Problem Statement

Current WinPE scripts are safe because they print DISM, bcdboot, or DiskPart plans instead of mutating disks by default. The next lifecycle layer needs a controlled execution bus before any real WinPE or disk action can be considered.

This first Issue #17 stage only records the real intake and creates a dry-run / WhatIf / report-only baseline. It does not implement real execution.

## Scope

- Add a controlled execution manifest and schema.
- Define default execution modes: `dry-run`, `what-if`, `plan-only`, and `manual`.
- Generate a structured plan report from the manifest.
- Validate safety defaults, blocked mutation semantics, and report contract.
- Wire PR Fast CI, Quality Gates, Build Lock, README, and Pester coverage.
- Add acceptance scaffolding in `docs/53-issue17-controlled-execution-acceptance.md`.

## Non-goals

- No real WinPE build or boot media creation.
- No real image build, capture, or deploy.
- No disk, partition, BCD, WinRE, DISM, Sysprep, AppX, Defender, Junction, Service, registry, profile, or hive mutation.
- No software install, uninstall, upgrade, network package lookup, or network download.
- No `paths.local.json`, local private artifact, or machine-local report artifact in Build Lock.
- No Issue #17 close-prep, main-evidence, or completion summary.
- No automatic closure of Issue #17.
- No edits to Issue #6-#16 close-prep, main-evidence, or completion summary documents.

## Execution Modes

| Mode | Current behavior | Real mutation allowed |
|---|---|---|
| `dry-run` | Build a report-only execution plan from manifest actions. | No |
| `what-if` | Same as dry-run, with `whatIf=true` in reports. | No |
| `plan-only` | Show planned actions without invoking action entrypoints. | No |
| `manual` | Mark actions as manual review only. | No |

Future `controlled-real` behavior is intentionally out of scope. True execution must not be enabled by omission or default.

## Safety Boundaries

The baseline requires:

- `allowTrueExecution=false`
- `trueExecutionDefault=false`
- `whatIf=true`
- `trueExecution=false`
- mutation flags set to false
- action entrypoints treated as strings only, never invoked
- mutation or network actions blocked by validation unless they are a deliberate failure fixture

## Proposed Manifest / Schema

The baseline manifest is `manifests/controlled-execution.json`.

The manifest schema is `schemas/controlled-execution.schema.json`; it is closed and keeps real execution out of the mode enum.

The report schema is `schemas/controlled-execution-report.schema.json`; it is closed and requires `whatIf=true` plus `trueExecution=false`.

## Report Contract

`scripts/common/New-KitControlledExecutionReport.ps1` emits:

- `reportType=controlled-execution`
- `schemaVersion=1`
- `executionSetId`
- `mode`
- `whatIf=true`
- `trueExecution=false`
- summary counts for planned, blocked, failed, admin, WinPE, reboot, network, and mutation signals
- per-action plan entries with `riskLevel`, `requiresAdmin`, `requiresWinPE`, `requiresReboot`, `requiresNetwork`, `mutationKind`, and `evidenceProducer`
- safety flags proving mutation and network download remain disabled

`scripts/validate/Test-ControlledExecution.ps1` exits 1 when `failedCount > 0` or `blockedActionCount > 0`.

## CI / Quality Gates / Build Lock

- PR Fast CI runs `scripts/validate/Test-ControlledExecution.ps1`.
- PR Fast CI includes Issue #17 and ControlledExecution Pester tests.
- Quality Gates include `controlled-execution`, `issue17-intake`, and `issue17-acceptance`.
- Build Lock covers the Issue #17 docs, manifest, schemas, scripts, fixtures, tests, README, workflow, and quality gates.
- PR Fast CI is not main or workflow evidence.

## Acceptance Checklist

- [ ] Issue #17 source and Roadmap #19 source recorded.
- [ ] `docs/53` exists with `Status: in-acceptance`.
- [ ] Manifest/schema/report schema parse.
- [ ] Runner emits dry-run / WhatIf report only.
- [ ] Blocked mutation fixtures fail validation.
- [ ] Dangerous command patterns are absent from new Issue #17 scripts.
- [ ] Quality Gates and Build Lock are synchronized.
- [ ] No Issue #17 close-prep, main-evidence, or completion summary exists.

## Related Documents

- [Issue #17 Controlled Execution Acceptance](53-issue17-controlled-execution-acceptance.md)
- [Issue #16 Evidence Chain Acceptance](49-issue16-evidence-chain-acceptance.md)
- [Issue #16 Close Preparation](50-issue16-close-preparation.md)
- [Issue #16 Main Validation Evidence](51-issue16-main-validation-evidence.md)
