#Requires -Version 5.1

. "$PSScriptRoot\Get-KitDefenderExclusionState.ps1"
. "$PSScriptRoot\New-StepResult.ps1"

function Invoke-KitDefaultDefenderExclusionMutation {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("path", "process")]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Value
    )

    if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
        throw "Add-MpPreference is not available on this system."
    }

    if ($Type -eq "path") {
        Add-MpPreference -ExclusionPath $Value -ErrorAction Stop
        return
    }

    Add-MpPreference -ExclusionProcess $Value -ErrorAction Stop
}

function Resolve-KitDefenderExclusionFailureStatus {
    param(
        [bool]$Required,

        [string]$FailurePolicy
    )

    if ($Required -and $FailurePolicy -eq "fail") {
        return "failed"
    }

    switch ($FailurePolicy) {
        "skip" { return "skipped" }
        "manual" { return "manual" }
        default { return "failed" }
    }
}

function New-KitDefenderExclusionResult {
    param(
        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [AllowEmptyString()]
        [string]$Action,

        [AllowEmptyString()]
        [string]$Reason,

        [bool]$ExistsBefore = $false,

        [bool]$ExistsAfter = $false,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [AllowEmptyString()]
        [string]$ManualAction
    )

    $stepResult = New-KitStepResult `
        -Name ("Defender exclusion: {0}" -f $Policy.id) `
        -Required ([bool]$Policy.required) `
        -Status $Status `
        -Reason $Reason `
        -Data ([pscustomobject]@{
            id = $Policy.id
            type = $Policy.type
            value = $Policy.value
            resolvedValue = $Policy.resolvedValue
            scope = $Policy.scope
            policyStatus = $Policy.policyStatus
            policyReason = $Policy.policyReason
            action = $Action
            existsBefore = [bool]$ExistsBefore
            existsAfter = [bool]$ExistsAfter
        }) `
        -Warnings $Warnings `
        -Errors $Errors `
        -ManualAction $ManualAction `
        -WhatIfResult ($Status -eq "whatif")

    [pscustomobject][ordered]@{
        id = $Policy.id
        type = $Policy.type
        value = $Policy.value
        resolvedValue = $Policy.resolvedValue
        scope = $Policy.scope
        reason = $Policy.reason
        policyStatus = $Policy.policyStatus
        policyReason = $Policy.policyReason
        existsBefore = [bool]$ExistsBefore
        existsAfter = [bool]$ExistsAfter
        action = $Action
        required = [bool]$Policy.required
        failurePolicy = $Policy.failurePolicy
        status = $stepResult.status
        changed = $stepResult.changed
        whatIf = $stepResult.whatIf
        warnings = $stepResult.warnings
        errors = $stepResult.errors
        manualAction = $stepResult.manualAction
        startedAt = $stepResult.startedAt
        endedAt = $stepResult.endedAt
    }
}

function Set-KitDefenderExclusionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Exclusions,

        [hashtable]$PathMap = @{},

        [AllowEmptyString()]
        [string]$RepoRoot,

        [scriptblock]$DefenderQuery = $null,

        [scriptblock]$DefenderMutation = $null,

        [switch]$WhatIf
    )

    $query = $DefenderQuery
    if ($null -eq $query) {
        $query = {
            Get-KitDefaultDefenderExclusionPreference
        }
    }

    $mutation = $DefenderMutation
    if ($null -eq $mutation) {
        $mutation = {
            param([string]$Type, [string]$Value)
            Invoke-KitDefaultDefenderExclusionMutation -Type $Type -Value $Value
        }
    }

    $results = @()
    foreach ($item in @(ConvertTo-KitDefenderExclusionArray -Value $Exclusions)) {
        $policy = Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $PathMap -RepoRoot $RepoRoot
        if (-not [bool]$policy.enabled) {
            $results += New-KitDefenderExclusionResult -Policy $policy -Status "skipped" -Action "skipped" -Reason "disabled"
            continue
        }

        if ($policy.policyStatus -ne "allowed") {
            $status = Resolve-KitDefenderExclusionFailureStatus -Required ([bool]$policy.required) -FailurePolicy $policy.failurePolicy
            if ($policy.policyStatus -eq "manual" -and $status -eq "failed") {
                $status = "manual"
            }

            $action = if ($policy.policyStatus -eq "manual") { "manual" } else { "blocked" }
            $manualAction = $policy.manualAction
            if ([string]::IsNullOrWhiteSpace($manualAction) -and $status -eq "manual") {
                $manualAction = "Review Defender exclusion policy result before applying manually."
            }

            $results += New-KitDefenderExclusionResult `
                -Policy $policy `
                -Status $status `
                -Action $action `
                -Reason $policy.policyReason `
                -Warnings $policy.warnings `
                -Errors $policy.errors `
                -ManualAction $manualAction
            continue
        }

        if ($WhatIf) {
            $results += New-KitDefenderExclusionResult -Policy $policy -Status "whatif" -Action "would-add" -Reason "whatif-preview" -ExistsBefore $false -ExistsAfter $false
            continue
        }

        $preferenceBefore = $null
        try {
            $preferenceBefore = & $query
        } catch {
            $status = Resolve-KitDefenderExclusionFailureStatus -Required ([bool]$policy.required) -FailurePolicy $policy.failurePolicy
            $results += New-KitDefenderExclusionResult -Policy $policy -Status $status -Action "query-failed" -Reason "defender-query-failed" -Errors @($_.Exception.Message)
            continue
        }

        $existsBefore = Test-KitDefenderExclusionExistsInPreference -Preference $preferenceBefore -Type $policy.type -ResolvedValue $policy.resolvedValue
        if ($existsBefore) {
            $results += New-KitDefenderExclusionResult -Policy $policy -Status "unchanged" -Action "unchanged" -Reason "already-present" -ExistsBefore $true -ExistsAfter $true
            continue
        }

        try {
            & $mutation $policy.type $policy.resolvedValue
        } catch {
            $status = Resolve-KitDefenderExclusionFailureStatus -Required ([bool]$policy.required) -FailurePolicy $policy.failurePolicy
            $results += New-KitDefenderExclusionResult -Policy $policy -Status $status -Action "add-failed" -Reason "defender-add-failed" -ExistsBefore $false -ExistsAfter $false -Errors @($_.Exception.Message)
            continue
        }

        $existsAfter = $false
        try {
            $preferenceAfter = & $query
            $existsAfter = Test-KitDefenderExclusionExistsInPreference -Preference $preferenceAfter -Type $policy.type -ResolvedValue $policy.resolvedValue
        } catch {
            $status = Resolve-KitDefenderExclusionFailureStatus -Required ([bool]$policy.required) -FailurePolicy $policy.failurePolicy
            $results += New-KitDefenderExclusionResult -Policy $policy -Status $status -Action "verify-failed" -Reason "defender-verify-failed" -ExistsBefore $false -ExistsAfter $false -Errors @($_.Exception.Message)
            continue
        }

        if ($existsAfter) {
            $results += New-KitDefenderExclusionResult -Policy $policy -Status "changed" -Action "added" -Reason "added-and-verified" -ExistsBefore $false -ExistsAfter $true
        } else {
            $status = Resolve-KitDefenderExclusionFailureStatus -Required ([bool]$policy.required) -FailurePolicy $policy.failurePolicy
            $results += New-KitDefenderExclusionResult -Policy $policy -Status $status -Action "verify-failed" -Reason "defender-exclusion-still-missing" -ExistsBefore $false -ExistsAfter $false -Errors @("exclusion not present after Add-MpPreference")
        }
    }

    return $results
}

function Get-KitDefenderExclusionResultSummary {
    param(
        [AllowNull()]
        $Results = @(),

        [AllowNull()]
        $StateResults = @()
    )

    $allResults = @()
    $allResults += @(ConvertTo-KitDefenderExclusionArray -Value $Results)
    $allResults += @(ConvertTo-KitDefenderExclusionArray -Value $StateResults)

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
    $blockedByPolicyCount = 0

    foreach ($result in $allResults) {
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

        if ($result.PSObject.Properties.Name -contains "policyStatus" -and [string]$result.policyStatus -in @("blocked", "manual")) {
            $blockedByPolicyCount++
        }
    }

    [pscustomobject][ordered]@{
        total = $allResults.Count
        statusCounts = [pscustomobject]$statusCounts
        changedCount = $statusCounts.changed
        unchangedCount = $statusCounts.unchanged
        failedCount = $statusCounts.failed
        manualCount = $statusCounts.manual
        skippedCount = $statusCounts.skipped
        whatIfCount = $statusCounts.whatif
        blockedByPolicyCount = $blockedByPolicyCount
        failedRequiredCount = $failedRequiredCount
        failedOptionalCount = $failedOptionalCount
        hasBlockingFailure = ($failedRequiredCount -gt 0)
        exitCode = if ($failedRequiredCount -gt 0) { 1 } else { 0 }
        defenderCheckedCount = ($statusCounts.changed + $statusCounts.unchanged + $statusCounts.failed)
        defenderMismatchCount = 0
        defenderSettingMissingCount = 0
        defenderQueryFailedCount = @($allResults | Where-Object { [string]$_.action -eq "query-failed" -or [string]$_.reason -eq "defender-query-failed" }).Count
        defenderNotRunCount = ($statusCounts.whatif + $statusCounts.skipped + $statusCounts.manual)
    }
}

function New-KitDefenderExclusionReport {
    param(
        [AllowNull()]
        $Results = @(),

        [AllowNull()]
        $StateResults = @(),

        [switch]$WhatIf
    )

    $exclusionResults = @(ConvertTo-KitDefenderExclusionArray -Value $Results)
    $stateCheckResults = @(ConvertTo-KitDefenderExclusionArray -Value $StateResults)
    [pscustomobject][ordered]@{
        reportType = "defender-exclusion-policy"
        generatedAt = (Get-Date).ToString("s")
        whatIf = [bool]$WhatIf
        defenderSummary = Get-KitDefenderExclusionResultSummary -Results $exclusionResults -StateResults $stateCheckResults
        defenderResults = $exclusionResults
        defenderStateResults = $stateCheckResults
    }
}
