Describe "Future true UX restore human authorization handoff" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreHumanAuthorizationHandoffReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-human-handoff-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing human authorization handoff validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-human-authorization-handoff.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreHumanAuthorizationHandoff.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual @($report.cases).Count 8
    }

    It "matches fixture expected decisions without execution flags" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\human-authorization-handoff"
        foreach ($file in Get-ChildItem -LiteralPath $fixtureRoot -Filter "*.json") {
            $request = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreHumanAuthorizationHandoffReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.handoffDecision ([string]$request.expectedDecision)
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "separates handoff-ready from authorization, execution, and closure states" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.allowedHandoffDecisions) -contains "handoff-ready-for-human-review") $true
        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.allowedHandoffDecisions) -contains "authorization-review-ready") $false
        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.forbiddenHandoffDecisions) -contains "authorization-review-ready") $true
        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.forbiddenHandoffDecisions) -contains "execute-ready") $true
        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.forbiddenHandoffDecisions) -contains "closure-ready") $true
    }

    It "blocks Issue 18 closure and private-path drift" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($fixture in @("handoff-mentions-issue-18-closure.json", "private-path-not-redacted.json")) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\human-authorization-handoff\$fixture") -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreHumanAuthorizationHandoffReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.handoffDecision "blocked"
            Assert-KitEqual (@($report.blockingReasons).Count -gt 0) $true
        }
    }

    It "keeps docs free of Issue 18 auto-close keywords" {
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\05-human-handoff\97-future-true-ux-restore-human-authorization-handoff.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\98-future-true-ux-restore-human-handoff-artifact-index.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\100-future-true-ux-restore-human-handoff-review-boundary.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\101-future-true-ux-restore-human-handoff-lessons.md"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
            Assert-KitMatch $text "handoff"
        }
    }

    It "does not contain real execution command verbs in the handoff scripts" {
        $scriptText = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreHumanAuthorizationHandoffReport.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreHumanAuthorizationHandoff.ps1") -Raw -Encoding UTF8
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
