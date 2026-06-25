# Issue #12 Close Preparation

Status: `ready-for-manual-closure-candidate`

## Final Scope

Issue #12 establishes an immutable Build Lock for selected trusted inputs. The shipped scope is manifest/schema validation, SHA256 hashing, lock loading, duplicate entry detection, hash drift detection, watched-but-untracked reporting, JSON report output, capability registry wiring, PR Fast CI guardrails, and documentation.

This close-preparation note is a candidate only. It does not claim main/workflow validation evidence and does not claim real VM or administrator smoke validation.

## Evidence Chain

- docs/32-issue12-build-lock.md
- docs/33-issue12-build-lock-acceptance.md
- docs/34-issue12-close-preparation.md
- docs/35-issue12-main-validation-evidence.md
- tests/pester/BuildLockSchema.Tests.ps1
- tests/pester/BuildLockHash.Tests.ps1
- tests/pester/BuildLockValidation.Tests.ps1
- tests/pester/BuildLockReport.Tests.ps1
- tests/pester/Issue12BuildLock.Tests.ps1
- tests/pester/Issue12BuildLockAcceptance.Tests.ps1
- tests/pester/Issue12ClosePrep.Tests.ps1
- tests/pester/Issue12MainValidationEvidence.Tests.ps1

## Validation Policy

- PR Fast CI validates schema, hash helper, loader, validator, report builder, CLI report behavior, acceptance guardrails, close-preparation guardrails, and main-evidence guardrails.
- PR Fast CI must not run real build, network access, signing, business handler, package retrieval, or system mutation.
- Main/workflow evidence is recorded in docs/35; while docs/35 is `pending-main-validation`, this document remains a manual-closure candidate.
- Real VM/admin smoke is optional manual evidence, not a PR Fast CI requirement.

## Manual Closure Checklist

- build-lock schema still rejects unknown fields.
- loader rejects duplicate entry paths.
- validator fails missing required files according to policy.
- validator fails hash mismatch according to policy.
- validator fails unsupported algorithms according to policy.
- report keeps watched-but-untracked files visible.
- validate entrypoint writes explicit reports only when requested.
- PR Fast CI includes every Issue #12 test.
- docs/35 remains pending until real main/workflow evidence is available.
- Issue #12 is handled manually by the maintainer after evidence review.

## Optional Manual Validation Evidence

| Evidence | Status | Notes |
| --- | --- | --- |
| main push Full Validate | pending | Recorded in docs/35 when available |
| workflow_dispatch Full Validate | pending | Recorded in docs/35 when available |
| real VM/admin smoke | not-run | Optional manual evidence |

## Closure Note Draft

Manual review candidate for Issue #12:

- Build Lock manifest/schema, helper, loader, validator, report, CLI, registry wiring, Pester guardrails, and docs are in place.
- PR Fast CI covers static, fixture, and report-only paths.
- Real build, network access, signing, system mutation, and business handler execution remain outside this scope.
- Main/workflow evidence should be reviewed in docs/35 before the maintainer performs final manual issue handling.

## Related Documents

- [Build Lock Runbook](32-issue12-build-lock.md)
- [Acceptance Matrix](33-issue12-build-lock-acceptance.md)
- [Main Validation Evidence](35-issue12-main-validation-evidence.md)
