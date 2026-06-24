$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Junction state verification results" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitJunctionState.ps1")
        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }
    }

    It "records matching junction target as unchanged" {
        $junction = [pscustomobject]@{
            name = "UserDataJunction"
            source = "C:\Users\hao\AppData\Local\Example"
            target = "D:\Data\Example"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Data\Example\"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" }
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.reason "junction-state-ok"
        Assert-KitEqual $result.exists $true
        Assert-KitEqual $result.isJunction $true
        Assert-KitEqual $result.actualTarget "D:\Data\Example\"
    }

    It "fails required missing junction path" {
        $junction = [pscustomobject]@{
            name = "MissingJunction"
            source = "C:\Missing"
            target = "D:\Data\Missing"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $false; IsJunction = $false; Target = ""; LinkType = ""; Attributes = "" }
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query
        $summary = Get-KitJunctionResultSummary -Results @($result)

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-missing"
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.exitCode 1
    }

    It "fails required path that is not a junction" {
        $junction = [pscustomobject]@{
            name = "PlainDirectory"
            source = "C:\Plain"
            target = "D:\Data\Plain"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $true; IsJunction = $false; Target = ""; LinkType = ""; Attributes = "Directory" }
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-not-junction"
        Assert-KitEqual $result.exists $true
        Assert-KitEqual $result.isJunction $false
    }

    It "fails required junction target mismatch" {
        $junction = [pscustomobject]@{
            name = "MismatchJunction"
            source = "C:\Source"
            target = "D:\Data\Expected"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Data\Actual"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" }
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-target-mismatch"
        Assert-KitMatch $result.errors[0] "expectedTarget=D:\\Data\\Expected"
    }

    It "maps optional skip policy to skipped" {
        $junction = [pscustomobject]@{
            name = "OptionalSkipJunction"
            source = "C:\OptionalSkip"
            target = "D:\Data\OptionalSkip"
            required = $false
            failurePolicy = "skip"
        }
        $query = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $false; IsJunction = $false; Target = ""; LinkType = ""; Attributes = "" }
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query
        $summary = Get-KitJunctionResultSummary -Results @($result)

        Assert-KitEqual $result.status "skipped"
        Assert-KitEqual $result.skippedReason "junction-missing"
        Assert-KitEqual $summary.exitCode 0
    }

    It "maps optional manual policy to manual" {
        $junction = [pscustomobject]@{
            name = "OptionalManualJunction"
            source = "C:\OptionalManual"
            target = "D:\Data\OptionalManual"
            required = $false
            failurePolicy = "manual"
        }
        $query = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $true; IsJunction = $false; Target = ""; LinkType = ""; Attributes = "Directory" }
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query

        Assert-KitEqual $result.status "manual"
        Assert-KitEqual $result.manualAction "junction-not-junction"
    }

    It "records WhatIf as not run without querying" {
        $junction = [pscustomobject]@{
            name = "PreviewJunction"
            source = "C:\Preview"
            target = "D:\Data\Preview"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            throw "Junction query should not run during WhatIf."
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query -WhatIf
        $summary = Get-KitJunctionResultSummary -Results @($result)

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.reason "whatif-preview"
        Assert-KitEqual $result.whatIf $true
        Assert-KitEqual $result.changed $false
        Assert-KitEqual $summary.junctionNotRunCount 1
        Assert-KitEqual $summary.exitCode 0
    }

    It "returns structured failure for query exceptions" {
        $junction = [pscustomobject]@{
            name = "QueryFailureJunction"
            source = "C:\QueryFailure"
            target = "D:\Data\QueryFailure"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            throw "query failed"
        }

        $result = Test-KitJunctionState -JunctionConfig $junction -JunctionQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-query-failed"
        Assert-KitMatch $result.errors[0] "query failed"
    }

    It "summarizes junction specific counters" {
        $results = @(
            (Test-KitJunctionState -JunctionConfig ([pscustomobject]@{ name = "OkJunction"; source = "C:\Ok"; target = "D:\Ok" }) -JunctionQuery { param([string]$Path, $JunctionConfig) [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Ok"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" } }),
            (Test-KitJunctionState -JunctionConfig ([pscustomobject]@{ name = "MissingJunction"; source = "C:\Missing"; target = "D:\Missing"; required = $true }) -JunctionQuery { param([string]$Path, $JunctionConfig) [pscustomobject]@{ Exists = $false; IsJunction = $false; Target = ""; LinkType = ""; Attributes = "" } }),
            (Test-KitJunctionState -JunctionConfig ([pscustomobject]@{ name = "NotJunction"; source = "C:\Plain"; target = "D:\Plain"; required = $false; failurePolicy = "skip" }) -JunctionQuery { param([string]$Path, $JunctionConfig) [pscustomobject]@{ Exists = $true; IsJunction = $false; Target = ""; LinkType = ""; Attributes = "Directory" } }),
            (Test-KitJunctionState -JunctionConfig ([pscustomobject]@{ name = "MismatchJunction"; source = "C:\Mismatch"; target = "D:\Expected"; required = $false; failurePolicy = "manual" }) -JunctionQuery { param([string]$Path, $JunctionConfig) [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Actual"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" } }),
            (Test-KitJunctionState -JunctionConfig ([pscustomobject]@{ name = "PreviewJunction"; source = "C:\Preview"; target = "D:\Preview" }) -WhatIf)
        )

        $summary = Get-KitJunctionResultSummary -Results $results
        $report = New-KitJunctionStateReport -Results $results

        Assert-KitEqual $summary.total 5
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.junctionCheckedCount 4
        Assert-KitEqual $summary.junctionMissingCount 1
        Assert-KitEqual $summary.junctionNotJunctionCount 1
        Assert-KitEqual $summary.junctionTargetMismatchCount 1
        Assert-KitEqual $summary.junctionNotRunCount 1
        Assert-KitEqual $report.junctionSummary.total 5
        Assert-KitEqual @($report.junctionResults).Count 5
    }

    It "uses mocked junction query commands without invoking mutating file commands" {
        Mock Test-Path { $true }
        Mock Get-Item {
            [pscustomobject]@{
                Attributes = ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)
                LinkType = "Junction"
                Target = "D:\Data\Mocked"
            }
        }
        Mock New-Item { throw "New-Item should not be called." }
        Mock Remove-Item { throw "Remove-Item should not be called." }
        Mock Move-Item { throw "Move-Item should not be called." }

        $junction = [pscustomobject]@{
            name = "MockedJunction"
            source = "C:\Mocked"
            target = "D:\Data\Mocked"
            required = $true
            failurePolicy = "fail"
        }

        $result = Test-KitJunctionState -JunctionConfig $junction

        Assert-KitEqual $result.status "unchanged"
        Assert-MockCalled Test-Path -Times 1 -Exactly
        Assert-MockCalled Get-Item -Times 1 -Exactly
        Assert-MockCalled New-Item -Times 0 -Exactly
        Assert-MockCalled Remove-Item -Times 0 -Exactly
        Assert-MockCalled Move-Item -Times 0 -Exactly
    }

    It "writes data junction report when status checks are skipped by WhatIf" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-junction-state-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $manifestPath = Join-Path $tempRoot "junctions.json"
        $pathsPath = Join-Path $tempRoot "paths.json"
        $reportPath = Join-Path $tempRoot "junction-report.json"
        $stdoutPath = Join-Path $tempRoot "stdout.txt"
        $stderrPath = Join-Path $tempRoot "stderr.txt"

        try {
            ([ordered]@{
                paths = [ordered]@{
                    DataRoot = Join-Path $tempRoot "data"
                    ToolRoot = Join-Path $tempRoot "tools"
                }
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsPath -Encoding UTF8

            ([ordered]@{
                junctions = @(
                    [ordered]@{
                        description = "ReportOnlyJunction"
                        source = '${ToolRoot}\example'
                        target = '${DataRoot}\example'
                    }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

            $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Set-DataJunctions.ps1"
            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    $scriptPath,
                    "-ManifestPath",
                    $manifestPath,
                    "-PathsManifestPath",
                    $pathsPath,
                    "-ReportPath",
                    $reportPath,
                    "-WhatIf"
                ) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            Assert-KitEqual ([int]$process.ExitCode) 0
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $reportPath -ErrorAction SilentlyContinue)

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $reportedJunction = @($report.junctionResults)[0]
            Assert-KitEqual $report.reportType "junction-state-verification"
            Assert-KitEqual $reportedJunction.status "whatif"
            Assert-KitEqual $report.junctionSummary.junctionNotRunCount 1
            Assert-KitEqual $report.junctionSummary.exitCode 0
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "links postdeploy junction summary without embedding junctionResults" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-postdeploy-junction-link-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $pathsPath = Join-Path $tempRoot "paths.json"
        $scopePath = Join-Path $tempRoot "scope.json"
        $softwarePath = Join-Path $tempRoot "software.json"
        $junctionsPath = Join-Path $tempRoot "junctions.json"
        $servicesPath = Join-Path $tempRoot "services.json"
        $summaryPath = Join-Path $tempRoot "postdeploy-summary.json"
        $installerPath = Join-Path $tempRoot "postdeploy-installer.json"
        $junctionReportPath = Join-Path $tempRoot "postdeploy-junctions.json"
        $servicePath = Join-Path $tempRoot "postdeploy-services.json"
        $userExperiencePath = Join-Path $tempRoot "postdeploy-user-experience.json"
        $logPath = Join-Path $tempRoot "postdeploy.log"
        $stdoutPath = Join-Path $tempRoot "stdout.txt"
        $stderrPath = Join-Path $tempRoot "stderr.txt"

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
            ([ordered]@{ services = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $servicesPath -Encoding UTF8
            ([ordered]@{
                junctions = @(
                    [ordered]@{
                        description = "LinkedJunction"
                        source = '${ToolRoot}\linked'
                        target = '${DataRoot}\linked'
                    }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $junctionsPath -Encoding UTF8

            ([ordered]@{
                profile = "pester-junction-report-link"
                pathsManifest = $pathsPath
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
                    softwareManifest = $softwarePath
                    servicesManifest = $servicesPath
                    junctionsManifest = $junctionsPath
                }
                reporting = [ordered]@{
                    build = [ordered]@{ enabled = $false }
                    postDeploy = [ordered]@{ enabled = $false }
                    validation = [ordered]@{ enabled = $false }
                }
            }) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $scopePath -Encoding UTF8

            $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1"
            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @(
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
                    "-JunctionReportPath",
                    $junctionReportPath,
                    "-ServiceReportPath",
                    $servicePath,
                    "-UserExperienceReportPath",
                    $userExperiencePath,
                    "-LogPath",
                    $logPath
                ) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            Assert-KitEqual ([int]$process.ExitCode) 0
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $summaryPath -ErrorAction SilentlyContinue)
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $junctionReportPath -ErrorAction SilentlyContinue)

            $summaryReport = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $junctionReport = Get-Content -LiteralPath $junctionReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $junctionReference = @($summaryReport.junctionReports)[0]

            Assert-KitEqual $summaryReport.junctionReportPath $junctionReportPath
            Assert-KitEqual $junctionReference.exists $true
            Assert-KitEqual $junctionReference.junctionSummary.junctionNotRunCount 1
            Assert-KitEqual ($junctionReference.junctionSummary.PSObject.Properties.Name -contains "junctionResults") $false
            Assert-KitEqual $junctionReport.junctionSummary.junctionNotRunCount 1
            Assert-KitEqual @($junctionReport.junctionResults).Count 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
