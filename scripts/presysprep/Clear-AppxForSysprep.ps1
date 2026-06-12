#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$patterns = "Microsoft\.(LockApp|Xbox|Bing|Zune|OfficeHub|Skype|Spotify|Solitaire|Minecraft|OneConnect|MixedReality|People|Wallet|Alarms|Camera|Maps|Paint|Sticky|SoundRecorder|Feedback|GetHelp|Tips|News|Weather|Clipchamp|DevHome|OutlookForWindows|PowerAutomate|Teams|Family|Todos|ScreenSketch|Whiteboard)"

$packages = Get-AppxPackage -AllUsers | Where-Object { $_.PackageFullName -match $patterns }

foreach ($package in $packages) {
    if ($PSCmdlet.ShouldProcess($package.PackageFullName, "Remove AppX package")) {
        Write-KitLog "Removing $($package.PackageFullName)" "WARN"
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
}

Write-KitLog "AppX cleanup pass finished" "OK"
