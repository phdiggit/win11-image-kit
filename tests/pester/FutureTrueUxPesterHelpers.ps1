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
