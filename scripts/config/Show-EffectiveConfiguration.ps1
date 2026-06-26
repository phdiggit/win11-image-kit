param(
    [string]$ConfigLayersPath = "manifests/config-layers.json",
    [string]$StackName = "default",
    [switch]$IncludeLocal,
    [string]$PathOverrideJson,
    [switch]$RedactLocalValues,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitEffectiveConfiguration.ps1"

$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$pathOverride = @{}
if (-not [string]::IsNullOrWhiteSpace($PathOverrideJson)) {
    $pathOverride = ConvertTo-KitHashtable -InputObject ($PathOverrideJson | ConvertFrom-Json)
}

$report = Resolve-KitEffectiveConfiguration `
    -ConfigLayersPath $ConfigLayersPath `
    -StackName $StackName `
    -IncludeLocal:$IncludeLocal `
    -PathOverride $pathOverride `
    -RedactLocalValues:$RedactLocalValues `
    -RepoRoot $RepoRoot

Write-KitLog ("Effective configuration stack: {0}" -f $report.stackName)
Write-KitLog ("Include local private override: {0}" -f $report.includeLocal)
Write-KitLog ("Redact local values: {0}" -f $report.redactedLocalValues)
Write-KitLog "Applied layers:"
foreach ($layer in @($report.appliedLayers)) {
    Write-KitLog ("  {0} ({1}) -> {2}" -f $layer.id, $layer.kind, $layer.path)
}

Write-KitLog "Effective paths:"
foreach ($path in @($report.pathSources)) {
    $displayValue = if ($RedactLocalValues) { $path.redactedValue } else { $path.value }
    Write-KitLog ("  {0} = {1} [{2}]" -f $path.key, $displayValue, $path.sourceLayer)
}

foreach ($warning in @($report.warnings)) {
    Write-KitLog ("Warning: {0}" -f $warning)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) {
        [IO.Path]::GetFullPath($ReportPath)
    } else {
        [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $ReportPath))
    }

    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-KitLog ("Effective configuration report written: {0}" -f $resolvedReportPath)
}
