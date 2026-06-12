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

Assert-Check "Running as administrator" ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) "Run PowerShell as administrator"
Assert-Check "Sysprep exists" (Test-Path "$env:WINDIR\System32\Sysprep\sysprep.exe") "Unexpected Windows installation"

$pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
Assert-Check "No pending reboot" (-not $pendingReboot) "Reboot before Sysprep"

$vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
Assert-Check "VMware Tools removed" (-not $vmwareTools) "Uninstall VMware Tools before Sysprep"

$tailscale = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
Assert-Check "Tailscale service absent" (-not $tailscale) "Stop and delete Tailscale service before Sysprep"

if ($failed -gt 0) {
    Write-KitLog "$failed check(s) failed. Do not run Sysprep yet." "ERROR"
    exit 1
}

Write-KitLog "Pre-Sysprep checks passed" "OK"
