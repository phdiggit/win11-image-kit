# 开始菜单模板元数据

本目录保存开始菜单布局模板的示例元数据。当前 Issue #18 阶段只把模板解析为 report-only 计划，不写 Default Profile，也不宣称当前用户开始菜单已改变。

未来如经单独授权从参考机导出布局，应同时记录：

- 来源 Windows edition、displayVersion、buildNumber、architecture。
- `exportedAt` 与 `sourceRunId`。
- 目标应用的 logicalName、AppUserModelId 或 packageFamilyName。
- 目标作用域：`default-user` 表示新用户默认布局，不能等同于 `current-user`。

metadata 缺失、来源版本不兼容、scope 不匹配或目标应用缺失时，自动化只能报告 blocked/manual。当前用户开始菜单和任务栏仍需要未来真实验证或人工清单。
