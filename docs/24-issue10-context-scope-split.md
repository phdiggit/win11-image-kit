# Issue #10 context scope split

Issue #10 separates Windows customization into three execution contexts so a
build or deployment plan can block unsafe routing before it becomes a registry,
hive, or profile write.

## Contexts

- `machine`: machine, image, and system-wide settings such as HKLM, services,
  capabilities, ProgramData, Windows, Program Files, and machine-wide tasks.
- `default-user`: Default User template settings such as the default profile,
  the Default User registry hive, and new-user Start or Explorer templates.
- `current-user`: only the currently logged-in user session, such as HKCU,
  `%USERPROFILE%`, `%APPDATA%`, `%LOCALAPPDATA%`, and taskbar or Explorer
  preferences for that user.

## Common mistakes

- Writing HKCU during image build and treating it as a machine default.
- Treating the Default User hive as if it were the current user.
- Treating the current logged-in profile as the image default profile.
- Writing machine-level files or registry state into a user profile path.
- Accepting ambiguous or unknown context as success.

## Running the guardrail

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-ContextScope.ps1 -WhatIf -ReportPath reports/context-scope-plan.json
```

The command only creates a plan/report. PR Fast CI must stay on plan, mock, or
WhatIf paths. It must not load a real Default User hive, unload a real hive,
write HKCU/HKLM, or mutate a real user profile.

## Handler adoption rule

New or updated handlers should declare or map each configurable target to a
context before mutation. Missing context should produce a warning/manual or
blocked plan item, not an implicit machine success. `current-user` operations
must be explicit opt-in and must not become build/image defaults.
