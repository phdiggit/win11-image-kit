Describe "Issue 16 evidence chain intake" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents the real Issue 16 source, scope, non-goals, and safety boundaries" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\48-issue16-evidence-chain-report.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "GitHub Issue #16",
            "https://github.com/phdiggit/win11-image-kit/issues/16",
            "Roadmap",
            "## Source",
            "## Scope",
            "## Non-goals",
            "## Current Repository Touchpoints",
            "## Evidence Chain Model",
            "## Report Contract",
            "## Producer Map",
            "## Aggregator / Validator",
            "## Safety Boundaries",
            "## Validation Plan",
            "## Quality Gates / Build Lock",
            "## Acceptance Checklist",
            "## Related Documents"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitMatch $doc 'Status:\s*`in-progress`'
        Assert-KitMatch $doc "manual"
        Assert-KitMatch $doc "not-captured"
        Assert-KitMatch $doc "PR Fast CI"
    }

    It "wires README, CI, Quality Gates, and Build Lock to Issue 16" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        $gateIds = @($qualityGates.gates.id)

        Assert-KitMatch $readme "docs/48-issue16-evidence-chain-report\.md"
        Assert-KitMatch $ci "Test-EvidenceChain\.ps1"
        Assert-KitMatch $ci "Issue16EvidenceChain\.Tests\.ps1"
        Assert-KitMatch $ci "EvidenceChain"
        Assert-KitEqual ($gateIds -contains "evidence-chain") $true

        foreach ($path in @(
            "docs/48-issue16-evidence-chain-report.md",
            "manifests/evidence-chain.json",
            "schemas/evidence-chain.schema.json",
            "schemas/evidence-chain-report.schema.json",
            "scripts/common/New-KitEvidenceChainReport.ps1",
            "scripts/validate/Test-EvidenceChain.ps1",
            "scripts/config/Show-EvidenceChain.ps1",
            "tests/fixtures/evidence-chain/sample-build-capture-deploy.json",
            "tests/pester/EvidenceChainSchema.Tests.ps1",
            "tests/pester/EvidenceChainReport.Tests.ps1",
            "tests/pester/EvidenceChainValidation.Tests.ps1",
            "tests/pester/EvidenceChainSafety.Tests.ps1",
            "tests/pester/Issue16EvidenceChain.Tests.ps1",
            ".github/workflows/ci.yml",
            "README.md",
            "manifests/quality-gates.json"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }
    }

    It "does not introduce auto-close wording or Issue 16 close artifacts" {
        $text = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\48-issue16-evidence-chain-report.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        ) -join "`n"

        Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#16\b"

        foreach ($path in @(
            "docs\49-issue16-close-preparation.md",
            "docs\49-issue16-main-validation-evidence.md",
            "docs\49-issue16-completion-summary.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) $false
        }
    }

    It "does not touch Issue 6 through Issue 15 close artifacts in this stage" {
        $changedNames = git -c core.quotepath=false diff --name-only
        foreach ($name in @($changedNames)) {
            Assert-KitNotMatch $name 'docs/[0-9]+-issue(6|7|8|9|10|11|12|13|14|15).*(close|main-validation|completion)'
        }
    }
}
