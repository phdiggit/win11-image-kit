Describe "Issue 15 layered configuration acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "adds acceptance scaffold without close-prep or main evidence" {
        $doc45 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\45-issue15-layered-configuration-acceptance.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Status: `in-acceptance`',
            "## Scope",
            "## Acceptance Matrix",
            "## Evidence Chain",
            "## Layer Priority",
            "## Merge Policy",
            "## Local Private Override Policy",
            "## CLI Explicit Override Policy",
            "## Token / Path Safety",
            "## Report Contract",
            "## CI / Quality Gates / Build Lock",
            "## Non-goals",
            "## Remaining Work",
            "## Related Documents",
            "repo-default < profile < hardware < local-private < cli-explicit"
        )) {
            Assert-KitMatch $doc45 ([regex]::Escape($term))
        }

        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\46-issue15-close-preparation.md")) $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\47-issue15-main-validation-evidence.md")) $false
    }

    It "wires README, CI, Quality Gates, and Build Lock for hardening" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        $gate = @($qualityGates.gates | Where-Object { $_.id -eq "effective-configuration" })[0]

        Assert-KitMatch $readme "docs/45-issue15-layered-configuration-acceptance\.md"
        Assert-KitMatch $ci "Test-EffectiveConfiguration\.ps1 -AllStacks"
        Assert-KitMatch $ci "EffectiveConfigurationMergePolicy\.Tests\.ps1"
        Assert-KitEqual $gate.mode "report-only"
        Assert-KitNotMatch ($qualityGates | ConvertTo-Json -Depth 10) "true-execution"

        foreach ($path in @(
            "docs/45-issue15-layered-configuration-acceptance.md",
            "manifests/paths.local.example.json",
            "tests/pester/EffectiveConfigurationMergePolicy.Tests.ps1",
            "tests/pester/EffectiveConfigurationLocalOverride.Tests.ps1",
            "tests/pester/EffectiveConfigurationTokenSafety.Tests.ps1",
            "tests/pester/EffectiveConfigurationCliOverride.Tests.ps1",
            "tests/pester/Issue15LayeredConfigurationAcceptance.Tests.ps1"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }
    }

    It "does not introduce auto-close wording for Issue 15" {
        $text = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\44-issue15-layered-configuration.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\45-issue15-layered-configuration-acceptance.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        ) -join "`n"

        Assert-KitNotMatch $text "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#15\b"
    }
}
