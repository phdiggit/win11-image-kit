# Issue #18 Restore Handler Integration

Status: `accepted-ready-for-manual-closure`

## Scope

本阶段把 `Restore-UserExperience.ps1` 与 Issue #18 的 scope-aware / version-aware planner 接起来，但仍保持 report-only。入口读取 `customization-scope.json`、`configs/default-apps/*.metadata.json` 和 `configs/start-menu/*.metadata.json`，输出 handler report、manual checklist 与 legacy `userExperienceSummary`。

## Restore-UserExperience Entry Point

`scripts/postdeploy/Restore-UserExperience.ps1` 默认输出 `restore-user-experience` 报告：

- `mode=plan-only`
- `whatIf=true`
- `trueExecution=false`
- `handlerExecutionCount=0`
- mutation counters 全为 0

`-Apply` / `-Execute` 当前只会生成 blocked handler，并返回失败退出码；它们不是真实执行授权。

## Handler Adapter Model

handler adapter 只把输入配置转换为计划：

- `default-apps`
- `start-menu`
- `taskbar`
- `manual-checklist`
- `verification`

所有 handler 都保留 `executed=false`。planned/manual/blocked 是审阅状态，不是用户体验已经生效的证据。

## Default App Handler

默认应用 handler 读取 `configs/default-apps/default-apps.metadata.json`。metadata 必须记录来源 Windows 版本、build、scope、目标应用与 ProgId。缺失 ProgId、缺失 required app、scope 不匹配或请求真实导入时，报告为 blocked。

当前不执行默认应用导入，不调用 DISM，不写系统位置，也不查询真实已安装 AppX 作为成功证据。

## Start Menu Handler

开始菜单 handler 读取 `configs/start-menu/start-menu.metadata.json`。`default-user` 表示新用户默认布局计划，不等同于当前用户开始菜单已变化。`current-user` 路径当前保持 manual checklist，等待未来受支持的真实验证设计。

## Taskbar Handler

任务栏 handler 当前仅生成 manual checklist。任何 registry 写入或 requested apply 都会被 blocked。

## Template Metadata Sources

`configs/default-apps/README.md` 与 `configs/start-menu/README.md` 说明未来参考机导出时需要记录的 metadata。当前提交的 metadata 是示例描述符，不包含私有用户路径、SID、NAS 路径或本机 evidence。

## Scope Mapping

`manifests/customization-scope.json` 新增 `userExperienceRestore`：

- `defaultUserIsCurrentUser=false`
- `offlineImageIsCurrentMachine=false`
- 所有 mutation allow flags 均为 `false`

这组字段用于阻止 Default Profile、offline image 或命令退出码被误报为当前用户已配置。

## Verification Checklist

manual checklist 是未来授权验证的待办清单：

- `commandExitCodeSufficient=false`
- `userConfigurationConfirmed=false`
- `status=manual`

它不是 main/workflow evidence，也不是真实 UX restore evidence。

## Current Non-goals

- ready is limited to current report-only / handler-adapter manual closure readiness
- real UX restore execution remains future authorized work
- no Issue #18 completion summary
- no Issue #18 auto-close
- no registry/profile/default app/Start menu/taskbar mutation
- no DISM import
- no StartLayout import/export as evidence
- no AppX query/mutation as success evidence

## Validation

本阶段验收以 fixture、schema、Pester、Quality Gates、Build Lock 和 post-PR #96 main/workflow Full Validate success 为主。`Restore-UserExperience.ps1 -WhatIf -ReportPath ...` 只能证明 handler report 结构和安全边界，不能证明真实用户体验已恢复。PR Fast CI 不是 main/workflow evidence，handler report 不是 real UX restore evidence，manual checklist 不是 success evidence。

## Remaining Work

- 扩展更多真实模板 fixture 与缺失应用矩阵。
- 设计未来真实执行授权与 evidence collection 分支。
- 在单独任务中回填 post-PR main/workflow validation evidence。
- 将未来真实 UX restore execution 拆到明确授权的受控任务。

## Related Documents

- [Issue #18 intake](58-issue18-user-experience-restore-intake.md)
- [Issue #18 acceptance](59-issue18-user-experience-restore-acceptance.md)
- [Issue #18 capability matrix](60-issue18-user-experience-capability-matrix.md)
- [Issue #18 close preparation](62-issue18-close-preparation.md)
- [Issue #18 main validation evidence](63-issue18-main-validation-evidence.md)
