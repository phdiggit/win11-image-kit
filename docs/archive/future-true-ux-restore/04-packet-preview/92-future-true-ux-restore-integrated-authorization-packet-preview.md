# Future True UX Restore Integrated Authorization Packet Preview

Status: `integrated-packet-preview`

Integrated packet preview 汇总 Future True UX Restore 的前置 review / preview / authorization-prep 信息，给维护者一个可读的单页入口。它只说明 packet preview 结构完整，可以进入人工阅读，不表示授权、执行或 Issue #18 closure。

## Boundary

`packet-preview-ready` 只表示预览结构完整、字段可读、风险入口清楚。它不是 `authorization-review-ready`，也不是 `execute-ready`。preview report 不是 true UX restore evidence，不证明用户体验已经恢复成功。

本层固定保持：

- `authorizationApproved=false`
- `executionApproved=false`
- `executeReady=false`
- `trueExecution=false`
- `mutationCount=0`

## Required Sections

- `scope`
- `target-identity-redaction`
- `evidence-boundary`
- `approval-checklist-summary`
- `negative-blocker-summary`
- `rollback-or-restore-plan`
- `execution-boundary`
- `runner-gate-reminder`

如果任何章节缺失、含糊、泄露私有路径，或把 CI / dry-run / mock / report-only / checklist 输出写成真实 UX 证据，预览必须进入 `needs-rework` 或 `blocked`。
