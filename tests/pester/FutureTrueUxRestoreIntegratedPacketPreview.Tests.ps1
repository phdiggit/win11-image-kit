Describe "Future true UX restore integrated packet preview" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreIntegratedPacketPreviewReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-packet-preview-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing integrated packet preview validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-integrated-packet-preview.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreIntegratedPacketPreview.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual @($report.cases).Count 7
    }

    It "matches fixture expected decisions without execution flags" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\packet-preview"
        foreach ($file in Get-ChildItem -LiteralPath $fixtureRoot -Filter "*.json") {
            $request = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreIntegratedPacketPreviewReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.previewDecision ([string]$request.expectedDecision)
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "separates packet-preview-ready from authorization-review-ready" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (@($manifest.integratedPacketPreview.allowedPreviewDecisions) -contains "packet-preview-ready") $true
        Assert-KitEqual (@($manifest.integratedPacketPreview.allowedPreviewDecisions) -contains "authorization-review-ready") $false
        Assert-KitEqual (@($manifest.integratedPacketPreview.forbiddenPreviewDecisions) -contains "authorization-review-ready") $true
        Assert-KitEqual (@($manifest.integratedPacketPreview.forbiddenPreviewDecisions) -contains "execute-ready") $true
    }

    It "blocks unredacted private paths" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\packet-preview\private-path-not-redacted.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreIntegratedPacketPreviewReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.previewDecision "blocked"
        Assert-KitEqual ($report.privatePathMatchCount -gt 0) $true
        Assert-KitMatch ($report.blockingReasons -join "`n") "private path"
    }

    It "keeps docs free of Issue 18 auto-close keywords" {
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\04-packet-preview\92-future-true-ux-restore-integrated-authorization-packet-preview.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\93-future-true-ux-restore-packet-preview-field-map.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\94-future-true-ux-restore-packet-preview-reviewer-reading-order.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\95-future-true-ux-restore-packet-preview-blocker-index.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\96-future-true-ux-restore-packet-preview-lessons.md"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
            Assert-KitMatch $text "packet-preview"
        }
    }

    It "does not contain real execution command verbs in the preview scripts" {
        $scriptText = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreIntegratedPacketPreviewReport.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreIntegratedPacketPreview.ps1") -Raw -Encoding UTF8
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
