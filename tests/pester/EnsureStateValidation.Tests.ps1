$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Ensure-State validation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStatePlan.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitEnsureState.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStateReport.ps1")
    }

    It "fails missing required software fields" {
        $plan = [pscustomobject]@{
            software = @([pscustomobject]@{ id = ""; desiredEnsure = ""; currentEnsure = "unknown"; actions = @(); warnings = @(); errors = @() })
            services = @()
            actions = @()
        }

        $results = @(Test-KitEnsureState -Plan $plan)
        Assert-KitEqual $results[0].status "failed"
    }

    It "keeps fixture-only validation in manual mode without reading real state" {
        function Get-Service { throw "should not query real services" }
        function Get-CimInstance { throw "should not query real services" }
        function winget { throw "should not query packages" }
        function choco { throw "should not query packages" }
        function msiexec { throw "should not query packages" }

        Mock Get-Service { throw "should not query real services" }
        Mock Get-CimInstance { throw "should not query real services" }
        Mock winget { throw "should not query packages" }
        Mock choco { throw "should not query packages" }
        Mock msiexec { throw "should not query packages" }

        $report = & (Join-Path $script:RepoRoot "scripts\validate\Test-EnsureState.ps1") -FixtureOnly

        Assert-KitEqual $report.status "manual"
        Assert-MockCalled Get-Service -Times 0 -Exactly
        Assert-MockCalled Get-CimInstance -Times 0 -Exactly
        Assert-MockCalled winget -Times 0 -Exactly
        Assert-MockCalled choco -Times 0 -Exactly
        Assert-MockCalled msiexec -Times 0 -Exactly
    }

    It "returns exit code 1 for failed ensure-state report" {
        $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($powerShell)) {
            $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-ensure-state-fail-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $softwarePath = Join-Path $tempRoot "software.json"
        $servicesPath = Join-Path $tempRoot "services.json"
        $scriptPath = Join-Path $script:RepoRoot "scripts\validate\Test-EnsureState.ps1"

        try {
            ([ordered]@{
                manifestVersion = 1
                software = @(
                    [ordered]@{
                        id = ""
                        displayName = "Broken"
                        ensure = ""
                        source = "manual"
                        packageId = "pkg.broken"
                        version = $null
                        scope = "machine"
                        installMode = "planned"
                        priority = 1
                        notes = "fixture"
                    }
                )
            }) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $softwarePath -Encoding UTF8
            ([ordered]@{
                manifestVersion = 1
                services = @()
            }) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $servicesPath -Encoding UTF8

            & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -SoftwareManifestPath $softwarePath -ServicesManifestPath $servicesPath | Out-Null
            $exitCode = $LASTEXITCODE

            Assert-KitEqual $exitCode 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
