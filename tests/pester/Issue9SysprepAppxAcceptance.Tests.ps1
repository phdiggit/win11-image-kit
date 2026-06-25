$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 9 Sysprep AppX acceptance guardrails" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitSysprepAppxReadiness.ps1")

        $script:Doc21 = Join-Path $script:RepoRoot "docs\21-issue9-sysprep-appx-acceptance.md"
        $script:CiPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"
        $script:ReadmePath = Join-Path $script:RepoRoot "README.md"
    }

    It "has the acceptance document with required sections" {
        $doc = Get-Content -LiteralPath $script:Doc21 -Raw -Encoding UTF8

        Assert-KitMatch $doc "Status: (in-acceptance|accepted-ready-for-manual-closure)"
        foreach ($text in @("Scope", "Non-goals", "Acceptance Matrix", "CI Boundary", "Manual Checklist")) {
            Assert-KitMatch $doc $text
        }
        Assert-KitMatch $doc "20-issue9-sysprep-appx-gate\.md"
        Assert-KitMatch $doc "docs/22"
        Assert-KitMatch $doc "docs/23"
    }

    It "keeps manifest and schema closed to unknown mutation fields" {
        $schemaPath = Join-Path $script:RepoRoot "schemas\sysprep-appx-gate.schema.json"
        $manifestPath = Join-Path $script:RepoRoot "manifests\sysprep-appx-gate.json"
        $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $topProperties = @($schema.properties.PSObject.Properties.Name) -join ","

        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.properties.rules.additionalProperties $false
        Assert-KitNotMatch $topProperties "remove|mutation|command|script"
        Assert-KitEqual $manifest.mode "audit"
    }

    It "keeps Issue 9 active code free of mutating calls" {
        $activeText = @(
            (Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\Get-KitAppxInventory.ps1") -Raw -Encoding UTF8),
            (Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\Test-KitSysprepAppxReadiness.ps1") -Raw -Encoding UTF8),
            (Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-SysprepReadiness.ps1") -Raw -Encoding UTF8)
        ) -join "`n"

        Assert-KitNotMatch $activeText "sysprep\.exe"
        Assert-KitNotMatch $activeText "Remove-AppxPackage"
        Assert-KitNotMatch $activeText "Remove-AppxProvisionedPackage"
        Assert-KitNotMatch $activeText "DISM\s+.*Remove"
        Assert-KitNotMatch $activeText "profile mutation|AppX repository mutation"
    }

    It "protects the readiness report field contract" {
        $policy = [pscustomobject]@{
            mode = "audit"
            failurePolicy = "fail"
            rules = [pscustomobject]@{}
            allowFamilies = @()
            manualFamilies = @()
        }
        $report = New-KitSysprepAppxReadinessReport -Policy $policy -PolicyPath "manifests/sysprep-appx-gate.json" -Findings @() -QueryErrors @() -WhatIf
        $fields = @($report.PSObject.Properties.Name)

        foreach ($field in @("reportType", "policyPath", "generatedAt", "mode", "failurePolicy", "status", "exitCode", "summary", "findings", "queryErrors", "recommendedActions", "whatIf")) {
            if ($fields -notcontains $field) {
                throw "Report field missing: $field"
            }
        }

        Assert-KitEqual $report.reportType "sysprep-appx-readiness"
        Assert-KitEqual $report.whatIf $true
    }

    It "keeps PR Fast CI wired to core and acceptance tests" {
        $ci = Get-Content -LiteralPath $script:CiPath -Raw -Encoding UTF8
        foreach ($path in @(
            "tests/pester/SysprepAppxInventory.Tests.ps1",
            "tests/pester/SysprepAppxReadiness.Tests.ps1",
            "tests/pester/SysprepAppxReport.Tests.ps1",
            "tests/pester/Issue9SysprepAppxGate.Tests.ps1",
            "tests/pester/Issue9SysprepAppxAcceptance.Tests.ps1"
        )) {
            Assert-KitMatch $ci ([regex]::Escape($path))
        }
    }

    It "links docs 21 from README" {
        $readme = Get-Content -LiteralPath $script:ReadmePath -Raw -Encoding UTF8

        Assert-KitMatch $readme "21-issue9-sysprep-appx-acceptance\.md"
    }
}
