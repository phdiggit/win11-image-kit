#Requires -Version 5.1

. "$PSScriptRoot\New-StepResult.ps1"

function Get-KitServiceConfigProperty {
    param(
        [AllowNull()]
        $ServiceConfig,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $ServiceConfig) {
        return $DefaultValue
    }

    if ($ServiceConfig -is [System.Collections.IDictionary] -and $ServiceConfig.Contains($Name)) {
        return $ServiceConfig[$Name]
    }

    if ($null -ne $ServiceConfig.PSObject -and $null -ne $ServiceConfig.PSObject.Properties[$Name]) {
        return $ServiceConfig.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function ConvertTo-KitServiceStartType {
    param(
        [AllowNull()]
        $Value
    )

    $text = ([string]$Value).Trim()
    switch -Regex ($text) {
        "^(Auto|Automatic)$" { return "Automatic" }
        "^Manual$" { return "Manual" }
        "^Disabled$" { return "Disabled" }
        default { return $text }
    }
}

function Get-KitServiceRequired {
    param(
        [AllowNull()]
        $ServiceConfig
    )

    $required = Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "required" -DefaultValue $true
    return [bool]$required
}

function Get-KitServiceFailurePolicy {
    param(
        [AllowNull()]
        $ServiceConfig
    )

    $policy = [string](Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($policy)) {
        return "fail"
    }

    return $policy.ToLowerInvariant()
}

function Resolve-KitServiceFailureStatus {
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

function New-KitServiceStateResult {
    param(
        [Parameter(Mandatory)]
        $ServiceConfig,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [AllowEmptyString()]
        [string]$Reason,

        [AllowEmptyString()]
        [string]$Message,

        [AllowEmptyString()]
        [string]$ActualState,

        [AllowEmptyString()]
        [string]$ActualStartType,

        [AllowNull()]
        $Evidence = $null,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date),

        [datetime]$EndedAt = (Get-Date)
    )

    $serviceName = [string](Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "name" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($serviceName)) {
        throw "service result 缺少 service name"
    }

    $required = Get-KitServiceRequired -ServiceConfig $ServiceConfig
    $failurePolicy = Get-KitServiceFailurePolicy -ServiceConfig $ServiceConfig
    $expectedState = [string](Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "expectedState" -DefaultValue "")
    $expectedStartType = ConvertTo-KitServiceStartType -Value (Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "expectedStartType" -DefaultValue "")
    $skippedReason = ""
    $manualAction = ""

    if ($Status -eq "skipped") {
        $skippedReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "service-verification-skipped" } else { $Reason }
    } elseif ($Status -eq "manual") {
        $manualAction = if ([string]::IsNullOrWhiteSpace($Reason)) { "inspect-service-state" } else { $Reason }
    }

    $stepArgs = @{
        Name = $serviceName
        Required = $required
        Status = $Status
        Message = $Message
        Reason = $Reason
        Data = [pscustomobject]@{
            serviceName = $serviceName
            expectedState = $expectedState
            actualState = $ActualState
            expectedStartType = $expectedStartType
            actualStartType = $ActualStartType
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
        serviceName = $serviceName
        displayName = [string](Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "displayName" -DefaultValue "")
        required = $stepResult.required
        status = $stepResult.status
        changed = $stepResult.changed
        reason = $stepResult.reason
        message = $stepResult.message
        expectedState = $expectedState
        actualState = $ActualState
        expectedStartType = $expectedStartType
        actualStartType = $ActualStartType
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

function Get-KitDefaultServiceState {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [bool]$IncludeStartType = $false
    )

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        return $null
    }

    $startType = ""
    if ($IncludeStartType) {
        $escapedName = $Name.Replace("'", "''")
        $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$escapedName'" -ErrorAction Stop
        if ($null -ne $cimService) {
            $startType = [string]$cimService.StartMode
        }
    }

    [pscustomobject]@{
        Name = [string]$service.Name
        Status = [string]$service.Status
        StartType = $startType
    }
}

function New-KitServiceVerificationResult {
    param(
        [Parameter(Mandatory)]
        $ServiceConfig,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$Message,

        [AllowEmptyString()]
        [string]$ActualState = "",

        [AllowEmptyString()]
        [string]$ActualStartType = "",

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date)
    )

    New-KitServiceStateResult -ServiceConfig $ServiceConfig -Status $Status -Reason $Reason -Message $Message -ActualState $ActualState -ActualStartType $ActualStartType -Errors $Errors -StartedAt $StartedAt -EndedAt (Get-Date)
}

function Test-KitServiceState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $ServiceConfig,

        [scriptblock]$ServiceQuery = $null,

        [switch]$WhatIf
    )

    $startedAt = Get-Date
    $serviceName = [string](Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "name" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($serviceName)) {
        throw "服务条目缺少 name"
    }

    if ($WhatIf) {
        return New-KitServiceVerificationResult -ServiceConfig $ServiceConfig -Status "whatif" -Reason "whatif-preview" -Message "WhatIf 预演未执行服务状态查询" -StartedAt $startedAt
    }

    $required = Get-KitServiceRequired -ServiceConfig $ServiceConfig
    $failurePolicy = Get-KitServiceFailurePolicy -ServiceConfig $ServiceConfig
    $expectedState = [string](Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "expectedState" -DefaultValue "")
    $expectedStartType = ConvertTo-KitServiceStartType -Value (Get-KitServiceConfigProperty -ServiceConfig $ServiceConfig -Name "expectedStartType" -DefaultValue "")
    $includeStartType = -not [string]::IsNullOrWhiteSpace($expectedStartType)
    $query = $ServiceQuery
    if ($null -eq $query) {
        $query = {
            param(
                [string]$Name,
                [AllowNull()]
                $ServiceConfig,
                [bool]$IncludeStartType
            )

            Get-KitDefaultServiceState -Name $Name -IncludeStartType:$IncludeStartType
        }
    }

    try {
        $serviceState = & $query -Name $serviceName -ServiceConfig $ServiceConfig -IncludeStartType:$includeStartType
    } catch {
        $status = Resolve-KitServiceFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitServiceVerificationResult -ServiceConfig $ServiceConfig -Status $status -Reason "service-query-failed" -Message "服务状态查询失败" -Errors @($_.Exception.Message) -StartedAt $startedAt
    }

    if ($null -eq $serviceState) {
        $status = Resolve-KitServiceFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitServiceVerificationResult -ServiceConfig $ServiceConfig -Status $status -Reason "service-missing" -Message "服务不存在" -Errors @("service not found: $serviceName") -StartedAt $startedAt
    }

    $actualState = [string](Get-KitServiceConfigProperty -ServiceConfig $serviceState -Name "Status" -DefaultValue "")
    $actualStartType = ConvertTo-KitServiceStartType -Value (Get-KitServiceConfigProperty -ServiceConfig $serviceState -Name "StartType" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($actualStartType)) {
        $actualStartType = ConvertTo-KitServiceStartType -Value (Get-KitServiceConfigProperty -ServiceConfig $serviceState -Name "StartMode" -DefaultValue "")
    }

    if (-not [string]::IsNullOrWhiteSpace($expectedState) -and $actualState -ne $expectedState) {
        $status = Resolve-KitServiceFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitServiceVerificationResult -ServiceConfig $ServiceConfig -Status $status -Reason "service-state-mismatch" -Message "服务状态不符合预期" -ActualState $actualState -ActualStartType $actualStartType -Errors @("expectedState=$expectedState actualState=$actualState") -StartedAt $startedAt
    }

    if (-not [string]::IsNullOrWhiteSpace($expectedStartType) -and $actualStartType -ne $expectedStartType) {
        $status = Resolve-KitServiceFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitServiceVerificationResult -ServiceConfig $ServiceConfig -Status $status -Reason "service-start-type-mismatch" -Message "服务启动类型不符合预期" -ActualState $actualState -ActualStartType $actualStartType -Errors @("expectedStartType=$expectedStartType actualStartType=$actualStartType") -StartedAt $startedAt
    }

    New-KitServiceVerificationResult -ServiceConfig $ServiceConfig -Status "unchanged" -Reason "service-state-ok" -Message "服务状态符合预期" -ActualState $actualState -ActualStartType $actualStartType -StartedAt $startedAt
}

function Get-KitServiceResultSummary {
    param(
        [AllowNull()]
        $Results = @()
    )

    $serviceResults = @(ConvertTo-KitStepResultArray -Value $Results)
    $stepSummary = Get-KitStepResultSummary -Results $serviceResults
    $serviceMismatchCount = @($serviceResults | Where-Object { $_.reason -in @("service-state-mismatch", "service-start-type-mismatch") }).Count
    $serviceMissingCount = @($serviceResults | Where-Object { $_.reason -eq "service-missing" }).Count
    $serviceNotRunCount = @($serviceResults | Where-Object { $_.status -eq "whatif" -or $_.reason -eq "service-verification-not-run" }).Count
    $serviceCheckedCount = $serviceResults.Count - $serviceNotRunCount

    [pscustomobject]@{
        total = $stepSummary.total
        statusCounts = $stepSummary.statusCounts
        failedRequiredCount = $stepSummary.failedRequiredCount
        failedOptionalCount = $stepSummary.failedOptionalCount
        hasBlockingFailure = $stepSummary.hasBlockingFailure
        exitCode = $stepSummary.exitCode
        serviceCheckedCount = $serviceCheckedCount
        serviceMismatchCount = $serviceMismatchCount
        serviceMissingCount = $serviceMissingCount
        serviceNotRunCount = $serviceNotRunCount
    }
}

function New-KitServiceStateReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $serviceResults = @(ConvertTo-KitStepResultArray -Value $Results)
    [pscustomobject]@{
        reportType = "service-state-verification"
        generatedAt = (Get-Date).ToString('s')
        serviceSummary = Get-KitServiceResultSummary -Results $serviceResults
        serviceResults = $serviceResults
    }
}

