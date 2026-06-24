$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Orchestrator package report links" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:TempRoots = @()

        $script:NewTempRoot = {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-package-links-{0}" -f ([guid]::NewGuid().ToString("N")))
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "packages"),(Join-Path $tempRoot "tools"),(Join-Path $tempRoot "deploy"),(Join-Path $tempRoot "data"),(Join-Path $tempRoot "config") -Force | Out-Null
            $script:TempRoots += $tempRoot
            return $tempRoot
        }

        $script:WritePathsManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot
            )

            $pathsManifestPath = Join-Path $TempRoot "paths.json"
            $pathsManifest = [ordered]@{
                '$schema' = '../schemas/paths.schema.json'
                paths = [ordered]@{
                    PackageRoot = Join-Path $TempRoot "packages"
                    ToolRoot = Join-Path $TempRoot "tools"
                    DeployRoot = Join-Path $TempRoot "deploy"
                    DataRoot = Join-Path $TempRoot "data"
                    ConfigRoot = Join-Path $TempRoot "config"
                }
            }
            $pathsManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsManifestPath -Encoding UTF8
            return $pathsManifestPath
        }

        $script:WriteSoftwareManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [string]$Type = "archive",

                [string]$Stage = "golden-image",

                [string]$Category = "test",

                [bool]$Required = $false,

                [string]$FailurePolicy = "skip",

                [bool]$AllowMissingSource = $true,

                [bool]$SilentInstall = $false
            )

            $softwareManifestPath = Join-Path $TempRoot "software.json"
            $extension = if ($Type -eq "installer") { "exe" } else { "zip" }
            $package = [ordered]@{
                name = "package-link-test"
                version = "1.0.0"
                enabled = $true
                category = $Category
                stage = $Stage
                type = $Type
                required = $Required
                failurePolicy = $FailurePolicy
                allowMissingSource = $AllowMissingSource
                source = '${PackageRoot}\missing.' + $extension
                destination = if ($Type -eq "installer") { 'C:\Program Files\PackageLinkTest' } else { '${ToolRoot}\package-link-test' }
            }

            if ($Type -eq "archive") {
                $package["archiveFormat"] = "zip"
            } elseif ($Type -eq "installer") {
                $package["installArgs"] = @()
                $package["silentInstall"] = $SilentInstall
                $package["successExitCodes"] = @(0)
            }

            $softwareManifest = [ordered]@{
                '$schema' = '../schemas/software.schema.json'
                packages = @($package)
            }
            $softwareManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $softwareManifestPath -Encoding UTF8
            return $softwareManifestPath
        }

        $script:WriteEmptyPostDeployManifests = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot
            )

            $junctionsPath = Join-Path $TempRoot "junctions.json"
            $servicesPath = Join-Path $TempRoot "services.json"
            ([ordered]@{ junctions = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $junctionsPath -Encoding UTF8
            ([ordered]@{ services = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $servicesPath -Encoding UTF8

            return [pscustomobject]@{
                JunctionsPath = $junctionsPath
                ServicesPath = $servicesPath
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

                [string]$JunctionsManifestPath = "manifests/junctions.json",

                [string]$ServicesManifestPath = "manifests/services.json"
            )

            $scopePath = Join-Path $TempRoot "scope.json"
            $scope = [ordered]@{
                '$schema' = '../schemas/customization-scope.schema.json'
                profile = "pester-package-report-links"
                pathsManifest = $PathsManifestPath
                system = [ordered]@{
                    contextMenu = [ordered]@{ enabled = $false }
                    explorerOptions = [ordered]@{ enabled = $false }
                    startMenu = [ordered]@{ enabled = $false }
                    windowsTerminal = [ordered]@{ enabled = $false }
                    defaultApps = [ordered]@{ enabled = $false }
                    vscodePortable = [ordered]@{ enabled = $false }
                    windowsDefender = [ordered]@{
                        mode = "disabled"
                        exclusionsManifest = "manifests/defender-exclusions.json"
                    }
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
            }
            $scope | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $scopePath -Encoding UTF8
            return $scopePath
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
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "links build package report summaries without embedding packageResults" {
        $tempRoot = & $script:NewTempRoot
        $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Type "archive" -Stage "golden-image" -Category "test"
        $scopePath = & $script:WriteScopeManifest -TempRoot $tempRoot -PathsManifestPath $pathsManifestPath -SoftwareManifestPath $softwareManifestPath
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
        Assert-KitNotNullOrEmpty $report.steps
        Assert-KitNotNullOrEmpty $report.stepResults
        Assert-KitNotNullOrEmpty $report.stepSummary
        Assert-KitEqual @($report.packageReports).Count 1
        Assert-KitEqual $report.packageReports[0].exists $true
        Assert-KitNotNullOrEmpty $report.packageReports[0].packageSummary
        Assert-KitEqual ($report.packageReports[0].PSObject.Properties.Name -contains "packageResults") $false
        Assert-KitEqual ($report.packageReports[0].packageSummary.PSObject.Properties.Name -contains "results") $false
        Assert-KitEqual $report.packageReports[0].packageSummary.exitCode 0
        Assert-KitEqual $report.packageReports[0].packageSummary.statusCounts.skipped 1
    }

    It "does not create build package reports for skipped package steps" {
        $tempRoot = & $script:NewTempRoot
        $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Type "archive" -Stage "golden-image" -Category "test"
        $scopePath = & $script:WriteScopeManifest -TempRoot $tempRoot -PathsManifestPath $pathsManifestPath -SoftwareManifestPath $softwareManifestPath
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
            "-SkipPortableApps",
            "-SkipSystemTweaks",
            "-SkipDevRuntime",
            "-SkipMiddleware"
        )

        Assert-KitEqual $result.ExitCode 0
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual @($report.packageReports).Count 0
        Assert-KitEqual @(Get-ChildItem -LiteralPath (Split-Path -Path $reportPath -Parent) -Filter "software-*-packages-*.json" -ErrorAction SilentlyContinue).Count 0
    }

    It "links postdeploy installer package summary without embedding packageResults" {
        $tempRoot = & $script:NewTempRoot
        $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Type "installer" -Stage "post-deploy" -Category "test" -FailurePolicy "manual" -AllowMissingSource $true -SilentInstall $false
        $postDeployManifests = & $script:WriteEmptyPostDeployManifests -TempRoot $tempRoot
        $scopePath = & $script:WriteScopeManifest `
            -TempRoot $tempRoot `
            -PathsManifestPath $pathsManifestPath `
            -SoftwareManifestPath $softwareManifestPath `
            -JunctionsManifestPath $postDeployManifests.JunctionsPath `
            -ServicesManifestPath $postDeployManifests.ServicesPath
        $summaryPath = Join-Path $tempRoot "reports\postdeploy-summary.json"
        $installerPath = Join-Path $tempRoot "reports\postdeploy-installer.json"
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
            "-UserExperienceReportPath",
            $userExperiencePath,
            "-LogPath",
            $logPath
        )

        Assert-KitEqual $result.ExitCode 0
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $summaryPath -ErrorAction SilentlyContinue)

        $report = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $report.installerReportPath $installerPath
        Assert-KitNotNullOrEmpty $report.steps
        Assert-KitNotNullOrEmpty $report.stepResults
        Assert-KitNotNullOrEmpty $report.stepSummary
        Assert-KitEqual @($report.packageReports).Count 1
        Assert-KitEqual $report.packageReports[0].path $installerPath
        Assert-KitEqual $report.packageReports[0].exists $true
        Assert-KitNotNullOrEmpty $report.packageReports[0].packageSummary
        Assert-KitEqual ($report.packageReports[0].PSObject.Properties.Name -contains "packageResults") $false
        Assert-KitEqual ($report.packageReports[0].packageSummary.PSObject.Properties.Name -contains "results") $false
        Assert-KitEqual ($report.packageReports[0].packageSummary.statusCounts.manual -gt 0) $true
    }
}
