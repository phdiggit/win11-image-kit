Describe "Future true UX restore evidence packet" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "extends the evidence schema with review packet fields while keeping execution false" {
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-evidence.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixture = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\evidence\baseline-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ($schema.required -contains "reviewDecision") $true
        Assert-KitEqual ($schema.required -contains "executeReady") $true
        Assert-KitEqual ($schema.required -contains "evidencePacket") $true
        Assert-KitEqual (@($schema.'$defs'.reviewDecision.enum) -contains "authorization-review-ready") $true
        Assert-KitEqual $schema.properties.executeReady.const $false
        Assert-KitEqual $schema.'$defs'.evidencePacket.properties.trueExecution.const $false
        Assert-KitEqual $schema.'$defs'.evidencePacket.properties.mutationCount.const 0
        Assert-KitEqual $fixture.reviewDecision "blocked"
        Assert-KitEqual $fixture.executeReady $false
        Assert-KitEqual $fixture.evidencePacket.executeReady $false
        Assert-KitEqual $fixture.evidencePacket.trueExecution $false
        Assert-KitEqual $fixture.evidencePacket.mutationCount 0
        Assert-KitEqual $fixture.evidencePacket.userConfigurationConfirmed $false
    }

    It "requires every review packet to carry independent evidence placeholders" {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\review") -Filter "*review-ready.json") {
            $request = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $packet = $request.evidencePacket

            foreach ($field in @(
                "scope",
                "targetIdentity",
                "requestedMutationType",
                "dryRunCommandEnvelope",
                "rollbackPlan",
                "beforeEvidence",
                "afterEvidencePlaceholder",
                "independentVerificationPlaceholder",
                "scopeGuardAssertion",
                "privacyRedactionStatement",
                "failurePropagation",
                "reviewerChecklist"
            )) {
                Assert-KitEqual ([string]::IsNullOrWhiteSpace([string]$packet.$field)) $false
            }
            Assert-KitEqual $packet.authorizationApproved $false
            Assert-KitEqual $packet.executionApproved $false
            Assert-KitEqual $packet.executeReady $false
            Assert-KitEqual $packet.trueExecution $false
            Assert-KitEqual $packet.mutationCount 0
            Assert-KitEqual $packet.userConfigurationConfirmed $false
        }
    }
}
