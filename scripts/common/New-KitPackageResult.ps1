#Requires -Version 5.1

. "$PSScriptRoot\New-StepResult.ps1"

function Get-KitPackageResultProperty {
    param(
        [AllowNull()]
        $Package,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Package -or $null -eq $Package.PSObject -or $null -eq $Package.PSObject.Properties[$Name]) {
        return ""
    }

    return [string]$Package.PSObject.Properties[$Name].Value
}

function New-KitPackageResult {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [AllowEmptyString()]
        [string]$Reason,

        [AllowEmptyString()]
        [string]$Message,

        [AllowEmptyString()]
        [string]$Source,

        [AllowEmptyString()]
        [string]$Destination,

        [AllowNull()]
        $Policy,

        [AllowNull()]
        $Evidence,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [AllowEmptyString()]
        [string]$SkippedReason,

        [AllowEmptyString()]
        [string]$ManualAction,

        [bool]$Changed = $false,

        [bool]$WhatIfResult = $false,

        [bool]$RebootRequired = $false,

        [datetime]$StartedAt = (Get-Date),

        [datetime]$EndedAt = (Get-Date)
    )

    $packageName = Get-KitPackageResultProperty -Package $Package -Name "name"
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        throw "package result 缺少 package name"
    }

    $required = $true
    $failurePolicy = ""
    $allowMissingSource = $false

    if ($null -ne $Policy) {
        if ($null -ne $Policy.PSObject.Properties["required"]) {
            $required = [bool]$Policy.required
        }
        if ($null -ne $Policy.PSObject.Properties["failurePolicy"]) {
            $failurePolicy = [string]$Policy.failurePolicy
        }
        if ($null -ne $Policy.PSObject.Properties["allowMissingSource"]) {
            $allowMissingSource = [bool]$Policy.allowMissingSource
        }
    } elseif ($null -ne $Package.PSObject.Properties["required"]) {
        $required = [bool]$Package.required
    }

    if ([string]::IsNullOrWhiteSpace($Reason)) {
        if ($Status -eq "whatif") {
            $Reason = "whatif-preview"
        } elseif ($Status -eq "changed") {
            $Reason = "completed"
        }
    }

    if ($Status -eq "skipped" -and [string]::IsNullOrWhiteSpace($SkippedReason)) {
        $SkippedReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "skipped" } else { $Reason }
    }

    if ($Status -eq "manual" -and [string]::IsNullOrWhiteSpace($ManualAction)) {
        $ManualAction = if ([string]::IsNullOrWhiteSpace($Reason)) { "manual" } else { $Reason }
    }

    $stepArgs = @{
        Name = $packageName
        Required = [bool]$required
        Status = $Status
        Message = $Message
        Reason = $Reason
        Evidence = $Evidence
        Warnings = $Warnings
        Errors = $Errors
        SkippedReason = $SkippedReason
        ManualAction = $ManualAction
        RebootRequired = $RebootRequired
        StartedAt = $StartedAt
        EndedAt = $EndedAt
    }

    if ($PSBoundParameters.ContainsKey("Changed")) {
        $stepArgs["Changed"] = [bool]$Changed
    }

    if ($PSBoundParameters.ContainsKey("WhatIfResult")) {
        $stepArgs["WhatIfResult"] = [bool]$WhatIfResult
    }

    $stepResult = New-KitStepResult @stepArgs

    [pscustomobject][ordered]@{
        name = $stepResult.name
        required = $stepResult.required
        status = $stepResult.status
        changed = $stepResult.changed
        reason = $stepResult.reason
        message = $stepResult.message
        packageName = $packageName
        packageType = Get-KitPackageResultProperty -Package $Package -Name "type"
        stage = Get-KitPackageResultProperty -Package $Package -Name "stage"
        category = Get-KitPackageResultProperty -Package $Package -Name "category"
        source = $Source
        destination = $Destination
        failurePolicy = $failurePolicy
        allowMissingSource = [bool]$allowMissingSource
        evidence = $stepResult.evidence
        warnings = $stepResult.warnings
        errors = $stepResult.errors
        skippedReason = $stepResult.skippedReason
        manualAction = $stepResult.manualAction
        whatIf = $stepResult.whatIf
        rebootRequired = $stepResult.rebootRequired
        startedAt = $stepResult.startedAt
        endedAt = $stepResult.endedAt
    }
}
