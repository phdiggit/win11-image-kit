#Requires -Version 5.1

. "$PSScriptRoot\New-StepResult.ps1"

function Get-KitDefenderConfigProperty {
    param(
        [AllowNull()]
        $Config,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $Config) {
        return $DefaultValue
    }

    if ($Config -is [System.Collections.IDictionary] -and $Config.Contains($Name)) {
        return $Config[$Name]
    }

    if ($null -ne $Config.PSObject -and $null -ne $Config.PSObject.Properties[$Name]) {
        return $Config.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function ConvertTo-KitDefenderStateCheck {
    param(
        [Parameter(Mandatory)]
        $Config
    )

    if ($Config -is [System.Array]) {
        return @($Config)
    }

    if ($Config -is [System.Collections.IEnumerable] -and -not ($Config -is [string]) -and $null -eq $Config.PSObject.Properties["settingName"] -and $null -eq $Config.PSObject.Properties["expected"]) {
        return @($Config)
    }

    $settingName = [string](Get-KitDefenderConfigProperty -Config $Config -Name "settingName" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($settingName)) {
        return @($Config)
    }

    $expected = Get-KitDefenderConfigProperty -Config $Config -Name "expected" -DefaultValue $null
    if ($null -eq $expected) {
        return @()
    }

    $checks = @()
    foreach ($property in $expected.PSObject.Properties) {
        $name = [string](Get-KitDefenderConfigProperty -Config $Config -Name "name" -DefaultValue "")
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = "Defender_$($property.Name)"
        }

        $checks += [pscustomobject]@{
            name = $name
            settingName = $property.Name
            expectedValue = $property.Value
            required = [bool](Get-KitDefenderConfigProperty -Config $Config -Name "required" -DefaultValue $true)
            failurePolicy = [string](Get-KitDefenderConfigProperty -Config $Config -Name "failurePolicy" -DefaultValue "fail")
        }
    }

    return $checks
}

function Get-KitDefenderRequired {
    param(
        [AllowNull()]
        $Config
    )

    return [bool](Get-KitDefenderConfigProperty -Config $Config -Name "required" -DefaultValue $true)
}

function Get-KitDefenderFailurePolicy {
    param(
        [AllowNull()]
        $Config
    )

    $policy = [string](Get-KitDefenderConfigProperty -Config $Config -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($policy)) {
        return "fail"
    }

    return $policy.ToLowerInvariant()
}

function Resolve-KitDefenderFailureStatus {
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

function Test-KitDefenderValueEqual {
    param(
        [AllowNull()]
        $Actual,

        [AllowNull()]
        $Expected
    )

    if ($Actual -is [bool] -or $Expected -is [bool]) {
        return ([bool]$Actual) -eq ([bool]$Expected)
    }

    return [string]$Actual -eq [string]$Expected
}

function New-KitDefenderStateResult {
    param(
        [Parameter(Mandatory)]
        $Config,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [AllowEmptyString()]
        [string]$Reason,

        [AllowEmptyString()]
        [string]$Message,

        [AllowNull()]
        $ActualValue = $null,

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date),

        [datetime]$EndedAt = (Get-Date)
    )

    $settingName = [string](Get-KitDefenderConfigProperty -Config $Config -Name "settingName" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($settingName)) {
        throw "Defender 状态检查缺少 settingName"
    }

    $name = [string](Get-KitDefenderConfigProperty -Config $Config -Name "name" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = "Defender_$settingName"
    }

    $required = Get-KitDefenderRequired -Config $Config
    $failurePolicy = Get-KitDefenderFailurePolicy -Config $Config
    $expectedValue = Get-KitDefenderConfigProperty -Config $Config -Name "expectedValue" -DefaultValue $null
    $skippedReason = ""
    $manualAction = ""
    if ($Status -eq "skipped") {
        $skippedReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "defender-verification-skipped" } else { $Reason }
    } elseif ($Status -eq "manual") {
        $manualAction = if ([string]::IsNullOrWhiteSpace($Reason)) { "inspect-defender-state" } else { $Reason }
    }

    $stepArgs = @{
        Name = $name
        Required = $required
        Status = $Status
        Message = $Message
        Reason = $Reason
        Data = [pscustomobject]@{
            settingName = $settingName
            expectedValue = $expectedValue
            actualValue = $ActualValue
            failurePolicy = $failurePolicy
        }
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
        settingName = $settingName
        expectedValue = $expectedValue
        actualValue = $ActualValue
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

function Get-KitDefaultDefenderPreference {
    Get-MpPreference -ErrorAction Stop
}

function Test-KitDefenderState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [scriptblock]$DefenderQuery = $null,

        [switch]$WhatIf
    )

    $checks = @(ConvertTo-KitDefenderStateCheck -Config $Config)
    if ($checks.Count -eq 0) {
        return @()
    }

    $results = @()
    if ($WhatIf) {
        foreach ($check in $checks) {
            $results += New-KitDefenderStateResult -Config $check -Status "whatif" -Reason "whatif-preview" -Message "WhatIf 预演未执行 Defender 状态查询"
        }
        return $results
    }

    $query = $DefenderQuery
    if ($null -eq $query) {
        $query = {
            Get-KitDefaultDefenderPreference
        }
    }

    $startedAt = Get-Date
    try {
        $preference = & $query
    } catch {
        foreach ($check in $checks) {
            $required = Get-KitDefenderRequired -Config $check
            $failurePolicy = Get-KitDefenderFailurePolicy -Config $check
            $status = Resolve-KitDefenderFailureStatus -Required $required -FailurePolicy $failurePolicy
            $results += New-KitDefenderStateResult -Config $check -Status $status -Reason "defender-query-failed" -Message "Defender 状态查询失败" -Errors @($_.Exception.Message) -StartedAt $startedAt -EndedAt (Get-Date)
        }
        return $results
    }

    foreach ($check in $checks) {
        $settingName = [string](Get-KitDefenderConfigProperty -Config $check -Name "settingName" -DefaultValue "")
        $expectedValue = Get-KitDefenderConfigProperty -Config $check -Name "expectedValue" -DefaultValue $null
        $actualValue = Get-KitDefenderConfigProperty -Config $preference -Name $settingName -DefaultValue $null
        if (Test-KitDefenderValueEqual -Actual $actualValue -Expected $expectedValue) {
            $results += New-KitDefenderStateResult -Config $check -Status "unchanged" -Reason "defender-state-ok" -Message "Defender 状态符合预期" -ActualValue $actualValue -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        $required = Get-KitDefenderRequired -Config $check
        $failurePolicy = Get-KitDefenderFailurePolicy -Config $check
        $status = Resolve-KitDefenderFailureStatus -Required $required -FailurePolicy $failurePolicy
        $results += New-KitDefenderStateResult -Config $check -Status $status -Reason "defender-state-mismatch" -Message "Defender 状态不符合预期" -ActualValue $actualValue -Errors @("settingName=$settingName expectedValue=$expectedValue actualValue=$actualValue") -StartedAt $startedAt -EndedAt (Get-Date)
    }

    return $results
}

function Get-KitDefenderResultSummary {
    param(
        [AllowNull()]
        $Results = @()
    )

    $defenderResults = @(ConvertTo-KitStepResultArray -Value $Results)
    $stepSummary = Get-KitStepResultSummary -Results $defenderResults
    $defenderMismatchCount = @($defenderResults | Where-Object { $_.reason -eq "defender-state-mismatch" }).Count
    $defenderQueryFailedCount = @($defenderResults | Where-Object { $_.reason -eq "defender-query-failed" }).Count
    $defenderNotRunCount = @($defenderResults | Where-Object { $_.status -eq "whatif" -or $_.reason -eq "defender-verification-not-run" }).Count
    $defenderCheckedCount = $defenderResults.Count - $defenderNotRunCount

    [pscustomobject]@{
        total = $stepSummary.total
        statusCounts = $stepSummary.statusCounts
        failedRequiredCount = $stepSummary.failedRequiredCount
        failedOptionalCount = $stepSummary.failedOptionalCount
        hasBlockingFailure = $stepSummary.hasBlockingFailure
        exitCode = $stepSummary.exitCode
        defenderCheckedCount = $defenderCheckedCount
        defenderMismatchCount = $defenderMismatchCount
        defenderQueryFailedCount = $defenderQueryFailedCount
        defenderNotRunCount = $defenderNotRunCount
    }
}

function New-KitDefenderStateReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $defenderResults = @(ConvertTo-KitStepResultArray -Value $Results)
    [pscustomobject]@{
        reportType = "defender-state-verification"
        generatedAt = (Get-Date).ToString('s')
        defenderSummary = Get-KitDefenderResultSummary -Results $defenderResults
        defenderResults = $defenderResults
    }
}

