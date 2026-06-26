Describe "Evidence chain report input index" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "keeps the input index schema closed and parseable" {
        foreach ($relativePath in @(
            "manifests\evidence-report-inputs.json",
            "schemas\evidence-report-inputs.schema.json",
            "tests\fixtures\evidence-chain\sample-report-input-index.json"
        )) {
            Assert-KitDoesNotThrow {
                Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
            }
        }

        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\evidence-report-inputs.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.input.additionalProperties $false
    }

    It "declares only known producers with repo-relative non-private paths" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\evidence-chain.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $index = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\evidence-report-inputs.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $producerIds = @($manifest.producers.id)

        foreach ($input in @($index.inputs)) {
            Assert-KitEqual ($producerIds -contains [string]$input.producerId) $true
            Assert-KitEqual ([IO.Path]::IsPathRooted([string]$input.path)) $false
            Assert-KitNotMatch ([string]$input.path) '(^|[\\/])paths\.local\.json$'
            Assert-KitNotMatch ([string]$input.path) '^[A-Za-z]:[\\/]'
            Assert-KitNotMatch ([string]$input.path) '^\\\\'
        }
    }

    It "writes input report identity and baseline normalization summary" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.inputSetId "issue16-pr-fast-fixture"
        Assert-KitEqual @($report.inputReports).Count 5
        Assert-KitEqual $report.producerNormalization.normalizedCount 5
        Assert-KitEqual $report.producerNormalization.missingRequiredCount 0
        Assert-KitEqual $report.producerNormalization.reportTypeMismatchCount 0
        Assert-KitEqual $report.producerNormalization.disallowedManualCount 0
        Assert-KitEqual $report.producerNormalization.disallowedNotCapturedCount 0
        Assert-KitEqual $report.producerNormalization.inputPolicyViolationCount 0
    }
}
