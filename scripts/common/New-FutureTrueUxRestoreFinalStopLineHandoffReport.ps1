#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreFinalStopLineText {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function New-FutureTrueUxRestoreFinalStopLinePattern {
    param(
        [Parameter(Mandatory)]
        [string[]]$Parts
    )

    [regex]::Escape(($Parts -join ""))
}

function New-FutureTrueUxRestoreFinalStopLineHandoffReport {
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

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "finalStopLineHandoff" -DefaultValue $null
    $caseId = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "caseId" -DefaultValue "repo-state")
    $requestedDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "stopLineDecision" -DefaultValue "pause-at-stop-line")
    $blockingReasons = @()
    $needsReworkReasons = @()

    $allowedDecisions = @("pause-at-stop-line", "request-rework", "start-true-restore-planning", "close-issue-manually")
    $forbiddenStates = @("execute-ready", "executed", "completed", "issue-18-complete", "closure-ready")
    $requiredLayers = @(
        "authorization-intake",
        "current-user-dry-run",
        "default-user-dry-run",
        "offline-image-dry-run",
        "machine-dry-run",
        "authorization-review",
        "mock-review-drill",
        "negative-review-drill",
        "approval-checklist-ergonomics",
        "integrated-packet-preview",
        "human-authorization-handoff",
        "end-to-end-no-execution-readiness-audit"
    )
    $requiredDocs = @(
        "docs/106-future-true-ux-restore-final-stop-line-handoff.md",
        "docs/107-future-true-ux-restore-stop-line-decision-matrix.md"
    )

    if ($null -eq $section) {
        $blockingReasons += "finalStopLineHandoff manifest section is missing"
    } else {
        $allowedDecisions = @($section.allowedStopLineDecisions | ForEach-Object { [string]$_ })
        $forbiddenStates = @($section.forbiddenStopLineStates | ForEach-Object { [string]$_ })
        $requiredLayers = @($section.requiredCompletedPreparationLayers | ForEach-Object { [string]$_ })
        $requiredDocs = @($section.requiredStopLineDocs | ForEach-Object { [string]$_ })
        if ($section.enabled -ne $true) {
            $blockingReasons += "finalStopLineHandoff must remain enabled"
        }
    }

    if ($allowedDecisions -notcontains $requestedDecision) {
        $blockingReasons += "stop-line decision is not allowed"
    }
    if ($forbiddenStates -contains $requestedDecision) {
        $blockingReasons += "stop-line decision is a forbidden execution or closure state"
    }

    $layerManifestMap = [ordered]@{
        "authorization-intake" = $Manifest
        "current-user-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "currentUserDryRun" -DefaultValue $null
        "default-user-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "defaultUserDryRun" -DefaultValue $null
        "offline-image-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "offlineImageDryRun" -DefaultValue $null
        "machine-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "machineDryRun" -DefaultValue $null
        "authorization-review" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "authorizationReview" -DefaultValue $null
        "mock-review-drill" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "mockReviewDrill" -DefaultValue $null
        "negative-review-drill" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "negativeReviewDrill" -DefaultValue $null
        "approval-checklist-ergonomics" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "approvalChecklistErgonomics" -DefaultValue $null
        "integrated-packet-preview" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "integratedPacketPreview" -DefaultValue $null
        "human-authorization-handoff" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "humanAuthorizationHandoff" -DefaultValue $null
        "end-to-end-no-execution-readiness-audit" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "endToEndNoExecutionReadinessAudit" -DefaultValue $null
    }

    $omittedLayers = @((Get-FutureTrueUxRestoreValue -InputObject $Request -Name "omittedLayers" -DefaultValue @()) | ForEach-Object { [string]$_ })
    $missingLayers = @()
    foreach ($layer in $requiredLayers) {
        if ($omittedLayers -contains $layer -or $null -eq $layerManifestMap[$layer]) {
            $missingLayers += $layer
        }
    }
    if ($missingLayers.Count -gt 0) {
        $needsReworkReasons += "missing completed preparation layers: $($missingLayers -join ', ')"
    }

    $flagDrift = @()
    foreach ($layer in $requiredLayers) {
        $layerObject = $layerManifestMap[$layer]
        if ($null -eq $layerObject) {
            continue
        }
        foreach ($flagName in @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")) {
            if ([bool](Get-FutureTrueUxRestoreValue -InputObject $layerObject -Name $flagName -DefaultValue $false)) {
                $flagDrift += "$layer.$flagName"
            }
        }
        if ([int](Get-FutureTrueUxRestoreValue -InputObject $layerObject -Name "mutationCount" -DefaultValue 0) -ne 0) {
            $flagDrift += "$layer.mutationCount"
        }
    }
    foreach ($flagName in @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")) {
        if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name $flagName -DefaultValue $false)) {
            $flagDrift += "request.$flagName"
        }
        if ($null -ne $section -and [bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
            $flagDrift += "finalStopLineHandoff.$flagName"
        }
    }
    if ([int](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $flagDrift += "request.mutationCount"
    }
    if ($null -ne $section -and [int](Get-FutureTrueUxRestoreValue -InputObject $section -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $flagDrift += "finalStopLineHandoff.mutationCount"
    }
    if ($flagDrift.Count -gt 0) {
        $blockingReasons += "execution flags drifted: $($flagDrift -join ', ')"
    }

    $missingDocs = @()
    $missingStatusDocs = @()
    $autoCloseMatches = @()
    $forbiddenDocOutputMatches = @()
    $docTexts = @()
    $autoClosePattern = '(?i)\b({0}|{1}|{2})\s+#18\b' -f ("fix" + "es"), ("close" + "s"), ("resolve" + "s")
    foreach ($docPath in $requiredDocs) {
        $resolvedDocPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $docPath
        $docText = Get-FutureTrueUxRestoreFinalStopLineText -Path $resolvedDocPath
        if ([string]::IsNullOrWhiteSpace($docText)) {
            $missingDocs += $docPath
            continue
        }
        $docTexts += $docText
        if ($docPath -like "*106-*" -and $docText -notmatch 'Status:\s*`final-stop-line-handoff`') {
            $missingStatusDocs += $docPath
        }
        if ($docPath -like "*107-*" -and $docText -notmatch 'Status:\s*`stop-line-decision-matrix`') {
            $missingStatusDocs += $docPath
        }
        if ($docText -match $autoClosePattern) {
            $autoCloseMatches += $docPath
        }
        foreach ($line in @($docText -split "`r?`n")) {
            if ($line -match '(?i)\b(current readiness|decision|result|output)\b.*\b(execute-ready|executed|completed|issue-18-complete|closure-ready)\b' -and $line -notmatch '(?i)\b(forbidden|must not|not output|listed here only)\b') {
                $forbiddenDocOutputMatches += "${docPath}: $line"
            }
        }
    }
    if ($missingDocs.Count -gt 0) {
        $needsReworkReasons += "missing stop-line docs: $($missingDocs -join ', ')"
    }
    if ($missingStatusDocs.Count -gt 0) {
        $needsReworkReasons += "missing stop-line doc status markers: $($missingStatusDocs -join ', ')"
    }
    if ($autoCloseMatches.Count -gt 0) {
        $blockingReasons += "stop-line docs contain Issue 18 auto-close wording"
    }
    if ($forbiddenDocOutputMatches.Count -gt 0) {
        $blockingReasons += "stop-line docs promote forbidden execution or closure output"
    }

    $requestText = (@($Request | Get-FutureTrueUxRestoreStrings) -join "`n")
    if ($requestText -match $autoClosePattern) {
        $blockingReasons += "request contains Issue 18 auto-close wording"
    }
    if ($requestText -match '(?i)\b(execute-ready|executed|completed|issue-18-complete|closure-ready)\b') {
        $blockingReasons += "request contains forbidden execution or closure wording"
    }

    $hasHumanDecisionBoundary = ($docTexts -join "`n") -match '(?i)human authorization|human decision|maintainer review'
    $hasNewRunnerGateBoundary = ($docTexts -join "`n") -match '(?i)new Runner Gate|fresh Runner Gate'
    $requiresHumanBoundary = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "requiresHumanDecisionBoundary" -DefaultValue $true)
    $requiresRunnerBoundary = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "requiresNewRunnerGateBoundary" -DefaultValue $true)
    if ($requiresHumanBoundary -and -not $hasHumanDecisionBoundary) {
        $needsReworkReasons += "human decision boundary is missing"
    }
    if ($requiresRunnerBoundary -and -not $hasNewRunnerGateBoundary) {
        $needsReworkReasons += "new Runner Gate boundary is missing"
    }
    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "missingRunnerGate" -DefaultValue $false)) {
        $needsReworkReasons += "fixture declares missing runner gate boundary"
    }

    if ($requestedDecision -eq "start-true-restore-planning" -and -not [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "newHighRiskPlanningChainRequired" -DefaultValue $false)) {
        $needsReworkReasons += "true restore planning requires a new high-risk planning chain"
    }

    $commandPatterns = @(
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Start", "-", "Process")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Invoke", "-", "Expression")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Set", "-", "Item", "Property")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("New", "-", "Item", "Property")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Remove", "-", "Appx", "Package")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Add", "-", "Mp", "Preference")),
        "\b$(([char]100).ToString())$(([char]105).ToString())$(([char]115).ToString())$(([char]109).ToString())\b",
        "\b$(([char]119).ToString())$(([char]105).ToString())$(([char]110).ToString())$(([char]103).ToString())$(([char]101).ToString())$(([char]116).ToString())\b",
        "\b$(([char]99).ToString())$(([char]104).ToString())$(([char]111).ToString())$(([char]99).ToString())$(([char]111).ToString())\b",
        "\b$(([char]109).ToString())$(([char]115).ToString())$(([char]105).ToString())$(([char]101).ToString())$(([char]120).ToString())$(([char]101).ToString())$(([char]99).ToString())\b",
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Invoke", "-", "Web", "Request")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Invoke", "-", "Rest", "Method")),
        (New-FutureTrueUxRestoreFinalStopLinePattern -Parts @("Install", "-", "Module"))
    )
    $dangerousScriptMatches = @()
    foreach ($relativePath in @("scripts/common/New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1", "scripts/validate/Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1")) {
        $scriptPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $relativePath
        $scriptText = Get-FutureTrueUxRestoreFinalStopLineText -Path $scriptPath
        foreach ($pattern in $commandPatterns) {
            if ($scriptText -match $pattern) {
                $dangerousScriptMatches += $relativePath
                break
            }
        }
    }
    if ($dangerousScriptMatches.Count -gt 0) {
        $blockingReasons += "dangerous command vocabulary found in final stop-line scripts"
    }

    $decision = $requestedDecision
    if ($blockingReasons.Count -gt 0) {
        $decision = "blocked"
    } elseif ($needsReworkReasons.Count -gt 0 -or $requestedDecision -eq "request-rework") {
        $decision = "request-rework"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-final-stop-line-handoff"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        caseId = $caseId
        stopLineDecision = $decision
        requestedStopLineDecision = $requestedDecision
        requiredCompletedPreparationLayers = @($requiredLayers)
        missingLayers = @($missingLayers)
        requiredStopLineDocs = @($requiredDocs)
        missingDocs = @($missingDocs)
        missingStatusDocs = @($missingStatusDocs)
        autoCloseMatches = @($autoCloseMatches)
        forbiddenDocOutputMatches = @($forbiddenDocOutputMatches)
        flagDrift = @($flagDrift)
        dangerousScriptMatches = @($dangerousScriptMatches)
        blockingReasons = @($blockingReasons)
        needsReworkReasons = @($needsReworkReasons)
        requiresNewRunnerGateForTrueRestorePlanning = $true
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
    }
}
