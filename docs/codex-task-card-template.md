# Codex 任务卡模板

本模板用于给 Codex 提供可执行、可验证、可裁剪的任务说明。简单任务可以合并或删除不适用章节；不要机械保持同样长度，也不要复制完整 `AGENTS.md`。

## 任务标题

<!-- 写清 Issue 编号、任务类型和交付目标。 -->

`#<issue> <短标题>`

## 推荐模型

<!-- 可删除。需要高风险推理或大范围盘点时再指定。 -->

`GPT-5.5`

## 推荐思考强度

<!-- 可删除。建议用低/中/高，而不是写复杂策略。 -->

`中`

## 完整交付流程

<!-- 写可观察的交付步骤。简单任务可以缩短为 3-5 步。 -->

1. 从最新默认分支创建任务分支。
2. 读取根 `AGENTS.md`、当前 Issue/任务卡和目标文件。
3. 盘点现有行为或文档约定。
4. 实施最小改动。
5. 运行验证。
6. 提交、推送并创建 PR。
7. 输出最终报告。

## 建议分支名

<!-- 必须按当前仓库调整，不要照抄其它仓库分支名。 -->

`codex/<short-task>`

## 任务定位

<!-- 说明本 PR 做什么、不做什么，以及为什么现在做。 -->

- 目标：
- 非目标：
- 与 roadmap 或其它 Issue 的关系：

## 执行环境

<!-- 可删除。仅在环境约束会影响执行时保留。 -->

- 本地 Windows / VSCode / Codex。
- 使用 PATH 中可用的 `git`、`gh`、`rg`、PowerShell 或 Python。
- 不依赖固定盘符或个人机器路径。

## 规则读取方式

<!-- 明确最小必读文件。不要要求通读全仓库。 -->

必须读取：

- `AGENTS.md`
- 当前 Issue/任务卡
- `<目标文件>`

按需读取：

- `<直接关联文件>`

不要通读：

- 与本任务无关的目录或 Issue。
- 完整日志、大型 manifest、完整 Git 历史。

## 同步与基线

<!-- 按当前仓库默认分支调整；如果不需要 PR，可删除推送相关内容。 -->

```bash
git fetch origin
git checkout <default-branch>
git pull --ff-only origin <default-branch>
git -c core.quotepath=false status --short
git checkout -b codex/<short-task>
```

如果工作区不为空：不覆盖、不 stash、不清理，停止并报告现有改动文件。

## 修改前盘点

<!-- 写出要搜索的关键词、目标函数、目标章节或现有模板。 -->

建议搜索：

```bash
rg -n "<keyword>|<keyword>" <paths>
```

需要记录：

- 当前行为或当前文档结构。
- 必须保留的稳定规则。
- 动态事实或环境绑定项。
- 可能影响验证的入口。

## 目标结构或目标行为

<!-- 文档任务写目标章节；代码任务写目标行为、输入输出和边界。 -->

- 新增：
- 修改：
- 删除或迁移：

## 实现要求

<!-- 必须具体到可执行。避免只写“优化”“完善”。 -->

1.
2.
3.

## 必须保持不变

<!-- 列出不能破坏的安全边界、兼容性、公开接口或文档定位。 -->

-

## 禁止范围

<!-- 必须具体。不要让 Codex 猜测哪些文件不能动。 -->

禁止修改：

- `<path>/**`

不得执行：

- 安装/卸载、服务、注册表、Defender、AppX、Sysprep、分区、Junction 或其它真实危险动作，除非本任务明确要求且用户另行授权。

## 预期修改文件

<!-- 列出允许 changed files。额外文件需要在 PR body 说明原因。 -->

```text
<file-1>
<file-2>
```

## 建议提交结构

<!-- 可删除。改动很小时允许单个原子 commit。 -->

Commit 1：

```text
<type>(<scope>): <summary>
```

包含：

- `<file>`

## 验证命令

<!-- 命令必须适配当前仓库；不要照抄其它仓库的 registry、repo_tool.py、输出目录或测试命令。 -->

基础检查：

```bash
git -c core.quotepath=false diff --check
git -c core.quotepath=false diff --name-only
git ls-files --others --exclude-standard
```

定向验证：

```bash
<command>
```

最终核对：

```bash
git -c core.quotepath=false status --short
git -c core.quotepath=false diff --name-only origin/<default-branch>...HEAD
git -c core.quotepath=false diff --stat origin/<default-branch>...HEAD
```

## 时间控制规则

<!-- 可删除。需要 PR 交付或 CI 验证时保留。 -->

- 默认 PR_READY：创建 ready PR 后不等待 CI 完成，除非本任务明确要求。
- PR 默认只要求 PR Fast CI；Full CI 在 `main` push 或手动 `workflow_dispatch` 运行。
- 只有任务卡明确要求，才等待 Full CI。
- 本地全量 Pester 最多一次；follow-up 只跑受影响测试。
- CI 失败最多修一轮，第二次仍失败则停止并报告。
- PR CI 不新增真实危险执行测试；真实执行另开 VM/admin smoke。

## PR body

<!-- 要求 PR body 包含可复核事实，不要复制完整任务卡。 -->

正文文件放在 `.tmp/pr-bodies/`，并使用本地护栏工具规范化、校验和写入：

```bash
python scripts/dev/pr_body_tool.py normalize --input <draft.md> --output .tmp/pr-bodies/<name>.md
python scripts/dev/pr_body_tool.py validate .tmp/pr-bodies/<name>.md
python scripts/dev/pr_body_tool.py create --title "<title>" --body-file .tmp/pr-bodies/<name>.md --base <default-branch> --head <branch>
python scripts/dev/pr_body_tool.py edit --pr <number-or-url> --body-file .tmp/pr-bodies/<name>.md --title "<title>" --base <default-branch> --head <branch> --draft false
python scripts/dev/pr_body_tool.py verify --pr <number-or-url> --body-file .tmp/pr-bodies/<name>.md --title "<title>" --base <default-branch> --head <branch> --draft false
```

不要通过 PowerShell 管道或命令行字符串直接向 `gh` 传中文正文；创建或编辑 PR 后必须读回 GitHub 正文、标题、base/head 和 Draft 状态并验证一致。

PR 标题建议：

```text
<title>
```

PR body 至少包含：

1. 摘要。
2. 修改文件。
3. 验证命令和结果。
4. 危险操作说明。
5. 未解决事项。
6. Issue 引用：阶段性 PR 使用 `Refs #<issue>`；任务明确关闭时才使用 `Closes/Fixes/Resolves #<issue>`。

## 最终验收标准

<!-- 每条必须可运行或可观察。避免“更好”“更清晰”这类不可验收描述。 -->

- [ ]
- [ ] changed files 符合预期。
- [ ] 验证命令已运行并记录结果。
- [ ] 未执行未经授权的危险系统动作。
- [ ] PR 已创建并符合任务要求。

## Codex 最终报告

<!-- 写用户最后需要看到的字段。简单任务可以删减。 -->

完成后报告：

- 基线 commit。
- 分支名。
- Commit 列表。
- PR 链接。
- PR base/head。
- Draft/ready 状态。
- 修改文件列表。
- 验证命令及结果。
- latest head SHA。
- CI 是否已触发。
- 是否等待 CI；如果未等待 CI，说明这是 PR_READY 模式。
- 是否执行危险系统动作。
- 工作区最终状态。
- 未解决的非阻断事项。
