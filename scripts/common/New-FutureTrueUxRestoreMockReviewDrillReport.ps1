#Requires -Version 5.1

. "$PSScriptRoot\FutureTrueUxRestore.Guards.ps1"
. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1"

function New-FutureTrueUxRestoreMockDecisionLedger {
    param(
        [Parameter(Mandatory)]
        [string]$Scope
    )

    $flags = New-FutureTrueUxRestoreFrozenExecutionState

    @(
        [pscustomobject][ordered]@{
            stage = "received"
            decision = "accepted-for-mock-review"
            reason = "fixture packet exists"
            allowedNextState = "packet-complete"
            forbiddenNextState = "execute-ready"
            evidenceSource = "mock request fixture"
            executionFlags = $flags
        },
        [pscustomobject][ordered]@{
            stage = "packet-complete"
            decision = "complete"
            reason = "required packet fields are present for $Scope"
            allowedNextState = "authorization-review-ready"
            forbiddenNextState = "executed"
            evidenceSource = "mock evidence packet"
            executionFlags = $flags
        },
        [pscustomobject][ordered]@{
            stage = "authorization-review-ready"
            decision = "ready-for-review-only"
            reason = "mock reviewer checklist is complete"
            allowedNextState = "not-execute-ready"
            forbiddenNextState = "completed"
            evidenceSource = "mock maintainer transcript"
            executionFlags = $flags
        },
        [pscustomobject][ordered]@{
            stage = "execute-ready-blocked"
            decision = "blocked"
            reason = "execution approval is outside the mock drill"
            allowedNextState = "true-execution-blocked"
            forbiddenNextState = "execute-ready"
            evidenceSource = "mock decision ledger"
            executionFlags = $flags
        },
        [pscustomobject][ordered]@{
            stage = "true-execution-blocked"
            decision = "blocked"
            reason = "no mutation is authorized"
            allowedNextState = "blocked-for-execution"
            forbiddenNextState = "executed"
            evidenceSource = "mock decision ledger"
            executionFlags = $flags
        }
    )
}

function New-FutureTrueUxRestoreMockReviewTranscript {
    param(
        [Parameter(Mandatory)]
        $ReviewReport
    )

    [pscustomobject][ordered]@{
        reviewerRole = "maintainer-reviewer-fixture"
        inputSummary = "single-scope mock packet for $($ReviewReport.scope)"
        checklist = [pscustomobject][ordered]@{
            oneScopeOnly = $true
            targetIdentityRedacted = $true
            evidencePacketComplete = ($ReviewReport.evidencePacketStatus -eq "complete")
            rollbackPresent = $true
            independentVerificationPlaceholderPresent = $true
            failurePropagationPresent = $true
            noPrivatePath = ($ReviewReport.privatePathMatchCount -eq 0)
            noAutoCloseKeyword = $true
            noExecuteReady = ($ReviewReport.executeReady -eq $false)
        }
        reviewDecision = $ReviewReport.reviewDecision
        executionDecision = "not-approved"
        warning = "review-ready is not execution approval"
    }
}

function New-FutureTrueUxRestoreMockReviewDrillReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        $Request,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "mockReviewDrill" -DefaultValue $null
    $reviewReport = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $Manifest -Request $Request -RepoRoot $RepoRoot

    $blockedReasons = @($reviewReport.blockedReasons)
    if ($null -eq $section) {
        $blockedReasons += "mockReviewDrill manifest section is missing"
    } else {
        foreach ($flagName in @(Get-FutureTrueUxRestoreFrozenFlagNames)) {
            if ([bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
                $blockedReasons += "mockReviewDrill $flagName must remain false"
            }
        }

        if ([int](Get-FutureTrueUxRestoreValue -InputObject $section -Name "mutationCount" -DefaultValue 0) -ne 0) {
            $blockedReasons += "mockReviewDrill mutationCount must remain 0"
        }

        $allowed = @($section.allowedMockDecisions | ForEach-Object { [string]$_ })
        foreach ($decision in @("execute-ready", "executed", "completed")) {
            if ($allowed -contains $decision) {
                $blockedReasons += "mockReviewDrill allowed decisions must not include $decision"
            }
        }
    }

    foreach ($decisionName in @("execute-ready", "executed", "completed")) {
        if ([string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "mockDecision" -DefaultValue "") -eq $decisionName) {
            $blockedReasons += "mock decision $decisionName is blocked"
        }
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "executed" -DefaultValue $false)) {
        $blockedReasons += "executed request is blocked"
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "completed" -DefaultValue $false)) {
        $blockedReasons += "completed request is blocked"
    }

    $packetStatus = $reviewReport.evidencePacketStatus
    $reviewDecision = $reviewReport.reviewDecision
    if ($blockedReasons.Count -gt 0) {
        $reviewDecision = "blocked"
        if ($packetStatus -eq "complete") {
            $packetStatus = "blocked"
        }
    }

    $transcript = New-FutureTrueUxRestoreMockReviewTranscript -ReviewReport $reviewReport
    $ledger = @(New-FutureTrueUxRestoreMockDecisionLedger -Scope $reviewReport.scope)

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-mock-review-drill"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        mode = "mock-review-drill"
        scope = $reviewReport.scope
        packetStatus = $packetStatus
        reviewDecision = $reviewDecision
        executionDecision = "not-approved"
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
        blockedForExecution = $true
        userConfigurationConfirmed = $false
        privatePathRedacted = ($reviewReport.privatePathMatchCount -eq 0)
        blockedReasons = @($blockedReasons)
        requestSummary = [pscustomobject][ordered]@{
            scope = $reviewReport.scope
            requestedReviewDecision = $reviewReport.requestedReviewDecision
            evidencePacketStatus = $reviewReport.evidencePacketStatus
        }
        packetSummary = $reviewReport.evidencePacket
        transcript = $transcript
        decisionLedger = @($ledger)
    }
}
