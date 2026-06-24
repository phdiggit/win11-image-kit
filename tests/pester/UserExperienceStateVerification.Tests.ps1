$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "User experience config state verification results" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitConfigState.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        foreach ($commandName in @("reg.exe", "dism.exe")) {
            if (-not (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) {
                Set-Item -Path "function:\global:$commandName" -Value { }
            }
        }
    }

    It "records matching config state as unchanged" {
        $config = [pscustomobject]@{
            name = "ExplorerShowFileExtensions"
            domain = "explorer"
            settingName = "HideFileExt"
            expectedValue = 0
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param($Check, [string]$Domain, [string]$SettingName)
            [pscustomobject]@{ found = $true; value = 0 }
        }

        $result = @(Test-KitConfigState -Config $config -ConfigQuery $query)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.reason "config-state-ok"
        Assert-KitEqual $result.domain "explorer"
        Assert-KitEqual $result.actualValue 0
    }

    It "fails required config mismatch" {
        $config = [pscustomobject]@{
            name = "ExplorerShowHiddenFiles"
            domain = "explorer"
            settingName = "Hidden"
            expectedValue = 1
            required = $true
            failurePolicy = "fail"
        }
        $query = { [pscustomobject]@{ found = $true; value = 2 } }

        $result = @(Test-KitConfigState -Config $config -ConfigQuery $query)[0]
        $summary = Get-KitConfigStateResultSummary -Results @($result)

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "config-state-mismatch"
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.configMismatchCount 1
        Assert-KitEqual $summary.exitCode 1
    }

    It "fails required config when state is missing" {
        $config = [pscustomobject]@{
            name = "DefaultAppsImported"
            domain = "defaultApps"
            settingName = "默认应用关联"
            expectedValue = "succeeded"
            required = $true
            failurePolicy = "fail"
        }
        $query = { [pscustomobject]@{ found = $false; value = $null } }

        $result = @(Test-KitConfigState -Config $config -ConfigQuery $query)[0]
        $summary = Get-KitConfigStateResultSummary -Results @($result)

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "config-state-missing"
        Assert-KitEqual $summary.configMissingCount 1
        Assert-KitEqual $summary.exitCode 1
    }

    It "maps optional skip and manual policies" {
        $query = { [pscustomobject]@{ found = $true; value = "missing" } }

        $skip = @(Test-KitConfigState -Config ([pscustomobject]@{
            name = "OptionalStartMenu"
            domain = "startMenu"
            settingName = "开始菜单默认布局"
            expectedValue = "succeeded"
            required = $false
            failurePolicy = "skip"
        }) -ConfigQuery $query)[0]
        $manual = @(Test-KitConfigState -Config ([pscustomobject]@{
            name = "OptionalTerminal"
            domain = "terminal"
            settingName = "Windows Terminal 配置模板"
            expectedValue = "succeeded"
            required = $false
            failurePolicy = "manual"
        }) -ConfigQuery $query)[0]

        Assert-KitEqual $skip.status "skipped"
        Assert-KitEqual $skip.skippedReason "config-state-mismatch"
        Assert-KitEqual $manual.status "manual"
        Assert-KitEqual $manual.manualAction "config-state-mismatch"
    }

    It "records WhatIf as not run without querying" {
        $config = [pscustomobject]@{
            name = "PreviewTerminal"
            domain = "terminal"
            settingName = "Windows Terminal 配置模板"
            expectedValue = "succeeded"
        }
        $query = { throw "Config query should not run during WhatIf." }

        $result = @(Test-KitConfigState -Config $config -ConfigQuery $query -WhatIf)[0]
        $summary = Get-KitConfigStateResultSummary -Results @($result)

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.whatIf $true
        Assert-KitEqual $summary.configNotRunCount 1
        Assert-KitEqual $summary.exitCode 0
    }

    It "returns structured config failure for query exceptions" {
        $config = [pscustomobject]@{
            name = "QueryFailureContextMenu"
            domain = "contextMenu"
            settingName = "VSCodeOpenHere"
            expectedValue = "succeeded"
        }
        $query = { throw "query failed" }

        $result = @(Test-KitConfigState -Config $config -ConfigQuery $query)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "config-query-failed"
        Assert-KitMatch $result.errors[0] "query failed"
    }

    It "summarizes config counters and report results" {
        $results = @(
            (Test-KitConfigState -Config ([pscustomobject]@{ name = "Ok"; domain = "explorer"; settingName = "HideFileExt"; expectedValue = 0 }) -ConfigQuery { [pscustomobject]@{ found = $true; value = 0 } }),
            (Test-KitConfigState -Config ([pscustomobject]@{ name = "Mismatch"; domain = "explorer"; settingName = "Hidden"; expectedValue = 1; required = $true }) -ConfigQuery { [pscustomobject]@{ found = $true; value = 2 } }),
            (Test-KitConfigState -Config ([pscustomobject]@{ name = "Preview"; domain = "terminal"; settingName = "Windows Terminal 配置模板"; expectedValue = "succeeded" }) -WhatIf)
        )

        $summary = Get-KitConfigStateResultSummary -Results $results
        $report = New-KitConfigStateReport -Results $results

        Assert-KitEqual $summary.total 3
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.configCheckedCount 2
        Assert-KitEqual $summary.configMismatchCount 1
        Assert-KitEqual $summary.configNotRunCount 1
        Assert-KitEqual $summary.explorerMismatchCount 1
        Assert-KitEqual $report.configSummary.total 3
        Assert-KitEqual @($report.configResults).Count 3
    }

    It "writes user experience state results and links top-level summary without embedding results" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-user-experience-state-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $pathsPath = Join-Path $tempRoot "paths.json"
        $scopePath = Join-Path $tempRoot "scope.json"
        $softwarePath = Join-Path $tempRoot "software.json"
        $junctionsPath = Join-Path $tempRoot "junctions.json"
        $servicesPath = Join-Path $tempRoot "services.json"
        $summaryPath = Join-Path $tempRoot "postdeploy-summary.json"
        $installerPath = Join-Path $tempRoot "postdeploy-installer.json"
        $userExperiencePath = Join-Path $tempRoot "postdeploy-user-experience.json"
        $logPath = Join-Path $tempRoot "postdeploy.log"

        try {
            ([ordered]@{
                paths = [ordered]@{
                    DeployRoot = Join-Path $tempRoot "deploy"
                    PackageRoot = Join-Path $tempRoot "packages"
                    ToolRoot = Join-Path $tempRoot "tools"
                    DataRoot = Join-Path $tempRoot "data"
                    ConfigRoot = Join-Path $tempRoot "config"
                }
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsPath -Encoding UTF8

            ([ordered]@{ packages = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $softwarePath -Encoding UTF8
            ([ordered]@{ junctions = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $junctionsPath -Encoding UTF8
            ([ordered]@{ services = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $servicesPath -Encoding UTF8

            ([ordered]@{
                profile = "pester-user-experience-state"
                pathsManifest = $pathsPath
                system = [ordered]@{
                    contextMenu = [ordered]@{ enabled = $false }
                    explorerOptions = [ordered]@{
                        enabled = $true
                        showFileExtensions = $true
                        showHiddenFiles = $true
                        stateChecks = @(
                            [ordered]@{
                                name = "ExplorerOptionsRestored"
                                domain = "explorer"
                                settingName = "资源管理器选项"
                                expectedValue = "succeeded"
                                required = $true
                                failurePolicy = "fail"
                            }
                        )
                    }
                    startMenu = [ordered]@{ enabled = $false }
                    windowsTerminal = [ordered]@{ enabled = $false }
                    defaultApps = [ordered]@{ enabled = $false }
                    vscodePortable = [ordered]@{ enabled = $false }
                    windowsDefender = [ordered]@{
                        mode = "disabled"
                        exclusionsManifest = "manifests/defender-exclusions.json"
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
                -UserExperienceReportPath $userExperiencePath `
                -LogPath $logPath

            $summaryReport = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $userExperienceReport = Get-Content -LiteralPath $userExperiencePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $userExperienceReference = @($summaryReport.userExperienceReports)[0]

            Assert-KitEqual $summaryReport.userExperienceReportPath $userExperiencePath
            Assert-KitEqual $userExperienceReference.exists $true
            Assert-KitEqual $userExperienceReference.userExperienceSummary.configNotRunCount 1
            Assert-KitEqual ($userExperienceReference.userExperienceSummary.PSObject.Properties.Name -contains "userExperienceResults") $false
            Assert-KitEqual $userExperienceReport.userExperienceSummary.configNotRunCount 1
            Assert-KitEqual @($userExperienceReport.userExperienceResults).Count 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "uses mocked query without invoking mutating UI configuration commands" {
        Mock Get-ItemProperty { [pscustomobject]@{ HideFileExt = 0 } }
        Mock Set-ItemProperty { throw "Set-ItemProperty should not be called." }
        Mock New-ItemProperty { throw "New-ItemProperty should not be called." }
        Mock Remove-ItemProperty { throw "Remove-ItemProperty should not be called." }
        Mock reg.exe { throw "reg.exe should not be called." }
        Mock dism.exe { throw "dism.exe should not be called." }
        Mock Copy-Item { throw "Copy-Item should not be called for real user paths." } -ParameterFilter {
            $target = [string]$Destination
            $tempRoot = [IO.Path]::GetTempPath()
            $target -like "$env:USERPROFILE*" -and $target -notlike "$tempRoot*"
        }
        Mock Set-Content { throw "Set-Content should not be called for real user paths." } -ParameterFilter {
            $target = if (-not [string]::IsNullOrWhiteSpace([string]$LiteralPath)) { [string]$LiteralPath } else { [string]$Path }
            $tempRoot = [IO.Path]::GetTempPath()
            $target -like "$env:USERPROFILE*" -and $target -notlike "$tempRoot*"
        }
        Mock Remove-Item { throw "Remove-Item should not be called for real user paths." } -ParameterFilter {
            $target = if (-not [string]::IsNullOrWhiteSpace([string]$LiteralPath)) { [string]$LiteralPath } else { [string]$Path }
            $tempRoot = [IO.Path]::GetTempPath()
            $target -like "$env:USERPROFILE*" -and $target -notlike "$tempRoot*"
        }

        $config = [pscustomobject]@{
            name = "ExplorerShowFileExtensions"
            domain = "explorer"
            settingName = "HideFileExt"
            expectedValue = 0
        }
        $query = { [pscustomobject]@{ found = $true; value = 0 } }

        $result = @(Test-KitConfigState -Config $config -ConfigQuery $query)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-MockCalled Get-ItemProperty -Times 0 -Exactly
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly
        Assert-MockCalled New-ItemProperty -Times 0 -Exactly
        Assert-MockCalled Remove-ItemProperty -Times 0 -Exactly
        Assert-MockCalled reg.exe -Times 0 -Exactly
        Assert-MockCalled dism.exe -Times 0 -Exactly
        Assert-MockCalled Copy-Item -Times 0 -Exactly -ParameterFilter {
            $target = [string]$Destination
            $tempRoot = [IO.Path]::GetTempPath()
            $target -like "$env:USERPROFILE*" -and $target -notlike "$tempRoot*"
        }
        Assert-MockCalled Set-Content -Times 0 -Exactly -ParameterFilter {
            $target = if (-not [string]::IsNullOrWhiteSpace([string]$LiteralPath)) { [string]$LiteralPath } else { [string]$Path }
            $tempRoot = [IO.Path]::GetTempPath()
            $target -like "$env:USERPROFILE*" -and $target -notlike "$tempRoot*"
        }
        Assert-MockCalled Remove-Item -Times 0 -Exactly -ParameterFilter {
            $target = if (-not [string]::IsNullOrWhiteSpace([string]$LiteralPath)) { [string]$LiteralPath } else { [string]$Path }
            $tempRoot = [IO.Path]::GetTempPath()
            $target -like "$env:USERPROFILE*" -and $target -notlike "$tempRoot*"
        }
    }
}
