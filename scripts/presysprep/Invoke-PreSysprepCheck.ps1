#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$failed = 0

function Assert-Check {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Hint
    )

    if ($Condition) {
        Write-KitLog "$Name" "OK"
    } else {
        Write-KitLog "$Name - $Hint" "ERROR"
        $script:failed++
    }
}

Assert-Check "当前以管理员身份运行" ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) "请以管理员身份运行 PowerShell"
Assert-Check "Sysprep 文件存在" (Test-Path "$env:WINDIR\System32\Sysprep\sysprep.exe") "当前 Windows 安装异常"

$pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
Assert-Check "没有待重启状态" (-not $pendingReboot) "请先重启系统，再执行 Sysprep"

$vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
Assert-Check "VMware Tools 已移除" (-not $vmwareTools) "Sysprep 前请卸载 VMware Tools"

$tailscale = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
Assert-Check "Tailscale 服务不存在" (-not $tailscale) "Sysprep 前请停止并删除 Tailscale 服务"

if ($failed -gt 0) {
    Write-KitLog "$failed 项检查失败。暂时不要执行 Sysprep。" "ERROR"
    exit 1
}

Write-KitLog "Sysprep 前检查通过" "OK"
