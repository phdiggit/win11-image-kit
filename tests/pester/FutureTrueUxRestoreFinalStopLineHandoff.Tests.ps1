Describe "Future true UX restore final stop-line handoff" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-final-stop-line-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passed final stop-line validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-final-stop-line-handoff.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.repositoryHandoff.stopLineDecision "pause-at-stop-line"
        Assert-KitEqual @($report.cases).Count 5
    }

    It "keeps final stop-line flags frozen false and mutation count zero" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $null -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.authorizationApproved $false
        Assert-KitEqual $report.executionApproved $false
        Assert-KitEqual $report.executeReady $false
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
        Assert-KitEqual @($report.flagDrift).Count 0
    }

    It "keeps stop-line docs present with expected status markers" {
        $doc106 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\106-future-true-ux-restore-final-stop-line-handoff.md") -Raw -Encoding UTF8
        $doc107 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\107-future-true-ux-restore-stop-line-decision-matrix.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc106 'Status:\s*`final-stop-line-handoff`'
        Assert-KitMatch $doc107 'Status:\s*`stop-line-decision-matrix`'
        Assert-KitMatch $doc106 "pause at the stop-line"
        Assert-KitMatch $doc107 "pause-at-stop-line"
    }

    It "blocks auto-close and execution or closure wording in fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($fixture in @("auto-close-wording-blocked.json", "execute-ready-wording-blocked.json")) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\final-stop-line-handoff\$fixture") -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.stopLineDecision "blocked"
            Assert-KitEqual (@($report.blockingReasons).Count -gt 0) $true
        }
    }

    It "requires a human decision boundary and fresh Runner Gate before true restore planning" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\final-stop-line-handoff\start-true-restore-planning-requires-new-chain.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.stopLineDecision "start-true-restore-planning"
        Assert-KitEqual $report.requiresNewRunnerGateForTrueRestorePlanning $true
        Assert-KitEqual $report.authorizationApproved $false
        Assert-KitEqual $report.executionApproved $false
    }

    It "matches fixture expected decisions" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\final-stop-line-handoff"
        foreach ($file in Get-ChildItem -LiteralPath $fixtureRoot -Filter "*.json") {
            $request = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.stopLineDecision ([string]$request.expectedDecision)
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "does not contain real execution command verbs in the final stop-line scripts" {
        $scriptText = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1") -Raw -Encoding UTF8
        ) -join "`n"

        foreach ($pattern in @(
            "Start-Process",
            "Invoke-Expression",
            "Set-ItemProperty",
            "New-ItemProperty",
            "Remove-AppxPackage",
            "Add-MpPreference",
            "\bdism\b",
            "\bwinget\b",
            "\bchoco\b",
            "\bmsiexec\b",
            "Invoke-WebRequest",
            "Invoke-RestMethod",
            "Install-Module"
        )) {
            Assert-KitNotMatch $scriptText $pattern
        }
    }
}
