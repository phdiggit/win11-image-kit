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
            "docs\archive\future-true-ux-restore\00-governance\66-future-true-ux-restore-authorization-intake.md",
            "docs\archive\future-true-ux-restore\00-governance\67-future-true-ux-restore-evidence-model.md",
            "docs\archive\future-true-ux-restore\00-governance\68-future-true-ux-restore-dry-run-plan.md",
            "docs\archive\future-true-ux-restore\00-governance\69-future-true-ux-restore-current-user-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\70-future-true-ux-restore-current-user-evidence-contract.md",
            "docs\archive\future-true-ux-restore\00-governance\71-future-true-ux-restore-execute-gate-dual-approval.md",
            "docs\archive\future-true-ux-restore\00-governance\72-future-true-ux-restore-default-user-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\73-future-true-ux-restore-offline-image-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\74-future-true-ux-restore-machine-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\75-future-true-ux-restore-scope-guard-matrix.md",
            "docs\archive\future-true-ux-restore\00-governance\76-future-true-ux-restore-unified-authorization-request.md",
            "docs\archive\future-true-ux-restore\00-governance\77-future-true-ux-restore-maintainer-review-checkpoint.md",
            "docs\archive\future-true-ux-restore\00-governance\78-future-true-ux-restore-evidence-packet-contract.md",
            "docs\archive\future-true-ux-restore\00-governance\79-future-true-ux-restore-authorization-state-machine.md",
            "docs\archive\future-true-ux-restore\01-mock-review\80-future-true-ux-restore-mock-review-packet-drill.md",
            "docs\archive\future-true-ux-restore\01-mock-review\81-future-true-ux-restore-mock-maintainer-review-transcript.md",
            "docs\archive\future-true-ux-restore\01-mock-review\82-future-true-ux-restore-mock-decision-ledger.md",
            "docs\archive\future-true-ux-restore\01-mock-review\83-future-true-ux-restore-mock-drill-lessons.md",
            "docs\archive\future-true-ux-restore\02-negative-review\84-future-true-ux-restore-negative-review-drill-bundle.md",
            "docs\archive\future-true-ux-restore\02-negative-review\85-future-true-ux-restore-negative-review-transcript.md",
            "docs\archive\future-true-ux-restore\02-negative-review\86-future-true-ux-restore-negative-decision-ledger.md",
            "docs\archive\future-true-ux-restore\02-negative-review\87-future-true-ux-restore-negative-drill-lessons.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\89-future-true-ux-restore-review-packet-readability-guide.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\90-future-true-ux-restore-manual-decision-form-template.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\91-future-true-ux-restore-approval-checklist-lessons.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\92-future-true-ux-restore-integrated-authorization-packet-preview.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\93-future-true-ux-restore-packet-preview-field-map.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\94-future-true-ux-restore-packet-preview-reviewer-reading-order.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\95-future-true-ux-restore-packet-preview-blocker-index.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\96-future-true-ux-restore-packet-preview-lessons.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\97-future-true-ux-restore-human-authorization-handoff.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\98-future-true-ux-restore-human-handoff-artifact-index.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\100-future-true-ux-restore-human-handoff-review-boundary.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\101-future-true-ux-restore-human-handoff-lessons.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\103-future-true-ux-restore-state-name-separation-matrix.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\104-future-true-ux-restore-artifact-chain-consistency-index.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\105-future-true-ux-restore-no-execution-stop-line.md",
            "docs\archive\future-true-ux-restore\00-governance\106-future-true-ux-restore-final-stop-line-handoff.md",
            "docs\archive\future-true-ux-restore\00-governance\107-future-true-ux-restore-stop-line-decision-matrix.md"
        )) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $doc)) $true
        }

        $doc66 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\66-future-true-ux-restore-authorization-intake.md") -Raw -Encoding UTF8
        $doc67 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\67-future-true-ux-restore-evidence-model.md") -Raw -Encoding UTF8
        $doc68 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\68-future-true-ux-restore-dry-run-plan.md") -Raw -Encoding UTF8
        $doc69 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\69-future-true-ux-restore-current-user-dry-run-gate.md") -Raw -Encoding UTF8
        $doc70 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\70-future-true-ux-restore-current-user-evidence-contract.md") -Raw -Encoding UTF8
        $doc71 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\71-future-true-ux-restore-execute-gate-dual-approval.md") -Raw -Encoding UTF8
        $doc72 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\72-future-true-ux-restore-default-user-dry-run-gate.md") -Raw -Encoding UTF8
        $doc73 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\73-future-true-ux-restore-offline-image-dry-run-gate.md") -Raw -Encoding UTF8
        $doc74 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\74-future-true-ux-restore-machine-dry-run-gate.md") -Raw -Encoding UTF8
        $doc75 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\75-future-true-ux-restore-scope-guard-matrix.md") -Raw -Encoding UTF8
        $doc76 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\76-future-true-ux-restore-unified-authorization-request.md") -Raw -Encoding UTF8
        $doc77 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\77-future-true-ux-restore-maintainer-review-checkpoint.md") -Raw -Encoding UTF8
        $doc78 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\78-future-true-ux-restore-evidence-packet-contract.md") -Raw -Encoding UTF8
        $doc79 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\79-future-true-ux-restore-authorization-state-machine.md") -Raw -Encoding UTF8
        $doc80 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review\80-future-true-ux-restore-mock-review-packet-drill.md") -Raw -Encoding UTF8
        $doc81 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review\81-future-true-ux-restore-mock-maintainer-review-transcript.md") -Raw -Encoding UTF8
        $doc82 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review\82-future-true-ux-restore-mock-decision-ledger.md") -Raw -Encoding UTF8
        $doc83 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review\83-future-true-ux-restore-mock-drill-lessons.md") -Raw -Encoding UTF8
        $doc84 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\02-negative-review\84-future-true-ux-restore-negative-review-drill-bundle.md") -Raw -Encoding UTF8
        $doc85 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\02-negative-review\85-future-true-ux-restore-negative-review-transcript.md") -Raw -Encoding UTF8
        $doc86 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\02-negative-review\86-future-true-ux-restore-negative-decision-ledger.md") -Raw -Encoding UTF8
        $doc87 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\02-negative-review\87-future-true-ux-restore-negative-drill-lessons.md") -Raw -Encoding UTF8
        $doc88 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\03-approval-checklist\88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md") -Raw -Encoding UTF8
        $doc89 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\03-approval-checklist\89-future-true-ux-restore-review-packet-readability-guide.md") -Raw -Encoding UTF8
        $doc90 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\03-approval-checklist\90-future-true-ux-restore-manual-decision-form-template.md") -Raw -Encoding UTF8
        $doc91 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\03-approval-checklist\91-future-true-ux-restore-approval-checklist-lessons.md") -Raw -Encoding UTF8
        $doc92 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\04-packet-preview\92-future-true-ux-restore-integrated-authorization-packet-preview.md") -Raw -Encoding UTF8
        $doc93 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\04-packet-preview\93-future-true-ux-restore-packet-preview-field-map.md") -Raw -Encoding UTF8
        $doc94 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\04-packet-preview\94-future-true-ux-restore-packet-preview-reviewer-reading-order.md") -Raw -Encoding UTF8
        $doc95 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\04-packet-preview\95-future-true-ux-restore-packet-preview-blocker-index.md") -Raw -Encoding UTF8
        $doc96 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\04-packet-preview\96-future-true-ux-restore-packet-preview-lessons.md") -Raw -Encoding UTF8
        $doc97 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\05-human-handoff\97-future-true-ux-restore-human-authorization-handoff.md") -Raw -Encoding UTF8
        $doc98 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\05-human-handoff\98-future-true-ux-restore-human-handoff-artifact-index.md") -Raw -Encoding UTF8
        $doc99 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\05-human-handoff\99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md") -Raw -Encoding UTF8
        $doc100 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\05-human-handoff\100-future-true-ux-restore-human-handoff-review-boundary.md") -Raw -Encoding UTF8
        $doc101 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\05-human-handoff\101-future-true-ux-restore-human-handoff-lessons.md") -Raw -Encoding UTF8
        $doc102 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\06-no-execution-audit\102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md") -Raw -Encoding UTF8
        $doc103 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\06-no-execution-audit\103-future-true-ux-restore-state-name-separation-matrix.md") -Raw -Encoding UTF8
        $doc104 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\06-no-execution-audit\104-future-true-ux-restore-artifact-chain-consistency-index.md") -Raw -Encoding UTF8
        $doc105 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\06-no-execution-audit\105-future-true-ux-restore-no-execution-stop-line.md") -Raw -Encoding UTF8
        $doc106 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\106-future-true-ux-restore-final-stop-line-handoff.md") -Raw -Encoding UTF8
        $doc107 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\107-future-true-ux-restore-stop-line-decision-matrix.md") -Raw -Encoding UTF8
        Assert-KitMatch $doc66 'Status:\s*`authorization-intake`'
        Assert-KitMatch $doc67 'Status:\s*`evidence-model-draft`'
        Assert-KitMatch $doc68 'Status:\s*`dry-run-plan`'
        Assert-KitMatch $doc69 'Status:\s*`current-user-dry-run-gate`'
        Assert-KitMatch $doc70 'Status:\s*`evidence-contract-draft`'
        Assert-KitMatch $doc71 'Status:\s*`execute-gate-draft`'
        Assert-KitMatch $doc72 'Status:\s*`default-user-dry-run-gate`'
        Assert-KitMatch $doc73 'Status:\s*`offline-image-dry-run-gate`'
        Assert-KitMatch $doc74 'Status:\s*`machine-dry-run-gate`'
        Assert-KitMatch $doc75 'Status:\s*`scope-guard-matrix`'
        Assert-KitMatch $doc76 'Status:\s*`authorization-request-draft`'
        Assert-KitMatch $doc77 'Status:\s*`review-checkpoint-draft`'
        Assert-KitMatch $doc78 'Status:\s*`evidence-packet-draft`'
        Assert-KitMatch $doc79 'Status:\s*`authorization-state-machine`'
        Assert-KitMatch $doc80 'Status:\s*`mock-review-drill`'
        Assert-KitMatch $doc81 'Status:\s*`mock-review-transcript`'
        Assert-KitMatch $doc82 'Status:\s*`mock-decision-ledger`'
        Assert-KitMatch $doc83 'Status:\s*`mock-drill-lessons`'
        Assert-KitMatch $doc84 'Status:\s*`negative-review-drill`'
        Assert-KitMatch $doc85 'Status:\s*`negative-review-transcript`'
        Assert-KitMatch $doc86 'Status:\s*`negative-decision-ledger`'
        Assert-KitMatch $doc87 'Status:\s*`negative-drill-lessons`'
        Assert-KitMatch $doc88 'Status:\s*`approval-checklist-ergonomics`'
        Assert-KitMatch $doc89 'Status:\s*`approval-checklist-readability-guide`'
        Assert-KitMatch $doc90 'Status:\s*`approval-checklist-form-template`'
        Assert-KitMatch $doc91 'Status:\s*`approval-checklist-lessons`'
        Assert-KitMatch $doc92 'Status:\s*`integrated-packet-preview`'
        Assert-KitMatch $doc93 'Status:\s*`integrated-packet-preview-field-map`'
        Assert-KitMatch $doc94 'Status:\s*`integrated-packet-preview-reading-order`'
        Assert-KitMatch $doc95 'Status:\s*`integrated-packet-preview-blocker-index`'
        Assert-KitMatch $doc96 'Status:\s*`integrated-packet-preview-lessons`'
        Assert-KitMatch $doc97 'Status:\s*`human-authorization-handoff`'
        Assert-KitMatch $doc98 'Status:\s*`human-authorization-handoff-artifact-index`'
        Assert-KitMatch $doc99 'Status:\s*`human-authorization-handoff-manual-decision-placeholder`'
        Assert-KitMatch $doc100 'Status:\s*`human-authorization-handoff-review-boundary`'
        Assert-KitMatch $doc101 'Status:\s*`human-authorization-handoff-lessons`'
        Assert-KitMatch $doc102 'Status:\s*`end-to-end-no-execution-readiness-audit`'
        Assert-KitMatch $doc103 'Status:\s*`state-name-separation-matrix`'
        Assert-KitMatch $doc104 'Status:\s*`artifact-chain-consistency-index`'
        Assert-KitMatch $doc105 'Status:\s*`no-execution-stop-line`'
        Assert-KitMatch $doc106 'Status:\s*`final-stop-line-handoff`'
        Assert-KitMatch $doc107 'Status:\s*`stop-line-decision-matrix`'

        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates.id)
        Assert-KitEqual ($gateIds -contains "future-true-ux-restore-authorization") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-restore-evidence-model") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-current-user-dry-run") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-scope-dry-run") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-scope-guard-matrix") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-execute-gate") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-authorization-review") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-mock-review-drill") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-mock-decision-ledger") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-evidence-packet") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-negative-review-drill") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-approval-checklist-ergonomics") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-integrated-packet-preview") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-human-authorization-handoff") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-end-to-end-no-execution-readiness-audit") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-final-stop-line-handoff") $true
    }

    It "keeps Issue 18 stop-line state frozen without resident completed-roadmap docs" {
        $doc65 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\65-future-true-ux-restore-execution-split.md") -Raw -Encoding UTF8
        $doc106 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\106-future-true-ux-restore-final-stop-line-handoff.md") -Raw -Encoding UTF8
        Assert-KitMatch $doc65 'Status:\s*`future-split`'
        Assert-KitMatch $doc106 'Status:\s*`final-stop-line-handoff`'
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-18")) $false
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" -Recurse) {
            Assert-KitNotMatch $file.Name "completion-summary"
        }
        foreach ($path in @(
            "docs\archive\future-true-ux-restore\00-governance\66-future-true-ux-restore-authorization-intake.md",
            "docs\archive\future-true-ux-restore\00-governance\67-future-true-ux-restore-evidence-model.md",
            "docs\archive\future-true-ux-restore\00-governance\68-future-true-ux-restore-dry-run-plan.md",
            "docs\archive\future-true-ux-restore\00-governance\72-future-true-ux-restore-default-user-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\73-future-true-ux-restore-offline-image-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\74-future-true-ux-restore-machine-dry-run-gate.md",
            "docs\archive\future-true-ux-restore\00-governance\75-future-true-ux-restore-scope-guard-matrix.md",
            "docs\archive\future-true-ux-restore\00-governance\76-future-true-ux-restore-unified-authorization-request.md",
            "docs\archive\future-true-ux-restore\00-governance\77-future-true-ux-restore-maintainer-review-checkpoint.md",
            "docs\archive\future-true-ux-restore\00-governance\78-future-true-ux-restore-evidence-packet-contract.md",
            "docs\archive\future-true-ux-restore\00-governance\79-future-true-ux-restore-authorization-state-machine.md",
            "docs\archive\future-true-ux-restore\01-mock-review\80-future-true-ux-restore-mock-review-packet-drill.md",
            "docs\archive\future-true-ux-restore\01-mock-review\81-future-true-ux-restore-mock-maintainer-review-transcript.md",
            "docs\archive\future-true-ux-restore\01-mock-review\82-future-true-ux-restore-mock-decision-ledger.md",
            "docs\archive\future-true-ux-restore\01-mock-review\83-future-true-ux-restore-mock-drill-lessons.md",
            "docs\archive\future-true-ux-restore\02-negative-review\84-future-true-ux-restore-negative-review-drill-bundle.md",
            "docs\archive\future-true-ux-restore\02-negative-review\85-future-true-ux-restore-negative-review-transcript.md",
            "docs\archive\future-true-ux-restore\02-negative-review\86-future-true-ux-restore-negative-decision-ledger.md",
            "docs\archive\future-true-ux-restore\02-negative-review\87-future-true-ux-restore-negative-drill-lessons.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\88-future-true-ux-restore-maintainer-approval-checklist-ergonomics.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\89-future-true-ux-restore-review-packet-readability-guide.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\90-future-true-ux-restore-manual-decision-form-template.md",
            "docs\archive\future-true-ux-restore\03-approval-checklist\91-future-true-ux-restore-approval-checklist-lessons.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\92-future-true-ux-restore-integrated-authorization-packet-preview.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\93-future-true-ux-restore-packet-preview-field-map.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\94-future-true-ux-restore-packet-preview-reviewer-reading-order.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\95-future-true-ux-restore-packet-preview-blocker-index.md",
            "docs\archive\future-true-ux-restore\04-packet-preview\96-future-true-ux-restore-packet-preview-lessons.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\97-future-true-ux-restore-human-authorization-handoff.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\98-future-true-ux-restore-human-handoff-artifact-index.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\99-future-true-ux-restore-human-handoff-manual-decision-placeholder.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\100-future-true-ux-restore-human-handoff-review-boundary.md",
            "docs\archive\future-true-ux-restore\05-human-handoff\101-future-true-ux-restore-human-handoff-lessons.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\103-future-true-ux-restore-state-name-separation-matrix.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\104-future-true-ux-restore-artifact-chain-consistency-index.md",
            "docs\archive\future-true-ux-restore\06-no-execution-audit\105-future-true-ux-restore-no-execution-stop-line.md",
            "docs\archive\future-true-ux-restore\00-governance\106-future-true-ux-restore-final-stop-line-handoff.md",
            "docs\archive\future-true-ux-restore\00-governance\107-future-true-ux-restore-stop-line-decision-matrix.md"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }
}
