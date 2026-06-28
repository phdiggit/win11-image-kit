# Future True UX Restore Packet Preview Lessons

Status: `integrated-packet-preview-lessons`

## Lessons

- Preview 是结构和阅读入口，不是授权入口。
- `packet-preview-ready` 不等于 `authorization-review-ready`，也不等于 true UX restore 已经成功。
- Preview report 不能被当成真实 UX evidence；它只汇总 dry-run、mock、negative review 和 approval checklist 的可读信息。
- Runner gate reminder 是风险提示，不是 runner 扩权确认。
- 本阶段不创建 Issue #18 completion summary，不做 close-prep，不做 main-evidence，不自动关闭 Issue #18。

## Stop Condition

如果实现需要 workflow 改动、真实系统写入、安装下载、注册表/Profile/AppX/StartLayout/Defender/Junction/Service/Sysprep/DISM、写真实用户配置或写系统目录，应停止并重新确认范围。
