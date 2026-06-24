$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Software package results" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:ArchiveScript = Join-Path $script:RepoRoot "scripts\build\Install-PortableApps.ps1"
        $script:InstallerScript = Join-Path $script:RepoRoot "scripts\postdeploy\Install-PostDeploySoftware.ps1"
        $script:TempRoots = @()

        $script:NewTempRoot = {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-package-results-{0}" -f ([guid]::NewGuid().ToString("N")))
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "packages"),(Join-Path $tempRoot "tools"),(Join-Path $tempRoot "deploy") -Force | Out-Null
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
                }
            }
            $pathsManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsManifestPath -Encoding UTF8
            return $pathsManifestPath
        }

        $script:WriteSoftwareManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [string]$Type = "archive",

                [bool]$SilentInstall = $true,

                [switch]$SourceExists
            )

            $softwareManifestPath = Join-Path $TempRoot "software.json"
            $stage = if ($Type -eq "installer") { "post-deploy" } else { "golden-image" }
            $extension = if ($Type -eq "installer") { "exe" } else { "zip" }
            $sourceName = if ($SourceExists) { "existing.$extension" } else { "missing.$extension" }
            $sourcePath = Join-Path (Join-Path $TempRoot "packages") $sourceName

            if ($SourceExists) {
                Set-Content -LiteralPath $sourcePath -Value "placeholder" -Encoding ASCII
            }

            $package = [ordered]@{
                name = "package-results-test"
                version = "1.0.0"
                enabled = $true
                category = "test"
                stage = $stage
                type = $Type
                required = [bool]$Policy.required
                failurePolicy = [string]$Policy.failurePolicy
                allowMissingSource = [bool]$Policy.allowMissingSource
                source = '${PackageRoot}\' + $sourceName
                destination = if ($Type -eq "installer") { 'C:\Program Files\PackageResultsTest' } else { '${ToolRoot}\package-results-test' }
            }

            if ($Type -eq "archive" -or $Type -eq "zip") {
                if ($Type -eq "archive") {
                    $package["archiveFormat"] = "zip"
                }
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

        $script:InvokeArchivePackageReport = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [switch]$SourceExists
            )

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $Policy -Type "archive" -SourceExists:$SourceExists
            $reportPath = Join-Path $tempRoot "archive-package-report.json"
            $stdoutPath = Join-Path $tempRoot "archive.stdout.txt"
            $stderrPath = Join-Path $tempRoot "archive.stderr.txt"

            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    $script:ArchiveScript,
                    "-ManifestPath",
                    $softwareManifestPath,
                    "-PathsManifestPath",
                    $pathsManifestPath,
                    "-Stage",
                    "golden-image",
                    "-PackageReportPath",
                    $reportPath,
                    "-PackageReportRequired",
                    "-WhatIf"
                ) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            $report = $null
            if (Test-Path -LiteralPath $reportPath) {
                $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            }

            return [pscustomobject]@{
                ExitCode = [int]$process.ExitCode
                Report = $report
                DestinationExists = Test-Path -LiteralPath (Join-Path (Join-Path $tempRoot "tools") "package-results-test")
            }
        }

        $script:InvokeInstallerReport = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [bool]$SilentInstall = $true,

                [switch]$SourceExists
            )

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $Policy -Type "installer" -SilentInstall $SilentInstall -SourceExists:$SourceExists
            $reportPath = Join-Path $tempRoot "installer-report.json"
            $stdoutPath = Join-Path $tempRoot "installer.stdout.txt"
            $stderrPath = Join-Path $tempRoot "installer.stderr.txt"

            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    $script:InstallerScript,
                    "-ManifestPath",
                    $softwareManifestPath,
                    "-PathsManifestPath",
                    $pathsManifestPath,
                    "-ReportPath",
                    $reportPath,
                    "-ReportRequired",
                    "-WhatIf"
                ) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            $report = $null
            if (Test-Path -LiteralPath $reportPath) {
                $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            }

            return [pscustomobject]@{
                ExitCode = [int]$process.ExitCode
                Report = $report
            }
        }
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes failed archive package result before required missing source throws" {
        $result = & $script:InvokeArchivePackageReport -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitNotNullOrEmpty $result.Report
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].reason "source-missing"
        Assert-KitEqual $result.Report.packageResults[0].required $true
        Assert-KitEqual $result.Report.packageSummary.exitCode 1
        Assert-KitEqual $result.DestinationExists $false
    }

    It "writes skipped archive package result for optional skip missing source" {
        $result = & $script:InvokeArchivePackageReport -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.packageResults[0].status "skipped"
        Assert-KitEqual $result.Report.packageResults[0].skippedReason "source-missing"
        Assert-KitEqual $result.Report.packageSummary.exitCode 0
    }

    It "writes manual archive package result for optional manual missing source" {
        $result = & $script:InvokeArchivePackageReport -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.packageResults[0].status "manual"
        Assert-KitEqual $result.Report.packageResults[0].manualAction "provide-source"
        Assert-KitEqual ($result.Report.packageSummary.statusCounts.manual -gt 0) $true
    }

    It "adds installer packageResults while preserving legacy report fields" {
        $result = & $script:InvokeInstallerReport -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitEqual $result.Report.items[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].reason "source-missing"
        Assert-KitEqual $result.Report.packageSummary.exitCode 1
    }

    It "maps optional installer skip and manual results into packageSummary" {
        $skipResult = & $script:InvokeInstallerReport -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }
        $manualResult = & $script:InvokeInstallerReport -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $skipResult.ExitCode 0
        Assert-KitEqual $skipResult.Report.packageResults[0].status "skipped"
        Assert-KitEqual $skipResult.Report.packageSummary.exitCode 0
        Assert-KitEqual $manualResult.ExitCode 0
        Assert-KitEqual $manualResult.Report.packageResults[0].status "manual"
        Assert-KitEqual ($manualResult.Report.packageSummary.statusCounts.manual -gt 0) $true
    }

    It "maps required silentInstall false installer to failed package result" {
        $result = & $script:InvokeInstallerReport -SilentInstall:$false -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitEqual $result.Report.items[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].reason "silent-install-required"
    }

    It "records WhatIf package result when source exists" {
        $result = & $script:InvokeArchivePackageReport -SourceExists -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.packageResults[0].status "whatif"
        Assert-KitEqual $result.Report.packageResults[0].reason "whatif-preview"
        Assert-KitEqual $result.Report.packageResults[0].whatIf $true
        Assert-KitEqual $result.Report.packageResults[0].changed $false
    }
}
