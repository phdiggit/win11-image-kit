[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "manifests/software.json",
    [string]$PathsManifestPath = "manifests/paths.json",
    [ValidateSet("golden-image", "post-deploy", "manual", "all")]
    [string]$Stage = "golden-image"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Install-KitSoftwarePackages.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$ManifestPath = if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path -Path $repoRoot -ChildPath $ManifestPath }
$PathsManifestPath = if ([IO.Path]::IsPathRooted($PathsManifestPath)) { $PathsManifestPath } else { Join-Path -Path $repoRoot -ChildPath $PathsManifestPath }
Assert-KitElevation -Operation "开发运行时准备入口" -AllowWhatIfPreview

Install-KitSoftwarePackages `
    -ManifestPath $ManifestPath `
    -PathsManifestPath $PathsManifestPath `
    -Stage $Stage `
    -IncludeCategories @("dev-runtime") `
    -IncludeTypes @("archive", "zip") `
    -WorkloadName "开发运行时" `
    -CompletionMessage "开发运行时准备完成" `
    -WhatIf:$WhatIfPreference
