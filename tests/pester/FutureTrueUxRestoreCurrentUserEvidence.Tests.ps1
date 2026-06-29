Describe "Future true UX restore current-user evidence contract" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents current-user evidence collector contract" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\70-future-true-ux-restore-current-user-evidence-contract.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`evidence-contract-draft`'
        foreach ($term in @("redacted user identity", "Before Evidence", "Dry-run Command Envelope", "After Evidence Placeholder", "Independent Verification Placeholder", "Rollback", "private paths", "command exit code", "manual checklist")) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "extends evidence schema with current-user no-execution contract" {
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-evidence.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $contract = $schema.'$defs'.currentUserEvidenceContract

        Assert-KitEqual $contract.additionalProperties $false
        foreach ($field in @("redactedUserIdentity", "beforeEvidence", "dryRunCommandEnvelope", "rollbackPlan", "afterEvidencePlaceholder", "independentVerificationPlaceholder", "failurePropagation", "reviewCheckpoint")) {
            Assert-KitEqual (@($contract.required) -contains $field) $true
        }
        Assert-KitEqual $contract.properties.privatePathRedacted.const $true
        Assert-KitEqual $contract.properties.currentUserConfirmed.const $false
        Assert-KitEqual $contract.properties.trueExecution.const $false
        Assert-KitEqual $contract.properties.mutationCount.const 0
    }
}
