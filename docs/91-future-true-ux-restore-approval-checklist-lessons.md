# Future True UX Restore Approval Checklist Lessons

Status: `approval-checklist-lessons`

## Lessons

- 可读性检查是执行前的人工安全栏，不是执行授权。
- 人工决定必须可追溯到 artifact id、head SHA、scope、证据边界和 rollback/restore 说明。
- `scope`、`evidence-boundary`、`rollback-or-restore-plan`、`privacy-redaction`、`execution-boundary` 是维护者最容易误判的区域，必须独立呈现。
- `approval-checklist-ready` 只表示清单可审，不等于 `authorization-review-ready`，更不等于真实 UX restore 成功。
- checklist-ready 不推进 Issue #18 自动关闭；后续真实执行仍需要单独授权、真实证据和明确 runner 边界。

## Anti-Drift

当 packet 出现执行态词汇、把 CI 或 report-only 输出写成真实证据、或者将人工清单当成批准执行时，默认结论应是 `blocked`。当章节齐全但措辞含糊时，默认结论应是 `needs-rework`。
