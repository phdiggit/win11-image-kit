@echo off
set IMAGE_DATE=%DATE:~0,4%-%DATE:~5,2%-%DATE:~8,2%
set IMAGE_NAME=win11-dev-%IMAGE_DATE%

echo Confirm WinPE drive letters before running this script.
echo Example:
echo   net use Z: \\192.168.1.37\images
echo   DISM /Capture-Image /ImageFile:Z:\win11\golden\%IMAGE_NAME%.wim /CaptureDir:C:\ /Name:"%IMAGE_NAME%" /Compress:max /CheckIntegrity
