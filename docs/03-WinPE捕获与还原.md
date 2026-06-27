# WinPE 捕获与还原

## 捕获镜像

仓库里的 `scripts\winpe\Capture-Win11Image.cmd` 只打印建议命令，不会执行 DISM：

```cmd
scripts\winpe\Capture-Win11Image.cmd C:\ Z:\golden win11-dev-YYYYMMDD
```

在 WinPE 中确认盘符：

```cmd
diskpart
list volume
exit
```

映射 NAS：

```cmd
net use Z: \\192.168.1.37\backups\win11-image-kit\images\win11
```

捕获：

```cmd
DISM /Capture-Image /ImageFile:Z:\golden\win11-dev-YYYYMMDD.wim /CaptureDir:C:\ /Name:"win11-dev-YYYYMMDD" /Compress:max /CheckIntegrity
```

## 还原镜像

警告：真正执行 `diskpart clean` 会清空目标磁盘。仓库里的 `scripts\winpe\Partition-GPT-UEFI.cmd` 只生成 diskpart 计划文件，不会执行分区：

```cmd
scripts\winpe\Partition-GPT-UEFI.cmd 0 X:\partition-disk0.txt
```

人工核对目标磁盘无误后，再手动执行：

```cmd
diskpart /s X:\partition-disk0.txt
```

推荐 GPT/UEFI 分区：

- EFI：300MB，FAT32
- MSR：16MB
- Windows：剩余空间减去 Recovery
- Recovery：1024MB

然后：

`scripts\winpe\Apply-Win11Image.cmd` 只打印建议命令，不会执行 DISM 或 `bcdboot`：

```cmd
scripts\winpe\Apply-Win11Image.cmd Z:\golden\win11-dev-YYYYMMDD.wim W:\ S:
```

```cmd
DISM /Apply-Image /ImageFile:Z:\golden\win11-dev-YYYYMMDD.wim /Index:1 /ApplyDir:W:\
bcdboot W:\Windows /s S: /f UEFI
```

## 受控执行计划入口

Issue #17 当前仍只允许计划、模拟和 `-WhatIf`。`scripts\winpe\New-WinPEControlledExecutionPlan.ps1` 可以解析未来还原流程需要的目标磁盘、镜像哈希、镜像索引、架构、确认令牌和 `SourceRunId`，但只输出 JSON 计划报告。

即使传入 `-Execute`，当前阶段也会返回 blocked 报告；确认令牌匹配不代表允许真实执行。diskpart、DISM、bcdboot 和 reagentc 只能出现在 planned command 字符串或 fixture 中，不得由受控执行脚本调用。

PR Fast CI 只验证计划/模拟边界，不是 main/workflow 生命周期证据。
