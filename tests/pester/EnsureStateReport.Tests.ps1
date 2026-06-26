$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Ensure-State report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStatePlan.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitEnsureState.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStateReport.ps1")
    }

    It "aggregates passed and manual counts and keeps planned actions" {
        $softwareManifest = [pscustomobject]@{
            software = @(
                [pscustomobject]@{ id = "ok"; displayName = "Ok"; ensure = "present"; source = "manual"; packageId = "pkg.ok"; version = $null; scope = "machine"; installMode = "planned"; priority = 10; notes = "fixture" },
                [pscustomobject]@{ id = "manual"; displayName = "Manual"; ensure = "present"; source = "manual"; packageId = "pkg.manual"; version = $null; scope = "machine"; installMode = "planned"; priority = 20; notes = "fixture" }
            )
        }
        $servicesManifest = [pscustomobject]@{
            services = @(
                [pscustomobject]@{ name = "Svc"; displayName = "Svc"; ensure = "running"; startupType = "automatic"; scope = "machine"; changeMode = "planned"; priority = 30; reason = "fixture"; notes = "fixture" }
            )
        }
        $softwareFixture = @(
            [pscustomobject]@{ id = "ok"; present = $true },
            [pscustomobject]@{ id = "manual"; present = $false }
        )
        $serviceFixture = @(
            [pscustomobject]@{ name = "Svc"; status = "Running"; startupType = "automatic" }
        )

        $plan = New-KitEnsureStatePlan -SoftwareManifest $softwareManifest -ServicesManifest $servicesManifest -SoftwareFixtureState $softwareFixture -ServiceFixtureState $serviceFixture -WhatIf
        $results = @(Test-KitEnsureState -Plan $plan)
        $report = New-KitEnsureStateReport -Plan $plan -Results $results -WhatIf
        $json = $report | ConvertTo-Json -Depth 12

        Assert-KitEqual $report.reportType "ensure-state"
        Assert-KitEqual $report.status "manual"
        Assert-KitEqual $report.summary.total 3
        Assert-KitEqual $report.summary.passedCount 2
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual ($report.summary.plannedActionCount -gt 0) $true
        Assert-KitMatch $json "plannedActions"
    }

    It "writes an explicit report path and keeps manual status exit code at zero" {
        $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($powerShell)) {
            $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-ensure-state-report-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $reportPath = Join-Path $tempRoot "ensure-state.json"
        $scriptPath = Join-Path $script:RepoRoot "scripts\validate\Test-EnsureState.ps1"

        try {
            $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -ReportPath $reportPath 2>&1
            $exitCode = $LASTEXITCODE
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $exitCode 0
            Assert-KitEqual $report.reportType "ensure-state"
            Assert-KitMatch ($output -join "`n") "Ensure-state report written"
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
