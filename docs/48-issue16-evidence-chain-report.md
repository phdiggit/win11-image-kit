# Issue #16 Evidence Chain Report

Status: `in-progress`

## Source

- GitHub Issue #16: `[P1] 建立贯穿构建、捕获、部署和验收的证据链报告`
- Issue URL: `https://github.com/phdiggit/win11-image-kit/issues/16`
- Roadmap source: README 指向的 Roadmap 入口为 GitHub Issue #19；本阶段以真实 Issue #16 和本任务卡共同限定范围。
- Upstream relationship:
  - Issue #6 established the result model and report semantics for required failures, manual items, and reboot requirements.
  - Issue #12 established Build Lock as the immutable input review signal.
  - Issue #14 established Quality Gates and the PR Fast CI / Full Validate split.
  - Issue #15 established effective configuration and local override redaction.
  - Existing report-only validators and Pester fixtures remain the first producers for this baseline.

## Scope

- Define a versioned evidence chain manifest.
- Define a closed evidence chain report contract with producer metadata, source metadata, safety flags, artifact references, and summary counts.
- Add a fixture-backed sample input set and sample report.
- Add a report-only aggregator script.
- Add a validator that checks manifest, producer, report, source, artifact, and safety rules.
- Add a read-only display entrypoint.
- Wire the baseline into PR Fast CI, Quality Gates, Build Lock, README, and Pester.
- Keep real lifecycle phases as manual or not-captured placeholders.

## Non-goals

- No real Windows image build.
- No real capture.
- No real deploy.
- No disk, partition, BCD, or WinRE operation.
- No DISM, Sysprep, AppX, Defender, Junction, registry, profile, hive, or service mutation.
- No software install, uninstall, or upgrade.
- No network package lookup or download.
- No signing service call.
- No admin or VM smoke evidence claim.
- No automatic Issue #16 closure.
- No Issue #16 close-prep, main-evidence, or completion summary.
- No changes to Issue #6 through Issue #15 close-prep, main-evidence, or completion summary documents.

## Current Repository Touchpoints

- `scripts/validate/Test-ProjectConfig.ps1` already emits project configuration validation reports.
- `scripts/validate/Test-BuildLock.ps1` already emits Build Lock reports.
- `scripts/validate/Test-QualityGates.ps1` already emits Quality Gates reports.
- `scripts/validate/Test-EffectiveConfiguration.ps1` already emits effective configuration reports.
- `.github/workflows/ci.yml` already separates PR `Validate` from non-PR `Full Validate`.
- `manifests/build-lock.json` and `manifests/quality-gates.json` are the trusted control-plane manifests for this baseline.

## Evidence Chain Model

The chain is a report-only index over stage evidence. A stage can be `config`, `validate`, `build`, `capture`, `deploy`, or `acceptance`. Each producer declares one stage, one mode, one entrypoint, and one report type. Allowed producer modes are `static`, `fixture`, `report-only`, and `manual`; `true-execution` is intentionally not part of the schema.

Evidence items record:

- who produced the evidence (`producerId`, `producerMode`, `entrypoint`);
- when it was recorded (`generatedAt`);
- which source context it belongs to (`source.kind`, optional SHA, workflow run, job);
- whether it is manual and reproducible;
- which artifacts are referenced;
- whether the status is `passed`, `failed`, `manual`, or `not-captured`.

Manual and not-captured items are explicit review signals. They are not failures, and they are not counted as passed.

## Report Contract

The report contract is defined by `schemas/evidence-chain-report.schema.json`.

Required top-level fields:

- `reportType = evidence-chain`
- `schemaVersion = 1`
- `generatedAt`
- `repository`
- `source`
- `status`
- `summary`
- `stages`
- `evidence`
- `safety`

`summary.failedCount > 0` is a validator failure and returns exit code 1. `manualCount` and `notCapturedCount` are allowed in the baseline because real build, capture, deploy, and admin or VM smoke evidence require a later explicit approval boundary.

## Producer Map

| Producer | Stage | Mode | Baseline status |
|---|---|---|---|
| `project-config` | `validate` | `report-only` | fixture-backed passed |
| `build-lock` | `validate` | `report-only` | fixture-backed passed |
| `quality-gates` | `validate` | `report-only` | fixture-backed passed |
| `effective-configuration` | `config` | `report-only` | fixture-backed passed |
| `pester-summary` | `validate` | `fixture` | fixture-backed passed |
| `real-build` | `build` | `manual` | not-captured |
| `capture` | `capture` | `manual` | not-captured |
| `deploy` | `deploy` | `manual` | not-captured |
| `admin-vm-smoke` | `acceptance` | `manual` | manual |

The manual producers describe later work only. They require a later Issue, explicit approval, and true-execution boundary before they can become real evidence.

## Aggregator / Validator

- Aggregator: `scripts/common/New-KitEvidenceChainReport.ps1`
- Validator: `scripts/validate/Test-EvidenceChain.ps1`
- Display entrypoint: `scripts/config/Show-EvidenceChain.ps1`

The aggregator reads `manifests/evidence-chain.json` and fixture/report JSON input from `tests/fixtures/evidence-chain/sample-report-inputs`. It normalizes producer evidence into a single report. It does not execute build, capture, deploy, install, service, network, registry, profile, or hive actions.

## Safety Boundaries

The baseline safety object must remain:

```json
{
  "trueExecution": false,
  "localPrivateIncluded": false,
  "networkUsed": false,
  "mutationUsed": false
}
```

Artifact references must be repo-relative review artifacts or documented manual placeholders. `manifests/paths.local.json`, secrets, user-profile paths, private local reports, and local machine-only artifacts are not allowed.

## Validation Plan

- Parse the evidence chain manifest and schemas.
- Validate producer IDs are unique.
- Validate stages and modes against the schema enums.
- Validate producer entrypoints exist unless they are explicit `manual://` placeholders.
- Validate fixture inputs and generated reports.
- Validate optional SHA is 40 lowercase or uppercase hex.
- Validate workflow and job URLs are GitHub Actions URLs.
- Validate safety flags are false.
- Validate `failedCount > 0` exits 1.
- Validate manual and not-captured items are counted but not treated as passed.
- Validate no auto-close wording for Issue #16.
- Validate no Issue #6 through Issue #15 close artifacts are modified in this stage.

## Quality Gates / Build Lock

- `manifests/quality-gates.json` adds the `evidence-chain` PR Fast gate in `report-only` mode.
- `.github/workflows/ci.yml` runs `Test-EvidenceChain.ps1` and the EvidenceChain/Issue16 Pester tests in PR `Validate`.
- `manifests/build-lock.json` covers the new docs, manifest, schemas, scripts, fixtures, tests, workflow, README, and Quality Gates entry.
- Build Lock remains a review signal; it does not run real lifecycle actions.

## Acceptance Checklist

- [x] Issue #16 source and Roadmap source are recorded.
- [x] Scope and non-goals are explicit.
- [x] Evidence chain manifest exists.
- [x] Evidence chain report schema exists.
- [x] Fixture report inputs exist.
- [x] Report-only aggregator exists.
- [x] Validator exists and exits 1 when `failedCount > 0`.
- [x] Display entrypoint exists.
- [x] Manual build/capture/deploy/admin-smoke placeholders are not passed.
- [x] PR Fast CI wiring exists.
- [x] Quality Gates wiring exists.
- [x] Build Lock coverage exists.
- [x] README links the Issue #16 entry.
- [x] No true-execution gate is introduced.
- [x] No private local artifact is introduced.
- [x] No Issue #16 close-prep, main-evidence, or completion summary is introduced.

## Related Documents

- [Issue #6 Completion Summary](12-issue6-completion-summary.md)
- [Issue #12 Build Lock](32-issue12-build-lock.md)
- [Issue #14 Quality Gates](40-issue14-quality-gates.md)
- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Codex Workflow](codex-workflow.md)
