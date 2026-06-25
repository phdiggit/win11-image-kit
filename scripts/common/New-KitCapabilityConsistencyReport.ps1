. "$PSScriptRoot\Get-KitCapabilityRegistry.ps1"
. "$PSScriptRoot\Test-KitCapabilityConsistency.ps1"

function New-KitCapabilityConsistencyReport {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [string]$RepoRoot,

        [switch]$Strict,

        [switch]$WhatIf
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $capabilityResults = @(Test-KitCapabilityConsistency -Registry $Registry -RepoRoot $RepoRoot -Strict:$Strict)
    $orphanManifests = @(Get-KitCapabilityOrphanManifests -RepoRoot $RepoRoot -Registry $Registry)
    $failedCount = @($capabilityResults | Where-Object { $_.status -eq "failed" }).Count
    $manualCount = @($capabilityResults | Where-Object { $_.status -eq "manual" }).Count
    $passedCount = @($capabilityResults | Where-Object { $_.status -eq "passed" }).Count
    $warningCount = 0
    foreach ($result in $capabilityResults) {
        $warningCount += @($result.warnings).Count
    }
    $warningCount += $orphanManifests.Count

    $status = "passed"
    if ($failedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    }

    [pscustomobject]@{
        reportType = "capability-consistency"
        generatedAt = (Get-Date).ToString("s")
        status = $status
        summary = [pscustomobject]@{
            total = @($capabilityResults).Count
            passedCount = $passedCount
            manualCount = $manualCount
            failedCount = $failedCount
            warningCount = $warningCount
            orphanManifestCount = $orphanManifests.Count
        }
        capabilities = @($capabilityResults)
        orphanManifests = @($orphanManifests)
        whatIf = [bool]$WhatIf
    }
}
