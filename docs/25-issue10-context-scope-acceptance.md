# Issue #10 Context Scope Acceptance

Status: in-acceptance

This acceptance matrix covers the guardrails added for the
machine/default-user/current-user split. It is a PR-safe evidence layer and does
not perform real registry, hive, or profile mutation.

## Scope

- `context-scope.json` manifest and schema.
- `machine`, `default-user`, and `current-user` routing.
- `phasePolicy` validation.
- Registry root and profile path context inference.
- Ambiguous and unknown context blocking.
- Context safety validation.
- Context-scope plan and report output.
- `Test-ContextScope.ps1` explicit report path.
- PR Fast CI guardrails.

## Non-goals

- Real registry mutation.
- Real HKCU or HKLM writes.
- Real Default User hive load or unload.
- Real profile mutation.
- Full migration of every existing handler.
- Interactive current-user mutation during PR Fast CI.

## Acceptance Matrix

| Area | Expected behavior | Evidence |
| --- | --- | --- |
| Manifest/schema | `context-scope.json` validates and rejects unknown fields | schema / Pester |
| Context enum | Only `machine`, `default-user`, and `current-user` are accepted | schema / Pester |
| Phase policy | `build`, `postdeploy`, `interactive`, and `validate` restrict allowed contexts | resolver / Pester |
| Registry root | `HKLM` maps to `machine`, `HKCU` maps to `current-user`, and `HKU_DEFAULT` maps to `default-user` | resolver / Pester |
| Profile path | Default profile paths map to `default-user`; current profile paths map to `current-user` | resolver / Pester |
| Machine path | `ProgramData`, `Windows`, and `Program Files` paths map to `machine` | resolver / Pester |
| Ambiguous hints | Conflicting hints become blocked, not allowed | resolver / safety Pester |
| Unknown context | Unknown root, path, or context cannot pass | resolver / safety Pester |
| Current-user build | `current-user` in build phase is blocked or manual | safety Pester |
| Default-user marker | `default-user` requires a Default User hive or profile marker | safety Pester |
| Report | `context-scope-plan` keeps summary and all items | report Pester |
| CLI | `Test-ContextScope.ps1` writes only an explicit report path | report / acceptance Pester |
| CI boundary | PR Fast CI uses plan, mock, and WhatIf paths only | CI / Pester |

## Handler Adoption Checklist

- New or updated handlers must declare a context or provide an explicit mapping rule.
- Configuration items without context must not default to a successful `machine` result.
- `current-user` work must be opt-in.
- `default-user` work must have a Default User hive or profile marker.
- `machine` work must not write HKCU or current profile paths.

## Evidence Links

- [Issue #10 context scope split](24-issue10-context-scope-split.md)
- [Issue #10 close preparation](26-issue10-close-preparation.md)
- [Issue #10 main validation evidence](27-issue10-main-validation-evidence.md)
