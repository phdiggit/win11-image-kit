# Issue #14 Quality Gates Acceptance

Status: `accepted-ready-for-manual-closure`

## Scope

- quality gate manifest and schema
- report-only quality gate runner
- structured quality-gates report
- PR Fast CI wiring for the runner and guardrail tests
- Pester coverage for schema, report, validation, acceptance, CI, and Build Lock
- Build Lock trusted-input coverage
- README and docs links

## Acceptance Matrix

| Area | Expected behavior | Evidence |
| --- | --- | --- |
| Manifest/schema | `quality-gates.json` parses and schema has closed objects, required fields, and enums | `QualityGateSchema.Tests.ps1` |
| Runner | `Test-QualityGates.ps1` reads the manifest and writes explicit reports | `QualityGateValidation.Tests.ps1` |
| Report contract | report keeps `reportType`, `status`, `summary`, `gates`, and `safety` | `QualityGateReport.Tests.ps1` |
| Manual signal | `manual / failedCount=0` exits 0 | `QualityGateValidation.Tests.ps1` |
| Failed gate | failed gate can mark report failed and exit 1 | `QualityGateValidation.Tests.ps1` |
| CI boundary | PR Fast CI runs the runner and QualityGate Pester without real mutation | workflow / Pester |
| Build Lock | new manifest/schema/scripts/docs/tests are locked or watched | Build Lock / Pester |
| Close prep | closure preparation is ready after main evidence is recorded | `Issue14ClosePrep.Tests.ps1` |
| Main evidence | main/workflow validation evidence is recorded in docs/43 | `Issue14MainValidationEvidence.Tests.ps1` |

## Acceptance Hardening Status

This acceptance document is accepted and ready for manual closure. Issue #14 has local schema, Pester, analyzer policy, CI wiring, quality-gates runner/report, Build Lock guardrails, and main/workflow validation evidence.

[Main Validation Evidence](43-issue14-main-validation-evidence.md) records verified `main` push Full Validate success. [Close Preparation](42-issue14-close-preparation.md) is also `ready-for-manual-closure`.

## Evidence Chain

- manifests/quality-gates.json
- schemas/quality-gates.schema.json
- scripts/common/New-KitQualityGateReport.ps1
- scripts/validate/Test-QualityGates.ps1
- docs/archive/completed-roadmap/issue-14/40-issue14-quality-gates.md
- docs/archive/completed-roadmap/issue-14/41-issue14-quality-gates-acceptance.md
- docs/archive/completed-roadmap/issue-14/42-issue14-close-preparation.md
- docs/archive/completed-roadmap/issue-14/43-issue14-main-validation-evidence.md
- tests/pester/QualityGateSchema.Tests.ps1
- tests/pester/QualityGateReport.Tests.ps1
- tests/pester/QualityGateValidation.Tests.ps1
- tests/pester/Issue14QualityGateAcceptance.Tests.ps1
- tests/pester/Issue14ClosePrep.Tests.ps1
- tests/pester/Issue14MainValidationEvidence.Tests.ps1

## Runner / Report Contract

The runner is static and report-only. It checks local manifest, workflow, docs, tests, and Build Lock wiring. It does not execute true build, package installation, service changes, network downloads, signing, registry/profile/hive writes, or admin/VM smoke.

The report status may be `passed`, `manual`, or `failed`. Manual review signals are acceptable when `failedCount=0`; failed gates must be visible and block through exit code 1.

## CI Boundary

PR Fast CI may run `Test-QualityGates.ps1` and Pester guardrails. Full Validate remains non-PR only. PR Fast CI is not main/workflow evidence.

## PSScriptAnalyzer Boundary

PSScriptAnalyzer remains governed by `PSScriptAnalyzerSettings.psd1`. Missing analyzer modules and diagnostics remain warning/manual under current policy. This scaffold does not add online module installation.

## Build Lock Boundary

Build Lock covers Issue #14 manifest/schema/scripts/docs/tests and changed workflow/README inputs. `manual / failedCount=0` remains a review signal, not a failed validation.

## Close Preparation Boundary

[Close Preparation](42-issue14-close-preparation.md) is ready for manual closure. It still preserves manual issue handling and true-execution boundaries.

## Main Evidence Boundary

[Main Validation Evidence](43-issue14-main-validation-evidence.md) records `main` push Full Validate success. Pull request-only Fast CI is not a substitute for main push or `workflow_dispatch` Full Validate evidence.

## Non-goals

- real Windows image build
- real software install/uninstall/upgrade
- real service mutation
- network package lookup or download
- signing service
- registry/profile/hive writes
- admin/VM smoke evidence
- automatic Issue #14 closure

## Remaining Work

- Manual closure remains a maintainer action.
- Keep true execution split into separate task/issue scope.

## Related Documents

- [Quality Gates](40-issue14-quality-gates.md)
- [Close Preparation](42-issue14-close-preparation.md)
- [Main Validation Evidence](43-issue14-main-validation-evidence.md)
- [Build Lock](32-issue12-build-lock.md)
