Describe "Future true UX restore validation runner" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-authorization-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing validation report while baseline remains blocked" {
        $reportPath = Join-Path $script:TempRoot "future-ux-authorization.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreAuthorization.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.baseline.decision "blocked"
        Assert-KitEqual $report.baseline.trueExecution $false
        Assert-KitEqual $report.baseline.mutationCount 0
    }

    It "prints a dry-run-only plan" {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\config\Show-FutureTrueUxRestoreAuthorizationPlan.ps1") | Out-String

        Assert-KitMatch $output "Dry-run only: true"
        Assert-KitMatch $output "Default deny: true"
        Assert-KitMatch $output "True execution: false"
        Assert-KitMatch $output "Mutation count: 0"
        Assert-KitMatch $output "current-user"
        Assert-KitMatch $output "default-user"
        Assert-KitMatch $output "offline-image"
        Assert-KitMatch $output "machine"
    }

    It "keeps docs and gates synchronized for authorization intake" {
        foreach ($doc in @(
            "docs\66-future-true-ux-restore-authorization-intake.md",
            "docs\67-future-true-ux-restore-evidence-model.md",
            "docs\68-future-true-ux-restore-dry-run-plan.md",
            "docs\69-future-true-ux-restore-current-user-dry-run-gate.md",
            "docs\70-future-true-ux-restore-current-user-evidence-contract.md",
            "docs\71-future-true-ux-restore-execute-gate-dual-approval.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $doc)) $true
        }

        $doc66 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\66-future-true-ux-restore-authorization-intake.md") -Raw -Encoding UTF8
        $doc67 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\67-future-true-ux-restore-evidence-model.md") -Raw -Encoding UTF8
        $doc68 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\68-future-true-ux-restore-dry-run-plan.md") -Raw -Encoding UTF8
        $doc69 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\69-future-true-ux-restore-current-user-dry-run-gate.md") -Raw -Encoding UTF8
        $doc70 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\70-future-true-ux-restore-current-user-evidence-contract.md") -Raw -Encoding UTF8
        $doc71 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\71-future-true-ux-restore-execute-gate-dual-approval.md") -Raw -Encoding UTF8
        Assert-KitMatch $doc66 'Status:\s*`authorization-intake`'
        Assert-KitMatch $doc67 'Status:\s*`evidence-model-draft`'
        Assert-KitMatch $doc68 'Status:\s*`dry-run-plan`'
        Assert-KitMatch $doc69 'Status:\s*`current-user-dry-run-gate`'
        Assert-KitMatch $doc70 'Status:\s*`evidence-contract-draft`'
        Assert-KitMatch $doc71 'Status:\s*`execute-gate-draft`'

        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates.id)
        Assert-KitEqual ($gateIds -contains "future-true-ux-restore-authorization") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-restore-evidence-model") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-current-user-dry-run") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-execute-gate") $true
    }

    It "keeps Issue 18 ready state frozen and avoids completion summary wording" {
        $doc64 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\64-issue18-manual-closure-handoff.md") -Raw -Encoding UTF8
        $doc65 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\65-future-true-ux-restore-execution-split.md") -Raw -Encoding UTF8
        Assert-KitMatch $doc64 "not an Issue #18 completion summary"
        Assert-KitMatch $doc65 'Status:\s*`future-split`'
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md") {
            Assert-KitNotMatch $file.Name "completion-summary"
        }
        foreach ($path in @(
            "docs\66-future-true-ux-restore-authorization-intake.md",
            "docs\67-future-true-ux-restore-evidence-model.md",
            "docs\68-future-true-ux-restore-dry-run-plan.md"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }
}
