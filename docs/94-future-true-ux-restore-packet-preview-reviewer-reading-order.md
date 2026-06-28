# Future True UX Restore Packet Preview Reviewer Reading Order

Status: `integrated-packet-preview-reading-order`

维护者阅读 integrated packet preview 时，按以下顺序能最快发现风险漂移：

1. `scope`：确认只有一个作用域，且 request / packet / scope guard 一致。
2. `target-identity-redaction`：确认用户、机器和私有路径已经脱敏。
3. `evidence-boundary`：确认 CI、dry-run、mock、report-only、manual checklist 都没有被写成真实 UX 证据。
4. `approval-checklist-summary`：确认 `packet-preview-ready` 没有被混写成 `authorization-review-ready`。
5. `negative-blocker-summary`：确认 known blockers 已经可见。
6. `rollback-or-restore-plan`：确认说明足够具体，能支持后续人工授权讨论。
7. `execution-boundary`：确认没有 execution state、系统写入或 true restore 声明。
8. `runner-gate-reminder`：确认本阶段只复用当前 report-only runner；扩大 runner 或 workflow 范围必须另行确认。

读完后只能给出 `packet-preview-ready`、`needs-rework` 或 `blocked`。
