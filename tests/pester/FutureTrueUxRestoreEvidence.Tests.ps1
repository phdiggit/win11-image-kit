Describe "Future true UX restore evidence model" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps authorization and evidence schemas closed" {
        $authorizationSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-authorization.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $evidenceSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-evidence.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $evidenceFixture = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\evidence\baseline-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $authorizationSchema.additionalProperties $false
        Assert-KitEqual $authorizationSchema.'$defs'.authorizationRequest.additionalProperties $false
        Assert-KitEqual (@($authorizationSchema.'$defs'.scope.enum) -join ",") "current-user,default-user,offline-image,machine"
        Assert-KitEqual (@($authorizationSchema.'$defs'.decision.enum) -join ",") "blocked,dry-run-ready,authorized-pending-review,needs-more-evidence,authorization-review-ready,rejected"
        Assert-KitEqual $evidenceSchema.additionalProperties $false
        Assert-KitEqual $evidenceSchema.properties.trueExecution.const $false
        Assert-KitEqual $evidenceSchema.properties.mutationCount.const 0
        Assert-KitEqual $evidenceSchema.properties.commandExitCodeSufficient.const $false
        Assert-KitEqual $evidenceSchema.properties.userConfigurationConfirmed.const $false
        Assert-KitEqual ($evidenceSchema.required -contains "currentUserEvidenceContract") $true
        Assert-KitEqual ($evidenceSchema.required -contains "defaultUserEvidenceContract") $true
        Assert-KitEqual ($evidenceSchema.required -contains "offlineImageEvidenceContract") $true
        Assert-KitEqual ($evidenceSchema.required -contains "machineEvidenceContract") $true
        Assert-KitEqual ($evidenceSchema.required -contains "scopeEvidenceContracts") $true
        Assert-KitEqual ($evidenceSchema.required -contains "reviewDecision") $true
        Assert-KitEqual ($evidenceSchema.required -contains "executeReady") $true
        Assert-KitEqual ($evidenceSchema.required -contains "evidencePacket") $true
        Assert-KitEqual (@($evidenceSchema.'$defs'.reviewDecision.enum) -contains "authorization-review-ready") $true
        Assert-KitEqual $evidenceFixture.trueExecution $false
        Assert-KitEqual $evidenceFixture.mutationCount 0
        Assert-KitEqual $evidenceFixture.commandExitCodeSufficient $false
        Assert-KitEqual $evidenceFixture.userConfigurationConfirmed $false
        Assert-KitEqual $evidenceFixture.reviewDecision "blocked"
        Assert-KitEqual $evidenceFixture.executeReady $false
        Assert-KitEqual $evidenceFixture.evidencePacket.executeReady $false
        foreach ($contractName in @("currentUserEvidenceContract", "defaultUserEvidenceContract", "offlineImageEvidenceContract", "machineEvidenceContract")) {
            Assert-KitEqual $evidenceFixture.$contractName.trueExecution $false
            Assert-KitEqual $evidenceFixture.$contractName.mutationCount 0
            Assert-KitEqual $evidenceFixture.$contractName.privatePathRedacted $true
        }
    }

    It "documents per-scope evidence requirements" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\67-future-true-ux-restore-evidence-model.md") -Raw -Encoding UTF8

        foreach ($term in @("current-user", "default-user", "offline-image", "machine", "Independent Verification", "Command exit code alone", "not real UX success evidence")) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }
}
