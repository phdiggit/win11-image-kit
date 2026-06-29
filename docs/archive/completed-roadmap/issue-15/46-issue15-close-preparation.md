# Issue #15 Close Preparation

Status: `ready-for-manual-closure`

## Final Scope Candidate

Issue #15 scope is the layered configuration mechanism for profile, local path, hardware, and explicit CLI overrides. The current candidate includes:

- Layer manifest: `manifests/config-layers.json`
- Compatibility path: `manifests/paths.json` remains the default `pathsManifest`
- Local private override: `manifests/paths.local.json`, ignored and untracked
- Safe local example: `manifests/paths.local.example.json`
- Profile fixtures: `profiles/default.json`, `profiles/release.json`
- Hardware fixture: `hardware/air15.json`
- Effective configuration resolver, display entrypoint, validator, reports, and Pester guardrails
- Opt-in consumer integration through `Show-CustomizationScope.ps1 -UseEffectiveConfiguration`

This is ready for maintainer manual closure because `docs/archive/completed-roadmap/issue-15/47-issue15-main-validation-evidence.md` records post-PR #77 main push Full Validate success. It is still not an automatic Issue #15 closure.

## Evidence Chain

- `docs/archive/completed-roadmap/issue-15/44-issue15-layered-configuration.md` records the design, safety boundaries, and migration-compatible consumer integration.
- `docs/archive/completed-roadmap/issue-15/45-issue15-layered-configuration-acceptance.md` records functional acceptance and ready manual-closure status.
- `docs/archive/completed-roadmap/issue-15/47-issue15-main-validation-evidence.md` records the post-PR #77 main push Full Validate evidence.
- PR Fast CI validates static configuration, effective configuration, and fixture tests for the PR branch.

PR Fast CI is not main/workflow evidence. The recorded evidence source is the `main` push Windows CI run after PR #77 merged.

## Validation Policy

- Validators and tests are static, fixture, report-only, or manual.
- `paths.local.json` must not enter Git or Build Lock required entries.
- `paths.local.example.json` must stay free of private NAS, account, token, password, API key, or machine-specific secret values.
- Quality Gates must not introduce `true-execution`.
- Real build, install, service mutation, network download, registry/profile/hive writes, DISM, Sysprep, AppX, Defender, and Junction mutation are out of scope.

## Manual Closure Checklist

| Item | Status |
| --- | --- |
| Functional acceptance documented | `complete` |
| Consumer integration documented | `complete` |
| Close-prep candidate created | `complete` |
| Main/workflow validation evidence | `complete` |
| PR Fast CI used as main evidence | `false` |
| Completion summary created | `false` |
| Issue auto-close wording used | `false` |

## Optional Manual Validation Evidence

Real VM/admin smoke is optional and not required for this scaffold. If it is performed later, record the operator, environment, date, exact scope, and result in the main evidence document. Do not invent or infer manual smoke evidence.

## Closure Note Draft

Issue #15 has a layered configuration baseline, acceptance hardening, opt-in consumer integration, close-prep documentation, and post-PR #77 main push Full Validate evidence. Maintainer manual closure may proceed after review.

Do not use auto-close keywords in PR bodies or commits for this staged work.

## Related Documents

- [Issue #15 Layered Configuration](44-issue15-layered-configuration.md)
- [Issue #15 Acceptance](45-issue15-layered-configuration-acceptance.md)
- [Issue #15 Main Validation Evidence](47-issue15-main-validation-evidence.md)
