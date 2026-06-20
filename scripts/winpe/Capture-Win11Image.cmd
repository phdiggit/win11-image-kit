@echo off
setlocal EnableExtensions

set CAPTURE_DIR=%~1
if "%CAPTURE_DIR%"=="" set CAPTURE_DIR=C:\

set IMAGE_ROOT=%~2
if "%IMAGE_ROOT%"=="" set IMAGE_ROOT=Z:\golden

set IMAGE_NAME=%~3
if "%IMAGE_NAME%"=="" set IMAGE_NAME=win11-dev-YYYYMMDD

echo This script prints capture commands only. It does not run DISM.
echo.
echo Confirm WinPE drive letters first:
echo   diskpart
echo   list volume
echo   exit
echo.
echo Map NAS image root if needed:
echo   net use Z: \\192.168.1.37\backups\win11-image-kit\images\win11
echo.
echo Capture command:
echo   DISM /Capture-Image /ImageFile:%IMAGE_ROOT%\%IMAGE_NAME%.wim /CaptureDir:%CAPTURE_DIR% /Name:"%IMAGE_NAME%" /Compress:max /CheckIntegrity
exit /b 0
