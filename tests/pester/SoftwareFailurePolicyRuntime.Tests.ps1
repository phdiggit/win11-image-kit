$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Software failure policy runtime" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-StepResult.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitPackageHash.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:ArchiveScript = Join-Path $script:RepoRoot "scripts\build\Install-PortableApps.ps1"
        $script:InstallerScript = Join-Path $script:RepoRoot "scripts\postdeploy\Install-PostDeploySoftware.ps1"
        $script:TempRoots = @()
        $script:WrongHash = "0000000000000000000000000000000000000000000000000000000000000000"

        $script:NewTempRoot = {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-failure-policy-{0}" -f ([guid]::NewGuid().ToString("N")))
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

                [string]$Sha256 = "",

                [int]$InstallerExitCode = 0,

                [int[]]$SuccessExitCodes = @(0),

                [string]$MarkerPath = "",

                [AllowEmptyString()]
                [string]$SourceOverride = "",

                [string[]]$InstallArgs = @()
            )

            $softwareManifestPath = Join-Path $TempRoot "software.json"
            $stage = if ($Type -eq "installer") { "post-deploy" } else { "golden-image" }
            $extension = if ($Type -eq "installer") { "cmd" } else { "zip" }
            $sourceName = "source.$extension"
            $sourcePath = Join-Path (Join-Path $TempRoot "packages") $sourceName

            if ($Type -eq "installer" -and [string]::IsNullOrWhiteSpace($SourceOverride)) {
                $lines = @("@echo off")
                if (-not [string]::IsNullOrWhiteSpace($MarkerPath)) {
                    $lines += "echo executed> `"$MarkerPath`""
                }
                $lines += "exit /b $InstallerExitCode"
                $lines | Set-Content -LiteralPath $sourcePath -Encoding ASCII
            } else {
                Set-Content -LiteralPath $sourcePath -Value "not a real archive" -Encoding ASCII
            }

            $package = [ordered]@{
                name = "failure-policy-test"
                version = "1.0.0"
                enabled = $true
                category = "test"
                stage = $stage
                type = $Type
                required = [bool]$Policy.required
                failurePolicy = [string]$Policy.failurePolicy
                allowMissingSource = [bool]$Policy.allowMissingSource
                source = if ([string]::IsNullOrWhiteSpace($SourceOverride)) { '${PackageRoot}\' + $sourceName } else { $SourceOverride }
                destination = if ($Type -eq "installer") { 'C:\Program Files\FailurePolicyTest' } else { '${ToolRoot}\failure-policy-test' }
            }

            if (-not [string]::IsNullOrWhiteSpace($Sha256)) {
                $package["sha256"] = $Sha256
            }

            if ($Type -eq "archive" -or $Type -eq "zip") {
                if ($Type -eq "archive") {
                    $package["archiveFormat"] = "zip"
                }
            } elseif ($Type -eq "installer") {
                $package["installArgs"] = @($InstallArgs)
                $package["silentInstall"] = $true
                $package["successExitCodes"] = @($SuccessExitCodes)
            }

            $softwareManifest = [ordered]@{
                '$schema' = '../schemas/software.schema.json'
                packages = @($package)
            }
            $softwareManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $softwareManifestPath -Encoding UTF8
            return [pscustomobject]@{
                ManifestPath = $softwareManifestPath
                SourcePath = $sourcePath
            }
        }

        $script:CanRunActualPostDeploy = {
            $tempRoot = & $script:NewTempRoot
            $stdoutPath = Join-Path $tempRoot "elevation.stdout.txt"
            $stderrPath = Join-Path $tempRoot "elevation.stderr.txt"
            $assertScript = Join-Path $script:RepoRoot "scripts\common\Assert-KitElevation.ps1"
            $command = @"
`$ErrorActionPreference = 'Stop'
. '$assertScript'
try {
    Assert-KitElevation -Operation 'pester actual installer check'
    exit 0
} catch {
    exit 1
}
"@
            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            return ([int]$process.ExitCode -eq 0)
        }

        $script:InvokeProcess = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [Parameter(Mandatory)]
                [string[]]$ArgumentList
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
                Stdout = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
                Stderr = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
            }
        }

        $script:InvokeArchive = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy
            )

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $manifestInfo = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $Policy -Type "archive" -Sha256 $script:WrongHash
            $reportPath = Join-Path $tempRoot "archive-report.json"
            $result = & $script:InvokeProcess -TempRoot $tempRoot -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                $script:ArchiveScript,
                "-ManifestPath",
                $manifestInfo.ManifestPath,
                "-PathsManifestPath",
                $pathsManifestPath,
                "-Stage",
                "golden-image",
                "-PackageReportPath",
                $reportPath,
                "-PackageReportRequired",
                "-WhatIf"
            )

            return [pscustomobject]@{
                ExitCode = $result.ExitCode
                Report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
                DestinationExists = Test-Path -LiteralPath (Join-Path (Join-Path $tempRoot "tools") "failure-policy-test")
            }
        }

        $script:InvokeInstaller = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [string]$Sha256 = "",

                [int]$InstallerExitCode = 0,

                [int[]]$SuccessExitCodes = @(0),

                [switch]$WhatIf,

                [switch]$RequireAdmin
            )

            if ($RequireAdmin -and -not (& $script:CanRunActualPostDeploy)) {
                return [pscustomobject]@{
                    SkippedActual = $true
                }
            }

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $markerPath = Join-Path $tempRoot "installer-marker.txt"
            $sourceOverride = ""
            $installArgs = @()
            if ($RequireAdmin) {
                $sourceOverride = $env:ComSpec
                if ([string]::IsNullOrWhiteSpace($sourceOverride)) {
                    $sourceOverride = Join-Path $env:SystemRoot "System32\cmd.exe"
                }
                $installArgs = @("/c", "exit", "/b", [string]$InstallerExitCode)
            }

            $manifestInfo = & $script:WriteSoftwareManifest `
                -TempRoot $tempRoot `
                -Policy $Policy `
                -Type "installer" `
                -Sha256 $Sha256 `
                -InstallerExitCode $InstallerExitCode `
                -SuccessExitCodes $SuccessExitCodes `
                -MarkerPath $markerPath `
                -SourceOverride $sourceOverride `
                -InstallArgs $installArgs
            $reportPath = Join-Path $tempRoot "installer-report.json"
            $arguments = @(
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                $script:InstallerScript,
                "-ManifestPath",
                $manifestInfo.ManifestPath,
                "-PathsManifestPath",
                $pathsManifestPath,
                "-ReportPath",
                $reportPath,
                "-ReportRequired"
            )
            if ($WhatIf) {
                $arguments += "-WhatIf"
            }

            $result = & $script:InvokeProcess -TempRoot $tempRoot -ArgumentList $arguments

            return [pscustomobject]@{
                SkippedActual = $false
                ExitCode = $result.ExitCode
                Report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
                MarkerExists = Test-Path -LiteralPath $markerPath
            }
        }
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "keeps structured hash helper results without breaking throw behavior" {
        $tempRoot = & $script:NewTempRoot
        $source = Join-Path $tempRoot "hash.txt"
        Set-Content -LiteralPath $source -Value "hash input" -Encoding ASCII

        $invalid = Test-KitPackageHash -Source $source -ExpectedHash "not-a-sha" -PassThru
        Assert-KitEqual $invalid.status "failed"
        Assert-KitEqual $invalid.reason "hash-invalid"

        Assert-KitThrows { Test-KitPackageHash -Source $source -ExpectedHash $script:WrongHash } "SHA256"
    }

    It "fails required archive hash mismatch before archive processing" {
        $result = & $script:InvokeArchive -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].reason "hash-mismatch"
        Assert-KitEqual $result.Report.packageSummary.exitCode 1
        Assert-KitEqual $result.DestinationExists $false
    }

    It "skips optional archive hash mismatch" {
        $result = & $script:InvokeArchive -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.packageResults[0].status "skipped"
        Assert-KitEqual $result.Report.packageResults[0].reason "hash-mismatch"
        Assert-KitEqual $result.Report.packageResults[0].skippedReason "hash-mismatch"
    }

    It "records optional archive hash mismatch as manual" {
        $result = & $script:InvokeArchive -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.packageResults[0].status "manual"
        Assert-KitEqual $result.Report.packageResults[0].reason "hash-mismatch"
        Assert-KitEqual $result.Report.packageResults[0].manualAction "verify-or-replace-source"
    }

    It "fails required installer hash mismatch and does not run the installer" {
        $result = & $script:InvokeInstaller -WhatIf -Sha256 $script:WrongHash -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitEqual $result.Report.items[0].status "failed"
        Assert-KitEqual $result.Report.items[0].reason "hash-mismatch"
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].reason "hash-mismatch"
        Assert-KitEqual $result.MarkerExists $false
    }

    It "routes optional installer hash mismatch to skip and manual" {
        $skipResult = & $script:InvokeInstaller -WhatIf -Sha256 $script:WrongHash -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }
        $manualResult = & $script:InvokeInstaller -WhatIf -Sha256 $script:WrongHash -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $skipResult.ExitCode 0
        Assert-KitEqual $skipResult.Report.items[0].status "skipped"
        Assert-KitEqual $skipResult.Report.packageResults[0].status "skipped"
        Assert-KitEqual $manualResult.ExitCode 0
        Assert-KitEqual $manualResult.Report.items[0].status "manual"
        Assert-KitEqual $manualResult.Report.packageResults[0].manualAction "verify-or-replace-source"
    }

    It "fails required installer unexpected exit code" {
        $result = & $script:InvokeInstaller -RequireAdmin -InstallerExitCode 42 -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }
        if ($result.SkippedActual) {
            return
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitEqual $result.Report.items[0].status "failed"
        Assert-KitEqual $result.Report.items[0].reason "unexpected-exit-code"
        Assert-KitEqual $result.Report.items[0].exitCode 42
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageSummary.exitCode 1
    }

    It "routes optional installer unexpected exit code to skip and manual" {
        $skipResult = & $script:InvokeInstaller -RequireAdmin -InstallerExitCode 42 -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }
        if ($skipResult.SkippedActual) {
            return
        }

        $manualResult = & $script:InvokeInstaller -RequireAdmin -InstallerExitCode 42 -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $skipResult.ExitCode 0
        Assert-KitEqual $skipResult.Report.items[0].status "skipped"
        Assert-KitEqual $skipResult.Report.packageResults[0].status "skipped"
        Assert-KitEqual $skipResult.Report.packageResults[0].evidence.exitCode 42
        Assert-KitEqual $manualResult.ExitCode 0
        Assert-KitEqual $manualResult.Report.items[0].status "manual"
        Assert-KitEqual $manualResult.Report.packageResults[0].manualAction "inspect-installer-failure"
    }

    It "marks successful reboot-required installer exit codes" {
        $result = & $script:InvokeInstaller -RequireAdmin -InstallerExitCode 3010 -SuccessExitCodes @(0, 3010) -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }
        if ($result.SkippedActual) {
            $summary = Get-KitStepResultSummary -Results @(
                (New-KitStepResult -Name "installer" -Status changed -RebootRequired $true)
            )
            Assert-KitEqual $summary.rebootRequiredCount 1
            return
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitEqual $result.Report.items[0].status "succeeded"
        Assert-KitEqual $result.Report.items[0].rebootRequired $true
        Assert-KitEqual $result.Report.packageResults[0].status "changed"
        Assert-KitEqual $result.Report.packageResults[0].rebootRequired $true
        Assert-KitEqual ($result.Report.packageSummary.rebootRequiredCount -gt 0) $true
    }
}
