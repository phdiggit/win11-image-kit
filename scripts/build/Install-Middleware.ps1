[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "manifests/software.json",
    [string]$PathsManifestPath = "manifests/paths.json",
    [ValidateSet("golden-image", "post-deploy", "manual", "all")]
    [string]$Stage = "golden-image",
    [string[]]$Categories = @("middleware", "middleware-*", "database", "cache", "message-queue", "search", "service-registry", "coordination")
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Install-KitSoftwarePackages.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$ManifestPath = if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path -Path $repoRoot -ChildPath $ManifestPath }
$PathsManifestPath = if ([IO.Path]::IsPathRooted($PathsManifestPath)) { $PathsManifestPath } else { Join-Path -Path $repoRoot -ChildPath $PathsManifestPath }
Assert-KitElevation -Operation "中间件准备入口" -AllowWhatIfPreview

Install-KitSoftwarePackages `
    -ManifestPath $ManifestPath `
    -PathsManifestPath $PathsManifestPath `
    -Stage $Stage `
    -IncludeCategories $Categories `
    -IncludeTypes @("archive", "zip") `
    -WorkloadName "中间件准备项" `
    -CompletionMessage "中间件准备完成，未注册或启动长期服务" `
    -WhatIf:$WhatIfPreference
