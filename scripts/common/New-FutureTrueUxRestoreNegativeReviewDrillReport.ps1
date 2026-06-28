[CmdletBinding()]
param()

. "$PSScriptRoot\New-FutureTrueUxRestoreMockReviewDrillReport.ps1"

function Add-FutureTrueUxNegativeReason {
    param(
        [Parameter(Mandatory)]
        [ref]$Reasons,

        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not (@($Reasons.Value.code) -contains $Code)) {
        $Reasons.Value += [pscustomobject][ordered]@{
            code = $Code
            message = $Message
        }
    }
}

function Test-FutureTrueUxNegativeFlag {
    param(
        [AllowNull()]
        $Value
    )

    if ($Value -eq $true) {
        return $true
    }

    if ($Value -is [string]) {
        return ($Value -match '^(?i:true|yes|1)$')
    }

    return $false
}

function New-FutureTrueUxRestoreNegativeReviewEvidenceClassification {
    param(
        [Parameter(Mandatory)]
        $Request
    )

    [pscustomobject][ordered]@{
        dryRunEvidence = (Test-FutureTrueUxNegativeFlag -Value $Request.dryRunReportAsSuccess)
        handlerReportEvidence = (Test-FutureTrueUxNegativeFlag -Value $Request.handlerReportAsSuccess)
        manualChecklistEvidence = (Test-FutureTrueUxNegativeFlag -Value $Request.manualChecklistAsSuccess)
        mockEvidence = (Test-FutureTrueUxNegativeFlag -Value $Request.mockArtifactAsRealEvidence)
        trueUxRestoreEvidence = $false
        acceptedAsTrueEvidence = $false
    }
}

function New-FutureTrueUxRestoreNegativeReviewTranscript {
    param(
        [Parameter(Mandatory)]
        [string]$CaseId,

        [Parameter(Mandatory)]
        [object[]]$Reasons,

        [Parameter(Mandatory)]
        [string]$Decision
    )

    $summary = "Negative drill case '$CaseId' remains review-only and cannot authorize execution."
    $findingText = @($Reasons | ForEach-Object { "$($_.code): $($_.message)" })

    [pscustomobject][ordered]@{
        summary = $summary
        decision = $Decision
        findings = @($findingText)
        warning = "Dry-run, handler, manual, mock, and CI artifacts are not true UX restore evidence."
        executionBoundary = "No restore command, installer, registry, profile, AppX, service, DISM, Defender, Junction, Start menu, taskbar, Sysprep, or network action is allowed by this drill."
    }
}

function New-FutureTrueUxRestoreNegativeReviewDecisionLedger {
    param(
        [Parameter(Mandatory)]
        [string]$CaseId,

        [Parameter(Mandatory)]
        [string]$Decision,

        [Parameter(Mandatory)]
        [object[]]$Reasons
    )

    $ledger = @(
        [pscustomobject][ordered]@{
            stage = "negative-case-received"
            caseId = $CaseId
            decision = "review-only"
            executeReady = $false
        }
    )

    foreach ($reason in $Reasons) {
        $ledger += [pscustomobject][ordered]@{
            stage = "negative-reason-recorded"
            caseId = $CaseId
            reasonCode = $reason.code
            decision = $Decision
            executeReady = $false
        }
    }

    $ledger += [pscustomobject][ordered]@{
        stage = "execution-blocked"
        caseId = $CaseId
        decision = "not-approved"
        executeReady = $false
    }

    @($ledger)
}

function New-FutureTrueUxRestoreNegativeReviewDrillReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        $Request,

        [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    )

    $section = $Manifest.negativeReviewDrill
    $caseId = $Request.caseId
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        $caseId = $Request.requestId
    }
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        $caseId = "negative-review-case"
    }

    $scope = $Request.scope
    if ([string]::IsNullOrWhiteSpace($scope)) {
        $scope = $section.defaultScope
    }

    $packet = Get-FutureTrueUxRestoreReviewEvidencePacket -Request $Request
    $reasons = @()

    if (-not (Test-FutureTrueUxNegativeFlag -Value $Request.maintainerApprovalPresent)) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "missing-maintainer-approval" -Message "Maintainer approval is absent, so the packet cannot advance."
    }

    if ($Request.reviewDecision -in @("authorization-review-ready", "execute-ready", "executed", "completed") -or
        (Test-FutureTrueUxNegativeFlag -Value $Request.executeReady) -or
        (Test-FutureTrueUxNegativeFlag -Value $Request.executed) -or
        (Test-FutureTrueUxNegativeFlag -Value $Request.completed)) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "high-risk-mutation-intent" -Message "The request tries to advance from negative review into execution language."
    }

    if (($Request.PSObject.Properties.Name -contains "scopes") -and @($Request.scopes).Count -gt 1) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "scope-ambiguous-or-expanded" -Message "Multiple scopes are present in a single review packet."
    }

    if ($packet -and -not [string]::IsNullOrWhiteSpace($packet.scope) -and $packet.scope -ne $scope) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "scope-ambiguous-or-expanded" -Message "Evidence packet scope does not match the requested scope."
    }

    if ($packet -and -not [string]::IsNullOrWhiteSpace($packet.scopeGuardAssertion) -and $packet.scopeGuardAssertion -ne $scope) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "scope-ambiguous-or-expanded" -Message "Scope guard assertion does not match the requested scope."
    }

    if (Test-FutureTrueUxNegativeFlag -Value $Request.exitCodeOnlySuccess) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "exit-code-not-ux-evidence" -Message "A command exit code does not prove that the user-visible UX state was restored."
    }

    if ((Test-FutureTrueUxNegativeFlag -Value $Request.dryRunReportAsSuccess) -or
        (Test-FutureTrueUxNegativeFlag -Value $Request.handlerReportAsSuccess) -or
        (Test-FutureTrueUxNegativeFlag -Value $Request.manualChecklistAsSuccess)) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "report-only-not-real-evidence" -Message "Report-only, dry-run, handler, or manual checklist artifacts are not real restore evidence."
    }

    if (Test-FutureTrueUxNegativeFlag -Value $Request.mockArtifactAsRealEvidence) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "mock-only-not-real-evidence" -Message "Mock review packets and ledgers cannot be promoted into real restore evidence."
    }

    if ((Test-FutureTrueUxNegativeFlag -Value $Request.staleOrInconsistent) -or
        ($Request.headShaMatches -eq $false) -or
        ($Request.artifactIdMatches -eq $false) -or
        ($Request.approvalTimestampMatches -eq $false) -or
        ($Request.decisionLedgerConsistent -eq $false)) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "stale-or-inconsistent-packet" -Message "Packet metadata is stale or inconsistent across approval, artifact, and ledger fields."
    }

    $rollbackText = $Request.rollbackPlan
    if ($packet -and -not [string]::IsNullOrWhiteSpace($packet.rollbackPlan)) {
        $rollbackText = $packet.rollbackPlan
    }

    if ([string]::IsNullOrWhiteSpace($rollbackText)) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "missing-rollback-plan" -Message "No rollback or restore explanation is present."
    }

    $allStrings = Get-FutureTrueUxRestoreStrings -InputObject $Request
    $highRiskPattern = '(?i)\b(registry|hklm|hkcu|dism|appx|startlayout|defender|junction|service|sysprep|winget|choco|msiexec|invoke-webrequest|invoke-restmethod|install-module)\b'
    foreach ($text in $allStrings) {
        if ($text -match $highRiskPattern) {
            Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "high-risk-mutation-intent" -Message "High-risk mutation vocabulary appears in a report-only review path."
            break
        }
    }

    if ($reasons.Count -eq 0) {
        Add-FutureTrueUxNegativeReason -Reasons ([ref]$reasons) -Code "missing-maintainer-approval" -Message "Negative drill cases must include at least one explicit blocking reason."
    }

    $reasonCodes = @($reasons | ForEach-Object { $_.code })
    $decision = "needs-rework"
    if ($reasonCodes -contains "high-risk-mutation-intent" -or
        $reasonCodes -contains "scope-ambiguous-or-expanded" -or
        $reasonCodes -contains "stale-or-inconsistent-packet" -or
        $reasonCodes -contains "mock-only-not-real-evidence") {
        $decision = "blocked"
    }
    if ($Request.expectedDecision -eq "rejected") {
        $decision = "rejected"
    }

    $classification = New-FutureTrueUxRestoreNegativeReviewEvidenceClassification -Request $Request
    $transcript = New-FutureTrueUxRestoreNegativeReviewTranscript -CaseId $caseId -Reasons $reasons -Decision $decision
    $ledger = New-FutureTrueUxRestoreNegativeReviewDecisionLedger -CaseId $caseId -Decision $decision -Reasons $reasons

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-negative-review-drill"
        schemaVersion = 1
        caseId = $caseId
        scope = $scope
        reviewDecision = $decision
        allowedDecisions = @($section.allowedNegativeDecisions)
        forbiddenDecisions = @($section.forbiddenNegativeDecisions)
        reasonCodes = @($reasonCodes)
        reasons = @($reasons)
        transcript = $transcript
        decisionLedger = @($ledger)
        evidenceClassification = $classification
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
        blockedForExecution = $true
        lessons = @(
            "Maintainer approval, scoped packet consistency, rollback explanation, and independent user-visible evidence are separate gates.",
            "Exit codes, dry-run reports, handler output, manual checklists, mock packets, and CI status cannot substitute for true UX restore evidence.",
            "Any high-risk mutation vocabulary in a report-only review path keeps execution blocked."
        )
    }
}
