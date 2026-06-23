# Codex 工作流

本文承载根 `AGENTS.md` 不宜展开的详细流程。普通任务先读根规则；只有涉及基线同步、分级验证、失败处理、提交或 PR 时，才按需读取本文对应章节。

## 文档定位

- 根 `AGENTS.md` 保存稳定原则、安全边界和最小读取路由。
- 本文保存详细命令、验证矩阵、失败分类、重跑策略、PR body 清单和最终报告字段。
- `docs/codex-task-card-template.md` 保存可复用任务卡模板。

## 本地任务生命周期

1. 读取根 `AGENTS.md` 与当前 Issue/任务卡。
2. 确认任务定位、禁止范围、预期 changed files 和验收标准。
3. 同步默认分支并从干净工作区创建任务分支。
4. 按任务路由读取最小文件集。
5. 盘点现有规则、调用方、行为和已有模板。
6. 实施最小改动，不顺手扩大范围。
7. 先运行定向验证，再运行适用的最终验证。
8. 核对 changed files、diff、工作区状态和禁止范围。
9. 提交、推送；验证完成后创建 ready PR，验证未完成时创建 Draft 或停止并报告。
10. 输出可核验的最终报告。

## 基线同步

默认基于仓库默认分支。任务卡指定分支时，使用任务卡给出的值。

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git -c core.quotepath=false status --short
git checkout -b codex/<short-task>
```

需要记录：

- 基线 commit SHA。
- 默认分支。
- 分支名。
- 任务卡指定的其它基线事实。

## 工作区保护

修改前和创建 PR 前都要检查工作区。

```bash
git -c core.quotepath=false status --short
git -c core.quotepath=false diff --name-only
git ls-files --others --exclude-standard
```

提交后再检查相对基线的 changed files：

```bash
git -c core.quotepath=false diff --name-only origin/<base>...HEAD
```

如果工作区在任务开始时不为空：

1. 不覆盖。
2. 不 stash。
3. 不清理。
4. 停止任务。
5. 报告已有改动文件。

如果执行过程中发现会覆盖用户已有改动，也停止并报告事实。

## 最小读取和上下文控制

- 优先用 `rg`、路径过滤、章节定位、函数定位和行区间。
- 大文件只读目标函数、目标章节或目标键。
- 已读取且未变化的文件不重复读取。
- 不把完整 Issue、完整 AGENTS、完整 manifest、完整 registry、完整日志或完整 diff 复制进回复。
- 任务卡已给出的答案不再询问。
- 动态事实只从事实源读取：路径值来自 `manifests/paths.json`，定制范围来自 `manifests/customization-scope.json`，当前任务来自 Issue/任务卡，当前代码状态来自 Git 和实际文件。
- 除非任务明确提供路径或授权，不读取仓库外的用户目录、全局 Codex memory、VSCode 用户配置、浏览器数据或其它项目文件。

## 修改前盘点

按任务相关性盘点，不为了盘点修改无关文件。

按任务卡给出的关键词、函数、路径或章节搜索；任务卡未指定时，基于当前目标构造一次最小搜索。

```bash
rg -n "<keyword>|<keyword>" <paths>
```

盘点结论应覆盖：

- 当前实现或文档结构。
- 必须保持不变的安全边界、公开接口或业务不变量。
- 本次应修改和不应修改的范围。
- 本次需要的验证入口。

## 改动范围控制

- 先改最小目标文件集合。
- 不修改任务卡禁止范围。
- 不新增 CI、依赖或业务功能，除非当前任务明确要求。
- 文档任务不顺手重写业务文档。
- 代码任务不顺手全仓库格式化。
- 任何超出预期 changed files 的文件，都要在 PR body 中说明原因。

## 分级验证矩阵

| 改动类型 | 优先验证 |
|---|---|
| 文档/任务卡 | `git diff --check`；链接和引用搜索；changed files 核对 |
| Manifest/Schema | JSON 解析；Schema 校验；项目配置验证；相关定向测试 |
| 普通 PowerShell | PowerShell 语法解析；定向测试；项目配置验证 |
| common/编排 | 语法解析；common 单元测试；相关编排 `-WhatIf`；项目配置验证；适用的集成测试 |
| 危险 handler | 语法解析；Mock 测试；临时目录测试；`-WhatIf`；禁止真实系统写入 |
| 测试/CI | 定向测试；静态检查；全套适用测试；CI 配置语法检查 |
| WinPE | 计划文件测试；命令构造测试；模拟输出；禁止在 CI 或主力机触碰真实磁盘 |

验证原则：

- 先便宜，后昂贵。
- 先定向，后全量。
- 先静态，后运行。
- 危险 handler 只做 Mock、`-WhatIf` 或临时目录测试。
- 没有代码变化时，不重复运行同一个重型失败命令。

## 危险脚本测试规则

当任务明确要求修改危险脚本源码时，可以运行：

- PowerShell 语法解析。
- 静态检查。
- Mock 测试。
- 临时目录测试。
- `-WhatIf` 或 plan 模式。
- 模拟输出测试。

仍禁止未经单独授权执行真实安装、卸载、服务、注册表、Defender、AppX、Junction、Sysprep、分区、格式化、镜像捕获/应用、大规模 NAS 写入或工作区外删除。

## 失败分类

至少区分：

- 代码回归。
- 测试本身失败。
- 缺少依赖或工具。
- NAS 不可达。
- 缺少管理员权限。
- 平台不兼容。
- 已知非阻断警告。
- 不稳定测试。
- 工作区污染。
- 基线同步失败。
- 任务范围不明确。
- 必须执行危险动作才能继续。

## 最小重跑策略

1. 记录精确失败命令。
2. 保留关键错误。
3. 判断属于代码、测试、环境还是权限。
4. 修复后先重跑受影响的最小测试。
5. 最后再跑适用的全量验证。
6. 不通过重复运行掩盖不稳定测试。
7. 无代码变化时不重复运行同一重型失败命令。

## 停止条件

遇到以下情况停止并报告事实，不自行清理或猜测：

- 工作区在任务开始时不为空。
- 无法 fast-forward 到目标基线。
- Issue 与任务卡范围冲突。
- 发现会覆盖用户已有改动。
- 需要真实执行危险动作但没有明确授权。
- 目标文件或依赖已被并行任务大幅修改。
- 无法确认 PR base。
- 验证未完成但任务要求 ready for review。

## 临时文件和报告位置

- 任务临时文件优先放在系统临时目录或仓库已忽略的本地目录。
- PR body、评论正文等需要交给 `gh --body-file` 的 Markdown 临时文件放在 `.tmp/pr-bodies/`，并通过 `scripts/dev/pr_body_tool.py normalize` 生成或刷新。
- 轻量日志和报告按 manifest 中 reporting 设置或任务卡指定位置输出。
- 不把大型日志、镜像、安装包、压缩包、授权文件或临时输出提交到 Git。
- 普通验证不要强制写 NAS；只有任务明确要求或 manifest 显式启用时才使用对应输出路径。

## 临时文件清理

- 只清理本任务创建且位于安全临时位置的文件。
- 不清理用户已有文件。
- 不删除工作区外文件，除非用户对具体路径给出明确授权。
- 清理失败时报告路径和原因，不扩大删除范围。

## Commit 规范

- 一个任务卡对应一个分支和一个 PR。
- Commit 必须是原子的，按真实改动边界拆分。
- 不为了满足数量机械拆分 commit。
- Commit message 使用简洁英文前缀，例如 `docs(agents): streamline repository instructions`。
- 提交前核对未提交文件、未跟踪文件和禁止范围。

## Shell 和编码

- 当前 shell 能可靠执行时使用当前 shell，不无必要地嵌套 PowerShell 与 Bash。
- Windows PowerShell 5.1 中不要用 `&&` 或 `||` 串联命令；连续步骤拆成单条命令或使用原生控制流。
- 中文 PR body、评论正文或其它需要交给 `gh --body-file` 的文本，先写入明确的 UTF-8 文件，再传给 `gh`；不要通过 PowerShell 管道或命令行字符串直接传中文正文。
- PR body 使用 `scripts/dev/pr_body_tool.py` 处理：

```bash
python scripts/dev/pr_body_tool.py normalize --input <draft.md> --output .tmp/pr-bodies/<name>.md
python scripts/dev/pr_body_tool.py validate .tmp/pr-bodies/<name>.md
python scripts/dev/pr_body_tool.py create --title "<title>" --body-file .tmp/pr-bodies/<name>.md --base main --head <branch>
python scripts/dev/pr_body_tool.py edit --pr <number-or-url> --body-file .tmp/pr-bodies/<name>.md
python scripts/dev/pr_body_tool.py verify --pr <number-or-url> --body-file .tmp/pr-bodies/<name>.md
```

- 创建或更新 PR 后，必须读回标题、正文、base/head 和 Draft 状态，确认中文未损坏；使用上述 `create` 或 `edit` 时，工具会在写入后自动读回正文并验证一致。

## PR body 清单

PR body 至少包含：

1. 摘要。
2. 范围和修改文件。
3. 验证命令和结果。
4. 风险或危险动作说明。
5. 未解决事项。
6. `Closes #<issue>`。

## Ready For Review 条件

只有同时满足以下条件，PR 才能保持 ready for review：

- base/head 已确认。
- changed files 在允许范围内。
- 验证已按任务要求完成并记录结果。
- 工作区无未提交改动。
- 未执行未经授权的危险系统动作。
- PR body 已读回确认，包含必要上下文和 `Closes #<issue>`。

如果验证未完成，创建 Draft 或停止并报告，不伪装 ready。

## 最终报告字段

最终报告按任务需要包含：

- 基线 commit。
- 分支名。
- Commit 列表。
- PR 链接。
- PR base/head。
- Draft 状态。
- ready 状态。
- 修改文件列表。
- 每条验证命令及结果。
- 是否执行任何危险系统操作。
- 工作区最终状态。
- 未解决事项或非阻断风险。

任务卡可以追加当前任务特有字段；通用工作流不要求所有任务输出与当前目标无关的章节。

## 完成定义

任务完成必须满足：

- 验收标准逐项满足。
- 改动范围符合任务卡。
- 禁止范围未被修改。
- 验证命令已运行并如实记录。
- 未执行未经授权的危险动作。
- 需要 PR 时，PR 已创建且状态符合任务要求。
- 最终报告可让用户复核结果。
