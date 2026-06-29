Describe "Future true UX restore approval checklist ergonomics" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-approval-checklist-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing approval checklist validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-approval-checklist.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreApprovalChecklistErgonomics.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual @($report.cases).Count 6
    }

    It "matches fixture expected decisions without execution flags" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\approval-checklist"
        foreach ($file in Get-ChildItem -LiteralPath $fixtureRoot -Filter "*.json") {
            $request = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.checklistDecision ([string]$request.expectedDecision)
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "requires all checklist sections and separates checklist-ready from authorization-review-ready" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (@($manifest.approvalChecklistErgonomics.allowedChecklistDecisions) -contains "approval-checklist-ready") $true
        Assert-KitEqual (@($manifest.approvalChecklistErgonomics.allowedChecklistDecisions) -contains "authorization-review-ready") $false
        Assert-KitEqual (@($manifest.approvalChecklistErgonomics.forbiddenChecklistDecisions) -contains "authorization-review-ready") $true

        $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\approval-checklist\complete-current-user-checklist.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot
        foreach ($section in @($manifest.approvalChecklistErgonomics.requiredChecklistSections)) {
            Assert-KitEqual ($report.checklistSections.PSObject.Properties.Name -contains [string]$section) $true
        }
    }

    It "keeps docs free of Issue 18 auto-close keywords" {
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\03-approval-checklist\88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\89-future-true-ux-restore-review-packet-readability-guide.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\90-future-true-ux-restore-manual-decision-form-template.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\91-future-true-ux-restore-approval-checklist-lessons.md"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
            Assert-KitMatch $text "checklist-ready"
        }
    }

    It "does not contain real execution command verbs in the validator scripts" {
        $scriptText = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreApprovalChecklistErgonomics.ps1") -Raw -Encoding UTF8
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
