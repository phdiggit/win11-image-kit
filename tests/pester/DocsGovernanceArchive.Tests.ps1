Describe "Docs governance archive integrity" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:PrunedFutureTrueUxArchiveDirs = @(
            "docs\archive\future-true-ux-restore\01-mock-review",
            "docs\archive\future-true-ux-restore\02-negative-review",
            "docs\archive\future-true-ux-restore\03-approval-checklist",
            "docs\archive\future-true-ux-restore\04-packet-preview",
            "docs\archive\future-true-ux-restore\05-human-handoff",
            "docs\archive\future-true-ux-restore\06-no-execution-audit"
        )
        $script:PrunedFutureTrueUxStageFiles = @(
            "80-future-true-ux-restore-mock-review-packet-drill.md",
            "81-future-true-ux-restore-mock-maintainer-review-transcript.md",
            "82-future-true-ux-restore-mock-decision-ledger.md",
            "83-future-true-ux-restore-mock-drill-lessons.md",
            "102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md",
            "103-future-true-ux-restore-state-name-separation-matrix.md",
            "104-future-true-ux-restore-artifact-chain-consistency-index.md",
            "105-future-true-ux-restore-no-execution-stop-line.md"
        )
    }

    It "has a canonical docs index and archive directories" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\README.md")) $true
        foreach ($dir in @(
            "docs\archive\completed-roadmap\issue-6",
            "docs\archive\completed-roadmap\issue-13",
            "docs\archive\future-true-ux-restore\00-governance"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $dir)) $true
        }
        foreach ($dir in @(
            "docs\archive\completed-roadmap\issue-14",
            "docs\archive\completed-roadmap\issue-15",
            "docs\archive\completed-roadmap\issue-16",
            "docs\archive\completed-roadmap\issue-17",
            "docs\archive\completed-roadmap\issue-18"
        ) + $script:PrunedFutureTrueUxArchiveDirs) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $dir)) $false
        }
    }

    It "keeps pruned Future True UX stage docs out of root and archive" {
        $futureArchiveRoot = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore"
        foreach ($fileName in $script:PrunedFutureTrueUxStageFiles) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot (Join-Path "docs" $fileName))) $false
            $archiveMatches = @(Get-ChildItem -LiteralPath $futureArchiveRoot -Recurse -Filter $fileName -File)
            Assert-KitEqual $archiveMatches.Count 0
        }
    }

    It "does not leave Pester literal path references to deleted Future True UX stage docs" {
        $pesterFiles = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "tests\pester") -Filter "*.Tests.ps1"
        $deletedRefs = @()
        foreach ($file in $pesterFiles) {
            if ($file.Name -eq "DocsGovernanceArchive.Tests.ps1") {
                continue
            }
            $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            foreach ($fileName in $script:PrunedFutureTrueUxStageFiles) {
                if ($text -match [regex]::Escape($fileName)) {
                    $deletedRefs += "$($file.Name):$fileName"
                }
            }
        }

        Assert-KitEqual $deletedRefs.Count 0
    }

    It "does not keep deleted Future True UX stage gate entrypoints" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $entrypoints = @($qualityGates.gates.entrypoint)
        foreach ($fileName in $script:PrunedFutureTrueUxStageFiles) {
            $matchingEntrypoints = @($entrypoints | Where-Object { $_ -like "*$fileName" })
            Assert-KitEqual $matchingEntrypoints.Count 0
        }
        foreach ($gateId in @(
            "future-true-ux-mock-decision-ledger",
            "future-true-ux-negative-review-drill",
            "future-true-ux-approval-checklist-ergonomics",
            "future-true-ux-integrated-packet-preview",
            "future-true-ux-human-authorization-handoff"
        )) {
            Assert-KitEqual (@($qualityGates.gates.id) -contains $gateId) $false
        }
    }

    It "keeps canonical Future True UX docs in archive governance" {
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\00-governance\65-future-true-ux-restore-execution-split.md",
            "docs\archive\future-true-ux-restore\00-governance\66-future-true-ux-restore-authorization-intake.md",
            "docs\archive\future-true-ux-restore\00-governance\67-future-true-ux-restore-evidence-model.md",
            "docs\archive\future-true-ux-restore\00-governance\68-future-true-ux-restore-dry-run-plan.md",
            "docs\archive\future-true-ux-restore\00-governance\69-future-true-ux-restore-current-user-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\79-future-true-ux-restore-authorization-state-machine.md",
            "docs\archive\future-true-ux-restore\00-governance\106-future-true-ux-restore-final-stop-line-handoff.md",
            "docs\archive\future-true-ux-restore\00-governance\107-future-true-ux-restore-stop-line-decision-matrix.md",
            "docs\archive\future-true-ux-restore\00-governance\108-repo-documentation-script-governance-audit.md",
            "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) $true
        }
    }

    It "keeps root docs limited to Chinese operator docs and root entrypoints" {
        $rootDocs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -File -Filter "*.md" | ForEach-Object { $_.Name })
        $forbiddenEnglishStageDocs = @($rootDocs | Where-Object { $_ -match '^\d+-.+\.md$' -and $_ -notmatch '^(00|01|02|03|04|05|06|07|08|09|10)-' })
        Assert-KitEqual $forbiddenEnglishStageDocs.Count 0

        foreach ($name in @(
            "README.md",
            "codex-workflow.md",
            "codex-task-card-template.md",
            "vm-test-runbook.md"
        )) {
            Assert-KitEqual ($rootDocs -contains $name) $true
        }
    }

    It "keeps Future True UX quality gate entrypoints existing and semantics unchanged" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $futureGates = @($qualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        Assert-KitEqual ($futureGates.Count -gt 0) $true

        foreach ($gate in $futureGates) {
            Assert-KitEqual $gate.layer "pr-fast"
            Assert-KitEqual $gate.trigger "pull_request"
            Assert-KitEqual $gate.mode "report-only"
            Assert-KitEqual $gate.required $true
            Assert-KitEqual $gate.blocking $true
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $gate.entrypoint)) $true
        }
    }

    It "keeps Build Lock required paths existing" {
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($entry in @($buildLock.entries | Where-Object { $_.required -eq $true })) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $entry.path)) $true
        }
    }

    It "keeps governance docs free of Issue 19 close keywords and true execution drift" {
        foreach ($path in @(
            "docs\README.md",
            "docs\archive\future-true-ux-restore\00-governance\108-repo-documentation-script-governance-audit.md",
            "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md"
        )) {
            $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $doc "(?i)\b(fixes|closes|resolves)\s+#19\b"
            Assert-KitNotMatch $doc "authorizationApproved\s*=\s*true"
            Assert-KitNotMatch $doc "executionApproved\s*=\s*true"
            Assert-KitNotMatch $doc "executeReady\s*=\s*true"
            Assert-KitNotMatch $doc "trueExecution\s*=\s*true"
        }
    }
}
