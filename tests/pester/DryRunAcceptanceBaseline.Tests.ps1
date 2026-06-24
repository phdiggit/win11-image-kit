$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Dry-run acceptance baseline" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitChildReportSummary.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:TempRoots = @()

        $script:NewTempRoot = {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-dryrun-acceptance-{0}" -f ([guid]::NewGuid().ToString("N")))
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            foreach ($name in @("packages", "tools", "deploy", "data", "config", "reports", "logs")) {
                New-Item -ItemType Directory -Path (Join-Path $tempRoot $name) -Force | Out-Null
            }
            $script:TempRoots += $tempRoot
            return $tempRoot
        }

        $script:WriteJson = {
            param(
                [Parameter(Mandatory)]
                [string]$Path,

                [Parameter(Mandatory)]
                $Value
            )

            $Value | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $Path -Encoding UTF8
            return $Path
        }

        $script:WritePathsManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot
            )

            & $script:WriteJson -Path (Join-Path $TempRoot "paths.json") -Value ([ordered]@{
                '$schema' = '../schemas/paths.schema.json'
                paths = [ordered]@{
                    PackageRoot = Join-Path $TempRoot "packages"
                    ToolRoot = Join-Path $TempRoot "tools"
                    DeployRoot = Join-Path $TempRoot "deploy"
                    DataRoot = Join-Path $TempRoot "data"
                    ConfigRoot = Join-Path $TempRoot "config"
                }
            })
        }

        $script:WriteSoftwareManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [ValidateSet("golden-image", "post-deploy")]
                [string]$Stage
            )

            $type = if ($Stage -eq "post-deploy") { "installer" } else { "archive" }
            $package = [ordered]@{
                name = "dryrun-acceptance-$Stage"
                version = "1.0.0"
                enabled = $true
                category = "acceptance"
                stage = $Stage
                type = $type
                required = $false
                failurePolicy = "manual"
                allowMissingSource = $true
                source = if ($type -eq "installer") { '${PackageRoot}\missing-installer.exe' } else { '${PackageRoot}\missing-archive.zip' }
                destination = if ($type -eq "installer") { '${ToolRoot}\dryrun-installer' } else { '${ToolRoot}\dryrun-archive' }
            }

            if ($type -eq "installer") {
                $package["silentInstall"] = $false
                $package["installArgs"] = @()
                $package["successExitCodes"] = @(0)
            } else {
                $package["archiveFormat"] = "zip"
            }

            & $script:WriteJson -Path (Join-Path $TempRoot "software-$Stage.json") -Value ([ordered]@{
                '$schema' = '../schemas/software.schema.json'
                packages = @($package)
            })
        }

        $script:WritePostDeployManifests = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot
            )

            $defenderPath = & $script:WriteJson -Path (Join-Path $TempRoot "defender-exclusions.json") -Value ([ordered]@{
                paths = @()
                processes = @()
                stateChecks = @(
                    [ordered]@{
                        name = "DryRunDefenderCheck"
                        settingName = "acceptance"
                        expectedValue = "restored"
                        required = $true
                        failurePolicy = "fail"
                    }
                )
            })

            $junctionPath = & $script:WriteJson -Path (Join-Path $TempRoot "junctions.json") -Value ([ordered]@{
                junctions = @(
                    [ordered]@{
                        description = "Dry-run acceptance junction"
                        source = '${DataRoot}\source'
                        target = '${DataRoot}\target'
                        required = $true
                        failurePolicy = "fail"
                    }
                )
            })

            $servicePath = & $script:WriteJson -Path (Join-Path $TempRoot "services.json") -Value ([ordered]@{
                services = @(
                    [ordered]@{
                        name = "DryRunAcceptanceService"
                        displayName = "Dry-run acceptance service"
                        install = 'cmd.exe /c exit 0'
                        required = $true
                        failurePolicy = "fail"
                    }
                )
            })

            return [pscustomobject]@{
                DefenderPath = $defenderPath
                JunctionPath = $junctionPath
                ServicePath = $servicePath
            }
        }

        $script:WriteScopeManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [Parameter(Mandatory)]
                [string]$PathsManifestPath,

                [Parameter(Mandatory)]
                [string]$SoftwareManifestPath,

                [string]$DefenderManifestPath,
                [string]$JunctionsManifestPath,
                [string]$ServicesManifestPath,
                [switch]$EnablePostDeploy
            )

            & $script:WriteJson -Path (Join-Path $TempRoot "scope.json") -Value ([ordered]@{
                '$schema' = '../schemas/customization-scope.schema.json'
                profile = "pester-dryrun-acceptance"
                pathsManifest = $PathsManifestPath
                system = [ordered]@{
                    contextMenu = [ordered]@{ enabled = $false }
                    explorerOptions = [ordered]@{
                        enabled = [bool]$EnablePostDeploy
                        showFileExtensions = $true
                        showHiddenFiles = $true
                        stateChecks = @(
                            [ordered]@{
                                name = "DryRunExplorerCheck"
                                domain = "explorer"
                                settingName = "资源管理器选项"
                                expectedValue = "restored"
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
                        mode = if ($EnablePostDeploy) { "enabled-with-exclusions" } else { "disabled" }
                        exclusionsManifest = $DefenderManifestPath
                    }
                    huorong = [ordered]@{ install = $false }
                }
                appx = [ordered]@{
                    policy = "audit-only"
                    removeManifest = "manifests/appx-cleanup.json"
                    keepPatterns = @()
                }
                applications = [ordered]@{
                    softwareManifest = $SoftwareManifestPath
                    servicesManifest = $ServicesManifestPath
                    junctionsManifest = $JunctionsManifestPath
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
            })
        }

        $script:InvokeProcess = {
            param(
                [Parameter(Mandatory)]
                [string[]]$ArgumentList,

                [Parameter(Mandatory)]
                [string]$TempRoot
            )

            $stdoutPath = Join-Path $TempRoot "process.stdout.txt"
            $stderrPath = Join-Path $TempRoot "process.stderr.txt"
            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList $ArgumentList `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            return [pscustomobject]@{
                ExitCode = [int]$process.ExitCode
                StdoutPath = $stdoutPath
                StderrPath = $stderrPath
            }
        }

        $script:AssertCompactChildReference = {
            param(
                [Parameter(Mandatory)]
                $Reference,

                [Parameter(Mandatory)]
                [string]$SummaryProperty,

                [Parameter(Mandatory)]
                [string]$ResultsProperty
            )

            Assert-KitNotNullOrEmpty $Reference
            Assert-KitNotNullOrEmpty $Reference.$SummaryProperty
            Assert-KitEqual ($Reference.PSObject.Properties.Name -contains $ResultsProperty) $false
            Assert-KitEqual ($Reference.$SummaryProperty.PSObject.Properties.Name -contains "results") $false
        }

        $script:NewFakeReference = {
            param(
                [Parameter(Mandatory)]
                [string]$SummaryProperty,

                [int]$FailedRequired = 0,
                [int]$FailedOptional = 0,
                [bool]$Required = $true,
                [bool]$Exists = $true,
                [string]$Error = ""
            )

            $reference = [ordered]@{
                name = "fake-child"
                stepName = "fake-step"
                reportType = "fake-report"
                path = "fake-child.json"
                required = $Required
                exists = $Exists
                error = $Error
            }

            if ($Exists -and [string]::IsNullOrWhiteSpace($Error)) {
                $reference[$SummaryProperty] = [pscustomobject]@{
                    failedRequiredCount = $FailedRequired
                    failedOptionalCount = $FailedOptional
                    statusCounts = [pscustomobject]@{
                        changed = 0
                        unchanged = 0
                        skipped = 0
                        manual = 0
                        whatif = 0
                        failed = $FailedRequired + $FailedOptional
                    }
                    hasBlockingFailure = $FailedRequired -gt 0
                    exitCode = if ($FailedRequired -gt 0) { 1 } else { 0 }
                }
            }

            [pscustomobject]$reference
        }
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes build WhatIf top-level report with StepResult and compact package child summary" {
        $tempRoot = & $script:NewTempRoot
        $pathsPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $softwarePath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Stage "golden-image"
        $scopePath = & $script:WriteScopeManifest -TempRoot $tempRoot -PathsManifestPath $pathsPath -SoftwareManifestPath $softwarePath
        $reportPath = Join-Path $tempRoot "reports\build-summary.json"
        $logPath = Join-Path $tempRoot "logs\build.log"
        $scriptPath = Join-Path $script:RepoRoot "scripts\build\Invoke-GoldenImageBuild.ps1"

        $result = & $script:InvokeProcess -TempRoot $tempRoot -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $scriptPath,
            "-WhatIf",
            "-ScopeManifestPath",
            $scopePath,
            "-ReportPath",
            $reportPath,
            "-LogPath",
            $logPath,
            "-SkipSystemTweaks",
            "-SkipDevRuntime",
            "-SkipMiddleware"
        )

        Assert-KitEqual $result.ExitCode 0
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $reportPath -ErrorAction SilentlyContinue)
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitNotNullOrEmpty $report.stepResults
        Assert-KitNotNullOrEmpty $report.stepSummary
        Assert-KitNotNullOrEmpty $report.packageReports
        Assert-KitNotNullOrEmpty $report.childReportSummary
        Assert-KitEqual $report.childReportSummary.hasBlockingFailure $false
        Assert-KitEqual $report.childReportSummary.exitCode 0
        Assert-KitEqual $report.childReportSummary.byType.package.reports 1
        & $script:AssertCompactChildReference -Reference @($report.packageReports)[0] -SummaryProperty "packageSummary" -ResultsProperty "packageResults"
    }

    It "writes postdeploy WhatIf top-level report with all dry-run child report types" {
        $tempRoot = & $script:NewTempRoot
        $pathsPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $softwarePath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Stage "post-deploy"
        $postDeployManifests = & $script:WritePostDeployManifests -TempRoot $tempRoot
        $scopePath = & $script:WriteScopeManifest `
            -TempRoot $tempRoot `
            -PathsManifestPath $pathsPath `
            -SoftwareManifestPath $softwarePath `
            -DefenderManifestPath $postDeployManifests.DefenderPath `
            -JunctionsManifestPath $postDeployManifests.JunctionPath `
            -ServicesManifestPath $postDeployManifests.ServicePath `
            -EnablePostDeploy
        $summaryPath = Join-Path $tempRoot "reports\postdeploy-summary.json"
        $installerPath = Join-Path $tempRoot "reports\postdeploy-installer.json"
        $defenderPath = Join-Path $tempRoot "reports\postdeploy-defender.json"
        $junctionPath = Join-Path $tempRoot "reports\postdeploy-junctions.json"
        $servicePath = Join-Path $tempRoot "reports\postdeploy-services.json"
        $userExperiencePath = Join-Path $tempRoot "reports\postdeploy-user-experience.json"
        $logPath = Join-Path $tempRoot "logs\postdeploy.log"
        $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1"

        $result = & $script:InvokeProcess -TempRoot $tempRoot -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $scriptPath,
            "-WhatIf",
            "-ScopeManifestPath",
            $scopePath,
            "-SummaryReportPath",
            $summaryPath,
            "-ReportPath",
            $installerPath,
            "-DefenderReportPath",
            $defenderPath,
            "-JunctionReportPath",
            $junctionPath,
            "-ServiceReportPath",
            $servicePath,
            "-UserExperienceReportPath",
            $userExperiencePath,
            "-LogPath",
            $logPath
        )

        Assert-KitEqual $result.ExitCode 0
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $summaryPath -ErrorAction SilentlyContinue)
        $report = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitNotNullOrEmpty $report.stepResults
        Assert-KitNotNullOrEmpty $report.stepSummary
        Assert-KitNotNullOrEmpty $report.packageReports
        Assert-KitNotNullOrEmpty $report.serviceReports
        Assert-KitNotNullOrEmpty $report.junctionReports
        Assert-KitNotNullOrEmpty $report.defenderReports
        Assert-KitNotNullOrEmpty $report.userExperienceReports
        Assert-KitNotNullOrEmpty $report.childReportSummary
        Assert-KitEqual $report.childReportSummary.reports 5
        Assert-KitEqual $report.childReportSummary.existing 5
        Assert-KitEqual $report.childReportSummary.hasBlockingFailure $false
        Assert-KitEqual $report.childReportSummary.exitCode 0
        foreach ($typeName in @("package", "service", "junction", "defender", "userExperience")) {
            Assert-KitEqual $report.childReportSummary.byType.$typeName.reports 1
        }
        Assert-KitEqual $report.childReportSummary.byType.appx.reports 0

        & $script:AssertCompactChildReference -Reference @($report.packageReports)[0] -SummaryProperty "packageSummary" -ResultsProperty "packageResults"
        & $script:AssertCompactChildReference -Reference @($report.serviceReports)[0] -SummaryProperty "serviceSummary" -ResultsProperty "serviceResults"
        & $script:AssertCompactChildReference -Reference @($report.junctionReports)[0] -SummaryProperty "junctionSummary" -ResultsProperty "junctionResults"
        & $script:AssertCompactChildReference -Reference @($report.defenderReports)[0] -SummaryProperty "defenderSummary" -ResultsProperty "defenderResults"
        & $script:AssertCompactChildReference -Reference @($report.userExperienceReports)[0] -SummaryProperty "userExperienceSummary" -ResultsProperty "userExperienceResults"

        if (@($report.stepResults | Where-Object { $_.status -eq "changed" -or $_.status -eq "completed" }).Count -gt 0) {
            throw "WhatIf steps must not be reported as changed/completed."
        }
    }

    It "maps required optional missing and parse-failed fake children into unified blocking summary" {
        $requiredFailure = Get-KitChildReportBlockingSummary -PackageReports @(
            (& $script:NewFakeReference -SummaryProperty "packageSummary" -FailedRequired 1 -Required $true)
        )
        Assert-KitEqual $requiredFailure.hasBlockingFailure $true
        Assert-KitEqual $requiredFailure.failedRequired 1
        Assert-KitEqual $requiredFailure.exitCode 1

        $optionalFailure = Get-KitChildReportBlockingSummary -PackageReports @(
            (& $script:NewFakeReference -SummaryProperty "packageSummary" -FailedOptional 1 -Required $false)
        )
        Assert-KitEqual $optionalFailure.hasBlockingFailure $false
        Assert-KitEqual $optionalFailure.failedOptional 1
        Assert-KitEqual $optionalFailure.exitCode 0

        $missingRequired = Get-KitChildReportBlockingSummary -PackageReports @(
            (& $script:NewFakeReference -SummaryProperty "packageSummary" -Exists $false -Required $true -Error "report-missing")
        )
        Assert-KitEqual $missingRequired.hasBlockingFailure $true
        Assert-KitEqual $missingRequired.missing 1
        Assert-KitEqual $missingRequired.exitCode 1

        $parseFailed = Get-KitChildReportBlockingSummary -PackageReports @(
            (& $script:NewFakeReference -SummaryProperty "packageSummary" -Exists $true -Required $true -Error "report-parse-failed")
        )
        Assert-KitEqual $parseFailed.hasBlockingFailure $true
        Assert-KitEqual $parseFailed.failedRequired 1
        Assert-KitEqual $parseFailed.exitCode 1
    }

    It "documents #6 result model and PR_READY acceptance terms" {
        $docPath = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "08-*.md" -ErrorAction SilentlyContinue)[0].FullName
        Assert-KitNotNullOrEmpty $docPath
        $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

        foreach ($term in @(
            "StepResult",
            "childReportSummary",
            "failedRequired",
            "failedOptional",
            "PR_READY",
            "Fast CI",
            "Full Validate",
            "Refs #6"
        )) {
            if (-not $doc.Contains($term)) {
                throw "Documentation is missing acceptance term: $term"
            }
        }
    }
}
