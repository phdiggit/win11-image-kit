# Future True UX Restore Packet Preview Field Map

Status: `integrated-packet-preview-field-map`

本字段映射用于说明 preview 如何引用前置层，但不把前置层输出升级为真实证据。

| Preview field | Source layer | Review use | Boundary |
|---|---|---|---|
| `scope` | authorization intake / scope guard | 判断是否单一作用域 | 不能替代授权 |
| `target-identity-redaction` | review packet / approval checklist | 检查身份脱敏 | 不能包含真实用户路径或私有 share |
| `evidence-boundary` | dry-run / mock / report-only reports | 说明证据仍是候选材料 | 不是 true UX restore evidence |
| `approval-checklist-summary` | approval checklist ergonomics | 摘要可读性和人工表完整度 | 不是 authorization-ready |
| `negative-blocker-summary` | negative review drill | 列出阻断条件 | 不是真实执行失败或成功 |
| `rollback-or-restore-plan` | review packet / checklist | 让维护者看到回退说明 | 不是执行许可 |
| `execution-boundary` | execute gate docs | 固定 no execution 语义 | 不能写成 execute-ready |
| `runner-gate-reminder` | task card / PR runner policy | 提醒当前仅复用 report-only runner | 不是扩展 runner 授权 |

字段映射只服务阅读顺序和一致性检查。它不得引入安装、下载、系统写入或 workflow 改动。
