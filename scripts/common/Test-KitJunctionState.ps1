#Requires -Version 5.1

. "$PSScriptRoot\New-StepResult.ps1"

function Get-KitJunctionConfigProperty {
    param(
        [AllowNull()]
        $JunctionConfig,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $JunctionConfig) {
        return $DefaultValue
    }

    if ($JunctionConfig -is [System.Collections.IDictionary] -and $JunctionConfig.Contains($Name)) {
        return $JunctionConfig[$Name]
    }

    if ($null -ne $JunctionConfig.PSObject -and $null -ne $JunctionConfig.PSObject.Properties[$Name]) {
        return $JunctionConfig.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function Get-KitJunctionName {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig
    )

    foreach ($propertyName in @("name", "description", "source", "path")) {
        $value = [string](Get-KitJunctionConfigProperty -JunctionConfig $JunctionConfig -Name $propertyName -DefaultValue "")
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    throw "Junction entry is missing name/description/source/path"
}

function Get-KitJunctionPath {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig
    )

    foreach ($propertyName in @("junctionPath", "path", "source")) {
        $value = [string](Get-KitJunctionConfigProperty -JunctionConfig $JunctionConfig -Name $propertyName -DefaultValue "")
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    throw "Junction entry is missing source/path"
}

function Get-KitJunctionExpectedTarget {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig
    )

    foreach ($propertyName in @("expectedTarget", "target", "destination")) {
        $value = [string](Get-KitJunctionConfigProperty -JunctionConfig $JunctionConfig -Name $propertyName -DefaultValue "")
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    throw "Junction entry is missing target/expectedTarget"
}

function Get-KitJunctionRequired {
    param(
        [AllowNull()]
        $JunctionConfig
    )

    $required = Get-KitJunctionConfigProperty -JunctionConfig $JunctionConfig -Name "required" -DefaultValue $true
    return [bool]$required
}

function Get-KitJunctionFailurePolicy {
    param(
        [AllowNull()]
        $JunctionConfig
    )

    $policy = [string](Get-KitJunctionConfigProperty -JunctionConfig $JunctionConfig -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($policy)) {
        return "fail"
    }

    return $policy.ToLowerInvariant()
}

function Resolve-KitJunctionFailureStatus {
    param(
        [bool]$Required,

        [string]$FailurePolicy
    )

    if ($Required) {
        return "failed"
    }

    switch ($FailurePolicy) {
        "skip" { return "skipped" }
        "manual" { return "manual" }
        default { return "failed" }
    }
}

function ConvertTo-KitJunctionTargetText {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ""
    }

    if ($Value -is [System.Array]) {
        return [string](@($Value) -join ";")
    }

    return [string]$Value
}

function Normalize-KitJunctionTarget {
    param(
        [AllowNull()]
        $Value
    )

    $text = (ConvertTo-KitJunctionTargetText -Value $Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    $trimChars = @([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    return $text.TrimEnd($trimChars)
}

function Test-KitJunctionTargetMatch {
    param(
        [AllowNull()]
        $ActualTarget,

        [AllowNull()]
        $ExpectedTarget
    )

    $actual = Normalize-KitJunctionTarget -Value $ActualTarget
    $expected = Normalize-KitJunctionTarget -Value $ExpectedTarget
    return [string]::Equals($actual, $expected, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-KitDefaultJunctionState {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Exists = $false
            IsJunction = $false
            Target = ""
            LinkType = ""
            Attributes = ""
        }
    }

    $item = Get-Item -LiteralPath $Path -Force
    $attributes = $item.Attributes
    $isReparsePoint = (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    $linkType = [string](Get-KitJunctionConfigProperty -JunctionConfig $item -Name "LinkType" -DefaultValue "")
    $target = ConvertTo-KitJunctionTargetText -Value (Get-KitJunctionConfigProperty -JunctionConfig $item -Name "Target" -DefaultValue "")
    $isJunction = $linkType -eq "Junction"
    if (-not $isJunction -and [string]::IsNullOrWhiteSpace($linkType) -and $isReparsePoint -and -not [string]::IsNullOrWhiteSpace($target)) {
        $isJunction = $true
    }

    [pscustomobject]@{
        Exists = $true
        IsJunction = [bool]$isJunction
        Target = $target
        LinkType = $linkType
        Attributes = [string]$attributes
    }
}

function New-KitJunctionStateResult {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [AllowEmptyString()]
        [string]$Reason,

        [AllowEmptyString()]
        [string]$Message,

        [bool]$Exists = $false,

        [bool]$IsJunction = $false,

        [AllowEmptyString()]
        [string]$ActualTarget = "",

        [AllowEmptyString()]
        [string]$LinkType = "",

        [AllowEmptyString()]
        [string]$Attributes = "",

        [AllowNull()]
        $Evidence = $null,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date),

        [datetime]$EndedAt = (Get-Date)
    )

    $name = Get-KitJunctionName -JunctionConfig $JunctionConfig
    $junctionPath = Get-KitJunctionPath -JunctionConfig $JunctionConfig
    $expectedTarget = Get-KitJunctionExpectedTarget -JunctionConfig $JunctionConfig
    $required = Get-KitJunctionRequired -JunctionConfig $JunctionConfig
    $failurePolicy = Get-KitJunctionFailurePolicy -JunctionConfig $JunctionConfig
    $skippedReason = ""
    $manualAction = ""

    if ($Status -eq "skipped") {
        $skippedReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "junction-verification-skipped" } else { $Reason }
    } elseif ($Status -eq "manual") {
        $manualAction = if ([string]::IsNullOrWhiteSpace($Reason)) { "inspect-junction-state" } else { $Reason }
    }

    $stepArgs = @{
        Name = $name
        Required = $required
        Status = $Status
        Message = $Message
        Reason = $Reason
        Data = [pscustomobject]@{
            junctionPath = $junctionPath
            expectedTarget = $expectedTarget
            actualTarget = $ActualTarget
            exists = [bool]$Exists
            isJunction = [bool]$IsJunction
            linkType = $LinkType
            attributes = $Attributes
            failurePolicy = $failurePolicy
        }
        Evidence = $Evidence
        Warnings = $Warnings
        Errors = $Errors
        SkippedReason = $skippedReason
        ManualAction = $manualAction
        WhatIfResult = ($Status -eq "whatif")
        StartedAt = $StartedAt
        EndedAt = $EndedAt
    }
    $stepResult = New-KitStepResult @stepArgs

    [pscustomobject][ordered]@{
        name = $stepResult.name
        junctionPath = $junctionPath
        expectedTarget = $expectedTarget
        actualTarget = $ActualTarget
        exists = [bool]$Exists
        isJunction = [bool]$IsJunction
        linkType = $LinkType
        attributes = $Attributes
        required = $stepResult.required
        status = $stepResult.status
        changed = $stepResult.changed
        reason = $stepResult.reason
        message = $stepResult.message
        failurePolicy = $failurePolicy
        evidence = $stepResult.evidence
        warnings = $stepResult.warnings
        errors = $stepResult.errors
        skippedReason = $stepResult.skippedReason
        manualAction = $stepResult.manualAction
        whatIf = $stepResult.whatIf
        startedAt = $stepResult.startedAt
        endedAt = $stepResult.endedAt
    }
}

function New-KitJunctionVerificationResult {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$Message,

        [bool]$Exists = $false,

        [bool]$IsJunction = $false,

        [AllowEmptyString()]
        [string]$ActualTarget = "",

        [AllowEmptyString()]
        [string]$LinkType = "",

        [AllowEmptyString()]
        [string]$Attributes = "",

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date)
    )

    New-KitJunctionStateResult -JunctionConfig $JunctionConfig -Status $Status -Reason $Reason -Message $Message -Exists:$Exists -IsJunction:$IsJunction -ActualTarget $ActualTarget -LinkType $LinkType -Attributes $Attributes -Errors $Errors -StartedAt $StartedAt -EndedAt (Get-Date)
}

function Test-KitJunctionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [scriptblock]$JunctionQuery = $null,

        [switch]$WhatIf
    )

    $startedAt = Get-Date
    $junctionPath = Get-KitJunctionPath -JunctionConfig $JunctionConfig
    $expectedTarget = Get-KitJunctionExpectedTarget -JunctionConfig $JunctionConfig

    if ($WhatIf) {
        return New-KitJunctionVerificationResult -JunctionConfig $JunctionConfig -Status "whatif" -Reason "whatif-preview" -Message "WhatIf preview did not query junction state" -StartedAt $startedAt
    }

    $required = Get-KitJunctionRequired -JunctionConfig $JunctionConfig
    $failurePolicy = Get-KitJunctionFailurePolicy -JunctionConfig $JunctionConfig
    $query = $JunctionQuery
    if ($null -eq $query) {
        $query = {
            param(
                [string]$Path,
                [AllowNull()]
                $JunctionConfig
            )

            Get-KitDefaultJunctionState -Path $Path
        }
    }

    try {
        $junctionState = & $query -Path $junctionPath -JunctionConfig $JunctionConfig
    } catch {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitJunctionVerificationResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-query-failed" -Message "Junction state query failed" -Errors @($_.Exception.Message) -StartedAt $startedAt
    }

    $exists = [bool](Get-KitJunctionConfigProperty -JunctionConfig $junctionState -Name "Exists" -DefaultValue $false)
    $isJunction = [bool](Get-KitJunctionConfigProperty -JunctionConfig $junctionState -Name "IsJunction" -DefaultValue $false)
    $actualTarget = ConvertTo-KitJunctionTargetText -Value (Get-KitJunctionConfigProperty -JunctionConfig $junctionState -Name "Target" -DefaultValue "")
    $linkType = [string](Get-KitJunctionConfigProperty -JunctionConfig $junctionState -Name "LinkType" -DefaultValue "")
    $attributes = [string](Get-KitJunctionConfigProperty -JunctionConfig $junctionState -Name "Attributes" -DefaultValue "")

    if (-not $exists) {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitJunctionVerificationResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-missing" -Message "Junction path does not exist" -Exists:$exists -IsJunction:$isJunction -ActualTarget $actualTarget -LinkType $linkType -Attributes $attributes -Errors @("junction path not found: $junctionPath") -StartedAt $startedAt
    }

    if (-not $isJunction) {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitJunctionVerificationResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-not-junction" -Message "Path exists but is not a junction" -Exists:$exists -IsJunction:$isJunction -ActualTarget $actualTarget -LinkType $linkType -Attributes $attributes -Errors @("path is not junction: $junctionPath") -StartedAt $startedAt
    }

    if (-not (Test-KitJunctionTargetMatch -ActualTarget $actualTarget -ExpectedTarget $expectedTarget)) {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitJunctionVerificationResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-target-mismatch" -Message "Junction target does not match expected target" -Exists:$exists -IsJunction:$isJunction -ActualTarget $actualTarget -LinkType $linkType -Attributes $attributes -Errors @("expectedTarget=$expectedTarget actualTarget=$actualTarget") -StartedAt $startedAt
    }

    New-KitJunctionVerificationResult -JunctionConfig $JunctionConfig -Status "unchanged" -Reason "junction-state-ok" -Message "Junction state matches expected target" -Exists:$exists -IsJunction:$isJunction -ActualTarget $actualTarget -LinkType $linkType -Attributes $attributes -StartedAt $startedAt
}

function Get-KitJunctionResultSummary {
    param(
        [AllowNull()]
        $Results = @()
    )

    $junctionResults = @(ConvertTo-KitStepResultArray -Value $Results)
    $stepSummary = Get-KitStepResultSummary -Results $junctionResults
    $junctionMissingCount = @($junctionResults | Where-Object { $_.reason -eq "junction-missing" }).Count
    $junctionNotJunctionCount = @($junctionResults | Where-Object { $_.reason -eq "junction-not-junction" }).Count
    $junctionTargetMismatchCount = @($junctionResults | Where-Object { $_.reason -eq "junction-target-mismatch" }).Count
    $junctionNotRunCount = @($junctionResults | Where-Object { $_.status -eq "whatif" -or $_.reason -eq "junction-verification-not-run" }).Count
    $junctionCheckedCount = $junctionResults.Count - $junctionNotRunCount

    [pscustomobject]@{
        total = $stepSummary.total
        statusCounts = $stepSummary.statusCounts
        failedRequiredCount = $stepSummary.failedRequiredCount
        failedOptionalCount = $stepSummary.failedOptionalCount
        hasBlockingFailure = $stepSummary.hasBlockingFailure
        exitCode = $stepSummary.exitCode
        junctionCheckedCount = $junctionCheckedCount
        junctionMissingCount = $junctionMissingCount
        junctionNotJunctionCount = $junctionNotJunctionCount
        junctionTargetMismatchCount = $junctionTargetMismatchCount
        junctionNotRunCount = $junctionNotRunCount
    }
}

function New-KitJunctionStateReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $junctionResults = @(ConvertTo-KitStepResultArray -Value $Results)
    [pscustomobject]@{
        reportType = "junction-state-verification"
        generatedAt = (Get-Date).ToString('s')
        junctionSummary = Get-KitJunctionResultSummary -Results $junctionResults
        junctionResults = $junctionResults
    }
}
