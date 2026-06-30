# Build Lock normalization and line-ending drift repair

Status: `build-lock-normalization`

Refs #19

## 结论

本记录对应 Task #121，目标是把前序多个已接受 PR 遗留的 Build Lock drift 集中归一化，而不是在功能 PR 里顺手吸收无关 hash churn。

本 PR 不改变功能行为，不改变 `.github/workflows/ci.yml`，不改变 Future True UX 质量门 ID、trigger、layer、required、blocking 或 report-only 语义，不改变报告 schema，不执行真实 UX restore，也不做注册表、DISM、Sysprep、WinPE、AppX、Defender、service、Junction、镜像、VM 或软件安装/下载操作。

## 基线盘点

基线命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate\Test-BuildLock.ps1 -ReportPath .tmp\build-lock-121-before.json
```

基线结果：

| 字段 | 数值 |
|---|---:|
| `total` | `611` |
| `passedCount` | `492` |
| `manualCount` | `1` |
| `failedCount` | `118` |
| `missingCount` | `0` |
| `mismatchCount` | `118` |
| `untrackedWatchedCount` | `1` |

唯一 manual 项是 `manifests/build-lock.json`。它被 `manifests/*.json` watch glob 命中，但不写入 `entries`，以避免 Build Lock 自身 hash 的自引用循环。

## Drift 分类

| 分组 | 数量 | 示例 | 判断 | 决策 |
|---|---:|---|---|---|
| line-ending-only drift | `85` | `README.md`, `manifests/capability-registry.json`, `tests/pester/Issue12BuildLock.Tests.ps1` | LF 规范化后的当前内容 hash 与旧 Build Lock hash 相同；当前 Windows checkout 为 CRLF 字节 | 更新为当前 Windows 验证基准 hash，不批量重写文件 |
| accepted content drift | `33` | `scripts/validate/Test-FutureTrueUxRestoreAuthorization.ps1`, `docs/README.md`, `docs/archive/future-true-ux-restore/00-governance/112-future-true-ux-validator-script-governance.md` | 前序已接受 PR 对内容做过真实修改，Build Lock 未在对应 PR 中吸收无关 drift | 更新 hash，治理记录解释来源 |
| completed-roadmap docs | `7` | `docs/archive/completed-roadmap/issue-14/42-issue14-close-preparation.md` | 已归档完成态证据文档的 hash stale 或 EOL drift | 更新 hash |
| Future True UX governance docs | `4` | `docs/archive/future-true-ux-restore/00-governance/111-future-true-ux-archive-dry-run-plan.md` | 文档迁移和治理 PR 后的 hash stale 或 EOL drift | 更新 hash |
| README/docs index | `3` | `README.md`, `docs/README.md` | 当前入口文档或 docs index 的 EOL/content drift | 更新 hash |
| manifests | `3` | `manifests/capability-registry.json`, `manifests/quality-gates.json`, `manifests/future-true-ux-restore-authorization.json` | 受前序治理 PR 或 EOL drift 影响 | 更新 hash，不改 schema/语义 |
| scripts | `29` | `scripts/common/New-FutureTrueUxRestoreMockReviewDrillReport.ps1` | Future True UX report-only helper 与 validator/presentation helper 的 accepted content drift | 更新 hash，不改脚本行为 |
| Pester tests | `72` | `tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1` | Issue 12-18 与 Future True UX 治理测试在前序 PR 后 hash stale 或 EOL drift | 更新 hash |
| controlled-execution fixtures | `5` | `tests/fixtures/controlled-execution/failure/registry-mutation-action.json` | fixture EOL drift | 更新 hash |

## 行尾和编码决策

仓库当前没有 `.gitattributes`，本地和当前 runner 基准为 Windows checkout，`core.autocrlf=true`，样例文件显示为 `i/lf w/crlf`。

本 PR 不新增 `.gitattributes`，原因是允许模式会影响大量现有文本文件，容易把本次专门的 Build Lock normalization 变成全仓行尾重签。Task #121 的修复范围改为：

- 记录 85 个 line-ending-only drift；
- 将 Build Lock hash 更新到当前 Windows 验证基准；
- 不做 mass-convert；
- 后续若要引入 `.gitattributes`，应作为单独 PR 先盘点 checkout 行为和 CI hash 基准。

## `manifests/build-lock.json` 自身策略

决策：继续将 `manifests/build-lock.json` 保持为 manual by policy。

原因：

- 它被 `manifests/*.json` 监控；
- 把自身加入 `entries` 会产生自引用 hash 循环；
- 当前 validator 将 watched-but-not-entry 按 `policy.untrackedWatchedFile=manual` 报告；
- 该 manual 项需要在报告、文档和 Pester 测试里显式接受。

目标归一化后状态：

| 字段 | 期望 |
|---|---:|
| `failedCount` | `0` |
| `mismatchCount` | `0` |
| `missingCount` | `0` |
| `manualCount` | `1` |
| `untrackedWatchedFiles` | `manifests/build-lock.json` |

## Future guardrails

Task #121 used a temporary selected-path Build Lock hash refresh helper during the dedicated normalization pass. The helper was a one-time normalization tool and must not remain resident after the final script-governance stop-line. Future Build Lock updates should be made narrowly inside the task that changes the locked file, or handled by a new dedicated normalization task with an explicit audit record.

新增 `tests/pester/BuildLockNormalization.Tests.ps1`，覆盖：

- 本治理记录存在并使用 `Refs #19`；
- Build Lock 归一化后没有 failed mismatch；
- `manifests/build-lock.json` self-watch manual 策略被文档化和测试；
- Future True UX 质量门语义保持不变；
- `.github/workflows/ci.yml` hash 固定为当前基线；
- 未新增 `.gitattributes` broad policy；
- the one-time helper does not remain resident after the final script-governance audit.

## No true execution

本任务保持以下语义冻结：

| 字段 | 值 |
|---|---|
| `authorizationApproved` | `false` |
| `executionApproved` | `false` |
| `executeReady` | `false` |
| `trueExecution` | `false` |
| `mutationCount` | `0` |

本 PR 只更新文档、测试、开发辅助脚本和 Build Lock metadata，不执行真实系统变更。
