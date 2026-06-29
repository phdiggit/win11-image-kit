function Get-FutureTrueUxFrozenFlagNames {
    @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")
}

function Assert-FutureTrueUxGovernanceBoundary {
    param(
        [Parameter(Mandatory)]
        [string]$DocumentText,

        [int]$IssueNumber = 19
    )

    Assert-KitMatch $DocumentText "Refs #$IssueNumber"
    Assert-KitNotMatch $DocumentText "(?i)\b(fixes|closes|resolves)\s+#$IssueNumber\b"

    foreach ($flagName in @(Get-FutureTrueUxFrozenFlagNames)) {
        Assert-KitMatch $DocumentText ('\| `{0}` \| `false` \|' -f [regex]::Escape($flagName))
        Assert-KitNotMatch $DocumentText "$flagName\s*=\s*true"
    }

    Assert-KitMatch $DocumentText '\| `mutationCount` \| `0` \|'
}

function Assert-FutureTrueUxFrozenExecutionObject {
    param(
        [AllowNull()]
        $Actual
    )

    foreach ($flagName in @(Get-FutureTrueUxFrozenFlagNames)) {
        Assert-KitEqual $Actual.$flagName $false
    }

    Assert-KitEqual $Actual.mutationCount 0
}

function Assert-FutureTrueUxQualityGateSemantics {
    param(
        [Parameter(Mandatory)]
        $Gate,

        [string]$RepoRoot = ""
    )

    Assert-KitEqual $Gate.layer "pr-fast"
    Assert-KitEqual $Gate.trigger "pull_request"
    Assert-KitEqual $Gate.mode "report-only"
    Assert-KitEqual $Gate.required $true
    Assert-KitEqual $Gate.blocking $true
    Assert-KitNotMatch $Gate.entrypoint "scripts/(build|postdeploy|presysprep|winpe)/"
    Assert-KitNotMatch $Gate.entrypoint "Restore-UserExperience|Invoke-GoldenImageBuild|Install-|Set-|Clear-|New-WinPE"

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $entrypointPath = Join-Path $RepoRoot $Gate.entrypoint
        Assert-KitEqual (Test-Path -LiteralPath $entrypointPath) $true
    }
}

function Get-FutureTrueUxDangerousCommandNames {
    @(
        "Start-Process",
        "Invoke-Expression",
        "Set-ItemProperty",
        "New-ItemProperty",
        "Remove-AppxPackage",
        "Add-MpPreference",
        "dism",
        "winget",
        "choco",
        "msiexec",
        "Invoke-WebRequest",
        "Invoke-RestMethod",
        "Install-Module"
    )
}

function Assert-FutureTrueUxNoDangerousCommands {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    foreach ($command in @(Get-FutureTrueUxDangerousCommandNames)) {
        Assert-KitNotMatch $Content ("(?i)(^|[^A-Za-z0-9-])" + [regex]::Escape($command) + "([^A-Za-z0-9-]|$)")
    }
}

function Assert-FutureTrueUxBuildLockTracksPath {
    param(
        [Parameter(Mandatory)]
        $BuildLock,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $lockedPaths = @($BuildLock.entries.path)
    Assert-KitEqual ($lockedPaths -contains $Path) $true
}

function Assert-FutureTrueUxValidatorEntrypointExists {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    Assert-KitMatch $RelativePath "^scripts/validate/Test-FutureTrueUxRestore.+\.ps1$"
    Assert-KitEqual (Test-Path -LiteralPath (Join-Path $RepoRoot $RelativePath)) $true
}

function Assert-FutureTrueUxQualityGateEntrypointStable {
    param(
        [Parameter(Mandatory)]
        $Gate,

        [Parameter(Mandatory)]
        [string]$ExpectedId,

        [Parameter(Mandatory)]
        [string]$ExpectedEntrypoint
    )

    Assert-KitEqual $Gate.id $ExpectedId
    Assert-KitEqual $Gate.entrypoint $ExpectedEntrypoint
}

function Assert-FutureTrueUxValidatorUsesSharedPrimitives {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    Assert-KitMatch $Content "FutureTrueUxRestore\.ValidatorPrimitives\.ps1"
    Assert-KitMatch $Content "Get-FutureTrueUxRestoreValidatorRepoRoot"
    Assert-KitMatch $Content "New-FutureTrueUxRestoreValidatorState"
    Assert-KitMatch $Content "Read-FutureTrueUxRestoreValidatorJson"
    Assert-KitMatch $Content "Add-FutureTrueUxRestoreValidatorCheck"
    Assert-KitMatch $Content "Write-FutureTrueUxRestoreValidatorReport"
    Assert-KitMatch $Content "Complete-FutureTrueUxRestoreValidatorRun"
}

function Assert-FutureTrueUxValidatorNoInlineReportWrites {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    Assert-KitNotMatch $Content "(?i)(^|[^A-Za-z0-9-])(Set-Content|Out-File|Export-Csv|Export-Clixml|Add-Content|New-Item|Remove-Item|Copy-Item|Move-Item)([^A-Za-z0-9-]|$)"
    Assert-KitNotMatch $Content '\$script:Failures'
    Assert-KitNotMatch $Content "function\s+Read-FutureTrueUx"
    Assert-KitNotMatch $Content "function\s+Assert-FutureTrueUx"
}

function Invoke-FutureTrueUxValidatorSmoke {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$ReportPath
    )

    $scriptPath = Join-Path $RepoRoot $RelativePath
    $resolvedReportPath = Join-Path $RepoRoot $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -ReportPath $ReportPath 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Validator smoke failed for <$RelativePath> with exit code <$exitCode>: $($output -join "`n")"
    }

    Assert-KitEqual (Test-Path -LiteralPath $resolvedReportPath) $true
    $report = Get-Content -LiteralPath $resolvedReportPath -Raw -Encoding UTF8 | ConvertFrom-Json

    [pscustomobject][ordered]@{
        exitCode = $exitCode
        output = @($output)
        reportPath = $resolvedReportPath
        report = $report
    }
}

function Assert-FutureTrueUxValidatorReportShape {
    param(
        [Parameter(Mandatory)]
        $Report,

        [Parameter(Mandatory)]
        [string]$ExpectedReportType
    )

    Assert-KitEqual $Report.reportType $ExpectedReportType
    Assert-KitEqual $Report.schemaVersion 1
    Assert-KitEqual $Report.status "passed"
    Assert-KitEqual $Report.failureCount 0
    Assert-KitEqual @($Report.failures).Count 0
    Assert-KitNotNullOrEmpty $Report.generatedAt
}

function Assert-FutureTrueUxPresentationEntrypointExists {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    Assert-KitMatch $RelativePath "^scripts/config/Show-FutureTrueUxRestore.+Plan\.ps1$"
    Assert-KitEqual (Test-Path -LiteralPath (Join-Path $RepoRoot $RelativePath)) $true
}

function Assert-FutureTrueUxPresentationUsesSharedPrimitives {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    Assert-KitMatch $Content "FutureTrueUxRestore\.PresentationPrimitives\.ps1"
    Assert-KitMatch $Content "Get-FutureTrueUxRestorePresentationRepoRoot"
    Assert-KitMatch $Content "Read-FutureTrueUxRestorePresentationJson"
    Assert-KitMatch $Content "Write-FutureTrueUxRestorePresentation"
}

function Assert-FutureTrueUxPresentationReadOnly {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    Assert-FutureTrueUxNoDangerousCommands -Content $Content
    Assert-KitNotMatch $Content "(?i)(^|[^A-Za-z0-9-])(Set-Content|Out-File|Export-Csv|Export-Clixml|Add-Content|New-Item|Remove-Item|Copy-Item|Move-Item)([^A-Za-z0-9-]|$)"
    Assert-KitNotMatch $Content "function\s+Read-FutureTrueUx.*PlanJson"
}

function Invoke-FutureTrueUxPresentationSmoke {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $scriptPath = Join-Path $RepoRoot $RelativePath
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Presentation smoke failed for <$RelativePath> with exit code <$exitCode>: $($output -join "`n")"
    }

    [pscustomobject][ordered]@{
        exitCode = $exitCode
        output = @($output)
        text = ($output -join "`n")
    }
}
