# Issue #12 Immutable Build Lock

Build Lock 是一个只读的供应链输入台账，用来说明哪些 repo 文件属于构建或验证可信输入，并用 SHA256 发现漂移。它不下载文件、不调用签名服务、不构建镜像、不自动信任变更，也不执行任何系统变更。

## 解决的问题

- trusted inputs ledger：`manifests/build-lock.json` 列出被锁定的 manifest、schema、脚本、测试和关键 runbook。
- hash drift detection：验证入口重新计算每个 entry 的 SHA256，并把 mismatch 标为 failed 或 manual。
- watched but untracked file warning：`watchGlobs` 命中的关键文件如果未列入 entries，会进入 report 的 manual/warning，而不是被静默忽略。
- report evidence：`scripts/validate/Test-BuildLock.ps1` 可以写出结构化 JSON report，供 CI 和人工审阅。

## 字段

- `lockVersion`：lock 文件格式版本。
- `algorithm`：当前只允许 `SHA256`。
- `mode`：`verify` 用于正常校验，`audit` 用于审阅态。
- `entries`：锁定文件列表，包含路径、类别、是否必需、实际 SHA256 和锁定原因。
- `watchGlobs`：需要观察但不一定全部锁定的文件模式。
- `policy`：定义缺失文件、hash mismatch、未列入 entries 的 watched 文件和不支持算法的处理方式。

## 运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate/Test-BuildLock.ps1 -ReportPath reports/build-lock.json
```

`failed` 会让入口返回非零退出码；`manual` 会返回 0，但 report 会保留人工审阅状态。

## Report Status

- `passed`：所有锁定输入匹配，且没有需要人工审阅的 watched 文件。
- `manual`：没有阻断失败，但存在需要人工确认的缺失、漂移或 watched 文件。
- `failed`：存在阻断失败，例如必需文件缺失、hash mismatch 或不支持的算法。

## 何时更新 Lock

只有当 manifest、schema、脚本、测试或关键文档被有意修改时，才应显式更新对应 entry 的 SHA256，并在 PR body 说明原因。验证脚本不会为了掩盖当前工作树变化而自动改写 lock。

## PR Fast CI 边界

- no network
- no system mutation
- no real build
- no signing
- no automatic trust

Build Lock 的 PR Fast CI 只允许静态、fixture 和 report 路径；不能下载 ISO、driver、package 或 binary，不能执行 Sysprep/AppX/DISM/Defender/Junction 变更。

## 与 Capability Registry 的关系

Build Lock 自身作为 `immutable-build-lock` capability 登记在 `manifests/capability-registry.json` 中。Capability registry 记录能力边界和入口文件；Build Lock 反过来锁定 registry、schema、相关 validator 和关键 runbook，使两者在静态/report 层互相校验。
