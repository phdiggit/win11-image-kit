# Future True UX Restore Manual Decision Form Template

Status: `approval-checklist-form-template`

此模板只用于维护者人工阅读和记录，不是执行授权表。

## Decision Form

- Reviewed artifact id: `<artifact-id>`
- Reviewed head SHA: `<head-sha>`
- Scope: `current-user | default-user | offline-image | machine`
- Target identity redaction: `<redacted-target>`
- Evidence boundary: `Dry-run, mock, and report-only material only; not real UX evidence and not approval.`
- Rollback / restore notes: `<actionable notes>`
- Reviewer decision: `approval-checklist-ready | needs-rework | blocked`
- Reviewer notes: `<notes>`
- Explicit non-execution statement: `This checklist does not approve authorization, execution, true UX restore, install, download, registry/Profile/AppX/StartLayout/Defender/Junction/Service/Sysprep/DISM mutation, or Issue #18 closure.`

## Review Rules

若 reviewed artifact id、head SHA、scope、证据边界、rollback、隐私脱敏或 non-execution statement 任一项缺失，维护者应选择 `needs-rework` 或 `blocked`，而不是补写执行授权。
