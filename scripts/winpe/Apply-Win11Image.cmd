@echo off
echo 运行前请确认目标分区。
echo 示例：
echo   net use Z: \\192.168.1.37\backups\win11-image-kit\images\win11
echo   DISM /Apply-Image /ImageFile:Z:\golden\win11-dev-YYYYMMDD.wim /Index:1 /ApplyDir:W:\
echo   bcdboot W:\Windows /s S: /f UEFI
