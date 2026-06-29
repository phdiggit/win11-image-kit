Describe "Issue 11 capability registry acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitCapabilityRegistry.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitCapabilityConsistencyReport.ps1")
    }

    It "documents acceptance scope, non-goals, matrix, extension checklist, and evidence links" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\29-issue11-capability-registry-acceptance.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("in-acceptance", "accepted-ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Scope",
            "## Non-goals",
            "## Acceptance Matrix",
            "## Extension Checklist",
            "## Evidence Links",
            "PR Fast CI",
            "28-issue11-capability-registry.md",
            "30-issue11-close-preparation.md",
            "31-issue11-main-validation-evidence.md"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        if ($statusMatch.Groups[1].Value -eq "accepted-ready-for-manual-closure") {
            Assert-KitMatch $doc "Close preparation and main validation evidence are recorded in docs/30 and"
            Assert-KitMatch $doc "docs/31"
        }
    }

    It "keeps the schema strict and aligned with required registry fields" {
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\capability-registry.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $capability = $schema.'$defs'.capability

        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $capability.additionalProperties $false

        foreach ($field in @("id", "issue", "status", "context", "mutationLevel", "manifest", "schema", "entrypoints", "validateEntrypoints", "tests", "docs", "notes")) {
            Assert-KitEqual (@($capability.required) -contains $field) $true
        }

        Assert-KitEqual ($capability.properties.issue.pattern -eq "^#[0-9]+$") $true
        Assert-KitEqual (@($schema.'$defs'.status.enum) -contains "implemented") $true
        Assert-KitEqual (@($schema.'$defs'.mutationLevel.enum) -contains "real-mutation") $true
    }

    It "keeps active capability scripts free of real mutation commands and network access" {
        $files = @(
            "scripts\common\Get-KitCapabilityRegistry.ps1",
            "scripts\common\Test-KitCapabilityConsistency.ps1",
            "scripts\common\New-KitCapabilityConsistencyReport.ps1",
            "scripts\validate\Test-CapabilityRegistry.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "sysprep\.exe|Remove-AppxPackage|Remove-AppxProvisionedPackage|dism\s+/Remove"
            Assert-KitNotMatch $text "reg\s+load|reg\.exe\s+load|reg\s+unload|reg\.exe\s+unload"
            Assert-KitNotMatch $text "Set-ItemProperty\s+-Path\s+HKLM|Set-ItemProperty\s+-Path\s+HKCU"
            Assert-KitNotMatch $text "New-ItemProperty\s+-Path\s+HKLM|New-ItemProperty\s+-Path\s+HKCU"
            Assert-KitNotMatch $text "Invoke-WebRequest|Invoke-RestMethod|Start-BitsTransfer|gh\s+|curl\s+"
        }
    }

    It "preserves the report field contract for acceptance evidence" {
        $registry = Get-KitCapabilityRegistry -Path "manifests/capability-registry.json" -RepoRoot $script:RepoRoot
        $report = New-KitCapabilityConsistencyReport -Registry $registry -RepoRoot $script:RepoRoot -WhatIf

        foreach ($field in @("reportType", "status", "summary", "capabilities", "orphanManifests", "whatIf")) {
            Assert-KitEqual ($null -ne $report.$field) $true
        }

        Assert-KitEqual $report.reportType "capability-consistency"
        Assert-KitEqual $report.whatIf $true
    }

    It "wires acceptance evidence into README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-11/29-issue11-capability-registry-acceptance\.md"
        foreach ($testPath in @(
            "tests/pester/CapabilityRegistrySchema.Tests.ps1",
            "tests/pester/CapabilityRegistryConsistency.Tests.ps1",
            "tests/pester/CapabilityRegistryReport.Tests.ps1",
            "tests/pester/Issue11CapabilityRegistry.Tests.ps1",
            "tests/pester/Issue11CapabilityRegistryAcceptance.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($testPath))
        }
    }
}
