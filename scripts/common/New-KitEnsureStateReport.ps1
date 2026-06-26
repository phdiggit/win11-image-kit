#Requires -Version 5.1

. "$PSScriptRoot\Test-KitEnsureState.ps1"

function New-KitEnsureStateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Plan,

        [AllowNull()]
        $Results,

        [switch]$WhatIf
    )

    if ($null -eq $Results) {
        $Results = Test-KitEnsureState -Plan $Plan -WhatIf:$WhatIf
    }

    $failedCount = @($Results | Where-Object { $_.status -eq "failed" }).Count
    $manualCount = @($Results | Where-Object { $_.status -eq "manual" }).Count
    $passedCount = @($Results | Where-Object { $_.status -eq "passed" }).Count
    $status = "passed"
    if ($failedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    }

    [pscustomobject][ordered]@{
        reportType = "ensure-state"
        generatedAt = (Get-Date).ToString("s")
        status = $status
        summary = [pscustomobject]@{
            total = @($Results).Count
            softwareCount = @($Plan.software).Count
            serviceCount = @($Plan.services).Count
            passedCount = $passedCount
            manualCount = $manualCount
            failedCount = $failedCount
            plannedActionCount = @($Plan.actions).Count
        }
        results = @($Results)
        plannedActions = @($Plan.actions)
        whatIf = [bool]$WhatIf
    }
}
