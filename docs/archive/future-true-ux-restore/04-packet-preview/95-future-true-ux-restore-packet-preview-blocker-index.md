# Future True UX Restore Packet Preview Blocker Index

Status: `integrated-packet-preview-blocker-index`

Integrated packet preview 至少要索引以下 blocker：

- scope mismatch：request、packet、scope guard 之间作用域不一致。
- private path：出现真实用户目录、NAS 私有路径、账号名或机器身份。
- evidence promotion：把 CI、dry-run、handler report、manual checklist、mock packet、negative drill 或 approval checklist 写成真实 UX 证据。
- approval wording drift：把 preview 写成 `authorization-review-ready`。
- execution wording drift：出现 `execute-ready`、`executed` 或 `completed`。
- rollback missing：rollback / restore 说明为空、TBD 或不可操作。
- runner gate missing：没有说明当前仅复用 report-only runner。

这些 blocker 是 preview 的阅读索引，不是执行结果。出现 blocker 时，preview 只能是 `needs-rework` 或 `blocked`。
