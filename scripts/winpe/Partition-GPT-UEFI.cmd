@echo off
echo 警告：此脚本会清空所选磁盘。
echo 正式使用前请先修改目标磁盘编号。
exit /b 1

rem Example diskpart layout:
rem select disk 0
rem clean
rem convert gpt
rem create partition efi size=300
rem format quick fs=fat32 label="System"
rem assign letter=S
rem create partition msr size=16
rem create partition primary
rem shrink minimum=1024
rem format quick fs=ntfs label="Windows"
rem assign letter=W
rem create partition primary
rem format quick fs=ntfs label="Recovery"
rem assign letter=R
