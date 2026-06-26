param(
    [string]$ConfigLayersPath = "manifests/config-layers.json",
    [string]$StackName = "default",
    [switch]$IncludeLocal,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitEffectiveConfiguration.ps1"

$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$report = Resolve-KitEffectiveConfiguration -ConfigLayersPath $ConfigLayersPath -StackName $StackName -IncludeLocal:$IncludeLocal -RepoRoot $RepoRoot
$failures = @()

foreach ($path in @($report.pathSources)) {
    if ($path.value -match '\$\{[^}]+\}') {
        $failures += "Unresolved path token: $($path.key) -> $($path.value)"
    }

    foreach ($pattern in @($report.safety.forbiddenPathPatterns)) {
        if ($path.value -match [string]$pattern) {
            $failures += "Path matched forbidden pattern: $($path.key) -> $($path.value)"
        }
    }
}

if ($report.safety.forbidTrackedLocalOverrides) {
    foreach ($layer in @($report.appliedLayers)) {
        if ($layer.kind -eq "local" -and $layer.tracked) {
            $failures += "Local override layer must not be tracked: $($layer.id)"
        }
    }
}

$validationReport = [pscustomobject]@{
    reportType = "effective-configuration-validation"
    stackName = $StackName
    includeLocal = [bool]$IncludeLocal
    failedCount = $failures.Count
    failures = $failures
    effectiveConfiguration = $report
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

    $validationReport | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host ("[ERROR] {0}" -f $failure) -ForegroundColor Red
    }
    exit 1
}

Write-Host ("Effective configuration validation passed: {0}; failedCount=0." -f $StackName) -ForegroundColor Green
