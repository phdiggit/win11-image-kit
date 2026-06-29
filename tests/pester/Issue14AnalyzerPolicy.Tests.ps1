Describe "Issue 14 analyzer policy" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $script:Settings = Get-Content -LiteralPath (Join-Path $script:RepoRoot "PSScriptAnalyzerSettings.psd1") -Raw -Encoding UTF8
    }

    It "keeps PSScriptAnalyzer settings explicit and local" {
        foreach ($term in @(
            "Severity",
            "ExcludeRules",
            "PSAvoidUsingWriteHost",
            "PSUseShouldProcessForStateChangingFunctions",
            "PSUseCompatibleSyntax",
            "'5.1'",
            "'7.0'"
        )) {
            Assert-KitMatch $script:Settings ([regex]::Escape($term))
        }
    }

    It "keeps analyzer workflow non-blocking for missing module and diagnostics" {
        foreach ($term in @(
            "Get-Module -ListAvailable Pester, PSScriptAnalyzer",
            "Get-Command Invoke-ScriptAnalyzer",
            "PSScriptAnalyzer is not available on this runner",
            "without blocking CI",
            "Invoke-ScriptAnalyzer -Path scripts -Recurse -Settings .\PSScriptAnalyzerSettings.psd1",
            'Write-Warning ("PSScriptAnalyzer reported {0} diagnostics'
        )) {
            Assert-KitMatch $script:Workflow ([regex]::Escape($term))
        }

        Assert-KitNotMatch $script:Workflow "Install-Module\s+PSScriptAnalyzer"
    }

    It "documents analyzer policy without pretending missing modules are success" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\40-issue14-quality-gates.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'PSScriptAnalyzer uses `PSScriptAnalyzerSettings.psd1`',
            "unavailable",
            "warning/manual",
            "does not pretend that analyzer diagnostics were executed",
            "does not add online module installation"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }
}
