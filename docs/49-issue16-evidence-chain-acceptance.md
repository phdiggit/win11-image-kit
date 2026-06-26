# Issue #16 Evidence Chain Acceptance

Status: `accepted-pending-main-validation`

## Scope

This page records the Issue #16 report-only and fixture-backed acceptance state for the evidence chain report. Run ID linkage, artifact identity, redaction policy, producer normalization, producer adapters, and report input index guardrails are accepted for PR Fast CI review.

This is still not a final closure page, not a main validation evidence page, and not a completion summary. Issue #16 remains open until maintainers review the pending main/workflow evidence scaffold and decide whether manual closure is appropriate.

## Acceptance Matrix

| Area | Current evidence | Status |
|---|---|---|
| Run ID format | `runId` is generated and schema/validator checked. | accepted |
| Upstream linkage | `upstreamRunId`, lifecycle fields, and stage links are modeled. | accepted |
| Artifact index | Report JSON, manifest snapshot, effective config, and WIM placeholder artifacts are indexed. | accepted |
| Producer normalization | ProjectConfig, BuildLock, QualityGates, EffectiveConfiguration, and Pester summary stay normalized. | accepted |
| Producer adapter | Input index driven adapters consume declared report-only producer reports. | accepted |
| Report input index | Required producer inputs, report types, and path policy are validated. | accepted |
| Manual lifecycle placeholders | build/capture/deploy/admin-smoke are manual or not-captured only. | accepted |
| Redaction policy | Redacted values are counted and blocked sensitive fields fail validation. | accepted |
| Real WIM evidence | No real WIM hash or DISM image info is claimed. | pending main/manual evidence |
| Real deployment evidence | No real target hardware, disk, or deployment report is claimed. | pending main/manual evidence |

## Run ID / Upstream Linkage

The accepted report-only model uses `kit-run-<yyyyMMddTHHmmssZ>-<shortSha>`.

- `runId` is required.
- `upstreamRunId` is optional and must match the same pattern when present.
- `configRunId` and `validateRunId` point to the current run.
- `buildRunId`, `captureRunId`, and `deployRunId` remain `not-captured`.
- `acceptanceRunId` remains `manual`.

This links the lifecycle without pretending that build, capture, deploy, or admin/VM smoke has actually run.

## Artifact Index

The artifact index records lightweight evidence identity:

- `kind`
- `path` or `logicalName`
- optional `sha256`
- optional `sizeBytes`
- `producerId`
- `stage`
- `runId`
- optional `upstreamRunId`
- `private`
- `redacted`

Valid baseline artifacts are repo-relative reports, tracked manifest snapshots, redacted fixture reports, and logical not-captured WIM placeholders. Private local paths, absolute drive paths, UNC paths, `secrets/`, user-profile paths, and `manifests/paths.local.json` are rejected.

## Producer Adapter / Report Input Index

The accepted adapter contract is driven by `manifests/evidence-report-inputs.json` and `schemas/evidence-report-inputs.schema.json`.

Each input declares:

- `producerId`
- repo-relative report `path`
- `expectedReportType`
- whether the report is required
- whether missing, manual, or not-captured values are allowed

The aggregator reads declared report JSON files and converts them through a normalized producer item contract. Missing required reports, reportType mismatches, failed reports, disallowed manual reports, disallowed not-captured reports, unknown producer IDs, and private or local-only paths fail validation.

The directory fallback remains only for fixture compatibility and does not execute any producer.

## Producer Normalization

The normalized producer envelope keeps these sources in report-only or fixture mode:

- `project-config`
- `build-lock`
- `quality-gates`
- `effective-configuration`
- `pester-summary`

Future `real-build`, `capture`, `deploy`, and `admin-vm-smoke` producers remain manual or not-captured in this stage. They cannot be counted as passed in PR Fast CI.

The report includes `producerNormalization` with:

- `normalizedCount`
- `missingRequiredCount`
- `reportTypeMismatchCount`
- `disallowedManualCount`
- `disallowedNotCapturedCount`
- `inputPolicyViolationCount`
- `unmatchedInputCount`

All failure counters must be zero for the baseline validator to exit successfully.

## Redaction Policy

The manifest defines forbidden field names for `password`, `token`, `secret`, `privateKey`, `credential`, and `username`. Sensitive values must be absent or represented as `<redacted>`. Redacted fixture values are counted in `redactions.redactedCount`; unredacted blocked fields increment `redactions.blockedCount` and fail validation.

## Evidence Chain Report Contract

The accepted report includes:

- `runId`
- optional `upstreamRunId`
- `inputSetId`
- `inputReports`
- `producerNormalization`
- `lifecycle`
- `stageLinks`
- `artifactIndex`
- `redactions`
- existing stage/evidence/safety summaries

`summary.failedCount > 0`, `redactions.blockedCount > 0`, and any producer normalization failure counter greater than zero fail validation. Manual and not-captured evidence is explicit but never counted as passed.

## CI / Quality Gates / Build Lock

PR Fast CI runs `Test-EvidenceChain.ps1` and the EvidenceChain/Issue16 Pester coverage. Quality Gates keep the `evidence-chain` gate in `report-only` mode and add Issue #16 acceptance, close-prep candidate, and main-evidence scaffold gates. Build Lock covers docs, schemas, manifest, scripts, fixtures, tests, workflow, README, and Quality Gates wiring.

PR Fast CI is not main/workflow evidence.

## Non-goals

- No real Windows image build.
- No real capture.
- No real deploy.
- No real WIM SHA256 or DISM image info.
- No disk, partition, BCD, or WinRE operation.
- No AppX, Defender, Junction, service, registry, profile, or hive mutation.
- No software install, uninstall, or upgrade.
- No network package lookup or download.
- No local private report artifact upload.
- No Issue #16 completion summary.
- No automatic Issue #16 closure.

## Remaining Work

- Backfill `docs/51-issue16-main-validation-evidence.md` only after real successful main push or workflow_dispatch evidence exists; the post-PR #83 main push failure remains blocked evidence only.
- Maintainer review of [Issue #16 Close Preparation](50-issue16-close-preparation.md) remains manual.
- Real build/capture/deploy/admin-smoke evidence remains not-run, not-captured, or not-provided unless maintainers explicitly perform it later.

## Related Documents

- [Issue #16 Evidence Chain Report](48-issue16-evidence-chain-report.md)
- [Issue #16 Close Preparation](50-issue16-close-preparation.md)
- [Issue #16 Main Validation Evidence](51-issue16-main-validation-evidence.md)
- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Issue #14 Quality Gates](40-issue14-quality-gates.md)
- [Issue #12 Build Lock](32-issue12-build-lock.md)
