#Requires -Version 5.1

. "$PSScriptRoot\New-StepResult.ps1"

function Get-KitConfigStateProperty {
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

function Test-KitConfigStatePropertyExists {
    param(
        [AllowNull()]
        $Config,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Config) {
        return $false
    }

    if ($Config -is [System.Collections.IDictionary]) {
        return $Config.Contains($Name)
    }

    if ($null -ne $Config.PSObject) {
        return @($Config.PSObject.Properties | Where-Object { $_.Name -eq $Name }).Count -gt 0
    }

    return $false
}

function ConvertTo-KitConfigStateCheck {
    param(
        [AllowNull()]
        $Config
    )

    if ($null -eq $Config) {
        return @()
    }

    if ($Config -is [System.Array]) {
        return @($Config)
    }

    if ($Config -is [System.Collections.IEnumerable] -and -not ($Config -is [string]) -and $null -eq $Config.PSObject.Properties["settingName"]) {
        return @($Config)
    }

    $settingName = [string](Get-KitConfigStateProperty -Config $Config -Name "settingName" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($settingName)) {
        return @($Config)
    }

    return @()
}

function Get-KitConfigStateRequired {
    param(
        [AllowNull()]
        $Config
    )

    return [bool](Get-KitConfigStateProperty -Config $Config -Name "required" -DefaultValue $true)
}

function Get-KitConfigStateFailurePolicy {
    param(
        [AllowNull()]
        $Config
    )

    $policy = [string](Get-KitConfigStateProperty -Config $Config -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($policy)) {
        return "fail"
    }

    return $policy.ToLowerInvariant()
}

function Resolve-KitConfigStateFailureStatus {
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

function Test-KitConfigStateValueEqual {
    param(
        [AllowNull()]
        $Actual,

        [AllowNull()]
        $Expected
    )

    if ($null -eq $Actual -or $null -eq $Expected) {
        return ($null -eq $Actual) -and ($null -eq $Expected)
    }

    if ($Actual -is [bool] -or $Expected -is [bool]) {
        return ([bool]$Actual) -eq ([bool]$Expected)
    }

    if ($Actual -is [int] -or $Actual -is [long] -or $Actual -is [double] -or $Actual -is [decimal] -or
        $Expected -is [int] -or $Expected -is [long] -or $Expected -is [double] -or $Expected -is [decimal]) {
        try {
            return ([double]$Actual) -eq ([double]$Expected)
        } catch {
            return [string]$Actual -eq [string]$Expected
        }
    }

    return [string]$Actual -eq [string]$Expected
}

function ConvertFrom-KitConfigStateQueryResult {
    param(
        [AllowNull()]
        $QueryResult,

        [Parameter(Mandatory)]
        [string]$SettingName
    )

    if ($null -eq $QueryResult) {
        return [pscustomobject]@{
            found = $false
            value = $null
        }
    }

    if (Test-KitConfigStatePropertyExists -Config $QueryResult -Name "found") {
        $found = [bool](Get-KitConfigStateProperty -Config $QueryResult -Name "found" -DefaultValue $false)
        $value = Get-KitConfigStateProperty -Config $QueryResult -Name "value" -DefaultValue $null
        if (Test-KitConfigStatePropertyExists -Config $QueryResult -Name "actualValue") {
            $value = Get-KitConfigStateProperty -Config $QueryResult -Name "actualValue" -DefaultValue $value
        }

        return [pscustomobject]@{
            found = $found
            value = $value
        }
    }

    if (Test-KitConfigStatePropertyExists -Config $QueryResult -Name "actualValue") {
        return [pscustomobject]@{
            found = $true
            value = Get-KitConfigStateProperty -Config $QueryResult -Name "actualValue" -DefaultValue $null
        }
    }

    if (Test-KitConfigStatePropertyExists -Config $QueryResult -Name "value") {
        return [pscustomobject]@{
            found = $true
            value = Get-KitConfigStateProperty -Config $QueryResult -Name "value" -DefaultValue $null
        }
    }

    if (Test-KitConfigStatePropertyExists -Config $QueryResult -Name $SettingName) {
        return [pscustomobject]@{
            found = $true
            value = Get-KitConfigStateProperty -Config $QueryResult -Name $SettingName -DefaultValue $null
        }
    }

    return [pscustomobject]@{
        found = $true
        value = $QueryResult
    }
}

function New-KitConfigStateResult {
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

    $settingName = [string](Get-KitConfigStateProperty -Config $Config -Name "settingName" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($settingName)) {
        throw "配置状态检查缺少 settingName"
    }

    $domain = [string](Get-KitConfigStateProperty -Config $Config -Name "domain" -DefaultValue "userExperience")
    if ([string]::IsNullOrWhiteSpace($domain)) {
        $domain = "userExperience"
    }

    $name = [string](Get-KitConfigStateProperty -Config $Config -Name "name" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = "{0}_{1}" -f $domain, $settingName
    }

    $required = Get-KitConfigStateRequired -Config $Config
    $failurePolicy = Get-KitConfigStateFailurePolicy -Config $Config
    $expectedValue = Get-KitConfigStateProperty -Config $Config -Name "expectedValue" -DefaultValue $null
    $skippedReason = ""
    $manualAction = ""

    if ($Status -eq "skipped") {
        $skippedReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "config-state-skipped" } else { $Reason }
    } elseif ($Status -eq "manual") {
        $manualAction = if ([string]::IsNullOrWhiteSpace($Reason)) { "inspect-config-state" } else { $Reason }
    }

    $stepResult = New-KitStepResult `
        -Name $name `
        -Required $required `
        -Status $Status `
        -Message $Message `
        -Reason $Reason `
        -Data ([pscustomobject]@{
            domain = $domain
            settingName = $settingName
            expectedValue = $expectedValue
            actualValue = $ActualValue
            failurePolicy = $failurePolicy
        }) `
        -Errors $Errors `
        -SkippedReason $skippedReason `
        -ManualAction $manualAction `
        -WhatIfResult ($Status -eq "whatif") `
        -StartedAt $StartedAt `
        -EndedAt $EndedAt

    [pscustomobject][ordered]@{
        name = $stepResult.name
        domain = $domain
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

function Test-KitConfigState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [scriptblock]$ConfigQuery = $null,

        [switch]$WhatIf
    )

    $checks = @(ConvertTo-KitConfigStateCheck -Config $Config)
    if ($checks.Count -eq 0) {
        return @()
    }

    $results = @()
    if ($WhatIf) {
        foreach ($check in $checks) {
            $results += New-KitConfigStateResult -Config $check -Status "whatif" -Reason "whatif-preview" -Message "WhatIf 预演未执行配置状态查询"
        }
        return $results
    }

    if ($null -eq $ConfigQuery) {
        foreach ($check in $checks) {
            $required = Get-KitConfigStateRequired -Config $check
            $failurePolicy = Get-KitConfigStateFailurePolicy -Config $check
            $status = Resolve-KitConfigStateFailureStatus -Required $required -FailurePolicy $failurePolicy
            $results += New-KitConfigStateResult -Config $check -Status $status -Reason "config-query-missing" -Message "配置状态查询未配置" -Errors @("ConfigQuery was not provided.")
        }
        return $results
    }

    foreach ($check in $checks) {
        $startedAt = Get-Date
        $domain = [string](Get-KitConfigStateProperty -Config $check -Name "domain" -DefaultValue "userExperience")
        $settingName = [string](Get-KitConfigStateProperty -Config $check -Name "settingName" -DefaultValue "")
        $expectedValue = Get-KitConfigStateProperty -Config $check -Name "expectedValue" -DefaultValue $null
        $required = Get-KitConfigStateRequired -Config $check
        $failurePolicy = Get-KitConfigStateFailurePolicy -Config $check

        try {
            $queryResult = & $ConfigQuery -Check $check -Domain $domain -SettingName $settingName
        } catch {
            $status = Resolve-KitConfigStateFailureStatus -Required $required -FailurePolicy $failurePolicy
            $results += New-KitConfigStateResult -Config $check -Status $status -Reason "config-query-failed" -Message "配置状态查询失败" -Errors @($_.Exception.Message) -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        $actual = ConvertFrom-KitConfigStateQueryResult -QueryResult $queryResult -SettingName $settingName
        if (-not [bool]$actual.found) {
            $status = Resolve-KitConfigStateFailureStatus -Required $required -FailurePolicy $failurePolicy
            $results += New-KitConfigStateResult -Config $check -Status $status -Reason "config-state-missing" -Message "配置状态不存在" -ActualValue $actual.value -Errors @("settingName not found: $settingName") -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        if (Test-KitConfigStateValueEqual -Actual $actual.value -Expected $expectedValue) {
            $results += New-KitConfigStateResult -Config $check -Status "unchanged" -Reason "config-state-ok" -Message "配置状态符合预期" -ActualValue $actual.value -StartedAt $startedAt -EndedAt (Get-Date)
            continue
        }

        $status = Resolve-KitConfigStateFailureStatus -Required $required -FailurePolicy $failurePolicy
        $results += New-KitConfigStateResult -Config $check -Status $status -Reason "config-state-mismatch" -Message "配置状态不符合预期" -ActualValue $actual.value -Errors @("settingName=$settingName expectedValue=$expectedValue actualValue=$($actual.value)") -StartedAt $startedAt -EndedAt (Get-Date)
    }

    return $results
}

function Get-KitConfigStateResultSummary {
    param(
        [AllowNull()]
        $Results = @()
    )

    $configResults = @(ConvertTo-KitStepResultArray -Value $Results)
    $stepSummary = Get-KitStepResultSummary -Results $configResults
    $configMismatchCount = @($configResults | Where-Object { $_.reason -eq "config-state-mismatch" }).Count
    $configMissingCount = @($configResults | Where-Object { $_.reason -eq "config-state-missing" }).Count
    $configQueryFailedCount = @($configResults | Where-Object { $_.reason -in @("config-query-failed", "config-query-missing") }).Count
    $configNotRunCount = @($configResults | Where-Object { $_.status -eq "whatif" -or $_.reason -eq "config-verification-not-run" }).Count
    $configCheckedCount = $configResults.Count - $configNotRunCount
    $domainMismatchCounts = [ordered]@{}

    foreach ($domain in @("explorer", "startMenu", "terminal", "defaultApps", "contextMenu", "userExperience")) {
        $domainMismatchCounts["${domain}MismatchCount"] = @($configResults | Where-Object { $_.domain -eq $domain -and $_.reason -eq "config-state-mismatch" }).Count
    }

    [pscustomobject]@{
        total = $stepSummary.total
        statusCounts = $stepSummary.statusCounts
        failedRequiredCount = $stepSummary.failedRequiredCount
        failedOptionalCount = $stepSummary.failedOptionalCount
        hasBlockingFailure = $stepSummary.hasBlockingFailure
        exitCode = $stepSummary.exitCode
        configCheckedCount = $configCheckedCount
        configMismatchCount = $configMismatchCount
        configMissingCount = $configMissingCount
        configQueryFailedCount = $configQueryFailedCount
        configNotRunCount = $configNotRunCount
        explorerMismatchCount = $domainMismatchCounts["explorerMismatchCount"]
        startMenuMismatchCount = $domainMismatchCounts["startMenuMismatchCount"]
        terminalMismatchCount = $domainMismatchCounts["terminalMismatchCount"]
        defaultAppsMismatchCount = $domainMismatchCounts["defaultAppsMismatchCount"]
        contextMenuMismatchCount = $domainMismatchCounts["contextMenuMismatchCount"]
        userExperienceMismatchCount = $domainMismatchCounts["userExperienceMismatchCount"]
    }
}

function New-KitConfigStateReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $configResults = @(ConvertTo-KitStepResultArray -Value $Results)
    [pscustomobject]@{
        reportType = "config-state-verification"
        generatedAt = (Get-Date).ToString('s')
        configSummary = Get-KitConfigStateResultSummary -Results $configResults
        configResults = $configResults
    }
}
