#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "待实现：安装并配置 JDK、Maven、Node.js、Miniconda"
Write-KitLog "要求：脚本必须幂等，重复执行不应破坏现有环境。" "WARN"
