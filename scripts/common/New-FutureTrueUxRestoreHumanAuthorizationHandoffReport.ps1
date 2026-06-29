#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreHandoffSectionValue {
    param(
        [AllowNull()]
        $HandoffSections,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $HandoffSections) {
        return $null
    }

    if ($HandoffSections.PSObject.Properties.Name -contains $Name) {
        return $HandoffSections.$Name
    }

    return $null
}

function Test-FutureTrueUxRestoreHandoffText {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [string]) {
        return -not [string]::IsNullOrWhiteSpace($Value)
    }

    foreach ($text in @($Value | Get-FutureTrueUxRestoreStrings)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$text)) {
            return $true
        }
    }

    return $false
}

function New-FutureTrueUxRestoreHumanAuthorizationHandoffReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [AllowNull()]
        $Request,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "humanAuthorizationHandoff" -DefaultValue $null
    $requiredSections = @()
    $allowedDecisions = @()
    $forbiddenDecisions = @("authorization-review-ready", "execute-ready", "executed", "completed", "issue-18-complete", "closure-ready")
    if ($null -ne $section) {
        $requiredSections = @($section.requiredHandoffSections | ForEach-Object { [string]$_ })
        $allowedDecisions = @($section.allowedHandoffDecisions | ForEach-Object { [string]$_ })
        $forbiddenDecisions = @($section.forbiddenHandoffDecisions | ForEach-Object { [string]$_ })
    }

    $caseId = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "caseId" -DefaultValue "")
    $scope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scope" -DefaultValue "")
    $requestedDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "handoffDecision" -DefaultValue "blocked")
    $handoffSections = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "handoffSections" -DefaultValue $null

    $missingSections = @()
    foreach ($name in $requiredSections) {
        $value = Get-FutureTrueUxRestoreHandoffSectionValue -HandoffSections $handoffSections -Name $name
        if (-not (Test-FutureTrueUxRestoreHandoffText -Value $value)) {
            $missingSections += $name
        }
    }

    $ambiguousSections = @()
    foreach ($name in @("scope", "artifact-index", "evidence-boundary", "rollback-or-restore-plan", "runner-gate-reminder", "manual-decision-placeholder", "non-execution-statement")) {
        $value = [string](Get-FutureTrueUxRestoreHandoffSectionValue -HandoffSections $handoffSections -Name $name)
        if ($value -match '(?i)\b(unclear|ambiguous|maybe|TBD|to be decided|later|unknown)\b') {
            $ambiguousSections += $name
        }
    }

    $blockingReasons = @()
    $needsReworkReasons = @()
    if ($null -eq $section) {
        $blockingReasons += "humanAuthorizationHandoff manifest section is missing"
    }

    if ($allowedDecisions.Count -gt 0 -and $allowedDecisions -notcontains $requestedDecision) {
        $blockingReasons += "handoff decision $requestedDecision is not allowed in this stage"
    }
    if ($forbiddenDecisions -contains $requestedDecision) {
        $blockingReasons += "handoff decision $requestedDecision is forbidden in this stage"
    }

    $validScopes = @(Get-FutureTrueUxRestoreSupportedScopes)
    if ($validScopes -notcontains $scope) {
        $blockingReasons += "scope must name exactly one supported scope"
    }

    if ($missingSections.Count -gt 0) {
        $needsReworkReasons += "missing handoff sections: $($missingSections -join ', ')"
    }
    if ($ambiguousSections.Count -gt 0) {
        $needsReworkReasons += "ambiguous handoff sections: $($ambiguousSections -join ', ')"
    }

    $blockingReasons += @(Get-FutureTrueUxRestoreFrozenStateMessages -InputObject $Request)
    if ($null -ne $section) {
        $blockingReasons += @(Get-FutureTrueUxRestoreFrozenStateMessages -InputObject $section -Subject "manifest")
    }

    $privatePathMatches = @(Test-FutureTrueUxRestorePrivatePath -InputObject $Request)
    if ($privatePathMatches.Count -gt 0) {
        $blockingReasons += "private path must be redacted before human handoff"
    }

    $artifactIndex = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "artifactIndex" -DefaultValue @()
    if (@($artifactIndex).Count -eq 0) {
        $needsReworkReasons += "artifact index must list reviewable handoff inputs"
    }

    $manualDecisionPlaceholder = [string](Get-FutureTrueUxRestoreHandoffSectionValue -HandoffSections $handoffSections -Name "manual-decision-placeholder")
    if ([string]::IsNullOrWhiteSpace($manualDecisionPlaceholder)) {
        $needsReworkReasons += "manual decision placeholder is missing"
    }

    $runnerGateReminder = [string](Get-FutureTrueUxRestoreHandoffSectionValue -HandoffSections $handoffSections -Name "runner-gate-reminder")
    if ([string]::IsNullOrWhiteSpace($runnerGateReminder)) {
        $needsReworkReasons += "runner gate reminder is missing"
    }

    $allText = (@($Request | Get-FutureTrueUxRestoreStrings) -join "`n")
    if ($allText -match (Get-FutureTrueUxRestoreReviewStateDriftPattern -IncludeClosure)) {
        $blockingReasons += "handoff wording drifts into authorization, execution, or closure state"
    }
    if ($allText -match '(?i)\b(completion summary|close-prep|main-evidence|closure-ready)\b') {
        $blockingReasons += "Issue 18 closure handoff wording is blocked"
    }
    if ($allText -match (Get-FutureTrueUxRestoreEvidencePromotionPattern)) {
        $needsReworkReasons += "handoff evidence boundary promotes review material into real UX evidence"
    }

    $decision = $requestedDecision
    if ($blockingReasons.Count -gt 0) {
        $decision = "blocked"
    } elseif ($needsReworkReasons.Count -gt 0 -or $missingSections.Count -gt 0 -or $ambiguousSections.Count -gt 0) {
        $decision = "needs-rework"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-human-authorization-handoff"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        caseId = $caseId
        scope = $scope
        handoffDecision = $decision
        requestedHandoffDecision = $requestedDecision
        missingSections = @($missingSections)
        ambiguousSections = @($ambiguousSections)
        blockingReasons = @($blockingReasons)
        needsReworkReasons = @($needsReworkReasons)
        handoffSections = $handoffSections
        artifactIndex = $artifactIndex
        manualDecisionPlaceholder = $manualDecisionPlaceholder
        runnerGateReminder = $runnerGateReminder
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
        privatePathMatchCount = $privatePathMatches.Count
        allowedHandoffDecisions = @($allowedDecisions)
        forbiddenHandoffDecisions = @($forbiddenDecisions)
    }
}
