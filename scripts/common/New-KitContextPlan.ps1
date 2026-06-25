. "$PSScriptRoot\Resolve-KitContextScope.ps1"

function New-KitContextPlan {
    param(
        [Parameter(Mandatory)]
        $Targets,

        [AllowNull()]
        $ScopeConfig = $null,

        [switch]$WhatIf
    )

    $items = @()
    foreach ($target in @($Targets)) {
        $items += Resolve-KitContextScope -Target $target -ScopeConfig $ScopeConfig
    }

    $machineCount = @($items | Where-Object { $_.context -eq "machine" }).Count
    $defaultUserCount = @($items | Where-Object { $_.context -eq "default-user" }).Count
    $currentUserCount = @($items | Where-Object { $_.context -eq "current-user" }).Count
    $manualCount = @($items | Where-Object { $_.status -eq "manual" }).Count
    $blockedCount = @($items | Where-Object { $_.status -eq "blocked" }).Count
    $ambiguousCount = @($items | Where-Object { @($_.errors | Where-Object { [string]$_ -match "ambiguous" }).Count -gt 0 }).Count

    $status = "passed"
    if ($blockedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    }

    [pscustomobject]@{
        reportType = "context-scope-plan"
        generatedAt = (Get-Date).ToString("s")
        status = $status
        summary = [pscustomobject]@{
            total = @($items).Count
            machineCount = $machineCount
            defaultUserCount = $defaultUserCount
            currentUserCount = $currentUserCount
            manualCount = $manualCount
            blockedCount = $blockedCount
            ambiguousCount = $ambiguousCount
        }
        items = @($items)
        whatIf = [bool]$WhatIf
    }
}
