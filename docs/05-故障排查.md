# 故障排查

## Sysprep 失败

日志：

```text
%WINDIR%\System32\Sysprep\Panther\setuperr.log
%WINDIR%\System32\Sysprep\Panther\setupact.log
```

优先处理：

- 每用户 AppX 包未 provision
- Store 应用更新残留
- 待重启状态
- 第三方驱动或服务

不要把修改 `Generalize.xml` 作为常规方案。它只能作为 VM 快照中的最后兜底实验。

## 新机无法启动

检查：

- 是否 UEFI 启动
- EFI 分区是否正确分配盘符
- `bcdboot` 是否成功
- 是否把镜像应用到了正确 Windows 分区

## D 盘重定向失败

检查：

- D 盘是否存在
- 源目录是否被进程占用
- Junction 是否已指向其它目标
- robocopy 退出码是否小于 8
