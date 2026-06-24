$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Service state verification results" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitServiceState.ps1")
        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }
    }

    It "records matching service state as unchanged" {
        $service = [pscustomobject]@{
            name = "ExampleService"
            expectedState = "Running"
            expectedStartType = "Automatic"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Name, $ServiceConfig, [bool]$IncludeStartType)
            [pscustomobject]@{ Status = "Running"; StartType = "Auto" }
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.reason "service-state-ok"
        Assert-KitEqual $result.actualState "Running"
        Assert-KitEqual $result.actualStartType "Automatic"
    }

    It "fails required service state mismatch" {
        $service = [pscustomobject]@{
            name = "RequiredService"
            expectedState = "Running"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Name, $ServiceConfig, [bool]$IncludeStartType)
            [pscustomobject]@{ Status = "Stopped"; StartType = "Manual" }
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "service-state-mismatch"
        Assert-KitEqual $result.required $true
        Assert-KitEqual (Get-KitServiceResultSummary -Results @($result)).exitCode 1
    }

    It "fails required missing service" {
        $service = [pscustomobject]@{
            name = "MissingRequiredService"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            param([string]$Name, $ServiceConfig, [bool]$IncludeStartType)
            return $null
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "service-missing"
        Assert-KitEqual $result.errors.Count 1
    }

    It "maps optional skip policy to skipped" {
        $service = [pscustomobject]@{
            name = "OptionalSkipService"
            expectedState = "Running"
            required = $false
            failurePolicy = "skip"
        }
        $query = {
            param([string]$Name, $ServiceConfig, [bool]$IncludeStartType)
            [pscustomobject]@{ Status = "Stopped"; StartType = "Manual" }
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query
        $summary = Get-KitServiceResultSummary -Results @($result)

        Assert-KitEqual $result.status "skipped"
        Assert-KitEqual $result.skippedReason "service-state-mismatch"
        Assert-KitEqual $summary.exitCode 0
    }

    It "maps optional manual policy to manual" {
        $service = [pscustomobject]@{
            name = "OptionalManualService"
            expectedState = "Running"
            required = $false
            failurePolicy = "manual"
        }
        $query = {
            param([string]$Name, $ServiceConfig, [bool]$IncludeStartType)
            return $null
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query

        Assert-KitEqual $result.status "manual"
        Assert-KitEqual $result.manualAction "service-missing"
    }

    It "records WhatIf as not run without querying" {
        $service = [pscustomobject]@{
            name = "PreviewService"
            expectedState = "Running"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            throw "Service query should not run during WhatIf."
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query -WhatIf
        $summary = Get-KitServiceResultSummary -Results @($result)

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.whatIf $true
        Assert-KitEqual $result.changed $false
        Assert-KitEqual $summary.serviceNotRunCount 1
        Assert-KitEqual $summary.exitCode 0
    }

    It "returns structured failure for query exceptions" {
        $service = [pscustomobject]@{
            name = "QueryFailureService"
            required = $true
            failurePolicy = "fail"
        }
        $query = {
            throw "query failed"
        }

        $result = Test-KitServiceState -ServiceConfig $service -ServiceQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "service-query-failed"
        Assert-KitMatch $result.errors[0] "query failed"
    }

    It "summarizes service specific counters" {
        $results = @(
            (Test-KitServiceState -ServiceConfig ([pscustomobject]@{ name = "OkService"; expectedState = "Running" }) -ServiceQuery { param([string]$Name, $ServiceConfig, [bool]$IncludeStartType) [pscustomobject]@{ Status = "Running"; StartType = "" } }),
            (Test-KitServiceState -ServiceConfig ([pscustomobject]@{ name = "MismatchService"; expectedState = "Running"; required = $true }) -ServiceQuery { param([string]$Name, $ServiceConfig, [bool]$IncludeStartType) [pscustomobject]@{ Status = "Stopped"; StartType = "" } }),
            (Test-KitServiceState -ServiceConfig ([pscustomobject]@{ name = "MissingService"; required = $false; failurePolicy = "skip" }) -ServiceQuery { param([string]$Name, $ServiceConfig, [bool]$IncludeStartType) return $null }),
            (Test-KitServiceState -ServiceConfig ([pscustomobject]@{ name = "PreviewService" }) -WhatIf)
        )

        $summary = Get-KitServiceResultSummary -Results $results
        $report = New-KitServiceStateReport -Results $results

        Assert-KitEqual $summary.total 4
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.serviceCheckedCount 3
        Assert-KitEqual $summary.serviceMismatchCount 1
        Assert-KitEqual $summary.serviceMissingCount 1
        Assert-KitEqual $summary.serviceNotRunCount 1
        Assert-KitEqual $report.serviceSummary.total 4
        Assert-KitEqual @($report.serviceResults).Count 4
    }

    It "uses mocked service query commands without invoking mutating service commands" {
        Mock Get-Service { [pscustomobject]@{ Name = $Name; Status = "Running" } }
        Mock Get-CimInstance { [pscustomobject]@{ StartMode = "Auto" } }
        Mock Set-Service { throw "Set-Service should not be called." }
        Mock Start-Service { throw "Start-Service should not be called." }
        Mock Stop-Service { throw "Stop-Service should not be called." }

        $service = [pscustomobject]@{
            name = "MockedService"
            expectedState = "Running"
            expectedStartType = "Automatic"
            required = $true
            failurePolicy = "fail"
        }

        $result = Test-KitServiceState -ServiceConfig $service

        Assert-KitEqual $result.status "unchanged"
        Assert-MockCalled Get-Service -Times 1 -Exactly
        Assert-MockCalled Get-CimInstance -Times 1 -Exactly
        Assert-MockCalled Set-Service -Times 0 -Exactly
        Assert-MockCalled Start-Service -Times 0 -Exactly
        Assert-MockCalled Stop-Service -Times 0 -Exactly
    }

    It "writes middleware service report when status checks are skipped" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-service-state-{0}" -f ([guid]::NewGuid().ToString("N")))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $manifestPath = Join-Path $tempRoot "services.json"
        $reportPath = Join-Path $tempRoot "service-report.json"
        $stdoutPath = Join-Path $tempRoot "stdout.txt"
        $stderrPath = Join-Path $tempRoot "stderr.txt"

        try {
            $manifest = [ordered]@{
                services = @(
                    [ordered]@{
                        name = "ReportOnlyService"
                        displayName = "ReportOnlyService"
                        install = "install command"
                        start = "start command"
                        stop = "stop command"
                        delete = "delete command"
                        expectedState = "Running"
                    }
                )
            }
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
            $scriptPath = Join-Path $script:RepoRoot "scripts\tests\Test-Middleware.ps1"

            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    $scriptPath,
                    "-ServicesManifestPath",
                    $manifestPath,
                    "-SkipServiceStatus",
                    "-ReportPath",
                    $reportPath
                ) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            Assert-KitEqual ([int]$process.ExitCode) 0
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $reportPath -ErrorAction SilentlyContinue)

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $reportedService = @($report.serviceResults)[0]
            Assert-KitEqual $report.reportType "service-state-verification"
            Assert-KitEqual $reportedService.status "whatif"
            Assert-KitEqual $report.serviceSummary.serviceNotRunCount 1
            Assert-KitEqual $report.serviceSummary.exitCode 0
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

