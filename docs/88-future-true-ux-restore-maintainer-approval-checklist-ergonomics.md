# Future True UX Restore Maintainer Approval Checklist Ergonomics

Status: `approval-checklist-ergonomics`

本文定义 future true UX restore 的维护者人工审批清单可读性层。它只帮助维护者读懂 packet，不代表授权通过，也不代表可以执行真实恢复。

## 目标

- 让维护者能快速判断 packet 是否完整、作用域是否单一、证据边界是否清楚。
- 把人工清单和执行授权分开：`approval-checklist-ready` 只说明清单可读、可审，不等于 `authorization-review-ready`。
- 明确 dry-run、mock、report-only、CI 结果都不是 real UX evidence。
- 在任何后续授权讨论前，先暴露 rollback、privacy redaction、execution boundary 的缺口。

## 清单边界

本层只输出 `approval-checklist-ready`、`needs-rework` 或 `blocked`。它不得输出 execution state，不得把维护者清单写成“已批准执行”，也不得推进 Issue #18 自动关闭。

报告字段固定保持：

- `authorizationApproved=false`
- `executionApproved=false`
- `executeReady=false`
- `trueExecution=false`
- `mutationCount=0`

## 必要章节

- `scope`
- `target-identity-redaction`
- `evidence-boundary`
- `rollback-or-restore-plan`
- `privacy-redaction`
- `reviewer-decision`
- `execution-boundary`

任何章节缺失、措辞含糊、或把 CI/dry-run/mock/report-only 结果当成真实 UX 证据，都应进入 `needs-rework` 或 `blocked`。
