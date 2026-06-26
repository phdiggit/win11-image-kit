# Issue #16 Main Validation Evidence

Status: `pending-main-validation`

## Evidence Sources

- main push Windows CI / Full Validate after close-prep PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual lifecycle evidence only if explicitly performed

Pull request-only Fast CI is not a substitute.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | `pending` |
| Main SHA | `pending` |
| Workflow run | `pending` |
| Full Validate job | `pending` |
| Result | `pending` |
| Notes | `Post-PR #83 main push run 28248115903 targeted 73861de486f3cf70c470548f1d446334f2f33481 but failed in Full Validate, so it is not acceptable ready evidence.` |

## Evidence Chain Report Evidence

| Field | Value |
|---|---|
| Report status | `pending` |
| failedCount | `pending` |
| blockedCount | `pending` |
| runId | `pending` |
| artifactCount | `pending` |
| producerCount | `pending` |
| normalizedCount | `pending` |
| missingRequiredCount | `pending` |
| reportTypeMismatchCount | `pending` |
| disallowedManualCount | `pending` |
| disallowedNotCapturedCount | `pending` |
| inputPolicyViolationCount | `pending` |
| manualCount | `pending` |
| notCapturedCount | `pending` |
| trueExecution | `false` |
| localPrivateIncluded | `false` |
| networkUsed | `false` |
| mutationUsed | `false` |

## Real Lifecycle Evidence

| Field | Value |
|---|---|
| Real build | `not-run` |
| Capture | `not-run` |
| Deploy | `not-run` |
| Admin/VM smoke | `not-provided` |
| Real WIM SHA256 | `not-captured` |
| DISM image info | `not-captured` |

## Manual Closure Readiness

| Field | Value |
|---|---|
| Current readiness | `pending-main-validation` |
| Required next evidence | `main/workflow validation` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

This document may be promoted only after real `main` or `workflow_dispatch` evidence exists. Do not fill these fields from pull request-only Fast CI, local fixture reports, or inferred success.

## Blocked Evidence Attempt

The post-PR #83 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28248115903` targeted `73861de486f3cf70c470548f1d446334f2f33481`, but `Full Validate` failed in the PowerShell 7 Pester step. The failing job was `https://github.com/phdiggit/win11-image-kit/actions/runs/28248115903/job/83692339314`. The run passed PowerShell 7 evidence chain validation, then failed `EvidenceChainRedaction.Tests.ps1` because `Copy-Item -LiteralPath` did not expand the sample report input wildcard. This failed run is recorded only as a blocker and is not used as ready evidence.

The post-PR #82 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28246816830` targeted `fb235d0a114c264decdbb46af08d1f29f38eca0d`, but `Full Validate` failed in the PowerShell 7 evidence chain validation step. The failing job was `https://github.com/phdiggit/win11-image-kit/actions/runs/28246816830/job/83687873647`. The failure was `Test-KitEvidenceRedaction` call depth overflow from `scripts/common/New-KitEvidenceChainReport.ps1`, and this failed run is recorded only as a blocker, not ready evidence.

The post-PR #81 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28245123952` targeted `6a60122ce17b6c3c3198a62f485bc48ffe677b5c`, but `Full Validate` failed in the PowerShell 7 evidence chain validation step. The failing job was `https://github.com/phdiggit/win11-image-kit/actions/runs/28245123952/job/83681950520`. This failed run is recorded only as a blocker and is not used as ready evidence.

## Related Documents

- [Issue #16 Evidence Chain Report](48-issue16-evidence-chain-report.md)
- [Issue #16 Evidence Chain Acceptance](49-issue16-evidence-chain-acceptance.md)
- [Issue #16 Close Preparation](50-issue16-close-preparation.md)
