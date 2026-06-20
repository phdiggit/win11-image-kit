#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\appx-cleanup.json"
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$removePatterns = @($manifest.removeNamePatterns)
$keepPatterns = @($manifest.keepNamePatterns)

$packages = Get-AppxPackage -AllUsers | Where-Object {
    $packageName = $_.Name
    $shouldRemove = $false
    foreach ($pattern in $removePatterns) {
        if ($packageName -match [regex]::Escape($pattern)) {
            $shouldRemove = $true
            break
        }
    }

    foreach ($pattern in $keepPatterns) {
        if ($packageName -match $pattern -or $_.PackageFullName -match $pattern) {
            $shouldRemove = $false
            break
        }
    }

    $shouldRemove
}

foreach ($package in $packages) {
    if ($manifest.policy -eq "audit-only") {
        Write-KitLog "仅审计，不删除 AppX 包：$($package.PackageFullName)" "WARN"
        continue
    }

    if ($PSCmdlet.ShouldProcess($package.PackageFullName, "删除 AppX 包")) {
        Write-KitLog "删除 AppX 包：$($package.PackageFullName)" "WARN"
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
}

Write-KitLog "AppX 清理完成" "OK"
