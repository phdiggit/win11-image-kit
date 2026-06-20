# Sysprep 前检查

Sysprep 是不可逆步骤。所有检查通过后再执行通用化。

## 必查项

- 当前运行在金镜像 VM，而不是主力机真实系统。
- 已拍 VMware 快照。
- 无 Windows Update pending reboot。
- 未运行系统代理或已退出代理软件。
- VMware Tools 已卸载。
- Tailscale、数据库、中间件服务已停止并删除。
- IDM 已取消浏览器接管。
- AppX per-user 包清理完成。
- Sysprep 日志目录可写。
- C 盘已清理临时文件和休眠文件。
- 镜像目标路径空间充足。

## 建议命令

```powershell
scripts\presysprep\Invoke-PreSysprepCheck.ps1
scripts\presysprep\Clear-AppxForSysprep.ps1 -WhatIf
scripts\presysprep\Stop-ImageUnsafeServices.ps1 -WhatIf
```

确认后再去掉 `-WhatIf`。

## Sysprep

VM 中建议：

```cmd
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /quit
```

完成后不要重启 Windows。通过 VMware 菜单关机，再进入 WinPE 或挂载虚拟磁盘捕获镜像。
