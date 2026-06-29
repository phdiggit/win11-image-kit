# Issue #18 User Experience Restore Intake

Status: `in-progress`

## Source

- Issue: [#18 [P2] 建立版本感知的默认应用与开始菜单恢复策略](https://github.com/phdiggit/win11-image-kit/issues/18)
- Roadmap: [#19 [Roadmap] Windows 11 镜像工具箱可靠性与可重复性优化总览](https://github.com/phdiggit/win11-image-kit/issues/19)

Issue #18 指出，现有部署后脚本会在线导入默认应用关联，并把 `LayoutModification.json` 写入 Default Profile。Windows 11 不同版本对默认应用和开始菜单布局的支持方式可能不同；模板来源版本、目标应用安装状态或执行时机不匹配时，脚本可能显示成功，但最终用户体验没有按预期生效。

## Roadmap Link

Roadmap #19 将 #18 放在 P2 "完善用户体验恢复" 中，目标是让用户体验恢复区分系统版本和用户作用域，不再把命令执行成功当作用户配置已生效。

## Problem Statement

默认应用、开始菜单、任务栏和应用可见性恢复必须先具备版本、作用域和目标应用依赖感知。当前阶段只建立 intake、manifest/schema、fixture 和 report-only planner，不执行真实恢复。

## Scope

- 记录 Windows Edition、Version、Build、架构和用户作用域的 fixture 输入。
- 生成默认应用关联 plan，覆盖扩展名、协议、ProgId、目标应用能力和缺失能力报告。
- 生成开始菜单和任务栏 plan，覆盖 pinned app、顺序、目标 Windows 版本和执行状态。
- 输出 `user-experience-restore` JSON report。
- 通过 Pester 覆盖 baseline 和 failure fixtures。
- 同步 PR Fast CI、Quality Gates、Build Lock 和 README 入口。

## Non-goals

- 不写 registry。
- 不写 profile、Default Profile 或 default user hive。
- 不导入默认应用关联。
- 不导入或导出真实 Start layout 作为证据。
- 不修改当前用户开始菜单、任务栏或默认应用。
- 不执行 DISM/AppX/Defender/Junction/Service/Sysprep mutation。
- 不下载网络依赖。
- 不新增 Issue #18 close-prep、main-evidence 或 completion summary。
- 不自动关闭 Issue #18。

## Version-Aware Inputs

版本上下文由 fixture 提供，至少包含 `productName`、`displayVersion`、`buildNumber`、`edition`、`architecture` 和 `scope`。当前 baseline 覆盖 Windows 11 24H2 和 23H2，unsupported 或 missing build fixture 必须进入 blocked/failed report。

## Default App Association Plan

默认应用 plan 只记录扩展名、协议和期望 ProgId，不生成真实导入命令，不声明默认应用已经变化。目标 ProgId 缺失或请求 mutation 时，validator 必须失败并输出结构化报告。

## Start Menu / Taskbar Plan

开始菜单和任务栏 plan 只读取 fixture，记录 pinned app、AppUserModelId placeholder、顺序和版本兼容性。写入 profile、写入 registry 或请求真实 layout mutation 的 fixture 必须被阻断。

## Report Contract

Report 必须包含：

- `trueExecution: false`
- `whatIf: true`
- `registryWriteCount: 0`
- `profileWriteCount: 0`
- `defaultAppMutationCount: 0`
- `startMenuMutationCount: 0`
- `taskbarMutationCount: 0`
- blocked/failed/missing capability/unsupported version counters

## CI / Quality Gates / Build Lock

PR Fast CI 运行 `scripts/validate/Test-UserExperienceRestore.ps1` 和 Issue #18 Pester。Post-PR #96 main/workflow Full Validate success 已记录为当前 report-only / handler-adapter stage 的 ready evidence。Quality Gates 纳入 `user-experience-restore`、`issue18-intake`、`issue18-acceptance`、`user-experience-default-apps-plan`、`user-experience-start-menu-plan`、close-prep 和 main evidence 文档。Build Lock 纳入本阶段文档、manifest、schema、scripts、fixtures、tests、workflow、README 和 Quality Gates。

Current report-only / handler-adapter stage manual closure handoff is recorded in [Issue #18 Manual Closure Handoff](64-issue18-manual-closure-handoff.md). Future true UX restore execution remains split into [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md). This intake remains source/background, not a completion summary.

## Acceptance Checklist

- [x] 真实 Issue #18 和 Roadmap #19 source 已记录。
- [x] 当前阶段为 intake + report-only / fixture baseline。
- [x] 默认应用和开始菜单计划是 version-aware。
- [x] baseline fixture 可生成 passing report。
- [x] unsupported version、missing build、unknown ProgId、profile write request、registry write request 和 local private path fixtures 被阻断。
- [x] 生成 ready close-prep 和 main-evidence 文档，但不生成 completion summary。
- [x] 不自动关闭 Issue #18。

## Related Documents

- [Issue #18 User Experience Restore Acceptance](59-issue18-user-experience-restore-acceptance.md)
- [Issue #18 User Experience Capability Matrix](60-issue18-user-experience-capability-matrix.md)
- [Issue #18 Restore Handler Integration](61-issue18-restore-handler-integration.md)
- [Issue #18 Manual Closure Handoff](64-issue18-manual-closure-handoff.md)
- [Future True UX Restore Execution Split](65-future-true-ux-restore-execution-split.md)
- [Codex 工作流](codex-workflow.md)
