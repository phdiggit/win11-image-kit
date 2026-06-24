$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Defender and AppX state verification results" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitDefenderState.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitAppxState.ps1")
        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        foreach ($commandName in @(
            "Get-MpPreference",
            "Set-MpPreference",
            "Add-MpPreference",
            "Remove-MpPreference",
            "Get-AppxPackage",
            "Get-AppxProvisionedPackage",
            "Remove-AppxPackage",
            "Remove-AppxProvisionedPackage",
            "Add-AppxPackage",
            "DISM"
        )) {
            if (-not (Test-Path -LiteralPath "function:\$commandName")) {
                Set-Item -Path "function:\global:$commandName" -Value { }
            }
        }
    }

    It "records matching Defender state as unchanged" {
        $config = [pscustomobject]@{
            name = "DefenderRealtimeProtection"
            settingName = "DisableRealtimeMonitoring"
            expectedValue = $false
            required = $true
            failurePolicy = "fail"
        }
        $query = { [pscustomobject]@{ DisableRealtimeMonitoring = $false } }

        $result = @(Test-KitDefenderState -Config $config -DefenderQuery $query)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.reason "defender-state-ok"
        Assert-KitEqual $result.actualValue $false
    }

    It "fails required Defender mismatch" {
        $config = [pscustomobject]@{
            settingName = "DisableRealtimeMonitoring"
            expectedValue = $false
            required = $true
            failurePolicy = "fail"
        }
        $query = { [pscustomobject]@{ DisableRealtimeMonitoring = $true } }

        $result = @(Test-KitDefenderState -Config $config -DefenderQuery $query)[0]
        $summary = Get-KitDefenderResultSummary -Results @($result)

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "defender-state-mismatch"
        Assert-KitEqual $summary.exitCode 1
    }

    It "maps optional Defender skip policy to skipped" {
        $config = [pscustomobject]@{
            settingName = "DisableIOAVProtection"
            expectedValue = $false
            required = $false
            failurePolicy = "skip"
        }
        $query = { [pscustomobject]@{ DisableIOAVProtection = $true } }

        $result = @(Test-KitDefenderState -Config $config -DefenderQuery $query)[0]
        $summary = Get-KitDefenderResultSummary -Results @($result)

        Assert-KitEqual $result.status "skipped"
        Assert-KitEqual $result.skippedReason "defender-state-mismatch"
        Assert-KitEqual $summary.exitCode 0
    }

    It "maps optional Defender manual policy to manual" {
        $config = [pscustomobject]@{
            settingName = "DisableBehaviorMonitoring"
            expectedValue = $false
            required = $false
            failurePolicy = "manual"
        }
        $query = { [pscustomobject]@{ DisableBehaviorMonitoring = $true } }

        $result = @(Test-KitDefenderState -Config $config -DefenderQuery $query)[0]

        Assert-KitEqual $result.status "manual"
        Assert-KitEqual $result.manualAction "defender-state-mismatch"
    }

    It "records Defender WhatIf as not run without querying" {
        $config = [pscustomobject]@{
            settingName = "DisableRealtimeMonitoring"
            expectedValue = $false
        }
        $query = { throw "Defender query should not run during WhatIf." }

        $result = @(Test-KitDefenderState -Config $config -DefenderQuery $query -WhatIf)[0]
        $summary = Get-KitDefenderResultSummary -Results @($result)

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.whatIf $true
        Assert-KitEqual $summary.defenderNotRunCount 1
        Assert-KitEqual $summary.exitCode 0
    }

    It "returns structured Defender failure for query exceptions" {
        $config = [pscustomobject]@{
            settingName = "DisableRealtimeMonitoring"
            expectedValue = $false
        }
        $query = { throw "query failed" }

        $result = @(Test-KitDefenderState -Config $config -DefenderQuery $query)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "defender-query-failed"
        Assert-KitMatch $result.errors[0] "query failed"
    }

    It "summarizes Defender specific counters" {
        $results = @(
            (Test-KitDefenderState -Config ([pscustomobject]@{ settingName = "Ok"; expectedValue = $false }) -DefenderQuery { [pscustomobject]@{ Ok = $false } }),
            (Test-KitDefenderState -Config ([pscustomobject]@{ settingName = "Mismatch"; expectedValue = $false; required = $true }) -DefenderQuery { [pscustomobject]@{ Mismatch = $true } }),
            (Test-KitDefenderState -Config ([pscustomobject]@{ settingName = "Preview"; expectedValue = $false }) -WhatIf)
        )

        $summary = Get-KitDefenderResultSummary -Results $results
        $report = New-KitDefenderStateReport -Results $results

        Assert-KitEqual $summary.total 3
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.defenderCheckedCount 2
        Assert-KitEqual $summary.defenderMismatchCount 1
        Assert-KitEqual $summary.defenderNotRunCount 1
        Assert-KitEqual $report.defenderSummary.total 3
        Assert-KitEqual @($report.defenderResults).Count 3
    }

    It "uses mocked Defender query commands without invoking mutating Defender commands" {
        Mock Get-MpPreference { [pscustomobject]@{ DisableRealtimeMonitoring = $false } }
        Mock Set-MpPreference { throw "Set-MpPreference should not be called." }
        Mock Add-MpPreference { throw "Add-MpPreference should not be called." }
        Mock Remove-MpPreference { throw "Remove-MpPreference should not be called." }

        $config = [pscustomobject]@{
            settingName = "DisableRealtimeMonitoring"
            expectedValue = $false
        }

        $result = @(Test-KitDefenderState -Config $config)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-MockCalled Get-MpPreference -Times 1 -Exactly
        Assert-MockCalled Set-MpPreference -Times 0 -Exactly
        Assert-MockCalled Add-MpPreference -Times 0 -Exactly
        Assert-MockCalled Remove-MpPreference -Times 0 -Exactly
    }

    It "records matching absent AppX package as unchanged" {
        $config = [pscustomobject]@{
            packageName = "Microsoft.XboxGamingOverlay"
            scope = "allUsers"
            expectedState = "absent"
        }
        $query = {
            param([string]$PackageName, [string]$Scope, $AppxConfig)
            [pscustomobject]@{ Present = $false }
        }

        $result = @(Test-KitAppxState -Config $config -AppxQuery $query)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.reason "appx-state-ok"
        Assert-KitEqual $result.actualState "absent"
    }

    It "fails required AppX expected absent but present mismatch" {
        $config = [pscustomobject]@{
            packageName = "Microsoft.XboxGamingOverlay"
            scope = "allUsers"
            expectedState = "absent"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$PackageName, [string]$Scope, $AppxConfig)
            [pscustomobject]@{ Present = $true }
        }

        $result = @(Test-KitAppxState -Config $config -AppxQuery $query)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "appx-state-mismatch"
        Assert-KitEqual $result.actualState "present"
    }

    It "fails required AppX expected present but absent mismatch" {
        $config = [pscustomobject]@{
            packageName = "Microsoft.WindowsCalculator"
            scope = "provisioned"
            expectedState = "present"
            required = $true
        }
        $query = {
            param([string]$PackageName, [string]$Scope, $AppxConfig)
            [pscustomobject]@{ Present = $false }
        }

        $result = @(Test-KitAppxState -Config $config -AppxQuery $query)[0]
        $summary = Get-KitAppxResultSummary -Results @($result)

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "appx-state-mismatch"
        Assert-KitEqual $summary.exitCode 1
    }

    It "maps optional AppX skip and manual policies" {
        $query = {
            param([string]$PackageName, [string]$Scope, $AppxConfig)
            [pscustomobject]@{ Present = $true }
        }

        $skip = @(Test-KitAppxState -Config ([pscustomobject]@{ packageName = "OptionalSkip"; scope = "user"; expectedState = "absent"; required = $false; failurePolicy = "skip" }) -AppxQuery $query)[0]
        $manual = @(Test-KitAppxState -Config ([pscustomobject]@{ packageName = "OptionalManual"; scope = "user"; expectedState = "absent"; required = $false; failurePolicy = "manual" }) -AppxQuery $query)[0]

        Assert-KitEqual $skip.status "skipped"
        Assert-KitEqual $skip.skippedReason "appx-state-mismatch"
        Assert-KitEqual $manual.status "manual"
        Assert-KitEqual $manual.manualAction "appx-state-mismatch"
    }

    It "records AppX WhatIf as not run without querying" {
        $config = [pscustomobject]@{
            packageName = "PreviewAppx"
            scope = "allUsers"
            expectedState = "absent"
        }
        $query = { throw "AppX query should not run during WhatIf." }

        $result = @(Test-KitAppxState -Config $config -AppxQuery $query -WhatIf)[0]
        $summary = Get-KitAppxResultSummary -Results @($result)

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $summary.appxNotRunCount 1
        Assert-KitEqual $summary.exitCode 0
    }

    It "returns structured AppX failure for query exceptions" {
        $config = [pscustomobject]@{
            packageName = "QueryFailureAppx"
            scope = "allUsers"
            expectedState = "absent"
        }
        $query = { throw "query failed" }

        $result = @(Test-KitAppxState -Config $config -AppxQuery $query)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "appx-query-failed"
        Assert-KitMatch $result.errors[0] "query failed"
    }

    It "summarizes AppX specific counters" {
        $results = @(
            (Test-KitAppxState -Config ([pscustomobject]@{ packageName = "AbsentOk"; scope = "allUsers"; expectedState = "absent" }) -AppxQuery { param([string]$PackageName, [string]$Scope, $AppxConfig) [pscustomobject]@{ Present = $false } }),
            (Test-KitAppxState -Config ([pscustomobject]@{ packageName = "MismatchAppx"; scope = "allUsers"; expectedState = "absent"; required = $true }) -AppxQuery { param([string]$PackageName, [string]$Scope, $AppxConfig) [pscustomobject]@{ Present = $true } }),
            (Test-KitAppxState -Config ([pscustomobject]@{ packageName = "PreviewAppx"; scope = "allUsers"; expectedState = "absent" }) -WhatIf)
        )

        $summary = Get-KitAppxResultSummary -Results $results
        $report = New-KitAppxStateReport -Results $results

        Assert-KitEqual $summary.total 3
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.appxCheckedCount 2
        Assert-KitEqual $summary.appxMismatchCount 1
        Assert-KitEqual $summary.appxNotRunCount 1
        Assert-KitEqual $report.appxSummary.total 3
        Assert-KitEqual @($report.appxResults).Count 3
    }

    It "uses mocked AppX query commands without invoking mutating AppX commands or DISM" {
        Mock Get-AppxPackage { @() }
        Mock Get-AppxProvisionedPackage { @() }
        Mock Remove-AppxPackage { throw "Remove-AppxPackage should not be called." }
        Mock Remove-AppxProvisionedPackage { throw "Remove-AppxProvisionedPackage should not be called." }
        Mock Add-AppxPackage { throw "Add-AppxPackage should not be called." }
        Mock DISM { throw "DISM should not be called." }

        $config = [pscustomobject]@{
            packageName = "Microsoft.XboxGamingOverlay"
            scope = "allUsers"
            expectedState = "absent"
        }

        $result = @(Test-KitAppxState -Config $config)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-MockCalled Get-AppxPackage -Times 1 -Exactly
        Assert-MockCalled Get-AppxProvisionedPackage -Times 0 -Exactly
        Assert-MockCalled Remove-AppxPackage -Times 0 -Exactly
        Assert-MockCalled Remove-AppxProvisionedPackage -Times 0 -Exactly
        Assert-MockCalled Add-AppxPackage -Times 0 -Exactly
        Assert-MockCalled DISM -Times 0 -Exactly
    }

    It "writes AppX state report without querying during WhatIf" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-appx-state-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $manifestPath = Join-Path $tempRoot "appx.json"
        $reportPath = Join-Path $tempRoot "appx-report.json"

        try {
            ([ordered]@{
                policy = "audit-only"
                removeNamePatterns = @()
                keepNamePatterns = @()
                stateChecks = @(
                    [ordered]@{
                        packageName = "PreviewAppx"
                        scope = "allUsers"
                        expectedState = "absent"
                    }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

            & (Join-Path $script:RepoRoot "scripts\appx\Test-AppxState.ps1") -ManifestPath $manifestPath -ReportPath $reportPath -WhatIf

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-KitEqual $report.reportType "appx-state-verification"
            Assert-KitEqual $report.appxSummary.appxNotRunCount 1
            Assert-KitEqual @($report.appxResults).Count 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "links postdeploy Defender summary without embedding defenderResults" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-postdeploy-defender-link-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $pathsPath = Join-Path $tempRoot "paths.json"
        $scopePath = Join-Path $tempRoot "scope.json"
        $softwarePath = Join-Path $tempRoot "software.json"
        $junctionsPath = Join-Path $tempRoot "junctions.json"
        $servicesPath = Join-Path $tempRoot "services.json"
        $defenderPath = Join-Path $tempRoot "defender.json"
        $summaryPath = Join-Path $tempRoot "postdeploy-summary.json"
        $installerPath = Join-Path $tempRoot "postdeploy-installer.json"
        $defenderReportPath = Join-Path $tempRoot "postdeploy-defender.json"
        $junctionReportPath = Join-Path $tempRoot "postdeploy-junctions.json"
        $servicePath = Join-Path $tempRoot "postdeploy-services.json"
        $userExperiencePath = Join-Path $tempRoot "postdeploy-user-experience.json"
        $logPath = Join-Path $tempRoot "postdeploy.log"

        try {
            ([ordered]@{
                paths = [ordered]@{
                    DeployRoot = Join-Path $tempRoot "deploy"
                    PackageRoot = Join-Path $tempRoot "packages"
                    ToolRoot = Join-Path $tempRoot "tools"
                    DataRoot = Join-Path $tempRoot "data"
                }
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsPath -Encoding UTF8

            ([ordered]@{ packages = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $softwarePath -Encoding UTF8
            ([ordered]@{ junctions = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $junctionsPath -Encoding UTF8
            ([ordered]@{ services = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $servicesPath -Encoding UTF8
            ([ordered]@{
                paths = @()
                processes = @()
                stateChecks = @(
                    [ordered]@{
                        settingName = "DisableRealtimeMonitoring"
                        expectedValue = $false
                    }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $defenderPath -Encoding UTF8

            ([ordered]@{
                profile = "pester-defender-report-link"
                pathsManifest = $pathsPath
                system = [ordered]@{
                    contextMenu = [ordered]@{ enabled = $false }
                    explorerOptions = [ordered]@{ enabled = $false }
                    startMenu = [ordered]@{ enabled = $false }
                    windowsTerminal = [ordered]@{ enabled = $false }
                    defaultApps = [ordered]@{ enabled = $false }
                    vscodePortable = [ordered]@{ enabled = $false }
                    windowsDefender = [ordered]@{
                        mode = "enabled-with-exclusions"
                        exclusionsManifest = $defenderPath
                    }
                    huorong = [ordered]@{ install = $false }
                }
                appx = [ordered]@{
                    policy = "audit-only"
                    removeManifest = "manifests/appx-cleanup.json"
                    keepPatterns = @()
                }
                applications = [ordered]@{
                    softwareManifest = $softwarePath
                    servicesManifest = $servicesPath
                    junctionsManifest = $junctionsPath
                }
                reporting = [ordered]@{
                    build = [ordered]@{ enabled = $false }
                    postDeploy = [ordered]@{ enabled = $false }
                    validation = [ordered]@{ enabled = $false }
                }
                userInteraction = [ordered]@{
                    editableBeforeRun = $true
                    allowedChanges = @()
                }
            }) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $scopePath -Encoding UTF8

            & (Join-Path $script:RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1") `
                -WhatIf `
                -ScopeManifestPath $scopePath `
                -SummaryReportPath $summaryPath `
                -ReportPath $installerPath `
                -DefenderReportPath $defenderReportPath `
                -JunctionReportPath $junctionReportPath `
                -ServiceReportPath $servicePath `
                -UserExperienceReportPath $userExperiencePath `
                -LogPath $logPath

            $summaryReport = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $defenderReport = Get-Content -LiteralPath $defenderReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $defenderReference = @($summaryReport.defenderReports)[0]

            Assert-KitEqual $summaryReport.defenderReportPath $defenderReportPath
            Assert-KitEqual $defenderReference.exists $true
            Assert-KitEqual $defenderReference.defenderSummary.defenderNotRunCount 1
            Assert-KitEqual ($defenderReference.defenderSummary.PSObject.Properties.Name -contains "defenderResults") $false
            Assert-KitEqual $defenderReport.defenderSummary.defenderNotRunCount 1
            Assert-KitEqual @($defenderReport.defenderResults).Count 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}

