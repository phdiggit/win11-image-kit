# Issue #12 Build Lock Acceptance

Status: `in-acceptance`

## Scope

- build-lock manifest and schema
- SHA256 file hash helper
- build-lock loader
- build-lock validator
- build-lock report
- validate entrypoint
- capability registry registration
- watched-but-untracked warning/manual behavior
- PR Fast CI guardrails
- docs and README entry

## Non-goals

- Real Windows image build
- Network download or package retrieval
- Signing service integration
- Sysprep/AppX/DISM/Defender/Junction execution
- Registry/profile/hive mutation
- Full repository lock coverage
- Main/workflow evidence backfill

## Acceptance Matrix

| Area | Expected behavior | Evidence |
| --- | --- | --- |
| Manifest/schema | `build-lock.json` validates against schema | schema / Pester |
| Closed schema | no unknown top-level, entry, or policy fields | schema / Pester |
| Algorithm | only `SHA256` is accepted | schema / validator Pester |
| Entry contract | path/category/required/hash/reason required | schema / Pester |
| Hash helper | stable lowercase SHA256; missing files stable; directories rejected | hash Pester |
| Loader | reads lock, parses JSON, rejects duplicate entry paths | loader / Pester |
| Validator | detects missing required, hash mismatch, unsupported algorithm | validation Pester |
| Watched files | watched but unlisted files are surfaced as manual/warning | validation / report Pester |
| Report | `build-lock` keeps summary, entries, untrackedWatchedFiles, whatIf | report Pester |
| CLI | `Test-BuildLock.ps1` writes explicit report path only; failed exits 1; manual exits 0 | report Pester |
| Registry | `immutable-build-lock` capability is audit-only and registered | registry / Issue #12 Pester |
| CI boundary | PR Fast CI uses static/fixture/report paths only | CI / Pester |

## Build Lock Update Checklist

- Update hashes only for intentional manifest/schema/script/test/doc changes.
- Explain each hash update reason in the PR body.
- Do not downgrade hash mismatch to passed silently.
- Keep watched-but-untracked files visible in the report.
- Treat the lock as audit/report evidence only; it does not authorize real build, network access, signing, or system mutation.
- Treat a PR Fast CI manual report as review input only, not as main/workflow evidence.

## CI Boundary

PR Fast CI may run schema checks, hash fixtures, duplicate-path fixtures, report serialization, explicit report-path checks, and documentation guardrails. It must not run a real image build, network transfer, signing service, business handler, registry/profile/hive write, Sysprep/AppX/DISM/Defender/Junction change, or package download.

## Related Documents

- [Build Lock Runbook](32-issue12-build-lock.md)
- [Issue #12 Close Preparation](34-issue12-close-preparation.md)
- [Issue #12 Main Validation Evidence](35-issue12-main-validation-evidence.md)

Docs index: docs/32, docs/33, docs/34, docs/35.
