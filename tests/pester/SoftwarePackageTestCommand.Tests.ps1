$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Software package testCommand results" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Install-KitSoftwarePackages.ps1")

        $script:TempRoots = @()

        $script:NewTempRoot = {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-test-command-{0}" -f ([guid]::NewGuid().ToString("N")))
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot "packages"),(Join-Path $tempRoot "tools"),(Join-Path $tempRoot "payload") -Force | Out-Null
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
                }
            }
            $pathsManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsManifestPath -Encoding UTF8
            return $pathsManifestPath
        }

        $script:WriteFakeCommand = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [Parameter(Mandatory)]
                [string]$Name,

                [int]$ExitCode = 0
            )

            $commandPath = Join-Path (Join-Path $TempRoot "packages") $Name
            @(
                "@echo off",
                "exit /b $ExitCode"
            ) | Set-Content -LiteralPath $commandPath -Encoding ASCII
            return $commandPath
        }

        $script:WriteArchive = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot
            )

            $sourcePath = Join-Path (Join-Path $TempRoot "packages") "source.zip"
            $payloadPath = Join-Path (Join-Path $TempRoot "payload") "marker.txt"
            Set-Content -LiteralPath $payloadPath -Value "payload" -Encoding ASCII
            Compress-Archive -LiteralPath $payloadPath -DestinationPath $sourcePath -Force
            return $sourcePath
        }

        $script:WriteSoftwareManifest = {
            param(
                [Parameter(Mandatory)]
                [string]$TempRoot,

                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [AllowNull()]
                [hashtable]$TestCommand = $null,

                [string]$Stage = "post-deploy"
            )

            & $script:WriteArchive -TempRoot $TempRoot | Out-Null
            $package = [ordered]@{
                name = "test-command-package"
                version = "1.0.0"
                enabled = $true
                category = "test"
                stage = $Stage
                type = "archive"
                required = [bool]$Policy.required
                failurePolicy = [string]$Policy.failurePolicy
                allowMissingSource = [bool]$Policy.allowMissingSource
                source = '${PackageRoot}\source.zip'
                destination = '${ToolRoot}\test-command-package'
                archiveFormat = "zip"
            }

            if ($null -ne $TestCommand) {
                $package["testCommand"] = $TestCommand
            }

            $softwareManifestPath = Join-Path $TempRoot "software.json"
            ([ordered]@{
                '$schema' = '../schemas/software.schema.json'
                packages = @($package)
            }) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $softwareManifestPath -Encoding UTF8
            return $softwareManifestPath
        }

        $script:InvokePackage = {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Policy,

                [AllowNull()]
                [hashtable]$TestCommand = $null,

                [string]$Stage = "post-deploy",

                [switch]$MissingSource,

                [switch]$WhatIf
            )

            $tempRoot = & $script:NewTempRoot
            $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
            $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $Policy -TestCommand $TestCommand -Stage $Stage
            if ($MissingSource) {
                Remove-Item -LiteralPath (Join-Path (Join-Path $tempRoot "packages") "source.zip") -Force
            }

            $reportPath = Join-Path $tempRoot "package-report.json"
            $thrown = $false
            try {
                Install-KitSoftwarePackages `
                    -ManifestPath $softwareManifestPath `
                    -PathsManifestPath $pathsManifestPath `
                    -Stage $Stage `
                    -IncludeTypes @("archive", "zip") `
                    -PackageReportPath $reportPath `
                    -PackageReportRequired `
                    -WhatIf:$WhatIf
            } catch {
                $thrown = $true
            }

            return [pscustomobject]@{
                Thrown = $thrown
                Report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
                DestinationExists = Test-Path -LiteralPath (Join-Path (Join-Path $tempRoot "tools") "test-command-package")
            }
        }
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "keeps package success behavior unchanged when testCommand is absent" {
        $result = & $script:InvokePackage -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.Thrown $false
        Assert-KitEqual $result.Report.packageResults[0].status "changed"
        Assert-KitEqual ($result.Report.packageResults[0].PSObject.Properties.Name -contains "testCommand") $false
        Assert-KitEqual $result.Report.packageSummary.testCommandRunCount 0
        Assert-KitEqual $result.DestinationExists $true
    }

    It "records successful testCommand and summary counts" {
        $tempRoot = & $script:NewTempRoot
        $commandPath = & $script:WriteFakeCommand -TempRoot $tempRoot -Name "test-pass.cmd" -ExitCode 0
        $policy = @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }
        $testCommand = @{
            command = $commandPath
            arguments = @()
            successExitCodes = @(0)
        }
        $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $softwareManifestPath = & $script:WriteSoftwareManifest -TempRoot $tempRoot -Policy $policy -TestCommand $testCommand
        $reportPath = Join-Path $tempRoot "success-report.json"

        Install-KitSoftwarePackages -ManifestPath $softwareManifestPath -PathsManifestPath $pathsManifestPath -Stage "post-deploy" -IncludeTypes @("archive", "zip") -PackageReportPath $reportPath -PackageReportRequired
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.packageResults[0].status "changed"
        Assert-KitEqual $report.packageResults[0].testCommand.status "success"
        Assert-KitEqual $report.packageSummary.testCommandRunCount 1
        Assert-KitEqual $report.packageSummary.testCommandSuccessCount 1
    }

    It "fails required package when testCommand fails" {
        $tempRoot = & $script:NewTempRoot
        $commandPath = & $script:WriteFakeCommand -TempRoot $tempRoot -Name "test-fail.cmd" -ExitCode 42
        $result = & $script:InvokePackage -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        } -TestCommand @{
            command = $commandPath
            successExitCodes = @(0)
        }

        Assert-KitEqual $result.Thrown $true
        Assert-KitEqual $result.Report.packageResults[0].status "failed"
        Assert-KitEqual $result.Report.packageResults[0].reason "test-command-failed"
        Assert-KitEqual $result.Report.packageResults[0].testCommand.status "failed"
        Assert-KitEqual $result.Report.packageSummary.exitCode 1
        Assert-KitEqual $result.Report.packageSummary.testCommandFailedCount 1
    }

    It "routes optional testCommand failure through skip and manual policies" {
        $tempRoot = & $script:NewTempRoot
        $commandPath = & $script:WriteFakeCommand -TempRoot $tempRoot -Name "test-optional-fail.cmd" -ExitCode 42
        $testCommand = @{
            command = $commandPath
            successExitCodes = @(0)
        }

        $skipResult = & $script:InvokePackage -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        } -TestCommand $testCommand
        $manualResult = & $script:InvokePackage -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        } -TestCommand $testCommand

        Assert-KitEqual $skipResult.Thrown $false
        Assert-KitEqual $skipResult.Report.packageResults[0].status "skipped"
        Assert-KitEqual $skipResult.Report.packageResults[0].skippedReason "test-command-failed"
        Assert-KitEqual $manualResult.Thrown $false
        Assert-KitEqual $manualResult.Report.packageResults[0].status "manual"
        Assert-KitEqual $manualResult.Report.packageResults[0].manualAction "inspect-test-command-failure"
    }

    It "honors custom testCommand successExitCodes" {
        $tempRoot = & $script:NewTempRoot
        $commandPath = & $script:WriteFakeCommand -TempRoot $tempRoot -Name "test-reboot-ok.cmd" -ExitCode 3010
        $result = & $script:InvokePackage -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        } -TestCommand @{
            command = $commandPath
            successExitCodes = @(0, 3010)
        }

        Assert-KitEqual $result.Thrown $false
        Assert-KitEqual $result.Report.packageResults[0].testCommand.status "success"
        Assert-KitEqual $result.Report.packageResults[0].testCommand.exitCode 3010
    }

    It "records notRun for WhatIf and non post-deploy stages" {
        $tempRoot = & $script:NewTempRoot
        $commandPath = & $script:WriteFakeCommand -TempRoot $tempRoot -Name "test-notrun.cmd" -ExitCode 0
        $testCommand = @{
            command = $commandPath
            successExitCodes = @(0)
        }
        $policy = @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        $whatIfResult = & $script:InvokePackage -Policy $policy -TestCommand $testCommand -WhatIf
        $buildResult = & $script:InvokePackage -Policy $policy -TestCommand $testCommand -Stage "golden-image"

        Assert-KitEqual $whatIfResult.Report.packageResults[0].testCommand.status "notRun"
        Assert-KitEqual $whatIfResult.Report.packageResults[0].testCommand.reason "whatif-preview"
        Assert-KitEqual $buildResult.Report.packageResults[0].testCommand.status "notRun"
        Assert-KitEqual $buildResult.Report.packageResults[0].testCommand.reason "stage-not-executable"
        Assert-KitEqual $buildResult.Report.packageSummary.testCommandNotRunCount 1
    }

    It "records notRun when package processing does not reach success" {
        $tempRoot = & $script:NewTempRoot
        $commandPath = & $script:WriteFakeCommand -TempRoot $tempRoot -Name "test-not-reached.cmd" -ExitCode 0
        $testCommand = @{
            command = $commandPath
            successExitCodes = @(0)
        }

        $failedResult = & $script:InvokePackage -MissingSource -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        } -TestCommand $testCommand
        $skippedResult = & $script:InvokePackage -MissingSource -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        } -TestCommand $testCommand
        $manualResult = & $script:InvokePackage -MissingSource -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        } -TestCommand $testCommand

        Assert-KitEqual $failedResult.Report.packageResults[0].testCommand.status "notRun"
        Assert-KitEqual $failedResult.Report.packageResults[0].testCommand.reason "package-not-successful"
        Assert-KitEqual $skippedResult.Report.packageResults[0].testCommand.status "notRun"
        Assert-KitEqual $manualResult.Report.packageResults[0].testCommand.status "notRun"
        Assert-KitEqual $manualResult.Report.packageSummary.testCommandNotRunCount 1
    }

    It "returns structured failure for test command exceptions" {
        $tempRoot = & $script:NewTempRoot
        $pathsManifestPath = & $script:WritePathsManifest -TempRoot $tempRoot
        $pathMap = Get-KitPathMap -ManifestPath $pathsManifestPath
        $result = Invoke-KitPackageTestCommand `
            -Package ([pscustomobject]@{
                name = "missing-command-test"
                testCommand = [pscustomobject]@{
                    command = (Join-Path $tempRoot "missing-command.exe")
                }
            }) `
            -PathMap $pathMap

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "exception"
        Assert-KitNotNullOrEmpty $result.error
    }
}
