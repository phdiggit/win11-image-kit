Describe "Evidence chain close-prep wiring" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "wires Issue 16 acceptance, close-prep, and main-evidence gates" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $ids = @($qualityGates.gates.id)

        foreach ($id in @("issue16-acceptance", "issue16-close-prep", "issue16-main-evidence-scaffold")) {
            Assert-KitEqual ($ids -contains $id) $true
        }

        $evidenceGate = @($qualityGates.gates | Where-Object { $_.id -eq "evidence-chain" })[0]
        Assert-KitEqual $evidenceGate.mode "report-only"
        Assert-KitMatch $evidenceGate.notes "report input index"
        Assert-KitMatch $evidenceGate.notes "producer normalization counters"
    }

    It "keeps Build Lock and README linked to close-prep scaffold files" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        foreach ($path in @(
            "docs/50-issue16-close-preparation.md",
            "docs/51-issue16-main-validation-evidence.md",
            "manifests/evidence-report-inputs.json",
            "schemas/evidence-report-inputs.schema.json",
            "scripts/common/Read-KitEvidenceReportInputs.ps1",
            "scripts/common/ConvertTo-KitEvidenceProducerItem.ps1",
            "tests/pester/EvidenceChainInputIndex.Tests.ps1",
            "tests/pester/EvidenceChainProducerAdapter.Tests.ps1",
            "tests/pester/EvidenceChainClosePrep.Tests.ps1",
            "tests/pester/Issue16ClosePrep.Tests.ps1",
            "tests/pester/Issue16MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $readme "docs/50-issue16-close-preparation\.md|docs/51-issue16-main-validation-evidence\.md"
            Assert-KitEqual ($paths -contains $path) $true
        }
    }
}
