@echo off
echo Confirm target partitions before running.
echo Example:
echo   net use Z: \\192.168.1.37\images
echo   DISM /Apply-Image /ImageFile:Z:\win11\golden\win11-dev-YYYYMMDD.wim /Index:1 /ApplyDir:W:\
echo   bcdboot W:\Windows /s S: /f UEFI
