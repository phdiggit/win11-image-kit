# Issue #16 Evidence Chain Acceptance

Status: `in-acceptance`

## Scope

This page records the Issue #16 acceptance hardening stage for the evidence chain report. The current scope is still report-only and fixture-backed: Run ID linkage, artifact identity, producer normalization, redaction policy, and PR Fast CI guardrails.

This is not a close-prep page, not a main validation evidence page, and not a completion summary.

## Acceptance Matrix

| Area | Current evidence | Status |
|---|---|---|
| Run ID format | `runId` is generated and schema/validator checked. | covered by fixture |
| Upstream linkage | `upstreamRunId`, lifecycle fields, and stage links are modeled. | covered by fixture |
| Artifact index | Report JSON, manifest snapshot, effective config, and WIM placeholder artifacts are indexed. | covered by fixture |
| Producer normalization | ProjectConfig, BuildLock, QualityGates, EffectiveConfiguration, and Pester summary stay normalized. | covered by fixture |
| Manual lifecycle placeholders | build/capture/deploy/admin-smoke are manual or not-captured only. | covered by fixture |
| Redaction policy | Redacted values are counted and blocked sensitive fields fail validation. | covered by fixture |
| Real WIM evidence | No real WIM hash or DISM image info is claimed. | remaining work |
| Real deployment evidence | No real target hardware, disk, or deployment report is claimed. | remaining work |

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

## Producer Normalization

The normalized producer envelope keeps these sources in report-only or fixture mode:

- `project-config`
- `build-lock`
- `quality-gates`
- `effective-configuration`
- `pester-summary`

Future `real-build`, `capture`, `deploy`, and `admin-vm-smoke` producers remain manual or not-captured in this stage. They cannot be counted as passed in PR Fast CI.

## Redaction Policy

The manifest defines forbidden field names for `password`, `token`, `secret`, `privateKey`, `credential`, and `username`. Sensitive values must be absent or represented as `<redacted>`. Redacted fixture values are counted in `redactions.redactedCount`; unredacted blocked fields increment `redactions.blockedCount` and fail validation.

## Evidence Chain Report Contract

The hardened report includes:

- `runId`
- optional `upstreamRunId`
- `lifecycle`
- `stageLinks`
- `artifactIndex`
- `redactions`
- existing stage/evidence/safety summaries

`summary.failedCount > 0` and `redactions.blockedCount > 0` both fail validation. Manual and not-captured evidence is explicit but never counted as passed.

## CI / Quality Gates / Build Lock

PR Fast CI runs `Test-EvidenceChain.ps1` and the EvidenceChain/Issue16 Pester coverage. Quality Gates keep the `evidence-chain` gate in `report-only` mode. Build Lock covers docs, schemas, manifest, scripts, fixtures, tests, workflow, README, and Quality Gates wiring.

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
- No Issue #16 close-prep, main validation evidence, or completion summary.
- No automatic Issue #16 closure.

## Remaining Work

- Normalize more actual producer reports after they exist.
- Decide when a later task may collect real build/capture/deploy evidence.
- Prepare a future close-prep candidate only after maintainers decide the evidence model is sufficient.

## Related Documents

- [Issue #16 Evidence Chain Report](48-issue16-evidence-chain-report.md)
- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Issue #14 Quality Gates](40-issue14-quality-gates.md)
- [Issue #12 Build Lock](32-issue12-build-lock.md)
