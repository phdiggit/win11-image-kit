. "$PSScriptRoot\Test-KitBuildLock.ps1"

function New-KitBuildLockReport {
    param(
        [Parameter(Mandatory)]
        $BuildLock,

        [string]$RepoRoot,

        [switch]$AuditOnly,

        [switch]$WhatIf
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $entryResults = @(Test-KitBuildLock -BuildLock $BuildLock -RepoRoot $RepoRoot -AuditOnly:$AuditOnly)
    $failedCount = @($entryResults | Where-Object { $_.status -eq "failed" }).Count
    $manualCount = @($entryResults | Where-Object { $_.status -eq "manual" }).Count
    $passedCount = @($entryResults | Where-Object { $_.status -eq "passed" }).Count
    $missingCount = @($entryResults | Where-Object { -not $_.exists }).Count
    $mismatchCount = @($entryResults | Where-Object {
        $_.exists -and
        -not [string]::IsNullOrWhiteSpace([string]$_.expectedHash) -and
        -not [string]::IsNullOrWhiteSpace([string]$_.actualHash) -and
        ([string]$_.expectedHash).ToLowerInvariant() -ne ([string]$_.actualHash).ToLowerInvariant()
    }).Count
    $untracked = @($entryResults | Where-Object { $_.category -eq "untracked" })

    $status = "passed"
    if ($failedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    }

    [pscustomobject]@{
        reportType = "build-lock"
        generatedAt = (Get-Date).ToString("s")
        status = $status
        summary = [pscustomobject]@{
            total = @($entryResults).Count
            passedCount = $passedCount
            manualCount = $manualCount
            failedCount = $failedCount
            missingCount = $missingCount
            mismatchCount = $mismatchCount
            untrackedWatchedCount = @($untracked).Count
        }
        entries = @($entryResults)
        untrackedWatchedFiles = @($untracked | ForEach-Object { $_.path })
        algorithm = [string]$BuildLock.algorithm
        mode = [string]$BuildLock.mode
        whatIf = [bool]$WhatIf
    }
}
