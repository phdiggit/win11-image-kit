Describe "Issue 15 close preparation candidate" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\46-issue15-close-preparation.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "adds a manual closure candidate without final closure claims" {
        Assert-KitMatch $script:Doc 'Status:\s*`ready-for-manual-closure-candidate`'
        Assert-KitMatch $script:Doc "PR Fast CI is not main/workflow evidence"
        Assert-KitMatch $script:Doc "manual closure candidate only"
        Assert-KitMatch $script:Doc "paths\.local\.json.*Build Lock"
        Assert-KitMatch $script:Doc "Do not use auto-close keywords"
        Assert-KitNotMatch $script:Doc "(?i)(Fixes|Closes|Resolves)\s+#15"
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
        Assert-KitEqual ($paths -contains "docs/46-issue15-close-preparation.md") $true
        Assert-KitEqual ($paths -contains "docs/47-issue15-main-validation-evidence.md") $true
    }
}
