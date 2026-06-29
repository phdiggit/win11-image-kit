# Future True UX Restore Review Packet Readability Guide

Status: `approval-checklist-readability-guide`

维护者阅读 packet 时，第一屏应能看清：作用域、目标身份脱敏、证据边界、rollback/restore 计划、隐私脱敏、人工决定和执行边界。

## 作用域

作用域必须只出现一个主标签：`current-user`、`default-user`、`offline-image` 或 `machine`。如果 request、packet、scope guard 的标签不一致，清单不能进入 `approval-checklist-ready`。

## 证据边界

推荐固定短句：

> Evidence is dry-run, mock, and report-only material. It is not real UX evidence and is not approval.

不要把 CI 通过、dry-run 输出、handler report、manual checklist 或 mock packet 写成真实 UX 恢复已经成功。

## Rollback / Restore

rollback/restore 说明必须可执行到人工审查层面：指出原始模板或导出物、需要保留的报告、谁负责后续授权后的恢复验证，以及失败时如何回退。只有“恢复即可”“稍后处理”这类空泛文字，应标记为 `needs-rework`。

## 隐私脱敏

维护者 packet 中不得出现真实用户目录、NAS 私有路径、账号名或机器身份。用 `<redacted-current-user>`、`<redacted-host>`、`<redacted-share>` 等占位符。

## 决定文字

人工决定只能是：

- `approval-checklist-ready`
- `needs-rework`
- `blocked`

禁止把清单决定写成 `authorization-review-ready`、`execute-ready`、`executed` 或 `completed`。这些词属于后续状态机或执行状态，不属于本层。
