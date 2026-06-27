# 默认应用模板元数据

本目录保存默认应用关联模板的示例元数据。当前 Issue #18 阶段只读取 metadata 生成计划和阻断报告，不导入默认应用关联，也不把命令退出码当作用户体验已生效证据。

未来如经单独授权从参考机导出模板，应同时记录：

- 来源 Windows edition、displayVersion、buildNumber、architecture。
- `exportedAt` 与 `sourceRunId`。
- 目标应用的 logicalName、ProgId、packageFamilyName 和 required 标记。
- 目标作用域，默认应用模板通常应明确为 `default-user` 或 `offline-image`。

metadata 缺失、来源版本不兼容、ProgId 缺失或目标 scope 不匹配时，自动化只能报告 blocked/manual，不能继续执行真实导入。
