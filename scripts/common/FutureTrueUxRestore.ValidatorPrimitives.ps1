#Requires -Version 5.1

function Get-FutureTrueUxRestoreValidatorRepoRoot {
    param(
        [Parameter(Mandatory)]
        [string]$ValidatorScriptRoot
    )

    (Resolve-Path -LiteralPath (Join-Path $ValidatorScriptRoot "..\..")).Path
}

function New-FutureTrueUxRestoreValidatorState {
    [pscustomobject][ordered]@{
        failures = @()
    }
}

function Read-FutureTrueUxRestoreValidatorJson {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-FutureTrueUxRestoreValidatorFailure {
    param(
        [Parameter(Mandatory)]
        $State,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $State.failures += $Message
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Add-FutureTrueUxRestoreValidatorCheck {
    param(
        [Parameter(Mandatory)]
        $State,

        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[OK] $Message" -ForegroundColor Green
        return
    }

    Add-FutureTrueUxRestoreValidatorFailure -State $State -Message $Message
}

function Get-FutureTrueUxRestoreValidatorStatus {
    param(
        [Parameter(Mandatory)]
        $State
    )

    if (@($State.failures).Count -eq 0) {
        return "passed"
    }

    "failed"
}

function Get-FutureTrueUxRestoreValidatorFailureCount {
    param(
        [Parameter(Mandatory)]
        $State
    )

    @($State.failures).Count
}

function Write-FutureTrueUxRestoreValidatorReport {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [AllowNull()]
        [string]$ReportPath,

        [Parameter(Mandatory)]
        $ReportObject,

        [Parameter(Mandatory)]
        [string]$SuccessMessage,

        [int]$Depth = 12
    )

    if ([string]::IsNullOrWhiteSpace($ReportPath)) {
        return
    }

    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $ReportObject | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "$SuccessMessage`: $resolvedReportPath"
}

function Complete-FutureTrueUxRestoreValidatorRun {
    param(
        [Parameter(Mandatory)]
        $State,

        [Parameter(Mandatory)]
        $ReportObject
    )

    $ReportObject

    if (@($State.failures).Count -gt 0) {
        exit 1
    }
}
