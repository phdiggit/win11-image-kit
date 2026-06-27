#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$PlanOnly,
    [int]$TargetDiskNumber = -1,
    [string]$ExpectedDiskSerial,
    [UInt64]$ExpectedDiskSize = 0,
    [string]$ImageSha256,
    [int]$ImageIndex = 0,
    [string]$ImageArchitecture,
    [string]$ConfirmationToken,
    [string]$SourceRunId,
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Test-KitControlledExecutionSafety.ps1"
. "$PSScriptRoot\..\common\Test-KitControlledExecutionAuthorization.ps1"

$tokenStatus = if ([string]::IsNullOrWhiteSpace($ConfirmationToken)) { "missing" } else { "matched" }
$diskStatus = if ($TargetDiskNumber -lt 0 -or [string]::IsNullOrWhiteSpace($ExpectedDiskSerial) -or $ExpectedDiskSize -le 0) { "missing" } else { "matched" }
$wimStatus = if ([string]::IsNullOrWhiteSpace($ImageSha256) -or $ImageIndex -le 0 -or [string]::IsNullOrWhiteSpace($ImageArchitecture)) { "missing" } else { "matched" }

$authorizationInput = [pscustomobject][ordered]@{
    reportType = "controlled-execution-authorization"
    schemaVersion = 1
    requestedMode = if ($Execute) { "execute" } else { "plan-only" }
    executeRequested = [bool]$Execute
    allowTrueExecution = $false
    targetDiskNumber = $TargetDiskNumber
    targetDiskSerial = [string]$ExpectedDiskSerial
    confirmationTokenStatus = $tokenStatus
    diskIdentityStatus = $diskStatus
    wimValidationStatus = $wimStatus
    sourceRunId = [string]$SourceRunId
    expectedSourceRunId = [string]$SourceRunId
    authorizationStatus = "planned"
    trueExecutionAllowed = $false
}

$authorization = Test-KitControlledExecutionAuthorization -InputObject $authorizationInput
$status = if ($authorization.status -eq "planned") { "planned" } else { "blocked" }

$report = [pscustomobject][ordered]@{
    reportType = "winpe-controlled-execution-plan"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    mode = "plan-only"
    whatIf = $true
    planOnly = $true
    executeRequested = [bool]$Execute
    trueExecution = $false
    status = $status
    reason = if ($status -eq "planned") { "WinPE controlled execution plan only; no native command executed" } else { $authorization.reason }
    target = [pscustomobject][ordered]@{
        diskNumber = $TargetDiskNumber
        expectedDiskSerial = [string]$ExpectedDiskSerial
        expectedDiskSize = $ExpectedDiskSize
    }
    image = [pscustomobject][ordered]@{
        sha256 = [string]$ImageSha256
        index = $ImageIndex
        architecture = [string]$ImageArchitecture
    }
    authorization = $authorization
    stageResults = @(
        [pscustomobject][ordered]@{
            id = "winpe-plan-entrypoint"
            stage = "winpe-plan-entrypoint"
            status = $status
            reason = if ($status -eq "planned") { "parameters parsed for future execution contract only" } else { $authorization.reason }
            executed = $false
        }
    )
}

$report | ConvertTo-Json -Depth 12
