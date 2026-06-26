$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Ensure-State plan" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStatePlan.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitEnsureState.ps1")
    }

    It "plans software install and uninstall actions from fixture drift" {
        $softwareManifest = [pscustomobject]@{
            software = @(
                [pscustomobject]@{ id = "install-me"; displayName = "Install Me"; ensure = "present"; source = "manual"; packageId = "pkg.install"; version = $null; scope = "machine"; installMode = "planned"; priority = 10; notes = "fixture" },
                [pscustomobject]@{ id = "remove-me"; displayName = "Remove Me"; ensure = "absent"; source = "manual"; packageId = "pkg.remove"; version = $null; scope = "machine"; installMode = "planned"; priority = 20; notes = "fixture" }
            )
        }
        $servicesManifest = [pscustomobject]@{ services = @() }
        $fixture = @(
            [pscustomobject]@{ id = "install-me"; present = $false },
            [pscustomobject]@{ id = "remove-me"; present = $true }
        )

        $plan = New-KitEnsureStatePlan -SoftwareManifest $softwareManifest -ServicesManifest $servicesManifest -SoftwareFixtureState $fixture -WhatIf
        $results = @(Test-KitEnsureState -Plan $plan)

        Assert-KitEqual (@($plan.actions | Where-Object { $_.operation -eq "install" }).Count) 1
        Assert-KitEqual (@($plan.actions | Where-Object { $_.operation -eq "uninstall" }).Count) 1
        Assert-KitEqual (@($results | Where-Object { $_.status -eq "manual" }).Count) 2
    }

    It "passes matched software and keeps latest or pinned evidence manual" {
        $softwareManifest = [pscustomobject]@{
            software = @(
                [pscustomobject]@{ id = "ok"; displayName = "Ok"; ensure = "present"; source = "manual"; packageId = "pkg.ok"; version = $null; scope = "machine"; installMode = "planned"; priority = 10; notes = "fixture" },
                [pscustomobject]@{ id = "latest"; displayName = "Latest"; ensure = "latest"; source = "manual"; packageId = "pkg.latest"; version = $null; scope = "machine"; installMode = "planned"; priority = 20; notes = "fixture" },
                [pscustomobject]@{ id = "pinned"; displayName = "Pinned"; ensure = "pinned"; source = "manual"; packageId = "pkg.pinned"; version = "1.0.0"; scope = "machine"; installMode = "planned"; priority = 30; notes = "fixture" }
            )
        }
        $servicesManifest = [pscustomobject]@{ services = @() }
        $fixture = @(
            [pscustomobject]@{ id = "ok"; present = $true },
            [pscustomobject]@{ id = "latest"; present = $true },
            [pscustomobject]@{ id = "pinned"; present = $true; version = "0.9.0" }
        )

        $plan = New-KitEnsureStatePlan -SoftwareManifest $softwareManifest -ServicesManifest $servicesManifest -SoftwareFixtureState $fixture -WhatIf
        $results = @(Test-KitEnsureState -Plan $plan)

        Assert-KitEqual (@($results | Where-Object { $_.id -eq "ok" })[0].status) "passed"
        Assert-KitEqual (@($results | Where-Object { $_.id -eq "latest" })[0].status) "manual"
        Assert-KitEqual (@($results | Where-Object { $_.id -eq "pinned" })[0].status) "manual"
    }

    It "plans service start and startup-type changes without mutation" {
        function Set-Service { }
        function Start-Service { }
        function Stop-Service { }
        function sc.exe { }

        Mock Set-Service { throw "should not mutate service" }
        Mock Start-Service { throw "should not start service" }
        Mock Stop-Service { throw "should not stop service" }
        Mock sc.exe { throw "should not call sc.exe" }

        $softwareManifest = [pscustomobject]@{ software = @() }
        $servicesManifest = [pscustomobject]@{
            services = @(
                [pscustomobject]@{ name = "Svc1"; displayName = "Svc1"; ensure = "running"; startupType = "automatic"; scope = "machine"; changeMode = "planned"; priority = 10; reason = "fixture"; notes = "fixture" },
                [pscustomobject]@{ name = "Svc2"; displayName = "Svc2"; ensure = "stopped"; startupType = "disabled"; scope = "machine"; changeMode = "planned"; priority = 20; reason = "fixture"; notes = "fixture" },
                [pscustomobject]@{ name = "Svc3"; displayName = "Svc3"; ensure = "manual"; startupType = "unchanged"; scope = "machine"; changeMode = "manual"; priority = 30; reason = "fixture"; notes = "fixture" }
            )
        }
        $fixture = @(
            [pscustomobject]@{ name = "Svc1"; status = "Stopped"; startupType = "manual" },
            [pscustomobject]@{ name = "Svc2"; status = "Running"; startupType = "automatic" },
            [pscustomobject]@{ name = "Svc3"; status = "Running"; startupType = "manual" }
        )

        $plan = New-KitEnsureStatePlan -SoftwareManifest $softwareManifest -ServicesManifest $servicesManifest -ServiceFixtureState $fixture -WhatIf
        $results = @(Test-KitEnsureState -Plan $plan)

        Assert-KitEqual (@($plan.actions | Where-Object { $_.operation -eq "service-start" }).Count) 1
        Assert-KitEqual (@($plan.actions | Where-Object { $_.operation -eq "service-change-startup-type" }).Count -ge 1) $true
        Assert-KitEqual (@($results | Where-Object { $_.status -eq "manual" }).Count) 3
        Assert-MockCalled Set-Service -Times 0 -Exactly
        Assert-MockCalled Start-Service -Times 0 -Exactly
        Assert-MockCalled Stop-Service -Times 0 -Exactly
        Assert-MockCalled sc.exe -Times 0 -Exactly
    }
}
