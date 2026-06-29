#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestorePreviewSectionValue {
    param(
        [AllowNull()]
        $PreviewSections,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $PreviewSections) {
        return $null
    }

    if ($PreviewSections.PSObject.Properties.Name -contains $Name) {
        return $PreviewSections.$Name
    }

    return $null
}

function Test-FutureTrueUxRestorePreviewText {
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

function New-FutureTrueUxRestoreIntegratedPacketPreviewReport {
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

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "integratedPacketPreview" -DefaultValue $null
    $requiredSections = @()
    $allowedDecisions = @()
    $forbiddenDecisions = @("authorization-review-ready", "execute-ready", "executed", "completed")
    if ($null -ne $section) {
        $requiredSections = @($section.requiredPreviewSections | ForEach-Object { [string]$_ })
        $allowedDecisions = @($section.allowedPreviewDecisions | ForEach-Object { [string]$_ })
        $forbiddenDecisions = @($section.forbiddenPreviewDecisions | ForEach-Object { [string]$_ })
    }

    $caseId = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "caseId" -DefaultValue "")
    $scope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scope" -DefaultValue "")
    $requestedDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "previewDecision" -DefaultValue "blocked")
    $previewSections = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "packetPreviewSections" -DefaultValue $null

    $missingSections = @()
    foreach ($name in $requiredSections) {
        $value = Get-FutureTrueUxRestorePreviewSectionValue -PreviewSections $previewSections -Name $name
        if (-not (Test-FutureTrueUxRestorePreviewText -Value $value)) {
            $missingSections += $name
        }
    }

    $ambiguousSections = @()
    foreach ($name in @("scope", "evidence-boundary", "approval-checklist-summary", "negative-blocker-summary", "rollback-or-restore-plan", "execution-boundary", "runner-gate-reminder")) {
        $value = [string](Get-FutureTrueUxRestorePreviewSectionValue -PreviewSections $previewSections -Name $name)
        if ($value -match '(?i)\b(unclear|ambiguous|maybe|TBD|to be decided|later|unknown)\b') {
            $ambiguousSections += $name
        }
    }

    $blockingReasons = @()
    $needsReworkReasons = @()
    if ($null -eq $section) {
        $blockingReasons += "integratedPacketPreview manifest section is missing"
    }

    if ($allowedDecisions.Count -gt 0 -and $allowedDecisions -notcontains $requestedDecision) {
        $blockingReasons += "preview decision $requestedDecision is not allowed in this stage"
    }
    if ($forbiddenDecisions -contains $requestedDecision) {
        $blockingReasons += "preview decision $requestedDecision is forbidden in this stage"
    }

    $validScopes = @(Get-FutureTrueUxRestoreSupportedScopes)
    if ($validScopes -notcontains $scope) {
        $blockingReasons += "scope must name exactly one supported scope"
    }

    if ($missingSections.Count -gt 0) {
        $needsReworkReasons += "missing preview sections: $($missingSections -join ', ')"
    }
    if ($ambiguousSections.Count -gt 0) {
        $needsReworkReasons += "ambiguous preview sections: $($ambiguousSections -join ', ')"
    }

    $blockingReasons += @(Get-FutureTrueUxRestoreFrozenStateMessages -InputObject $Request)
    if ($null -ne $section) {
        $blockingReasons += @(Get-FutureTrueUxRestoreFrozenStateMessages -InputObject $section -Subject "manifest")
    }

    $privatePathMatches = @(Test-FutureTrueUxRestorePrivatePath -InputObject $Request)
    if ($privatePathMatches.Count -gt 0) {
        $blockingReasons += "private path must be redacted before packet preview"
    }

    $allText = (@($Request | Get-FutureTrueUxRestoreStrings) -join "`n")
    if ($allText -match (Get-FutureTrueUxRestoreReviewStateDriftPattern)) {
        $blockingReasons += "preview wording drifts into authorization or execution state"
    }
    if ($allText -match (Get-FutureTrueUxRestoreEvidencePromotionPattern)) {
        $needsReworkReasons += "preview evidence boundary promotes report-only material into real UX evidence"
    }

    $decision = $requestedDecision
    if ($blockingReasons.Count -gt 0) {
        $decision = "blocked"
    } elseif ($needsReworkReasons.Count -gt 0 -or $missingSections.Count -gt 0 -or $ambiguousSections.Count -gt 0) {
        $decision = "needs-rework"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-integrated-packet-preview"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        caseId = $caseId
        scope = $scope
        previewDecision = $decision
        requestedPreviewDecision = $requestedDecision
        missingSections = @($missingSections)
        ambiguousSections = @($ambiguousSections)
        blockingReasons = @($blockingReasons)
        needsReworkReasons = @($needsReworkReasons)
        packetPreviewSections = $previewSections
        fieldMap = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "fieldMap" -DefaultValue @()
        reviewerReadingOrder = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "reviewerReadingOrder" -DefaultValue @()
        blockerIndex = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "blockerIndex" -DefaultValue @()
        runnerGateReminder = [string](Get-FutureTrueUxRestorePreviewSectionValue -PreviewSections $previewSections -Name "runner-gate-reminder")
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
        privatePathMatchCount = $privatePathMatches.Count
        allowedPreviewDecisions = @($allowedDecisions)
        forbiddenPreviewDecisions = @($forbiddenDecisions)
    }
}
