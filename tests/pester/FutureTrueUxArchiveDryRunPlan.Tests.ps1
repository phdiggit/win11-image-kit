Describe "Future True UX archive dry-run plan" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\111-future-true-ux-archive-dry-run-plan.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "exists and records the implementation state" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-true-ux-archive-dry-run-plan`'
        Assert-KitMatch $script:Doc 'the files were moved into `docs/archive/future-true-ux-restore/`'
        Assert-KitMatch $script:Doc "No file deletion is authorized"
        Assert-KitMatch $script:Doc "No workflow behavior change is authorized"
    }

    It "keeps Issue 19 and true execution boundaries closed" {
        Assert-FutureTrueUxGovernanceBoundary -DocumentText $script:Doc -IssueNumber 19
    }

    It "records every implemented old root path to archive path row" {
        $oldRootPaths = @([regex]::Matches($script:Doc, '`(docs/[0-9]+-future-true-ux-restore-[^`]+\.md)`') | ForEach-Object { $_.Groups[1].Value })
        $archivePaths = @([regex]::Matches($script:Doc, '`(docs/archive/future-true-ux-restore/[^`]+\.md)`') | ForEach-Object { $_.Groups[1].Value } | Where-Object {
            $_ -match "/(01-mock-review|02-negative-review|03-approval-checklist|04-packet-preview|05-human-handoff|06-no-execution-audit)/"
        })

        Assert-KitEqual $oldRootPaths.Count 26
        Assert-KitEqual $archivePaths.Count 26

        for ($documentNumber = 80; $documentNumber -le 105; $documentNumber++) {
            $oldPath = @($oldRootPaths | Where-Object { $_ -like "docs/$documentNumber-*" })
            $archivePath = @($archivePaths | Where-Object { $_ -like "docs/archive/future-true-ux-restore/*/$documentNumber-*" })
            Assert-KitEqual $oldPath.Count 1
            Assert-KitEqual $archivePath.Count 1
        }
    }

    It "keeps archive paths under the approved archive root" {
        $archivePaths = @([regex]::Matches($script:Doc, '`docs/archive/future-true-ux-restore/([^`]+)`') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -match "\.md$" } | Sort-Object -Unique)
        Assert-KitEqual $archivePaths.Count 33

        foreach ($relativePath in $archivePaths) {
            Assert-KitMatch $relativePath "^(00-governance|01-mock-review|02-negative-review|03-approval-checklist|04-packet-preview|05-human-handoff|06-no-execution-audit)/[0-9]+-.+\.md$"
        }
    }

    It "keeps canonical docs in place and archived files present" {
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\00-governance\65-future-true-ux-restore-execution-split.md",
            "docs\archive\future-true-ux-restore\00-governance\106-future-true-ux-restore-final-stop-line-handoff.md",
            "docs\archive\future-true-ux-restore\00-governance\107-future-true-ux-restore-stop-line-decision-matrix.md",
            "docs\archive\future-true-ux-restore\00-governance\108-repo-documentation-script-governance-audit.md",
            "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md",
            "docs\archive\future-true-ux-restore\00-governance\110-future-true-ux-archive-policy-reference-map.md",
            "docs\archive\future-true-ux-restore\00-governance\111-future-true-ux-archive-dry-run-plan.md",
            "docs\archive\future-true-ux-restore\01-mock-review\80-future-true-ux-restore-mock-review-packet-drill.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\105-future-true-ux-restore-no-execution-stop-line.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) $true
        }
    }
}
