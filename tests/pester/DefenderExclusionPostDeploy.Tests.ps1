$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

function Write-TestDefenderManifest {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [AllowNull()]
        $Exclusions = @(),

        [AllowNull()]
        $StateChecks = @()
    )

    $manifest = [ordered]@{
        exclusions = @($Exclusions)
    }
    if (@($StateChecks).Count -gt 0) {
        $manifest.stateChecks = @($StateChecks)
    }

    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-TestDefenderExclusion {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Value,

        [bool]$Required = $false,

        [string]$FailurePolicy = "manual"
    )

    [ordered]@{
        id = $Id
        type = $Type
        value = $Value
        scope = $Id
        reason = $Id
        required = $Required
        failurePolicy = $FailurePolicy
    }
}

function Invoke-TestDefenderScript {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$PathsManifestPath,

        [Parameter(Mandatory)]
        [string]$ReportPath,

        [switch]$ExpectFailure
    )

    $thrown = $null
    try {
        & $ScriptPath -ManifestPath $ManifestPath -PathsManifestPath $PathsManifestPath -ReportPath $ReportPath -WhatIf
    } catch {
        $thrown = $_
    }

    if ($ExpectFailure) {
        return $thrown
    }

    if ($null -ne $thrown) {
        throw $thrown
    }
}

Describe "Defender exclusion postdeploy integration" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        function script:Write-TestDefenderManifest {
            param(
                [Parameter(Mandatory)]
                [string]$Path,

                [AllowNull()]
                $Exclusions = @(),

                [AllowNull()]
                $StateChecks = @()
            )

            $manifest = [ordered]@{
                exclusions = @($Exclusions)
            }
            if (@($StateChecks).Count -gt 0) {
                $manifest.stateChecks = @($StateChecks)
            }

            $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
        }

        function script:New-TestDefenderExclusion {
            param(
                [Parameter(Mandatory)]
                [string]$Id,

                [Parameter(Mandatory)]
                [string]$Type,

                [Parameter(Mandatory)]
                [string]$Value,

                [bool]$Required = $false,

                [string]$FailurePolicy = "manual"
            )

            [ordered]@{
                id = $Id
                type = $Type
                value = $Value
                scope = $Id
                reason = $Id
                required = $Required
                failurePolicy = $FailurePolicy
            }
        }

        function script:Invoke-TestDefenderScript {
            param(
                [Parameter(Mandatory)]
                [string]$ScriptPath,

                [Parameter(Mandatory)]
                [string]$ManifestPath,

                [Parameter(Mandatory)]
                [string]$PathsManifestPath,

                [Parameter(Mandatory)]
                [string]$ReportPath,

                [switch]$ExpectFailure
            )

            $thrown = $null
            try {
                & $ScriptPath -ManifestPath $ManifestPath -PathsManifestPath $PathsManifestPath -ReportPath $ReportPath -WhatIf
            } catch {
                $thrown = $_
            }

            if ($ExpectFailure) {
                return $thrown
            }

            if ($null -ne $thrown) {
                throw $thrown
            }
        }

        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-defender-postdeploy-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
        $script:PathsPath = Join-Path $script:TempRoot "paths.json"
        $script:ManifestPath = Join-Path $script:TempRoot "defender-exclusions.json"
        $script:ReportPath = Join-Path $script:TempRoot "defender-report.json"
        $script:DefenderScriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Set-DefenderExclusions.ps1"
        $script:DriveRoot = [IO.Path]::GetPathRoot($env:SystemRoot)

        ([ordered]@{
            paths = [ordered]@{
                WorkRoot = Join-Path $script:TempRoot "work"
                DeployRoot = Join-Path $script:TempRoot "deploy"
                PackageRoot = Join-Path $script:TempRoot "packages"
                ConfigRoot = Join-Path $script:TempRoot "configs"
                ToolRoot = Join-Path $script:TempRoot "tools"
                DataRoot = Join-Path $script:TempRoot "data"
            }
        }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:PathsPath -Encoding UTF8
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "keeps the repository Defender manifest schema-compatible" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\defender-exclusions.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "exclusions") $true
        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "paths") $false
        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "processes") $false
        Assert-KitEqual @($manifest.exclusions | Where-Object { [string]$_.type -eq "extension" }).Count 0
    }

    It "reports dangerous optional exclusions as manual without blocking exitCode" {
        $exclusion = New-TestDefenderExclusion -Id "drive-root" -Type "path" -Value $script:DriveRoot
        Write-TestDefenderManifest -Path $script:ManifestPath -Exclusions @($exclusion)

        Invoke-TestDefenderScript -ScriptPath $script:DefenderScriptPath -ManifestPath $script:ManifestPath -PathsManifestPath $script:PathsPath -ReportPath $script:ReportPath
        $report = Get-Content -LiteralPath $script:ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $result = @($report.defenderResults)[0]

        Assert-KitEqual $report.defenderSummary.exitCode 0
        Assert-KitEqual $result.policyStatus "blocked"
        Assert-KitEqual $result.action "blocked"
        Assert-KitEqual $result.status "manual"
    }

    It "blocks exitCode for required fail exclusions" {
        $exclusion = New-TestDefenderExclusion -Id "drive-root-required" -Type "path" -Value $script:DriveRoot -Required $true -FailurePolicy 'fail'
        Write-TestDefenderManifest -Path $script:ManifestPath -Exclusions @($exclusion)

        $thrown = Invoke-TestDefenderScript -ScriptPath $script:DefenderScriptPath -ManifestPath $script:ManifestPath -PathsManifestPath $script:PathsPath -ReportPath $script:ReportPath -ExpectFailure
        Assert-KitNotNullOrEmpty $thrown

        $report = Get-Content -LiteralPath $script:ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $report.defenderSummary.exitCode 1
        Assert-KitEqual $report.defenderSummary.failedRequiredCount 1
    }

    It "writes policy status, action, exists flags, and summary for WhatIf" {
        $exclusion = New-TestDefenderExclusion -Id "cache" -Type "path" -Value '${WorkRoot}\cache'
        Write-TestDefenderManifest -Path $script:ManifestPath -Exclusions @($exclusion)

        Invoke-TestDefenderScript -ScriptPath $script:DefenderScriptPath -ManifestPath $script:ManifestPath -PathsManifestPath $script:PathsPath -ReportPath $script:ReportPath
        $report = Get-Content -LiteralPath $script:ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $result = @($report.defenderResults)[0]

        Assert-KitEqual $report.reportType "defender-exclusion-policy"
        Assert-KitEqual $report.whatIf $true
        Assert-KitEqual $result.policyStatus "allowed"
        Assert-KitEqual $result.action "would-add"
        Assert-KitEqual $result.existsBefore $false
        Assert-KitEqual $result.existsAfter $false
        Assert-KitEqual $report.defenderSummary.whatIfCount 1
        Assert-KitEqual $report.defenderSummary.exitCode 0
    }

    It "records state checks as WhatIf without requiring administrator rights" {
        Write-TestDefenderManifest -Path $script:ManifestPath -StateChecks @(
            [ordered]@{
                name = 'DefenderRealtimeProtection'
                settingName = 'DisableRealtimeMonitoring'
                expectedValue = $false
                required = $true
                failurePolicy = 'fail'
            }
        )

        Invoke-TestDefenderScript -ScriptPath $script:DefenderScriptPath -ManifestPath $script:ManifestPath -PathsManifestPath $script:PathsPath -ReportPath $script:ReportPath
        $report = Get-Content -LiteralPath $script:ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual @($report.defenderStateResults).Count 1
        Assert-KitEqual @($report.defenderResults).Count 0
        Assert-KitEqual $report.defenderSummary.whatIfCount 1
        Assert-KitEqual $report.defenderSummary.exitCode 0
    }
}
