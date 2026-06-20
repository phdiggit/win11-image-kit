@echo off
set IMAGE_DATE=%DATE:~0,4%-%DATE:~5,2%-%DATE:~8,2%
set IMAGE_NAME=win11-dev-%IMAGE_DATE%

echo 运行前请确认 WinPE 中的盘符。
echo 示例：
echo   net use Z: \\192.168.1.37\backups\win11-image-kit\images\win11
echo   DISM /Capture-Image /ImageFile:Z:\golden\%IMAGE_NAME%.wim /CaptureDir:C:\ /Name:"%IMAGE_NAME%" /Compress:max /CheckIntegrity
