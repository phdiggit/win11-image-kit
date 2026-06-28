Describe "Future true UX restore end-to-end no-execution readiness audit" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-no-execution-audit-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passed readiness audit validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-end-to-end-no-execution-readiness-audit.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.repositoryAudit.auditDecision "audit-ready"
        Assert-KitEqual @($report.cases).Count 7
    }

    It "covers every required Future True UX Restore layer" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport -Manifest $manifest -Request $null -RepoRoot $script:RepoRoot

        foreach ($layer in @(
            "authorization-intake",
            "current-user-dry-run",
            "default-user-dry-run",
            "offline-image-dry-run",
            "machine-dry-run",
            "authorization-review",
            "mock-review-drill",
            "negative-review-drill",
            "approval-checklist-ergonomics",
            "integrated-packet-preview",
            "human-authorization-handoff"
        )) {
            Assert-KitEqual (@($report.requiredLayers) -contains $layer) $true
        }
        Assert-KitEqual @($report.missingLayers).Count 0
    }

    It "keeps all execution flags frozen false and mutation count zero" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport -Manifest $manifest -Request $null -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.authorizationApproved $false
        Assert-KitEqual $report.executionApproved $false
        Assert-KitEqual $report.executeReady $false
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
        Assert-KitEqual @($report.flagDrift).Count 0
    }

    It "separates review states from authorization, execution, and closure states" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (@($manifest.approvalChecklistErgonomics.allowedChecklistDecisions) -contains "approval-checklist-ready") $true
        Assert-KitEqual (@($manifest.approvalChecklistErgonomics.allowedChecklistDecisions) -contains "authorization-review-ready") $false
        Assert-KitEqual (@($manifest.integratedPacketPreview.allowedPreviewDecisions) -contains "packet-preview-ready") $true
        Assert-KitEqual (@($manifest.integratedPacketPreview.allowedPreviewDecisions) -contains "authorization-review-ready") $false
        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.allowedHandoffDecisions) -contains "handoff-ready-for-human-review") $true
        Assert-KitEqual (@($manifest.humanAuthorizationHandoff.allowedHandoffDecisions) -contains "authorization-review-ready") $false
        foreach ($state in @("execute-ready", "executed", "completed", "issue-18-complete", "closure-ready")) {
            Assert-KitEqual (@($manifest.endToEndNoExecutionReadinessAudit.forbiddenStates) -contains $state) $true
        }
    }

    It "keeps active Future True UX Restore docs free of Issue 18 auto-close terms" {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*future-true-ux-restore*.md") {
            $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }

    It "does not contain real execution command verbs in the audit scripts" {
        $scriptText = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1") -Raw -Encoding UTF8
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

    It "matches fixture expected audit decisions" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\no-execution-readiness-audit"
        foreach ($file in Get-ChildItem -LiteralPath $fixtureRoot -Filter "*.json") {
            $request = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.auditDecision ([string]$request.expectedDecision)
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }
}
