Describe "Issue 10 context scope acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents the context split and links it from README" {
        $docPath = Join-Path $script:RepoRoot "docs\24-issue10-context-scope-split.md"
        $readmePath = Join-Path $script:RepoRoot "README.md"

        Assert-KitEqual (Test-Path -LiteralPath $docPath) $true
        $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
        $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8

        Assert-KitMatch $doc "machine"
        Assert-KitMatch $doc "default-user"
        Assert-KitMatch $doc "current-user"
        Assert-KitMatch $doc "must not load a real Default User hive"
        Assert-KitMatch $readme "docs/24-issue10-context-scope-split.md"
    }

    It "keeps active context code free of uncontrolled registry and hive writes" {
        $files = @(
            "scripts\common\Resolve-KitContextScope.ps1",
            "scripts\common\New-KitContextPlan.ps1",
            "scripts\common\Test-KitContextSafety.ps1",
            "scripts\validate\Test-ContextScope.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "reg\s+load|reg\.exe\s+load|reg\s+unload|reg\.exe\s+unload"
            Assert-KitNotMatch $text "New-ItemProperty\s+-Path\s+HKCU|Set-ItemProperty\s+-Path\s+HKCU|New-ItemProperty\s+-Path\s+HKLM|Set-ItemProperty\s+-Path\s+HKLM"
            Assert-KitNotMatch $text "Copy-Item.*USERPROFILE|Set-Content.*USERPROFILE|Remove-Item.*USERPROFILE"
        }
    }

    It "includes all Issue 10 tests in PR Fast CI" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        foreach ($testPath in @(
            "tests/pester/ContextScopeSchema.Tests.ps1",
            "tests/pester/ContextScopeResolver.Tests.ps1",
            "tests/pester/ContextScopeSafety.Tests.ps1",
            "tests/pester/ContextScopeReport.Tests.ps1",
            "tests/pester/Issue10ContextScope.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($testPath))
        }

        Assert-KitNotMatch $workflow "reg load|reg unload"
    }

    It "runs the context validation entrypoint in WhatIf report mode" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-issue10-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $reportPath = Join-Path $tempRoot "context-scope-plan.json"
        try {
            & (Join-Path $script:RepoRoot "scripts\validate\Test-ContextScope.ps1") -WhatIf -ReportPath $reportPath | Out-Null
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $report.reportType "context-scope-plan"
            Assert-KitEqual $report.summary.blockedCount 0
            Assert-KitEqual $report.status "manual"
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
