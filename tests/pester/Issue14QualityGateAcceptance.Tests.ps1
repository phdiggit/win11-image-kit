Describe "Issue 14 quality gate acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents acceptance without close-prep or main-evidence claims" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\41-issue14-quality-gates-acceptance.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Status: `in-acceptance`',
            "## Acceptance Matrix",
            "## Acceptance Hardening Status",
            "## Evidence Chain",
            "## Runner / Report Contract",
            "## CI Boundary",
            "## PSScriptAnalyzer Boundary",
            "## Build Lock Boundary",
            "## Close Preparation Boundary",
            "## Main Evidence Boundary",
            "## Non-goals"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        foreach ($term in @(
            "42-issue14-close-preparation.md",
            "43-issue14-main-validation-evidence.md",
            "Pull request-only Fast CI is not a substitute",
            "report-only",
            "does not execute true build"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#14\b"
        Assert-KitNotMatch $doc "main validation evidence is complete"
        Assert-KitNotMatch $doc "accepted-ready-for-manual-closure"
        Assert-KitNotMatch $doc '(?m)^Status: `ready-for-manual-closure`'
    }

    It "wires runner and acceptance tests into CI" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $workflow "Test-QualityGates\.ps1"
        foreach ($path in @(
            "tests/pester/QualityGateSchema.Tests.ps1",
            "tests/pester/QualityGateReport.Tests.ps1",
            "tests/pester/QualityGateValidation.Tests.ps1",
            "tests/pester/Issue14QualityGateAcceptance.Tests.ps1",
            "tests/pester/Issue14ClosePrep.Tests.ps1",
            "tests/pester/Issue14MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($path))
        }

        Assert-KitMatch $workflow "if:\s*github\.event_name == 'pull_request'"
        Assert-KitMatch $workflow "if:\s*github\.event_name != 'pull_request'"
    }

    It "tracks quality gate files in Build Lock" {
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        $watchGlobs = @($buildLock.watchGlobs)

        foreach ($path in @(
            "manifests/quality-gates.json",
            "schemas/quality-gates.schema.json",
            "scripts/common/New-KitQualityGateReport.ps1",
            "scripts/validate/Test-QualityGates.ps1",
            "docs/41-issue14-quality-gates-acceptance.md",
            "docs/42-issue14-close-preparation.md",
            "docs/43-issue14-main-validation-evidence.md",
            "tests/pester/QualityGateSchema.Tests.ps1",
            "tests/pester/QualityGateReport.Tests.ps1",
            "tests/pester/QualityGateValidation.Tests.ps1",
            "tests/pester/Issue14QualityGateAcceptance.Tests.ps1",
            "tests/pester/Issue14ClosePrep.Tests.ps1",
            "tests/pester/Issue14MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }

        foreach ($glob in @(
            "manifests/quality-gates.json",
            "schemas/quality-gates.schema.json",
            "scripts/common/*QualityGate*.ps1",
            "scripts/validate/*QualityGate*.ps1",
            "tests/pester/*QualityGate*.Tests.ps1"
        )) {
            Assert-KitEqual ($watchGlobs -contains $glob) $true
        }
    }

    It "keeps runner scripts report-only" {
        $text = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-KitQualityGateReport.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-QualityGates.ps1") -Raw -Encoding UTF8
        ) -join "`n"

        foreach ($pattern in @(
            "(?im)^\s*Start-Process\b",
            "(?im)^\s*Invoke-Expression\b",
            '(?im)^\s*&\s*(winget|choco|msiexec|dism|sysprep)\b',
            "(?im)^\s*(Set-Service|Start-Service|Stop-Service)\b",
            "(?im)^\s*reg\s+(load|unload|add|delete)\b"
        )) {
            Assert-KitNotMatch $text $pattern
        }
    }
}
