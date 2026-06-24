function ConvertTo-KitStepResultArray {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array] -or $Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value)
    }

    return @($Value)
}

function ConvertTo-KitStepResultTimestamp {
    param(
        [Parameter(Mandatory)]
        [datetime]$Value
    )

    return $Value.ToUniversalTime().ToString("o")
}

function New-KitStepResult {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [bool]$Required = $true,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [bool]$Changed = $false,

        [AllowEmptyString()]
        [string]$Message,

        [AllowEmptyString()]
        [string]$Reason,

        [AllowNull()]
        $Data = $null,

        [AllowNull()]
        $Evidence = $null,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [AllowEmptyString()]
        [string]$SkippedReason,

        [AllowEmptyString()]
        [string]$ManualAction,

        [bool]$WhatIfResult = $false,

        [bool]$RebootRequired = $false,

        [datetime]$StartedAt = (Get-Date),

        [datetime]$EndedAt = (Get-Date)
    )

    if ($EndedAt -lt $StartedAt) {
        throw "endedAt cannot be earlier than startedAt: $Name"
    }

    $effectiveChanged = if ($PSBoundParameters.ContainsKey("Changed")) {
        [bool]$Changed
    } else {
        $Status -eq "changed"
    }

    $effectiveWhatIf = [bool]$WhatIfResult
    if ($Status -eq "whatif") {
        $effectiveWhatIf = $true
        $effectiveChanged = $false
    }

    [pscustomobject]@{
        name = $Name
        required = [bool]$Required
        status = $Status
        changed = [bool]$effectiveChanged
        message = $Message
        reason = $Reason
        data = $Data
        evidence = $Evidence
        warnings = @(ConvertTo-KitStepResultArray -Value $Warnings)
        errors = @(ConvertTo-KitStepResultArray -Value $Errors)
        skippedReason = $SkippedReason
        manualAction = $ManualAction
        whatIf = [bool]$effectiveWhatIf
        rebootRequired = [bool]$RebootRequired
        startedAt = ConvertTo-KitStepResultTimestamp -Value $StartedAt
        endedAt = ConvertTo-KitStepResultTimestamp -Value $EndedAt
    }
}

function Get-KitStepResultSummary {
    param(
        [AllowNull()]
        $Results = @()
    )

    $resultList = @(ConvertTo-KitStepResultArray -Value $Results)
    $statusCounts = [ordered]@{
        changed = 0
        unchanged = 0
        skipped = 0
        manual = 0
        whatif = 0
        failed = 0
    }
    $failedRequiredCount = 0
    $failedOptionalCount = 0
    $rebootRequiredCount = 0

    foreach ($result in $resultList) {
        $status = [string]$result.status
        if ($statusCounts.Contains($status)) {
            $statusCounts[$status]++
        }

        if ($status -eq "failed") {
            if ([bool]$result.required) {
                $failedRequiredCount++
            } else {
                $failedOptionalCount++
            }
        }

        if ([bool]$result.rebootRequired) {
            $rebootRequiredCount++
        }
    }

    $hasBlockingFailure = $failedRequiredCount -gt 0

    [pscustomobject]@{
        total = $resultList.Count
        statusCounts = [pscustomobject]$statusCounts
        failedRequiredCount = $failedRequiredCount
        failedOptionalCount = $failedOptionalCount
        rebootRequiredCount = $rebootRequiredCount
        hasBlockingFailure = $hasBlockingFailure
        exitCode = if ($hasBlockingFailure) { 1 } else { 0 }
        results = $resultList
    }
}
