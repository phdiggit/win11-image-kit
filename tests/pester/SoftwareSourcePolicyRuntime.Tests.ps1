$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Software source policy runtime" {
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
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-source-policy-{0}" -f ([guid]::NewGuid().ToString("N")))
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

                [bool]$SilentInstall = $true
            )

            $softwareManifestPath = Join-Path $TempRoot "software.json"
            $stage = if ($Type -eq "installer") { "post-deploy" } else { "golden-image" }
            $package = [ordered]@{
                name = "runtime-policy-test"
                version = "1.0.0"
                enabled = $true
                category = "test"
                stage = $stage
                type = $Type
                required = [bool]$Policy.required
                failurePolicy = [string]$Policy.failurePolicy
                allowMissingSource = [bool]$Policy.allowMissingSource
                source = if ($Type -eq "installer") { '${PackageRoot}\missing.exe' } else { '${PackageRoot}\missing.zip' }
                destination = if ($Type -eq "installer") { 'C:\Program Files\RuntimePolicyTest' } else { '${ToolRoot}\runtime-policy-test' }
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

        $script:InvokeArchivePolicy = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy
            )

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $Policy -Type "archive"
            $stdoutPath = Join-Path $tempRoot "archive.stdout.txt"
            $stderrPath = Join-Path $tempRoot "archive.stderr.txt"

            & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File $script:ArchiveScript -ManifestPath $softwareManifestPath -PathsManifestPath $pathsManifestPath -Stage "golden-image" -WhatIf > $stdoutPath 2> $stderrPath
            $destinationPath = Join-Path (Join-Path $tempRoot "tools") "runtime-policy-test"

            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Stdout = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
                Stderr = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
                DestinationExists = Test-Path -LiteralPath $destinationPath
            }
        }

        $script:InvokeInstallerPolicy = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [bool]$SilentInstall = $true
            )

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $Policy -Type "installer" -SilentInstall $SilentInstall
            $reportPath = Join-Path $tempRoot "installer-report.json"
            $stdoutPath = Join-Path $tempRoot "installer.stdout.txt"
            $stderrPath = Join-Path $tempRoot "installer.stderr.txt"

            & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File $script:InstallerScript -ManifestPath $softwareManifestPath -PathsManifestPath $pathsManifestPath -ReportPath $reportPath -ReportRequired -WhatIf > $stdoutPath 2> $stderrPath

            $report = $null
            if (Test-Path -LiteralPath $reportPath) {
                $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            }

            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Stdout = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
                Stderr = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
                Report = $report
            }
        }
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "fails archive missing source when required" {
        $result = & $script:InvokeArchivePolicy -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch ($result.Stdout + $result.Stderr) "source-missing"
        Assert-KitEqual $result.DestinationExists $false
    }

    It "skips archive missing source when optional skip" {
        $result = & $script:InvokeArchivePolicy -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch ($result.Stdout + $result.Stderr) "source-missing"
        Assert-KitMatch ($result.Stdout + $result.Stderr) "skipped"
        Assert-KitEqual $result.DestinationExists $false
    }

    It "records archive missing source as manual when optional manual" {
        $result = & $script:InvokeArchivePolicy -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch ($result.Stdout + $result.Stderr) "source-missing"
        Assert-KitMatch ($result.Stdout + $result.Stderr) "manual"
        Assert-KitEqual $result.DestinationExists $false
    }

    It "writes failed installer report for required missing source" {
        $result = & $script:InvokeInstallerPolicy -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitNotNullOrEmpty $result.Report
        Assert-KitEqual $result.Report.items[0].status "failed"
        Assert-KitEqual $result.Report.items[0].reason "source-missing"
        Assert-KitEqual $result.Report.items[0].required $true
        Assert-KitEqual $result.Report.items[0].failurePolicy "fail"
        Assert-KitEqual $result.Report.items[0].allowMissingSource $false
        Assert-KitEqual ($result.Report.summary.failed -gt 0) $true
    }

    It "writes skipped installer report for optional skip missing source" {
        $result = & $script:InvokeInstallerPolicy -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.items[0].status "skipped"
        Assert-KitEqual $result.Report.items[0].reason "source-missing"
        Assert-KitEqual ($result.Report.summary.skipped -gt 0) $true
    }

    It "writes manual installer report for optional manual missing source" {
        $result = & $script:InvokeInstallerPolicy -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.items[0].status "manual"
        Assert-KitEqual $result.Report.items[0].reason "source-missing"
        Assert-KitEqual ($result.Report.summary.manual -gt 0) $true
    }

    It "fails silentInstall false when installer is required" {
        $result = & $script:InvokeInstallerPolicy -SilentInstall:$false -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitEqual $result.Report.items[0].status "failed"
        Assert-KitEqual $result.Report.items[0].reason "silent-install-required"
        Assert-KitEqual ($result.Report.summary.failed -gt 0) $true
    }
}
