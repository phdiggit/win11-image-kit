[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "manifests/software.json",
    [string]$PathsManifestPath = "manifests/paths.json",
    [ValidateSet("golden-image", "post-deploy", "manual", "all")]
    [string]$Stage = "golden-image",
    [string]$PackageReportPath,
    [switch]$PackageReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Install-KitSoftwarePackages.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$ManifestPath = if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path -Path $repoRoot -ChildPath $ManifestPath }
$PathsManifestPath = if ([IO.Path]::IsPathRooted($PathsManifestPath)) { $PathsManifestPath } else { Join-Path -Path $repoRoot -ChildPath $PathsManifestPath }
Assert-KitElevation -Operation "归档包安装入口" -AllowWhatIfPreview

$excludedCategories = @()
if ($Stage -eq "golden-image") {
    $excludedCategories = @("dev-runtime", "middleware", "middleware-*", "database", "cache", "message-queue", "search", "service-registry", "coordination")
}

Install-KitSoftwarePackages `
    -ManifestPath $ManifestPath `
    -PathsManifestPath $PathsManifestPath `
    -Stage $Stage `
    -ExcludeCategories $excludedCategories `
    -IncludeTypes @("archive", "zip") `
    -WorkloadName "归档包" `
    -CompletionMessage "归档包安装完成" `
    -PackageReportPath $PackageReportPath `
    -PackageReportRequired:$PackageReportRequired `
    -WhatIf:$WhatIfPreference
