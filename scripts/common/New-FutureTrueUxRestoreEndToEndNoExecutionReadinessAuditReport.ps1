#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport {
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

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "endToEndNoExecutionReadinessAudit" -DefaultValue $null
    $requiredLayers = @(
        "authorization-intake",
        "current-user-dry-run",
        "default-user-dry-run",
        "offline-image-dry-run",
        "machine-dry-run",
        "authorization-review"
    )
    $forbiddenStates = @("execute-ready", "executed", "completed", "issue-18-complete", "closure-ready")
    if ($null -ne $section) {
        $requiredLayers = @($section.requiredLayers | ForEach-Object { [string]$_ })
        $forbiddenStates = @($section.forbiddenStates | ForEach-Object { [string]$_ })
    }

    $caseId = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "caseId" -DefaultValue "repo-state")
    $requestedDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "auditDecision" -DefaultValue "audit-ready")
    $blockingReasons = @()
    $needsReworkReasons = @()

    if ($null -eq $section) {
        $blockingReasons += "endToEndNoExecutionReadinessAudit manifest section is missing"
    } elseif ($section.enabled -ne $true) {
        $blockingReasons += "endToEndNoExecutionReadinessAudit must remain enabled"
    }

    $layerManifestMap = [ordered]@{
        "authorization-intake" = $Manifest
        "current-user-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "currentUserDryRun" -DefaultValue $null
        "default-user-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "defaultUserDryRun" -DefaultValue $null
        "offline-image-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "offlineImageDryRun" -DefaultValue $null
        "machine-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "machineDryRun" -DefaultValue $null
        "authorization-review" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "authorizationReview" -DefaultValue $null
    }

    $omittedLayers = @((Get-FutureTrueUxRestoreValue -InputObject $Request -Name "omittedLayers" -DefaultValue @()) | ForEach-Object { [string]$_ })
    $missingLayers = @()
    foreach ($layer in $requiredLayers) {
        if ($omittedLayers -contains $layer -or $null -eq $layerManifestMap[$layer]) {
            $missingLayers += $layer
        }
    }
    if ($missingLayers.Count -gt 0) {
        $needsReworkReasons += "missing required layers: $($missingLayers -join ', ')"
    }

    $flagDrift = @()
    foreach ($layer in $requiredLayers) {
        $layerObject = $layerManifestMap[$layer]
        if ($null -eq $layerObject) {
            continue
        }

        $flagDrift += @(Get-FutureTrueUxRestoreFrozenStateDrift -InputObject $layerObject -Prefix "$layer.")
    }
    $flagDrift += @(Get-FutureTrueUxRestoreFrozenStateDrift -InputObject $Request -Prefix "request.")
    if ($null -ne $section) {
        $flagDrift += @(Get-FutureTrueUxRestoreFrozenStateDrift -InputObject $section -Prefix "audit.")
    }
    if ($flagDrift.Count -gt 0) {
        $blockingReasons += "execution flags drifted: $($flagDrift -join ', ')"
    }

    $qualityGatePath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path "manifests/quality-gates.json"
    $qualityGateIds = @()
    if (Test-Path -LiteralPath $qualityGatePath) {
        $qualityGateIds = @((Get-Content -LiteralPath $qualityGatePath -Raw -Encoding UTF8 | ConvertFrom-Json).gates.id)
    }
    $requiredGateIds = @(
        "future-true-ux-restore-authorization",
        "future-true-ux-current-user-dry-run",
        "future-true-ux-scope-dry-run",
        "future-true-ux-authorization-review",
        "future-true-ux-end-to-end-no-execution-readiness-audit"
    )
    $missingGateIds = @()
    foreach ($gateId in $requiredGateIds) {
        if ($qualityGateIds -notcontains $gateId) {
            $missingGateIds += $gateId
        }
    }
    if ($missingGateIds.Count -gt 0) {
        $needsReworkReasons += "missing quality gates: $($missingGateIds -join ', ')"
    }

    $requiredDocs = @(
        @{ Path = "docs/archive/future-true-ux-restore/00-governance/106-future-true-ux-restore-final-stop-line-handoff.md"; Status = "final-stop-line-handoff" },
        @{ Path = "docs/archive/future-true-ux-restore/00-governance/107-future-true-ux-restore-stop-line-decision-matrix.md"; Status = "stop-line-decision-matrix" }
    )
    $missingDocs = @()
    $missingDocStatuses = @()
    foreach ($doc in $requiredDocs) {
        $resolvedDoc = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $doc.Path
        $text = Get-FutureTrueUxRestoreDocumentText -Path $resolvedDoc
        if ([string]::IsNullOrWhiteSpace($text)) {
            $missingDocs += $doc.Path
        } elseif (-not (Test-FutureTrueUxRestoreStatusMarker -Text $text -Status $doc.Status)) {
            $missingDocStatuses += $doc.Path
        }
    }
    if ($missingDocs.Count -gt 0) {
        $needsReworkReasons += "missing stop-line docs: $($missingDocs -join ', ')"
    }
    if ($missingDocStatuses.Count -gt 0) {
        $needsReworkReasons += "missing stop-line doc status markers: $($missingDocStatuses -join ', ')"
    }

    $docRoot = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path "docs"
    $futureDocs = @(Get-ChildItem -LiteralPath $docRoot -Filter "*future-true-ux-restore*.md" -Recurse | Where-Object { $_.Name -match '^\d+' })
    $autoCloseMatches = @()
    $statePromotionMatches = @()
    $evidencePromotionMatches = @()
    $autoClosePattern = Get-FutureTrueUxRestoreIssueAutoClosePattern -IssueNumber 18
    $statePromotionPattern = Get-FutureTrueUxRestoreStatePromotionPattern
    $evidencePromotionPattern = Get-FutureTrueUxRestoreEvidencePromotionPattern -Scope NoExecutionAudit
    $stopLineSeen = $false
    foreach ($docFile in $futureDocs) {
        $text = Get-FutureTrueUxRestoreDocumentText -Path $docFile.FullName
        if ($text -match $autoClosePattern) {
            $autoCloseMatches += $docFile.Name
        }
        if ($text -match '(?i)\b(no-execution stop line|stops before human authorization|stops at review readiness)\b') {
            $stopLineSeen = $true
        }
        foreach ($line in @($text -split "`r?`n")) {
            if ($line -match $statePromotionPattern -and $line -notmatch '(?i)\bnot\b') {
                $statePromotionMatches += "$($docFile.Name): $line"
            }
            if ($line -match $evidencePromotionPattern -and $line -notmatch '(?i)\bnot\b') {
                $evidencePromotionMatches += "$($docFile.Name): $line"
            }
        }
    }
    if ($autoCloseMatches.Count -gt 0) {
        $blockingReasons += "Issue 18 auto-close terms found: $($autoCloseMatches -join ', ')"
    }
    if ($statePromotionMatches.Count -gt 0) {
        $blockingReasons += "state promotion wording found"
    }
    if ($evidencePromotionMatches.Count -gt 0) {
        $needsReworkReasons += "review material promoted into real evidence"
    }

    $requestText = (@($Request | Get-FutureTrueUxRestoreStrings) -join "`n")
    if ($requestText -match $autoClosePattern) {
        $blockingReasons += "request contains Issue 18 auto-close wording"
    }
    if ($requestText -match $statePromotionPattern -and $requestText -notmatch '(?i)\bnot\b') {
        $blockingReasons += "request promotes separated states"
    }
    if ($requestText -match $evidencePromotionPattern -and $requestText -notmatch '(?i)\bnot\b') {
        $needsReworkReasons += "request promotes review material into real evidence"
    }

    $commandPatterns = @(Get-FutureTrueUxRestoreDangerousCommandPatterns)
    $scriptScanPaths = @(
        "scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1",
        "scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1"
    )
    $dangerousScriptMatches = @()
    foreach ($relativePath in $scriptScanPaths) {
        $scriptPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $relativePath
        $scriptText = Get-FutureTrueUxRestoreDocumentText -Path $scriptPath
        foreach ($pattern in $commandPatterns) {
            if ($scriptText -match $pattern) {
                $dangerousScriptMatches += "$relativePath"
                break
            }
        }
    }
    $dangerousRequestMatches = @()
    foreach ($pattern in $commandPatterns) {
        if ($requestText -match $pattern) {
            $dangerousRequestMatches += $pattern
        }
    }
    if ($dangerousScriptMatches.Count -gt 0) {
        $blockingReasons += "dangerous command vocabulary found in audit scripts: $($dangerousScriptMatches -join ', ')"
    }
    if ($dangerousRequestMatches.Count -gt 0) {
        $blockingReasons += "dangerous command vocabulary found in request"
    }

    $closurePrepMatches = @()
    foreach ($docFile in $futureDocs) {
        if ($docFile.Name -match '(?i)(completion-summary|close-preparation|main-validation-evidence|main-evidence|closure-ready)') {
            $closurePrepMatches += $docFile.Name
        }
    }
    if ($closurePrepMatches.Count -gt 0) {
        $blockingReasons += "Future True UX Restore closure-prep artifact found: $($closurePrepMatches -join ', ')"
    }

    $requiresStopLine = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "requiresRunnerStopLine" -DefaultValue $false)
    $hasFixtureStopLine = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "hasRunnerStopLine" -DefaultValue $true)
    if ((-not $stopLineSeen) -or ($requiresStopLine -and -not $hasFixtureStopLine)) {
        $needsReworkReasons += "no-execution stop-line language is missing"
    }

    $decision = $requestedDecision
    if ($blockingReasons.Count -gt 0) {
        $decision = "blocked"
    } elseif ($needsReworkReasons.Count -gt 0) {
        $decision = "needs-rework"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-end-to-end-no-execution-readiness-audit"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        caseId = $caseId
        auditDecision = $decision
        requestedAuditDecision = $requestedDecision
        requiredLayers = @($requiredLayers)
        missingLayers = @($missingLayers)
        forbiddenStates = @($forbiddenStates)
        flagDrift = @($flagDrift)
        missingQualityGates = @($missingGateIds)
        missingDocs = @($missingDocs)
        missingDocStatuses = @($missingDocStatuses)
        autoCloseMatches = @($autoCloseMatches)
        statePromotionMatches = @($statePromotionMatches)
        evidencePromotionMatches = @($evidencePromotionMatches)
        dangerousScriptMatches = @($dangerousScriptMatches)
        dangerousRequestMatchCount = $dangerousRequestMatches.Count
        closurePrepMatches = @($closurePrepMatches)
        stopLineSeen = [bool]$stopLineSeen
        blockingReasons = @($blockingReasons)
        needsReworkReasons = @($needsReworkReasons)
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
    }
}
