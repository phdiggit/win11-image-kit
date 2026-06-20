$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "测试部署后关键项"

if (Test-Path "D:\") {
    Write-KitLog "D: 存在" "OK"
} else {
    Write-KitLog "D: 不存在" "WARN"
}

& "$PSScriptRoot\Test-DevEnvironment.ps1"
& "$PSScriptRoot\Test-Middleware.ps1"
