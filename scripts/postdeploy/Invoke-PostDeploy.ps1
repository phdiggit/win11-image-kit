#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "Starting post-deploy"

& "$PSScriptRoot\Set-DataJunctions.ps1"
& "$PSScriptRoot\Register-MiddlewareServices.ps1"
& "$PSScriptRoot\Restore-UserExperience.ps1"

Write-KitLog "Post-deploy finished" "OK"
