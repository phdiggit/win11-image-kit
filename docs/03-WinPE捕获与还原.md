# WinPE 捕获与还原

## 捕获镜像

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

警告：分区脚本会清空目标磁盘。

推荐 GPT/UEFI 分区：

- EFI：300MB，FAT32
- MSR：16MB
- Windows：剩余空间减去 Recovery
- Recovery：1024MB

然后：

```cmd
DISM /Apply-Image /ImageFile:Z:\golden\win11-dev-YYYYMMDD.wim /Index:1 /ApplyDir:W:\
bcdboot W:\Windows /s S: /f UEFI
```
