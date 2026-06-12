$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "Testing post-deploy essentials"

if (Test-Path "D:\") {
    Write-KitLog "D: exists" "OK"
} else {
    Write-KitLog "D: missing" "WARN"
}

& "$PSScriptRoot\Test-DevEnvironment.ps1"
& "$PSScriptRoot\Test-Middleware.ps1"
