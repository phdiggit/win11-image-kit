@echo off
setlocal EnableExtensions

if "%~1"=="" goto usage

set IMAGE_FILE=%~1
set APPLY_DIR=%~2
if "%APPLY_DIR%"=="" set APPLY_DIR=W:\

set EFI_DRIVE=%~3
if "%EFI_DRIVE%"=="" set EFI_DRIVE=S:

echo This script prints apply commands only. It does not run DISM or bcdboot.
echo.
echo Confirm target partitions first:
echo   diskpart
echo   list volume
echo   exit
echo.
echo Apply command:
echo   DISM /Apply-Image /ImageFile:%IMAGE_FILE% /Index:1 /ApplyDir:%APPLY_DIR%
echo.
echo Boot command:
echo   bcdboot %APPLY_DIR%Windows /s %EFI_DRIVE% /f UEFI
exit /b 0

:usage
echo This script prints restore commands only.
echo.
echo Usage:
echo   %~nx0 ^<image-file^> [apply-dir] [efi-drive]
echo.
echo Example:
echo   %~nx0 Z:\golden\win11-dev-YYYYMMDD.wim W:\ S:
exit /b 1
