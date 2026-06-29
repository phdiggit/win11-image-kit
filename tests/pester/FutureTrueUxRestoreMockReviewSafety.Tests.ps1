Describe "Future true UX restore mock review safety" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")
    }

    It "blocks execute-ready, executed, completed, private path, auto-close, and cross-scope fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ File = "negative-execute-ready.json"; Pattern = "execute-ready" },
            @{ File = "negative-executed.json"; Pattern = "executed" },
            @{ File = "negative-completed.json"; Pattern = "completed" },
            @{ File = "negative-private-path.json"; Pattern = "private path" },
            @{ File = "negative-auto-close-keyword.json"; Pattern = "auto-close" },
            @{ File = "negative-cross-scope-packet.json"; Pattern = "scope guard" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review\$($case.File)") -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.reviewDecision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "keeps dangerous command names out of mock review scripts" {
        $patterns = @(
            '\bSet-ItemProperty\b',
            '\bNew-ItemProperty\b',
            '\bRemove-ItemProperty\b',
            '\breg\.exe\b',
            '\breg\s+add\b',
            '\breg\s+delete\b',
            '\bDism(\.exe)?\b',
            '\bImport-StartLayout\b',
            '\bExport-StartLayout\b',
            '\bGet-StartApps\b',
            '\bGet-AppxPackage\b',
            '\bGet-AppxProvisionedPackage\b',
            '\bInvoke-Expression\b',
            '\bInvoke-WebRequest\b',
            '\bInvoke-RestMethod\b',
            '\bInstall-Module\b',
            '\bwinget\b',
            '\bchoco\b',
            '\bmsiexec\b'
        )
        $files = @(
            "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1",
            "scripts\validate\Test-FutureTrueUxRestoreMockReviewDrill.ps1",
            "scripts\config\Show-FutureTrueUxRestoreMockReviewDrillPlan.ps1"
        )

        foreach ($file in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $file) -Raw -Encoding UTF8
            foreach ($pattern in $patterns) {
                Assert-KitNotMatch $text $pattern
            }
        }
    }

    It "does not create Issue 18 completion summary or weaken archived Issue 6-17 closure docs" {
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\01-mock-review\80-future-true-ux-restore-mock-review-packet-drill.md",
            "docs\archive\future-true-ux-restore\01-mock-review\81-future-true-ux-restore-mock-maintainer-review-transcript.md",
            "docs\archive\future-true-ux-restore\01-mock-review\82-future-true-ux-restore-mock-decision-ledger.md",
            "docs\archive\future-true-ux-restore\01-mock-review\83-future-true-ux-restore-mock-drill-lessons.md"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
            Assert-KitMatch $text "(?i)(mock|review|blocked|not execution approval|trueExecution=false)"
        }

        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" -Recurse) {
            Assert-KitNotMatch $file.Name "completion-summary"
        }

        foreach ($issue in 6..17) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-$issue")) $true
        }

        $docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap") -Filter "*.md" -Recurse | Where-Object { $_.FullName -match 'issue-(6|7|8|9|10|11|12|13|14|15|16|17)' })
        foreach ($doc in $docs) {
            $text = Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#(6|7|8|9|10|11|12|13|14|15|16|17)\b"
        }
    }
}
