#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "TODO: install and configure JDK, Maven, Node.js, Miniconda"
Write-KitLog "Keep this script idempotent: rerunning it should be safe." "WARN"
