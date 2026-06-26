Describe "Issue 15 layered configuration intake" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents the real Issue 15 scope and safety boundaries" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\44-issue15-layered-configuration.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "GitHub Issue #15",
            "Roadmap Issue #19",
            "Profile",
            "hardware",
            "## Source",
            "## Scope",
            "## Non-goals",
            "## Current Repository Touchpoints",
            "## Proposed Implementation Layers",
            "## Safety Boundaries",
            "## Validation Plan",
            "## Build Lock / Quality Gates",
            "## Acceptance Checklist",
            "## Related Documents"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitMatch $doc 'Status:\s*`(in-progress|accepted-ready-for-manual-closure)`'

        foreach ($term in @(
            "Windows image build",
            "registry",
            "profile",
            "hive",
            "static",
            "fixture",
            "report-only"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "does not introduce auto-close wording for Issue 15" {
        $text = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\44-issue15-layered-configuration.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        ) -join "`n"

        Assert-KitNotMatch $text "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#15\b"
    }

    It "links README, CI, Build Lock, and Quality Gates to Issue 15 guardrails" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        $gateIds = @($qualityGates.gates.id)

        Assert-KitMatch $readme "docs/44-issue15-layered-configuration\.md"
        Assert-KitMatch $ci "Issue15LayeredConfiguration\.Tests\.ps1"
        Assert-KitMatch $ci "EffectiveConfiguration"
        Assert-KitEqual ($gateIds -contains "effective-configuration") $true

        foreach ($path in @(
            "docs/44-issue15-layered-configuration.md",
            "manifests/config-layers.json",
            "schemas/config-layers.schema.json",
            "schemas/config-layer-fragment.schema.json",
            "profiles/default.json",
            "profiles/release.json",
            "hardware/air15.json",
            "scripts/common/Resolve-KitEffectiveConfiguration.ps1",
            "scripts/config/Show-EffectiveConfiguration.ps1",
            "scripts/validate/Test-EffectiveConfiguration.ps1",
            "tests/pester/Issue15LayeredConfiguration.Tests.ps1",
            "tests/pester/EffectiveConfigurationSchema.Tests.ps1",
            "tests/pester/EffectiveConfigurationReport.Tests.ps1",
            "tests/pester/EffectiveConfigurationValidation.Tests.ps1",
            ".github/workflows/ci.yml",
            "README.md",
            ".gitignore"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }
    }

    It "does not touch Issue 6 through Issue 14 close artifacts in this stage" {
        $changedNames = git -c core.quotepath=false diff --name-only
        foreach ($name in @($changedNames)) {
            Assert-KitNotMatch $name 'docs/[0-9]+-issue(6|7|8|9|10|11|12|13|14).*(close|main-validation|completion)'
        }
    }
}
