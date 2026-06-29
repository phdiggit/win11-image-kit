Describe "Future True UX archive dry-run plan" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\111-future-true-ux-archive-dry-run-plan.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "exists and records the dry-run status marker" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-true-ux-archive-dry-run-plan`'
        Assert-KitMatch $script:Doc "No file moves are performed in this PR"
        Assert-KitMatch $script:Doc "No file deletions are performed in this PR"
        Assert-KitMatch $script:Doc "No archive directory is required or created in this PR"
    }

    It "keeps Issue 19 and true execution boundaries closed" {
        Assert-KitMatch $script:Doc "Refs #19"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#19\b"
        Assert-KitMatch $script:Doc '\| `authorizationApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executionApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executeReady` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `trueExecution` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `mutationCount` \| `0` \|'
        Assert-KitNotMatch $script:Doc "authorizationApproved\s*=\s*true"
        Assert-KitNotMatch $script:Doc "executionApproved\s*=\s*true"
        Assert-KitNotMatch $script:Doc "executeReady\s*=\s*true"
        Assert-KitNotMatch $script:Doc "trueExecution\s*=\s*true"
    }

    It "marks every proposed move row as not movable in this PR" {
        $rows = @([regex]::Matches($script:Doc, '(?m)^\| `docs/[0-9]+-future-true-ux-restore-[^`]+\.md` \| `docs/archive/future-true-ux-restore/[^`]+\.md` \| .+ \| .+ \| no \| .+ \|$'))
        Assert-KitEqual $rows.Count 26

        foreach ($row in $rows) {
            Assert-KitMatch $row.Value "\| no \|"
            Assert-KitNotMatch $row.Value "\| yes \|"
        }
    }

    It "keeps proposed archive paths under the approved archive root" {
        $proposedPaths = @([regex]::Matches($script:Doc, '`docs/archive/future-true-ux-restore/([^`]+)`') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -match "\.md$" })
        Assert-KitEqual $proposedPaths.Count 26

        foreach ($relativePath in $proposedPaths) {
            Assert-KitMatch $relativePath "^(01-mock-review|02-negative-review|03-approval-checklist|04-packet-preview|05-human-handoff|06-no-execution-audit)/[0-9]+-future-true-ux-restore-.+\.md$"
        }
    }

    It "keeps canonical docs in place" {
        foreach ($path in @(
            "docs\65-future-true-ux-restore-execution-split.md",
            "docs\106-future-true-ux-restore-final-stop-line-handoff.md",
            "docs\107-future-true-ux-restore-stop-line-decision-matrix.md",
            "docs\108-repo-documentation-script-governance-audit.md",
            "docs\109-future-true-ux-quality-gate-governance.md",
            "docs\110-future-true-ux-archive-policy-reference-map.md",
            "docs\111-future-true-ux-archive-dry-run-plan.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) $true
        }
    }

    It "does not require an actual archive directory or moved files" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive")) $false

        foreach ($path in @(
            "docs\80-future-true-ux-restore-mock-review-packet-drill.md",
            "docs\84-future-true-ux-restore-negative-review-drill-bundle.md",
            "docs\92-future-true-ux-restore-integrated-authorization-packet-preview.md",
            "docs\97-future-true-ux-restore-human-authorization-handoff.md",
            "docs\102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md",
            "docs\105-future-true-ux-restore-no-execution-stop-line.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) $true
        }
    }
}
