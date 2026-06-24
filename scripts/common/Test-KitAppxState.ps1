#Requires -Version 5.1

. "$PSScriptRoot\New-StepResult.ps1"

function Get-KitAppxConfigProperty {
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

function Get-KitAppxRequired {
    param(
        [AllowNull()]
        $Config
    )

    return [bool](Get-KitAppxConfigProperty -Config $Config -Name "required" -DefaultValue $true)
}

function Get-KitAppxFailurePolicy {
    param(
        [AllowNull()]
        $Config
    )

    $policy = [string](Get-KitAppxConfigProperty -Config $Config -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($policy)) {
        return "fail"
    }

    return $policy.ToLowerInvariant()
}

function Resolve-KitAppxFailureStatus {
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

function Get-KitAppxScope {
    param(
        [AllowNull()]
        $Config
    )

    $scope = [string](Get-KitAppxConfigProperty -Config $Config -Name "scope" -DefaultValue "allUsers")
    if ([string]::IsNullOrWhiteSpace($scope)) {
        return "allUsers"
    }

    return $scope
}

function Get-KitAppxExpectedState {
    param(
        [AllowNull()]
        $Config
    )

    $expectedState = [string](Get-KitAppxConfigProperty -Config $Config -Name "expectedState" -DefaultValue "absent")
    if ([string]::IsNullOrWhiteSpace($expectedState)) {
        return "absent"
    }

    return $expectedState.ToLowerInvariant()
}

function ConvertTo-KitAppxStateCheck {
    param(
        [Parameter(Mandatory)]
        $Config
    )

    if ($Config -is [System.Array]) {
        return @($Config)
    }

    if ($Config -is [System.Collections.IEnumerable] -and -not ($Config -is [string]) -and $null -eq $Config.PSObject.Properties["packageName"]) {
        return @($Config)
    }

    return @($Config)
}

function Get-KitDefaultAppxState {
    param(
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    $matches = @()
    switch ($Scope) {
        "provisioned" {
            $matches = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object {
                $_.DisplayName -eq $PackageName -or $_.PackageName -like "$PackageName*"
            })
        }
        "user" {
            $matches = @(Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue)
        }
        default {
            $matches = @(Get-AppxPackage -Name $PackageName -AllUsers -ErrorAction SilentlyContinue)
        }
    }

    [pscustomobject]@{
        Present = ($matches.Count -gt 0)
        Matches = $matches
    }
}

function New-KitAppxStateResult {
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

        [AllowEmptyString()]
        [string]$ActualState = "",

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date),

        [datetime]$EndedAt = (Get-Date)
    )

    $packageName = [string](Get-KitAppxConfigProperty -Config $Config -Name "packageName" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        throw "AppX 状态检查缺少 packageName"
    }

    $name = [string](Get-KitAppxConfigProperty -Config $Config -Name "name" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $packageName
    }

    $scope = Get-KitAppxScope -Config $Config
    $expectedState = Get-KitAppxExpectedState -Config $Config
    $required = Get-KitAppxRequired -Config $Config
    $failurePolicy = Get-KitAppxFailurePolicy -Config $Config
    $skippedReason = ""
    $manualAction = ""
    if ($Status -eq "skipped") {
        $skippedReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "appx-verification-skipped" } else { $Reason }
    } elseif ($Status -eq "manual") {
        $manualAction = if ([string]::IsNullOrWhiteSpace($Reason)) { "inspect-appx-state" } else { $Reason }
    }

    $stepArgs = @{
        Name = $name
        Required = $required
        Status = $Status
        Message = $Message
        Reason = $Reason
        Data = [pscustomobject]@{
            packageName = $packageName
            scope = $scope
            expectedState = $expectedState
            actualState = $ActualState
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
        packageName = $packageName
        scope = $scope
        expectedState = $expectedState
        actualState = $ActualState
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

function Test-KitAppxState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [scriptblock]$AppxQuery = $null,

        [switch]$WhatIf
    )

    $checks = @(ConvertTo-KitAppxStateCheck -Config $Config)
    $results = @()
    foreach ($check in $checks) {
        $startedAt = Get-Date
        $packageName = [string](Get-KitAppxConfigProperty -Config $check -Name "packageName" -DefaultValue "")
        if ([string]::IsNullOrWhiteSpace($packageName)) {
            throw "AppX 状态检查缺少 packageName"
        }

        if ($WhatIf) {
            $results += New-KitAppxStateResult -Config $check -Status "whatif" -Reason "whatif-preview" -Message "WhatIf 预演未执行 AppX 状态查询" -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        $scope = Get-KitAppxScope -Config $check
        $expectedState = Get-KitAppxExpectedState -Config $check
        $query = $AppxQuery
        if ($null -eq $query) {
            $query = {
                param(
                    [string]$PackageName,
                    [string]$Scope,
                    [AllowNull()]
                    $AppxConfig
                )

                Get-KitDefaultAppxState -PackageName $PackageName -Scope $Scope
            }
        }

        try {
            $queryResult = & $query -PackageName $packageName -Scope $scope -AppxConfig $check
        } catch {
            $required = Get-KitAppxRequired -Config $check
            $failurePolicy = Get-KitAppxFailurePolicy -Config $check
            $status = Resolve-KitAppxFailureStatus -Required $required -FailurePolicy $failurePolicy
            $results += New-KitAppxStateResult -Config $check -Status $status -Reason "appx-query-failed" -Message "AppX 状态查询失败" -Errors @($_.Exception.Message) -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        $present = $false
        if ($null -ne $queryResult) {
            if ($null -ne $queryResult.PSObject -and $null -ne $queryResult.PSObject.Properties["Present"]) {
                $present = [bool]$queryResult.Present
            } else {
                $present = @($queryResult).Count -gt 0
            }
        }

        $actualState = if ($present) { "present" } else { "absent" }
        if ($actualState -eq $expectedState) {
            $results += New-KitAppxStateResult -Config $check -Status "unchanged" -Reason "appx-state-ok" -Message "AppX 状态符合预期" -ActualState $actualState -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        $required = Get-KitAppxRequired -Config $check
        $failurePolicy = Get-KitAppxFailurePolicy -Config $check
        $status = Resolve-KitAppxFailureStatus -Required $required -FailurePolicy $failurePolicy
        $results += New-KitAppxStateResult -Config $check -Status $status -Reason "appx-state-mismatch" -Message "AppX 状态不符合预期" -ActualState $actualState -Errors @("packageName=$packageName expectedState=$expectedState actualState=$actualState") -StartedAt $startedAt -EndedAt (Get-Date)
    }

    return $results
}

function Get-KitAppxResultSummary {
    param(
        [AllowNull()]
        $Results = @()
    )

    $appxResults = @(ConvertTo-KitStepResultArray -Value $Results)
    $stepSummary = Get-KitStepResultSummary -Results $appxResults
    $appxMismatchCount = @($appxResults | Where-Object { $_.reason -eq "appx-state-mismatch" }).Count
    $appxQueryFailedCount = @($appxResults | Where-Object { $_.reason -eq "appx-query-failed" }).Count
    $appxNotRunCount = @($appxResults | Where-Object { $_.status -eq "whatif" -or $_.reason -eq "appx-verification-not-run" }).Count
    $appxCheckedCount = $appxResults.Count - $appxNotRunCount

    [pscustomobject]@{
        total = $stepSummary.total
        statusCounts = $stepSummary.statusCounts
        failedRequiredCount = $stepSummary.failedRequiredCount
        failedOptionalCount = $stepSummary.failedOptionalCount
        hasBlockingFailure = $stepSummary.hasBlockingFailure
        exitCode = $stepSummary.exitCode
        appxCheckedCount = $appxCheckedCount
        appxMismatchCount = $appxMismatchCount
        appxQueryFailedCount = $appxQueryFailedCount
        appxNotRunCount = $appxNotRunCount
    }
}

function New-KitAppxStateReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $appxResults = @(ConvertTo-KitStepResultArray -Value $Results)
    [pscustomobject]@{
        reportType = "appx-state-verification"
        generatedAt = (Get-Date).ToString('s')
        appxSummary = Get-KitAppxResultSummary -Results $appxResults
        appxResults = $appxResults
    }
}

