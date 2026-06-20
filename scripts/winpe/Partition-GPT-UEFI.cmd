@echo off
setlocal EnableExtensions

if "%~1"=="" goto usage

set TARGET_DISK=%~1
set PLAN_FILE=%~2
if "%PLAN_FILE%"=="" set PLAN_FILE=%TEMP%\partition-gpt-uefi-disk-%TARGET_DISK%.txt

> "%PLAN_FILE%" echo select disk %TARGET_DISK%
>> "%PLAN_FILE%" echo clean
>> "%PLAN_FILE%" echo convert gpt
>> "%PLAN_FILE%" echo create partition efi size=300
>> "%PLAN_FILE%" echo format quick fs=fat32 label="System"
>> "%PLAN_FILE%" echo assign letter=S
>> "%PLAN_FILE%" echo create partition msr size=16
>> "%PLAN_FILE%" echo create partition primary
>> "%PLAN_FILE%" echo shrink minimum=1024
>> "%PLAN_FILE%" echo format quick fs=ntfs label="Windows"
>> "%PLAN_FILE%" echo assign letter=W
>> "%PLAN_FILE%" echo create partition primary
>> "%PLAN_FILE%" echo format quick fs=ntfs label="Recovery"
>> "%PLAN_FILE%" echo assign letter=R

echo Diskpart plan written:
echo   %PLAN_FILE%
echo.
echo This script DID NOT run diskpart.
echo Review the target disk carefully. To execute manually:
echo   diskpart /s "%PLAN_FILE%"
exit /b 0

:usage
echo This script only writes a GPT/UEFI diskpart plan. It never runs diskpart.
echo.
echo Usage:
echo   %~nx0 ^<disk-number^> [plan-file]
echo.
echo Example:
echo   %~nx0 0 X:\partition-disk0.txt
echo.
echo After review, run manually:
echo   diskpart /s X:\partition-disk0.txt
exit /b 1
