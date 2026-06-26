param(
    [string]$ConfigLayersPath = "manifests/config-layers.json",
    [string]$StackName = "default",
    [switch]$AllStacks,
    [switch]$IncludeLocal,
    [hashtable]$PathOverride,
    [string]$PathOverrideJson,
    [string]$RepoRoot,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitEffectiveConfiguration.ps1"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
}
$pathOverrideMap = @{}
if ($null -ne $PathOverride) {
    $pathOverrideMap = ConvertTo-KitHashtable -InputObject $PathOverride
}
if (-not [string]::IsNullOrWhiteSpace($PathOverrideJson)) {
    $pathOverrideMap = ConvertTo-KitHashtable -InputObject ($PathOverrideJson | ConvertFrom-Json)
}

$stackNames = if ($AllStacks) {
    Get-KitConfigurationStackNames -ConfigLayersPath $ConfigLayersPath -RepoRoot $RepoRoot
} else {
    @($StackName)
}

$reports = @()
$failures = @()

foreach ($name in @($stackNames)) {
    $report = Resolve-KitEffectiveConfiguration `
        -ConfigLayersPath $ConfigLayersPath `
        -StackName $name `
        -IncludeLocal:$IncludeLocal `
        -PathOverride $pathOverrideMap `
        -RepoRoot $RepoRoot
    $reports += $report

    foreach ($path in @($report.pathSources)) {
        if ($path.value -match '\$\{[^}]+\}') {
            $failures += "[$name] Unresolved path token: $($path.key) -> $($path.value)"
        }

        foreach ($pattern in @($report.safety.forbiddenPathPatterns)) {
            if ($path.value -match [string]$pattern) {
                $failures += "[$name] Path matched forbidden pattern: $($path.key) -> $($path.value)"
            }
        }
    }

    if ($report.safety.forbidTrackedLocalOverrides) {
        foreach ($layer in @($report.appliedLayers)) {
            if ($layer.kind -eq "local" -and $layer.tracked) {
                $failures += "[$name] Local override layer must not be tracked: $($layer.id)"
            }
        }
    }
}

$validationReport = [pscustomobject]@{
    reportType = "effective-configuration-validation"
    stackName = $(if ($AllStacks) { "all" } else { $StackName })
    stackNames = @($stackNames)
    includeLocal = [bool]$IncludeLocal
    allStacks = [bool]$AllStacks
    failedCount = $failures.Count
    failures = $failures
    effectiveConfigurations = $reports
    effectiveConfiguration = @($reports)[0]
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

Write-Host ("Effective configuration validation passed: {0}; failedCount=0." -f $validationReport.stackName) -ForegroundColor Green
