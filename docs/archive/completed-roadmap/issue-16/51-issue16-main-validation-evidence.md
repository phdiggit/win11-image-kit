# Issue #16 Main Validation Evidence

Status: `ready-for-manual-closure`

## Evidence Sources

- main push Windows CI / Full Validate after close-prep PR is merged
- workflow_dispatch Windows CI / Full Validate targeting `main`
- maintainer-provided manual lifecycle evidence only if explicitly performed

Pull request-only Fast CI is not a substitute.

## Current Evidence

| Field | Value |
|---|---|
| Trigger source | `main push` |
| Main SHA | `48c13ac5a66cdcb733363546af03f98cb85ac50a` |
| Workflow run | `https://github.com/phdiggit/win11-image-kit/actions/runs/28250101014` |
| Full Validate job | `https://github.com/phdiggit/win11-image-kit/actions/runs/28250101014/job/83699160541` |
| Result | `success` |
| Notes | `Post-PR #84 main push Full Validate completed successfully. The checkout log fetched 48c13ac5a66cdcb733363546af03f98cb85ac50a and printed the same checkout SHA; local git log -1 on the same SHA confirms 48c13ac5a66cdcb733363546af03f98cb85ac50a.` |

## Evidence Chain Report Evidence

| Field | Value |
|---|---|
| Report status | `manual` |
| failedCount | `0` |
| blockedCount | `0` |
| runId | `kit-run-20260626T161726Z-0000000` |
| artifactCount | `4` |
| producerCount | `9` |
| normalizedCount | `5` |
| missingRequiredCount | `0` |
| reportTypeMismatchCount | `0` |
| disallowedManualCount | `0` |
| disallowedNotCapturedCount | `0` |
| inputPolicyViolationCount | `0` |
| manualCount | `1` |
| notCapturedCount | `3` |
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
| Current readiness | `ready-for-manual-closure` |
| Required next evidence | `maintainer manual review` |
| PR Fast CI substitute allowed | `false` |

## Ready-State Rules

This document is promoted because real `main` push Full Validate evidence exists and was verified against the checkout SHA. Pull request-only Fast CI is still not a substitute, and same-SHA local report evidence is recorded only for report counters, not as a GitHub artifact.

## Same-SHA Local Report Evidence

The Evidence Chain Report Evidence table uses `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-EvidenceChain.ps1 -ReportPath "$env:TEMP\evidence-chain-issue16-post84.json"` run locally at the same main SHA, after verifying the post-PR #84 Full Validate job completed successfully. This is same-SHA local report evidence, not a GitHub artifact.

## Blocked Evidence Attempt

The post-PR #83 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28248115903` targeted `73861de486f3cf70c470548f1d446334f2f33481`, but `Full Validate` failed in the PowerShell 7 Pester step. The failing job was `https://github.com/phdiggit/win11-image-kit/actions/runs/28248115903/job/83692339314`. The run passed PowerShell 7 evidence chain validation, then failed `EvidenceChainRedaction.Tests.ps1` because `Copy-Item -LiteralPath` did not expand the sample report input wildcard. This failed run is recorded only as a blocker and is not used as ready evidence.

The post-PR #82 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28246816830` targeted `fb235d0a114c264decdbb46af08d1f29f38eca0d`, but `Full Validate` failed in the PowerShell 7 evidence chain validation step. The failing job was `https://github.com/phdiggit/win11-image-kit/actions/runs/28246816830/job/83687873647`. The failure was `Test-KitEvidenceRedaction` call depth overflow from `scripts/common/New-KitEvidenceChainReport.ps1`, and this failed run is recorded only as a blocker, not ready evidence.

The post-PR #81 `main` push run at `https://github.com/phdiggit/win11-image-kit/actions/runs/28245123952` targeted `6a60122ce17b6c3c3198a62f485bc48ffe677b5c`, but `Full Validate` failed in the PowerShell 7 evidence chain validation step. The failing job was `https://github.com/phdiggit/win11-image-kit/actions/runs/28245123952/job/83681950520`. This failed run is recorded only as a blocker and is not used as ready evidence.

## Related Documents

- [Issue #16 Evidence Chain Report](48-issue16-evidence-chain-report.md)
- [Issue #16 Evidence Chain Acceptance](49-issue16-evidence-chain-acceptance.md)
- [Issue #16 Close Preparation](50-issue16-close-preparation.md)
