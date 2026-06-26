Describe "Issue 13 ensure-state acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStatePlan.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitEnsureState.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEnsureStateReport.ps1")
    }

    It "records acceptance status, scope, non-goals, matrix, split rules, and CI boundary" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\37-issue13-ensure-state-acceptance.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("in-acceptance", "accepted-ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Scope",
            "## Non-goals",
            "## Acceptance Matrix",
            "## Acceptance Decision",
            "## True Execution Split Rules",
            "## CI Boundary",
            "36-issue13-ensure-state.md"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        if ($statusMatch.Groups[1].Value -eq "accepted-ready-for-manual-closure") {
            foreach ($term in @(
                "Main/workflow validation evidence is recorded",
                "39-issue13-main-validation-evidence.md",
                "PR Fast CI remains static/fixture/report-only",
                "not a substitute for main/workflow validation evidence"
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }
        }
    }

    It "keeps software and service schemas closed with required fields and enums" {
        $softwareSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\software.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $servicesSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\services.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $softwareSchema.additionalProperties $false
        Assert-KitEqual $softwareSchema.properties.software.items.additionalProperties $false
        Assert-KitEqual $servicesSchema.additionalProperties $false
        Assert-KitEqual $servicesSchema.properties.services.items.additionalProperties $false

        foreach ($name in @("id", "displayName", "ensure", "source", "packageId", "scope", "installMode", "priority", "notes")) {
            Assert-KitEqual (@($softwareSchema.properties.software.items.required) -contains $name) $true
        }
        foreach ($name in @("name", "displayName", "ensure", "startupType", "scope", "changeMode", "priority", "reason", "notes")) {
            Assert-KitEqual (@($servicesSchema.properties.services.items.required) -contains $name) $true
        }

        Assert-KitEqual ((@($softwareSchema.properties.software.items.properties.ensure.enum) -join ",") -eq "present,absent,latest,pinned,manual") $true
        Assert-KitEqual ((@($softwareSchema.properties.software.items.properties.source.enum) -join ",") -eq "winget,chocolatey,msi,powershell,manual,none") $true
        Assert-KitEqual ((@($softwareSchema.properties.software.items.properties.scope.enum) -join ",") -eq "machine,current-user,default-user,none") $true
        Assert-KitEqual ((@($softwareSchema.properties.software.items.properties.installMode.enum) -join ",") -eq "planned,manual,disabled") $true
        Assert-KitEqual ((@($servicesSchema.properties.services.items.properties.ensure.enum) -join ",") -eq "running,stopped,disabled,manual,absent,ignore") $true
        Assert-KitEqual ((@($servicesSchema.properties.services.items.properties.startupType.enum) -join ",") -eq "automatic,manual,disabled,unchanged") $true
        Assert-KitEqual ((@($servicesSchema.properties.services.items.properties.changeMode.enum) -join ",") -eq "planned,manual,disabled") $true
    }

    It "keeps active ensure-state scripts free of real mutation, network, registry, and build commands" {
        $paths = @(
            "scripts/common/Resolve-KitSoftwareState.ps1",
            "scripts/common/Resolve-KitServiceState.ps1",
            "scripts/common/New-KitEnsureStatePlan.ps1",
            "scripts/common/Test-KitEnsureState.ps1",
            "scripts/common/New-KitEnsureStateReport.ps1",
            "scripts/validate/Test-EnsureState.ps1"
        )
        $joined = (($paths | ForEach-Object {
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $_) -Raw -Encoding UTF8
        }) -join "`n")

        foreach ($pattern in @(
            "Invoke-WebRequest",
            "Invoke-RestMethod",
            "Start-BitsTransfer",
            "winget\s+(install|uninstall|upgrade)",
            "choco\s+(install|uninstall|upgrade)",
            "msiexec\s+/(i|x)",
            "\bInstall-Package\b",
            "\bUninstall-Package\b",
            "\bSet-Service\b",
            "\bStart-Service\b",
            "\bStop-Service\b",
            "sc\.exe\s+(config|delete|stop|start)",
            "\breg\s+(load|unload|add|delete)",
            "\bSet-ItemProperty\b",
            "\bNew-ItemProperty\b",
            "\bdism(\.exe)?\b",
            "Invoke-GoldenImageBuild"
        )) {
            Assert-KitNotMatch $joined $pattern
        }
    }

    It "keeps report field contract stable" {
        $softwareManifest = [pscustomobject]@{
            software = @([pscustomobject]@{ id = "ok"; displayName = "Ok"; ensure = "present"; source = "manual"; packageId = "pkg.ok"; version = $null; scope = "machine"; installMode = "planned"; priority = 10; notes = "fixture" })
        }
        $servicesManifest = [pscustomobject]@{
            services = @([pscustomobject]@{ name = "Svc"; displayName = "Svc"; ensure = "running"; startupType = "automatic"; scope = "machine"; changeMode = "planned"; priority = 30; reason = "fixture"; notes = "fixture" })
        }
        $plan = New-KitEnsureStatePlan `
            -SoftwareManifest $softwareManifest `
            -ServicesManifest $servicesManifest `
            -SoftwareFixtureState @([pscustomobject]@{ id = "ok"; present = $true }) `
            -ServiceFixtureState @([pscustomobject]@{ name = "Svc"; status = "Running"; startupType = "automatic" }) `
            -WhatIf
        $report = New-KitEnsureStateReport -Plan $plan -WhatIf

        foreach ($field in @("reportType", "status", "summary", "results", "plannedActions", "whatIf")) {
            Assert-KitEqual ($report.PSObject.Properties.Name -contains $field) $true
        }
    }

    It "keeps README, docs, capability registry, build lock, and PR Fast CI wired" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\37-issue13-ensure-state-acceptance.md") -Raw -Encoding UTF8
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $registry = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\capability-registry.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $capability = @($registry.capabilities | Where-Object { $_.id -eq "ensure-state-convergence" })[0]
        $lockedPaths = @($buildLock.entries.path)

        Assert-KitMatch $readme "docs/37-issue13-ensure-state-acceptance\.md"
        Assert-KitMatch $doc "36-issue13-ensure-state\.md"
        Assert-KitEqual $capability.issue "#13"
        Assert-KitEqual $capability.mutationLevel "plan-only"

        foreach ($path in @(
            "tests/pester/EnsureStateSchema.Tests.ps1",
            "tests/pester/EnsureStatePlan.Tests.ps1",
            "tests/pester/EnsureStateReport.Tests.ps1",
            "tests/pester/EnsureStateValidation.Tests.ps1",
            "tests/pester/Issue13EnsureState.Tests.ps1",
            "tests/pester/Issue13EnsureStateAcceptance.Tests.ps1"
        )) {
            Assert-KitMatch $ci ([regex]::Escape($path))
        }

        foreach ($path in @(
            "docs/37-issue13-ensure-state-acceptance.md",
            "docs/39-issue13-main-validation-evidence.md",
            "tests/pester/Issue13EnsureStateAcceptance.Tests.ps1"
        )) {
            Assert-KitEqual ($lockedPaths -contains $path) $true
        }
    }
}
