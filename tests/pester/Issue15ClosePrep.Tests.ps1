Describe "Issue 15 close preparation candidate" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-15\46-issue15-close-preparation.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "adds manual closure readiness without final closure claims" {
        Assert-KitMatch $script:Doc 'Status:\s*`(ready-for-manual-closure-candidate|ready-for-manual-closure)`'
        Assert-KitMatch $script:Doc "PR Fast CI is not main/workflow evidence"
        Assert-KitMatch $script:Doc "(manual closure candidate only|maintainer manual closure)"
        Assert-KitMatch $script:Doc "paths\.local\.json.*Build Lock"
        Assert-KitMatch $script:Doc "Do not use auto-close keywords"
        Assert-KitNotMatch $script:Doc "(?i)(Fixes|Closes|Resolves)\s+#15"
    }

    It "requires main validation evidence when close prep is ready" {
        if ($script:Doc -match 'Status:\s*`ready-for-manual-closure`') {
            Assert-KitMatch $script:Doc "post-PR #77 main push Full Validate"
            $evidenceDoc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-15\47-issue15-main-validation-evidence.md") -Raw -Encoding UTF8
            Assert-KitMatch $evidenceDoc 'Status:\s*`ready-for-manual-closure`'
            Assert-KitMatch $evidenceDoc '\| Result \| `success` \|'
        }
    }

    It "does not add an Issue 15 completion summary" {
        $issue15Docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue15*" | ForEach-Object { $_.Name })
        Assert-KitEqual (@($issue15Docs | Where-Object { $_ -match "completion-summary" }).Count) 0
    }

    It "keeps close-prep and main evidence in the fast CI and Build Lock scope" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries | ForEach-Object { [string]$_.path })

        Assert-KitMatch $workflow "tests/pester/Issue15ClosePrep\.Tests\.ps1"
        Assert-KitMatch $workflow "tests/pester/Issue15MainValidationEvidence\.Tests\.ps1"
        Assert-KitEqual ($paths -contains "docs/archive/completed-roadmap/issue-15/46-issue15-close-preparation.md") $true
        Assert-KitEqual ($paths -contains "docs/archive/completed-roadmap/issue-15/47-issue15-main-validation-evidence.md") $true
    }
}
