[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "manifests/context-scope.json",
    [string]$SchemaPath = "schemas/context-scope.schema.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitContextPlan.ps1"
. "$PSScriptRoot\..\common\Test-KitContextSafety.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Resolve-KitContextRepoPath {
    param([string]$Path)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $repoRoot -ChildPath $Path))
}

function Read-KitContextJson {
    param([string]$Path)

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-KitContextManifestShape {
    param($Manifest)

    $errors = @()
    $allowedTop = @('$schema', 'defaultMode', 'allowedContexts', 'phasePolicy', 'targets')
    $requiredTop = @('defaultMode', 'allowedContexts', 'phasePolicy', 'targets')
    $allowedContexts = @('machine', 'default-user', 'current-user')
    $allowedPhases = @('build', 'postdeploy', 'interactive', 'validate')
    $allowedTargetTypes = @('registry', 'file', 'profile', 'scheduled-task', 'service', 'capability', 'appx', 'unknown')
    $allowedPolicies = @('planned', 'manual', 'blocked')
    $allowedRoots = @('HKLM', 'HKU_DEFAULT', 'HKCU')

    foreach ($property in $Manifest.PSObject.Properties.Name) {
        if ($allowedTop -notcontains $property) {
            $errors += "unknown top-level field: $property"
        }
    }

    foreach ($property in $requiredTop) {
        if ($Manifest.PSObject.Properties.Name -notcontains $property) {
            $errors += "missing top-level field: $property"
        }
    }

    foreach ($context in @($Manifest.allowedContexts)) {
        if ($allowedContexts -notcontains [string]$context) {
            $errors += "invalid allowedContexts value: $context"
        }
    }

    foreach ($phase in $Manifest.phasePolicy.PSObject.Properties) {
        if ($allowedPhases -notcontains $phase.Name) {
            $errors += "invalid phasePolicy key: $($phase.Name)"
        }

        foreach ($context in @($phase.Value)) {
            if ($allowedContexts -notcontains [string]$context) {
                $errors += "invalid phasePolicy context: $($phase.Name) -> $context"
            }
        }
    }

    foreach ($target in @($Manifest.targets)) {
        foreach ($field in @('id', 'context', 'targetType', 'phase', 'mutationPolicy', 'reason')) {
            if ($target.PSObject.Properties.Name -notcontains $field -or [string]::IsNullOrWhiteSpace([string]$target.$field)) {
                $errors += "target missing field: $field"
            }
        }

        foreach ($property in $target.PSObject.Properties.Name) {
            if (@('id', 'context', 'targetType', 'phase', 'mutationPolicy', 'reason', 'root', 'path', 'marker') -notcontains $property) {
                $errors += "target has unknown field: $property"
            }
        }

        if ($allowedContexts -notcontains [string]$target.context) {
            $errors += "invalid target context: $($target.context)"
        }

        if ($allowedPhases -notcontains [string]$target.phase) {
            $errors += "invalid target phase: $($target.phase)"
        }

        if ($allowedTargetTypes -notcontains [string]$target.targetType) {
            $errors += "invalid targetType: $($target.targetType)"
        }

        if ($allowedPolicies -notcontains [string]$target.mutationPolicy) {
            $errors += "invalid mutationPolicy: $($target.mutationPolicy)"
        }

        if ([string]$target.targetType -eq 'registry') {
            if ($target.PSObject.Properties.Name -notcontains 'root') {
                $errors += "registry target missing root: $($target.id)"
            } elseif ($allowedRoots -notcontains [string]$target.root) {
                $errors += "invalid registry root: $($target.root)"
            }
        }
    }

    return $errors
}

$resolvedManifestPath = Resolve-KitContextRepoPath -Path $ManifestPath
$resolvedSchemaPath = Resolve-KitContextRepoPath -Path $SchemaPath

if (-not (Test-Path -LiteralPath $resolvedManifestPath)) {
    throw "context scope manifest not found: $ManifestPath"
}

if (-not (Test-Path -LiteralPath $resolvedSchemaPath)) {
    throw "context scope schema not found: $SchemaPath"
}

$manifest = Read-KitContextJson -Path $resolvedManifestPath
$schema = Read-KitContextJson -Path $resolvedSchemaPath
$schemaErrors = @(Test-KitContextManifestShape -Manifest $manifest)
$plan = New-KitContextPlan -Targets $manifest.targets -ScopeConfig $manifest -WhatIf:$WhatIfPreference
$safety = Test-KitContextSafety -InputObject $plan -ValidateMode

if ($schemaErrors.Count -gt 0) {
    $plan.status = "failed"
    $plan.summary.blockedCount = [int]$plan.summary.blockedCount + $schemaErrors.Count
    $plan | Add-Member -NotePropertyName schemaErrors -NotePropertyValue @($schemaErrors) -Force
} else {
    $plan | Add-Member -NotePropertyName schemaTitle -NotePropertyValue $schema.title -Force
}

$plan.items = @($safety.items)
if ($safety.status -eq "failed") {
    $plan.status = "failed"
    $plan.summary.blockedCount = @($safety.items | Where-Object { $_.status -eq "blocked" }).Count
} elseif ($plan.status -ne "failed" -and $safety.status -eq "manual") {
    $plan.status = "manual"
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitContextRepoPath -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force -WhatIf:$false | Out-Null
    }

    $plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8 -WhatIf:$false
    Write-Host "Context scope report written: $resolvedReportPath"
}

$plan

if ($plan.status -eq "failed") {
    exit 1
}
