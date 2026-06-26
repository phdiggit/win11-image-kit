Describe "Issue 16 main validation evidence scaffold" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps docs 51 pending-only" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\51-issue16-main-validation-evidence.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`pending-main-validation`'
        foreach ($field in @(
            'Trigger source | `pending`',
            'Main SHA | `pending`',
            'Workflow run | `pending`',
            'Full Validate job | `pending`',
            'Result | `pending`',
            'Report status | `pending`',
            'failedCount | `pending`',
            'blockedCount | `pending`',
            'runId | `pending`',
            'normalizedCount | `pending`',
            'missingRequiredCount | `pending`',
            'reportTypeMismatchCount | `pending`',
            'disallowedManualCount | `pending`',
            'disallowedNotCapturedCount | `pending`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($field))
        }
        Assert-KitMatch $doc "Pull request-only Fast CI is not a substitute"
        Assert-KitMatch $doc 'PR Fast CI substitute allowed \| `false`'
        Assert-KitNotMatch $doc "(?i)\b(fixes|closes|resolves)\s+#16\b"
    }

    It "keeps real lifecycle evidence not-run or not-captured" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\51-issue16-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($field in @(
            'Real build | `not-run`',
            'Capture | `not-run`',
            'Deploy | `not-run`',
            'Admin/VM smoke | `not-provided`',
            'Real WIM SHA256 | `not-captured`',
            'DISM image info | `not-captured`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($field))
        }
    }
}
