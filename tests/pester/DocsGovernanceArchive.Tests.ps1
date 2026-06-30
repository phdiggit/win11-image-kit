Describe "Docs governance archive integrity" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $items = @(
            @{ Family = "01-mock-review"; File = "80-future-true-ux-restore-mock-review-packet-drill.md" },
            @{ Family = "01-mock-review"; File = "81-future-true-ux-restore-mock-maintainer-review-transcript.md" },
            @{ Family = "01-mock-review"; File = "82-future-true-ux-restore-mock-decision-ledger.md" },
            @{ Family = "01-mock-review"; File = "83-future-true-ux-restore-mock-drill-lessons.md" },
            @{ Family = "02-negative-review"; File = "84-future-true-ux-restore-negative-review-drill-bundle.md" },
            @{ Family = "02-negative-review"; File = "85-future-true-ux-restore-negative-review-transcript.md" },
            @{ Family = "02-negative-review"; File = "86-future-true-ux-restore-negative-decision-ledger.md" },
            @{ Family = "02-negative-review"; File = "87-future-true-ux-restore-negative-drill-lessons.md" },
            @{ Family = "03-approval-checklist"; File = "88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md" },
            @{ Family = "03-approval-checklist"; File = "89-future-true-ux-restore-review-packet-readability-guide.md" },
            @{ Family = "03-approval-checklist"; File = "90-future-true-ux-restore-manual-decision-form-template.md" },
            @{ Family = "03-approval-checklist"; File = "91-future-true-ux-restore-approval-checklist-lessons.md" },
            @{ Family = "04-packet-preview"; File = "92-future-true-ux-restore-integrated-authorization-packet-preview.md" },
            @{ Family = "04-packet-preview"; File = "93-future-true-ux-restore-packet-preview-field-map.md" },
            @{ Family = "04-packet-preview"; File = "94-future-true-ux-restore-packet-preview-reviewer-reading-order.md" },
            @{ Family = "04-packet-preview"; File = "95-future-true-ux-restore-packet-preview-blocker-index.md" },
            @{ Family = "04-packet-preview"; File = "96-future-true-ux-restore-packet-preview-lessons.md" },
            @{ Family = "05-human-handoff"; File = "97-future-true-ux-restore-human-authorization-handoff.md" },
            @{ Family = "05-human-handoff"; File = "98-future-true-ux-restore-human-handoff-artifact-index.md" },
            @{ Family = "05-human-handoff"; File = "99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md" },
            @{ Family = "05-human-handoff"; File = "100-future-true-ux-restore-human-handoff-review-boundary.md" },
            @{ Family = "05-human-handoff"; File = "101-future-true-ux-restore-human-handoff-lessons.md" },
            @{ Family = "06-no-execution-audit"; File = "102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md" },
            @{ Family = "06-no-execution-audit"; File = "103-future-true-ux-restore-state-name-separation-matrix.md" },
            @{ Family = "06-no-execution-audit"; File = "104-future-true-ux-restore-artifact-chain-consistency-index.md" },
            @{ Family = "06-no-execution-audit"; File = "105-future-true-ux-restore-no-execution-stop-line.md" }
        )
        $script:ArchiveMap = @($items | ForEach-Object {
            @{
                Old = Join-Path "docs" $_.File
                New = Join-Path (Join-Path "docs\archive\future-true-ux-restore" $_.Family) $_.File
            }
        })
    }

    It "has a canonical docs index and archive directories" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\README.md")) $true
        foreach ($dir in @(
            "docs\archive\completed-roadmap\issue-6",
            "docs\archive\completed-roadmap\issue-13",
            "docs\archive\future-true-ux-restore\00-governance",
            "docs\archive\future-true-ux-restore\01-mock-review",
            "docs\archive\future-true-ux-restore\02-negative-review",
            "docs\archive\future-true-ux-restore\03-approval-checklist",
            "docs\archive\future-true-ux-restore\04-packet-preview",
            "docs\archive\future-true-ux-restore\05-human-handoff",
            "docs\archive\future-true-ux-restore\06-no-execution-audit"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $dir)) $true
        }
        foreach ($dir in @(
            "docs\archive\completed-roadmap\issue-14",
            "docs\archive\completed-roadmap\issue-15",
            "docs\archive\completed-roadmap\issue-16",
            "docs\archive\completed-roadmap\issue-17",
            "docs\archive\completed-roadmap\issue-18"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $dir)) $false
        }
    }

    It "moves docs 80 through 105 out of root and into archive" {
        foreach ($item in $script:ArchiveMap) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $item.Old)) $false
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $item.New)) $true
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
            "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md",
            "docs\archive\future-true-ux-restore\00-governance\110-future-true-ux-archive-policy-reference-map.md",
            "docs\archive\future-true-ux-restore\00-governance\111-future-true-ux-archive-dry-run-plan.md"
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

    It "does not leave Pester literal path references to missing moved docs" {
        $pesterFiles = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "tests\pester") -Filter "*.Tests.ps1"
        $missingMovedRefs = @()
        foreach ($file in $pesterFiles) {
            $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            foreach ($item in $script:ArchiveMap) {
                if ($text -match [regex]::Escape($item.Old) -and -not (Test-Path -LiteralPath (Join-Path $script:RepoRoot $item.Old))) {
                    $missingMovedRefs += "$($file.Name):$($item.Old)"
                }
            }
        }

        Assert-KitEqual $missingMovedRefs.Count 0
    }

    It "keeps governance docs free of Issue 19 close keywords and true execution drift" {
        foreach ($path in @(
            "docs\README.md",
            "docs\archive\future-true-ux-restore\00-governance\108-repo-documentation-script-governance-audit.md",
            "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md",
            "docs\archive\future-true-ux-restore\00-governance\110-future-true-ux-archive-policy-reference-map.md",
            "docs\archive\future-true-ux-restore\00-governance\111-future-true-ux-archive-dry-run-plan.md"
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
