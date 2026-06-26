# Issue #13 Ensure-State Acceptance

Status: `accepted-ready-for-manual-closure`

## Scope

- software manifest and schema
- services manifest and schema
- fixture/current-state resolver
- convergence plan generation
- result mapping
- ensure-state report generation
- validate entrypoint
- capability registry registration
- Build Lock trusted-input coverage
- PR Fast CI guardrails
- docs and README entry

## Non-goals

- Real software install/uninstall/upgrade
- Real service start/stop/config/delete
- Network package source query
- Package download
- Signing service
- Registry/profile/hive mutation
- Real Windows image build
- Main/workflow evidence backfill
- Real machine remediation

## Acceptance Matrix

| Area | Expected behavior | Evidence |
| --- | --- | --- |
| Software schema | `software.json` validates and uses ensure/source/scope/installMode enums | schema / Pester |
| Services schema | `services.json` validates and uses ensure/startupType/changeMode enums | schema / Pester |
| Resolver | uses fixture/current objects, not real installed package/service state | resolver / Pester |
| Plan | generates planned/manual/disabled actions without executing them | plan Pester |
| Result mapping | maps matched/drift/manual/unknown/missing to passed/manual/failed | validation Pester |
| Report | `ensure-state` keeps summary, results, plannedActions, whatIf | report Pester |
| CLI | `Test-EnsureState.ps1` writes explicit report path; failed exits 1; manual exits 0 | report/validation Pester |
| Registry | `ensure-state-convergence` capability is plan-only and registered | registry / Issue #13 Pester |
| Build Lock | Issue #13 manifest/schema/script/test/doc/CI are locked or watched | Build Lock / Pester |
| CI boundary | PR Fast CI uses static/fixture/report paths only | CI / Pester |

## Acceptance Decision

Issue #13 acceptance is complete for the plan/report-only Ensure-State layer. Main/workflow validation evidence is recorded in [Main Validation Evidence](39-issue13-main-validation-evidence.md) from the main push after PR #69 was merged.

This acceptance does not convert report-only Ensure-State into real machine remediation. PR Fast CI remains static/fixture/report-only and is not a substitute for main/workflow validation evidence.

## True Execution Split Rules

- This issue only produces desired-state ledger, plan, and report evidence.
- Real software install/uninstall/upgrade must be handled by a separate task or issue.
- Real service start/stop/disable/delete must be handled by a separate task or issue.
- Real execution must have admin/VM evidence, rollback plan, dry-run, allowlist, and explicit approval.
- PR Fast CI cannot prove real machine remediation.

## CI Boundary

PR Fast CI may validate static files, fixture states, plan generation, result mapping, report shape, explicit report output, and safety guardrails. It must not run real software install/uninstall/upgrade, real service mutation, network package lookup, package download, signing, registry/profile/hive mutation, Windows image build, Sysprep/AppX/DISM/Defender/Junction mutation, or real machine remediation.

## Related Documents

- [Ensure-State Runbook](36-issue13-ensure-state.md)
- [Close Preparation](38-issue13-close-preparation.md)
- [Main Validation Evidence](39-issue13-main-validation-evidence.md)
