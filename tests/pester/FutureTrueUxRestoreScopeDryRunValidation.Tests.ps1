Describe "Future true UX restore scope dry-run validation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "runs the unified scope dry-run validator" {
        $reportPath = Join-Path $env:TEMP "future-ux-scope-dryrun-pester.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreScopeDryRun.ps1") -ReportPath $reportPath | Out-Null
        Assert-KitEqual $LASTEXITCODE 0

        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.aggregate.trueExecution $false
        Assert-KitEqual $report.aggregate.mutationCount 0
    }

}
