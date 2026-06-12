#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "Applying system-level tweaks"

reg add "HKCR\Directory\shell\VSCode" /ve /d "通过 Code 打开" /f | Out-Null
reg add "HKCR\Directory\shell\VSCode" /v Icon /d "C:\tools\vscode-portable\Code.exe" /f | Out-Null
reg add "HKCR\Directory\shell\VSCode\command" /ve /d '"C:\tools\vscode-portable\Code.exe" "%V"' /f | Out-Null

reg add "HKCR\*\shell\VSCode" /ve /d "通过 Code 打开" /f | Out-Null
reg add "HKCR\*\shell\VSCode" /v Icon /d "C:\tools\vscode-portable\Code.exe" /f | Out-Null
reg add "HKCR\*\shell\VSCode\command" /ve /d '"C:\tools\vscode-portable\Code.exe" "%1"' /f | Out-Null

Write-KitLog "System tweaks finished" "OK"
