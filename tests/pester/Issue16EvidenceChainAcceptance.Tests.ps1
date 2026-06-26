Describe "Issue 16 evidence chain acceptance scaffold" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "adds docs 49 as in-acceptance and keeps it out of ready closure states" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\49-issue16-evidence-chain-acceptance.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`in-acceptance`'
        foreach ($term in @(
            "## Scope",
            "## Acceptance Matrix",
            "## Run ID / Upstream Linkage",
            "## Artifact Index",
            "## Producer Normalization",
            "## Redaction Policy",
            "## Evidence Chain Report Contract",
            "## CI / Quality Gates / Build Lock",
            "## Non-goals",
            "## Remaining Work",
            "## Related Documents"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "Status:\s*`ready"
        Assert-KitMatch $doc "not a close-prep page"
        Assert-KitMatch $doc "not a main validation evidence page"
        Assert-KitMatch $doc "not a completion summary"
        Assert-KitMatch $doc "PR Fast CI is not main/workflow evidence"
    }

    It "keeps README, CI, Quality Gates, and Build Lock wired to acceptance hardening" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        $evidenceGate = @($qualityGates.gates | Where-Object { $_.id -eq "evidence-chain" })[0]

        Assert-KitMatch $readme "docs/49-issue16-evidence-chain-acceptance\.md"
        foreach ($testName in @("EvidenceChainRunId", "EvidenceChainArtifactIndex", "EvidenceChainRedaction", "EvidenceChainProducerNormalization", "Issue16EvidenceChainAcceptance")) {
            Assert-KitMatch $ci ("tests/pester/{0}\.Tests\.ps1" -f $testName)
        }
        Assert-KitEqual $evidenceGate.mode "report-only"
        Assert-KitMatch $evidenceGate.notes "runId inheritance"
        Assert-KitMatch $evidenceGate.notes "artifact index"
        Assert-KitMatch $evidenceGate.notes "redaction policy"

        foreach ($path in @(
            "docs/49-issue16-evidence-chain-acceptance.md",
            "schemas/evidence-artifact-index.schema.json",
            "scripts/common/New-KitEvidenceArtifactIndex.ps1",
            "scripts/common/Test-KitEvidenceRedaction.ps1",
            "tests/fixtures/evidence-chain/sample-artifact-index.json",
            "tests/fixtures/evidence-chain/sample-run-linkage.json",
            "tests/fixtures/evidence-chain/sample-redacted-report.json",
            "tests/fixtures/evidence-chain/sample-blocked-sensitive-report.json",
            "tests/pester/EvidenceChainRunId.Tests.ps1",
            "tests/pester/EvidenceChainArtifactIndex.Tests.ps1",
            "tests/pester/EvidenceChainRedaction.Tests.ps1",
            "tests/pester/EvidenceChainProducerNormalization.Tests.ps1",
            "tests/pester/Issue16EvidenceChainAcceptance.Tests.ps1"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }
    }

    It "does not introduce Issue 16 close artifacts or auto-close wording" {
        foreach ($path in @(
            "docs\50-issue16-close-preparation.md",
            "docs\50-issue16-main-validation-evidence.md",
            "docs\50-issue16-completion-summary.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) $false
        }

        $text = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\48-issue16-evidence-chain-report.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\49-issue16-evidence-chain-acceptance.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        ) -join "`n"
        Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#16\b"
    }
}
