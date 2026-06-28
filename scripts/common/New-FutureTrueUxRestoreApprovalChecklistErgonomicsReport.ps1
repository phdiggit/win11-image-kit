#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreChecklistSectionValue {
    param(
        [AllowNull()]
        $ChecklistSections,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $ChecklistSections) {
        return $null
    }

    if ($ChecklistSections.PSObject.Properties.Name -contains $Name) {
        return $ChecklistSections.$Name
    }

    return $null
}

function Test-FutureTrueUxRestoreChecklistText {
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

function New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport {
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

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "approvalChecklistErgonomics" -DefaultValue $null
    $requiredSections = @()
    $allowedDecisions = @()
    $forbiddenDecisions = @("authorization-review-ready", "execute-ready", "executed", "completed")
    if ($null -ne $section) {
        $requiredSections = @($section.requiredChecklistSections | ForEach-Object { [string]$_ })
        $allowedDecisions = @($section.allowedChecklistDecisions | ForEach-Object { [string]$_ })
        $forbiddenDecisions = @($section.forbiddenChecklistDecisions | ForEach-Object { [string]$_ })
    }

    $caseId = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "caseId" -DefaultValue "")
    $scope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scope" -DefaultValue "")
    $requestedDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "checklistDecision" -DefaultValue "blocked")
    $checklistSections = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "checklistSections" -DefaultValue $null

    $missingSections = @()
    foreach ($name in $requiredSections) {
        $value = Get-FutureTrueUxRestoreChecklistSectionValue -ChecklistSections $checklistSections -Name $name
        if (-not (Test-FutureTrueUxRestoreChecklistText -Value $value)) {
            $missingSections += $name
        }
    }

    $ambiguousSections = @()
    foreach ($name in @("scope", "evidence-boundary", "rollback-or-restore-plan", "reviewer-decision", "execution-boundary")) {
        $value = [string](Get-FutureTrueUxRestoreChecklistSectionValue -ChecklistSections $checklistSections -Name $name)
        if ($value -match '(?i)\b(unclear|ambiguous|maybe|TBD|to be decided|later|unknown)\b') {
            $ambiguousSections += $name
        }
    }

    $blockingReasons = @()
    $needsReworkReasons = @()
    if ($null -eq $section) {
        $blockingReasons += "approvalChecklistErgonomics manifest section is missing"
    }

    if ($allowedDecisions.Count -gt 0 -and $allowedDecisions -notcontains $requestedDecision) {
        $blockingReasons += "checklist decision $requestedDecision is not allowed in this stage"
    }
    if ($forbiddenDecisions -contains $requestedDecision) {
        $blockingReasons += "checklist decision $requestedDecision is forbidden in this stage"
    }

    $validScopes = @("current-user", "default-user", "offline-image", "machine")
    if ($validScopes -notcontains $scope) {
        $blockingReasons += "scope must name exactly one supported scope"
    }

    if ($missingSections.Count -gt 0) {
        $needsReworkReasons += "missing checklist sections: $($missingSections -join ', ')"
    }
    if ($ambiguousSections.Count -gt 0) {
        $needsReworkReasons += "ambiguous checklist sections: $($ambiguousSections -join ', ')"
    }

    foreach ($flagName in @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")) {
        if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name $flagName -DefaultValue $false)) {
            $blockingReasons += "$flagName must remain false"
        }
        if ($null -ne $section -and [bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
            $blockingReasons += "manifest $flagName must remain false"
        }
    }

    $mutationCount = [int](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "mutationCount" -DefaultValue 0)
    if ($mutationCount -ne 0) {
        $blockingReasons += "mutationCount must remain 0"
    }
    if ($null -ne $section -and [int](Get-FutureTrueUxRestoreValue -InputObject $section -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $blockingReasons += "manifest mutationCount must remain 0"
    }

    $privatePathMatches = @(Test-FutureTrueUxRestorePrivatePath -InputObject $Request)
    if ($privatePathMatches.Count -gt 0) {
        $blockingReasons += "private path must be redacted before maintainer review"
    }

    $allText = (@($Request | Get-FutureTrueUxRestoreStrings) -join "`n")
    if ($allText -match '(?i)\b(authorization-review-ready|execute-ready|approved to execute|executed|completed)\b') {
        $blockingReasons += "wording drifts into authorization or execution state"
    }
    if ($allText -match '(?i)\b(CI success|dry-run success|mock packet success|report-only success)\b.*\b(real UX evidence|true UX evidence|approval)\b') {
        $needsReworkReasons += "evidence boundary treats CI, dry-run, mock, or report-only output as approval"
    }

    $score = 100
    $score -= ($missingSections.Count * 12)
    $score -= ($ambiguousSections.Count * 10)
    $score -= ($needsReworkReasons.Count * 8)
    $score -= ($blockingReasons.Count * 18)
    if ($score -lt 0) {
        $score = 0
    }

    $tier = "ready"
    if ($score -lt 80) {
        $tier = "needs-rework"
    }
    if ($score -lt 50 -or $blockingReasons.Count -gt 0) {
        $tier = "blocked"
    }

    $decision = $requestedDecision
    if ($blockingReasons.Count -gt 0) {
        $decision = "blocked"
    } elseif ($needsReworkReasons.Count -gt 0 -or $missingSections.Count -gt 0 -or $ambiguousSections.Count -gt 0) {
        $decision = "needs-rework"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-approval-checklist-ergonomics"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        caseId = $caseId
        scope = $scope
        checklistDecision = $decision
        requestedChecklistDecision = $requestedDecision
        readabilityScore = $score
        readabilityTier = $tier
        missingSections = @($missingSections)
        ambiguousSections = @($ambiguousSections)
        blockingReasons = @($blockingReasons)
        needsReworkReasons = @($needsReworkReasons)
        checklistSections = $checklistSections
        humanDecisionSummary = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "humanDecisionSummary" -DefaultValue "")
        executionBoundary = [string](Get-FutureTrueUxRestoreChecklistSectionValue -ChecklistSections $checklistSections -Name "execution-boundary")
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
        privatePathMatchCount = $privatePathMatches.Count
        allowedChecklistDecisions = @($allowedDecisions)
        forbiddenChecklistDecisions = @($forbiddenDecisions)
    }
}
